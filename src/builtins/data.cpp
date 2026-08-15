#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/data.cpp
// JSON, crypto, collections
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_data() is called from NythonExecutor::callBuiltin().
//   It has full access to the executor via the `E` reference (same as `*this`
//   in the original monolithic main.cpp).  Every helper that was previously
//   a member call (getStringValue, makeStringValue, callBuiltin, etc.) is
//   accessed through `E.` — keeping code changes minimal.
// ─────────────────────────────────────────────────────────────────────────────

// Platform compatibility (must come first)
#include "platform_compat.hpp"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <regex>
#include <cstdlib>
#include <cmath>
#include <chrono>
#include <random>
#include <thread>
#include <mutex>
#include <functional>
#include <iomanip>
#include <string>
#include <vector>
#include <map>
#include <ctime>
#include <cwctype>
#include <locale>

// Full executor definition (needed for E.getStringValue etc.)
#include "NythonExecutor.hpp"
#include "builtins/data.hpp"

// ── Namespace imports (match main.cpp) ────────────────────────────────────────
using namespace std;
using namespace nython;
using namespace nython::io;
using namespace nython::node;
using namespace nython::lexer;
using namespace nython::kernel;
using namespace nython::parser;
using namespace nython::reader;
using namespace nython::exception;

// ════════════════════════════════════════════════════════════════════════════════
// dispatch_data
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_data(NythonExecutor& E,
                       const std::string& name,
                       std::vector<Value>& args,
                       Context* ctx) {
    // Local aliases — identical names to original main.cpp code so the
    // extracted if-blocks compile unchanged.
    auto  makeStringValue  = [&](const std::string& s) { return E.makeStringValue(s); };
    auto  getStringValue   = [&](const Value& v)       { return E.getStringValue(v); };
    auto  isStringValue    = [&](const Value& v)       { return E.isStringValue(v); };
    auto  callBuiltin      = [&](const std::string& n, std::vector<Value>& a, Context* c)
                                { return E.callBuiltin(n, a, c); };
    auto  callFunctionValue= [&](Value fn, std::vector<Value>& a, Context* c)
                                { return E.callFunctionValue(fn, a, c); };
    auto  isTruthy         = [&](Value v) { return E.isTruthy(v); };
    auto  evalNode         = [&](node_ptr n, Context* c) { return E.evalNode(n, c); };
    auto& file_handles     = E.file_handles;
    auto& next_file_handle = E.next_file_handle;
    Runnable* runner       = E.runner;
    auto& func_names       = E.func_names;
    auto& instance_to_class= E.instance_to_class;
    auto& instance_properties = E.instance_properties;
    auto& class_by_name    = E.class_by_name;
    auto& class_parent     = E.class_parent;
    auto& super_parent_stack = E.super_parent_stack;
    auto& func_ast_nodes   = E.func_ast_nodes;
    auto& func_id_store    = E.func_id_store;
    auto& instance_store   = E.instance_store;
    auto& string_store     = E.string_store;
    auto  registerBuiltin  = [&](const std::string& n) { E.registerBuiltin(n); };
    auto  callMethod       = [&](Value inst, const std::string& mname, std::vector<Value>& a, Context* c)
                                { return E.callMethod(inst, mname, a, c); };
    auto  printValue       = [&](const Value& v, Context* c = nullptr) { E.printValue(v, c ? c : ctx); };

    // ── shape_to_size helper (used by tensor builtins) ───────────────────────
    auto shape_to_size = [&](const Value& v) -> int {
        if (v.type == ValueType::INTEGER) return (int)bigint_to_i64(v.value.i);
        if (v.type == ValueType::DOUBLE)  return (int)v.value.d;
        if (v.isCollectable()) {
            auto* c = dynamic_cast<Container*>(v.value.gc);
            if (c && c->container) {
                auto li = c->container->find("__len__");
                int len = (li != c->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                if (len == 0) return 0;
                int total = 1;
                for (int k = 0; k < len; k++) {
                    auto ei = c->container->find(std::to_string(k));
                    if (ei != c->container->end()) {
                        if (ei->second.type == ValueType::INTEGER)
                            total *= (int)bigint_to_i64(ei->second.value.i);
                        else if (ei->second.type == ValueType::DOUBLE)
                            total *= (int)ei->second.value.d;
                    }
                }
                return total;
            }
        }
        return 0;
    };

// ── Extracted builtin implementations ────────────────────────────────────────
    // ── from main.cpp lines 4858–4887 ──────────────────────────────────────────
        // ===================== FIXED CRYPTO =====================
        if (name == "md5") {
            if (!args.empty())
                return makeStringValue(ny_crypto::md5(getStringValue(args[0])));
            return NONE_VALUE;
        }
        if (name == "sha256") {
            if (!args.empty())
                return makeStringValue(ny_crypto::sha256(getStringValue(args[0])));
            return NONE_VALUE;
        }
        // ===================== FIXED JSON DECODE =====================
    // ── from main.cpp lines 4888–4938 ──────────────────────────────────────────
        if (name == "json_decode" || name == "json_parse") {
            if (!args.empty()) {
                std::string json = getStringValue(args[0]);
                // Trim whitespace
                while (!json.empty() && (json.front()==' '||json.front()=='\t'||json.front()=='\n')) json.erase(0,1);
                while (!json.empty() && (json.back()==' '||json.back()=='\t'||json.back()=='\n')) json.pop_back();
                // Handle primitives first
                if (json == "null" || json == "none") return NONE_VALUE;
                if (json == "true") return Value(true);
                if (json == "false") return Value(false);
                if (json.size() >= 2 && json.front() == '"' && json.back() == '"')
                    return makeStringValue(json.substr(1, json.size() - 2));
                if (!json.empty() && json[0] != '{' && json[0] != '[') {
                    if (json.find('.') != std::string::npos) { try { return Value(std::stod(json)); } catch (...) {} }
                    try { return Value(static_cast<int>(std::stoll(json))); } catch (...) {}
                }
                Object* result = new Object((Runnable*)runner, "map", Type::LIST);
                if (!json.empty() && json[0] == '{') {
                    size_t pos = 1;
                    while (pos < json.size()) {
                        while (pos < json.size() && (json[pos]==' '||json[pos]=='\n'||json[pos]==','||json[pos]=='\t')) pos++;
                        if (pos >= json.size() || json[pos] == '}') break;
                        if (json[pos] == '"') {
                            pos++; size_t ks = pos;
                            while (pos < json.size() && json[pos] != '"') pos++;
                            std::string key = json.substr(ks, pos - ks); pos++;
                            while (pos < json.size() && (json[pos]==':'||json[pos]==' ')) pos++;
                            if (pos < json.size()) {
                                if (json[pos] == '"') {
                                    pos++; size_t vs = pos;
                                    while (pos < json.size() && json[pos] != '"') pos++;
                                    result->set(key, makeStringValue(json.substr(vs, pos - vs))); pos++;
                                } else if (json[pos]=='t') { result->set(key, Value(true)); pos+=4; }
                                else if (json[pos]=='f') { result->set(key, Value(false)); pos+=5; }
                                else if (json[pos]=='n') { result->set(key, NONE_VALUE); pos+=4; }
                                else {
                                    size_t vs = pos; bool dot = false;
                                    while (pos<json.size()&&(std::isdigit(json[pos])||json[pos]=='.'||json[pos]=='-')) { if(json[pos]=='.') dot=true; pos++; }
                                    std::string ns = json.substr(vs, pos-vs);
                                    // A malformed/edge-case number here (empty, a
                                    // lone "-") previously threw an unguarded
                                    // std::invalid_argument straight out of
                                    // json_decode, past every Nython-level
                                    // try/except, and crashed the whole process
                                    // with an unhelpful "error: stol" instead of
                                    // a catchable ValueError. Fall back to 0
                                    // rather than take the process down over one
                                    // bad field, matching the top-level-primitive
                                    // parse a few lines above.
                                    if (dot) { try { result->set(key, Value(std::stod(ns))); } catch (...) { result->set(key, Value(0.0)); } }
                                    else { try { result->set(key, Value(static_cast<int>(std::stol(ns)))); } catch (...) { result->set(key, Value(0)); } }
                                }
                            }
                        } else pos++;
                    }
                }
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        // ===================== THREADING =====================
    // ── from main.cpp lines 8452–8518 ──────────────────────────────────────────
        // ===================== JSON MODULE =====================
        if (name == "json_encode" || name == "json_stringify") {
            if (args.size() >= 1) {
                std::function<std::string(Value)> to_json;
                to_json = [&](Value v) -> std::string {
                    if (v.isNone()) return "null";
                    if (v.type == ValueType::BOOLEAN) return v.value.b ? "true" : "false";
                    if (v.type == ValueType::INTEGER) return std::to_string(bigint_to_i64(v.value.i));
                    if (v.type == ValueType::DOUBLE) {
                        std::ostringstream oss; oss << v.value.d; return oss.str();
                    }
                    if (v.type == ValueType::USERDATA) return "\"" + getStringValue(v) + "\"";
                    if (v.isCollectable() && v.value.gc) {
                        auto* cont = dynamic_cast<Container*>(v.value.gc);
                        if (cont && cont->container) {
                            auto li = cont->container->find("__len__");
                            if (li != cont->container->end()) {
                                int len = (int)bigint_to_i64(li->second.value.i);
                                std::string r = "[";
                                for (int i = 0; i < len; i++) {
                                    if (i > 0) r += ", ";
                                    auto it = cont->container->find(std::to_string(i));
                                    r += (it != cont->container->end()) ? to_json(it->second) : "null";
                                }
                                return r + "]";
                            }
                            std::string r = "{";
                            bool first = true;
                            for (auto& [k, val] : *cont->container) {
                                if (k == "__len__" || k == "__type__" || k == "__name__") continue;
                                if (!first) r += ", ";
                                first = false;
                                r += "\"" + k + "\": " + to_json(val);
                            }
                            return r + "}";
                        }
                    }
                    return "null";
                };
                return makeStringValue(to_json(args[0]));
            }
            return makeStringValue("null");
        }
        if (name == "json_decode" || name == "json_parse") {
            if (args.size() >= 1) {
                std::string json = getStringValue(args[0]);
                // Simple JSON parser for basic types
                auto trim = [](std::string s) -> std::string {
                    while (!s.empty() && (s.front() == ' ' || s.front() == '\t' || s.front() == '\n')) s.erase(0, 1);
                    while (!s.empty() && (s.back() == ' ' || s.back() == '\t' || s.back() == '\n')) s.pop_back();
                    return s;
                };
                json = trim(json);
                if (json == "null") return NONE_VALUE;
                if (json == "true") return Value(true);
                if (json == "false") return Value(false);
                if (json.size() >= 2 && json.front() == '"' && json.back() == '"')
                    return makeStringValue(json.substr(1, json.size() - 2));
                if (json.find('.') != std::string::npos) {
                    try { return Value(std::stod(json)); } catch (...) {}
                }
                try { return Value((int)std::stoll(json)); } catch (...) {}
            }
            return NONE_VALUE;
        }

        // ===================== CRYPTO/HASH MODULE =====================
    // ── from main.cpp lines 8519–8658 ──────────────────────────────────────────
        if (name == "hash_sha256" || name == "hash_md5") {
            // Simple hash using std::hash (not cryptographic, but functional)
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                std::hash<std::string> hasher;
                size_t h = hasher(input);
                // Generate pseudo-hash string
                char buf[32];
                snprintf(buf, sizeof(buf), "%016lx", (unsigned long)h);
                return makeStringValue(std::string(buf));
            }
            return makeStringValue("");
        }
        if (name == "base64_encode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                const char* chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
                std::string result;
                int i = 0, len = input.size();
                unsigned char c3[3]; unsigned char c4[4];
                while (len--) {
                    c3[i++] = *(input.c_str() + (input.size() - len - 1));
                    if (i == 3) {
                        c4[0] = static_cast<unsigned char>((c3[0] & 0xfc) >> 2);
                        c4[1] = ((c3[0] & 0x03) << 4) + ((c3[1] & 0xf0) >> 4);
                        c4[2] = ((c3[1] & 0x0f) << 2) + ((c3[2] & 0xc0) >> 6);
                        c4[3] = static_cast<unsigned char>(c3[2] & 0x3f);
                        for (int j = 0; j < 4; j++) result += chars[c4[j]];
                        i = 0;
                    }
                }
                if (i) {
                    for (int j = i; j < 3; j++) c3[j] = '\0';
                    c4[0] = static_cast<unsigned char>((c3[0] & 0xfc) >> 2);
                    c4[1] = ((c3[0] & 0x03) << 4) + ((c3[1] & 0xf0) >> 4);
                    c4[2] = ((c3[1] & 0x0f) << 2) + ((c3[2] & 0xc0) >> 6);
                    for (int j = 0; j < i + 1; j++) result += chars[c4[j]];
                    while (i++ < 3) result += '=';
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "base64_decode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                const std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
                std::string result;
                int i = 0;
                unsigned char c4[4], c3[3];
                for (char ch : input) {
                    if (ch == '=') break;
                    auto pos = chars.find(ch);
                    if (pos == std::string::npos) continue;
                    c4[i++] = (unsigned char)pos;
                    if (i == 4) {
                        c3[0] = (c4[0] << 2) + ((c4[1] & 0x30) >> 4);
                        c3[1] = ((c4[1] & 0xf) << 4) + ((c4[2] & 0x3c) >> 2);
                        c3[2] = ((c4[2] & 0x3) << 6) + c4[3];
                        for (int j = 0; j < 3; j++) result += (char)c3[j];
                        i = 0;
                    }
                }
                if (i) {
                    for (int j = i; j < 4; j++) c4[j] = 0;
                    c3[0] = (c4[0] << 2) + ((c4[1] & 0x30) >> 4);
                    c3[1] = ((c4[1] & 0xf) << 4) + ((c4[2] & 0x3c) >> 2);
                    for (int j = 0; j < i - 1; j++) result += (char)c3[j];
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "hex_encode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                std::string result;
                for (unsigned char c : input) {
                    char buf[4]; snprintf(buf, sizeof(buf), "%02x", static_cast<unsigned>(c));
                    result += buf;
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "hex_decode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                std::string result;
                for (size_t i = 0; i + 1 < input.size(); i += 2) {
                    unsigned int hex_byte = 0;
                    for (int j = 0; j < 2; j++) {
                        char ch = input[i + static_cast<size_t>(j)];
                        hex_byte <<= 4;
                        if (ch >= '0' && ch <= '9') hex_byte |= static_cast<unsigned>(ch - '0');
                        else if (ch >= 'a' && ch <= 'f') hex_byte |= static_cast<unsigned>(ch - 'a' + 10);
                        else if (ch >= 'A' && ch <= 'F') hex_byte |= static_cast<unsigned>(ch - 'A' + 10);
                    }
                    result += static_cast<char>(hex_byte);
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "url_encode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                std::string result;
                for (unsigned char c : input) {
                    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') result += c;
                    else { char buf[4]; snprintf(buf, sizeof(buf), "%%%02X", static_cast<unsigned>(c)); result += buf; }
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "url_decode") {
            if (args.size() >= 1) {
                std::string input = getStringValue(args[0]);
                std::string result;
                for (size_t i = 0; i < input.size(); i++) {
                    if (input[i] == '%' && i + 2 < input.size()) {
                        unsigned int hex_byte = 0;
                        for (int j = 0; j < 2; j++) {
                            char ch = input[i + 1 + static_cast<size_t>(j)];
                            hex_byte <<= 4;
                            if (ch >= '0' && ch <= '9') hex_byte |= static_cast<unsigned>(ch - '0');
                            else if (ch >= 'a' && ch <= 'f') hex_byte |= static_cast<unsigned>(ch - 'a' + 10);
                            else if (ch >= 'A' && ch <= 'F') hex_byte |= static_cast<unsigned>(ch - 'A' + 10);
                        }
                        result += static_cast<char>(hex_byte); i += 2;
                    } else if (input[i] == '+') result += ' ';
                    else result += input[i];
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }

        // ===================== THREADING MODULE =====================
    // ── from main.cpp lines 9120–9256 ──────────────────────────────────────────
        // ===================== COLLECTIONS MODULE =====================
        if (name == "Counter") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                auto* result = new Object((Runnable*)runner, "map", Type::LIST);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::string key = getStringValue(it->second);
                                auto existing = result->container->find(key);
                                if (existing != result->container->end()) {
                                    existing->second = Value((int)(bigint_to_i64(existing->second.value.i) + 1));
                                } else {
                                    result->set(key, Value(1));
                                }
                            }
                        }
                    }
                }
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "Set") {
            auto* result = new Object((Runnable*)runner, "set", Type::LIST);
            result->set("__type__", makeStringValue("set"));
            int idx = 0;
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        std::set<std::string> seen;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::string sv = getStringValue(it->second);
                                if (seen.find(sv) == seen.end()) {
                                    seen.insert(sv);
                                    result->set(std::to_string(idx++), it->second);
                                }
                            }
                        }
                    }
                }
            }
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "deque" || name == "OrderedDict" || name == "defaultdict") {
            // Deque/OrderedDict/defaultdict: return a list/map (simplified)
            auto* result = new Object((Runnable*)runner, "list", Type::LIST);
            result->set("__len__", Value(0));
            return Value((Collectable*)result);
        }

        if (name == "any") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && isTruthy(it->second)) return Value(true);
                        }
                    }
                }
            }
            return Value(false);
        }
        if (name == "all") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && !isTruthy(it->second)) return Value(false);
                        }
                    }
                }
            }
            return Value(true);
        }
        if (name == "exit" || name == "quit") {
            int code = (args.size() >= 1) ? (int)bigint_to_i64(args[0].value.i) : 0;
            std::exit(code);
            return NONE_VALUE;
        }
        if (name == "open") {
            // open(filename, mode) - returns file handle as map
            if (args.size() >= 1) {
                std::string filename = getStringValue(args[0]);
                std::string mode = (args.size() >= 2) ? getStringValue(args[1]) : "r";
                auto* fobj = new Object((Runnable*)runner, "file", Type::LIST);
                fobj->set("name", makeStringValue(filename));
                fobj->set("mode", makeStringValue(mode));
                if (mode == "r") {
                    std::ifstream f(filename);
                    if (f.good()) {
                        std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
                        fobj->set("content", makeStringValue(content));
                        fobj->set("open", Value(true));
                    } else {
                        fobj->set("open", Value(false));
                    }
                } else {
                    fobj->set("content", makeStringValue(""));
                    fobj->set("open", Value(true));
                }
                return Value((Collectable*)fobj);
            }
            return NONE_VALUE;
        }
        if (name == "chr") {
            if (args.size() >= 1) {
                int code = (int)bigint_to_i64(args[0].value.i);
                return makeStringValue(std::string(1, static_cast<char>(code)));
            }
            return makeStringValue("");
        }
        if (name == "ord") {
            if (args.size() >= 1) {
                std::string s = getStringValue(args[0]);
                if (!s.empty()) return Value((int)(unsigned char)s[0]);
            }
            return Value(0);
        }
    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

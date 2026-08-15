#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/string.cpp
// String ops, regex, NLP, HTML strip
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_string() is called from NythonExecutor::callBuiltin().
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
#include "builtins/string.hpp"

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
// dispatch_string
// ════════════════════════════════════════════════════════════════════════════════

// ── UTF-8 index helpers ──────────────────────────────────────────────────────
// len() counts characters, but string_slice() and string_find() worked in bytes.
// Mixing them silently corrupted non-ASCII text: string_slice(s, 0, len(s)) did
// not round-trip, and a slice could end mid-character, producing invalid UTF-8.
// These convert between character and byte offsets so every string builtin
// speaks the same units.
static inline bool ny_u8_is_cont(unsigned char c) { return (c & 0xC0) == 0x80; }

static size_t ny_u8_chars(const std::string& s) {
    size_t n = 0;
    for (unsigned char c : s) if (!ny_u8_is_cont(c)) n++;
    return n;
}

// Character index -> byte offset. Clamped to the end of the string.
static size_t ny_u8_byte_at(const std::string& s, size_t char_idx) {
    size_t chars = 0, i = 0;
    while (i < s.size()) {
        if (!ny_u8_is_cont((unsigned char)s[i])) {
            if (chars == char_idx) return i;
            chars++;
        }
        i++;
    }
    return s.size();
}

// Byte offset -> character index.
static size_t ny_u8_char_at(const std::string& s, size_t byte_idx) {
    size_t chars = 0;
    for (size_t i = 0; i < s.size() && i < byte_idx; i++)
        if (!ny_u8_is_cont((unsigned char)s[i])) chars++;
    return chars;
}

Value dispatch_string(NythonExecutor& E,
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
    // ── from main.cpp lines 3590–3677 ──────────────────────────────────────────
        // NYTORCH NLP: TEXT PROCESSING BUILTINS
        // =====================================================================
        if (name == "text_tokenize") {
            // text_tokenize(text, lowercase=true) -> list of token strings
            if (!args.empty()) {
                std::string txt = getStringValue(args[0]);
                bool lower = (args.size()<2) || isTruthy(args[1]);
                if (lower) { for (auto& c : txt) c = (char)std::tolower((unsigned char)c); }
                auto* lst = new Container((Runnable*)runner, Type::LIST);
                int idx=0; std::string tok;
                for (size_t i=0; i<=txt.size(); i++) {
                    char c=(i<txt.size())?txt[i]:' ';
                    if (std::isalnum((unsigned char)c)||c=='\'') tok+=c;
                    else if (!tok.empty()) { (*lst->container)[std::to_string(idx++)]=makeStringValue(tok); tok=""; }
                }
                (*lst->container)["__len__"]=Value(idx);
                return Value((Collectable*)lst);
            }
            return NONE_VALUE;
        }
        if (name == "text_ngrams") {
            // text_ngrams(tokens_list, n) -> list of ngram strings
            if (args.size()>=2 && args[0].isCollectable()) {
                auto* tokens=dynamic_cast<Container*>(args[0].value.gc);
                int n=(int)bigint_to_i64(args[1].value.i);
                if (!tokens||!tokens->container) return NONE_VALUE;
                auto li=tokens->container->find("__len__"); int len=(li!=tokens->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                auto* out=new Container((Runnable*)runner,Type::LIST);
                int idx=0;
                for (int i=0;i+n<=len;i++) {
                    std::string gram;
                    for (int j=0;j<n;j++) {
                        auto it=tokens->container->find(std::to_string(i+j));
                        if (j>0) gram+=" ";
                        gram+=(it!=tokens->container->end())?getStringValue(it->second):"";
                    }
                    (*out->container)[std::to_string(idx++)]=makeStringValue(gram);
                }
                (*out->container)["__len__"]=Value(idx);
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "text_char_ids") {
            // text_char_ids(text) -> tensor of ASCII int values
            if (!args.empty()) {
                std::string txt=getStringValue(args[0]);
                auto* t=new Container((Runnable*)runner,Type::LIST);
                (*t->container)["__len__"]=Value((int)txt.size());
                for (size_t i=0;i<txt.size();i++) (*t->container)[std::to_string(i)]=Value((int)(unsigned char)txt[i]);
                return Value((Collectable*)t);
            }
            return NONE_VALUE;
        }
        if (name == "text_from_ids") {
            // text_from_ids(tensor) -> string
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return makeStringValue("");
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                std::string result; result.reserve((size_t)n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); result+=(char)((it!=t->container->end())?(int)bigint_to_i64(it->second.value.i):0); }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "text_bow") {
            // text_bow(tokens_list, vocab_list) -> count tensor
            if (args.size()>=2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* toks=dynamic_cast<Container*>(args[0].value.gc);
                auto* vocab=dynamic_cast<Container*>(args[1].value.gc);
                if (!toks||!vocab||!toks->container||!vocab->container) return NONE_VALUE;
                auto vli=vocab->container->find("__len__"); int vn=(int)bigint_to_i64(vli->second.value.i);
                auto tli=toks->container->find("__len__"); int tn=(int)bigint_to_i64(tli->second.value.i);
                std::vector<double> counts((size_t)vn,0.0);
                for (int ti=0;ti<tn;ti++) {
                    auto it=toks->container->find(std::to_string(ti));
                    if (it==toks->container->end()) continue;
                    std::string tok=getStringValue(it->second);
                    for (int vi=0;vi<vn;vi++) { auto vit=vocab->container->find(std::to_string(vi)); if(vit!=vocab->container->end()&&getStringValue(vit->second)==tok) counts[(size_t)vi]+=1.0; }
                }
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(vn);
                for (int i=0;i<vn;i++) (*out->container)[std::to_string(i)]=Value(counts[(size_t)i]);
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 4806–4857 ──────────────────────────────────────────
        // ===================== FIXED REGEX =====================
        if (name == "regex_match" || name == "re_match") {
            if (args.size() >= 2) {
                try {
                    std::regex re(getStringValue(args[0]));
                    std::string input = getStringValue(args[1]);
                    std::smatch m;
                    if (std::regex_search(input, m, re)) return makeStringValue(m[0].str());
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "regex_replace" || name == "re_sub") {
            if (args.size() >= 3) {
                try {
                    std::regex re(getStringValue(args[0]));
                    return makeStringValue(std::regex_replace(getStringValue(args[2]), re, getStringValue(args[1])));
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "regex_findall" || name == "re_findall") {
            if (args.size() >= 2) {
                try {
                    std::regex re(getStringValue(args[0]));
                    std::string input = getStringValue(args[1]);
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    auto begin = std::sregex_iterator(input.begin(), input.end(), re);
                    for (auto it = begin; it != std::sregex_iterator(); ++it)
                        result->set(std::to_string(idx++), makeStringValue((*it)[0].str()));
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "regex_split" || name == "re_split") {
            if (args.size() >= 2) {
                try {
                    std::regex re(getStringValue(args[0]));
                    std::string input = getStringValue(args[1]);
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    std::sregex_token_iterator it(input.begin(), input.end(), re, -1), end;
                    for (; it != end; ++it) result->set(std::to_string(idx++), makeStringValue(it->str()));
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                } catch (...) {}
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 6951–7038 ──────────────────────────────────────────
        if (name == "http_get") {
            std::string url = getStringValue(args.empty() ? Value() : args[0]);
            return makeStringValue(ny_http::get(url));
        }
        // ── http_post(url, body, content_type) ───────────────────────────────────
        if (name == "http_post") {
            std::string url  = args.size() > 0 ? getStringValue(args[0]) : "";
            std::string body = args.size() > 1 ? getStringValue(args[1]) : "";
            std::string ct   = args.size() > 2 ? getStringValue(args[2]) : "application/json";
            return makeStringValue(ny_http::post(url, body, ct));
        }
        // ── file_read(path) ──────────────────────────────────────────────────────
        if (name == "load_text" || name == "read_text") {
            std::string path = args.empty() ? "" : getStringValue(args[0]);
            std::ifstream f(path);
            if (!f.is_open()) return makeStringValue("");
            std::string content_str((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
            return makeStringValue(content_str);
        }
        // ── file_write(path, content) ────────────────────────────────────────────
        if (name == "save_text" || name == "write_text") {
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::string content_str = getStringValue(args[1]);
                std::ofstream f(path);
                if (!f.is_open()) return Value(false);
                f << content_str;
                return Value(true);
            }
            return Value(false);
        }
        // ── file_append(path, content) ───────────────────────────────────────────
        if (name == "append_text") {
            if (args.size() >= 2) {
                std::ofstream f(getStringValue(args[0]), std::ios::app);
                if (!f.is_open()) return Value(false);
                f << getStringValue(args[1]);
                return Value(true);
            }
            return Value(false);
        }
        // ── file_exists(path) ────────────────────────────────────────────────────
        if (name == "path_exists") {
            if (!args.empty()) {
                std::ifstream f(getStringValue(args[0]));
                return Value(f.good());
            }
            return Value(false);
        }
        // ── file_list(dir) ───────────────────────────────────────────────────────
        if (name == "list_dir") {
            std::string dir = args.empty() ? "." : getStringValue(args[0]);
            auto* lst = new Container((Runnable*)runner, Type::LIST);
            int idx = 0;
            for (const auto& entry : ny_fs::listdir(dir))
                (*lst->container)[std::to_string(idx++)] = makeStringValue(entry);
            (*lst->container)["__len__"] = Value(idx);
            return Value((Collectable*)lst);
        }
        // ── string_split(s, delim) ───────────────────────────────────────────────
    // ── from main.cpp lines 7039–7561 ──────────────────────────────────────────
        if (name == "string_split") {
            std::string s = args.empty() ? "" : getStringValue(args[0]);
            std::string delim = args.size() > 1 ? getStringValue(args[1]) : " ";
            auto* obj = new Object((Runnable*)runner, "list", Type::LIST);
            int idx = 0;
            auto addItem = [&](const std::string& item) {
                obj->set(std::to_string(idx++), makeStringValue(item));
            };
            if (delim.empty()) {
                for (char c : s) addItem(std::string(1, c));
            } else {
                size_t prev = 0, pos;
                while ((pos = s.find(delim, prev)) != std::string::npos) {
                    addItem(s.substr(prev, pos - prev));
                    prev = pos + delim.size();
                }
                addItem(s.substr(prev));
            }
            obj->set("__len__", Value(idx));
            return Value((Collectable*)obj);
        }
        // ── string_join(list, delim) ─────────────────────────────────────────────
        if (name == "string_join") {
            std::string delim = args.size() > 1 ? getStringValue(args[1]) : "";
            if (!args.empty() && args[0].isCollectable()) {
                auto* lst = dynamic_cast<Container*>(args[0].value.gc);
                if (lst && lst->container) {
                    auto li = lst->container->find("__len__");
                    int len = (li != lst->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    std::string result;
                    for (int i = 0; i < len; i++) {
                        if (i > 0) result += delim;
                        auto it = lst->container->find(std::to_string(i));
                        if (it != lst->container->end()) result += getStringValue(it->second);
                    }
                    return makeStringValue(result);
                }
            }
            return makeStringValue("");
        }
        // ── string_replace(s, old, new_s) ───────────────────────────────────────
        if (name == "string_replace") {
            if (args.size() >= 3) {
                std::string s = getStringValue(args[0]);
                std::string from = getStringValue(args[1]);
                std::string to = getStringValue(args[2]);
                if (from.empty()) return makeStringValue(s);
                std::string result; size_t prev = 0, pos;
                while ((pos = s.find(from, prev)) != std::string::npos) {
                    result += s.substr(prev, pos - prev) + to;
                    prev = pos + from.size();
                }
                return makeStringValue(result + s.substr(prev));
            }
            return NONE_VALUE;
        }
        // ── string_contains(s, sub) ──────────────────────────────────────────────
        if (name == "string_contains") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                std::string sub = getStringValue(args[1]);
                return Value(s.find(sub) != std::string::npos);
            }
            return Value(false);
        }
        // ── string_lower(s) ──────────────────────────────────────────────────────
        if (name == "string_lower") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
                return makeStringValue(s);
            }
            return NONE_VALUE;
        }
        // ── string_upper(s) ──────────────────────────────────────────────────────
        if (name == "string_upper") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::toupper(c); });
                return makeStringValue(s);
            }
            return NONE_VALUE;
        }
        // ── string_strip(s) ──────────────────────────────────────────────────────
        if (name == "string_strip") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                auto start = s.find_first_not_of(" \t\n\r\f\v");
                if (start == std::string::npos) return makeStringValue("");
                auto end = s.find_last_not_of(" \t\n\r\f\v");
                return makeStringValue(s.substr(start, end - start + 1));
            }
            return NONE_VALUE;
        }
        // ── string_startswith(s, prefix) ─────────────────────────────────────────
        if (name == "string_startswith") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                std::string pre = getStringValue(args[1]);
                return Value(s.size() >= pre.size() && s.substr(0, pre.size()) == pre);
            }
            return Value(false);
        }
        // ── string_endswith(s, suffix) ───────────────────────────────────────────
        if (name == "string_endswith") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                std::string suf = getStringValue(args[1]);
                return Value(s.size() >= suf.size() && s.substr(s.size() - suf.size()) == suf);
            }
            return Value(false);
        }
        // ── string_format(template, values_list) ─────────────────────────────────
        if (name == "string_format") {
            if (!args.empty()) {
                std::string tmpl = getStringValue(args[0]);
                if (args.size() > 1 && args[1].isCollectable()) {
                    auto* lst = dynamic_cast<Container*>(args[1].value.gc);
                    if (lst && lst->container) {
                        auto li = lst->container->find("__len__");
                        int len = (li != lst->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = lst->container->find(std::to_string(i));
                            std::string val = (it != lst->container->end()) ? getStringValue(it->second) : "";
                            size_t pos = tmpl.find("{}");
                            if (pos != std::string::npos) tmpl.replace(pos, 2, val);
                        }
                    }
                }
                return makeStringValue(tmpl);
            }
            return NONE_VALUE;
        }
        // ── string_count(s, sub) ─────────────────────────────────────────────────
        if (name == "string_count") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                std::string sub = getStringValue(args[1]);
                if (sub.empty()) return Value(0);
                int count = 0; size_t pos = 0;
                while ((pos = s.find(sub, pos)) != std::string::npos) { count++; pos += sub.size(); }
                return Value(count);
            }
            return Value(0);
        }
        // ── string_find(s, sub, start=0) ─────────────────────────────────────────
        if (name == "string_find") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                std::string sub = getStringValue(args[1]);
                int start_ch = (args.size() > 2 && args[2].type == ValueType::INTEGER) ? (int)bigint_to_i64(args[2].value.i) : 0;
                if (start_ch < 0) start_ch = 0;
                size_t pos = s.find(sub, ny_u8_byte_at(s, (size_t)start_ch));
                // Report a CHARACTER index, matching len() and string_slice().
                return Value(pos == std::string::npos ? -1 : (int)ny_u8_char_at(s, pos));
            }
            return Value(-1);
        }
        // ── string_slice(s, start, end) ──────────────────────────────────────────
        if (name == "string_slice") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                int slen = (int)ny_u8_chars(s);   // characters, as len() reports
                int start = (args.size() > 1 && args[1].type == ValueType::INTEGER) ? (int)bigint_to_i64(args[1].value.i) : 0;
                int endp = (args.size() > 2 && args[2].type == ValueType::INTEGER) ? (int)bigint_to_i64(args[2].value.i) : slen;
                if (start < 0) start = std::max(0, slen + start);
                if (endp < 0) endp = std::max(0, slen + endp);
                start = std::min(start, slen); endp = std::min(endp, slen);
                if (endp < start) endp = start;
                size_t b0 = ny_u8_byte_at(s, (size_t)start);
                size_t b1 = ny_u8_byte_at(s, (size_t)endp);
                return makeStringValue(s.substr(b0, b1 - b0));
            }
            return NONE_VALUE;
        }
        // ── json_stringify(value) ────────────────────────────────────────────────
        if (name == "json_stringify") {
            if (!args.empty()) {
                std::function<std::string(const Value&, int)> to_json = [&](const Value& v, int depth) -> std::string {
                    if (depth > 20) return "null";
                    if (isStringValue(v)) {
                        std::string s = getStringValue(v), r = "\"";
                        for (char c : s) {
                            if (c=='"') r+="\\\""; else if (c=='\\') r+="\\\\";
                            else if (c=='\n') r+="\\n"; else if (c=='\r') r+="\\r";
                            else if (c=='\t') r+="\\t"; else r+=c;
                        }
                        return r + "\"";
                    } else if (v.type == ValueType::BOOLEAN) {
                        return v.value.b ? "true" : "false";
                    } else if (v.type == ValueType::NONE) {
                        return "null";
                    } else if (v.type == ValueType::DOUBLE) {
                        std::ostringstream oss; oss << v.value.d; return oss.str();
                    } else if (v.type == ValueType::INTEGER) {
                        return std::to_string(bigint_to_i64(v.value.i));
                    } else if (v.isCollectable()) {
                        auto* obj = dynamic_cast<Container*>(v.value.gc);
                        if (!obj || !obj->container) return "null";
                        auto li = obj->container->find("__len__");
                        bool is_list = (li != obj->container->end());
                        if (is_list) {
                            int len = (int)bigint_to_i64(li->second.value.i);
                            std::string r = "[";
                            for (int i = 0; i < len; i++) {
                                if (i > 0) r += ",";
                                auto it = obj->container->find(std::to_string(i));
                                r += (it != obj->container->end()) ? to_json(it->second, depth+1) : "null";
                            }
                            return r + "]";
                        } else {
                            std::string r = "{"; bool first = true;
                            for (auto& kv : *obj->container) {
                                if (kv.first == "__class__") continue;
                                if (!first) r += ",";
                                r += "\"" + kv.first + "\":" + to_json(kv.second, depth+1);
                                first = false;
                            }
                            return r + "}";
                        }
                    }
                    return "null";
                };
                return makeStringValue(to_json(args[0], 0));
            }
            return makeStringValue("null");
        }
        // ── device_info() ────────────────────────────────────────────────────────
        if (name == "device_info") {
            auto* result = new Container((Runnable*)runner, Type::LIST);
            (*result->container)["cpu_cores"] = Value(std::max(1, (int)std::thread::hardware_concurrency()));
            // nvidia-smi works on both Windows and Linux
            std::string gpu_name;
            FILE* gp = popen("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader", "r");
            if (gp) { char buf[256]; if (fgets(buf, sizeof(buf), gp)) gpu_name = buf; pclose(gp); }
            while (!gpu_name.empty() && (gpu_name.back()=='\n'||gpu_name.back()=='\r'||gpu_name.back()==' ')) gpu_name.pop_back();
            (*result->container)["gpu_available"] = Value(!gpu_name.empty());
            (*result->container)["gpu_name"] = makeStringValue(gpu_name.empty() ? "none" : gpu_name);
            // TPU detection: count /dev/accel* entries (Linux only, portable)
            int tpu = 0;
#ifndef _WIN32
            {
                auto devfiles = ny_fs::listdir("/dev");
                for (auto& f : devfiles)
                    if (f.substr(0, 5) == "accel") tpu++;
            }
#endif
            (*result->container)["tpu_available"] = Value(tpu > 0);
            (*result->container)["tpu_count"] = Value(tpu);
            (*result->container)["backend"] = makeStringValue(!gpu_name.empty() ? "cuda" : "cpu");
            return Value((Collectable*)result);
        }
        // ── time_now() ───────────────────────────────────────────────────────────
        if (name == "time_now") {
            auto now = std::chrono::system_clock::now();
            return Value((double)std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count() / 1000.0);
        }
        // ── time_ms() ────────────────────────────────────────────────────────────
        if (name == "time_ms") {
            return Value((double)std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count());
        }
        // ── process_exec(cmd) ────────────────────────────────────────────────────
        if (name == "process_exec") {
            if (!args.empty()) {
                std::string cmd = getStringValue(args[0]) + " 2>&1";
                FILE* pipe = popen(cmd.c_str(), "r");
                if (!pipe) return makeStringValue("");
                std::string result; char buf[4096];
                while (fgets(buf, sizeof(buf), pipe)) result += buf;
                pclose(pipe);
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        // ── env_get(key) ─────────────────────────────────────────────────────────
        if (name == "env_get") {
            if (!args.empty()) {
                const char* val = std::getenv(getStringValue(args[0]).c_str());
                return makeStringValue(val ? val : "");
            }
            return makeStringValue("");
        }
        // ── base64_encode(s) ─────────────────────────────────────────────────────
        if (name == "base64_encode") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                static const char* chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
                std::string result; int val = 0, valb = -6;
                for (unsigned char c : s) {
                    val = (val << 8) + c; valb += 8;
                    while (valb >= 0) { result.push_back(chars[(val>>valb)&0x3F]); valb -= 6; }
                }
                if (valb > -6) result.push_back(chars[((val<<8)>>(valb+8))&0x3F]);
                while (result.size() % 4) result.push_back('=');
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        // ── sha256(s) ────────────────────────────────────────────────────────────
        if (name == "sha256") {
            if (!args.empty())
                return makeStringValue(ny_crypto::sha256(getStringValue(args[0])));
            return makeStringValue("");
        }

        if (name == "zip_list") {
#ifndef _WIN32
            if (!args.empty()) {
                std::string zp = getStringValue(args[0]);
                std::string ezp;
                for (char c : zp) { if (c=='\'') ezp += "'\''"; else ezp += c; }
                FILE* pipe = popen(("unzip -l '" + ezp + "' 2>/dev/null | awk 'NR>3{print $NF}' | head -n -2").c_str(), "r");
                auto* lst = new Object((Runnable*)runner, "list", Type::LIST);
                int idx_ = 0;
                if (pipe) {
                    char buf[1024];
                    while (fgets(buf, sizeof(buf), pipe)) {
                        std::string entry(buf);
                        while (!entry.empty() && (entry.back()=='\n'||entry.back()=='\r'||entry.back()==' ')) entry.pop_back();
                        if (!entry.empty()) lst->set(std::to_string(idx_++), makeStringValue(entry));
                    }
                    pclose(pipe);
                }
                lst->set("__len__", Value(idx_));
                return Value((Collectable*)lst);
            }
#endif
            auto* lst = new Object((Runnable*)runner, "list", Type::LIST);
            lst->set("__len__", Value(0));
            return Value((Collectable*)lst);
        }

        if (name == "zip_extract_text") {
#ifndef _WIN32
            if (args.size() >= 2) {
                std::string zp = getStringValue(args[0]);
                std::string ep = getStringValue(args[1]);
                std::string ezp, eep;
                for (char c : zp) { if (c=='\'') ezp += "'\''"; else ezp += c; }
                for (char c : ep) { if (c=='\'') eep += "'\''"; else eep += c; }
                FILE* pipe = popen(("unzip -p '" + ezp + "' '" + eep + "' 2>/dev/null").c_str(), "r");
                if (pipe) {
                    std::string result; char buf[4096];
                    while (fgets(buf, sizeof(buf), pipe)) result += buf;
                    pclose(pipe);
                    return makeStringValue(result);
                }
            }
#endif
            return makeStringValue("");
        }

        if (name == "html_strip") {
            if (!args.empty()) {
                std::string html = getStringValue(args[0]);
                std::string result; bool in_tag = false;
                for (size_t i = 0; i < html.size(); i++) {
                    if (html[i] == '<') in_tag = true;
                    else if (html[i] == '>') in_tag = false;
                    else if (!in_tag) {
                        if (html[i] == '&') {
                            size_t semi = html.find(';', i);
                            if (semi != std::string::npos && semi - i < 10) { result += ' '; i = semi; }
                            else result += html[i];
                        } else result += html[i];
                    }
                }
                return makeStringValue(result);
            }
            return NONE_VALUE;
        }
        // ── regex_extract(s, pattern) ────────────────────────────────────────────
        if (name == "regex_extract") {
            if (args.size() >= 2) {
                try {
                    std::string s = getStringValue(args[0]);
                    std::regex re(getStringValue(args[1]));
                    auto* lst = new Container((Runnable*)runner, Type::LIST);
                    int idx = 0;
                    std::sregex_iterator it(s.begin(), s.end(), re), end;
                    while (it != end) {
                        (*lst->container)[std::to_string(idx++)] = makeStringValue((*it)[0].str());
                        ++it;
                    }
                    (*lst->container)["__len__"] = Value(idx);
                    return Value((Collectable*)lst);
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        // ── tensor_benchmark(n_iters) ────────────────────────────────────────────
        if (name == "tensor_benchmark") {
            int n = (!args.empty() && args[0].type == ValueType::INTEGER) ? (int)bigint_to_i64(args[0].value.i) : 100;
            auto t0 = std::chrono::high_resolution_clock::now();
            volatile double acc = 0;
            for (int i = 0; i < n; i++) for (int j = 0; j < 64; j++) acc += std::sin(j*0.01)*std::cos(i*0.01);
            auto t1 = std::chrono::high_resolution_clock::now();
            return Value((double)std::chrono::duration_cast<std::chrono::microseconds>(t1-t0).count() / 1000.0);
        }


        if (name == "huber_loss") {
            // Smooth L1 / Huber loss: less sensitive to outliers than MSE
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                double delta = (args.size() >= 3) ? ((args[2].type == ValueType::DOUBLE) ? (double)args[2].value.d : 1.0) : 1.0;
                if (pred && target && pred->container && target->container) {
                    auto pl = pred->container->find("__len__");
                    int len = (pl != pred->container->end()) ? (int)bigint_to_i64(pl->second.value.i) : 0;
                    double total = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = pred->container->find(std::to_string(i));
                        auto ti = target->container->find(std::to_string(i));
                        double pv = (pi != pred->container->end()) ? (double)pi->second.value.d : 0;
                        double tv = (ti != target->container->end()) ? (double)ti->second.value.d : 0;
                        double diff = std::abs(pv - tv);
                        total += (diff <= delta) ? 0.5 * diff * diff : delta * (diff - 0.5 * delta);
                    }
                    return Value(total / len);
                }
            }
            return Value(0.0);
        }
        if (name == "multi_head_attention") {
            // multi_head_attention(Q, K, V, d_model, num_heads) -> output
            // Simplified: splits Q/K/V into heads, runs attention, concatenates
            if (args.size() >= 5 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* Q = dynamic_cast<Container*>(args[0].value.gc);
                auto* K = dynamic_cast<Container*>(args[1].value.gc);
                auto* V = dynamic_cast<Container*>(args[2].value.gc);
                int d_model = (int)bigint_to_i64(args[3].value.i);
                int num_heads = (int)bigint_to_i64(args[4].value.i);
                if (Q && K && V && Q->container && K->container && V->container && num_heads > 0) {
                    int d_k = d_model / num_heads;
                    auto kl = K->container->find("__len__");
                    int k_total = (kl != K->container->end()) ? (int)bigint_to_i64(kl->second.value.i) : 0;
                    int seq_len = k_total / d_model;
                    Object* output = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int out_idx = 0;
                    for (int h = 0; h < num_heads; h++) {
                        // Extract head slice from Q
                        double scale = 1.0 / std::sqrt((double)d_k);
                        // Compute attention for this head
                        std::vector<double> scores(seq_len);
                        double max_s = -1e308;
                        for (int s = 0; s < seq_len; s++) {
                            double dot = 0;
                            for (int d = 0; d < d_k; d++) {
                                auto qi = Q->container->find(std::to_string(h * d_k + d));
                                auto ki = K->container->find(std::to_string(s * d_model + h * d_k + d));
                                double qv = (qi != Q->container->end()) ? (double)qi->second.value.d : 0;
                                double kv = (ki != K->container->end()) ? (double)ki->second.value.d : 0;
                                dot += qv * kv;
                            }
                            scores[s] = dot * scale;
                            if (scores[s] > max_s) max_s = scores[s];
                        }
                        double sum_e = 0;
                        for (int s = 0; s < seq_len; s++) { scores[s] = std::exp(scores[s] - max_s); sum_e += scores[s]; }
                        for (int s = 0; s < seq_len; s++) scores[s] /= sum_e;
                        for (int d = 0; d < d_k; d++) {
                            double sum = 0;
                            for (int s = 0; s < seq_len; s++) {
                                auto vi = V->container->find(std::to_string(s * d_model + h * d_k + d));
                                double vv = (vi != V->container->end()) ? (double)vi->second.value.d : 0;
                                sum += scores[s] * vv;
                            }
                            output->set(std::to_string(out_idx++), Value(sum));
                        }
                    }
                    output->set("__len__", Value(out_idx));
                    return Value((Collectable*)output);
                }
            }
            return NONE_VALUE;
        }
        if (name == "gelu") {
            // GELU activation: x * 0.5 * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double c = 0.7978845608; // sqrt(2/pi)
                return Value(0.5 * x * (1.0 + std::tanh(c * (x + 0.044715 * x * x * x))));
            }
            return Value(0.0);
        }
        if (name == "silu" || name == "swish") {
            // SiLU/Swish: x * sigmoid(x)
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x / (1.0 + std::exp(-x)));
            }
            return Value(0.0);
        }
        if (name == "elu") {
            // ELU: x if x>0, alpha*(exp(x)-1) if x<=0
            double alpha = (args.size() >= 2) ? ((args[1].type == ValueType::DOUBLE) ? (double)args[1].value.d : 1.0) : 1.0;
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x > 0 ? x : alpha * (std::exp(x) - 1.0));
            }
            return Value(0.0);
        }
        if (name == "layer_norm") {
            // Layer normalization (same as batch_norm but explicitly named)
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double mean = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        mean += (it != t->container->end()) ? (double)it->second.value.d : 0;
                    }
                    mean /= len;
                    double var_v = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_v += (v - mean) * (v - mean);
                    }
                    var_v /= len;
                    double std_v = std::sqrt(var_v + 1e-5);
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value((v - mean) / std_v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 8358–8451 ──────────────────────────────────────────
        if (name == "re_match") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string text = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    std::smatch m;
                    if (std::regex_match(text, m, re)) {
                        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (size_t i = 0; i < m.size(); i++) result->set(std::to_string(i), makeStringValue(m[i].str()));
                        result->set("__len__", Value((int)m.size()));
                        return Value((Collectable*)result);
                    }
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "re_search") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string text = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    std::smatch m;
                    if (std::regex_search(text, m, re)) {
                        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (size_t i = 0; i < m.size(); i++) result->set(std::to_string(i), makeStringValue(m[i].str()));
                        result->set("__len__", Value((int)m.size()));
                        return Value((Collectable*)result);
                    }
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "re_findall") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string text = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    auto begin = std::sregex_iterator(text.begin(), text.end(), re);
                    auto end = std::sregex_iterator();
                    for (auto it = begin; it != end; ++it) {
                        result->set(std::to_string(idx++), makeStringValue((*it)[0].str()));
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "re_replace") {
            if (args.size() >= 3) {
                std::string pattern = getStringValue(args[0]);
                std::string replacement = getStringValue(args[1]);
                std::string text = getStringValue(args[2]);
                try {
                    std::regex re(pattern);
                    return makeStringValue(std::regex_replace(text, re, replacement));
                } catch (...) {}
            }
            return args.size() >= 3 ? args[2] : NONE_VALUE;
        }
        if (name == "re_split") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string text = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    std::sregex_token_iterator it(text.begin(), text.end(), re, -1);
                    std::sregex_token_iterator end;
                    for (; it != end; ++it) result->set(std::to_string(idx++), makeStringValue(it->str()));
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                } catch (...) {}
            }
            return NONE_VALUE;
        }
        if (name == "re_test") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string text = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    return Value(std::regex_search(text, re));
                } catch (...) {}
            }
            return Value(false);
        }


    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

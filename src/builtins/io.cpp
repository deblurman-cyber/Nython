#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/io.cpp
// File I/O (handle + path), KV store, ZIP
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_io() is called from NythonExecutor::callBuiltin().
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
#include "builtins/io.hpp"

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
// dispatch_io
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_io(NythonExecutor& E,
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
    // ── from main.cpp lines 2821–2926 ──────────────────────────────────────────
        // =====================================================================
        // NYTORCH AGENT I/O: KEY-VALUE STORE (JSON-backed flat file database)
        // =====================================================================
        if (name == "kv_set") {
            // kv_set(store_file, key, value_str) -> bool
            if (args.size() >= 3) {
                std::string store = getStringValue(args[0]);
                std::string key   = getStringValue(args[1]);
                std::string val   = getStringValue(args[2]);
                // Load existing entries
                std::map<std::string,std::string> db;
                std::ifstream fin(store);
                if (fin.is_open()) {
                    std::string line;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('\x1F');
                        if (eq != std::string::npos) db[line.substr(0,eq)] = line.substr(eq+1);
                    }
                    fin.close();
                }
                db[key] = val;
                std::ofstream fout(store);
                for (auto& kv : db) fout << kv.first << '\x1F' << kv.second << '\n';
                return Value(true);
            }
            return Value(false);
        }
        if (name == "kv_get") {
            // kv_get(store_file, key) -> string or none
            if (args.size() >= 2) {
                std::string store = getStringValue(args[0]);
                std::string key   = getStringValue(args[1]);
                std::ifstream fin(store);
                if (fin.is_open()) {
                    std::string line;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('\x1F');
                        if (eq != std::string::npos && line.substr(0,eq) == key)
                            return makeStringValue(line.substr(eq+1));
                    }
                }
            }
            return NONE_VALUE;
        }
        if (name == "kv_del") {
            // kv_del(store_file, key) -> bool
            if (args.size() >= 2) {
                std::string store = getStringValue(args[0]);
                std::string key   = getStringValue(args[1]);
                std::map<std::string,std::string> db;
                std::ifstream fin(store);
                if (fin.is_open()) {
                    std::string line;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('\x1F');
                        if (eq != std::string::npos) db[line.substr(0,eq)] = line.substr(eq+1);
                    }
                    fin.close();
                }
                bool erased = (db.erase(key) > 0);
                std::ofstream fout(store);
                for (auto& kv : db) fout << kv.first << '\x1F' << kv.second << '\n';
                return Value(erased);
            }
            return Value(false);
        }
        if (name == "kv_keys") {
            // kv_keys(store_file) -> list of key strings
            if (!args.empty()) {
                std::string store = getStringValue(args[0]);
                auto* lst = new Container((Runnable*)runner, Type::LIST);
                int idx = 0;
                std::ifstream fin(store);
                if (fin.is_open()) {
                    std::string line;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('\x1F');
                        if (eq != std::string::npos) {
                            (*lst->container)[std::to_string(idx++)] = makeStringValue(line.substr(0,eq));
                        }
                    }
                }
                (*lst->container)["__len__"] = Value(idx);
                return Value((Collectable*)lst);
            }
            return NONE_VALUE;
        }
        if (name == "kv_all") {
            // kv_all(store_file) -> map {key: value}
            if (!args.empty()) {
                std::string store = getStringValue(args[0]);
                auto* obj = new Object((Runnable*)runner, "map", Type::MAP);
                std::ifstream fin(store);
                if (fin.is_open()) {
                    std::string line;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('\x1F');
                        if (eq != std::string::npos)
                            obj->set(line.substr(0,eq), makeStringValue(line.substr(eq+1)));
                    }
                }
                return Value((Collectable*)obj);
            }
            return NONE_VALUE;
        }
        // =====================================================================
    // ── from main.cpp lines 4989–5195 ──────────────────────────────────────────
        // ===================== COMPLETE I/O MODULE =====================
        if (name == "input") {
            // input(prompt) -> reads line from stdin
            if (!args.empty()) {
                std::string prompt = getStringValue(args[0]);
                std::cout << prompt << std::flush;
            }
            std::string line;
            if (std::getline(std::cin, line)) {
                return makeStringValue(line);
            }
            return makeStringValue("");
        }
        if (name == "file_open" || name == "open") {
            if (args.size() >= 1) {
                std::string path = getStringValue(args[0]);
                std::string mode = (args.size() >= 2) ? getStringValue(args[1]) : "r";
                FILE* f = fopen(path.c_str(), mode.c_str());
                if (f) {
                    int handle = next_file_handle++;
                    file_handles[handle] = f;
                    return Value(handle);
                }
            }
            return Value(-1);
        }
        if (name == "file_close" || name == "fclose") {
            if (args.size() >= 1) {
                int handle = static_cast<int>(bigint_to_i64(args[0].value.i));
                auto it = file_handles.find(handle);
                if (it != file_handles.end()) {
                    fclose(it->second);
                    file_handles.erase(it);
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "file_read" || name == "fread") {
            if (args.size() >= 1) {
                int handle = static_cast<int>(bigint_to_i64(args[0].value.i));
                FILE* f = (file_handles.count(handle)) ? file_handles[handle] : nullptr;
                if (f) {
                    int size = (args.size() >= 2) ? static_cast<int>(bigint_to_i64(args[1].value.i)) : -1;
                    if (size < 0) {
                        // Read all
                        long pos = ftell(f);
                        fseek(f, 0, SEEK_END);
                        long fsize = ftell(f);
                        fseek(f, pos, SEEK_SET);
                        std::string content(static_cast<size_t>(fsize - pos), '\0');
                        size_t r = fread(&content[0], 1, content.size(), f);
                        content.resize(r);
                        return makeStringValue(content);
                    } else {
                        std::string buf(static_cast<size_t>(size), '\0');
                        size_t r = fread(&buf[0], 1, static_cast<size_t>(size), f);
                        buf.resize(r);
                        return makeStringValue(buf);
                    }
                }
            }
            return makeStringValue("");
        }
        if (name == "file_write" || name == "fwrite") {
            if (args.size() >= 2) {
                int handle = static_cast<int>(bigint_to_i64(args[0].value.i));
                FILE* f = (file_handles.count(handle)) ? file_handles[handle] : nullptr;
                std::string data = getStringValue(args[1]);
                if (f) {
                    size_t written = fwrite(data.c_str(), 1, data.size(), f);
                    return Value(static_cast<int>(written));
                }
            }
            return Value(-1);
        }
        if (name == "file_readline" || name == "freadline") {
            if (args.size() >= 1) {
                int handle = static_cast<int>(bigint_to_i64(args[0].value.i));
                FILE* f = (file_handles.count(handle)) ? file_handles[handle] : nullptr;
                if (f) {
                    char buf[8192];
                    if (fgets(buf, sizeof(buf), f)) {
                        std::string line(buf);
                        // Remove trailing newline
                        while (!line.empty() && (line.back() == '\n' || line.back() == '\r'))
                            line.pop_back();
                        return makeStringValue(line);
                    }
                }
            }
            return NONE_VALUE;
        }
        if (name == "file_readlines" || name == "readlines") {
            // Read all lines from a file path
            if (args.size() >= 1) {
                std::string path = getStringValue(args[0]);
                std::ifstream file(path);
                if (file.is_open()) {
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    std::string line;
                    while (std::getline(file, line)) {
                        result->set(std::to_string(idx++), makeStringValue(line));
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "file_writelines" || name == "writelines") {
            // Write list of lines to file
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::ofstream file(path);
                if (file.is_open() && args[1].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[1].value.gc);
                    if (cont && cont->container) {
                        auto li = cont->container->find("__len__");
                        int len = (li != cont->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end())
                                file << getStringValue(it->second) << "\n";
                        }
                    }
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "file_append" || name == "append_file") {
            // Append string to file
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::string data = getStringValue(args[1]);
                std::ofstream file(path, std::ios::app);
                if (file.is_open()) {
                    file << data;
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "file_size") {
            if (args.size() >= 1) {
                std::string path = getStringValue(args[0]);
                struct stat st;
                if (stat(path.c_str(), &st) == 0)
                    return Value(static_cast<int>(st.st_size));
            }
            return Value(-1);
        }
        if (name == "file_delete" || name == "remove_file") {
            if (args.size() >= 1) {
                return Value(remove(getStringValue(args[0]).c_str()) == 0);
            }
            return Value(false);
        }
        if (name == "file_rename") {
            if (args.size() >= 2) {
                return Value(rename(getStringValue(args[0]).c_str(), getStringValue(args[1]).c_str()) == 0);
            }
            return Value(false);
        }
        if (name == "file_copy") {
            if (args.size() >= 2) {
                std::ifstream src(getStringValue(args[0]), std::ios::binary);
                std::ofstream dst(getStringValue(args[1]), std::ios::binary);
                if (src.is_open() && dst.is_open()) {
                    dst << src.rdbuf();
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "print_to" || name == "fprint") {
            // Print to file: print_to(path, data)
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::string data = getStringValue(args[1]);
                std::ofstream file(path, std::ios::app);
                if (file.is_open()) {
                    file << data << "\n";
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "eprint" || name == "print_err") {
            // Print to stderr
            for (size_t i = 0; i < args.size(); i++) {
                if (i > 0) std::cerr << " ";
                if (args[i].type == ValueType::USERDATA)
                    std::cerr << getStringValue(args[i]);
                else
                    std::cerr << args[i].toString();
            }
            std::cerr << std::endl;
            return NONE_VALUE;
        }
        if (name == "flush") {
            std::cout << std::flush;
            return NONE_VALUE;
        }
        // ===================== LINUX SHELL COMMANDS =====================

    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

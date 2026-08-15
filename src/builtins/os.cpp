#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/os.cpp
// Filesystem, shell, OS env
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_os() is called from NythonExecutor::callBuiltin().
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
#include "builtins/os.hpp"

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
// dispatch_os
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_os(NythonExecutor& E,
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
    // ── from main.cpp lines 3256–3381 ──────────────────────────────────────────
        if (name == "fs_mkdirs") {
            // fs_mkdirs(path) -> bool — create directory tree
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                return Value(ny_fs::mkdirs(path));
            }
            return Value(false);
        }
        if (name == "fs_stat") {
            // fs_stat(path) -> {size, is_file, is_dir, exists}
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                auto* obj = new Object((Runnable*)runner, "map", Type::MAP);
                struct stat buf{};
                if (stat(path.c_str(), &buf) == 0) {
                    obj->set("exists",  Value(true));
                    obj->set("size",    Value((int)buf.st_size));
                    obj->set("is_file", Value((bool)S_ISREG(buf.st_mode)));
                    obj->set("is_dir",  Value((bool)S_ISDIR(buf.st_mode)));
                } else {
                    obj->set("exists",  Value(false));
                    obj->set("size",    Value(0));
                    obj->set("is_file", Value(false));
                    obj->set("is_dir",  Value(false));
                }
                return Value((Collectable*)obj);
            }
            return NONE_VALUE;
        }
        if (name == "fs_walk") {
            // fs_walk(dir) -> list of file paths (shallow)
            if (!args.empty()) {
                std::string dir = getStringValue(args[0]);
                auto* lst = new Container((Runnable*)runner, Type::LIST);
                int idx = 0;
                DIR* d = opendir(dir.c_str());
                if (d) {
                    struct dirent* e;
                    while ((e = readdir(d)) != nullptr) {
                        std::string nm = e->d_name;
                        if (nm == "." || nm == "..") continue;
                        (*lst->container)[std::to_string(idx++)] = makeStringValue(dir + "/" + nm);
                    }
                    closedir(d);
                }
                (*lst->container)["__len__"] = Value(idx);
                return Value((Collectable*)lst);
            }
            return NONE_VALUE;
        }
        if (name == "path_join") {
            // path_join(a, b, ...) -> joined path
            if (!args.empty()) {
                std::string result = getStringValue(args[0]);
                for (size_t i = 1; i < args.size(); i++) {
                    std::string part = getStringValue(args[i]);
                    if (!result.empty() && result.back() != '/') result += '/';
                    if (!part.empty() && part[0] == '/') result = part;
                    else result += part;
                }
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "path_basename") {
            if (!args.empty()) {
                std::string p = getStringValue(args[0]);
                auto pos = p.rfind('/');
                return makeStringValue(pos == std::string::npos ? p : p.substr(pos+1));
            }
            return makeStringValue("");
        }
        if (name == "path_dirname") {
            if (!args.empty()) {
                std::string p = getStringValue(args[0]);
                auto pos = p.rfind('/');
                return makeStringValue(pos == std::string::npos ? "." : (pos == 0 ? "/" : p.substr(0, pos)));
            }
            return makeStringValue("");
        }
        if (name == "path_ext") {
            if (!args.empty()) {
                std::string p = getStringValue(args[0]);
                auto pos = p.rfind('.');
                return makeStringValue(pos == std::string::npos ? "" : p.substr(pos));
            }
            return makeStringValue("");
        }
        if (name == "read_bytes") {
            // read_bytes(path) -> list of ints (raw bytes)
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream f(path, std::ios::binary);
                if (!f.is_open()) return NONE_VALUE;
                std::vector<unsigned char> bytes(
                    (std::istreambuf_iterator<char>(f)),
                    std::istreambuf_iterator<char>());
                auto* lst = new Container((Runnable*)runner, Type::LIST);
                (*lst->container)["__len__"] = Value((int)bytes.size());
                for (size_t i = 0; i < bytes.size(); i++)
                    (*lst->container)[std::to_string(i)] = Value((int)bytes[i]);
                return Value((Collectable*)lst);
            }
            return NONE_VALUE;
        }
        if (name == "write_bytes") {
            // write_bytes(path, list_of_ints) -> bool
            if (args.size() >= 2 && args[1].isCollectable()) {
                std::string path = getStringValue(args[0]);
                auto* lst = dynamic_cast<Container*>(args[1].value.gc);
                if (!lst || !lst->container) return Value(false);
                auto li = lst->container->find("__len__");
                int n = (li != lst->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                std::ofstream f(path, std::ios::binary);
                if (!f.is_open()) return Value(false);
                for (int i = 0; i < n; i++) {
                    auto it = lst->container->find(std::to_string(i));
                    unsigned char b = (it != lst->container->end()) ? (unsigned char)(int)bigint_to_i64(it->second.value.i) : 0;
                    f.write((char*)&b, 1);
                }
                return Value(true);
            }
            return Value(false);
        }
        // =====================================================================
        // NYTORCH VISION: 2D TENSOR OPS (images stored as flat H*W*C tensors)
    // ── from main.cpp lines 4724–4805 ──────────────────────────────────────────
        // ===================== OS COMMANDS =====================
        if (name == "getcwd") {
            char buf[4096];
            if (::getcwd(buf, sizeof(buf))) return makeStringValue(std::string(buf));
            return makeStringValue(".");
        }
        if (name == "getenv") {
            if (!args.empty()) {
                const char* val = std::getenv(getStringValue(args[0]).c_str());
                if (val) return makeStringValue(std::string(val));
            }
            return NONE_VALUE;
        }
        // system/shell moved to new popen-based handler below
        if (name == "popen" || name == "exec_cmd" || name == "sh") {
            if (!args.empty()) {
                std::string cmd = getStringValue(args[0]);
                std::string result;
                FILE* pipe = ::popen(cmd.c_str(), "r");
                if (pipe) {
                    char buffer[256];
                    while (fgets(buffer, sizeof(buffer), pipe)) result += buffer;
                    ::pclose(pipe);
                    while (!result.empty() && result.back() == '\n') result.pop_back();
                }
                return makeStringValue(result);
            }
            return NONE_VALUE;
        }
        if (name == "listdir" || name == "ls") {
            std::string path = args.empty() ? "." : getStringValue(args[0]);
            Object* result = new Object((Runnable*)runner, "list", Type::LIST);
            int idx = 0;
            for (const auto& entry : ny_fs::listdir(path))
                result->set(std::to_string(idx++), makeStringValue(entry));
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "mkdir") {
            if (!args.empty()) {
                #ifdef _WIN32
                return Value(::_mkdir(getStringValue(args[0]).c_str()) == 0);
                #else
                return Value(::mkdir(getStringValue(args[0]).c_str(), 0755) == 0);
                #endif
            }
            return Value(false);
        }
        if (name == "chdir" || name == "cd") {
            if (!args.empty()) return Value(::chdir(getStringValue(args[0]).c_str()) == 0);
            return Value(false);
        }
        if (name == "path_exists") {
            if (!args.empty()) {
                struct stat st;
                return Value(stat(getStringValue(args[0]).c_str(), &st) == 0);
            }
            return Value(false);
        }
        if (name == "path_isdir") {
            if (!args.empty()) {
                struct stat st;
                if (stat(getStringValue(args[0]).c_str(), &st) == 0) return Value(S_ISDIR(st.st_mode));
            }
            return Value(false);
        }
        if (name == "path_isfile") {
            if (!args.empty()) {
                struct stat st;
                if (stat(getStringValue(args[0]).c_str(), &st) == 0) return Value(S_ISREG(st.st_mode));
            }
            return Value(false);
        }
    // ── from main.cpp lines 5196–5287 ──────────────────────────────────────────
        if (name == "shell" || name == "system" || name == "cmd") {
            if (!args.empty()) {
                std::string command = getStringValue(args[0]);
                FILE* pipe = popen(command.c_str(), "r");
                if (pipe) {
                    std::string result;
                    char buffer[4096];
                    while (fgets(buffer, sizeof(buffer), pipe)) result += buffer;
                    pclose(pipe);
                    // Remove trailing newline
                    while (!result.empty() && (result.back() == '\n' || result.back() == '\r'))
                        result.pop_back();
                    return makeStringValue(result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "ls") {
            std::string path = args.empty() ? "." : getStringValue(args[0]);
            Object* result = new Object((Runnable*)runner, "list", Type::LIST);
            int idx = 0;
            for (const auto& entry : ny_fs::listdir(path))
                result->set(std::to_string(idx++), makeStringValue(entry));
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "cat") {
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream file(path);
                if (file.is_open()) {
                    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
                    return makeStringValue(content);
                }
            }
            return NONE_VALUE;
        }
        if (name == "pwd") {
            char cwd[4096];
            if (getcwd(cwd, sizeof(cwd))) return makeStringValue(std::string(cwd));
            return NONE_VALUE;
        }
        if (name == "mkdir") {
            if (!args.empty())
                return Value(ny_fs::mkdirs(getStringValue(args[0])));
            return Value(false);
        }
        if (name == "write") {
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::string content = getStringValue(args[1]);
                std::ofstream file(path);
                if (file.is_open()) {
                    file << content;
                    file.close();
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "exists") {
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream f(path);
                return Value(f.good());
            }
            return Value(false);
        }
        if (name == "env") {
            if (!args.empty()) {
                const char* val = getenv(getStringValue(args[0]).c_str());
                if (val) return makeStringValue(std::string(val));
            }
            return NONE_VALUE;
        }
        // ===================== AI/ML MODULE (NyTorch) =====================
    // ── from main.cpp lines 8233–8357 ──────────────────────────────────────────
        if (name == "os_getenv") {
            if (args.size() >= 1) {
                const char* val = std::getenv(getStringValue(args[0]).c_str());
                if (val) return makeStringValue(std::string(val));
                if (args.size() >= 2) return args[1]; // default
            }
            return NONE_VALUE;
        }
        if (name == "os_setenv") {
            if (args.size() >= 2) setenv(getStringValue(args[0]).c_str(), getStringValue(args[1]).c_str(), 1);
            return NONE_VALUE;
        }
        if (name == "os_getcwd") {
            char buf[4096];
            if (getcwd(buf, sizeof(buf))) return makeStringValue(std::string(buf));
            return makeStringValue("");
        }
        if (name == "os_listdir") {
            std::string dir = ".";
            if (args.size() >= 1) dir = getStringValue(args[0]);
            auto* result = new Object((Runnable*)runner, "list", Type::LIST);
            int idx = 0;
            for (const auto& entry : ny_fs::listdir(dir))
                result->set(std::to_string(idx++), makeStringValue(entry));
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "os_mkdir") {
            if (args.size() >= 1)
                return Value(ny_fs::mkdirs(getStringValue(args[0])));
            return Value(false);
        }
        if (name == "os_remove") {
            if (args.size() >= 1) return Value(std::remove(getStringValue(args[0]).c_str()) == 0);
            return Value(false);
        }
        if (name == "os_rename") {
            if (args.size() >= 2) return Value(std::rename(getStringValue(args[0]).c_str(), getStringValue(args[1]).c_str()) == 0);
            return Value(false);
        }
        if (name == "os_exists") {
            if (args.size() >= 1) { std::ifstream f(getStringValue(args[0])); return Value(f.good()); }
            return Value(false);
        }
        if (name == "os_isdir") {
            if (args.size() >= 1) {
                struct stat st;
                return Value(stat(getStringValue(args[0]).c_str(), &st) == 0 && S_ISDIR(st.st_mode));
            }
            return Value(false);
        }
        if (name == "os_isfile") {
            if (args.size() >= 1) {
                struct stat st;
                return Value(stat(getStringValue(args[0]).c_str(), &st) == 0 && S_ISREG(st.st_mode));
            }
            return Value(false);
        }
        if (name == "os_exec") {
            if (args.size() >= 1) {
                std::string cmd = getStringValue(args[0]);
                FILE* fp = popen(cmd.c_str(), "r");
                if (fp) {
                    std::string result;
                    char buf[4096];
                    while (fgets(buf, sizeof(buf), fp)) result += buf;
                    pclose(fp);
                    while (!result.empty() && result.back() == '\n') result.pop_back();
                    return makeStringValue(result);
                }
            }
            return makeStringValue("");
        }
        if (name == "os_path_join") {
            std::string result;
            for (size_t i = 0; i < args.size(); i++) {
                if (i > 0) result = ny_fs::join(result, getStringValue(args[i]));
                else        result = getStringValue(args[i]);
            }
            return makeStringValue(result);
        }
        if (name == "os_path_basename") {
            if (args.size() >= 1) {
                std::string p = getStringValue(args[0]);
                size_t pos1 = p.rfind('/');
                size_t pos2 = p.rfind('\\');
                size_t pos = (pos1 == std::string::npos) ? pos2 :
                             (pos2 == std::string::npos) ? pos1 : std::max(pos1, pos2);
                return makeStringValue(pos != std::string::npos ? p.substr(pos + 1) : p);
            }
            return makeStringValue("");
        }
        if (name == "os_path_dirname") {
            if (args.size() >= 1) {
                std::string p = getStringValue(args[0]);
                size_t pos1 = p.rfind('/');
                size_t pos2 = p.rfind('\\');
                size_t pos = (pos1 == std::string::npos) ? pos2 :
                             (pos2 == std::string::npos) ? pos1 : std::max(pos1, pos2);
                return makeStringValue(pos != std::string::npos ? p.substr(0, pos) : ".");
            }
            return makeStringValue("");
        }
        if (name == "os_path_ext") {
            if (args.size() >= 1) {
                std::string p = getStringValue(args[0]);
                auto pos = p.rfind('.');
                return makeStringValue(pos != std::string::npos ? p.substr(pos) : "");
            }
            return makeStringValue("");
        }
        if (name == "os_path_abs") {
            if (args.size() >= 1) {
                char buf[4096];
                if (ny_realpath(getStringValue(args[0]).c_str(), buf)) return makeStringValue(std::string(buf));
            }
            return makeStringValue("");
        }

        // ===================== REGEX MODULE =====================

    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/math.cpp
// Math, RNG, time
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_math() is called from NythonExecutor::callBuiltin().
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
#include "builtins/math.hpp"

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
// dispatch_math
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_math(NythonExecutor& E,
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
    // ── from main.cpp lines 6804–6819 ──────────────────────────────────────────
        // ── Miscellaneous math ─────────────────────────────────────────────────────
        if (name == "softplus") {
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(std::log(1.0 + std::exp(x)));
            }
            return NONE_VALUE;
        }
        if (name == "mish") {
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x * std::tanh(std::log(1.0 + std::exp(x))));
            }
            return NONE_VALUE;
        }

    // ── from main.cpp lines 8105–8139 ──────────────────────────────────────────
        // ===================== TIME MODULE =====================
        if (name == "time_now" || name == "time_timestamp") {
            auto now = std::chrono::system_clock::now();
            auto epoch = now.time_since_epoch();
            auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(epoch).count();
            return Value(static_cast<double>(millis / 1000.0));
        }
        if (name == "time_clock") {
            auto now = std::chrono::high_resolution_clock::now();
            auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
            return Value(static_cast<double>(ns / 1e9));
        }
        if (name == "time_sleep") {
            if (args.size() >= 1) {
                double secs = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                std::this_thread::sleep_for(std::chrono::milliseconds((int)(secs * 1000)));
            }
            return NONE_VALUE;
        }
        if (name == "time_format" || name == "time_date") {
            std::time_t t = std::time(nullptr);
            char buf[64];
            std::string fmt = "%Y-%m-%d %H:%M:%S";
            if (args.size() >= 1) fmt = getStringValue(args[0]);
            std::strftime(buf, sizeof(buf), fmt.c_str(), std::localtime(&t));
            return makeStringValue(std::string(buf));
        }
        if (name == "time_elapsed") {
            static auto start_time = std::chrono::high_resolution_clock::now();
            auto now = std::chrono::high_resolution_clock::now();
            double elapsed = std::chrono::duration<double>(now - start_time).count();
            return Value(static_cast<double>(elapsed));
        }

        // ===================== RANDOM MODULE =====================
    // ── from main.cpp lines 8140–8232 ──────────────────────────────────────────
        if (name == "random_int" || name == "randint") {
            static std::mt19937 rng(std::random_device{}());
            int lo = 0, hi = 100;
            if (args.size() >= 2) { lo = (int)bigint_to_i64(args[0].value.i); hi = (int)bigint_to_i64(args[1].value.i); }
            else if (args.size() == 1) { hi = (int)bigint_to_i64(args[0].value.i); }
            std::uniform_int_distribution<int> dist(lo, hi);
            return Value(dist(rng));
        }
        if (name == "random_float" || name == "uniform") {
            static std::mt19937 rng(std::random_device{}());
            double lo = 0.0, hi = 1.0;
            if (args.size() >= 2) {
                lo = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                hi = (args[1].type == ValueType::DOUBLE) ? static_cast<double>(args[1].value.d) : (double)bigint_to_i64(args[1].value.i);
            }
            std::uniform_real_distribution<double> dist(lo, hi);
            return Value(dist(rng));
        }
        if (name == "random_choice") {
            static std::mt19937 rng(std::random_device{}());
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        if (len > 0) {
                            std::uniform_int_distribution<int> dist(0, len - 1);
                            auto it = cont->container->find(std::to_string(dist(rng)));
                            if (it != cont->container->end()) return it->second;
                        }
                    }
                }
            }
            return NONE_VALUE;
        }
        if (name == "random_shuffle") {
            static std::mt19937 rng(std::random_device{}());
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        std::vector<Value> vals;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) vals.push_back(it->second);
                        }
                        std::shuffle(vals.begin(), vals.end(), rng);
                        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (int i = 0; i < (int)vals.size(); i++) result->set(std::to_string(i), vals[i]);
                        result->set("__len__", Value((int)vals.size()));
                        return Value((Collectable*)result);
                    }
                }
            }
            return NONE_VALUE;
        }
        if (name == "random_sample") {
            static std::mt19937 rng(std::random_device{}());
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                int k = (int)bigint_to_i64(args[1].value.i);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    if (li != cont->container->end()) {
                        int len = (int)bigint_to_i64(li->second.value.i);
                        std::vector<int> indices(len);
                        for (int i = 0; i < len; i++) indices[i] = i;
                        std::shuffle(indices.begin(), indices.end(), rng);
                        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                        int count = std::min(k, len);
                        for (int i = 0; i < count; i++) {
                            auto it = cont->container->find(std::to_string(indices[i]));
                            if (it != cont->container->end()) result->set(std::to_string(i), it->second);
                        }
                        result->set("__len__", Value(count));
                        return Value((Collectable*)result);
                    }
                }
            }
            return NONE_VALUE;
        }
        if (name == "random_seed") {
            // No-op, seeds are per-function static
            return NONE_VALUE;
        }
        if (name == "random_range") {
            return callBuiltin("random_int", args, ctx);
        }

        // ===================== OS MODULE =====================

    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

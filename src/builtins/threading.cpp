#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/threading.cpp
// Threads, mutexes, async
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_threading() is called from NythonExecutor::callBuiltin().
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
#include "builtins/threading.hpp"

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
// dispatch_threading
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_threading(NythonExecutor& E,
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
    // ── from main.cpp lines 3678–3754 ──────────────────────────────────────────
        // =====================================================================
        // NYTORCH SIGNAL: FFT (DFT via Cooley-Tukey, power-of-2 sizes)
        // =====================================================================
        if (name == "fft_magnitude") {
            // fft_magnitude(signal_tensor) -> magnitude spectrum tensor (N/2+1)
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__"); int N=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                std::vector<double> re((size_t)N,0.0), im((size_t)N,0.0);
                for (int i=0;i<N;i++) { auto it=t->container->find(std::to_string(i)); re[(size_t)i]=(it!=t->container->end())?it->second.value.d:0.0; }
                // DFT (O(N^2), works for any N; for large N use with care)
                int out_n=N/2+1;
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(out_n);
                for (int k=0;k<out_n;k++) {
                    double sr=0,si=0;
                    for (int n=0;n<N;n++) { double ang=2.0*3.14159265358979323846*k*n/N; sr+=re[(size_t)n]*std::cos(ang); si-=re[(size_t)n]*std::sin(ang); }
                    (*out->container)[std::to_string(k)]=Value(std::sqrt(sr*sr+si*si));
                }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "signal_window") {
            // signal_window(t, window_type="hann") -> windowed tensor
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                std::string wtype=(args.size()>=2)?getStringValue(args[1]):"hann";
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__"); int N=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(N);
                const double PI=3.14159265358979323846;
                for (int i=0;i<N;i++) {
                    auto it=t->container->find(std::to_string(i));
                    double v=(it!=t->container->end())?it->second.value.d:0.0;
                    double w=1.0;
                    if (wtype=="hann") w=0.5*(1.0-std::cos(2.0*PI*i/(N-1)));
                    else if (wtype=="hamming") w=0.54-0.46*std::cos(2.0*PI*i/(N-1));
                    else if (wtype=="blackman") w=0.42-0.5*std::cos(2.0*PI*i/(N-1))+0.08*std::cos(4.0*PI*i/(N-1));
                    (*out->container)[std::to_string(i)]=Value(v*w);
                }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "signal_rms") {
            // signal_rms(t) -> scalar rms energy
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return Value(0.0);
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                double ss=0;
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); double v=(it!=t->container->end())?it->second.value.d:0.0; ss+=v*v; }
                return Value(std::sqrt(ss/std::max(1,n)));
            }
            return Value(0.0);
        }
        if (name == "signal_zero_crossings") {
            // signal_zero_crossings(t) -> count of zero crossings
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return Value(0);
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                int count=0; double prev=0;
                for (int i=0;i<n;i++) {
                    auto it=t->container->find(std::to_string(i)); double v=(it!=t->container->end())?it->second.value.d:0.0;
                    if (i>0 && ((prev>=0&&v<0)||(prev<0&&v>=0))) count++;
                    prev=v;
                }
                return Value(count);
            }
            return Value(0);
        }
        // =====================================================================
        // NYTORCH MATH: STATISTICS & LINEAR ALGEBRA
    // ── from main.cpp lines 4939–4988 ──────────────────────────────────────────
        if (name == "sleep") {
            if (!args.empty()) {
                double secs = args[0].type == ValueType::DOUBLE ? static_cast<double>(args[0].value.d) : static_cast<double>(bigint_to_i64(args[0].value.i));
                std::this_thread::sleep_for(std::chrono::milliseconds(static_cast<int>(secs * 1000)));
            }
            return NONE_VALUE;
        }
        if (name == "isdigit_str") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                bool result = !s.empty();
                for (char c : s) if (!std::isdigit(static_cast<unsigned char>(c))) { result = false; break; }
                return Value(result);
            }
            return Value(false);
        }
        if (name == "isalpha_str") {
            if (!args.empty()) {
                std::string s = getStringValue(args[0]);
                bool result = !s.empty();
                for (char c : s) if (!std::isalpha(static_cast<unsigned char>(c))) { result = false; break; }
                return Value(result);
            }
            return Value(false);
        }
        if (name == "regex_search" || name == "re_search") {
            if (args.size() >= 2) {
                std::string pattern = getStringValue(args[0]);
                std::string input = getStringValue(args[1]);
                try {
                    std::regex re(pattern);
                    std::smatch m;
                    if (std::regex_search(input, m, re)) {
                        if (m.size() <= 1) return makeStringValue(m[0].str());
                        Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (size_t i = 0; i < m.size(); i++) {
                            result->set(std::to_string(i), makeStringValue(m[i].str()));
                        }
                        result->set("__len__", Value(static_cast<int>(m.size())));
                        return Value((Collectable*)result);
                    }
                    return Value(false);
                } catch (std::regex_error& e) {
                    return makeStringValue(std::string("regex error: ") + e.what());
                } catch (...) {
                    return makeStringValue("unknown regex error");
                }
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 8659–8729 ──────────────────────────────────────────
        if (name == "thread_create") {
            if (!args.empty() && args[0].type == ValueType::USERDATA) {
                Value fn = args[0];
                // Create a real thread using std::thread
                auto* thr = new std::thread([&E, fn, ctx]() {
                    std::vector<Value> no_args;
                    try {
                        E.callFunctionValue(const_cast<Value&>(fn), no_args, ctx);
                    } catch (...) {}
                });
                thr->detach();
                // Return thread handle as integer
                return Value(static_cast<int>(reinterpret_cast<intptr_t>(thr) & 0x7FFFFFFF));
            }
            return NONE_VALUE;
        }
        if (name == "thread_join") {
            // thread_join waits for thread (simplified - detached threads can't be joined)
            // Use sleep as approximation
            if (!args.empty()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
            return Value(true);
        }
        if (name == "thread_sleep") {
            // thread_sleep() takes MILLISECONDS. It used to forward straight to
            // time_sleep(), which takes SECONDS — so lib/gui.ny's
            //     thread_sleep(int(1000 / fps))  ->  thread_sleep(16)
            // slept 16 seconds per frame instead of 16 ms, giving the IDE a frame
            // every 16s and the appearance of a frozen/black window.
            // Every caller in lib/ passes milliseconds (frame_ms, interval_ms, ...).
            if (!args.empty()) {
                double ms = (args[0].type == ValueType::DOUBLE)
                    ? static_cast<double>(args[0].value.d)
                    : (double)bigint_to_i64(args[0].value.i);
                if (ms < 0) ms = 0;
                std::this_thread::sleep_for(std::chrono::microseconds((long long)(ms * 1000.0)));
            }
            return NONE_VALUE;
        }
        if (name == "mutex_create") {
            static int mutex_counter = 0;
            return Value(++mutex_counter);
        }
        if (name == "mutex_lock" || name == "mutex_unlock") {
            return Value(true); // Simplified - single-threaded
        }
        if (name == "semaphore_create") {
            int count = (args.size() >= 1) ? (int)bigint_to_i64(args[0].value.i) : 1;
            auto* sem = new Object((Runnable*)runner, "semaphore", Type::LIST);
            sem->set("count", Value(count));
            sem->set("max", Value(count));
            return Value((Collectable*)sem);
        }
        if (name == "semaphore_acquire") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto it = cont->container->find("count");
                    if (it != cont->container->end()) {
                        int c = (int)bigint_to_i64(it->second.value.i);
                        if (c > 0) { it->second = Value(c - 1); return Value(true); }
                    }
                }
            }
            return Value(false);
        }
        if (name == "semaphore_release") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto it = cont->container->find("count");
                    auto mx = cont->container->find("max");
                    if (it != cont->container->end()) {
                        int c = (int)bigint_to_i64(it->second.value.i);
                        int m = (mx != cont->container->end()) ? (int)bigint_to_i64(mx->second.value.i) : c + 1;
                        if (c < m) { it->second = Value(c + 1); return Value(true); }
                    }
                }
            }
            return Value(false);
        }

        // ===================== NET/SOCKET MODULE =====================

    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

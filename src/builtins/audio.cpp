#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/audio.cpp
// Audio DSP: mel filterbank, MFCC, STFT, CTC loss
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_audio() is called from NythonExecutor::callBuiltin().
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
#include "builtins/audio.hpp"

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
// dispatch_audio
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_audio(NythonExecutor& E,
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
    // ── from main.cpp lines 6725–6819 ──────────────────────────────────────────
        if (name == "mel_filterbank") {
            // mel_filterbank(n_mels, n_fft, sample_rate) -> tensor of n_mels filterbank centers
            int n_mels = 40, n_fft = 512;
            double sr = 22050.0;
            if (!args.empty()) n_mels = (int)(args[0].type == ValueType::INTEGER ? bigint_to_i64(args[0].value.i) : args[0].value.d);
            if (args.size() >= 2) n_fft = (int)(args[1].type == ValueType::INTEGER ? bigint_to_i64(args[1].value.i) : args[1].value.d);
            if (args.size() >= 3) sr = (args[2].type == ValueType::DOUBLE) ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
            auto hz_to_mel = [](double hz) { return 2595.0 * std::log10(1.0 + hz / 700.0); };
            auto mel_to_hz = [](double mel) { return 700.0 * (std::pow(10.0, mel / 2595.0) - 1.0); };
            double mel_min = hz_to_mel(0.0);
            double mel_max = hz_to_mel(sr / 2.0);
            Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
            for (int i = 0; i < n_mels; i++) {
                double mel = mel_min + (mel_max - mel_min) * (i + 1) / (n_mels + 1);
                result->set(std::to_string(i), Value(mel_to_hz(mel)));
            }
            result->set("__len__", Value(n_mels));
            return Value((Collectable*)result);
        }
        if (name == "mfcc") {
            // Compute pseudo-MFCC: DCT of log mel energies
            if (!args.empty() && args[0].isCollectable()) {
                auto* mel = dynamic_cast<Container*>(args[0].value.gc);
                int n_mfcc = (args.size() >= 2) ? (int)(args[1].type == ValueType::INTEGER ? bigint_to_i64(args[1].value.i) : args[1].value.d) : 13;
                if (mel && mel->container) {
                    auto li = mel->container->find("__len__");
                    int len = (li != mel->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int c = 0; c < n_mfcc; c++) {
                        double coef = 0;
                        for (int n = 0; n < len; n++) {
                            auto it = mel->container->find(std::to_string(n));
                            double v = (it != mel->container->end()) ? (double)it->second.value.d : 0;
                            coef += v * std::cos(3.14159265 * c * (2*n+1) / (2*len));
                        }
                        result->set(std::to_string(c), Value(coef));
                    }
                    result->set("__len__", Value(n_mfcc));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "stft_magnitude") {
            // Simple STFT magnitude approximation from raw signal
            if (!args.empty() && args[0].isCollectable()) {
                auto* sig = dynamic_cast<Container*>(args[0].value.gc);
                int frame_size = (args.size() >= 2) ? (int)(args[1].type == ValueType::INTEGER ? bigint_to_i64(args[1].value.i) : args[1].value.d) : 512;
                int hop = (args.size() >= 3) ? (int)(args[2].type == ValueType::INTEGER ? bigint_to_i64(args[2].value.i) : args[2].value.d) : 128;
                if (sig && sig->container) {
                    auto li = sig->container->find("__len__");
                    int len = (li != sig->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int start = 0; start + frame_size <= len; start += hop) {
                        double energy = 0;
                        for (int i = start; i < start + frame_size; i++) {
                            auto it = sig->container->find(std::to_string(i));
                            double v = (it != sig->container->end()) ? (double)it->second.value.d : 0;
                            energy += v * v;
                        }
                        result->set(std::to_string(idx++), Value(std::sqrt(energy / frame_size)));
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "ctc_loss") {
            // Simplified CTC loss (returns a scalar approximation)
            if (args.size() >= 2) {
                double input_len = (args[0].type == ValueType::INTEGER) ? (double)bigint_to_i64(args[0].value.i) : (double)args[0].value.d;
                double target_len = (args[1].type == ValueType::INTEGER) ? (double)bigint_to_i64(args[1].value.i) : (double)args[1].value.d;
                if (input_len > 0 && target_len > 0 && input_len >= target_len)
                    return Value(std::log(input_len / target_len + 1.0));
            }
            return Value(0.0);
        }
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


    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

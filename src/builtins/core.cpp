#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/core.cpp
// Core builtins, type ops, functional
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_core() is called from NythonExecutor::callBuiltin().
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
#include "builtins/core.hpp"
#include <utility>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

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
// dispatch_core
// ════════════════════════════════════════════════════════════════════════════════
Value dispatch_core(NythonExecutor& E,
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
    // ── from main.cpp lines 3382–3589 ──────────────────────────────────────────
        // =====================================================================
        if (name == "tensor2d_get") {
            // tensor2d_get(t, row, col, width) -> value
            if (args.size() >= 4) {
                int row = (int)bigint_to_i64(args[1].value.i);
                int col = (int)bigint_to_i64(args[2].value.i);
                int w   = (int)bigint_to_i64(args[3].value.i);
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto it = t->container->find(std::to_string(row*w+col));
                    if (it != t->container->end()) return Value(it->second.value.d);
                }
            }
            return Value(0.0);
        }
        if (name == "tensor2d_set") {
            // tensor2d_set(t, row, col, width, val) -> tensor
            if (args.size() >= 5) {
                int row = (int)bigint_to_i64(args[1].value.i);
                int col = (int)bigint_to_i64(args[2].value.i);
                int w   = (int)bigint_to_i64(args[3].value.i);
                double v = args[4].type==ValueType::DOUBLE ? args[4].value.d : (double)bigint_to_i64(args[4].value.i);
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) (*t->container)[std::to_string(row*w+col)] = Value(v);
                return args[0];
            }
            return NONE_VALUE;
        }
        if (name == "tensor2d_conv") {
            // tensor2d_conv(image_flat, H, W, kernel_flat, kH, kW) -> output flat tensor
            if (args.size() >= 6) {
                auto* img = dynamic_cast<Container*>(args[0].value.gc);
                int H = (int)bigint_to_i64(args[1].value.i);
                int W = (int)bigint_to_i64(args[2].value.i);
                auto* ker = dynamic_cast<Container*>(args[3].value.gc);
                int kH = (int)bigint_to_i64(args[4].value.i);
                int kW = (int)bigint_to_i64(args[5].value.i);
                if (!img || !ker || !img->container || !ker->container) return NONE_VALUE;
                int pH = kH/2, pW = kW/2;
                int oH = H, oW = W;
                auto* out = new Container((Runnable*)runner, Type::LIST);
                (*out->container)["__len__"] = Value(oH*oW);
                for (int r = 0; r < oH; r++) {
                    for (int c = 0; c < oW; c++) {
                        double acc = 0;
                        for (int kr = 0; kr < kH; kr++) {
                            for (int kc = 0; kc < kW; kc++) {
                                int ir = r+kr-pH, ic = c+kc-pW;
                                if (ir>=0 && ir<H && ic>=0 && ic<W) {
                                    auto ii = img->container->find(std::to_string(ir*W+ic));
                                    auto ki = ker->container->find(std::to_string(kr*kW+kc));
                                    double iv = (ii!=img->container->end()) ? ii->second.value.d : 0.0;
                                    double kv = (ki!=ker->container->end()) ? ki->second.value.d : 0.0;
                                    acc += iv*kv;
                                }
                            }
                        }
                        (*out->container)[std::to_string(r*oW+c)] = Value(acc);
                    }
                }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "tensor2d_maxpool") {
            // tensor2d_maxpool(img, H, W, kH, kW, stride) -> {tensor, outH, outW}
            if (args.size() >= 6) {
                auto* img = dynamic_cast<Container*>(args[0].value.gc);
                int H=(int)bigint_to_i64(args[1].value.i), W=(int)bigint_to_i64(args[2].value.i);
                int kH=(int)bigint_to_i64(args[3].value.i), kW=(int)bigint_to_i64(args[4].value.i);
                int stride=(int)bigint_to_i64(args[5].value.i);
                if (!img || !img->container) return NONE_VALUE;
                int oH=(H-kH)/stride+1, oW=(W-kW)/stride+1;
                auto* out = new Container((Runnable*)runner, Type::LIST);
                (*out->container)["__len__"] = Value(oH*oW);
                for (int r=0;r<oH;r++) for (int c=0;c<oW;c++) {
                    double mx=-1e308;
                    for (int kr=0;kr<kH;kr++) for (int kc=0;kc<kW;kc++) {
                        int ir=r*stride+kr, ic=c*stride+kc;
                        if (ir<H&&ic<W) {
                            auto it=img->container->find(std::to_string(ir*W+ic));
                            double v=(it!=img->container->end())?it->second.value.d:0.0;
                            if(v>mx) mx=v;
                        }
                    }
                    (*out->container)[std::to_string(r*oW+c)]=Value(mx);
                }
                auto* res = new Object((Runnable*)runner, "map", Type::MAP);
                res->set("tensor", Value((Collectable*)out));
                res->set("outH", Value(oH)); res->set("outW", Value(oW));
                return Value((Collectable*)res);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_sort") {
            // tensor_sort(t, ascending=true) -> sorted tensor
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                bool asc = (args.size()<2) || isTruthy(args[1]);
                if (!t || !t->container) return NONE_VALUE;
                auto li = t->container->find("__len__");
                int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                std::vector<double> v; v.reserve((size_t)n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); v.push_back(it!=t->container->end()?it->second.value.d:0.0); }
                if (asc) std::sort(v.begin(),v.end()); else std::sort(v.begin(),v.end(),[](double a,double b){return a>b;});
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(n);
                for (int i=0;i<n;i++) (*out->container)[std::to_string(i)]=Value(v[(size_t)i]);
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_topk") {
            // tensor_topk(t, k) -> list of {value, index}
            if (args.size()>=2 && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                int k=(int)bigint_to_i64(args[1].value.i);
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__");
                int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                std::vector<std::pair<double,int>> v;
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); v.push_back({it!=t->container->end()?it->second.value.d:0.0, i}); }
                std::sort(v.begin(),v.end(),[](auto&a,auto&b){return a.first>b.first;});
                if (k>n) k=n;
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(k);
                for (int i=0;i<k;i++) {
                    auto* item=new Object((Runnable*)runner,"map",Type::MAP);
                    item->set("value",Value(v[(size_t)i].first));
                    item->set("index",Value(v[(size_t)i].second));
                    (*out->container)[std::to_string(i)]=Value((Collectable*)item);
                }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_eye") {
            // tensor_eye(n) -> identity matrix as flat n*n tensor
            if (!args.empty()) {
                int n=(int)bigint_to_i64(args[0].value.i);
                auto* t=new Container((Runnable*)runner,Type::LIST);
                (*t->container)["__len__"]=Value(n*n);
                for (int r=0;r<n;r++) for (int c=0;c<n;c++) (*t->container)[std::to_string(r*n+c)]=Value(r==c?1.0:0.0);
                return Value((Collectable*)t);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_diag") {
            // tensor_diag(t) -> diagonal elements as new tensor
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__"); int n=(int)std::sqrt((double)bigint_to_i64(li->second.value.i));
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i*n+i)); (*out->container)[std::to_string(i)]=Value(it!=t->container->end()?it->second.value.d:0.0); }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_flatten") {
            // tensor_flatten(t) -> same tensor (already flat, just updates __len__ from data)
            if (!args.empty() && args[0].isCollectable()) return args[0];
            return NONE_VALUE;
        }
        if (name == "tensor_pad") {
            // tensor_pad(t, pad_left, pad_right, val=0.0) -> padded tensor
            if (args.size()>=3 && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                int pl=(int)bigint_to_i64(args[1].value.i), pr=(int)bigint_to_i64(args[2].value.i);
                double pv=(args.size()>=4)?(args[3].type==ValueType::DOUBLE?args[3].value.d:(double)bigint_to_i64(args[3].value.i)):0.0;
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                int nn=n+pl+pr;
                auto* out=new Container((Runnable*)runner,Type::LIST);
                (*out->container)["__len__"]=Value(nn);
                for (int i=0;i<pl;i++) (*out->container)[std::to_string(i)]=Value(pv);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); (*out->container)[std::to_string(i+pl)]=Value(it!=t->container->end()?it->second.value.d:0.0); }
                for (int i=0;i<pr;i++) (*out->container)[std::to_string(n+pl+i)]=Value(pv);
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_dot_product") {
            // tensor_dot_product(a, b) -> scalar (alias for tensor_dot)
            if (args.size()>=2) {
                std::vector<Value> dargs={args[0],args[1]};
                return callBuiltin("tensor_dot", dargs, ctx);
            }
            return Value(0.0);
        }
        if (name == "tensor_cosine_sim") {
            // tensor_cosine_sim(a, b) -> scalar
            if (args.size()>=2) {
                std::vector<Value> sa={args[0]}, sb={args[1]};
                Value na=callBuiltin("tensor_norm", sa, ctx);
                Value nb=callBuiltin("tensor_norm", sb, ctx);
                std::vector<Value> dv2={args[0],args[1]};
                Value dot=callBuiltin("tensor_dot", dv2, ctx);
                double dv=dot.type==ValueType::DOUBLE?dot.value.d:(double)bigint_to_i64(dot.value.i);
                double nva=na.type==ValueType::DOUBLE?na.value.d:(double)bigint_to_i64(na.value.i);
                double nvb=nb.type==ValueType::DOUBLE?nb.value.d:(double)bigint_to_i64(nb.value.i);
                double denom=nva*nvb; if(denom<1e-12) denom=1e-12;
                return Value(dv/denom);
            }
            return Value(0.0);
        }
        // =====================================================================
    // ── from main.cpp lines 4561–4723 ──────────────────────────────────────────
        // ===================== MAP / FILTER / REDUCE =====================
        if (name == "map") {
            if (args.size() >= 2 && args[0].type == ValueType::USERDATA) {
                Value fn_val = args[0];
                if (args.size() == 2 && args[1].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[1].value.gc);
                    if (cont && cont->container) {
                        auto li = cont->container->find("__len__");
                        int len = (li != cont->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                        Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::vector<Value> ca = {it->second};
                                result->set(std::to_string(i), callFunctionValue(fn_val, ca, ctx));
                            }
                        }
                        result->set("__len__", Value(len));
                        return Value((Collectable*)result);
                    }
                }
                if (args.size() >= 3) {
                    int min_len = 999999;
                    std::vector<Container*> iters;
                    for (size_t a = 1; a < args.size(); a++) {
                        if (args[a].isCollectable()) {
                            auto* c = dynamic_cast<Container*>(args[a].value.gc);
                            iters.push_back(c);
                            if (c && c->container) {
                                auto li = c->container->find("__len__");
                                int l = (li != c->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                                if (l < min_len) min_len = l;
                            }
                        }
                    }
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int i = 0; i < min_len; i++) {
                        std::vector<Value> ca;
                        for (auto* c : iters) {
                            if (c && c->container) {
                                auto it = c->container->find(std::to_string(i));
                                if (it != c->container->end()) ca.push_back(it->second);
                            }
                        }
                        result->set(std::to_string(i), callFunctionValue(fn_val, ca, ctx));
                    }
                    result->set("__len__", Value(min_len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "filter") {
            // filter(fn, list) -> [x for x in list if fn(x)]
            if (args.size() >= 2 && args[0].type == ValueType::USERDATA && args[1].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[1].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int out_idx = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            std::vector<Value> ca = {it->second};
                            Value rv = callFunctionValue(args[0], ca, ctx);
                            if (rv.isTrue()) {
                                result->set(std::to_string(out_idx++), it->second);
                            }
                        }
                    }
                    result->set("__len__", Value(out_idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "reduce") {
            // reduce(fn, list[, initial])
            if (args.size() >= 2 && args[0].type == ValueType::USERDATA && args[1].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[1].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    Value acc;
                    int start = 0;
                    if (args.size() >= 3) {
                        acc = args[2];
                    } else if (len > 0) {
                        acc = cont->container->at("0");
                        start = 1;
                    } else {
                        return NONE_VALUE;
                    }
                    for (int i = start; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            std::vector<Value> ca = {acc, it->second};
                            acc = callFunctionValue(args[0], ca, ctx);
                        }
                    }
                    return acc;
                }
            }
            return NONE_VALUE;
        }
        if (name == "list" || name == "tuple") {
            if (args.empty()) return NONE_VALUE;
            // If it's a generator object, collect remaining values from __idx__
            if (args[0].isCollectable() && args[0].value.gc) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container && cont->container->count("__gen__")) {
                    auto idx_it = cont->container->find("__idx__");
                    auto len_it = cont->container->find("__len__");
                    int start = (idx_it != cont->container->end()) ? (int)bigint_to_i64(idx_it->second.value.i) : 0;
                    int len   = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                    auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int out = 0;
                    for (int i = start; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) result->set(std::to_string(out++), it->second);
                    }
                    result->set("__len__", Value(out));
                    return Value((Collectable*)result);
                }
            }
            return args[0];
        }
        if (name == "set") {
            // Deduplicate: build a new list containing only unique values
            if (args.empty() || !args[0].isCollectable()) return args.empty() ? NONE_VALUE : args[0];
            auto* src = dynamic_cast<Container*>(args[0].value.gc);
            if (!src || !src->container) return args[0];
            auto li = src->container->find("__len__");
            int len = (li != src->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
            auto* result = new Object((Runnable*)runner, "list", Type::LIST);
            std::vector<std::string> seen_strs;
            int out_idx = 0;
            for (int i = 0; i < len; i++) {
                auto it = src->container->find(std::to_string(i));
                if (it == src->container->end()) continue;
                const Value& v = it->second;
                // Compute a string key for deduplication
                std::string key;
                if (v.type == ValueType::INTEGER) key = "i:" + std::to_string(bigint_to_i64(v.value.i));
                else if (v.type == ValueType::DOUBLE) key = "d:" + std::to_string(v.value.d);
                else if (v.type == ValueType::BOOLEAN) key = std::string("b:") + (v.value.b ? "1" : "0");
                else if (v.type == ValueType::NONE) key = "none";
                else key = "s:" + getStringValue(const_cast<Value&>(v));
                bool dup = false;
                for (auto& s : seen_strs) if (s == key) { dup = true; break; }
                if (!dup) {
                    seen_strs.push_back(key);
                    result->set(std::to_string(out_idx++), v);
                }
            }
            result->set("__len__", Value(out_idx));
            result->set("__set__", Value(1));  // tag as set type
            return Value((Collectable*)result);
        }
        if (name == "divmod") {
            if (args.size() >= 2 && args[0].type == ValueType::INTEGER && args[1].type == ValueType::INTEGER) {
                int64_t a = bigint_to_i64(args[0].value.i);
                int64_t b = bigint_to_i64(args[1].value.i);
                if (b == 0) throw std::string("division by zero");
                Object* result = new Object((Runnable*)runner, "tuple", Type::LIST);
                result->set("0", Value(static_cast<int>(a / b)));
                result->set("1", Value(static_cast<int>(a % b)));
                result->set("__len__", Value(2));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "all") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    int len = (li != cont->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end() && !isTruthy(it->second)) return Value(false);
                    }
                    return Value(true);
                }
            }
            return Value(true);
        }
        if (name == "any") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    int len = (li != cont->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end() && isTruthy(it->second)) return Value(true);
                    }
                    return Value(false);
                }
            }
            return Value(false);
        }
        if (name == "round") {
            if (args.empty()) return NONE_VALUE;
            double val = args[0].type == ValueType::DOUBLE ? static_cast<double>(args[0].value.d) : static_cast<double>(bigint_to_i64(args[0].value.i));
            if (args.size() >= 2) {
                int digits = static_cast<int>(bigint_to_i64(args[1].value.i));
                double factor = std::pow(10.0, digits);
                return Value(std::round(val * factor) / factor);
            }
            return Value(static_cast<int>(std::round(val)));
        }



    // ── from main.cpp lines 9328–9641 (final core/math/io builtins) ─────────
        if (name == "hasattr") {
            if (args.size() >= 2) {
                std::string attr = getStringValue(args[1]);
                // Check Collectable containers
                if (args[0].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        return Value(cont->container->find(attr) != cont->container->end());
                    }
                }
                // Check USERDATA instance properties
                if (args[0].type == ValueType::USERDATA && args[0].value.p && !E.string_ptrs_.count(args[0].value.p)) {
                    auto pctx_it = instance_properties.find(args[0].value.p);
                    if (pctx_it != instance_properties.end() && pctx_it->second) {
                        try { Value v = pctx_it->second->getByName(attr); if (v.type != ValueType::UNDEFINED) return Value(true); } catch(...) {}
                    }
                    // Also check class methods
                    auto cit2 = instance_to_class.find(args[0].value.p);
                    if (cit2 != instance_to_class.end()) {
                        void* class_ptr = cit2->second;
                        void* ast_ptr2 = class_ptr;
                        auto ast_it2 = func_ast_nodes.find(class_ptr);
                        if (ast_it2 != func_ast_nodes.end()) ast_ptr2 = ast_it2->second;
                        Node* cn2 = (Node*)ast_ptr2;
                        if (cn2 && cn2->type() == NodeType::CLASS) {
                            auto* cnode = static_cast<ClassNode*>(cn2);
                            if (cnode->body) {
                                for (auto& stmt : cnode->body->statements()) {
                                    if (stmt->type() == NodeType::FUNCTION) {
                                        auto* fn = static_cast<FunctionNode*>(stmt.get());
                                        if (fn->name == attr) return Value(true);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return Value(false);
        }
        if (name == "getattr") {
            if (args.size() >= 2) {
                std::string attr = getStringValue(args[1]);
                if (args[0].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        auto it = cont->container->find(attr);
                        if (it != cont->container->end()) return it->second;
                    }
                }
                if (args[0].type == ValueType::USERDATA && !E.string_ptrs_.count(args[0].value.p) && instance_properties.count(args[0].value.p)) {
                    auto* pctx = instance_properties[args[0].value.p];
                    if (pctx) {
                        try {
                            Value v = pctx->getByName(attr);
                            if (v.type != ValueType::UNDEFINED) return v;
                        } catch(...) {}
                    }
                }
                if (args.size() >= 3) return args[2]; // default
            }
            return NONE_VALUE;
        }
        if (name == "setattr") {
            if (args.size() >= 3) {
                std::string attr = getStringValue(args[1]);
                if (args[0].type == ValueType::USERDATA && !E.string_ptrs_.count(args[0].value.p) && instance_properties.count(args[0].value.p)) {
                    auto* pctx = instance_properties[args[0].value.p];
                    if (pctx) pctx->defineByName(attr, args[2]);
                } else if (args[0].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) (*cont->container)[attr] = args[2];
                }
                return NONE_VALUE;
            }
            return NONE_VALUE;
        }

        if (name == "keys") {
            if (args.size() >= 1) {
                Container* cont = nullptr;
                if (args[0].isCollectable()) cont = dynamic_cast<Container*>(args[0].value.gc);
                // Only a non-string USERDATA can be a Collectable. A string's value.p
                // points into the executor's string store, so casting it to
                // Collectable* and dynamic_cast-ing read a bogus vtable and
                // segfaulted: items("abc"), keys("abc") and values("abc") all
                // crashed the process.
                if (!cont && args[0].type == ValueType::USERDATA && !isStringValue(args[0]))
                    cont = dynamic_cast<Container*>(static_cast<Collectable*>(args[0].value.p));
                if (cont && cont->container) {
                    auto* list = new Object(static_cast<Runnable*>(runner), "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (!k.empty() && k[0] != '_' && (k[0] < '0' || k[0] > '9'))
                            (*list->container)[std::to_string(idx++)] = makeStringValue(k);
                    }
                    (*list->container)["__len__"] = Value(idx);
                    return Value(static_cast<Collectable*>(list));
                }
            }
            return NONE_VALUE;
        }
        if (name == "values") {
            if (args.size() >= 1) {
                Container* cont = nullptr;
                if (args[0].isCollectable()) cont = dynamic_cast<Container*>(args[0].value.gc);
                // Only a non-string USERDATA can be a Collectable. A string's value.p
                // points into the executor's string store, so casting it to
                // Collectable* and dynamic_cast-ing read a bogus vtable and
                // segfaulted: items("abc"), keys("abc") and values("abc") all
                // crashed the process.
                if (!cont && args[0].type == ValueType::USERDATA && !isStringValue(args[0]))
                    cont = dynamic_cast<Container*>(static_cast<Collectable*>(args[0].value.p));
                if (cont && cont->container) {
                    auto* list = new Object(static_cast<Runnable*>(runner), "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (!k.empty() && k[0] != '_' && (k[0] < '0' || k[0] > '9'))
                            (*list->container)[std::to_string(idx++)] = v;
                    }
                    (*list->container)["__len__"] = Value(idx);
                    return Value(static_cast<Collectable*>(list));
                }
            }
            return NONE_VALUE;
        }
        if (name == "items") {
            if (args.size() >= 1) {
                Container* cont = nullptr;
                if (args[0].isCollectable()) cont = dynamic_cast<Container*>(args[0].value.gc);
                // Only a non-string USERDATA can be a Collectable. A string's value.p
                // points into the executor's string store, so casting it to
                // Collectable* and dynamic_cast-ing read a bogus vtable and
                // segfaulted: items("abc"), keys("abc") and values("abc") all
                // crashed the process.
                if (!cont && args[0].type == ValueType::USERDATA && !isStringValue(args[0]))
                    cont = dynamic_cast<Container*>(static_cast<Collectable*>(args[0].value.p));
                if (cont && cont->container) {
                    auto* list = new Object(static_cast<Runnable*>(runner), "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (!k.empty() && k[0] != '_' && (k[0] < '0' || k[0] > '9')) {
                            auto* pair = new Object(static_cast<Runnable*>(runner), "list", Type::LIST);
                            (*pair->container)["0"] = makeStringValue(k);
                            (*pair->container)["1"] = v;
                            (*pair->container)["__len__"] = Value(2);
                            (*list->container)[std::to_string(idx++)] = Value(static_cast<Collectable*>(pair));
                        }
                    }
                    (*list->container)["__len__"] = Value(idx);
                    return Value(static_cast<Collectable*>(list));
                }
            }
            return NONE_VALUE;
        }
        if (name == "next") {
            if (!args.empty() && args[0].isCollectable() && args[0].value.gc) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container && cont->container->count("__gen__")) {
                    auto idx_it = cont->container->find("__idx__");
                    auto len_it = cont->container->find("__len__");
                    int idx = (idx_it != cont->container->end()) ? (int)bigint_to_i64(idx_it->second.value.i) : 0;
                    int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                    if (idx < len) {
                        auto val_it = cont->container->find(std::to_string(idx));
                        (*cont->container)["__idx__"] = Value(idx + 1);
                        return val_it != cont->container->end() ? val_it->second : NONE_VALUE;
                    }
                    // Exhausted - raise StopIteration
                    throw std::string("__exc__:StopIteration:generator exhausted");
                }
            }
            return NONE_VALUE;
        }
        if (name == "issubclass" || name == "property" || name == "staticmethod" || name == "classmethod" || name == "dir" || name == "vars" || name == "globals" || name == "locals" || name == "iter" || name == "help" || name == "format" || name == "slice" || name == "divmod" || name == "complex") {
            return NONE_VALUE; // placeholder
        }
        // id(x) / hash(x) — registered as recognised builtin names (see
        // NythonExecutor::registerBuiltins) but never actually dispatched
        // here, so a bare id(x)/hash(x) call fell through every dispatch_*
        // module and returned UNDEFINED, which reads as 0. The method form
        // obj.id()/obj.hash() (objectProtocol) already worked; this gives
        // the global function the same behaviour instead of nothing.
        if (name == "id") {
            if (args.empty()) return Value(bigint((long long)0));
            Value& v = args[0];
            // Heap-allocated values (class instances, containers): identity
            // is the underlying pointer, masked to fit a signed bigint the
            // same way objectProtocol's "id" method does.
            if (v.type == ValueType::USERDATA && v.value.p) {
                unsigned long long raw = (unsigned long long)(size_t)v.value.p;
                return Value(bigint((long long)(raw & 0x7fffffffULL)));
            }
            if (v.isCollectable() && v.value.gc) {
                unsigned long long raw = (unsigned long long)(size_t)v.value.gc;
                return Value(bigint((long long)(raw & 0x7fffffffULL)));
            }
            // Primitives have no heap identity; derive a stable value so
            // id(x) is non-zero, repeatable for the same x, and type-aware
            // (id(1) != id(1.0) even though 1 == 1.0).
            unsigned long long h = std::hash<std::string>{}(getStringValue(v) + "|" + std::to_string((int)v.type));
            return Value(bigint((long long)(h & 0x7fffffffULL)));
        }
        if (name == "hash") {
            if (args.empty()) return Value(bigint((long long)0));
            unsigned long long h = std::hash<std::string>{}(getStringValue(args[0]));
            return Value(bigint((long long)(h & 0x7fffffffULL)));
        }
        if (name == "sqrt") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(static_cast<double>(std::sqrt(v)));
            }
            return Value(0.0);
        }
        if (name == "sin") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::sin(v));
            }
            return Value(0.0);
        }
        if (name == "cos") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::cos(v));
            }
            return Value(0.0);
        }
        if (name == "tan") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::tan(v));
            }
            return Value(0.0);
        }
        if (name == "exp") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::exp(v));
            }
            return Value(1.0);
        }
        if (name == "tanh") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::tanh(v));
            }
            return Value(0.0);
        }
        if (name == "atan2") {
            if (args.size() >= 2) {
                double y = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                double x = (args[1].type == ValueType::DOUBLE) ? static_cast<double>(args[1].value.d) : (double)bigint_to_i64(args[1].value.i);
                return Value(std::atan2(y, x));
            }
            return Value(0.0);
        }
        if (name == "log") {
            if (args.size() >= 1) {
                double v = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                return Value(std::log(v));
            }
            return Value(0.0);
        }
        if (name == "floor") {
            if (args.size() >= 1 && args[0].type == ValueType::DOUBLE) return Value((int)std::floor(args[0].value.d));
            return args.size() ? args[0] : Value(0);
        }
        if (name == "ceil") {
            if (args.size() >= 1 && args[0].type == ValueType::DOUBLE) return Value((int)std::ceil(args[0].value.d));
            return args.size() ? args[0] : Value(0);
        }
        if (name == "read_file") {
            if (args.size() >= 1) {
                std::string fname = getStringValue(args[0]);
                std::ifstream f(fname);
                if (f.is_open()) {
                    std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
                    return makeStringValue(content);
                }
            }
            return makeStringValue("");
        }
        if (name == "write_file") {
            if (args.size() >= 2) {
                std::string fname = getStringValue(args[0]);
                std::string content = getStringValue(args[1]);
                std::ofstream f(fname);
                if (f.is_open()) { f << content; return Value(true); }
            }
            return Value(false);
        }
        if (name == "file_exists") {
            if (args.size() >= 1) {
                struct stat buf;
                return Value(stat(getStringValue(args[0]).c_str(), &buf) == 0);
            }
            return Value(false);
        }
        if (name == "dict") {
            if (args.empty()) { auto* m = new Object((Runnable*)runner, "map", Type::MAP); return Value((Collectable*)m); }
            if (args[0].isCollectable()) {
                auto* src = dynamic_cast<Container*>(args[0].value.gc);
                if (src && src->container) {
                    auto li = src->container->find("__len__");
                    int len = (li != src->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    auto* m = new Object((Runnable*)runner, "map", Type::MAP);
                    for (int i = 0; i < len; i++) {
                        auto it = src->container->find(std::to_string(i));
                        if (it != src->container->end() && it->second.isCollectable()) {
                            auto* pair = dynamic_cast<Container*>(it->second.value.gc);
                            if (pair && pair->container) {
                                auto k = pair->container->find("0");
                                auto v = pair->container->find("1");
                                if (k != pair->container->end() && v != pair->container->end())
                                    (*m->container)[getStringValue(k->second)] = v->second;
                            }
                        }
                    }
                    return Value((Collectable*)m);
                }
            }
            return NONE_VALUE;
        }
        if (name == "bool") {
            if (args.size() >= 1) {
                if (args[0].type == ValueType::USERDATA && args[0].value.p) return Value(!getStringValue(args[0]).empty());
                if (args[0].type == ValueType::COLLECTABLE && args[0].value.gc) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        auto len_it = cont->container->find("__len__");
                        if (len_it != cont->container->end()) return Value(bigint_to_i64(len_it->second.value.i) > 0);
                    }
                }
                if (args[0].type == ValueType::NONE) return Value(false);
                if (args[0].type == ValueType::INTEGER) return Value(bigint_to_i64(args[0].value.i) != 0);
                if (args[0].type == ValueType::DOUBLE) return Value(args[0].value.d != 0.0);
                if (args[0].type == ValueType::BOOLEAN) return args[0];
                return Value(true);
            }
            return Value(false);
        }
        if (name == "repeat") {
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                int n = static_cast<int>(bigint_to_i64(args[1].value.i));
                std::string result;
                result.reserve(s.size() * n);
                for (int i = 0; i < n; i++) result += s;
                return makeStringValue(result);
            }
            return NONE_VALUE;
        }
        if (name == "abs") {
            if (args.size() >= 1) {
                if (args[0].type == ValueType::INTEGER) {
                    int64_t v = bigint_to_i64(args[0].value.i);
                    return Value((int)(v < 0 ? -v : v));
                }
                if (args[0].type == ValueType::DOUBLE) return Value(std::abs(args[0].value.d));
            }
            return Value(0);
        }
        if (name == "min" || name == "max") {
            if (args.size() == 1 && args[0].isCollectable()) {
                // Single iterable arg: find min/max element
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    if (len == 0) return NONE_VALUE;
                    Value best = cont->container->at("0");
                    for (int i = 1; i < len; i++) {
                        Value v = cont->container->at(std::to_string(i));
                        double vd = (v.type == ValueType::DOUBLE) ? v.value.d : (double)bigint_to_i64(v.value.i);
                        double bd = (best.type == ValueType::DOUBLE) ? best.value.d : (double)bigint_to_i64(best.value.i);
                        // Also handle string comparison
                        if (v.type == ValueType::USERDATA && best.type == ValueType::USERDATA) {
                            std::string sv = getStringValue(v), sb = getStringValue(best);
                            if (name == "min" ? sv < sb : sv > sb) best = v;
                        } else if (name == "min" ? vd < bd : vd > bd) best = v;
                    }
                    return best;
                }
            }
            if (args.size() >= 2) {
                auto toDouble = [](const Value& v) -> double {
                    if (v.type == ValueType::DOUBLE) return v.value.d;
                    if (v.type == ValueType::INTEGER) return (double)bigint_to_i64(v.value.i);
                    return 0.0;
                };
                bool bothInt = args[0].type == ValueType::INTEGER && args[1].type == ValueType::INTEGER;
                if (bothInt) {
                    int64_t a = bigint_to_i64(args[0].value.i), b = bigint_to_i64(args[1].value.i);
                    return Value((int)(name == "min" ? std::min(a, b) : std::max(a, b)));
                }
                double a = toDouble(args[0]), b = toDouble(args[1]);
                return Value(name == "min" ? std::min(a, b) : std::max(a, b));
            }
            return args.empty() ? Value(0) : args[0];
        }
        if (name == "input") {
            if (!args.empty()) printValue(args[0]);
            std::string line;
            std::getline(std::cin, line);
            return makeStringValue(line);
        }
        if (name == "hex") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                std::stringstream ss; ss << "0x" << std::hex << bigint_to_i64(args[0].value.i);
                return makeStringValue(ss.str());
            }
            return NONE_VALUE;
        }
        if (name == "oct") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                std::stringstream ss; ss << "0o" << std::oct << bigint_to_i64(args[0].value.i);
                return makeStringValue(ss.str());
            }
            return NONE_VALUE;
        }
        if (name == "bin") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                int64_t n = bigint_to_i64(args[0].value.i);
                std::string s = "0b";
                if (n == 0) s += "0";
                else { std::string bits; while(n>0){ bits = (char)('0'+(n&1)) + bits; n>>=1; } s+=bits; }
                return makeStringValue(s);
            }
            return NONE_VALUE;
        }
        if (name == "chr") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                return makeStringValue(std::string(1, (char)bigint_to_i64(args[0].value.i)));
            }
            return NONE_VALUE;
        }
        if (name == "ord") {
            if (args.size() >= 1 && args[0].type == ValueType::USERDATA && args[0].value.p) {
                std::string s = getStringValue(args[0]);
                if (!s.empty()) return Value((int)s[0]);
            }
            return Value(0);
        }

    return UNDEFINED_VALUE;  // not handled by this module
}
#pragma GCC diagnostic pop

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/tensor.cpp
// Tensor math, ML ops, NyTorch v1-v3
// ─────────────────────────────────────────────────────────────────────────────
// HOW THIS FILE WORKS:
//   dispatch_tensor() is called from NythonExecutor::callBuiltin().
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
#include "builtins/tensor.hpp"

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
// dispatch_tensor
// ════════════════════════════════════════════════════════════════════════════════

// Reads an integer marker such as "__rows__" from a container.
//
// These were read as container->find("__rows__")->second without checking the
// iterator: handing a plain list to a matrix builtin dereferenced end() and
// segfaulted, e.g. mat_transpose([3,1,2]).
static int64_t ny_mat_dim(Container* c, const char* key, int64_t fallback = -1) {
    if (!c || !c->container) return fallback;
    auto it = c->container->find(key);
    if (it == c->container->end()) return fallback;
    if (it->second.type != ValueType::INTEGER) return fallback;
    return bigint_to_i64(it->second.value.i);
}

Value dispatch_tensor(NythonExecutor& E,
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
    // ── from main.cpp lines 2719–2820 ──────────────────────────────────────────
        // NYTORCH AGENT I/O: STORAGE ACCESS
        // =====================================================================
        if (name == "tensor_save") {
            // tensor_save(tensor, path) -> bool  — saves floats as binary: magic(4) + n(4) + f32*n
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                std::string path = getStringValue(args[1]);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int n = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    std::ofstream f(path, std::ios::binary);
                    if (!f.is_open()) return Value(false);
                    uint32_t magic = 0x4E594D4C; // NYML
                    uint32_t sz = (uint32_t)n;
                    f.write((char*)&magic, 4); f.write((char*)&sz, 4);
                    for (int i = 0; i < n; i++) {
                        auto it = t->container->find(std::to_string(i));
                        float v = (it != t->container->end()) ? (float)it->second.value.d : 0.0f;
                        f.write((char*)&v, 4);
                    }
                    return Value(true);
                }
            }
            return Value(false);
        }
        if (name == "tensor_load") {
            // tensor_load(path) -> tensor
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream f(path, std::ios::binary);
                if (!f.is_open()) return NONE_VALUE;
                uint32_t magic, sz;
                f.read((char*)&magic, 4); f.read((char*)&sz, 4);
                if (magic != 0x4E594D4C) return NONE_VALUE;
                auto* t = new Container((Runnable*)runner, Type::LIST);
                (*t->container)["__len__"] = Value((int)sz);
                for (uint32_t i = 0; i < sz; i++) {
                    float v; f.read((char*)&v, 4);
                    (*t->container)[std::to_string(i)] = Value((double)v);
                }
                return Value((Collectable*)t);
            }
            return NONE_VALUE;
        }
        if (name == "model_save") {
            // model_save(params_list, path) -> bool  — saves list of tensors
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* lst = dynamic_cast<Container*>(args[0].value.gc);
                std::string path = getStringValue(args[1]);
                if (!lst || !lst->container) return Value(false);
                std::ofstream f(path, std::ios::binary);
                if (!f.is_open()) return Value(false);
                uint32_t magic = 0x4E594D44; // NYMD
                auto li = lst->container->find("__len__");
                int num_params = (li != lst->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                f.write((char*)&magic, 4);
                uint32_t np = (uint32_t)num_params;
                f.write((char*)&np, 4);
                for (int pi = 0; pi < num_params; pi++) {
                    auto pit = lst->container->find(std::to_string(pi));
                    if (pit == lst->container->end()) continue;
                    auto* t = pit->second.isCollectable() ? dynamic_cast<Container*>(pit->second.value.gc) : nullptr;
                    if (!t || !t->container) { uint32_t z=0; f.write((char*)&z,4); continue; }
                    auto tli = t->container->find("__len__");
                    int tn = (tli != t->container->end()) ? (int)bigint_to_i64(tli->second.value.i) : 0;
                    uint32_t tsz = (uint32_t)tn;
                    f.write((char*)&tsz, 4);
                    for (int i = 0; i < tn; i++) {
                        auto it = t->container->find(std::to_string(i));
                        float v = (it != t->container->end()) ? (float)it->second.value.d : 0.0f;
                        f.write((char*)&v, 4);
                    }
                }
                return Value(true);
            }
            return Value(false);
        }
        if (name == "model_load") {
            // model_load(path) -> list of tensors
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream f(path, std::ios::binary);
                if (!f.is_open()) return NONE_VALUE;
                uint32_t magic; f.read((char*)&magic, 4);
                if (magic != 0x4E594D44) return NONE_VALUE;
                uint32_t num_params; f.read((char*)&num_params, 4);
                auto* lst = new Container((Runnable*)runner, Type::LIST);
                (*lst->container)["__len__"] = Value((int)num_params);
                for (uint32_t pi = 0; pi < num_params; pi++) {
                    uint32_t tsz; f.read((char*)&tsz, 4);
                    auto* t = new Container((Runnable*)runner, Type::LIST);
                    (*t->container)["__len__"] = Value((int)tsz);
                    for (uint32_t i = 0; i < tsz; i++) {
                        float v; f.read((char*)&v, 4);
                        (*t->container)[std::to_string(i)] = Value((double)v);
                    }
                    (*lst->container)[std::to_string(pi)] = Value((Collectable*)t);
                }
                return Value((Collectable*)lst);
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 3755–4560 ──────────────────────────────────────────
        // =====================================================================
        if (name == "tensor_corr") {
            // tensor_corr(a, b) -> pearson correlation coefficient
            if (args.size()>=2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* ta=dynamic_cast<Container*>(args[0].value.gc);
                auto* tb=dynamic_cast<Container*>(args[1].value.gc);
                if (!ta||!tb||!ta->container||!tb->container) return Value(0.0);
                auto lia=ta->container->find("__len__"); int n=(int)bigint_to_i64(lia->second.value.i);
                double ma=0,mb=0;
                for (int i=0;i<n;i++) {
                    auto ia=ta->container->find(std::to_string(i)), ib=tb->container->find(std::to_string(i));
                    ma+=(ia!=ta->container->end())?ia->second.value.d:0.0;
                    mb+=(ib!=tb->container->end())?ib->second.value.d:0.0;
                }
                ma/=n; mb/=n;
                double cov=0,sa=0,sb=0;
                for (int i=0;i<n;i++) {
                    auto ia=ta->container->find(std::to_string(i)), ib=tb->container->find(std::to_string(i));
                    double da=((ia!=ta->container->end())?ia->second.value.d:0.0)-ma;
                    double db=((ib!=tb->container->end())?ib->second.value.d:0.0)-mb;
                    cov+=da*db; sa+=da*da; sb+=db*db;
                }
                double denom=std::sqrt(sa*sb); if(denom<1e-12) denom=1e-12;
                return Value(cov/denom);
            }
            return Value(0.0);
        }
        if (name == "tensor_histogram") {
            // tensor_histogram(t, n_bins=10) -> {bins, counts}
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                int nbins=(args.size()>=2)?(int)bigint_to_i64(args[1].value.i):10;
                if (!t||!t->container||nbins<1) return NONE_VALUE;
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                double mn=1e308,mx=-1e308;
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); double v=(it!=t->container->end())?it->second.value.d:0.0; if(v<mn)mn=v; if(v>mx)mx=v; }
                double rng=mx-mn; if(rng<1e-12) rng=1.0;
                std::vector<int> counts((size_t)nbins,0);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); double v=(it!=t->container->end())?it->second.value.d:0.0; int b=(int)((v-mn)/rng*nbins); if(b>=nbins)b=nbins-1; counts[(size_t)b]++; }
                auto* bins_t=new Container((Runnable*)runner,Type::LIST); (*bins_t->container)["__len__"]=Value(nbins);
                auto* cnts_t=new Container((Runnable*)runner,Type::LIST); (*cnts_t->container)["__len__"]=Value(nbins);
                for (int i=0;i<nbins;i++) { (*bins_t->container)[std::to_string(i)]=Value(mn+rng*i/nbins); (*cnts_t->container)[std::to_string(i)]=Value(counts[(size_t)i]); }
                auto* res=new Object((Runnable*)runner,"map",Type::MAP);
                res->set("bins",Value((Collectable*)bins_t)); res->set("counts",Value((Collectable*)cnts_t));
                return Value((Collectable*)res);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_percentile") {
            // tensor_percentile(t, p) -> value at percentile p (0-100)
            if (args.size()>=2 && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                double p=args[1].type==ValueType::DOUBLE?args[1].value.d:(double)bigint_to_i64(args[1].value.i);
                if (!t||!t->container) return Value(0.0);
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                std::vector<double> v; v.reserve((size_t)n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); v.push_back(it!=t->container->end()?it->second.value.d:0.0); }
                std::sort(v.begin(),v.end());
                double idx=(p/100.0)*(n-1); int lo=(int)idx; int hi=std::min(lo+1,n-1);
                return Value(v[(size_t)lo]+(idx-lo)*(v[(size_t)hi]-v[(size_t)lo]));
            }
            return Value(0.0);
        }
        if (name == "tensor_zscore") {
            // tensor_zscore(t) -> z-normalized tensor
            if (!args.empty() && args[0].isCollectable()) {
                auto* t=dynamic_cast<Container*>(args[0].value.gc);
                if (!t||!t->container) return NONE_VALUE;
                auto li=t->container->find("__len__"); int n=(li!=t->container->end())?(int)bigint_to_i64(li->second.value.i):0;
                double mean=0,var2=0;
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); mean+=(it!=t->container->end())?it->second.value.d:0.0; }
                mean/=std::max(1,n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); double d=((it!=t->container->end())?it->second.value.d:0.0)-mean; var2+=d*d; }
                double std_val=std::sqrt(var2/std::max(1,n)); if(std_val<1e-12) std_val=1.0;
                auto* out=new Container((Runnable*)runner,Type::LIST); (*out->container)["__len__"]=Value(n);
                for (int i=0;i<n;i++) { auto it=t->container->find(std::to_string(i)); double v=(it!=t->container->end())?it->second.value.d:0.0; (*out->container)[std::to_string(i)]=Value((v-mean)/std_val); }
                return Value((Collectable*)out);
            }
            return NONE_VALUE;
        }
        // =====================================================================
        // NYTORCH AGENT NETWORK: REGISTER NEW BUILTINS IN MODULE
        // =====================================================================
        if (name == "agent_net" || name == "agent_io") {
            registerBuiltin("tensor_save"); registerBuiltin("tensor_load");
            registerBuiltin("model_save");  registerBuiltin("model_load");
            registerBuiltin("kv_set"); registerBuiltin("kv_get");
            registerBuiltin("kv_del"); registerBuiltin("kv_keys"); registerBuiltin("kv_all");
            registerBuiltin("http_post_json"); registerBuiltin("http_get_json");
            registerBuiltin("agent_broadcast"); registerBuiltin("agent_listen");
            registerBuiltin("agent_send"); registerBuiltin("agent_recv");
                registerBuiltin("tcp_server_create"); registerBuiltin("tcp_accept"); registerBuiltin("tcp_connect");
                registerBuiltin("tcp_send"); registerBuiltin("tcp_recv"); registerBuiltin("tcp_recv_all"); registerBuiltin("tcp_close");
                registerBuiltin("http_respond"); registerBuiltin("http_parse_request");
            registerBuiltin("fs_mkdirs"); registerBuiltin("fs_stat"); registerBuiltin("fs_walk");
            registerBuiltin("path_join"); registerBuiltin("path_basename");
            registerBuiltin("path_dirname"); registerBuiltin("path_ext");
            registerBuiltin("read_bytes"); registerBuiltin("write_bytes");
            return NONE_VALUE;
        }

        if (name == "println" || name == "print") {
            for (size_t i = 0; i < args.size(); i++) {
                if (i > 0) std::cout << " ";
                printValue(args[i]);
            }
            std::cout << std::endl;
            return NONE_VALUE;
        }
        if (name == "range") {
            int start = 0, stop = 0, step = 1;
            if (args.size() == 1) {
                stop = static_cast<int>(bigint_to_i64(args[0].value.i));
            } else if (args.size() >= 2) {
                start = static_cast<int>(bigint_to_i64(args[0].value.i));
                stop = static_cast<int>(bigint_to_i64(args[1].value.i));
            }
            if (args.size() >= 3) {
                step = static_cast<int>(bigint_to_i64(args[2].value.i));
                if (step == 0) step = 1;
            }
            Object* result = new Object((Runnable*)runner, "list", Type::LIST);
            int idx = 0;
            if (step > 0) {
                for (int i = start; i < stop; i += step)
                    result->set(std::to_string(idx++), Value(i));
            } else {
                for (int i = start; i > stop; i += step)
                    result->set(std::to_string(idx++), Value(i));
            }
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "len" || name == "sizeof") {
            // Check for __len__ dunder method on instances
            if (args.size() >= 1 && args[0].type == ValueType::USERDATA && args[0].value.p 
                && !E.string_ptrs_.count(args[0].value.p)
                && instance_to_class.count(args[0].value.p)) {
                std::vector<Value> no_args;
                Value result = callMethod(args[0], "__len__", no_args, ctx);
                if (result.type != ValueType::NONE) return result;
            }
            if (args.size() >= 1) {
                if (args[0].type == ValueType::COLLECTABLE || args[0].isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        auto it = cont->container->find("__len__");
                        if (it != cont->container->end()) return it->second;
                        return Value(cont->size());
                    }
                }
                // String length: count UTF-8 characters, not bytes
                if (args[0].type == ValueType::USERDATA && args[0].value.p) {
                    std::string s = getStringValue(args[0]);
                    int char_count = 0;
                    for (size_t i = 0; i < s.size(); ) {
                        unsigned char c = (unsigned char)s[i];
                        if (c < 0x80) i += 1;
                        else if ((c & 0xE0) == 0xC0) i += 2;
                        else if ((c & 0xF0) == 0xE0) i += 3;
                        else if ((c & 0xF8) == 0xF0) i += 4;
                        else i += 1;
                        char_count++;
                    }
                    return Value(char_count);
                }
            }
            return Value(0);
        }
        if (name == "type" || name == "typeof") {
            if (args.size() >= 1) {
                // Check collectables (lists, maps)
                if (args[0].type == ValueType::COLLECTABLE && args[0].value.gc) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        if (cont->container->count("__set__")) return makeStringValue("set");
                        if (cont->container->count("__gen__")) return makeStringValue("generator");
                        if (cont->container->count("__len__")) return makeStringValue("list");
                        auto type_it = cont->container->find("__type__");
                        if (type_it != cont->container->end()) {
                            return makeStringValue(getStringValue(type_it->second));
                        }
                        return makeStringValue("map");
                    }
                    return makeStringValue("object");
                }
                // Check userdata (strings, functions, classes, instances)
                if (args[0].type == ValueType::USERDATA && args[0].value.p) {
                    // String pointer check first
                    if (E.string_ptrs_.count(args[0].value.p))
                        return makeStringValue("string");
                    auto fit = func_names.find(args[0].value.p);
                    if (fit != func_names.end()) {
                        if (fit->second.find("__func__:") == 0 || fit->second.find("__lambda__") == 0) return makeStringValue("function");
                        if (fit->second.find("__builtin__:") == 0) return makeStringValue("builtin");
                        if (fit->second.find("__class__:") == 0) return makeStringValue("class");
                        if (fit->second.find("__instance__:") == 0) return makeStringValue(fit->second.substr(13));
                    }
                    return makeStringValue("string");
                }
                switch (args[0].type) {
                    case ValueType::NONE: return makeStringValue("none");
                    case ValueType::BOOLEAN: return makeStringValue("bool");
                    case ValueType::INTEGER: return makeStringValue("int");
                    case ValueType::DOUBLE: return makeStringValue("float");
                    default: return makeStringValue("unknown");
                }
            }
            return NONE_VALUE;
        }
        if (name == "str") {
            if (args.size() >= 1) {
                if (args[0].type == ValueType::INTEGER) return makeStringValue(args[0].value.i.toString());
                if (args[0].type == ValueType::DOUBLE) {
                    return makeStringValue(args[0].toString());
                }
                if (args[0].type == ValueType::BOOLEAN) return makeStringValue(args[0].value.b ? "true" : "false");
                if (args[0].type == ValueType::NONE) return makeStringValue("none");
                if (args[0].type == ValueType::COLLECTABLE && args[0].value.gc) {
                    auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                    if (cont && cont->container) {
                        auto len_it = cont->container->find("__len__");
                        if (len_it != cont->container->end()) {
                            int len = (int)bigint_to_i64(len_it->second.value.i);
                            bool is_tup = cont->container->count("__tuple__") > 0;
                            bool is_set = cont->container->count("__set__") > 0;
                            std::string open_br  = is_tup ? "(" : (is_set ? "{" : "[");
                            std::string close_br = is_tup ? ")" : (is_set ? "}" : "]");
                            std::string result = open_br;
                            for (int i = 0; i < len; i++) {
                                if (i > 0) result += ", ";
                                auto eit = cont->container->find(std::to_string(i));
                                if (eit != cont->container->end()) {
                                    Value& elem = eit->second;
                                    bool is_str_elem = elem.type == ValueType::USERDATA && elem.value.p
                                        && !func_names.count(elem.value.p)
                                        && !instance_to_class.count(elem.value.p);
                                    if (is_str_elem) {
                                        result += "'" + getStringValue(elem) + "'";
                                    } else {
                                        std::vector<Value> sa = {elem};
                                        Value sv = callBuiltin("str", sa, ctx);
                                        result += getStringValue(sv);
                                    }
                                }
                            }
                            if (is_tup && len == 1) result += ",";
                            return makeStringValue(result + close_br);
                        } else {
                            std::string result = "{";
                            bool first = true;
                            for (auto& [k, v] : *cont->container) {
                                if (k == "__len__") continue;
                                if (!first) result += ", ";
                                std::vector<Value> sa = {v};
                                result += k + ": " + getStringValue(callBuiltin("str", sa, ctx));
                                first = false;
                            }
                            return makeStringValue(result + "}");
                        }
                    }
                }
                if (args[0].type == ValueType::USERDATA && args[0].value.p) {
                    // String pointer check first — prevent collision with instance maps
                    if (E.string_ptrs_.count(args[0].value.p)) {
                        return args[0]; // already a string Value
                    }
                    // Check for __str__/__repr__ method on class instances
                    if (instance_to_class.count(args[0].value.p)) {
                        std::vector<Value> str_args;
                        // Try __str__ first
                        try {
                            Value result = callMethod(args[0], "__str__", str_args, ctx);
                            if (!result.isNone()) return result;
                        } catch (nython::node::ReturnSignal& rs) { return rs.value; }
                          catch (...) {}
                        // Try __repr__ as fallback
                        try {
                            Value result = callMethod(args[0], "__repr__", str_args, ctx);
                            if (!result.isNone()) return result;
                        } catch (...) {}
                        // Default: <ClassName instance>
                        auto cit = instance_to_class.find(args[0].value.p);
                        if (cit != instance_to_class.end()) {
                            for (auto& [cn, cp] : class_by_name) {
                                if (cp == cit->second)
                                    return makeStringValue("<" + cn + " instance>");
                            }
                        }
                        return makeStringValue("<instance>");
                    }
                    return args[0];
                }
            }
            return makeStringValue("");
        }
        if (name == "int") {
            if (args.empty()) return Value(0);
            if (args[0].type == ValueType::INTEGER) return args[0];
            if (args[0].type == ValueType::DOUBLE) return Value(static_cast<int>(args[0].value.d));
            if (args[0].type == ValueType::BOOLEAN) return Value(args[0].value.b ? 1 : 0);
            if (args[0].type == ValueType::USERDATA || args[0].isCollectable()) {
                std::string s = getStringValue(args[0]);
                int base = 10;
                if (args.size() >= 2 && args[1].type == ValueType::INTEGER)
                    base = static_cast<int>(bigint_to_i64(args[1].value.i));
                if (s.size() > 2 && s[0] == '0') {
                    if ((s[1] == 'x' || s[1] == 'X') && base == 10) base = 16;
                    if ((s[1] == 'b' || s[1] == 'B') && base == 10) base = 2;
                    if ((s[1] == 'o' || s[1] == 'O') && base == 10) base = 8;
                    if (base != 10 && (s[1] == 'x' || s[1] == 'X' || s[1] == 'b' || s[1] == 'B' || s[1] == 'o' || s[1] == 'O'))
                        s = s.substr(2);
                }
                try {
                    size_t idx = 0;
                    long long iv = std::stoll(s, &idx, base);
                    if (idx != s.size()) throw std::invalid_argument("not fully consumed");
                    return Value(static_cast<int>(iv));
                }
                catch (...) { throw std::string("__exc__:ValueError:invalid literal for int(): '" + s + "'"); }
            }
            return args[0];
        }
        if (name == "float") {
            if (args.size() >= 1) {
                if (args[0].type == ValueType::INTEGER) return Value((double)bigint_to_i64(args[0].value.i));
                if (args[0].type == ValueType::DOUBLE) return args[0];
                if (args[0].type == ValueType::BOOLEAN) return Value(args[0].value.b ? 1.0 : 0.0);
                // String -> double
                std::string s = getStringValue(args[0]);
                try { return Value(std::stod(s)); }
                catch (...) { throw std::string("__exc__:ValueError:could not convert string to float: '" + s + "'"); }
            }
            return Value(0.0);
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
        if (name == "min") {
            if (args.empty()) return NONE_VALUE;
            if (args.size() == 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    if (len == 0) return NONE_VALUE;
                    Value best = cont->container->at("0");
                    for (int i = 1; i < len; i++) {
                        Value v = cont->container->at(std::to_string(i));
                        double vd = (v.type == ValueType::DOUBLE) ? (double)v.value.d : (double)bigint_to_i64(v.value.i);
                        double bd = (best.type == ValueType::DOUBLE) ? (double)best.value.d : (double)bigint_to_i64(best.value.i);
                        if (vd < bd) best = v;
                    }
                    return best;
                }
            }
            Value best = args[0];
            for (size_t i = 1; i < args.size(); i++) {
                double ad = (args[i].type == ValueType::DOUBLE) ? (double)args[i].value.d : (double)bigint_to_i64(args[i].value.i);
                double bd = (best.type == ValueType::DOUBLE) ? (double)best.value.d : (double)bigint_to_i64(best.value.i);
                if (ad < bd) best = args[i];
            }
            return best;
        }
        if (name == "max") {
            if (args.empty()) return NONE_VALUE;
            if (args.size() == 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    if (len == 0) return NONE_VALUE;
                    Value best = cont->container->at("0");
                    for (int i = 1; i < len; i++) {
                        Value v = cont->container->at(std::to_string(i));
                        double vd = (v.type == ValueType::DOUBLE) ? (double)v.value.d : (double)bigint_to_i64(v.value.i);
                        double bd = (best.type == ValueType::DOUBLE) ? (double)best.value.d : (double)bigint_to_i64(best.value.i);
                        if (vd > bd) best = v;
                    }
                    return best;
                }
            }
            Value best = args[0];
            for (size_t i = 1; i < args.size(); i++) {
                double ad = (args[i].type == ValueType::DOUBLE) ? (double)args[i].value.d : (double)bigint_to_i64(args[i].value.i);
                double bd = (best.type == ValueType::DOUBLE) ? (double)best.value.d : (double)bigint_to_i64(best.value.i);
                if (ad > bd) best = args[i];
            }
            return best;
        }
        if (name == "enumerate") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                int start = (args.size() >= 2 && args[1].type == ValueType::INTEGER) ? static_cast<int>(bigint_to_i64(args[1].value.i)) : 0;
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            Object* pair = new Object((Runnable*)runner, "list", Type::LIST);
                            pair->set("0", Value(i + start));
                            pair->set("1", it->second);
                            pair->set("__len__", Value(2));
                            result->set(std::to_string(i), Value((Collectable*)pair));
                        }
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "zip") {
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* c1 = dynamic_cast<Container*>(args[0].value.gc);
                auto* c2 = dynamic_cast<Container*>(args[1].value.gc);
                if (c1 && c2 && c1->container && c2->container) {
                    auto l1 = c1->container->find("__len__");
                    auto l2 = c2->container->find("__len__");
                    int len1 = l1 != c1->container->end() ? (int)bigint_to_i64(l1->second.value.i) : 0;
                    int len2 = l2 != c2->container->end() ? (int)bigint_to_i64(l2->second.value.i) : 0;
                    int len = std::min(len1, len2);
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        Object* pair = new Object((Runnable*)runner, "tuple", Type::LIST);
                        auto i1 = c1->container->find(std::to_string(i));
                        auto i2 = c2->container->find(std::to_string(i));
                        if (i1 != c1->container->end()) pair->set("0", i1->second);
                        if (i2 != c2->container->end()) pair->set("1", i2->second);
                        pair->set("__len__", Value(2));
                        pair->set("__tuple__", Value(1));
                        result->set(std::to_string(i), Value((Collectable*)pair));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "sorted") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    std::vector<Value> vals;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) vals.push_back(it->second);
                    }
                    // Detect key and reverse from args[1..] via CALL_KW convention
                    // key=lambda arrives as args[1] if callable; reverse=true as args[2] or args[1] if bool
                    Value key_fn; bool has_key = false;
                    bool rev = false;
                    for (size_t ki = 1; ki < args.size(); ki++) {
                        Value& av = args[ki];
                        bool is_callable = (av.type == ValueType::USERDATA && av.value.p && func_names.count(av.value.p));
                        if (is_callable && !has_key) { key_fn = av; has_key = true; }
                        else if (av.type == ValueType::BOOLEAN) rev = av.value.b;
                        else if (av.type == ValueType::INTEGER && bigint_to_i64(av.value.i) == 1 && !has_key) rev = true;
                    }
                    // Compute key values
                    std::vector<Value> keys;
                    if (has_key) {
                        for (auto& v : vals) {
                            std::vector<Value> kargs = {v};
                            keys.push_back(callFunctionValue(key_fn, kargs, ctx));
                        }
                    }
                    // Sort indices
                    std::vector<int> idx_order(vals.size());
                    std::iota(idx_order.begin(), idx_order.end(), 0);
                    std::stable_sort(idx_order.begin(), idx_order.end(), [&](int a2, int b2) {
                        const Value& ka = has_key ? keys[a2] : vals[a2];
                        const Value& kb = has_key ? keys[b2] : vals[b2];
                        if (ka.type == ValueType::INTEGER && kb.type == ValueType::INTEGER)
                            return bigint_to_i64(ka.value.i) < bigint_to_i64(kb.value.i);
                        if (ka.type == ValueType::DOUBLE && kb.type == ValueType::DOUBLE) return ka.value.d < kb.value.d;
                        if (ka.type == ValueType::INTEGER && kb.type == ValueType::DOUBLE) return (double)bigint_to_i64(ka.value.i) < kb.value.d;
                        if (ka.type == ValueType::DOUBLE && kb.type == ValueType::INTEGER) return ka.value.d < (double)bigint_to_i64(kb.value.i);
                        if (ka.type == ValueType::USERDATA && kb.type == ValueType::USERDATA) return getStringValue(ka) < getStringValue(kb);
                        return ka.toString() < kb.toString();
                    });
                    if (rev) std::reverse(idx_order.begin(), idx_order.end());
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (size_t i = 0; i < idx_order.size(); i++) result->set(std::to_string(i), vals[idx_order[i]]);
                    result->set("__len__", Value(static_cast<int>(idx_order.size())));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "reversed") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(len - 1 - i));
                        if (it != cont->container->end()) result->set(std::to_string(i), it->second);
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "sum") {
            double total = 0; int has_float = 0;
            if (args.size() >= 2) {
                if (args[1].type == ValueType::DOUBLE) { total = args[1].value.d; has_float = 1; }
                else if (args[1].type == ValueType::INTEGER) total = static_cast<double>(bigint_to_i64(args[1].value.i));
            }
            if (!args.empty() && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    int len = (li != cont->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            if (it->second.type == ValueType::DOUBLE) { total += it->second.value.d; has_float = 1; }
                            else if (it->second.type == ValueType::INTEGER) total += static_cast<double>(bigint_to_i64(it->second.value.i));
                        }
                    }
                }
            }
            if (has_float) return Value(total);
            return Value(static_cast<int>(total));
        }
        if (name == "input") {
            if (args.size() >= 1) std::cout << getStringValue(args[0]);
            std::string line;
            std::getline(std::cin, line);
            return makeStringValue(line);
        }
        if (name == "round_DISABLED_OLD") {
            if (args.size() >= 1 && args[0].type == ValueType::DOUBLE)
                return Value((int)std::round(args[0].value.d));
            return args.size() ? args[0] : Value(0);
        }
        if (name == "pow") {
            if (args.size() >= 2) {
                double base = (args[0].type == ValueType::DOUBLE) ? static_cast<double>(args[0].value.d) : (double)bigint_to_i64(args[0].value.i);
                double exp = (args[1].type == ValueType::DOUBLE) ? static_cast<double>(args[1].value.d) : (double)bigint_to_i64(args[1].value.i);
                return Value(std::pow(base, exp));
            }
            return Value(0);
        }
        if (name == "hex") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                std::stringstream ss; ss << "0x" << std::hex << bigint_to_i64(args[0].value.i);
                return makeStringValue(ss.str());
            }
            return makeStringValue("0x0");
        }
        if (name == "oct") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                std::stringstream ss; ss << "0o" << std::oct << bigint_to_i64(args[0].value.i);
                return makeStringValue(ss.str());
            }
            return makeStringValue("0o0");
        }
        if (name == "bin") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                int64_t n = bigint_to_i64(args[0].value.i);
                std::string r = "0b";
                if (n == 0) r += "0";
                else { std::string bits; int64_t v = n < 0 ? -n : n; while(v){bits=(char)('0'+(v&1))+bits;v>>=1;} if(n<0)r+="-"; r+=bits; }
                return makeStringValue(r);
            }
            return makeStringValue("0b0");
        }
        if (name == "chr") {
            if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                return makeStringValue(std::string(1, (char)bigint_to_i64(args[0].value.i)));
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
        if (name == "isinstance") {
            if (args.size() >= 2) {
                // Extract type name: handle builtin funcs (int, str, float...) and class objects
                std::string type_name;
                if (args[1].type == ValueType::USERDATA && args[1].value.p) {
                    // Check if it's a string first
                    if (E.string_ptrs_.count(args[1].value.p)) {
                        type_name = *static_cast<std::string*>(args[1].value.p);
                    } else {
                        auto fit = func_names.find(args[1].value.p);
                        if (fit != func_names.end()) {
                            if (fit->second.find("__builtin__:") == 0)
                                type_name = fit->second.substr(12);
                            else if (fit->second.find("__class__:") == 0)
                                type_name = fit->second.substr(10);
                            else
                                type_name = getStringValue(args[1]);
                        } else {
                            type_name = getStringValue(args[1]);
                        }
                    }
                } else {
                    type_name = getStringValue(args[1]);
                }
                if (type_name == "int" || type_name == "integer") return Value(args[0].type == ValueType::INTEGER);
                if (type_name == "float" || type_name == "double") return Value(args[0].type == ValueType::DOUBLE);
                if (type_name == "bool" || type_name == "boolean") return Value(args[0].type == ValueType::BOOLEAN);
                if (type_name == "str" || type_name == "string") {
                    // Positive string pointer check first
                    if (args[0].type == ValueType::USERDATA && args[0].value.p
                        && E.string_ptrs_.count(args[0].value.p))
                        return Value(true);
                    if (args[0].isCollectable() && args[0].value.gc) {
                        Type t = args[0].value.gc->getType();
                        if (t == Type::STRING) return Value(true);
                    }
                    // Also check if it's a USERDATA string (our runtime representation)
                    if (args[0].type == ValueType::USERDATA && args[0].value.p) {
                        auto fit = func_names.find(args[0].value.p);
                        if (fit == func_names.end() && !instance_to_class.count(args[0].value.p))
                            return Value(true);
                    }
                    return Value(false);
                }
                if (type_name == "list" || type_name == "array") {
                    if (args[0].isCollectable() && args[0].value.gc) {
                        Type t = args[0].value.gc->getType();
                        if (t == Type::LIST || t == Type::ARRAY) return Value(true);
                    }
                    // Check via __len__ key (our list representation)
                    if (args[0].isCollectable() && args[0].value.gc) {
                        auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                        if (cont && cont->container && cont->container->count("__len__"))
                            return Value(true);
                    }
                    return Value(false);
                }
                if (type_name == "map" || type_name == "dict") {
                    if (args[0].isCollectable() && args[0].value.gc) {
                        return Value(args[0].value.gc->getType() == Type::MAP);
                    }
                    return Value(false);
                }
                if (type_name == "none") return Value(args[0].type == ValueType::NONE);
                if (type_name == "function") return Value(args[0].type == ValueType::USERDATA && args[0].value.p && !E.string_ptrs_.count(args[0].value.p) && func_names.count(args[0].value.p));
                // Check class instances (user-defined classes) — type_name is the class name
                if (args[0].type == ValueType::USERDATA && args[0].value.p && !E.string_ptrs_.count(args[0].value.p)) {
                    auto cit2 = instance_to_class.find(args[0].value.p);
                    if (cit2 != instance_to_class.end()) {
                        void* walk_cls = cit2->second;
                        while (walk_cls) {
                            for (auto& kv : class_by_name) {
                                if (kv.second == walk_cls && kv.first == type_name) return Value(true);
                            }
                            auto pit2 = class_parent.find(walk_cls);
                            if (pit2 != class_parent.end()) {
                                auto par = class_by_name.find(pit2->second);
                                if (par != class_by_name.end()) { walk_cls = par->second; continue; }
                            }
                            break;
                        }
                    }
                }
            }
            return Value(false);
        }
        if (name == "display" || name == "show") {
            // Print and return value (usable in lambdas)
            for (size_t i = 0; i < args.size(); i++) {
                if (i > 0) std::cout << " ";
                if (args[i].type == ValueType::USERDATA)
                    std::cout << getStringValue(args[i]);
                else
                    std::cout << args[i].toString();
            }
            std::cout << std::endl;
            return args.empty() ? NONE_VALUE : args[0];
        }
        if (name == "typeof_val" || name == "is_int" || name == "is_float" || name == "is_string" || name == "is_list" || name == "is_dict" || name == "is_none" || name == "is_bool") {
            if (!args.empty()) {
                if (name == "is_int") return Value(args[0].type == ValueType::INTEGER);
                if (name == "is_float") return Value(args[0].type == ValueType::DOUBLE);
                if (name == "is_string") return Value(args[0].type == ValueType::USERDATA);
                if (name == "is_none") return Value(args[0].type == ValueType::NONE);
                if (name == "is_bool") return Value(args[0].type == ValueType::BOOLEAN);
                if (name == "is_list") return Value(args[0].isCollectable());
                if (name == "is_dict") return Value(args[0].isCollectable());
            }
            return Value(false);
        }
        if (name == "to_int") {
            if (!args.empty()) {
                if (args[0].type == ValueType::INTEGER) return args[0];
                if (args[0].type == ValueType::DOUBLE) return Value(static_cast<int>(args[0].value.d));
                if (args[0].type == ValueType::BOOLEAN) return Value(args[0].value.b ? 1 : 0);
                if (args[0].type == ValueType::USERDATA) {
                    try { return Value(std::stoi(getStringValue(args[0]))); } catch(...) { return Value(0); }
                }
            }
            return Value(0);
        }
        if (name == "to_float") {
            if (!args.empty()) {
                if (args[0].type == ValueType::DOUBLE) return args[0];
                if (args[0].type == ValueType::INTEGER) return Value(static_cast<double>(bigint_to_i64(args[0].value.i)));
                if (args[0].type == ValueType::USERDATA) {
                    try { return Value(std::stod(getStringValue(args[0]))); } catch(...) { return Value(0.0); }
                }
            }
            return Value(0.0);
        }
        if (name == "to_str") {
            if (!args.empty()) {
                if (args[0].type == ValueType::USERDATA) return args[0];
                return makeStringValue(args[0].toString());
            }
            return makeStringValue("");
        }
        if (name == "clamp") {
            // clamp(value, min, max)
            if (args.size() >= 3) {
                double v = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double lo = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                double hi = args[2].type == ValueType::DOUBLE ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
                if (v < lo) v = lo;
                if (v > hi) v = hi;
                if (args[0].type == ValueType::INTEGER) return Value(static_cast<int>(v));
                return Value(v);
            }
            return args.empty() ? NONE_VALUE : args[0];
        }
        if (name == "lerp") {
            // Linear interpolation: lerp(a, b, t) = a + (b-a)*t
            if (args.size() >= 3) {
                double a = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double b = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                double t = args[2].type == ValueType::DOUBLE ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
                return Value(a + (b - a) * t);
            }
            return Value(0.0);
        }
        if (name == "map_range") {
            // Map value from one range to another
            if (args.size() >= 5) {
                double v = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double in_lo = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                double in_hi = args[2].type == ValueType::DOUBLE ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
                double out_lo = args[3].type == ValueType::DOUBLE ? (double)args[3].value.d : (double)bigint_to_i64(args[3].value.i);
                double out_hi = args[4].type == ValueType::DOUBLE ? (double)args[4].value.d : (double)bigint_to_i64(args[4].value.i);
                double t = (v - in_lo) / (in_hi - in_lo);
                return Value(out_lo + (out_hi - out_lo) * t);
            }
            return Value(0.0);
        }
        if (name == "repeat_str") {
            // repeat_str("abc", 3) -> "abcabcabc" (lambda-safe string repeat)
            if (args.size() >= 2) {
                std::string s = getStringValue(args[0]);
                int n = (int)bigint_to_i64(args[1].value.i);
                std::string result;
                for (int i = 0; i < n; i++) result += s;
                return makeStringValue(result);
            }
            return makeStringValue("");
        }
        if (name == "flat" || name == "flatten") {
            // Flatten a list of lists into a single list
            if (!args.empty() && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto li = cont->container->find("__len__");
                    int len = (li != cont->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            if (it->second.isCollectable()) {
                                auto* inner = dynamic_cast<Container*>(it->second.value.gc);
                                if (inner && inner->container) {
                                    auto il = inner->container->find("__len__");
                                    int ilen = (il != inner->container->end()) ? (int)bigint_to_i64(il->second.value.i) : 0;
                                    for (int j = 0; j < ilen; j++) {
                                        auto jt = inner->container->find(std::to_string(j));
                                        if (jt != inner->container->end())
                                            result->set(std::to_string(idx++), jt->second);
                                    }
                                }
                            } else {
                                result->set(std::to_string(idx++), it->second);
                            }
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "callable") { return Value(args.size() >= 1 && args[0].type == ValueType::USERDATA); }
        if (name == "hash") {
            if (args.size() >= 1) return Value((int)std::hash<std::string>{}(args[0].toString()));
            return Value(0);
        }
        if (name == "repr") {
            if (args.empty()) return makeStringValue("none");
            Value v = args[0];
            // Check for __repr__ method on instances
            if (v.type == ValueType::USERDATA && v.value.p && instance_to_class.count(v.value.p)) {
                std::vector<Value> no_args;
                Value result = callMethod(v, "__repr__", no_args, ctx);
                if (result.type != ValueType::NONE) return result;
                // Fall back to __str__
                result = callMethod(v, "__str__", no_args, ctx);
                if (result.type != ValueType::NONE) return result;
            }
            if (v.type == ValueType::INTEGER) return makeStringValue(std::to_string(bigint_to_i64(v.value.i)));
            if (v.type == ValueType::DOUBLE) return makeStringValue(std::to_string(static_cast<double>(v.value.d)));
            if (v.type == ValueType::BOOLEAN) return makeStringValue(v.value.b ? "true" : "false");
            if (v.isNone()) return makeStringValue("none");
            if (isStringValue(v)) return makeStringValue("\"" + getStringValue(v) + "\"");
            // Collections
            std::vector<Value> str_args = {v};
            return callBuiltin("str", str_args, ctx);
        }
        if (name == "sorted") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    std::vector<Value> vals;
                    int len = cont->size();
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) vals.push_back(it->second);
                    }
                    std::sort(vals.begin(), vals.end(), [](const Value& a, const Value& b) {
                        if (a.type == ValueType::INTEGER && b.type == ValueType::INTEGER)
                            return a.value.i < b.value.i;
                        return false;
                    });
                    auto* list = new Object(runner, "sorted_list", Type::LIST);
                    for (size_t i = 0; i < vals.size(); i++)
                        list->set(std::to_string(i), vals[i]);
                    list->set("__len__", Value((int)vals.size()));
                    return Value((Collectable*)list);
                }
            }
            return args.size() ? args[0] : NONE_VALUE;
        }
        if (name == "reversed") {
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    int len = cont->size();
                    auto* list = new Object(runner, "rev_list", Type::LIST);
                    for (int i = len - 1; i >= 0; i--) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end())
                            list->set(std::to_string(len - 1 - i), it->second);
                    }
                    list->set("__len__", Value(len));
                    return Value((Collectable*)list);
                }
            }
            return args.size() ? args[0] : NONE_VALUE;
        }
    // ── from main.cpp lines 5288–5616 ──────────────────────────────────────────
        if (name == "tensor" || name == "Tensor") {
            // Create a tensor (1D array of floats)
            if (!args.empty() && args[0].isCollectable()) {
                auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    Object* tensor = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) {
                            double val = 0;
                            if (it->second.type == ValueType::INTEGER) val = static_cast<double>(bigint_to_i64(it->second.value.i));
                            else if (it->second.type == ValueType::DOUBLE) val = static_cast<double>(it->second.value.d);
                            tensor->set(std::to_string(i), Value(val));
                        }
                    }
                    tensor->set("__len__", Value(len));
                    tensor->set("__type__", makeStringValue("tensor"));
                    return Value((Collectable*)tensor);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_add" || name == "tensor_sub" || name == "tensor_mul" || name == "tensor_dot") {
            // Element-wise tensor operations
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* a = dynamic_cast<Container*>(args[0].value.gc);
                auto* b = dynamic_cast<Container*>(args[1].value.gc);
                if (a && b && a->container && b->container) {
                    auto al = a->container->find("__len__");
                    int len = (al != a->container->end()) ? static_cast<int>(bigint_to_i64(al->second.value.i)) : 0;
                    if (name == "tensor_dot") {
                        // Dot product
                        double sum = 0;
                        for (int i = 0; i < len; i++) {
                            auto ai = a->container->find(std::to_string(i));
                            auto bi = b->container->find(std::to_string(i));
                            if (ai != a->container->end() && bi != b->container->end()) {
                                double va = ai->second.type == ValueType::DOUBLE ? static_cast<double>(ai->second.value.d) : static_cast<double>(bigint_to_i64(ai->second.value.i));
                                double vb = bi->second.type == ValueType::DOUBLE ? static_cast<double>(bi->second.value.d) : static_cast<double>(bigint_to_i64(bi->second.value.i));
                                sum += va * vb;
                            }
                        }
                        return Value(sum);
                    }
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto ai = a->container->find(std::to_string(i));
                        auto bi = b->container->find(std::to_string(i));
                        double va = (ai != a->container->end()) ? (ai->second.type == ValueType::DOUBLE ? static_cast<double>(ai->second.value.d) : static_cast<double>(bigint_to_i64(ai->second.value.i))) : 0;
                        double vb = (bi != b->container->end()) ? (bi->second.type == ValueType::DOUBLE ? static_cast<double>(bi->second.value.d) : static_cast<double>(bigint_to_i64(bi->second.value.i))) : 0;
                        double r = 0;
                        if (name == "tensor_add") r = va + vb;
                        else if (name == "tensor_sub") r = va - vb;
                        else if (name == "tensor_mul") r = va * vb;
                        result->set(std::to_string(i), Value(r));
                    }
                    result->set("__len__", Value(len));
                    result->set("__type__", makeStringValue("tensor"));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_sum" || name == "tensor_mean" || name == "tensor_max" || name == "tensor_min") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    double sum = 0, mn = 1e308, mx = -1e308;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) {
                            double v = it->second.type == ValueType::DOUBLE ? static_cast<double>(it->second.value.d) : static_cast<double>(bigint_to_i64(it->second.value.i));
                            sum += v;
                            if (v < mn) mn = v;
                            if (v > mx) mx = v;
                        }
                    }
                    if (name == "tensor_sum") return Value(sum);
                    if (name == "tensor_mean") return Value(len > 0 ? sum / len : 0.0);
                    if (name == "tensor_max") return Value(mx);
                    if (name == "tensor_min") return Value(mn);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_scale") {
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                double scale = args[1].type == ValueType::DOUBLE ? static_cast<double>(args[1].value.d) : static_cast<double>(bigint_to_i64(args[1].value.i));
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? static_cast<double>(it->second.value.d) : 0;
                        result->set(std::to_string(i), Value(v * scale));
                    }
                    result->set("__len__", Value(len));
                    result->set("__type__", makeStringValue("tensor"));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_apply") {
            // Apply a function to each element: tensor_apply(t, fn)
            if (args.size() >= 2 && args[0].isCollectable() && args[1].type == ValueType::USERDATA) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) {
                            std::vector<Value> ca = {it->second};
                            result->set(std::to_string(i), callFunctionValue(args[1], ca, ctx));
                        }
                    }
                    result->set("__len__", Value(len));
                    result->set("__type__", makeStringValue("tensor"));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "relu" || name == "sigmoid" || name == "tanh_fn") {
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? static_cast<double>(args[0].value.d) : static_cast<double>(bigint_to_i64(args[0].value.i));
                if (name == "relu") return Value(x > 0 ? x : 0.0);
                if (name == "sigmoid") return Value(1.0 / (1.0 + std::exp(-x)));
                if (name == "tanh_fn") return Value(std::tanh(x));
            }
            return Value(0.0);
        }
        // ===================== NYTORCH MATRIX OPS =====================
        if (name == "matrix" || name == "mat") {
            // Create a 2D matrix from list of lists: matrix([[1,2],[3,4]])
            if (!args.empty() && args[0].isCollectable()) {
                auto* rows_cont = dynamic_cast<Container*>(args[0].value.gc);
                if (rows_cont && rows_cont->container) {
                    auto ri = rows_cont->container->find("__len__");
                    int nrows = (ri != rows_cont->container->end()) ? static_cast<int>(bigint_to_i64(ri->second.value.i)) : 0;
                    Object* mat = new Object((Runnable*)runner, "matrix", Type::LIST);
                    int ncols = 0;
                    for (int r = 0; r < nrows; r++) {
                        auto row_it = rows_cont->container->find(std::to_string(r));
                        if (row_it != rows_cont->container->end() && row_it->second.isCollectable()) {
                            auto* row_cont = dynamic_cast<Container*>(row_it->second.value.gc);
                            if (row_cont && row_cont->container) {
                                auto ci = row_cont->container->find("__len__");
                                ncols = (ci != row_cont->container->end()) ? static_cast<int>(bigint_to_i64(ci->second.value.i)) : 0;
                                for (int c = 0; c < ncols; c++) {
                                    auto val_it = row_cont->container->find(std::to_string(c));
                                    double v = 0;
                                    if (val_it != row_cont->container->end()) {
                                        if (val_it->second.type == ValueType::DOUBLE) v = static_cast<double>(val_it->second.value.d);
                                        else if (val_it->second.type == ValueType::INTEGER) v = static_cast<double>(bigint_to_i64(val_it->second.value.i));
                                    }
                                    mat->set(std::to_string(r) + "," + std::to_string(c), Value(v));
                                }
                            }
                        }
                    }
                    mat->set("__rows__", Value(nrows));
                    mat->set("__cols__", Value(ncols));
                    mat->set("__type__", makeStringValue("matrix"));
                    return Value((Collectable*)mat);
                }
            }
            return NONE_VALUE;
        }
        if (name == "mat_mul") {
            // Matrix multiply: mat_mul(A, B)
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* A = dynamic_cast<Container*>(args[0].value.gc);
                auto* B = dynamic_cast<Container*>(args[1].value.gc);
                if (A && B && A->container && B->container) {
                    int ar = static_cast<int>(ny_mat_dim(A, "__rows__"));
                    int ac = static_cast<int>(ny_mat_dim(A, "__cols__"));
                    int br = static_cast<int>(ny_mat_dim(B, "__rows__"));
                    int bc = static_cast<int>(ny_mat_dim(B, "__cols__"));
                    if (ac != br) return NONE_VALUE;
                    Object* C = new Object((Runnable*)runner, "matrix", Type::LIST);
                    for (int i = 0; i < ar; i++) {
                        for (int j = 0; j < bc; j++) {
                            double sum = 0;
                            for (int k = 0; k < ac; k++) {
                                auto aik = A->container->find(std::to_string(i)+","+std::to_string(k));
                                auto bkj = B->container->find(std::to_string(k)+","+std::to_string(j));
                                double va = (aik != A->container->end()) ? static_cast<double>(aik->second.value.d) : 0;
                                double vb = (bkj != B->container->end()) ? static_cast<double>(bkj->second.value.d) : 0;
                                sum += va * vb;
                            }
                            C->set(std::to_string(i)+","+std::to_string(j), Value(sum));
                        }
                    }
                    C->set("__rows__", Value(ar));
                    C->set("__cols__", Value(bc));
                    C->set("__type__", makeStringValue("matrix"));
                    return Value((Collectable*)C);
                }
            }
            return NONE_VALUE;
        }
        if (name == "mat_transpose") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* M = dynamic_cast<Container*>(args[0].value.gc);
                if (M && M->container) {
                    int rows = static_cast<int>(ny_mat_dim(M, "__rows__"));
                    int cols = static_cast<int>(ny_mat_dim(M, "__cols__"));
                    if (rows < 0 || cols < 0) return NONE_VALUE;   // not a matrix
                    Object* T = new Object((Runnable*)runner, "matrix", Type::LIST);
                    for (int i = 0; i < rows; i++)
                        for (int j = 0; j < cols; j++) {
                            auto it = M->container->find(std::to_string(i)+","+std::to_string(j));
                            double v = (it != M->container->end()) ? static_cast<double>(it->second.value.d) : 0;
                            T->set(std::to_string(j)+","+std::to_string(i), Value(v));
                        }
                    T->set("__rows__", Value(cols));
                    T->set("__cols__", Value(rows));
                    T->set("__type__", makeStringValue("matrix"));
                    return Value((Collectable*)T);
                }
            }
            return NONE_VALUE;
        }
        if (name == "mat_get") {
            if (args.size() >= 3 && args[0].isCollectable()) {
                auto* M = dynamic_cast<Container*>(args[0].value.gc);
                if (M && M->container) {
                    int r = static_cast<int>(bigint_to_i64(args[1].value.i));
                    int c = static_cast<int>(bigint_to_i64(args[2].value.i));
                    auto it = M->container->find(std::to_string(r)+","+std::to_string(c));
                    if (it != M->container->end()) return it->second;
                }
            }
            return Value(0.0);
        }
        if (name == "mat_shape") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* M = dynamic_cast<Container*>(args[0].value.gc);
                if (M && M->container) {
                    auto ri = M->container->find("__rows__");
                    auto ci = M->container->find("__cols__");
                    Object* shape = new Object((Runnable*)runner, "list", Type::LIST);
                    shape->set("0", ri != M->container->end() ? ri->second : Value(0));
                    shape->set("1", ci != M->container->end() ? ci->second : Value(0));
                    shape->set("__len__", Value(2));
                    return Value((Collectable*)shape);
                }
            }
            return NONE_VALUE;
        }
        if (name == "zeros" || name == "ones" || name == "random_tensor") {
            // Create tensor filled with 0, 1, or random values
            if (!args.empty()) {
                int size = static_cast<int>(bigint_to_i64(args[0].value.i));
                Object* t = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < size; i++) {
                    double v = 0;
                    if (name == "ones") v = 1.0;
                    else if (name == "random_tensor") v = static_cast<double>(rand()) / RAND_MAX;
                    t->set(std::to_string(i), Value(v));
                }
                t->set("__len__", Value(size));
                t->set("__type__", makeStringValue("tensor"));
                return Value((Collectable*)t);
            }
            return NONE_VALUE;
        }
        if (name == "softmax" || name == "tensor_softmax") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    double max_val = -1e308, sum_exp = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) {
                            double v = it->second.type == ValueType::DOUBLE ? static_cast<double>(it->second.value.d) : static_cast<double>(bigint_to_i64(it->second.value.i));
                            if (v > max_val) max_val = v;
                        }
                    }
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (it->second.type == ValueType::DOUBLE ? static_cast<double>(it->second.value.d) : static_cast<double>(bigint_to_i64(it->second.value.i))) : 0;
                        double e = std::exp(v - max_val);
                        result->set(std::to_string(i), Value(e));
                        sum_exp += e;
                    }
                    for (int i = 0; i < len; i++) {
                        auto it = result->container->find(std::to_string(i));
                        if (it != result->container->end())
                            it->second = Value(static_cast<double>(it->second.value.d) / sum_exp);
                    }
                    result->set("__len__", Value(len));
                    result->set("__type__", makeStringValue("tensor"));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ===================== AGENT / KNOWLEDGE BASE =====================
        if (name == "kb_save") {
            // Save knowledge base to file: kb_save(filename, dict)
            if (args.size() >= 2) {
                std::string path = getStringValue(args[0]);
                std::string data = getStringValue(args[1]);
                std::ofstream f(path);
                if (f.is_open()) { f << data; f.close(); return Value(true); }
            }
            return Value(false);
        }
        if (name == "kb_load") {
            // Load knowledge base from file
            if (!args.empty()) {
                std::string path = getStringValue(args[0]);
                std::ifstream f(path);
                if (f.is_open()) {
                    std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
                    return makeStringValue(content);
                }
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 5618–6131 ──────────────────────────────────────────
        if (name == "tanh_act") {
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(std::tanh(x));
            }
            return Value(0.0);
        }
        if (name == "leaky_relu") {
            double alpha = (args.size() >= 2) ? (args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i)) : 0.01;
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x > 0 ? x : alpha * x);
            }
            return Value(0.0);
        }
        if (name == "softmax" || name == "tensor_softmax") {
            // softmax(tensor) -> tensor of probabilities
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double max_val = -1e308;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) {
                            double v = it->second.type == ValueType::DOUBLE ? (double)it->second.value.d : (double)bigint_to_i64(it->second.value.i);
                            if (v > max_val) max_val = v;
                        }
                    }
                    double sum_exp = 0;
                    std::vector<double> exps(len);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (it->second.type == ValueType::DOUBLE ? (double)it->second.value.d : (double)bigint_to_i64(it->second.value.i)) : 0;
                        exps[i] = std::exp(v - max_val);
                        sum_exp += exps[i];
                    }
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        result->set(std::to_string(i), Value(exps[i] / sum_exp));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_exp" || name == "tensor_log" || name == "tensor_sqrt" || name == "tensor_abs" || name == "tensor_neg") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        double r = 0;
                        if (name == "tensor_exp") r = std::exp(v);
                        else if (name == "tensor_log") r = (v > 0) ? std::log(v) : -1e308;
                        else if (name == "tensor_sqrt") r = (v >= 0) ? std::sqrt(v) : 0;
                        else if (name == "tensor_abs") r = std::abs(v);
                        else if (name == "tensor_neg") r = -v;
                        result->set(std::to_string(i), Value(r));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_pow") {
            // tensor_pow(tensor, exponent)
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                double exp_val = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(std::pow(v, exp_val)));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_matmul" || name == "matmul") {
            // matmul(A, B, rows_a, cols_a, cols_b) -> C
            // A is rows_a x cols_a, B is cols_a x cols_b, C is rows_a x cols_b
            // All stored as flat 1D tensors
            if (args.size() >= 5) {
                auto* a = dynamic_cast<Container*>(args[0].value.gc);
                auto* b = dynamic_cast<Container*>(args[1].value.gc);
                int ra = (int)bigint_to_i64(args[2].value.i);
                int ca = (int)bigint_to_i64(args[3].value.i);
                int cb = (int)bigint_to_i64(args[4].value.i);
                if (a && b && a->container && b->container) {
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int i = 0; i < ra; i++) {
                        for (int j = 0; j < cb; j++) {
                            double sum = 0;
                            for (int k = 0; k < ca; k++) {
                                auto ai = a->container->find(std::to_string(i * ca + k));
                                auto bj = b->container->find(std::to_string(k * cb + j));
                                double va = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                                double vb = (bj != b->container->end()) ? (double)bj->second.value.d : 0;
                                sum += va * vb;
                            }
                            result->set(std::to_string(idx++), Value(sum));
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_transpose") {
            // transpose(tensor, rows, cols) -> transposed tensor
            if (args.size() >= 3) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                int rows = (int)bigint_to_i64(args[1].value.i);
                int cols = (int)bigint_to_i64(args[2].value.i);
                if (t && t->container) {
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int j = 0; j < cols; j++) {
                        for (int i = 0; i < rows; i++) {
                            auto it = t->container->find(std::to_string(i * cols + j));
                            double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                            result->set(std::to_string(idx++), Value(v));
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_concat") {
            // Concatenate two tensors
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* a = dynamic_cast<Container*>(args[0].value.gc);
                auto* b = dynamic_cast<Container*>(args[1].value.gc);
                if (a && b && a->container && b->container) {
                    auto la = a->container->find("__len__");
                    auto lb = b->container->find("__len__");
                    int alen = (la != a->container->end()) ? (int)bigint_to_i64(la->second.value.i) : 0;
                    int blen = (lb != b->container->end()) ? (int)bigint_to_i64(lb->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int i = 0; i < alen; i++) {
                        auto it = a->container->find(std::to_string(i));
                        if (it != a->container->end()) result->set(std::to_string(idx++), it->second);
                    }
                    for (int i = 0; i < blen; i++) {
                        auto it = b->container->find(std::to_string(i));
                        if (it != b->container->end()) result->set(std::to_string(idx++), it->second);
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_zeros" || name == "zeros") {
            if (!args.empty()) {
                int n = shape_to_size(args[0]);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) result->set(std::to_string(i), Value(0.0));
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_ones" || name == "ones") {
            if (!args.empty()) {
                int n = shape_to_size(args[0]);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) result->set(std::to_string(i), Value(1.0));
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_rand" || name == "rand_tensor") {
            // Random tensor with values in [0, 1)
            if (!args.empty()) {
                int n = shape_to_size(args[0]);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) {
                    double v = static_cast<double>(rand()) / RAND_MAX;
                    result->set(std::to_string(i), Value(v));
                }
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_randn" || name == "randn_tensor") {
            // Random normal distribution (Box-Muller transform)
            if (!args.empty()) {
                int n = shape_to_size(args[0]);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) {
                    double u1 = (static_cast<double>(rand()) + 1) / (RAND_MAX + 2.0);
                    double u2 = static_cast<double>(rand()) / RAND_MAX;
                    double z = std::sqrt(-2.0 * std::log(u1)) * std::cos(2.0 * 3.14159265358979 * u2);
                    result->set(std::to_string(i), Value(z));
                }
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "tensor_arange") {
            // arange(start, stop, step) -> tensor
            double start = 0, stop = 0, step = 1;
            if (args.size() == 1) { stop = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i); }
            else if (args.size() >= 2) {
                start = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                stop = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
            }
            if (args.size() >= 3) step = args[2].type == ValueType::DOUBLE ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
            Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
            int idx = 0;
            for (double v = start; step > 0 ? v < stop : v > stop; v += step)
                result->set(std::to_string(idx++), Value(v));
            result->set("__len__", Value(idx));
            return Value((Collectable*)result);
        }
        if (name == "tensor_linspace") {
            // linspace(start, stop, num) -> tensor of evenly spaced values
            if (args.size() >= 3) {
                double start = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double stop = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                int num = (int)bigint_to_i64(args[2].value.i);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < num; i++) {
                    double v = start + (stop - start) * i / (num - 1);
                    result->set(std::to_string(i), Value(v));
                }
                result->set("__len__", Value(num));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "mse_loss") {
            // Mean squared error: mse_loss(predicted, target)
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double total = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = pred->container->find(std::to_string(i));
                        auto ti = target->container->find(std::to_string(i));
                        double pv = (pi != pred->container->end()) ? (double)pi->second.value.d : 0;
                        double tv = (ti != target->container->end()) ? (double)ti->second.value.d : 0;
                        total += (pv - tv) * (pv - tv);
                    }
                    return Value(total / len);
                }
            }
            return Value(0.0);
        }
        if (name == "cross_entropy_loss") {
            // Cross entropy: -sum(target * log(pred))
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double total = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = pred->container->find(std::to_string(i));
                        auto ti = target->container->find(std::to_string(i));
                        double pv = (pi != pred->container->end()) ? (double)pi->second.value.d : 1e-7;
                        double tv = (ti != target->container->end()) ? (double)ti->second.value.d : 0;
                        if (pv < 1e-7) pv = 1e-7;
                        total += -tv * std::log(pv);
                    }
                    return Value(total);
                }
            }
            return Value(0.0);
        }
        if (name == "numerical_gradient") {
            // numerical_gradient(fn, tensor, epsilon) -> gradient tensor
            if (args.size() >= 2 && args[0].type == ValueType::USERDATA && args[1].isCollectable()) {
                Value fn_val = args[0];
                auto* t = dynamic_cast<Container*>(args[1].value.gc);
                double eps = (args.size() >= 3) ? ((double)args[2].value.d) : 1e-5;
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* grad = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        // f(x + eps)
                        auto orig = t->container->find(std::to_string(i));
                        double orig_val = (orig != t->container->end()) ? (double)orig->second.value.d : 0;
                        (*t->container)[std::to_string(i)] = Value(orig_val + eps);
                        std::vector<Value> a1 = {Value((Collectable*)t)};
                        Value f_plus = callFunctionValue(fn_val, a1, ctx);
                        // f(x - eps)
                        (*t->container)[std::to_string(i)] = Value(orig_val - eps);
                        std::vector<Value> a2 = {Value((Collectable*)t)};
                        Value f_minus = callFunctionValue(fn_val, a2, ctx);
                        // Restore
                        (*t->container)[std::to_string(i)] = Value(orig_val);
                        double fp = f_plus.type == ValueType::DOUBLE ? (double)f_plus.value.d : (double)bigint_to_i64(f_plus.value.i);
                        double fm = f_minus.type == ValueType::DOUBLE ? (double)f_minus.value.d : (double)bigint_to_i64(f_minus.value.i);
                        grad->set(std::to_string(i), Value((fp - fm) / (2 * eps)));
                    }
                    grad->set("__len__", Value(len));
                    return Value((Collectable*)grad);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_clip" || name == "tensor_clamp") {
            // clip(tensor, min, max)
            if (args.size() >= 3 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                double lo = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                double hi = args[2].type == ValueType::DOUBLE ? (double)args[2].value.d : (double)bigint_to_i64(args[2].value.i);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        if (v < lo) v = lo;
                        if (v > hi) v = hi;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_argmax" || name == "argmax") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double best = -1e308; int best_idx = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        if (v > best) { best = v; best_idx = i; }
                    }
                    return Value(best_idx);
                }
            }
            return Value(0);
        }
        if (name == "tensor_argmin" || name == "argmin") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double best = 1e308; int best_idx = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        if (v < best) { best = v; best_idx = i; }
                    }
                    return Value(best_idx);
                }
            }
            return Value(0);
        }
        if (name == "tensor_norm" || name == "norm") {
            // L2 norm
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double sum_sq = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        sum_sq += v * v;
                    }
                    return Value(std::sqrt(sum_sq));
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_normalize") {
            // Normalize to unit length
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double sum_sq = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        sum_sq += v * v;
                    }
                    double n = std::sqrt(sum_sq);
                    if (n < 1e-12) n = 1e-12;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(v / n));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_slice") {
            // Slice a tensor: tensor_slice(t, start, end)
            if (args.size() >= 3 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                int start = (int)bigint_to_i64(args[1].value.i);
                int end_idx = (int)bigint_to_i64(args[2].value.i);
                if (t && t->container) {
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int i = start; i < end_idx; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) result->set(std::to_string(idx++), it->second);
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_reshape") {
            // Just returns the same data (flat storage) - shape is metadata only
            if (!args.empty()) return args[0];
            return NONE_VALUE;
        }
        if (name == "one_hot") {
            // one_hot(index, num_classes) -> tensor
            if (args.size() >= 2) {
                int idx = (int)bigint_to_i64(args[0].value.i);
                int nc = (int)bigint_to_i64(args[1].value.i);
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < nc; i++)
                    result->set(std::to_string(i), Value(i == idx ? 1.0 : 0.0));
                result->set("__len__", Value(nc));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "binary_cross_entropy") {
            // BCE: -mean(target*log(pred) + (1-target)*log(1-pred))
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double total = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = pred->container->find(std::to_string(i));
                        auto ti = target->container->find(std::to_string(i));
                        double p = (pi != pred->container->end()) ? (double)pi->second.value.d : 0.5;
                        double t = (ti != target->container->end()) ? (double)ti->second.value.d : 0;
                        p = std::max(1e-7, std::min(1.0 - 1e-7, p));
                        total += -(t * std::log(p) + (1 - t) * std::log(1 - p));
                    }
                    return Value(total / len);
                }
            }
            return Value(0.0);
        }
        if (name == "accuracy") {
            // Compare argmax of predictions with target labels
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* preds = dynamic_cast<Container*>(args[0].value.gc);
                auto* targets = dynamic_cast<Container*>(args[1].value.gc);
                if (preds && targets && preds->container && targets->container) {
                    auto li = preds->container->find("__len__");
                    int len = (li != preds->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    int correct = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = preds->container->find(std::to_string(i));
                        auto ti = targets->container->find(std::to_string(i));
                        if (pi != preds->container->end() && ti != targets->container->end()) {
                            double pv = (double)pi->second.value.d;
                            double tv = (double)ti->second.value.d;
                            if (std::round(pv) == std::round(tv)) correct++;
                        }
                    }
                    return Value(static_cast<double>(correct) / len);
                }
            }
            return Value(0.0);
        }
    // ── from main.cpp lines 6133–6511 ──────────────────────────────────────────
        if (name == "conv1d") {
            // conv1d(input, kernel) -> output (valid convolution)
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* inp = dynamic_cast<Container*>(args[0].value.gc);
                auto* ker = dynamic_cast<Container*>(args[1].value.gc);
                if (inp && ker && inp->container && ker->container) {
                    auto il = inp->container->find("__len__");
                    auto kl = ker->container->find("__len__");
                    int ilen = (il != inp->container->end()) ? (int)bigint_to_i64(il->second.value.i) : 0;
                    int klen = (kl != ker->container->end()) ? (int)bigint_to_i64(kl->second.value.i) : 0;
                    int olen = ilen - klen + 1;
                    if (olen <= 0) return NONE_VALUE;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < olen; i++) {
                        double sum = 0;
                        for (int k = 0; k < klen; k++) {
                            auto ii = inp->container->find(std::to_string(i + k));
                            auto ki = ker->container->find(std::to_string(k));
                            double iv = (ii != inp->container->end()) ? (double)ii->second.value.d : 0;
                            double kv = (ki != ker->container->end()) ? (double)ki->second.value.d : 0;
                            sum += iv * kv;
                        }
                        result->set(std::to_string(i), Value(sum));
                    }
                    result->set("__len__", Value(olen));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "max_pool1d") {
            // max_pool1d(input, kernel_size) -> pooled output
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* inp = dynamic_cast<Container*>(args[0].value.gc);
                int ks = (int)bigint_to_i64(args[1].value.i);
                if (inp && inp->container && ks > 0) {
                    auto il = inp->container->find("__len__");
                    int ilen = (il != inp->container->end()) ? (int)bigint_to_i64(il->second.value.i) : 0;
                    int olen = ilen / ks;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < olen; i++) {
                        double mx = -1e308;
                        for (int k = 0; k < ks; k++) {
                            auto it = inp->container->find(std::to_string(i * ks + k));
                            double v = (it != inp->container->end()) ? (double)it->second.value.d : 0;
                            if (v > mx) mx = v;
                        }
                        result->set(std::to_string(i), Value(mx));
                    }
                    result->set("__len__", Value(olen));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "avg_pool1d") {
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* inp = dynamic_cast<Container*>(args[0].value.gc);
                int ks = (int)bigint_to_i64(args[1].value.i);
                if (inp && inp->container && ks > 0) {
                    auto il = inp->container->find("__len__");
                    int ilen = (il != inp->container->end()) ? (int)bigint_to_i64(il->second.value.i) : 0;
                    int olen = ilen / ks;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < olen; i++) {
                        double sum = 0;
                        for (int k = 0; k < ks; k++) {
                            auto it = inp->container->find(std::to_string(i * ks + k));
                            sum += (it != inp->container->end()) ? (double)it->second.value.d : 0;
                        }
                        result->set(std::to_string(i), Value(sum / ks));
                    }
                    result->set("__len__", Value(olen));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "dropout") {
            // dropout(tensor, rate) -> tensor with elements randomly zeroed
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                double rate = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double scale = 1.0 / (1.0 - rate);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        double r = static_cast<double>(rand()) / RAND_MAX;
                        result->set(std::to_string(i), Value(r > rate ? v * scale : 0.0));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "embedding_lookup" || name == "embedding") {
            // embedding(table, indices) -> concatenated embeddings
            // table: flat tensor [vocab_size * embed_dim], indices: list of ints
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* table = dynamic_cast<Container*>(args[0].value.gc);
                auto* indices = dynamic_cast<Container*>(args[1].value.gc);
                int embed_dim = (int)bigint_to_i64(args[2].value.i);
                if (table && indices && table->container && indices->container) {
                    auto il = indices->container->find("__len__");
                    int num_idx = (il != indices->container->end()) ? (int)bigint_to_i64(il->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int i = 0; i < num_idx; i++) {
                        auto ii = indices->container->find(std::to_string(i));
                        int word_idx = (ii != indices->container->end()) ? (int)bigint_to_i64(ii->second.value.i) : 0;
                        for (int d = 0; d < embed_dim; d++) {
                            auto ti = table->container->find(std::to_string(word_idx * embed_dim + d));
                            double v = (ti != table->container->end()) ? (double)ti->second.value.d : 0;
                            result->set(std::to_string(idx++), Value(v));
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "cosine_similarity" || name == "cos_sim") {
            // cosine_similarity(a, b) -> dot(a,b) / (norm(a) * norm(b))
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* a = dynamic_cast<Container*>(args[0].value.gc);
                auto* b = dynamic_cast<Container*>(args[1].value.gc);
                if (a && b && a->container && b->container) {
                    auto al = a->container->find("__len__");
                    int len = (al != a->container->end()) ? (int)bigint_to_i64(al->second.value.i) : 0;
                    double dot = 0, na = 0, nb = 0;
                    for (int i = 0; i < len; i++) {
                        auto ai = a->container->find(std::to_string(i));
                        auto bi = b->container->find(std::to_string(i));
                        double av = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                        double bv = (bi != b->container->end()) ? (double)bi->second.value.d : 0;
                        dot += av * bv; na += av * av; nb += bv * bv;
                    }
                    double denom = std::sqrt(na) * std::sqrt(nb);
                    return Value(denom > 1e-12 ? dot / denom : 0.0);
                }
            }
            return Value(0.0);
        }
        if (name == "attention" || name == "scaled_dot_attention") {
            // attention(Q, K, V, d_k) -> softmax(Q*K^T / sqrt(d_k)) * V
            // Q: [1, d_k], K: [seq_len, d_k], V: [seq_len, d_v], d_k: int
            // Simplified: single query attention
            if (args.size() >= 4 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* Q = dynamic_cast<Container*>(args[0].value.gc);
                auto* K = dynamic_cast<Container*>(args[1].value.gc);
                auto* V = dynamic_cast<Container*>(args[2].value.gc);
                int dk = (int)bigint_to_i64(args[3].value.i);
                if (Q && K && V && Q->container && K->container && V->container && dk > 0) {
                    auto kl = K->container->find("__len__");
                    auto vl = V->container->find("__len__");
                    int k_total = (kl != K->container->end()) ? (int)bigint_to_i64(kl->second.value.i) : 0;
                    int v_total = (vl != V->container->end()) ? (int)bigint_to_i64(vl->second.value.i) : 0;
                    int seq_len = k_total / dk;
                    int dv = v_total / seq_len;
                    double scale = 1.0 / std::sqrt((double)dk);
                    // Compute attention scores: Q * K^T / sqrt(d_k)
                    std::vector<double> scores(seq_len);
                    double max_score = -1e308;
                    for (int s = 0; s < seq_len; s++) {
                        double dot = 0;
                        for (int d = 0; d < dk; d++) {
                            auto qi = Q->container->find(std::to_string(d));
                            auto ki = K->container->find(std::to_string(s * dk + d));
                            double qv = (qi != Q->container->end()) ? (double)qi->second.value.d : 0;
                            double kv = (ki != K->container->end()) ? (double)ki->second.value.d : 0;
                            dot += qv * kv;
                        }
                        scores[s] = dot * scale;
                        if (scores[s] > max_score) max_score = scores[s];
                    }
                    // Softmax
                    double sum_exp = 0;
                    for (int s = 0; s < seq_len; s++) {
                        scores[s] = std::exp(scores[s] - max_score);
                        sum_exp += scores[s];
                    }
                    for (int s = 0; s < seq_len; s++) scores[s] /= sum_exp;
                    // Weighted sum of V
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int d = 0; d < dv; d++) {
                        double sum = 0;
                        for (int s = 0; s < seq_len; s++) {
                            auto vi = V->container->find(std::to_string(s * dv + d));
                            double vv = (vi != V->container->end()) ? (double)vi->second.value.d : 0;
                            sum += scores[s] * vv;
                        }
                        result->set(std::to_string(d), Value(sum));
                    }
                    result->set("__len__", Value(dv));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "batch_norm" || name == "batchnorm") {
            // batch_norm(tensor, gamma, beta, eps) -> normalized tensor
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double eps = (args.size() >= 4) ? ((args[3].type == ValueType::DOUBLE) ? (double)args[3].value.d : 1e-5) : 1e-5;
                    // Compute mean and variance
                    double mean = 0, var_val = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        mean += (it != t->container->end()) ? (double)it->second.value.d : 0;
                    }
                    mean /= len;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_val += (v - mean) * (v - mean);
                    }
                    var_val /= len;
                    double std_val = std::sqrt(var_val + eps);
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        double normed = (v - mean) / std_val;
                        // Apply gamma and beta if provided
                        if (args.size() >= 3 && args[1].isCollectable() && args[2].isCollectable()) {
                            auto* gamma = dynamic_cast<Container*>(args[1].value.gc);
                            auto* beta = dynamic_cast<Container*>(args[2].value.gc);
                            auto gi = gamma->container->find(std::to_string(i));
                            auto bi = beta->container->find(std::to_string(i));
                            double g = (gi != gamma->container->end()) ? (double)gi->second.value.d : 1.0;
                            double b = (bi != beta->container->end()) ? (double)bi->second.value.d : 0.0;
                            normed = g * normed + b;
                        }
                        result->set(std::to_string(i), Value(normed));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_var" || name == "variance") {
            // Variance of tensor elements
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
                    double var_sum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_sum += (v - mean) * (v - mean);
                    }
                    return Value(var_sum / len);
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_std" || name == "std_dev") {
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
                    double var_sum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_sum += (v - mean) * (v - mean);
                    }
                    return Value(std::sqrt(var_sum / len));
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_where" || name == "where") {
            // where(condition_tensor, x_tensor, y_tensor) -> element-wise select
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* cond = dynamic_cast<Container*>(args[0].value.gc);
                auto* x = dynamic_cast<Container*>(args[1].value.gc);
                auto* y = dynamic_cast<Container*>(args[2].value.gc);
                if (cond && x && y && cond->container && x->container && y->container) {
                    auto cl = cond->container->find("__len__");
                    int len = (cl != cond->container->end()) ? (int)bigint_to_i64(cl->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto ci = cond->container->find(std::to_string(i));
                        auto xi = x->container->find(std::to_string(i));
                        auto yi = y->container->find(std::to_string(i));
                        double cv = (ci != cond->container->end()) ? (double)ci->second.value.d : 0;
                        double xv = (xi != x->container->end()) ? (double)xi->second.value.d : 0;
                        double yv = (yi != y->container->end()) ? (double)yi->second.value.d : 0;
                        result->set(std::to_string(i), Value(cv > 0 ? xv : yv));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_stack") {
            // Stack multiple tensors: stack([t1, t2, t3]) -> flat tensor
            if (!args.empty() && args[0].isCollectable()) {
                auto* list = dynamic_cast<Container*>(args[0].value.gc);
                if (list && list->container) {
                    auto ll = list->container->find("__len__");
                    int num = (ll != list->container->end()) ? (int)bigint_to_i64(ll->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int n = 0; n < num; n++) {
                        auto ti = list->container->find(std::to_string(n));
                        if (ti != list->container->end() && ti->second.isCollectable()) {
                            auto* t = dynamic_cast<Container*>(ti->second.value.gc);
                            if (t && t->container) {
                                auto tl = t->container->find("__len__");
                                int tlen = (tl != t->container->end()) ? (int)bigint_to_i64(tl->second.value.i) : 0;
                                for (int i = 0; i < tlen; i++) {
                                    auto vi = t->container->find(std::to_string(i));
                                    if (vi != t->container->end())
                                        result->set(std::to_string(idx++), vi->second);
                                }
                            }
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_split") {
            // Split tensor into chunks: split(tensor, chunk_size) -> list of tensors
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                int cs = (int)bigint_to_i64(args[1].value.i);
                if (t && t->container && cs > 0) {
                    auto tl = t->container->find("__len__");
                    int len = (tl != t->container->end()) ? (int)bigint_to_i64(tl->second.value.i) : 0;
                    int num_chunks = (len + cs - 1) / cs;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int c = 0; c < num_chunks; c++) {
                        Object* chunk = new Object((Runnable*)runner, "tensor", Type::LIST);
                        int ci = 0;
                        for (int i = c * cs; i < (c + 1) * cs && i < len; i++) {
                            auto vi = t->container->find(std::to_string(i));
                            if (vi != t->container->end())
                                chunk->set(std::to_string(ci++), vi->second);
                        }
                        chunk->set("__len__", Value(ci));
                        result->set(std::to_string(c), Value((Collectable*)chunk));
                    }
                    result->set("__len__", Value(num_chunks));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 6513–6723 ──────────────────────────────────────────
        if (name == "linspace") {
            // alias for tensor_linspace
            if (args.size() >= 3) {
                double start = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double stop  = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                int n = (int)(args[2].type == ValueType::INTEGER ? bigint_to_i64(args[2].value.i) : (int64_t)args[2].value.d);
                if (n < 2) n = 2;
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) {
                    double v = start + (stop - start) * i / (n - 1);
                    result->set(std::to_string(i), Value(v));
                }
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        if (name == "logspace") {
            if (args.size() >= 3) {
                double start = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double stop  = args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                int n = (int)(args[2].type == ValueType::INTEGER ? bigint_to_i64(args[2].value.i) : (int64_t)args[2].value.d);
                double base = (args.size() >= 4) ? (args[3].type == ValueType::DOUBLE ? (double)args[3].value.d : (double)bigint_to_i64(args[3].value.i)) : 10.0;
                if (n < 2) n = 2;
                Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                for (int i = 0; i < n; i++) {
                    double exp_v = start + (stop - start) * i / (n - 1);
                    result->set(std::to_string(i), Value(std::pow(base, exp_v)));
                }
                result->set("__len__", Value(n));
                return Value((Collectable*)result);
            }
            return NONE_VALUE;
        }
        // ── tensor_median / cummax / cummin ────────────────────────────────────────
        if (name == "tensor_median") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    std::vector<double> vals;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) vals.push_back((double)it->second.value.d);
                    }
                    std::sort(vals.begin(), vals.end());
                    if (vals.empty()) return NONE_VALUE;
                    double med = (vals.size() % 2 == 0) ? (vals[vals.size()/2-1] + vals[vals.size()/2]) / 2.0 : vals[vals.size()/2];
                    return Value(med);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_cummax") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double running = -1e18;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        if (v > running) running = v;
                        result->set(std::to_string(i), Value(running));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_cummin") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double running = 1e18;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        if (v < running) running = v;
                        result->set(std::to_string(i), Value(running));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ── tensor_flip / tensor_roll / tensor_unique ──────────────────────────────
        if (name == "tensor_flip") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(len-1-i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_roll") {
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                int shift = (int)(args[1].type == ValueType::INTEGER ? bigint_to_i64(args[1].value.i) : (int64_t)args[1].value.d);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    if (len == 0) return NONE_VALUE;
                    shift = ((shift % len) + len) % len;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string((i - shift + len) % len));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_unique") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    std::vector<double> vals;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        if (it != t->container->end()) vals.push_back((double)it->second.value.d);
                    }
                    std::sort(vals.begin(), vals.end());
                    vals.erase(std::unique(vals.begin(), vals.end()), vals.end());
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (size_t i = 0; i < vals.size(); i++) result->set(std::to_string(i), Value(vals[i]));
                    result->set("__len__", Value((int)vals.size()));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ── tensor_abs / tensor_pow / tensor_sqrt ─────────────────────────────────
        if (name == "tensor_abs") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? std::abs((double)it->second.value.d) : 0;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_pow") {
            if (args.size() >= 2 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                double exp_v = (args[1].type == ValueType::DOUBLE) ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? std::pow((double)it->second.value.d, exp_v) : 0;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_sqrt") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? std::sqrt(std::abs((double)it->second.value.d)) : 0;
                        result->set(std::to_string(i), Value(v));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
    // ── from main.cpp lines 6820–6949 ──────────────────────────────────────────
        // ── tensor_cumprod ─────────────────────────────────────────────────────────
        if (name == "tensor_cumprod") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double running = 1.0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        running *= v;
                        result->set(std::to_string(i), Value(running));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ── tensor_sign ─────────────────────────────────────────────────────────────
        if (name == "tensor_sign") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        double sign = (v > 0) ? 1.0 : ((v < 0) ? -1.0 : 0.0);
                        result->set(std::to_string(i), Value(sign));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ── logsumexp ────────────────────────────────────────────────────────────────
        if (name == "logsumexp") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double max_val = -1e18;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : -1e18;
                        if (v > max_val) max_val = v;
                    }
                    double sum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : -1e18;
                        sum += std::exp(v - max_val);
                    }
                    return Value(max_val + std::log(sum));
                }
            }
            return NONE_VALUE;
        }
        // ── tensor_scatter_add ───────────────────────────────────────────────────────
        if (name == "tensor_scatter_add") {
            // tensor_scatter_add(output, indices, values) - add values at indices into output
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* out = dynamic_cast<Container*>(args[0].value.gc);
                auto* idx = dynamic_cast<Container*>(args[1].value.gc);
                auto* val = dynamic_cast<Container*>(args[2].value.gc);
                if (out && idx && val && out->container && idx->container && val->container) {
                    auto oli = out->container->find("__len__");
                    auto ili = idx->container->find("__len__");
                    int olen = (oli != out->container->end()) ? (int)bigint_to_i64(oli->second.value.i) : 0;
                    int ilen = (ili != idx->container->end()) ? (int)bigint_to_i64(ili->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < olen; i++) {
                        auto it = out->container->find(std::to_string(i));
                        result->set(std::to_string(i), it != out->container->end() ? it->second : Value(0.0));
                    }
                    result->set("__len__", Value(olen));
                    for (int i = 0; i < ilen; i++) {
                        auto ii = idx->container->find(std::to_string(i));
                        auto vi = val->container->find(std::to_string(i));
                        if (ii != idx->container->end() && vi != val->container->end()) {
                            int target = (ii->second.type == ValueType::INTEGER) ? (int)bigint_to_i64(ii->second.value.i) : (int)(double)ii->second.value.d;
                            if (target >= 0 && target < olen) {
                                auto cur = result->container->find(std::to_string(target));
                                double cv = (cur != result->container->end()) ? (double)cur->second.value.d : 0;
                                result->set(std::to_string(target), Value(cv + (double)vi->second.value.d));
                            }
                        }
                    }
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        // ── tensor_gather ─────────────────────────────────────────────────────────────
        if (name == "tensor_gather") {
            // tensor_gather(input, indices) -> output[i] = input[indices[i]]
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* inp = dynamic_cast<Container*>(args[0].value.gc);
                auto* idx = dynamic_cast<Container*>(args[1].value.gc);
                if (inp && idx && inp->container && idx->container) {
                    auto ili = idx->container->find("__len__");
                    int ilen = (ili != idx->container->end()) ? (int)bigint_to_i64(ili->second.value.i) : 0;
                    auto inli = inp->container->find("__len__");
                    int inlen = (inli != inp->container->end()) ? (int)bigint_to_i64(inli->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < ilen; i++) {
                        auto ii = idx->container->find(std::to_string(i));
                        int src = 0;
                        if (ii != idx->container->end()) {
                            if (ii->second.type == ValueType::INTEGER) src = (int)bigint_to_i64(ii->second.value.i);
                            else src = (int)(double)ii->second.value.d;
                        }
                        src = std::max(0, std::min(inlen - 1, src));
                        auto vi = inp->container->find(std::to_string(src));
                        result->set(std::to_string(i), vi != inp->container->end() ? vi->second : Value(0.0));
                    }
                    result->set("__len__", Value(ilen));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }

    // ── from main.cpp lines 7563–8104 ──────────────────────────────────────────
        if (name == "tensor_var" || name == "tensor_variance") {
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
                    double var_val = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_val += (v - mean) * (v - mean);
                    }
                    return Value(var_val / len);
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_std") {
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
                    double var_val = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_val += (v - mean) * (v - mean);
                    }
                    return Value(std::sqrt(var_val / len));
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_where") {
            // tensor_where(condition_tensor, a, b) -> a[i] if cond[i]>0 else b[i]
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* cond = dynamic_cast<Container*>(args[0].value.gc);
                auto* a = dynamic_cast<Container*>(args[1].value.gc);
                auto* b = dynamic_cast<Container*>(args[2].value.gc);
                if (cond && a && b && cond->container && a->container && b->container) {
                    auto cl = cond->container->find("__len__");
                    int len = (cl != cond->container->end()) ? (int)bigint_to_i64(cl->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto ci = cond->container->find(std::to_string(i));
                        auto ai = a->container->find(std::to_string(i));
                        auto bi = b->container->find(std::to_string(i));
                        double cv = (ci != cond->container->end()) ? (double)ci->second.value.d : 0;
                        double av = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                        double bv = (bi != b->container->end()) ? (double)bi->second.value.d : 0;
                        result->set(std::to_string(i), Value(cv > 0 ? av : bv));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_stack") {
            // stack(list_of_tensors) -> flat tensor (concatenate all)
            if (!args.empty() && args[0].isCollectable()) {
                auto* list = dynamic_cast<Container*>(args[0].value.gc);
                if (list && list->container) {
                    auto ll = list->container->find("__len__");
                    int num = (ll != list->container->end()) ? (int)bigint_to_i64(ll->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int n = 0; n < num; n++) {
                        auto ti = list->container->find(std::to_string(n));
                        if (ti != list->container->end() && ti->second.isCollectable()) {
                            auto* t = dynamic_cast<Container*>(ti->second.value.gc);
                            if (t && t->container) {
                                auto tl = t->container->find("__len__");
                                int tlen = (tl != t->container->end()) ? (int)bigint_to_i64(tl->second.value.i) : 0;
                                for (int i = 0; i < tlen; i++) {
                                    auto vi = t->container->find(std::to_string(i));
                                    if (vi != t->container->end()) result->set(std::to_string(idx++), vi->second);
                                }
                            }
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "elu") {
            // ELU: x if x > 0 else alpha * (exp(x) - 1)
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double alpha = (args.size() >= 2) ? (args[1].type == ValueType::DOUBLE ? (double)args[1].value.d : (double)bigint_to_i64(args[1].value.i)) : 1.0;
                return Value(x > 0 ? x : alpha * (std::exp(x) - 1));
            }
            return Value(0.0);
        }
        if (name == "gelu") {
            // GELU: 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
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
        if (name == "layer_norm") {
            // layer_norm(tensor) -> (x - mean) / std
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double mean = 0, var_v = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        mean += (it != t->container->end()) ? (double)it->second.value.d : 0;
                    }
                    mean /= len;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_v += (v - mean) * (v - mean);
                    }
                    double s = std::sqrt(var_v / len + 1e-5);
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value((v - mean) / s));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_cumsum") {
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double cumsum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        cumsum += (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(cumsum));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_diff") {
            // Difference between consecutive elements
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 1; i < len; i++) {
                        auto prev = t->container->find(std::to_string(i-1));
                        auto curr = t->container->find(std::to_string(i));
                        double pv = (prev != t->container->end()) ? (double)prev->second.value.d : 0;
                        double cv = (curr != t->container->end()) ? (double)curr->second.value.d : 0;
                        result->set(std::to_string(i-1), Value(cv - pv));
                    }
                    result->set("__len__", Value(len > 0 ? len - 1 : 0));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_outer") {
            // Outer product: a[i] * b[j] for all i,j
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* a = dynamic_cast<Container*>(args[0].value.gc);
                auto* b = dynamic_cast<Container*>(args[1].value.gc);
                if (a && b && a->container && b->container) {
                    auto al = a->container->find("__len__");
                    auto bl = b->container->find("__len__");
                    int alen = (al != a->container->end()) ? (int)bigint_to_i64(al->second.value.i) : 0;
                    int blen = (bl != b->container->end()) ? (int)bigint_to_i64(bl->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    int idx = 0;
                    for (int i = 0; i < alen; i++) {
                        auto ai = a->container->find(std::to_string(i));
                        double av = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                        for (int j = 0; j < blen; j++) {
                            auto bj = b->container->find(std::to_string(j));
                            double bv = (bj != b->container->end()) ? (double)bj->second.value.d : 0;
                            result->set(std::to_string(idx++), Value(av * bv));
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "huber_loss") {
            // Huber loss: smooth L1 loss
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                double delta = (args.size() >= 3) ? ((args[2].type == ValueType::DOUBLE) ? (double)args[2].value.d : 1.0) : 1.0;
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
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
        if (name == "gelu") {
            // GELU: x * 0.5 * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double c = 0.7978845608; // sqrt(2/pi)
                return Value(0.5 * x * (1.0 + std::tanh(c * (x + 0.044715 * x * x * x))));
            }
            return Value(0.0);
        }
        if (name == "swish" || name == "silu") {
            // Swish/SiLU: x * sigmoid(x)
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x / (1.0 + std::exp(-x)));
            }
            return Value(0.0);
        }
        if (name == "elu") {
            // ELU: x if x > 0 else alpha * (exp(x) - 1)
            double alpha = (args.size() >= 2) ? ((double)args[1].value.d) : 1.0;
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x > 0 ? x : alpha * (std::exp(x) - 1));
            }
            return Value(0.0);
        }
        if (name == "tensor_where") {
            // where(condition_tensor, a, b) -> element-wise selection
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* cond = dynamic_cast<Container*>(args[0].value.gc);
                auto* a = dynamic_cast<Container*>(args[1].value.gc);
                auto* b = dynamic_cast<Container*>(args[2].value.gc);
                if (cond && a && b && cond->container && a->container && b->container) {
                    auto li = cond->container->find("__len__");
                    int len = (li != cond->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto ci = cond->container->find(std::to_string(i));
                        auto ai = a->container->find(std::to_string(i));
                        auto bi = b->container->find(std::to_string(i));
                        double cv = (ci != cond->container->end()) ? (double)ci->second.value.d : 0;
                        double av = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                        double bv = (bi != b->container->end()) ? (double)bi->second.value.d : 0;
                        result->set(std::to_string(i), Value(cv > 0 ? av : bv));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_cumsum") {
            // Cumulative sum
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double cum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        cum += (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(cum));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_diff") {
            // Finite differences: diff[i] = t[i+1] - t[i]
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    if (len < 2) return NONE_VALUE;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len - 1; i++) {
                        auto a = t->container->find(std::to_string(i));
                        auto b = t->container->find(std::to_string(i + 1));
                        double av = (a != t->container->end()) ? (double)a->second.value.d : 0;
                        double bv = (b != t->container->end()) ? (double)b->second.value.d : 0;
                        result->set(std::to_string(i), Value(bv - av));
                    }
                    result->set("__len__", Value(len - 1));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "tensor_var" || name == "tensor_std") {
            // Variance / Standard deviation
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
                    double var_val = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        var_val += (v - mean) * (v - mean);
                    }
                    var_val /= len;
                    if (name == "tensor_std") return Value(std::sqrt(var_val));
                    return Value(var_val);
                }
            }
            return Value(0.0);
        }
        if (name == "huber_loss") {
            // Smooth L1 / Huber loss
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                double delta = (args.size() >= 3) ? ((double)args[2].value.d) : 1.0;
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
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
        if (name == "layer_norm" || name == "layernorm") {
            // Layer normalization: normalize each element, then scale+shift
            if (args.size() >= 1 && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double eps = 1e-5;
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
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        double v = (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value((v - mean) / std::sqrt(var_v + eps)));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "gelu") {
            // GELU activation: x * 0.5 * (1 + tanh(sqrt(2/pi) * (x + 0.044715*x^3)))
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                double c = 0.7978845608; // sqrt(2/pi)
                return Value(0.5 * x * (1.0 + std::tanh(c * (x + 0.044715 * x * x * x))));
            }
            return Value(0.0);
        }
        if (name == "elu") {
            // ELU: x if x > 0, alpha*(exp(x)-1) otherwise
            double alpha = (args.size() >= 2) ? ((args[1].type == ValueType::DOUBLE) ? (double)args[1].value.d : 1.0) : 1.0;
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x > 0 ? x : alpha * (std::exp(x) - 1));
            }
            return Value(0.0);
        }
        if (name == "swish" || name == "silu") {
            // Swish/SiLU: x * sigmoid(x)
            if (!args.empty()) {
                double x = args[0].type == ValueType::DOUBLE ? (double)args[0].value.d : (double)bigint_to_i64(args[0].value.i);
                return Value(x / (1.0 + std::exp(-x)));
            }
            return Value(0.0);
        }
        if (name == "tensor_where") {
            // where(condition_tensor, a, b) -> element-wise selection
            if (args.size() >= 3 && args[0].isCollectable() && args[1].isCollectable() && args[2].isCollectable()) {
                auto* cond = dynamic_cast<Container*>(args[0].value.gc);
                auto* a = dynamic_cast<Container*>(args[1].value.gc);
                auto* b = dynamic_cast<Container*>(args[2].value.gc);
                if (cond && a && b && cond->container && a->container && b->container) {
                    auto cl = cond->container->find("__len__");
                    int len = (cl != cond->container->end()) ? (int)bigint_to_i64(cl->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto ci = cond->container->find(std::to_string(i));
                        auto ai = a->container->find(std::to_string(i));
                        auto bi = b->container->find(std::to_string(i));
                        double cv = (ci != cond->container->end()) ? (double)ci->second.value.d : 0;
                        double av = (ai != a->container->end()) ? (double)ai->second.value.d : 0;
                        double bv = (bi != b->container->end()) ? (double)bi->second.value.d : 0;
                        result->set(std::to_string(i), Value(cv > 0 ? av : bv));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }
        if (name == "huber_loss") {
            // Huber loss: MSE for small errors, MAE for large errors
            if (args.size() >= 2 && args[0].isCollectable() && args[1].isCollectable()) {
                auto* pred = dynamic_cast<Container*>(args[0].value.gc);
                auto* target = dynamic_cast<Container*>(args[1].value.gc);
                double delta = (args.size() >= 3 && args[2].type == ValueType::DOUBLE) ? (double)args[2].value.d : 1.0;
                if (pred && target && pred->container && target->container) {
                    auto li = pred->container->find("__len__");
                    int len = (li != pred->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    double total = 0;
                    for (int i = 0; i < len; i++) {
                        auto pi = pred->container->find(std::to_string(i));
                        auto ti = target->container->find(std::to_string(i));
                        double pv = (pi != pred->container->end()) ? (double)pi->second.value.d : 0;
                        double tv = (ti != target->container->end()) ? (double)ti->second.value.d : 0;
                        double a = std::abs(pv - tv);
                        total += (a <= delta) ? 0.5 * a * a : delta * (a - 0.5 * delta);
                    }
                    return Value(total / len);
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_var" || name == "tensor_std") {
            // Variance or standard deviation
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
                    if (name == "tensor_std") return Value(std::sqrt(var_v));
                    return Value(var_v);
                }
            }
            return Value(0.0);
        }
        if (name == "tensor_cumsum") {
            // Cumulative sum
            if (!args.empty() && args[0].isCollectable()) {
                auto* t = dynamic_cast<Container*>(args[0].value.gc);
                if (t && t->container) {
                    auto li = t->container->find("__len__");
                    int len = (li != t->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
                    Object* result = new Object((Runnable*)runner, "tensor", Type::LIST);
                    double cum = 0;
                    for (int i = 0; i < len; i++) {
                        auto it = t->container->find(std::to_string(i));
                        cum += (it != t->container->end()) ? (double)it->second.value.d : 0;
                        result->set(std::to_string(i), Value(cum));
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
            }
            return NONE_VALUE;
        }

    return UNDEFINED_VALUE;  // not handled by this module
}

#pragma GCC diagnostic pop

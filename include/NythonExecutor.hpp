#pragma once
#include "platform_compat.hpp"
// NythonExecutor.hpp
// ─────────────────────────────────────────────────────────────────────────────
// NythonExecutor struct — the interpreter's runtime object.
// Includes the full struct definition so that builtin modules (which each live
// in their own .cpp) can take a `NythonExecutor&` and call all helpers freely.
//
// Split layout:
//   NythonExecutor.hpp         ← this file (struct definition + callBuiltin dispatcher)
//   src/builtins/tensor.cpp    ← dispatch_tensor()
//   src/builtins/audio.cpp     ← dispatch_audio()
//   src/builtins/string.cpp    ← dispatch_string()
//   src/builtins/io.cpp        ← dispatch_io()
//   src/builtins/network.cpp   ← dispatch_network()
//   src/builtins/math.cpp      ← dispatch_math()
//   src/builtins/os.cpp        ← dispatch_os()
//   src/builtins/data.cpp      ← dispatch_data()
//   src/builtins/threading.cpp ← dispatch_threading()
//   src/builtins/core.cpp      ← dispatch_core()
//   src/builtins/gui.cpp       ← dispatch_gui()    (SDL2 backend)
//   src/main.cpp               ← main(), repl(), run_file(), eval chain
// ─────────────────────────────────────────────────────────────────────────────

// Windows: winsock2.h MUST come before windows.h (which some headers pull in)
#include "Nython.hpp"
#include "NythonREPL.hpp"
#include <algorithm>
#include <fstream>
#include <cwctype>
#include <chrono>
#include <iomanip>
#include <map>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <random>
#include <regex>
#include <sstream>
#include <ctime>
#include <functional>

// Platform compat (sockets, dirent, stat, getcwd, etc.) in platform_compat.hpp
#include <locale>

// Unicode case conversion tables for Latin characters
static uint32_t unicode_toupper(uint32_t cp) {
    // Latin-1 Supplement (U+00C0-U+00FF)
    if (cp >= 0xE0 && cp <= 0xF6) return cp - 0x20; // à-ö -> À-Ö
    if (cp >= 0xF8 && cp <= 0xFE) return cp - 0x20; // ø-þ -> Ø-Þ
    // Latin Extended-A
    if (cp >= 0x0101 && cp <= 0x017E && (cp & 1)) return cp - 1;
    // Special cases
    if (cp == 0x00FF) return 0x0178; // ÿ -> Ÿ
    if (cp == 0x00DF) return cp; // ß has no single uppercase (SS)
    if (cp == 0x0131) return 0x0049; // ı -> I
    return cp;
}
static uint32_t unicode_tolower(uint32_t cp) {
    if (cp >= 0xC0 && cp <= 0xD6) return cp + 0x20; // À-Ö -> à-ö
    if (cp >= 0xD8 && cp <= 0xDE) return cp + 0x20; // Ø-Þ -> ø-þ
    if (cp >= 0x0100 && cp <= 0x017D && !(cp & 1)) return cp + 1;
    if (cp == 0x0178) return 0x00FF; // Ÿ -> ÿ
    return cp;
}
static void utf8_encode(uint32_t cp, std::string& out) {
    if (cp < 0x80) out += (char)cp;
    else if (cp < 0x800) { out += (char)(0xC0 | (cp >> 6)); out += (char)(0x80 | (cp & 0x3F)); }
    else if (cp < 0x10000) { out += (char)(0xE0 | (cp >> 12)); out += (char)(0x80 | ((cp >> 6) & 0x3F)); out += (char)(0x80 | (cp & 0x3F)); }
    else { out += (char)(0xF0 | (cp >> 18)); out += (char)(0x80 | ((cp >> 12) & 0x3F)); out += (char)(0x80 | ((cp >> 6) & 0x3F)); out += (char)(0x80 | (cp & 0x3F)); }
}
static uint32_t utf8_decode(const std::string& s, size_t& pos) {
    unsigned char ch = s[pos];
    if (ch < 0x80) { pos++; return ch; }
    if (ch < 0xC0) { pos++; return ch; } // invalid continuation
    uint32_t cp;
    if (ch < 0xE0) { cp = (ch & 0x1F) << 6; if (pos+1<s.size()) cp |= (s[pos+1]&0x3F); pos+=2; }
    else if (ch < 0xF0) { cp = (ch & 0x0F) << 12; if(pos+1<s.size()) cp |= ((s[pos+1]&0x3F)<<6); if(pos+2<s.size()) cp |= (s[pos+2]&0x3F); pos+=3; }
    else { cp = (ch & 0x07) << 18; if(pos+1<s.size()) cp |= ((s[pos+1]&0x3F)<<12); if(pos+2<s.size()) cp |= ((s[pos+2]&0x3F)<<6); if(pos+3<s.size()) cp |= (s[pos+3]&0x3F); pos+=4; }
    return cp;
}
static std::string utf8_upper(const std::string& s) {
    std::string r; size_t pos = 0;
    while (pos < s.size()) { uint32_t cp = utf8_decode(s, pos); utf8_encode(unicode_toupper(cp < 0x80 ? toupper(cp) : unicode_toupper(cp)), r); }
    return r;
}
static std::string utf8_lower(const std::string& s) {
    std::string r; size_t pos = 0;
    while (pos < s.size()) { uint32_t cp = utf8_decode(s, pos); utf8_encode(unicode_tolower(cp < 0x80 ? tolower(cp) : unicode_tolower(cp)), r); }
    return r;
}
// utf8_charcount removed (unused, functionality inlined)

#include "Evaluator.hpp"
#include "Context.hpp"
#include "ASTNodes.hpp"
#include "DynamicLang.hpp"
#include "Runtime.hpp"

using namespace std;
using namespace nython;
using namespace nython::io;
using namespace nython::node;
using namespace nython::lexer;
using namespace nython::kernel;
using namespace nython::parser;
using namespace nython::reader;
using namespace nython::exception;

// ═══════════════════════════════════════════════════════════════════════════
// BUILT-IN FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

// Simple execution context that doesn't need full Runnable
static const std::set<std::string> builtin_set = {
    "len","type","str","int","float","bool","range","input","abs",
    "min","max","sum","list","map","print","isinstance","hasattr",
    "hex","oct","bin","ord","chr"
};

// Safe bigint to int64_t conversion
inline int64_t bigint_to_i64(nython::kernel::bigint bi) {
    // Use string conversion to avoid ambiguous operator overloads in C++20
    std::string s = bi.toString(10, false, true);
    if (s.empty() || s == "0") return 0;
    try { return std::stoll(s); }
    catch (...) { return 0; }
}

// Safe double extraction from Value (avoids long double -> double warning)
inline double to_double(const Value& v) {
    if (v.type == ValueType::DOUBLE) return static_cast<double>(v.value.d);
    if (v.type == ValueType::INTEGER) return (double)bigint_to_i64(v.value.i);
    return 0.0;
}





// Forward-declare struct so dispatch function signatures compile cleanly.
struct NythonExecutor;

// ── Forward declarations of module dispatch functions ─────────────────────
// Each is implemented in src/builtins/X.cpp
Value dispatch_tensor   (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_audio    (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_string   (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_io       (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_network  (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_math     (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_os       (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_data     (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_threading(NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_core     (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_gui      (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);
Value dispatch_lang     (NythonExecutor& E, const std::string& name, std::vector<Value>& args, Context* ctx);


struct NythonExecutor {
    Context* global_ctx;
    Runnable* runner;
    std::map<void*, std::string> func_names;
    std::vector<Value>* yield_sink_ = nullptr; // set during generator collection
    std::map<int, FILE*> file_handles{};
    int next_file_handle{1000};
    std::map<void*, Context*> closure_contexts;
    // ── Per-call context reclamation ────────────────────────────────────────
    // Every interpreted call allocated a Context that was never freed (~550
    // bytes a call: the Context plus the ContainerType map it news in its
    // constructor and no destructor releases).
    //
    // A context may outlive its call only if something retained a pointer to
    // it: a closure, a class body, or a child context that itself escaped.
    // Those are the only three retainers in this file, and each marks the
    // context AND its whole parent chain. Anything unmarked when the call
    // returns is provably unreachable and is freed.
    //
    // This is deliberately conservative: a missed retainer must cause a leak,
    // never a use-after-free, so escape marking walks upward and reaping only
    // ever happens for contexts this executor created for a single call.
    // unordered_set: this is probed once per call return, so an O(log n) lookup
    // against a set that grows with every closure and class is a per-call tax.
    std::unordered_set<Context*> escaped_ctxs_;
    void markEscaped(Context* c) {
        while (c && escaped_ctxs_.insert(c).second) c = c->parent;
    }
    void reapContext(Context* c) {
        if (!c) return;
        if (escaped_ctxs_.count(c)) return;
        // Container news its map and its destructor does not free it, and the
        // copy constructor is defaulted (shallow), so the shared destructor
        // cannot safely own it. Release it here, where this context is known
        // dead and known not to have been copied.
        if (c->container) { delete c->container; c->container = nullptr; }
        delete c;
    }
    // Frees the context on scope exit unless it escaped, including when the
    // body exits via a ReturnSignal or a user exception.
    struct CtxReaper {
        NythonExecutor* e;
        Context* c;
        CtxReaper(NythonExecutor* ex, Context* cx) : e(ex), c(cx) {}
        ~CtxReaper() { if (c) e->reapContext(c); }
        void release() { c = nullptr; }
        CtxReaper(const CtxReaper&) = delete;
        CtxReaper& operator=(const CtxReaper&) = delete;
    };
    int64_t closure_id_counter = 0;
    std::map<int64_t, Context*> closure_by_id;
    std::map<void*, int64_t> value_closure_id;
    std::vector<std::unique_ptr<std::string>> string_store; // keeps strings alive
    std::unordered_set<void*> string_ptrs_; // fast positive lookup for string pointers

    // Create a Value that stores a string (persists across Value copies)
    Value makeStringValue(const std::string& s) {
        string_store.push_back(std::make_unique<std::string>(s));
        Value v;
        v.type = ValueType::USERDATA;
        v.value.p = (void*)string_store.back().get();
        string_ptrs_.insert(v.value.p);
        return v;
    }

    // Get string from a string Value
    bool isStringValue(const Value& v) {
        if (v.type == ValueType::USERDATA && v.value.p && string_ptrs_.count(v.value.p))
            return true;
        return v.type == ValueType::USERDATA && v.value.p 
            && !func_names.count(v.value.p) 
            && !instance_to_class.count(v.value.p)
            && !instance_properties.count(v.value.p);
    }
    // func_names stores internal identifiers ("__func__:inner", "__lambda__",
    // "__class__:Point"); render them the way the VM does so the two engines
    // print the same thing.
    static std::string funcDisplayName(const std::string& fn) {
        if (fn.rfind("__class__:", 0) == 0) return "<class " + fn.substr(10) + ">";
        std::string n = fn;
        if (n.rfind("__func__:", 0) == 0) n = n.substr(9);
        if (n == "__lambda__" || n.empty()) n = "<lambda>";
        return "<function " + n + ">";
    }
    std::string getStringValue(Value v) {
        if (v.type == ValueType::USERDATA && v.value.p && string_ptrs_.count(v.value.p)) {
            return *static_cast<std::string*>(v.value.p);
        }
        if (isStringValue(v)) {
            return *static_cast<std::string*>(v.value.p);
        }
        if (v.type == ValueType::USERDATA && v.value.p && !func_names.count(v.value.p)) {
            return *static_cast<std::string*>(v.value.p);
        }
        // A function value fell through to Value::toString(), which renders any
        // USERDATA as the literal "user-data" — so printing a function showed
        // that instead of anything identifying. func_names already holds the
        // name, so use it and match the VM's "<function name>" spelling.
        if (v.type == ValueType::USERDATA && v.value.p) {
            auto fit = func_names.find(v.value.p);
            if (fit != func_names.end()) return funcDisplayName(fit->second);
        }
        return v.toString();
    } // maps USERDATA ptr -> function identifier

    // Produce a stable string key for any value (used for dict keys)
    std::string valueToKeyString(const Value& v) {
        if (v.type == ValueType::INTEGER) return std::to_string(bigint_to_i64(v.value.i));
        if (v.type == ValueType::DOUBLE) return v.toString();
        if (v.type == ValueType::BOOLEAN) return v.value.b ? "true" : "false";
        if (v.type == ValueType::NONE) return "none";
        if (v.type == ValueType::USERDATA && v.value.p && !func_names.count(v.value.p))
            return *static_cast<std::string*>(v.value.p);
        if (v.isCollectable() && v.value.gc) {
            auto* cont = dynamic_cast<Container*>(v.value.gc);
            if (cont && cont->container) {
                auto len_it = cont->container->find("__len__");
                int len = len_it != cont->container->end() ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                std::string s = "(";
                for (int i = 0; i < len; i++) {
                    if (i > 0) s += ", ";
                    auto it = cont->container->find(std::to_string(i));
                    if (it != cont->container->end()) s += valueToKeyString(it->second);
                }
                s += ")";
                return s;
            }
        }
        return v.toString();
    }

    NythonExecutor(const NythonExecutor&) = delete;
    NythonExecutor& operator=(const NythonExecutor&) = delete;
    NythonExecutor(Runnable* r) : global_ctx{nullptr}, runner(r),
        func_names{}, closure_contexts{}, closure_by_id{}, value_closure_id{},
        string_store{}, string_ptrs_{}, builtin_ptrs{},
        func_id_store{}, func_ast_nodes{}, imported_asts{},
        instance_store{}, instance_to_class{}, instance_properties{},
        class_by_name{}, super_parent_stack{}, class_parent{} {
        global_ctx = new Context(r, "global");
        registerBuiltins();
    }

    ~NythonExecutor() {
        delete global_ctx;
    }

    void registerBuiltin(const std::string& name) {
        // Skip if already registered
        if (builtin_ptrs.count(name)) return;
        Value v;
        v.type = ValueType::USERDATA;
        v.value.p = nullptr;
        // Store a unique pointer per builtin
        builtin_ptrs[name] = std::make_unique<std::string>(name);
        v.value.p = (void*)builtin_ptrs[name].get();
        func_names[v.value.p] = "__builtin__:" + name;
        global_ctx->defineByName(name, v);
    }

    std::unordered_map<std::string, std::unique_ptr<std::string>> builtin_ptrs;
public:
    // Used by the VM builtin bridge in main.cpp: is `name` a builtin this
    // executor registered, and where should a bridged call be evaluated?
    bool hasBuiltin(const std::string& name) const {
        return builtin_ptrs.find(name) != builtin_ptrs.end();
    }
    Context* globalContext() { return global_ctx; }
public:   // NythonExecutor is a struct: members default to public

    void registerBuiltins() {
        // Built-in values
        global_ctx->defineByName("true", Value(true));
        global_ctx->defineByName("false", Value(false));
        global_ctx->defineByName("none", NONE_VALUE);
        global_ctx->defineByName("null", NONE_VALUE);
        global_ctx->defineByName("undefined", UNDEFINED_VALUE);
        // Built-in functions
        std::vector<std::string> builtins = {
            "print","println","range","len","type","str","int","float","bool",
            "input","abs","min","max","round","sorted","reversed",
            "list","tuple","dict","set","map","filter","reduce","zip",
            "enumerate","sum","any","all","hasattr","getattr","setattr",
            "isinstance","issubclass","id","hash","hex","oct","bin",
            "chr","ord","repr","format","open","exit","quit",
            "pow","divmod","input","dict","display","show","is_int","is_float","is_string","is_list","is_none","is_bool","to_int","to_float","to_str","clamp","lerp","map_range","repeat_str","repeat","flatten","flat","shell","system","ls","cat","pwd","mkdir","write","exists","env","all","any","complex","slice","super","property",
            "staticmethod","classmethod","callable","dir","vars","globals","locals",
            "iter","next","help","Set","Counter","OrderedDict","deque","defaultdict","assert",
            "sqrt","sin","cos","tan","log","floor","ceil",
            "keys","values","items",
            "read_file","write_file","file_exists",
            "string_split","string_join","string_replace","string_contains",
            "string_lower","string_upper","string_strip","string_startswith",
            "string_endswith","string_format","string_count","string_find","string_slice",
            // ── Runtime language-extension builtins ──
            "lang_define_token","lang_define_rule","lang_define_macro",
            "lang_define_infix","lang_define_prefix","lang_define_operator",
            "lang_remove_token","lang_remove_rule","lang_remove_operator",
            "lang_list_tokens","lang_list_rules","lang_list_operators",
            "lang_registry_json","lang_eval","lang_version","lang_reset",
            // ── GUI builtins — value-returning ──────────────────────────────
            "gui_get_error","gui_sdl_version","gui_get_display_size","gui_get_window_size","gui_set_window_size","gui_set_cursor","gui_hash_id","gui_display_scale","gui_window_scale","gui_measure_text_w",
            // ── Previously implemented but never registered ──────────────
            // The module dispatchers implement 537 builtins; only 197 were
            // registered as global names, so the rest were unreachable and
            // silently evaluated to none. os_listdir, file_read, file_write,
            // getcwd, path_join and the whole filesystem layer were among
            // them, which is why the IDE could not open a real folder.
            "accuracy","agent_broadcast","agent_io","agent_listen","agent_net","agent_recv","agent_send","append_file",
            "append_text","argmax","argmin","array","atan2","attention","avg_pool1d","base64_decode",
            "base64_encode","batch_norm","batchnorm","binary_cross_entropy","broadcast","chdir","cmd","conv1d",
            "cos_sim","cosine_similarity","cross_entropy_loss","ctc_loss","device_info","dns_resolve","dropout","elu",
            "embedding","embedding_lookup","env_get","eprint","exec_cmd","exp","fclose","fft_magnitude",
            "file_append","file_close","file_copy","file_delete","file_open","file_read","file_readline","file_readlines",
            "file_rename","file_size","file_write","file_writelines","flush","fprint","fread","freadline",
            "fs_mkdirs","fs_stat","fs_walk","function","fwrite","gelu","getcwd","getenv",
            "gethostbyname","hash_md5","hash_sha256","hex_decode","hex_encode","html_strip","htonl","htons",
            "http_parse_request","http_respond","huber_loss","inet_aton","inet_ntoa","integer","ip_to_string","is_dict",
            "isalpha_str","isdigit_str","kb_load","kb_save","keepalive","kv_all","kv_del","kv_get",
            "kv_keys","kv_set","layer_norm","layernorm","leaky_relu","linspace","list_dir","listdir",
            "load_text","logspace","logsumexp","mat","mat_get","mat_mul","mat_shape","mat_transpose",
            "matmul","matrix","max_pool1d","md5","mel_filterbank","mfcc","mish","model_load",
            "model_save","mse_loss","multi_head_attention","mutex_create","mutex_lock","mutex_unlock","norm","ntohl",
            "ntohs","numerical_gradient","one_hot","ones","os_exec","os_exists","os_getcwd","os_getenv",
            "os_isdir","os_isfile","os_listdir","os_mkdir","os_path_abs","os_path_basename","os_path_dirname","os_path_ext",
            "os_path_join","os_remove","os_rename","os_setenv","path_basename","path_dirname","path_exists","path_ext",
            "path_isdir","path_isfile","path_join","popen","print_err","print_to","process_exec","rand_tensor",
            "randint","randn_tensor","random_choice","random_float","random_int","random_range","random_sample","random_seed",
            "random_shuffle","random_tensor","rcvbuf","re_findall","re_match","re_replace","re_search","re_split",
            "re_sub","re_test","read_bytes","read_text","readlines","regex_extract","regex_findall","regex_match",
            "regex_replace","regex_search","regex_split","relu","remove_file","return","reuseaddr","reuseport",
            "save_text","scaled_dot_attention","semaphore_acquire","semaphore_create","semaphore_release","sha256","sigmoid","signal_rms",
            "signal_window","signal_zero_crossings","silu","sizeof","sleep","sndbuf","socket_accept","socket_bind",
            "socket_close","socket_connect","socket_create","socket_create_tcp","socket_create_udp","socket_getpeername","socket_getsockname","socket_listen",
            "socket_recv","socket_recvfrom","socket_select","socket_send","socket_sendto","socket_setsockopt","socket_shutdown","socket_tcp",
            "socket_udp","softmax","softplus","std_dev","stft_magnitude","string","string_to_ip","swish",
            "tanh","tanh_act","tanh_fn","tcp_accept","tcp_close","tcp_connect","tcp_recv","tcp_recv_all",
            "tcp_send","tcp_server_create","tensor","tensor2d_conv","tensor2d_get","tensor2d_maxpool","tensor2d_set","tensor_abs",
            "tensor_add","tensor_apply","tensor_arange","tensor_argmax","tensor_argmin","tensor_benchmark","tensor_clamp","tensor_clip",
            "tensor_concat","tensor_corr","tensor_cosine_sim","tensor_cummax","tensor_cummin","tensor_cumprod","tensor_cumsum","tensor_diag",
            "tensor_diff","tensor_dot","tensor_dot_product","tensor_exp","tensor_eye","tensor_flatten","tensor_flip","tensor_gather",
            "tensor_histogram","tensor_linspace","tensor_load","tensor_log","tensor_matmul","tensor_max","tensor_mean","tensor_median",
            "tensor_min","tensor_mul","tensor_neg","tensor_norm","tensor_normalize","tensor_ones","tensor_outer","tensor_pad",
            "tensor_percentile","tensor_pow","tensor_rand","tensor_randn","tensor_reshape","tensor_roll","tensor_save","tensor_scale",
            "tensor_scatter_add","tensor_sign","tensor_slice","tensor_softmax","tensor_sort","tensor_split","tensor_sqrt","tensor_stack",
            "tensor_std","tensor_sub","tensor_sum","tensor_topk","tensor_transpose","tensor_unique","tensor_var","tensor_variance",
            "tensor_where","tensor_zeros","tensor_zscore","text_bow","text_char_ids","text_from_ids","text_ngrams","text_tokenize",
            "thread_create","thread_join","time_clock","time_date","time_elapsed","time_format","time_timestamp","typeof",
            "typeof_val","uniform","url_decode","url_encode","variance","where","write_bytes","write_text",
            "writelines","zeros","zip_extract_text","zip_list",
            "gui_create_window","gui_load_font","gui_measure_text",
            "gui_load_image","gui_poll_events",
            "gui_video_time","gui_video_duration",
            "gui_load_video",
            // ── GUI builtins — void (rendering, window ops) ─────────────────
            "gui_destroy_window","gui_center_window",
            "gui_maximize_window","gui_minimize_window","gui_restore_window",
            "gui_set_window_title","gui_set_window_icon",
            "gui_clear","gui_present",
            "gui_fill_rect","gui_draw_rect",
            "gui_fill_rounded_rect","gui_draw_rounded_rect",
            "gui_draw_text","gui_draw_image",
            "gui_draw_line","gui_draw_circle","gui_fill_circle",
            "gui_draw_shadow","gui_draw_gradient",
            "gui_draw_polygon","gui_fill_polygon",
            "gui_set_clip","gui_clear_clip",
            "gui_set_viewport","gui_clear_viewport",
            "gui_video_play","gui_video_pause","gui_video_stop",
            "gui_video_seek","gui_video_volume","gui_video_render",
            // ── JSON ────────────────────────────────────────────────────────
            "json_encode","json_decode","json_parse","json_stringify",
            // ── HTTP / network ───────────────────────────────────────────────
            "http_get","http_post","http_request","http_get_json","http_post_json",
            // ── Time ─────────────────────────────────────────────────────────
            "time_ms","time_now","time_sleep","thread_sleep"
        };
        for (auto& name : builtins) registerBuiltin(name);
        // Exception types
        std::vector<std::string> exc_types = {
            "Exception","BaseException","Error",
            "ValueError","TypeError","KeyError","IndexError","AttributeError",
            "NameError","RuntimeError","IOError","OSError","FileNotFoundError",
            "ZeroDivisionError","OverflowError","MemoryError","RecursionError",
            "StopIteration","GeneratorExit","SystemExit","KeyboardInterrupt",
            "AssertionError","NotImplementedError","PermissionError","TimeoutError"
        };
        for (auto& name : exc_types) registerBuiltin(name);
        // Math constants
        global_ctx->defineByName("PI", Value(3.14159265358979323846));
        global_ctx->defineByName("E", Value(2.71828182845904523536));
        global_ctx->defineByName("TAU", Value(6.28318530717958647692));
        global_ctx->defineByName("INFINITY", Value(std::numeric_limits<double>::infinity()));
#ifndef _WIN32
        // Socket-level option constants (SOL_SOCKET)
        global_ctx->defineByName("SOL_SOCKET",    Value((int)SOL_SOCKET));
        global_ctx->defineByName("SO_REUSEADDR",  Value((int)SO_REUSEADDR));
        #ifdef SO_REUSEPORT
        global_ctx->defineByName("SO_REUSEPORT",  Value((int)SO_REUSEPORT));
        #else
        global_ctx->defineByName("SO_REUSEPORT",  Value((int)SO_REUSEADDR));
        #endif
        global_ctx->defineByName("SO_KEEPALIVE",  Value((int)SO_KEEPALIVE));
        global_ctx->defineByName("SO_BROADCAST",  Value((int)SO_BROADCAST));
        global_ctx->defineByName("SO_RCVBUF",     Value((int)SO_RCVBUF));
        global_ctx->defineByName("SO_SNDBUF",     Value((int)SO_SNDBUF));
        global_ctx->defineByName("SO_LINGER",     Value((int)SO_LINGER));
        global_ctx->defineByName("SO_ERROR",      Value((int)SO_ERROR));
        global_ctx->defineByName("SO_TYPE",       Value((int)SO_TYPE));
        // Protocol-level option constants
        global_ctx->defineByName("IPPROTO_TCP",   Value((int)IPPROTO_TCP));
        global_ctx->defineByName("IPPROTO_UDP",   Value((int)IPPROTO_UDP));
        global_ctx->defineByName("IPPROTO_IP",    Value((int)IPPROTO_IP));
        global_ctx->defineByName("TCP_NODELAY",   Value((int)TCP_NODELAY));
        global_ctx->defineByName("TCP_KEEPIDLE",  Value((int)TCP_KEEPIDLE));
        global_ctx->defineByName("TCP_KEEPINTVL", Value((int)TCP_KEEPINTVL));
        global_ctx->defineByName("TCP_KEEPCNT",   Value((int)TCP_KEEPCNT));
        // Address family and socket type constants
        global_ctx->defineByName("AF_INET",       Value((int)AF_INET));
        global_ctx->defineByName("AF_INET6",      Value((int)AF_INET6));
        global_ctx->defineByName("AF_UNIX",       Value((int)AF_UNIX));
        global_ctx->defineByName("SOCK_STREAM",   Value((int)SOCK_STREAM));
        global_ctx->defineByName("SOCK_DGRAM",    Value((int)SOCK_DGRAM));
        global_ctx->defineByName("SOCK_RAW",      Value((int)SOCK_RAW));
        // Shutdown constants
        global_ctx->defineByName("SHUT_RD",       Value((int)SHUT_RD));
        global_ctx->defineByName("SHUT_WR",       Value((int)SHUT_WR));
        global_ctx->defineByName("SHUT_RDWR",     Value((int)SHUT_RDWR));
        // IP multicast
        global_ctx->defineByName("IP_ADD_MEMBERSHIP",  Value((int)IP_ADD_MEMBERSHIP));
        global_ctx->defineByName("IP_MULTICAST_TTL",   Value((int)IP_MULTICAST_TTL));
        global_ctx->defineByName("IP_MULTICAST_LOOP",  Value((int)IP_MULTICAST_LOOP));
        // Common errno-like socket error values
        global_ctx->defineByName("INADDR_ANY",         Value((int)INADDR_ANY));
        global_ctx->defineByName("INADDR_LOOPBACK",    Value((int)INADDR_LOOPBACK));
        global_ctx->defineByName("INADDR_BROADCAST",   Value((int)INADDR_BROADCAST));
#endif
    }

    Value execute(node_ptr ast) {
        if (!ast) return NONE_VALUE;
        return evalNode(ast, global_ctx);
    }

    Value evalNode(node_ptr node, Context* ctx) {
        if (!node) return NONE_VALUE;

        switch (node->type()) {
            case NodeType::SCRIPT: return evalScript(node, ctx);
            case NodeType::STATEMENTS: return evalStatements(node, ctx);
            case NodeType::BLOCK: return evalStatements(node, ctx);
            case NodeType::INTEGER: return evalInteger(node);
            case NodeType::FLOAT: return evalFloat(node);
            case NodeType::STRING: return evalString(node, ctx);
            case NodeType::TRUE: return Value(true);
            case NodeType::FALSE: return Value(false);
            case NodeType::NONE: return NONE_VALUE;
            case NodeType::UNDEFINED: return UNDEFINED_VALUE;
            case NodeType::VARIABLE: return evalVariable(node, ctx);
            case NodeType::VARIABLE_DECL: return evalVarDecl(node, ctx);
            case NodeType::ASSIGNMENT: return evalAssignment(node, ctx);
            case NodeType::ASSIGNMENT_AUG: return evalAugAssignment(node, ctx);
            case NodeType::BINARY: return evalBinary(node, ctx);
            case NodeType::UNARY: return evalUnary(node, ctx);
            case NodeType::PRINT: return evalPrint(node, ctx);
            case NodeType::IF: return evalIf(node, ctx);
            case NodeType::WHILE: return evalWhile(node, ctx);
            case NodeType::FOR: return evalFor(node, ctx);
            case NodeType::FUNCTION: return evalFunctionDecl(node, ctx);
            case NodeType::CLASS: return evalClassDecl(node, ctx);
            case NodeType::RETURN: return evalReturn(node, ctx);
            case NodeType::BREAK: throw std::string("break");
            case NodeType::CONTINUE: throw std::string("continue");
            case NodeType::PASS: return NONE_VALUE;
            case NodeType::CALL: return evalCall(node, ctx);
            case NodeType::ATTRIBUTE: return evalAttribute(node, ctx);
            case NodeType::SUBSCRIPT: return evalSubscript(node, ctx);
            case NodeType::LIST: return evalList(node, ctx);
            case NodeType::COMPLEX: return evalComprehension(node, ctx);
            case NodeType::MAP: return evalMap(node, ctx);
            case NodeType::TUPLE: return evalList(node, ctx);
            case NodeType::ARRAY: return evalList(node, ctx);
            case NodeType::RANGE: return evalRange(node, ctx);
            case NodeType::TRY: return evalTry(node, ctx);
            case NodeType::RAISE: return evalRaise(node, ctx);
            case NodeType::ASSERT: return evalAssert(node, ctx);
            case NodeType::IMPORT: return evalImport(node, ctx);
            case NodeType::ENUM: return evalEnum(node, ctx);
            case NodeType::SWITCH: return evalSwitch(node, ctx);
            case NodeType::DELETE: return evalDelete(node, ctx);
            case NodeType::MACRO_CALL: return evalMacroCall(node, ctx);
            case NodeType::DYN_BINOP:  return evalDynBinop(node, ctx);
            case NodeType::LAMBDA: return evalLambda(node, ctx);
            case NodeType::REPEAT: return evalRepeat(node, ctx);
            case NodeType::WITH: return evalWith(node, ctx);
            case NodeType::NAMESPACE: return evalNamespace(node, ctx);
            case NodeType::INTERFACE: return NONE_VALUE;
            case NodeType::YIELD: { auto yn = static_pointer_cast<YieldNode>(node); Value yv = yn->expr ? evalNode(yn->expr, ctx) : NONE_VALUE; if (yield_sink_) { yield_sink_->push_back(yv); return NONE_VALUE; } throw nython::node::YieldSignal(yv); }
            case NodeType::GLOBAL: return NONE_VALUE;
            case NodeType::SELF: return ctx->getByName("self");
            case NodeType::SUPER: return ctx->getByName("super");
            case NodeType::WALRUS: {
                // Walrus operator: (var name = expr) — evaluates expr, stores it, returns value
                auto wn = static_pointer_cast<WalrusNode>(node);
                Value v = evalNode(wn->init, ctx);
                ctx->defineByName(wn->name, v);
                return v;
            }
            default: return NONE_VALUE;
        }
    }

    // ─── SCRIPT / STATEMENTS ────────────────────────────────────────────
    Value evalScript(node_ptr node, Context* ctx) {
        Value result = NONE_VALUE;
        for (auto& child : node->statements()) {
            result = evalNode(child, ctx);
        }
        return result;
    }

    Value evalStatements(node_ptr node, Context* ctx) {
        Value result = NONE_VALUE;
        for (auto& child : node->statements()) {
            result = evalNode(child, ctx);
        }
        return result;
    }

    // ─── LITERALS ───────────────────────────────────────────────────────
    Value evalInteger(node_ptr node) {
        Token tok_copy = node->token(); auto& v = tok_copy.value;
        try {
            if (v.size() > 2 && v[0] == '0') {
                if (v[1]=='x'||v[1]=='X') return Value((int)std::stoi(v, nullptr, 16));
                if (v[1]=='o'||v[1]=='O') return Value((int)std::stoi(v.substr(2), nullptr, 8));
                if (v[1]=='b'||v[1]=='B') return Value((int)std::stoi(v.substr(2), nullptr, 2));
            }
            return Value((int)std::stoi(v));
        } catch (...) {
            try { return Value((long int)std::stoll(v)); }
            catch (...) { return Value(0); }
        }
    }

    Value evalFloat(node_ptr node) {
        try { return Value(std::stod(node->token().value)); }
        catch (...) { return Value(0.0); }
    }

    Value evalString(node_ptr node, Context* ctx = nullptr) {
        const std::string& raw = node->token().value;
        // Check for ${...} interpolation
        if (ctx && raw.find("${") != std::string::npos) {
            std::string result;
            size_t i = 0;
            while (i < raw.size()) {
                if (i + 1 < raw.size() && raw[i] == '$' && raw[i+1] == '{') {
                    i += 2; // skip ${
                    std::string expr_name;
                    while (i < raw.size() && raw[i] != '}') expr_name += raw[i++];
                    if (i < raw.size()) i++; // skip }
                    // Evaluate the variable name
                    try {
                        Value v = ctx->getByName(expr_name);
                        if (v.type == ValueType::INTEGER) result += std::to_string(bigint_to_i64(v.value.i));
                        else if (v.type == ValueType::DOUBLE) { char buf[64]; snprintf(buf, sizeof(buf), "%g", static_cast<double>(v.value.d)); result += buf; }
                        else if (v.type == ValueType::NONE) result += "none";
                        else if (v.type == ValueType::BOOLEAN) result += v.value.b ? "true" : "false";
                        else if (isStringValue(v)) result += *static_cast<std::string*>(v.value.p);
                        else result += getStringValue(v);
                    } catch (...) { result += "${" + expr_name + "}"; }
                } else {
                    result += raw[i++];
                }
            }
            return makeStringValue(result);
        }
        return makeStringValue(raw);
    }

    // ─── VARIABLES ──────────────────────────────────────────────────────


    Value evalVariable(node_ptr node, Context* ctx) {
        auto vn = static_pointer_cast<VariableNode>(node);
        // Check user-defined first
        Value found = ctx->getByName(vn->name);
        if (found.type != ValueType::UNDEFINED) return found;
        // Then check builtins — return a USERDATA marker
        if (builtin_set.count(vn->name)) {
            Value v;
            v.type = ValueType::USERDATA;
            v.value.p = nullptr; // null ptr = builtin
            func_names[nullptr] = "__builtin__:" + vn->name; // temporary, overwritten each call
            return v;
        }
        return found;
    }

    Value evalVarDecl(node_ptr node, Context* ctx) {
        auto vd = static_pointer_cast<VarDeclNode>(node);
        Value val = vd->init ? evalNode(vd->init, ctx) : NONE_VALUE;
        ctx->defineByName(vd->name, val);
        return val;
    }

    Value evalAssignment(node_ptr node, Context* ctx) {
        auto an = static_pointer_cast<AssignmentNode>(node);
        Value val = evalNode(an->value_node, ctx);
        if (an->target->type() == NodeType::VARIABLE) {
            auto vn = static_pointer_cast<VariableNode>(an->target);
            ctx->setByName(vn->name, val);
        } else if (an->target->type() == NodeType::ATTRIBUTE) {
            auto attr = static_pointer_cast<AttributeNode>(an->target);
            Value obj = evalNode(attr->object, ctx);
            // Store on instance properties (USERDATA instances)
            if (obj.type == ValueType::USERDATA && obj.value.p) {
                auto pit = instance_properties.find(obj.value.p);
                if (pit != instance_properties.end()) {
                    pit->second->defineByName(attr->attr, val);
                } else {
                    // Might be a class object (not an instance) — store as class var
                    void* class_ptr = obj.value.p;
                    void* ast_ptr = class_ptr;
                    auto ast_it = func_ast_nodes.find(class_ptr);
                    if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                    Node* class_node = (Node*)ast_ptr;
                    if (class_node && func_names.find(class_ptr) != func_names.end() && class_node->type() == NodeType::CLASS) {
                        auto* cn = static_cast<ClassNode*>(class_node);
                        class_vars_[cn->name + "." + attr->attr] = val;
                        // Also update class_ctx_map_ so subsequent reads via evalAttribute see the new value
                        auto cctx_it = class_ctx_map_.find((void*)class_node);
                        if (cctx_it != class_ctx_map_.end()) {
                            try { cctx_it->second->setByName(attr->attr, val); }
                            catch (...) { cctx_it->second->defineByName(attr->attr, val); }
                        }
                    }
                }
            }
            // Store on Collectable containers
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<nython::kernel::Container*>(obj.value.gc);
                if (cont && cont->container) (*cont->container)[attr->attr] = val;
            }
        } else if (an->target->type() == NodeType::SUBSCRIPT) {
            auto sub = static_pointer_cast<SubscriptNode>(an->target);
            Value obj = evalNode(sub->object, ctx);
            Value idx = evalNode(sub->index, ctx);
            // Check for __setitem__ on instances
            if (obj.type == ValueType::USERDATA && obj.value.p && !string_ptrs_.count(obj.value.p) && instance_to_class.count(obj.value.p)) {
                std::vector<Value> call_args = {idx, val};
                Value result = callMethod(obj, "__setitem__", call_args, ctx);
                if (result.type != ValueType::NONE) return val;
            }
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<Container*>(obj.value.gc);
                if (cont && cont->container) {
                    if (idx.type == ValueType::INTEGER) {
                        int64_t i = bigint_to_i64(idx.value.i);
                        if (i < 0) {
                            auto len_it = cont->container->find("__len__");
                            if (len_it != cont->container->end()) i += bigint_to_i64(len_it->second.value.i);
                        }
                        (*cont->container)[std::to_string(i)] = val;
                    } else if (idx.type == ValueType::USERDATA) {
                        (*cont->container)[getStringValue(idx)] = val;
                    } else if (idx.isCollectable() && idx.value.gc) {
                        // Tuple/list as key: use stable string representation
                        (*cont->container)[valueToKeyString(idx)] = val;
                    } else {
                        (*cont->container)[idx.toString()] = val;
                    }
                }
            }
        } else if (an->target->type() == NodeType::CALL) {
            // Slice assignment: arr[1:3] = [20, 30] is parsed as arr.slice(1,3) = [20,30]
            auto cn = static_pointer_cast<CallNode>(an->target);
            if (cn->callee && cn->callee->type() == NodeType::ATTRIBUTE) {
                auto attr = static_pointer_cast<AttributeNode>(cn->callee);
                if (attr->attr == "slice" && cn->args.size() >= 2) {
                    Value obj = evalNode(attr->object, ctx);
                    int64_t start = bigint_to_i64(evalNode(cn->args[0], ctx).value.i);
                    int64_t end = bigint_to_i64(evalNode(cn->args[1], ctx).value.i);
                    if (obj.isCollectable() && obj.value.gc) {
                        auto* cont = dynamic_cast<Container*>(obj.value.gc);
                        if (cont && cont->container) {
                            auto len_it = cont->container->find("__len__");
                            int64_t old_len = (len_it != cont->container->end()) ? bigint_to_i64(len_it->second.value.i) : 0;
                            if (start < 0) start += old_len;
                            if (end < 0) end += old_len;
                            if (start < 0) start = 0;
                            if (end > old_len) end = old_len;
                            int64_t slice_len = end - start;
                            // Get replacement values
                            int64_t repl_len = 0;
                            Container* repl_cont = nullptr;
                            if (val.isCollectable() && val.value.gc) {
                                repl_cont = dynamic_cast<Container*>(val.value.gc);
                                if (repl_cont && repl_cont->container) {
                                    auto rl = repl_cont->container->find("__len__");
                                    repl_len = (rl != repl_cont->container->end()) ? bigint_to_i64(rl->second.value.i) : 0;
                                }
                            }
                            int64_t new_len = old_len - slice_len + repl_len;
                            // Shift elements after the slice
                            if (repl_len != slice_len) {
                                if (repl_len < slice_len) {
                                    // Shrinking: shift left
                                    for (int64_t i = end; i < old_len; i++) {
                                        auto it2 = cont->container->find(std::to_string(i));
                                        if (it2 != cont->container->end())
                                            (*cont->container)[std::to_string(i - slice_len + repl_len)] = it2->second;
                                    }
                                    // Remove trailing
                                    for (int64_t i = new_len; i < old_len; i++)
                                        cont->container->erase(std::to_string(i));
                                } else {
                                    // Growing: shift right (from end)
                                    for (int64_t i = old_len - 1; i >= end; i--) {
                                        auto it2 = cont->container->find(std::to_string(i));
                                        if (it2 != cont->container->end())
                                            (*cont->container)[std::to_string(i + repl_len - slice_len)] = it2->second;
                                    }
                                }
                            }
                            // Insert replacement values
                            if (repl_cont && repl_cont->container) {
                                for (int64_t i = 0; i < repl_len; i++) {
                                    auto it2 = repl_cont->container->find(std::to_string(i));
                                    if (it2 != repl_cont->container->end())
                                        (*cont->container)[std::to_string(start + i)] = it2->second;
                                }
                            }
                            (*cont->container)["__len__"] = Value(static_cast<int>(new_len));
                        }
                    }
                }
            }
        }
        return val;
    }

    Value evalAugAssignment(node_ptr node, Context* ctx) {
        auto an = static_pointer_cast<AugAssignNode>(node);
        Value old_val = evalNode(an->target, ctx);
        Value new_val = evalNode(an->value_node, ctx);
        Value result;
        if (an->op == "+=") {
            // String concatenation
            if (old_val.type == ValueType::USERDATA || new_val.type == ValueType::USERDATA) {
                result = makeStringValue(getStringValue(old_val) + getStringValue(new_val));
            } else {
                result = old_val + new_val;
            }
        }
        else if (an->op == "-=") result = old_val - new_val;
        else if (an->op == "*=") result = old_val * new_val;
        else if (an->op == "/=") {
            if (old_val.type == ValueType::INTEGER && new_val.type == ValueType::INTEGER) {
                double a = static_cast<double>(bigint_to_i64(old_val.value.i));
                double b = static_cast<double>(bigint_to_i64(new_val.value.i));
                if (b == 0) throw std::string("__exc__:ZeroDivisionError:division by zero");
                result = Value(a / b);
            } else result = old_val / new_val;
        }
        else if (an->op == "%=") {
            if (old_val.type == ValueType::DOUBLE || new_val.type == ValueType::DOUBLE) {
                double a = old_val.type == ValueType::DOUBLE ? static_cast<double>(old_val.value.d) : static_cast<double>(bigint_to_i64(old_val.value.i));
                double b = new_val.type == ValueType::DOUBLE ? static_cast<double>(new_val.value.d) : static_cast<double>(bigint_to_i64(new_val.value.i));
                result = Value(std::fmod(a, b));
            } else result = old_val % new_val;
        }
        else if (an->op == "**=") {
            if (old_val.type == ValueType::DOUBLE || new_val.type == ValueType::DOUBLE) {
                double a = old_val.type == ValueType::DOUBLE ? static_cast<double>(old_val.value.d) : static_cast<double>(bigint_to_i64(old_val.value.i));
                double b = new_val.type == ValueType::DOUBLE ? static_cast<double>(new_val.value.d) : static_cast<double>(bigint_to_i64(new_val.value.i));
                result = Value(std::pow(a, b));
            }
            else if (old_val.type == ValueType::INTEGER && new_val.type == ValueType::INTEGER) {
                int64_t base = bigint_to_i64(old_val.value.i);
                int64_t exp = bigint_to_i64(new_val.value.i);
                int64_t r = 1;
                for (int64_t i = 0; i < exp; i++) r *= base;
                result = Value(static_cast<int>(r));
            } else {
                double a = old_val.type == ValueType::DOUBLE ? static_cast<double>(old_val.value.d) : static_cast<double>(bigint_to_i64(old_val.value.i));
                double b = new_val.type == ValueType::DOUBLE ? static_cast<double>(new_val.value.d) : static_cast<double>(bigint_to_i64(new_val.value.i));
                result = Value(std::pow(a, b));
            }
        }
        else if (an->op == "//=") {
            double da = old_val.type == ValueType::DOUBLE ? static_cast<double>(old_val.value.d) : static_cast<double>(bigint_to_i64(old_val.value.i));
            double db = new_val.type == ValueType::DOUBLE ? static_cast<double>(new_val.value.d) : static_cast<double>(bigint_to_i64(new_val.value.i));
            if (db == 0) throw std::string("__exc__:ZeroDivisionError:division by zero");
            result = Value(static_cast<int>(std::floor(da / db)));
        }
        else if (an->op == "&=") {
            int64_t a = old_val.type == ValueType::DOUBLE ? static_cast<int64_t>(old_val.value.d) : bigint_to_i64(old_val.value.i);
            int64_t b = new_val.type == ValueType::DOUBLE ? static_cast<int64_t>(new_val.value.d) : bigint_to_i64(new_val.value.i);
            result = Value(static_cast<int>(a & b));
        }
        else if (an->op == "|=") {
            int64_t a = old_val.type == ValueType::DOUBLE ? static_cast<int64_t>(old_val.value.d) : bigint_to_i64(old_val.value.i);
            int64_t b = new_val.type == ValueType::DOUBLE ? static_cast<int64_t>(new_val.value.d) : bigint_to_i64(new_val.value.i);
            result = Value(static_cast<int>(a | b));
        }
        else if (an->op == "^=") {
            int64_t a = old_val.type == ValueType::DOUBLE ? static_cast<int64_t>(old_val.value.d) : bigint_to_i64(old_val.value.i);
            int64_t b = new_val.type == ValueType::DOUBLE ? static_cast<int64_t>(new_val.value.d) : bigint_to_i64(new_val.value.i);
            result = Value(static_cast<int>(a ^ b));
        }
        else if (an->op == "<<=") {
            int64_t a = old_val.type == ValueType::DOUBLE ? static_cast<int64_t>(old_val.value.d) : bigint_to_i64(old_val.value.i);
            int64_t b = new_val.type == ValueType::DOUBLE ? static_cast<int64_t>(new_val.value.d) : bigint_to_i64(new_val.value.i);
            result = Value(static_cast<int>(a << b));
        }
        else if (an->op == ">>=") {
            int64_t a = old_val.type == ValueType::DOUBLE ? static_cast<int64_t>(old_val.value.d) : bigint_to_i64(old_val.value.i);
            int64_t b = new_val.type == ValueType::DOUBLE ? static_cast<int64_t>(new_val.value.d) : bigint_to_i64(new_val.value.i);
            result = Value(static_cast<int>(a >> b));
        }
        else result = new_val;
        if (an->target->type() == NodeType::VARIABLE) {
            ctx->setByName(static_pointer_cast<VariableNode>(an->target)->name, result);
        } else if (an->target->type() == NodeType::SUBSCRIPT) {
            // arr[i] += val
            auto sub = static_pointer_cast<SubscriptNode>(an->target);
            Value obj = evalNode(sub->object, ctx);
            Value idx = evalNode(sub->index, ctx);
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<Container*>(obj.value.gc);
                if (cont && cont->container) {
                    std::string key;
                    if (idx.type == ValueType::INTEGER) key = std::to_string(bigint_to_i64(idx.value.i));
                    else key = getStringValue(idx);
                    (*cont->container)[key] = result;
                }
            }
        } else if (an->target->type() == NodeType::ATTRIBUTE) {
            // obj.field += val
            auto attr = static_pointer_cast<AttributeNode>(an->target);
            Value obj = evalNode(attr->object, ctx);
            if (obj.type == ValueType::USERDATA && obj.value.p) {
                auto pit = instance_properties.find(obj.value.p);
                if (pit != instance_properties.end())
                    pit->second->setByName(attr->attr, result);
                else {
                    // Class variable aug-assign (Counter.count += 1)
                    void* ast_ptr = obj.value.p;
                    auto ast_it = func_ast_nodes.find(obj.value.p);
                    if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                    Node* class_node = (Node*)ast_ptr;
                    if (class_node && class_node->type() == NodeType::CLASS) {
                        auto* cn = static_cast<ClassNode*>(class_node);
                        class_vars_[cn->name + "." + attr->attr] = result;
                        auto cctx_it = class_ctx_map_.find((void*)class_node);
                        if (cctx_it != class_ctx_map_.end()) {
                            try { cctx_it->second->setByName(attr->attr, result); }
                            catch (...) { cctx_it->second->defineByName(attr->attr, result); }
                        }
                    }
                }
            }
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<Container*>(obj.value.gc);
                if (cont && cont->container) (*cont->container)[attr->attr] = result;
            }
        }
        return result;
    }

    // ─── EXPRESSIONS ────────────────────────────────────────────────────

    // ── Set union / intersection helpers ────────────────────────────────────────
    std::string set_key_str(Value v) {
        if (v.type == ValueType::INTEGER) return "i:" + std::to_string(bigint_to_i64(v.value.i));
        if (v.type == ValueType::DOUBLE)  return "d:" + std::to_string(v.value.d);
        if (v.type == ValueType::BOOLEAN) return std::string("b:") + (v.value.b ? "1" : "0");
        if (v.type == ValueType::NONE)    return "none";
        return "s:" + getStringValue(v);
    }
    std::vector<Value> collect_coll(const Value& v) {
        std::vector<Value> out;
        if (!v.isCollectable() || !v.value.gc) return out;
        auto* cont = dynamic_cast<Container*>(v.value.gc);
        if (!cont || !cont->container) return out;
        auto li = cont->container->find("__len__");
        int len = (li != cont->container->end()) ? (int)bigint_to_i64(li->second.value.i) : 0;
        for (int i = 0; i < len; i++) {
            auto it = cont->container->find(std::to_string(i));
            if (it != cont->container->end()) out.push_back(it->second);
        }
        return out;
    }
    Value build_set_val(std::vector<Value> items) {
        auto* obj = new Object((Runnable*)runner, "list", Type::LIST);
        obj->set("__set__", Value(1));
        int idx = 0;
        std::vector<std::string> seen;
        for (auto& v : items) {
            std::string k = set_key_str(v);
            bool dup = false; for (auto& s : seen) if (s==k){dup=true;break;}
            if (!dup) { seen.push_back(k); obj->set(std::to_string(idx++), v); }
        }
        obj->set("__len__", Value(idx));
        return Value((Collectable*)obj);
    }
    Value setUnion(const Value& a, const Value& b) {
        auto av = collect_coll(a); auto bv = collect_coll(b);
        for (auto& v : bv) av.push_back(v);
        return build_set_val(av);
    }
    Value setIntersect(const Value& a, const Value& b) {
        auto av = collect_coll(a); auto bv = collect_coll(b);
        std::vector<Value> result;
        for (auto& v : av) {
            std::string k = set_key_str(v);
            for (auto& w : bv) if (set_key_str(w)==k) { result.push_back(v); break; }
        }
        return build_set_val(result);
    }
    Value setDiff(const Value& a, const Value& b) {
        auto av = collect_coll(a); auto bv = collect_coll(b);
        std::vector<Value> result;
        for (auto& v : av) {
            std::string k = set_key_str(v);
            bool inB = false;
            for (auto& w : bv) if (set_key_str(w)==k) { inB=true; break; }
            if (!inB) result.push_back(v);
        }
        return build_set_val(result);
    }
    Value setSymDiff(const Value& a, const Value& b) {
        auto av = collect_coll(a); auto bv = collect_coll(b);
        std::vector<Value> result;
        for (auto& v : av) {
            std::string k = set_key_str(v);
            bool inB = false;
            for (auto& w : bv) if (set_key_str(w)==k) { inB=true; break; }
            if (!inB) result.push_back(v);
        }
        for (auto& v : bv) {
            std::string k = set_key_str(v);
            bool inA = false;
            for (auto& w : av) if (set_key_str(w)==k) { inA=true; break; }
            if (!inA) result.push_back(v);
        }
        return build_set_val(result);
    }

    Value evalBinary(node_ptr node, Context* ctx) {
        auto bn = static_pointer_cast<BinaryNode>(node);
        // Short-circuit for logical ops
        if (bn->op == "and" || bn->op == "&&") {
            Value lv = evalNode(bn->left, ctx);
            if (lv.isFalse() || lv.isNone()) return Value(false);
            return evalNode(bn->right, ctx);
        }
        if (bn->op == "or" || bn->op == "||") {
            Value lv = evalNode(bn->left, ctx);
            if (lv.isTrue()) return lv;
            return evalNode(bn->right, ctx);
        }
        if (bn->op == "xor" || bn->op == "^^") {
            Value lv = evalNode(bn->left, ctx);
            Value rv = evalNode(bn->right, ctx);
            bool lb = isTruthy(lv);
            bool rb = isTruthy(rv);
            return Value(lb != rb); // XOR: true when exactly one is true
        }

        Value lv = evalNode(bn->left, ctx);
        Value rv = evalNode(bn->right, ctx);

        // Operator overloading: check for dunder methods on instances
        if (lv.type == ValueType::USERDATA && lv.value.p && !string_ptrs_.count(lv.value.p) && instance_to_class.count(lv.value.p)) {
            std::string dunder;
            if (bn->op == "+") dunder = "__add__";
            else if (bn->op == "-") dunder = "__sub__";
            else if (bn->op == "*") dunder = "__mul__";
            else if (bn->op == "/") dunder = "__div__";
            else if (bn->op == "%") dunder = "__mod__";
            else if (bn->op == "**") dunder = "__pow__";
            else if (bn->op == "//") dunder = "__floordiv__";
            else if (bn->op == "&") dunder = "__and__";
            else if (bn->op == "|") dunder = "__or__";
            else if (bn->op == "^") dunder = "__xor__";
            else if (bn->op == "<<") dunder = "__lshift__";
            else if (bn->op == ">>") dunder = "__rshift__";
            else if (bn->op == "<") dunder = "__lt__";
            else if (bn->op == ">") dunder = "__gt__";
            else if (bn->op == "<=") dunder = "__le__";
            else if (bn->op == ">=") dunder = "__ge__";
            else if (bn->op == "==") dunder = "__eq__";
            else if (bn->op == "!=") dunder = "__ne__";
            if (!dunder.empty()) {
                std::vector<Value> call_args = {rv};
                Value result = callMethod(lv, dunder, call_args, ctx);
                if (result.type != ValueType::NONE || dunder == "__eq__" || dunder == "__ne__") {
                    // Only use dunder result if it didn't return none (method exists)
                    // For __eq__/__ne__, none means no method, but we need to check
                    // Try to detect if method actually existed:
                    // If result is NONE and it's not __eq__/__ne__, fall through
                    if (result.type != ValueType::NONE) return result;
                }
            }
        }

        if (bn->op == "+") {
            // List concatenation
            if (lv.type == ValueType::COLLECTABLE && rv.type == ValueType::COLLECTABLE) {
                auto* lc = dynamic_cast<Container*>(lv.value.gc);
                auto* rc = dynamic_cast<Container*>(rv.value.gc);
                if (lc && rc && lc->container && rc->container) {
                    auto li = lc->container->find("__len__");
                    auto ri = rc->container->find("__len__");
                    if (li != lc->container->end() && ri != rc->container->end()) {
                        int ll = (int)bigint_to_i64(li->second.value.i);
                        int rl = (int)bigint_to_i64(ri->second.value.i);
                        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
                        int idx = 0;
                        for (int i = 0; i < ll; i++) {
                            auto it = lc->container->find(std::to_string(i));
                            if (it != lc->container->end()) result->set(std::to_string(idx++), it->second);
                        }
                        for (int i = 0; i < rl; i++) {
                            auto it = rc->container->find(std::to_string(i));
                            if (it != rc->container->end()) result->set(std::to_string(idx++), it->second);
                        }
                        result->set("__len__", Value(idx));
                        return Value((Collectable*)result);
                    }
                }
            }
            // Integer addition
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                return Value(bigint(bigint_to_i64(lv.value.i) + bigint_to_i64(rv.value.i)));

            }
            // Mixed int/float
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::DOUBLE)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                return Value(static_cast<double>(a + b));
            }
            // String concatenation
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return makeStringValue(getStringValue(lv) + getStringValue(rv));
            }
            if (lv.type == ValueType::USERDATA || rv.type == ValueType::USERDATA) {
                return makeStringValue(getStringValue(lv) + getStringValue(rv));
            }
            return lv + rv;
        }
        if (bn->op == "-") {
            if (lv.isCollectable() && rv.isCollectable()) return setDiff(lv, rv);
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                return Value(bigint(bigint_to_i64(lv.value.i) - bigint_to_i64(rv.value.i)));

            }
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::DOUBLE)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                return Value(static_cast<double>(a - b));
            }
            return lv - rv;
        }
        if (bn->op == "*") {
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                int64_t a = bigint_to_i64(lv.value.i);
                int64_t b = bigint_to_i64(rv.value.i);
                return Value(bigint(a * b));
            }
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::DOUBLE)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                return Value(static_cast<double>(a * b));
            }
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::INTEGER) {
                std::string s = getStringValue(lv), r;
                for (int64_t i = 0; i < bigint_to_i64(rv.value.i); i++) r += s;
                return makeStringValue(r);
            }
            
            // Reverse: int * string  ->  3 * "ab" = "ababab"
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::USERDATA) {
                int times = static_cast<int>(bigint_to_i64(lv.value.i));
                std::string s = getStringValue(rv);
                std::string result;
                for (int i = 0; i < times; i++) result += s;
                return makeStringValue(result);
            }
            // Reverse: int * list  ->  3 * [1,2] = [1,2,1,2,1,2]
            if (lv.type == ValueType::INTEGER && rv.isCollectable()) {
                auto* cont = dynamic_cast<Container*>(rv.value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    int times = static_cast<int>(bigint_to_i64(lv.value.i));
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (int t = 0; t < times; t++) {
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end())
                                result->set(std::to_string(idx++), it->second);
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
            // List repetition: [1,2] * 3 = [1,2,1,2,1,2]
            if (lv.isCollectable() && rv.type == ValueType::INTEGER) {
                auto* cont = dynamic_cast<Container*>(lv.value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    int times = static_cast<int>(bigint_to_i64(rv.value.i));
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (int t = 0; t < times; t++) {
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end())
                                result->set(std::to_string(idx++), it->second);
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
            }
return lv * rv;
        }
        if (bn->op == "/") {
            // True division (always returns float, like Python)
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                int64_t a = bigint_to_i64(lv.value.i);
                int64_t b = bigint_to_i64(rv.value.i);
                if (b == 0) throw std::string("__exc__:ZeroDivisionError:division by zero");
                // Return float (true division) - use // for integer division
                return Value(static_cast<double>(a) / static_cast<double>(b));
            }
            // Float division when mixing types
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::DOUBLE)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                if (b == 0.0) throw std::string("__exc__:ZeroDivisionError:division by zero");
                return Value(static_cast<double>(a / b));
            }
            if (rv.type == ValueType::INTEGER && rv.value.i == 0) throw std::string("__exc__:ZeroDivisionError:division by zero");
            if (rv.type == ValueType::DOUBLE && rv.value.d == 0.0) throw std::string("__exc__:ZeroDivisionError:division by zero");
            return lv / rv;
        }
        if (bn->op == "//") {
            // Floor division
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                int64_t a = bigint_to_i64(lv.value.i);
                int64_t b = bigint_to_i64(rv.value.i);
                if (b == 0) throw std::string("__exc__:ZeroDivisionError:division by zero");
                int64_t result = a / b;
                // Floor toward negative infinity (Python semantics)
                if ((a ^ b) < 0 && result * b != a) result--;
                return Value(static_cast<int>(result));
            }
            if (lv.type == ValueType::DOUBLE || rv.type == ValueType::DOUBLE) {
                double a = (lv.type == ValueType::DOUBLE) ? static_cast<double>(lv.value.d) : static_cast<double>(bigint_to_i64(lv.value.i));
                double b = (rv.type == ValueType::DOUBLE) ? static_cast<double>(rv.value.d) : static_cast<double>(bigint_to_i64(rv.value.i));
                if (b == 0.0) throw std::string("__exc__:ZeroDivisionError:division by zero");
                return Value(std::floor(a / b));
            }
            return Value(0);
        }
        if (bn->op == "%") {
            // String % formatting: "fmt" % (args...)
            if (isStringValue(lv)) {
                std::string fmt = getStringValue(lv);
                // Collect args from rhs (tuple/list or single value)
                std::vector<Value> fargs;
                if (rv.isCollectable() && rv.value.gc) {
                    auto* cont = dynamic_cast<Container*>(rv.value.gc);
                    if (cont && cont->container) {
                        auto len_it = cont->container->find("__len__");
                        int len = len_it != cont->container->end() ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) fargs.push_back(it->second);
                        }
                    }
                } else {
                    fargs.push_back(rv);
                }
                // Apply format substitutions
                std::string result;
                size_t fi = 0; int ai = 0;
                while (fi < fmt.size()) {
                    if (fmt[fi] == '%' && fi + 1 < fmt.size()) {
                        char spec = fmt[fi + 1];
                        if (spec == '%') { result += '%'; fi += 2; continue; }
                        Value arg = (ai < (int)fargs.size()) ? fargs[ai++] : NONE_VALUE;
                        if (spec == 's') {
                            result += getStringValue(arg);
                        } else if (spec == 'd' || spec == 'i') {
                            int64_t iv = arg.type == ValueType::INTEGER ? bigint_to_i64(arg.value.i) : (int64_t)arg.value.d;
                            result += std::to_string(iv);
                        } else if (spec == 'f') {
                            double dv = arg.type == ValueType::DOUBLE ? arg.value.d : (double)bigint_to_i64(arg.value.i);
                            char buf[64]; std::snprintf(buf, sizeof(buf), "%.6f", dv);
                            result += buf;
                        } else if (spec == 'g') {
                            double dv = arg.type == ValueType::DOUBLE ? arg.value.d : (double)bigint_to_i64(arg.value.i);
                            char buf[64]; std::snprintf(buf, sizeof(buf), "%g", dv);
                            result += buf;
                        } else if (spec == 'r') {
                            result += getStringValue(arg);
                        } else {
                            result += fmt[fi]; result += spec;
                        }
                        fi += 2;
                    } else {
                        result += fmt[fi++];
                    }
                }
                return makeStringValue(result);
            }
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
                if (rv.value.i == 0) throw std::string("modulo by zero");
                int64_t ma = bigint_to_i64(lv.value.i), mb = bigint_to_i64(rv.value.i);
                int64_t mr = ma % mb;
                // Floor-modulo, to match this file's floor `//`: the remainder
                // takes the sign of the divisor, so -7 % 3 is 2, not -1.
                if (mr != 0 && ((mr < 0) != (mb < 0))) mr += mb;
                return Value(bigint(mr));
            }
            // Float modulo
            if (lv.type == ValueType::DOUBLE || rv.type == ValueType::DOUBLE) {
                double a = lv.type == ValueType::DOUBLE ? static_cast<double>(lv.value.d) : static_cast<double>(bigint_to_i64(lv.value.i));
                double b = rv.type == ValueType::DOUBLE ? static_cast<double>(rv.value.d) : static_cast<double>(bigint_to_i64(rv.value.i));
                if (b == 0) throw std::string("modulo by zero");
                return Value(std::fmod(a, b));

            }
            return lv % rv;
        }
        if (bn->op == "**") {
            double base_v = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
            double exp_v = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
            double pow_result = std::pow(base_v, exp_v);
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER && pow_result == (int64_t)pow_result) {
                int64_t ir = (int64_t)pow_result;
                // Was capped at 2^31 and demoted to double past that, so 2**62
                // printed as 4.61e+18 instead of the exact value. int64 range is
                // exactly the range where pow_result == (int64_t)pow_result still
                // holds, so no precision is claimed that double does not have.
                return Value(bigint(ir));
            }
            return Value(pow_result);
        }
        if (bn->op == "===" || bn->op == "equals") {
            // Deep/strict equality: same type AND same value
            if (lv.type != rv.type) return Value(false);
            if (lv.type == ValueType::INTEGER) return Value(bigint_to_i64(lv.value.i) == bigint_to_i64(rv.value.i));
            if (lv.type == ValueType::DOUBLE) return Value(lv.value.d == rv.value.d);
            if (lv.type == ValueType::BOOLEAN) return Value(lv.value.b == rv.value.b);
            if (lv.type == ValueType::NONE) return Value(true);
            if (lv.type == ValueType::USERDATA) return Value(getStringValue(lv) == getStringValue(rv));
            return Value(lv.toString() == rv.toString());
        }
        if (bn->op == "!==") {
            if (lv.type != rv.type) return Value(true);
            if (lv.type == ValueType::INTEGER) return Value(bigint_to_i64(lv.value.i) != bigint_to_i64(rv.value.i));
            if (lv.type == ValueType::DOUBLE) return Value(lv.value.d != rv.value.d);
            if (lv.type == ValueType::BOOLEAN) return Value(lv.value.b != rv.value.b);
            if (lv.type == ValueType::NONE) return Value(false);
            if (lv.type == ValueType::USERDATA) return Value(getStringValue(lv) != getStringValue(rv));
            return Value(lv.toString() != rv.toString());
        }
        if (bn->op == "==") {
            // String equality
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA)
                return Value(getStringValue(lv) == getStringValue(rv));
            // List/collection equality: compare element-by-element
            if (lv.isCollectable() && rv.isCollectable()) {
                auto* lc = dynamic_cast<Container*>(lv.value.gc);
                auto* rc = dynamic_cast<Container*>(rv.value.gc);
                if (lc && rc && lc->container && rc->container) {
                    auto li = lc->container->find("__len__");
                    auto ri = rc->container->find("__len__");
                    int ll = (li != lc->container->end()) ? static_cast<int>(bigint_to_i64(li->second.value.i)) : 0;
                    int rl = (ri != rc->container->end()) ? static_cast<int>(bigint_to_i64(ri->second.value.i)) : 0;
                    if (ll != rl) return Value(false);
                    for (int i = 0; i < ll; i++) {
                        auto a = lc->container->find(std::to_string(i));
                        auto b = rc->container->find(std::to_string(i));
                        if (a == lc->container->end() || b == rc->container->end()) return Value(false);
                        if (a->second.toString() != b->second.toString()) return Value(false);
                    }
                    return Value(true);
                }
            }
            // Mixed int/float comparison
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                return Value(a == b);
            }
            return Value(lv == rv);
        }
        if (bn->op == "!=") {
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA)
                return Value(getStringValue(lv) != getStringValue(rv));
            if ((lv.type == ValueType::INTEGER && rv.type == ValueType::DOUBLE) ||
                (lv.type == ValueType::DOUBLE && rv.type == ValueType::INTEGER)) {
                double a = (lv.type == ValueType::DOUBLE) ? (double)lv.value.d : (double)bigint_to_i64(lv.value.i);
                double b = (rv.type == ValueType::DOUBLE) ? (double)rv.value.d : (double)bigint_to_i64(rv.value.i);
                return Value(a != b);
            }
            return Value(!(lv == rv));
        }
        if (bn->op == "<") {
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return Value(getStringValue(lv) < getStringValue(rv));
            }
            double a_d, b_d;
            if (lv.type == ValueType::INTEGER) a_d = (double)bigint_to_i64(lv.value.i);
            else if (lv.type == ValueType::DOUBLE) a_d = (double)lv.value.d;
            else { return Value(false); }
            if (rv.type == ValueType::INTEGER) b_d = (double)bigint_to_i64(rv.value.i);
            else if (rv.type == ValueType::DOUBLE) b_d = (double)rv.value.d;
            else { return Value(false); }
            return Value(a_d < b_d);
        }
        if (bn->op == ">") {
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return Value(getStringValue(lv) > getStringValue(rv));
            }
            double a_d, b_d;
            if (lv.type == ValueType::INTEGER) a_d = (double)bigint_to_i64(lv.value.i);
            else if (lv.type == ValueType::DOUBLE) a_d = (double)lv.value.d;
            else { return Value(false); }
            if (rv.type == ValueType::INTEGER) b_d = (double)bigint_to_i64(rv.value.i);
            else if (rv.type == ValueType::DOUBLE) b_d = (double)rv.value.d;
            else { return Value(false); }
            return Value(a_d > b_d);
        }
        if (bn->op == "<=") {
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return Value(getStringValue(lv) <= getStringValue(rv));
            }
            double a_d, b_d;
            if (lv.type == ValueType::INTEGER) a_d = (double)bigint_to_i64(lv.value.i);
            else if (lv.type == ValueType::DOUBLE) a_d = (double)lv.value.d;
            else { return Value(false); }
            if (rv.type == ValueType::INTEGER) b_d = (double)bigint_to_i64(rv.value.i);
            else if (rv.type == ValueType::DOUBLE) b_d = (double)rv.value.d;
            else { return Value(false); }
            return Value(a_d <= b_d);
        }
        if (bn->op == ">=") {
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return Value(getStringValue(lv) >= getStringValue(rv));
            }
            double a_d, b_d;
            if (lv.type == ValueType::INTEGER) a_d = (double)bigint_to_i64(lv.value.i);
            else if (lv.type == ValueType::DOUBLE) a_d = (double)lv.value.d;
            else { return Value(false); }
            if (rv.type == ValueType::INTEGER) b_d = (double)bigint_to_i64(rv.value.i);
            else if (rv.type == ValueType::DOUBLE) b_d = (double)rv.value.d;
            else { return Value(false); }
            return Value(a_d >= b_d);
        }
        if (bn->op == "is") {
            // `is` answers "does the left operand belong to the right?" in the
            // widest useful sense, not only pointer identity:
            //
            //     1 is 1          -> true   (same value)
            //     1 is int        -> true   (type name)
            //     1 is Integer    -> true   (type alias)
            //     1 is Object     -> true   (everything is an Object)
            //     1 is "1"        -> false  (a number is not a string)
            //     obj is MyClass  -> true   (class, walking the parent chain)
            //
            // The right operand may be a TYPE NAME rather than a value, so the
            // type test is tried BEFORE evaluating identity — otherwise `int`
            // would resolve as an undefined variable and the test would silently
            // be false. `bn->right` is inspected rather than `rv` for that
            // reason.
            {
                std::string tn = typeNameOperand(bn->right, ctx);
                if (!tn.empty()) return Value(valueIsOfType(lv, tn, ctx));
            }
            if (lv.isNone() && rv.isNone()) return Value(true);
            if (lv.isNone() || rv.isNone()) return Value(false);
            if (lv.type == rv.type) {
                if (lv.type == ValueType::INTEGER) return Value(lv.value.i == rv.value.i);
                if (lv.type == ValueType::DOUBLE) return Value(lv.value.d == rv.value.d);
                if (lv.type == ValueType::BOOLEAN) return Value(lv.value.b == rv.value.b);
                if (lv.type == ValueType::USERDATA) {
                    // Two equal strings are the same value even when they are
                    // separate allocations: `"1" is "1"` was false here and true
                    // on the VM. Comparing by pointer is right for instances and
                    // wrong for strings, which are immutable values.
                    if (string_ptrs_.count(lv.value.p) && string_ptrs_.count(rv.value.p))
                        return Value(getStringValue(lv) == getStringValue(rv));
                    return Value(lv.value.p == rv.value.p);
                }
                if (lv.type == ValueType::COLLECTABLE) return Value(lv.value.gc == rv.value.gc);
            }
            return Value(false);
        }
        if (bn->op == "is not") {
            bn->op = "is";
            Value r = evalBinary(node, ctx);
            bn->op = "is not";
            return Value(!isTruthy(r));
        }
        if (bn->op == "in") {
            // Check for __contains__ dunder method on RHS
            if (rv.type == ValueType::USERDATA && rv.value.p && !string_ptrs_.count(rv.value.p) && instance_to_class.count(rv.value.p)) {
                std::vector<Value> args = {lv};
                Value result = callMethod(rv, "__contains__", args, ctx);
                if (result.type == ValueType::BOOLEAN) return result;
            }
            if (lv.type == ValueType::USERDATA && rv.type == ValueType::USERDATA) {
                return Value(getStringValue(rv).find(getStringValue(lv)) != std::string::npos);
            }
            if (rv.isCollectable() && rv.value.gc) {
                auto* cont = dynamic_cast<Container*>(rv.value.gc);
                if (cont && cont->container) {
                    auto len_it = cont->container->find("__len__");
                    if (len_it != cont->container->end()) {
                        int len = (int)bigint_to_i64(len_it->second.value.i);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it == cont->container->end()) continue;
                            if (lv == it->second) return Value(true);
                            if (lv.type == ValueType::USERDATA && it->second.type == ValueType::USERDATA &&
                                getStringValue(lv) == getStringValue(it->second)) return Value(true);
                        }
                        return Value(false);
                    }
                    std::string key = getStringValue(lv);
                    return Value(cont->container->count(key) > 0);
                }
            }
            return Value(false);
        }
        if (bn->op == "not in") {
            bn->op = "in";
            Value r = evalBinary(node, ctx);
            bn->op = "not in";
            return Value(!isTruthy(r));
        }
        if (bn->op == "<<") {
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER)
                return Value((int)(bigint_to_i64(lv.value.i) << bigint_to_i64(rv.value.i)));

            return Value(0);
        }
        if (bn->op == ">>") {
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER)
                return Value((int)(bigint_to_i64(lv.value.i) >> bigint_to_i64(rv.value.i)));

            return Value(0);
        }
        if (bn->op == "|") {
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER)
                return Value(static_cast<int>(bigint_to_i64(lv.value.i) | bigint_to_i64(rv.value.i)));
            // Set union
            if (lv.isCollectable() && rv.isCollectable()) return setUnion(lv, rv);
            return Value(0);
        }
        if (bn->op == "&") {
            // Set intersection
            if (lv.isCollectable() && rv.isCollectable()) return setIntersect(lv, rv);
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER)
                return Value(static_cast<int>(bigint_to_i64(lv.value.i) & bigint_to_i64(rv.value.i)));
            return Value(0);
        }
        if (bn->op == "^") {
            if (lv.isCollectable() && rv.isCollectable()) return setSymDiff(lv, rv);
            if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER)
                return Value(static_cast<int>(bigint_to_i64(lv.value.i) ^ bigint_to_i64(rv.value.i)));
            return Value(0);
        }
        return NONE_VALUE;
    }

    Value evalUnary(node_ptr node, Context* ctx) {
        auto un = static_pointer_cast<UnaryNode>(node);
        Value v = evalNode(un->operand, ctx);
        if (un->op == "+") {
            return v; // unary plus is identity
        }
        if (un->op == "-") {
            if (v.type == ValueType::INTEGER) {
                int64_t val = (long long)v.value.i;
                nython::kernel::bigint zero(0);
                if (v.value.i < zero) val = -val;
                return Value((int)(-val));
            }
            if (v.type == ValueType::DOUBLE) return Value(-v.value.d);
            return Value(0) - v;
        }
        if (un->op == "+" ) return v;
        if (un->op == "!" || un->op == "not") return Value(v.isFalse() || v.isNone());
        if (un->op == "~") {
            if (v.type == ValueType::INTEGER)
                return Value(static_cast<int>(~bigint_to_i64(v.value.i)));
            return Value(0);
        }
        if (un->op == "++" || un->op == "--") {
            Value result = (un->op == "++") ? v + Value(1) : v - Value(1);
            // Post-increment/decrement: update the variable in context
            if (un->operand->type() == NodeType::VARIABLE) {
                ctx->setByName(un->operand->value(), result);
            } else if (un->operand->type() == NodeType::ATTRIBUTE) {
                // Handle obj.field++ 
                auto attr = static_pointer_cast<AttributeNode>(un->operand);
                Value obj = evalNode(attr->object, ctx);
                if (obj.type == ValueType::USERDATA && obj.value.p) {
                    auto pit = instance_properties.find(obj.value.p);
                    if (pit != instance_properties.end())
                        pit->second->setByName(attr->attr, result);
                }
            }
            return v; // return OLD value (post-increment)
        }
        return v;
    }

    // ─── PRINT ──────────────────────────────────────────────────────────
    Value evalPrint(node_ptr node, Context* ctx) {
        auto pn = static_pointer_cast<PrintNode>(node);
        for (size_t i = 0; i < pn->args.size(); i++) {
            if (i > 0) std::cout << " ";
            Value v = evalNode(pn->args[i], ctx);
            printValue(v, ctx);
        }
        std::cout << std::endl;
        return NONE_VALUE;
    }

    void printValueRepr(Value v, Context* ctx = nullptr) {
        if (v.type == ValueType::USERDATA && v.value.p && func_names.count(v.value.p)
            && !instance_to_class.count(v.value.p) && !string_ptrs_.count(v.value.p)) {
            std::cout << funcDisplayName(func_names[v.value.p]);
            return;
        }
        if (v.type == ValueType::USERDATA && v.value.p
            && (string_ptrs_.count(v.value.p)
                || (!func_names.count(v.value.p)
                    && !instance_to_class.count(v.value.p)))) {
            std::cout << "'" << *(std::string*)v.value.p << "'";
        } else {
            printValue(v, ctx);
        }
    }

    void printValue(Value v, Context* ctx = nullptr) {
        switch (v.type) {
            case ValueType::NONE: std::cout << "none"; break;
            case ValueType::BOOLEAN: std::cout << (v.value.b ? "true" : "false"); break;
            case ValueType::INTEGER: std::cout << v.value.i; break;
            case ValueType::DOUBLE: std::cout << v.toString(); break;
            case ValueType::UNDEFINED: std::cout << "undefined"; break;
            case ValueType::COLLECTABLE:
                if (v.value.gc) {
                    auto* cont = dynamic_cast<Container*>(v.value.gc);
                    if (cont && cont->container) {
                        auto len_it = cont->container->find("__len__");
                        if (len_it != cont->container->end()) {
                            int len = (int)bigint_to_i64(len_it->second.value.i);
                            bool is_tup = cont->container->count("__tuple__") > 0;
                            bool is_set2 = cont->container->count("__set__") > 0;
                            std::cout << (is_tup ? "(" : (is_set2 ? "{" : "["));
                            for (int i = 0; i < len; i++) {
                                if (i > 0) std::cout << ", ";
                                auto eit = cont->container->find(std::to_string(i));
                                if (eit != cont->container->end()) printValueRepr(eit->second);
                            }
                            if (is_tup && len == 1) std::cout << ",";
                            std::cout << (is_tup ? ")" : (is_set2 ? "}" : "]"));
                        } else {
                            // Map or generic object
                            std::cout << "{";
                            bool first = true;
                            for (auto& [k, val] : *cont->container) {
                                if (k == "__len__") continue;
                                if (!first) std::cout << ", ";
                                std::cout << k << ": ";
                                printValue(val);
                                first = false;
                            }
                            std::cout << "}";
                        }
                    } else {
                        std::cout << v.value.gc->toString();
                    }
                } else std::cout << "none";
                break;
            case ValueType::USERDATA:
                if (v.value.p) {
                    if (string_ptrs_.count(v.value.p)) {
                        // Known string pointer
                        std::cout << *(std::string*)v.value.p;
                    } else if (instance_to_class.count(v.value.p)) {
                        // Class instance - use __str__ if available
                        std::vector<Value> sa = {v};
                        Value sv = callBuiltin("str", sa, ctx);
                        if (sv.type == ValueType::USERDATA && sv.value.p)
                            std::cout << *(std::string*)sv.value.p;
                        else
                            std::cout << sv.toString();
                    } else if (!func_names.count(v.value.p)) {
                        // Plain string
                        std::cout << *(std::string*)v.value.p;
                    } else {
                        // A function value. This printed "none", which is
                        // actively misleading: the function is perfectly live
                        // (calling it works, and it compares != none), it just
                        // had no display case. Match the VM's spelling.
                        std::cout << funcDisplayName(func_names[v.value.p]);
                    }
                } else std::cout << "none";
                break;
            default: {
                    // Check if it's a list/collection and print nicely
                    auto* cont = dynamic_cast<Container*>(v.value.gc);
                    if (cont && cont->container) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        std::cout << "[";
                        for (int i = 0; i < len; i++) {
                            if (i > 0) std::cout << ", ";
                            auto eit = cont->container->find(std::to_string(i));
                            if (eit != cont->container->end()) printValueRepr(eit->second);
                        }
                        std::cout << "]";
                    } else {
                        std::cout << v.toString();
                    }
                    break;
                }
        }
    }

    // ─── CONTROL FLOW ───────────────────────────────────────────────────
    Value evalIf(node_ptr node, Context* ctx) {
        auto in = static_pointer_cast<IfNode>(node);
        Value cond = evalNode(in->condition, ctx);
        if (isTruthy(cond)) return evalNode(in->then_branch, ctx);
        for (auto& ei : in->elseif_branches) {
            auto eif = static_pointer_cast<IfNode>(ei);
            if (isTruthy(evalNode(eif->condition, ctx))) return evalNode(eif->then_branch, ctx);
        }
        if (in->else_branch) return evalNode(in->else_branch, ctx);
        return NONE_VALUE;
    }

    Value evalWhile(node_ptr node, Context* ctx) {
        auto wn = static_pointer_cast<WhileNode>(node);
        Value result = NONE_VALUE;
        bool broke = false;
        while (isTruthy(evalNode(wn->condition, ctx))) {
            try { result = evalNode(wn->body, ctx); }
            catch (std::string& flow) {
                if (flow == "break") { broke = true; break; }
                if (flow == "continue") continue;
            }
        }
        // while/else: execute else branch only on natural exit (no break)
        if (!broke && wn->else_branch) result = evalNode(wn->else_branch, ctx);
        return result;
    }

    Value evalFor(node_ptr node, Context* ctx) {
        auto fn = static_pointer_cast<ForNode>(node);
        bool broke = false;
        Value iter_val = evalNode(fn->iterable, ctx);
        std::string var_name = fn->var->value();
        Value result = NONE_VALUE;

        // range() returns an integer — iterate 0..n-1
        if (iter_val.type == ValueType::INTEGER) {
            int64_t n = bigint_to_i64(iter_val.value.i);
            for (int64_t i = 0; i < n; i++) {
                ctx->defineByName(var_name, Value((int)i));
                try { result = evalNode(fn->body, ctx); }
                catch (std::string& flow) { if (flow == "break") { broke = true; break; } if (flow == "continue") continue; throw; }
            }
            if (!broke && fn->else_branch) result = evalNode(fn->else_branch, ctx);
            return result;
        }

        // List/collection iteration — iterate by index order
        if (iter_val.isCollectable() && iter_val.value.gc) {
            auto* cont = dynamic_cast<Container*>(iter_val.value.gc);
            if (cont && cont->container) {
                // Check if this is a list (has numeric indices) or a map (has string keys)
                auto len_it = cont->container->find("__len__");
                int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                bool is_list = (len > 0) || cont->container->count("0");
                
                if (!is_list) {
                    // Dict/map iteration — iterate all non-internal keys
                    for (auto& [key, val] : *cont->container) {
                        if (key.empty() || key[0] == '_') continue; // skip __len__ etc
                        ctx->defineByName(var_name, makeStringValue(key));
                        try { result = evalNode(fn->body, ctx); }
                        catch (std::string& flow) { if (flow == "break") { broke = true; break; } if (flow == "continue") continue; throw; }
                    }
                    return result;
                }
                
                // List iteration by numeric index
                for (int i = 0; i < len; i++) {
                    std::string key = std::to_string(i);
                    auto it = cont->container->find(key);
                    if (it != cont->container->end()) {
                        Value elem = it->second;
                        if (!fn->unpack_vars.empty() && elem.isCollectable() && elem.value.gc) {
                            // Tuple unpacking: destructure element
                            auto* elem_cont = dynamic_cast<Container*>(elem.value.gc);
                            if (elem_cont && elem_cont->container) {
                                // First var gets index 0
                                auto it0 = elem_cont->container->find("0");
                                if (it0 != elem_cont->container->end())
                                    ctx->defineByName(var_name, it0->second);
                                // Remaining vars get indices 1, 2, ...
                                for (size_t ui = 0; ui < fn->unpack_vars.size(); ui++) {
                                    auto itN = elem_cont->container->find(std::to_string(ui + 1));
                                    if (itN != elem_cont->container->end())
                                        ctx->defineByName(fn->unpack_vars[ui]->value(), itN->second);
                                }
                            }
                        } else {
                            ctx->defineByName(var_name, elem);
                        }
                        try { result = evalNode(fn->body, ctx); }
                        catch (std::string& flow) { if (flow == "break") { broke = true; break; } if (flow == "continue") continue; throw; }
                    }
                }
            }
            if (!broke && fn->else_branch) result = evalNode(fn->else_branch, ctx);
            return result;
        }

        // String iteration — iterate characters
        if (iter_val.type == ValueType::USERDATA && iter_val.value.p) {
            // Check if it's a string (not in func_names)
            if (!func_names.count(iter_val.value.p)) {
                std::string* sp = static_cast<std::string*>(iter_val.value.p);
                for (size_t i = 0; i < sp->size(); i++) {
                    std::string ch(1, (*sp)[i]);
                    ctx->defineByName(var_name, makeStringValue(ch));
                    try { result = evalNode(fn->body, ctx); }
                    catch (std::string& flow) { if (flow == "break") { broke = true; break; } if (flow == "continue") continue; throw; }
                }
                if (!broke && fn->else_branch) result = evalNode(fn->else_branch, ctx);
                return result;
            }
        }

        // __iter__/__next__ protocol for user-defined iterables
        if (iter_val.type == ValueType::USERDATA && iter_val.value.p && !string_ptrs_.count(iter_val.value.p) && instance_to_class.count(iter_val.value.p)) {
            // Call __iter__ if present to get the iterator (may return self)
            std::vector<Value> no_args;
            Value iterator = iter_val;
            try {
                Value it = callMethod(iter_val, "__iter__", no_args, ctx);
                if (it.type != ValueType::NONE && it.type != ValueType::UNDEFINED) iterator = it;
            } catch (...) {}
            // Now call __next__ repeatedly until StopIteration
            while (true) {
                Value item;
                bool stop = false;
                try {
                    item = callMethod(iterator, "__next__", no_args, ctx);
                } catch (nython::node::ReturnSignal& rs) {
                    item = rs.value;
                } catch (std::string& exc) {
                    if (exc.find("StopIteration") != std::string::npos) { stop = true; }
                    else throw;
                } catch (...) { stop = true; }
                if (stop) break;
                // Unpack tuples for k,v iteration
                if (!fn->unpack_vars.empty() && item.isCollectable()) {
                    auto* cont = dynamic_cast<Container*>(item.value.gc);
                    if (cont && cont->container) {
                        ctx->defineByName(var_name, cont->container->count("0") ? (*cont->container)["0"] : NONE_VALUE);
                        for (size_t ui = 0; ui < fn->unpack_vars.size(); ui++) {
                            std::string uname = fn->unpack_vars[ui]->value();
                            auto uit = cont->container->find(std::to_string(ui + 1));
                            ctx->defineByName(uname, uit != cont->container->end() ? uit->second : NONE_VALUE);
                        }
                    }
                } else {
                    ctx->defineByName(var_name, item);
                }
                try { result = evalNode(fn->body, ctx); }
                catch (std::string& flow) { if (flow == "break") { broke = true; break; } if (flow == "continue") continue; throw; }
            }
            if (!broke && fn->else_branch) result = evalNode(fn->else_branch, ctx);
            return result;
        }

        // Execute else branch if loop completed without break
        if (!broke && fn->else_branch) {
            result = evalNode(fn->else_branch, ctx);
        }
        return result;
    }

    Value evalRepeat(node_ptr node, Context* ctx) {
        auto rn = static_pointer_cast<RepeatNode>(node);
        Value count = evalNode(rn->count, ctx);
        int64_t n = (count.type == ValueType::INTEGER) ? bigint_to_i64(count.value.i) : 0;
        Value result = NONE_VALUE;
        for (int64_t i = 0; i < n; i++) {
            try { result = evalNode(rn->body, ctx); }
            catch (std::string& flow) {
                if (flow == "break") break;
                if (flow == "continue") continue;
            }
        }
        return result;
    }

    Value evalSwitch(node_ptr node, Context* ctx) {
        auto sn = static_pointer_cast<SwitchNode>(node);
        Value subject = evalNode(sn->subject, ctx);
        for (auto& c : sn->cases) {
            auto cn = static_pointer_cast<CaseNode>(c);
            // Wildcard: `case _:` acts as a catch-all — also triggers if case val is UNDEFINED
            bool is_wildcard = (cn->value_node->value() == "_");
            if (!is_wildcard) {
                Value case_val_probe = evalNode(cn->value_node, ctx);
                if (case_val_probe.type == ValueType::UNDEFINED) is_wildcard = true;
            }
            if (is_wildcard) {
                try { return evalNode(cn->body, ctx); }
                catch (nython::node::ReturnSignal& r) { throw; }
                catch (...) { throw; }
            }
            Value case_val = evalNode(cn->value_node, ctx);
            // Compare using type-aware comparison
            bool match = false;
            if (subject.type == ValueType::INTEGER && case_val.type == ValueType::INTEGER)
                match = bigint_to_i64(subject.value.i) == bigint_to_i64(case_val.value.i);
            else if (subject.type == ValueType::DOUBLE && case_val.type == ValueType::DOUBLE)
                match = subject.value.d == case_val.value.d;
            else if (subject.type == ValueType::BOOLEAN && case_val.type == ValueType::BOOLEAN)
                match = subject.value.b == case_val.value.b;
            else if (isStringValue(subject) || isStringValue(case_val))
                match = getStringValue(subject) == getStringValue(case_val);
            else
                match = subject.equals(case_val);
            if (match) return evalNode(cn->body, ctx);
        }
        if (sn->default_case) {
            auto dn = static_pointer_cast<DefaultNode>(sn->default_case);
            if (dn->body) return evalNode(dn->body, ctx);
        }
        return NONE_VALUE;
    }

    // ─── FUNCTION / CLASS / LAMBDA ──────────────────────────────────────
    Value evalFunctionDecl(node_ptr node, Context* ctx) {
        auto fn = static_pointer_cast<FunctionNode>(node);
        // Create a unique identity per function instance using a counter
        int64_t fid = ++closure_id_counter;
        auto unique_key = std::make_unique<int64_t>(fid);
        void* unique_ptr = (void*)unique_key.get();
        func_id_store.push_back(std::move(unique_key));

        Value func_val;
        func_val.type = ValueType::USERDATA;
        func_val.value.p = unique_ptr;
        func_names[unique_ptr] = "__func__:" + fn->name;
        closure_contexts[unique_ptr] = ctx;
        markEscaped(ctx);
        // Also store the AST node pointer so we can find the FunctionNode later
        func_ast_nodes[unique_ptr] = (void*)node.get();

        ctx->defineByName(fn->name, func_val);
        return func_val;
    }



    // Check if an AST subtree contains any YieldNode (used to skip generator probe)
    bool hasYield(node_ptr node) {
        if (!node) return false;
        if (node->type() == NodeType::YIELD) return true;
        // Check children via dynamic casts of common container nodes
        if (auto* blk = dynamic_cast<BlockNode*>(node.get())) {
            for (auto& s : blk->statements()) if (hasYield(s)) return true;
        }
        if (auto* fn = dynamic_cast<FunctionNode*>(node.get())) {
            // Don't recurse into nested function defs (they are separate generators)
            return false;
        }
        if (auto* ifn = dynamic_cast<IfNode*>(node.get())) {
            return hasYield(ifn->then_branch) || hasYield(ifn->else_branch);
        }
        if (auto* wn = dynamic_cast<WhileNode*>(node.get())) {
            return hasYield(wn->body);
        }
        if (auto* forn = dynamic_cast<ForNode*>(node.get())) {
            return hasYield(forn->body);
        }
        if (auto* tryn = dynamic_cast<TryNode*>(node.get())) {
            return hasYield(tryn->body);
        }
        // Check inside var declarations and assignments (yield as expression)
        if (auto* vd = dynamic_cast<VarDeclNode*>(node.get())) {
            return vd->init && hasYield(vd->init);
        }
        if (auto* an = dynamic_cast<AssignmentNode*>(node.get())) {
            return hasYield(an->value_node);
        }
        return false;
    }

    // Wrap a plain function Value into a method bound to `self_val`.
    // Returns fn_val unchanged if it is not a user-defined function/lambda.
    Value makeBoundMethod(Value fn_val, Value self_val) {
        if (fn_val.type != ValueType::USERDATA || !fn_val.value.p) return fn_val;
        if (string_ptrs_.count(fn_val.value.p)) return fn_val;
        auto fit = func_names.find(fn_val.value.p);
        if (fit == func_names.end()) return fn_val;
        const std::string& tag = fit->second;
        // Only bind real methods. Static methods, class methods, properties and
        // builtins must keep their existing calling convention.
        if (tag.find("__func__:") != 0 && tag.find("__lambda__") != 0) return fn_val;
        if (tag.find("__static__") != std::string::npos) return fn_val;
        if (tag.find("__classmethod__") != std::string::npos) return fn_val;
        if (tag.find("__property__") != std::string::npos) return fn_val;
        // The function must actually declare `self` as its first parameter,
        // otherwise it is a plain function stored on the instance and binding
        // would corrupt its arguments instead of fixing them.
        void* ast_ptr = fn_val.value.p;
        auto ast_it = func_ast_nodes.find(fn_val.value.p);
        if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
        Node* raw = (Node*)ast_ptr;
        if (!raw || raw->type() != NodeType::FUNCTION) return fn_val;
        auto* fn = static_cast<FunctionNode*>(raw);
        if (fn->params.empty()) return fn_val;
        const std::string p0 = fn->params[0]->value();
        if (p0 != "self" && p0 != "this") return fn_val;
        // Reuse an existing binding for this exact (method, instance) pair.
        //
        // Without this, every read of `obj.method` as a VALUE allocated a fresh
        // bound method plus four map entries, none of which were ever released.
        // A loop doing `var f = o.m` leaked ~0.5 KB per iteration: 200k
        // iterations reached 109 MB and 2M reached 1023 MB. The earlier check
        // looked up fn_val.value.p in bound_self_, but that map is keyed by the
        // NEW bound pointer, so it could never hit.
        auto ck = std::make_pair(fn_val.value.p, self_val.value.p);
        auto cached = bound_cache_.find(ck);
        if (cached != bound_cache_.end()) {
            Value hit;
            hit.type    = ValueType::USERDATA;
            hit.value.p = cached->second;
            return hit;
        }

        auto holder = std::make_unique<std::string>("__bound__:" + fn->name);
        void* bp = (void*)holder.get();
        bound_store_.push_back(std::move(holder));
        func_names[bp]      = tag;          // keep "__func__:name" so call paths match
        func_ast_nodes[bp]  = ast_ptr;      // same body
        auto cit = closure_contexts.find(fn_val.value.p);
        if (cit != closure_contexts.end()) { closure_contexts[bp] = cit->second; markEscaped(cit->second); }
        bound_self_[bp] = self_val;
        bound_cache_[ck] = bp;
        Value out;
        out.type    = ValueType::USERDATA;
        out.value.p = bp;
        return out;
    }

    // NOTE: there is deliberately no applyBoundSelf() helper any more.
    // Supplying a bound method's captured instance happens in exactly one
    // place — bindParamsKw() — so no invocation path can forget to do it.

    Value callFunctionValue(Value fn_val, std::vector<Value>& call_args, Context* ctx) {
        if (fn_val.type != ValueType::USERDATA || !fn_val.value.p) return NONE_VALUE;
        auto fit = func_names.find(fn_val.value.p);
        if (fit == func_names.end()) return NONE_VALUE;
        // Bound-method `self` is supplied centrally in bindParamsKw via the
        // callee pointer. Lambdas are never bound (makeBoundMethod only binds
        // FUNCTION nodes declaring self), so the lambda path below can use
        // call_args directly.

        void* ast_ptr = fn_val.value.p;
        auto ast_it = func_ast_nodes.find(fn_val.value.p);
        if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
        Node* raw = (Node*)ast_ptr;

        if (raw->type() == NodeType::FUNCTION) {
            auto* fn_node = static_cast<FunctionNode*>(raw);
            Context* closure_parent = ctx;
            auto cit = closure_contexts.find(fn_val.value.p);
            if (cit != closure_contexts.end()) closure_parent = cit->second;
            // Generator detection: run with yield_sink_ set so yield appends and continues
            if (hasYield(fn_node->body)) {
                std::vector<Value> yielded;
                yield_sink_ = &yielded;
                Context* fn_ctx_probe = new Context(runner, fn_node->name, nullptr, nullptr, closure_parent);
                CtxReaper _reap_fn_ctx_probe2003(this, fn_ctx_probe);
                bindParams(fn_node, call_args, fn_ctx_probe, ctx, fn_val.value.p);
                try { evalNode(fn_node->body, fn_ctx_probe); }
                catch (nython::node::ReturnSignal&) {}
                catch (...) {}
                yield_sink_ = nullptr;
                if (!yielded.empty()) {
                    Object* gen_obj = new Object((Runnable*)runner, "__gen__", Type::LIST);
                    int len = (int)yielded.size();
                    for (int i = 0; i < len; i++) gen_obj->set(std::to_string(i), yielded[(size_t)i]);
                    gen_obj->set("__len__", Value(len));
                    gen_obj->set("__gen__", Value(1));
                    gen_obj->set("__idx__", Value(0));
                    return Value((Collectable*)gen_obj);
                }
            }
            // Normal (non-generator) function
            Context* fn_ctx = new Context(runner, fn_node->name, nullptr, nullptr, closure_parent);
            CtxReaper _reap_fn_ctx2020(this, fn_ctx);
            bindParams(fn_node, call_args, fn_ctx, ctx, fn_val.value.p);
            try {
                Value rv = evalNode(fn_node->body, fn_ctx);
                return rv;
            } catch (nython::node::ReturnSignal& r) { return r.value; }
            catch (std::string& _ex) { throw; }
            catch (...) { return NONE_VALUE; }
        } else if (raw->type() == NodeType::LAMBDA) {
            auto* lam = static_cast<LambdaNode*>(raw);
            Context* closure_parent = ctx;
            auto cit = closure_contexts.find(fn_val.value.p);
            if (cit != closure_contexts.end()) closure_parent = cit->second;
            Context* fn_ctx = new Context(runner, "<lambda>", nullptr, nullptr, closure_parent);
            CtxReaper _reap_fn_ctx2033(this, fn_ctx);
            {
                size_t arg_idx = 0;
                for (size_t i = 0; i < lam->params.size(); i++) {
                    std::string pname = lam->params[i]->value();
                    if (pname.size() > 1 && pname[0] == '*' && pname[1] != '*') {
                        std::string real_name = pname.substr(1);
                        Object* varargs = new Object((Runnable*)runner, "list", Type::LIST);
                        int va_idx = 0;
                        while (arg_idx < call_args.size()) {
                            varargs->set(std::to_string(va_idx++), call_args[arg_idx++]);
                        }
                        varargs->set("__len__", Value(va_idx));
                        fn_ctx->defineByName(real_name, Value((Collectable*)varargs));
                    } else if (arg_idx < call_args.size()) {
                        fn_ctx->defineByName(pname, call_args[arg_idx++]);
                    } else {
                        fn_ctx->defineByName(pname, NONE_VALUE);
                    }
                }
            }
            return evalNode(lam->body, fn_ctx);
        }
        return NONE_VALUE;
    }

    // `kw_in` carries keyword arguments through to the method body. It used to
    // be absent entirely, so callMethod built an empty map and every keyword
    // argument passed to a method was silently dropped:
    //     c.m(b=20, a=10)  ->  a=none b=none
    // Plain functions were unaffected, which is why this went unnoticed.
    Value callMethod(Value obj, const std::string& method_name, std::vector<Value>& args, Context* ctx,
                     const std::unordered_map<std::string, Value>* kw_in = nullptr) {
        static const std::unordered_map<std::string, Value> kEmptyKw;
        const std::unordered_map<std::string, Value>& kw_args_in = kw_in ? *kw_in : kEmptyKw;
        // Built-in string methods
        if (obj.type == ValueType::USERDATA && obj.value.p) {
            std::string s = getStringValue(obj);
            bool is_string = string_ptrs_.count(obj.value.p) || (!func_names.count(obj.value.p) && !instance_to_class.count(obj.value.p));
            if (is_string) {
                if (method_name == "upper") { return makeStringValue(utf8_upper(s)); }
                if (method_name == "lower") { return makeStringValue(utf8_lower(s)); }
                if (method_name == "strip" || method_name == "trim") {
                    size_t a = s.find_first_not_of(" \t\n\r"), b = s.find_last_not_of(" \t\n\r");
                    return makeStringValue(a == std::string::npos ? "" : s.substr(a, b-a+1));
                }
                if (method_name == "split") {
                    std::string delim = args.empty() ? " " : getStringValue(args[0]);
                    int maxsplit = (args.size() >= 2 && args[1].type == ValueType::INTEGER)
                        ? (int)bigint_to_i64(args[1].value.i) : -1;
                    Object* list = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0; size_t pos = 0, found;
                    while ((maxsplit < 0 || idx < maxsplit) &&
                           (found = s.find(delim, pos)) != std::string::npos) {
                        list->set(std::to_string(idx++), makeStringValue(s.substr(pos, found - pos)));
                        pos = found + delim.size();
                    }
                    list->set(std::to_string(idx++), makeStringValue(s.substr(pos)));
                    list->set("__len__", Value((int)idx));
                    return Value((Collectable*)list);
                }
                if (method_name == "join") {
                    if (!args.empty() && args[0].isCollectable()) {
                        auto* cont = dynamic_cast<Container*>(args[0].value.gc);
                        if (cont && cont->container) {
                            std::string result; int len = cont->size(), i = 0;
                            for (int j = 0; j < len; j++) {
                                auto it = cont->container->find(std::to_string(j));
                                if (it != cont->container->end()) {
                                    if (i > 0) result += s;
                                    result += getStringValue(it->second);
                                    i++;
                                }
                            }
                            return makeStringValue(result);
                        }
                    }
                    return makeStringValue("");
                }
                if (method_name == "replace") {
                    if (args.size() >= 2) {
                        std::string from = getStringValue(args[0]), to = getStringValue(args[1]);
                        std::string r = s; size_t pos = 0;
                        while ((pos = r.find(from, pos)) != std::string::npos) { r.replace(pos, from.size(), to); pos += to.size(); }
                        return makeStringValue(r);
                    }
                    return makeStringValue(s);
                }
                if (method_name == "find" || method_name == "index") {
                    if (!args.empty()) {
                        size_t pos = s.find(getStringValue(args[0]));
                        return Value(pos == std::string::npos ? -1 : (int)pos);
                    }
                    return Value(-1);
                }
                if (method_name == "startswith") {
                    return args.empty() ? Value(false) : Value(s.find(getStringValue(args[0])) == 0);
                }
                if (method_name == "endswith") {
                    if (args.empty()) return Value(false);
                    std::string suf = getStringValue(args[0]);
                    return Value(s.size() >= suf.size() && s.compare(s.size()-suf.size(), suf.size(), suf) == 0);
                }
                if (method_name == "contains" || method_name == "__contains__") {
                    return args.empty() ? Value(false) : Value(s.find(getStringValue(args[0])) != std::string::npos);
                }
                if (method_name == "length" || method_name == "size") {
                    int cc = 0;
                    for (size_t ii = 0; ii < s.size(); ) {
                        unsigned char uc = (unsigned char)s[ii];
                        if (uc < 0x80) ii += 1; else if ((uc & 0xE0) == 0xC0) ii += 2;
                        else if ((uc & 0xF0) == 0xE0) ii += 3; else if ((uc & 0xF8) == 0xF0) ii += 4; else ii += 1;
                        cc++;
                    }
                    return Value(cc);
                }
                if (method_name == "reverse" || method_name == "reversed") {
                    std::string r(s.rbegin(), s.rend()); return makeStringValue(r);
                }
                if (method_name == "repeat") {
                    if (!args.empty() && args[0].type == ValueType::INTEGER) {
                        std::string r; for (int64_t i = 0; i < bigint_to_i64(args[0].value.i); i++) r += s;
                        return makeStringValue(r);
                    }
                    return makeStringValue(s);
                }
                if (method_name == "charAt" || method_name == "char_at") {
                    if (!args.empty() && args[0].type == ValueType::INTEGER) {
                        int idx = (int)bigint_to_i64(args[0].value.i);
                        if (idx >= 0 && idx < (int)s.size()) return makeStringValue(std::string(1, s[idx]));
                    }
                    return makeStringValue("");
                }
                if (method_name == "substring" || method_name == "substr") {
                    if (args.size() >= 2) return makeStringValue(s.substr(bigint_to_i64(args[0].value.i), bigint_to_i64(args[1].value.i)));
                    if (args.size() >= 1) return makeStringValue(s.substr(bigint_to_i64(args[0].value.i)));
                    return makeStringValue(s);
                }
                if (method_name == "slice") {
                    // String slice with optional step: s[start:end:step]
                    int start = 0, end_idx = static_cast<int>(s.size()), step = 1;
                    if (args.size() >= 1 && args[0].type == ValueType::INTEGER) start = static_cast<int>(bigint_to_i64(args[0].value.i));
                    if (args.size() >= 2 && args[1].type == ValueType::INTEGER) end_idx = static_cast<int>(bigint_to_i64(args[1].value.i));
                    else if (args.size() >= 2 && args[1].type == ValueType::NONE) end_idx = static_cast<int>(s.size());
                    if (args.size() >= 3 && args[2].type == ValueType::INTEGER) step = static_cast<int>(bigint_to_i64(args[2].value.i));
                    int len = static_cast<int>(s.size());
                    if (start < 0) start += len;
                    if (end_idx < 0) end_idx += len;
                    if (start < 0) start = 0;
                    if (end_idx > len) end_idx = len;
                    std::string result;
                    if (step > 0) {
                        for (int i = start; i < end_idx; i += step) result += s[static_cast<size_t>(i)];
                    } else if (step < 0) {
                        if (args.size() < 2 || args[1].type == ValueType::NONE) { start = len - 1; end_idx = -1; }
                        if (args.size() >= 1 && args[0].type == ValueType::INTEGER) {
                            start = static_cast<int>(bigint_to_i64(args[0].value.i));
                            if (start == 0 && args.size() >= 2 && args[1].type == ValueType::NONE) start = len - 1;
                        }
                        for (int i = start; i > end_idx; i += step) result += s[static_cast<size_t>(i)];
                    }
                    return makeStringValue(result);
                }
                if (method_name == "isdigit") {
                    return Value(!s.empty() && std::all_of(s.begin(), s.end(), ::isdigit));
                }
                if (method_name == "format") {
                    std::string result = s;
                    // First handle numbered placeholders {0}, {1}, etc.
                    for (size_t i = 0; i < args.size(); i++) {
                        std::string placeholder = "{" + std::to_string(i) + "}";
                        size_t pos;
                        while ((pos = result.find(placeholder)) != std::string::npos) {
                            result.replace(pos, placeholder.size(), getStringValue(args[i]));
                        }
                    }
                    // Then handle positional {} placeholders
                    for (size_t i = 0; i < args.size(); i++) {
                        size_t pos = result.find("{}");
                        if (pos != std::string::npos) {
                            result.replace(pos, 2, getStringValue(args[i]));
                        }
                    }
                    return makeStringValue(result);
                }
                if (method_name == "count") {
                    if (!args.empty()) {
                        std::string sub = getStringValue(args[0]);
                        int count = 0; size_t pos = 0;
                        while ((pos = s.find(sub, pos)) != std::string::npos) { count++; pos += sub.size(); }
                        return Value(count);
                    }
                    return Value(0);
                }
                if (method_name == "capitalize") {
                    std::string r = s;
                    if (!r.empty()) r[0] = toupper(r[0]);
                    return makeStringValue(r);
                }
                if (method_name == "title") {
                    std::string r = s; bool next_upper = true;
                    for (auto& c : r) { if (next_upper) { c = toupper(c); next_upper = false; } if (c == ' ') next_upper = true; }
                    return makeStringValue(r);
                }
                if (method_name == "lstrip") {
                    size_t a = s.find_first_not_of(" \t\n\r");
                    return makeStringValue(a == std::string::npos ? "" : s.substr(a));
                }
                if (method_name == "rstrip") {
                    size_t b = s.find_last_not_of(" \t\n\r");
                    return makeStringValue(b == std::string::npos ? "" : s.substr(0, b+1));
                }
                if (method_name == "center") {
                    if (!args.empty()) {
                        int width = static_cast<int>(bigint_to_i64(args[0].value.i));
                        char fill = (args.size() > 1) ? getStringValue(args[1])[0] : ' ';
                        int pad = width - static_cast<int>(s.size());
                        if (pad > 0) {
                            int left = pad / 2;
                            int right = pad - left;
                            return makeStringValue(std::string(left, fill) + s + std::string(right, fill));
                        }
                    }
                    return makeStringValue(s);
                }
                if (method_name == "ljust") {
                    if (!args.empty()) {
                        int width = static_cast<int>(bigint_to_i64(args[0].value.i));
                        char fill = (args.size() > 1) ? getStringValue(args[1])[0] : ' ';
                        if (static_cast<int>(s.size()) < width)
                            return makeStringValue(s + std::string(width - s.size(), fill));
                    }
                    return makeStringValue(s);
                }
                if (method_name == "rjust") {
                    if (!args.empty()) {
                        int width = static_cast<int>(bigint_to_i64(args[0].value.i));
                        char fill = (args.size() > 1) ? getStringValue(args[1])[0] : ' ';
                        if (static_cast<int>(s.size()) < width)
                            return makeStringValue(std::string(width - s.size(), fill) + s);
                    }
                    return makeStringValue(s);
                }
                if (method_name == "isalnum") {
                    bool result = !s.empty();
                    for (char c : s) if (!std::isalnum(static_cast<unsigned char>(c))) { result = false; break; }
                    return Value(result);
                }
                if (method_name == "isupper") {
                    bool result = !s.empty();
                    for (char c : s) if (std::isalpha(static_cast<unsigned char>(c)) && !std::isupper(static_cast<unsigned char>(c))) { result = false; break; }
                    return Value(result);
                }
                if (method_name == "islower") {
                    bool result = !s.empty();
                    for (char c : s) if (std::isalpha(static_cast<unsigned char>(c)) && !std::islower(static_cast<unsigned char>(c))) { result = false; break; }
                    return Value(result);
                }
                if (method_name == "isspace") {
                    bool result = !s.empty();
                    for (char c : s) if (!std::isspace(static_cast<unsigned char>(c))) { result = false; break; }
                    return Value(result);
                }
                if (method_name == "swapcase") {
                    std::string r;
                    for (char c : s) {
                        if (std::isupper((unsigned char)c)) r += (char)std::tolower((unsigned char)c);
                        else if (std::islower((unsigned char)c)) r += (char)std::toupper((unsigned char)c);
                        else r += c;
                    }
                    return makeStringValue(r);
                }
                if (method_name == "partition") {
                    if (!args.empty()) {
                        std::string sep = getStringValue(args[0]);
                        size_t pos = s.find(sep);
                        Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                        if (pos != std::string::npos) {
                            result->set("0", makeStringValue(s.substr(0, pos)));
                            result->set("1", makeStringValue(sep));
                            result->set("2", makeStringValue(s.substr(pos + sep.size())));
                        } else {
                            result->set("0", makeStringValue(s));
                            result->set("1", makeStringValue(""));
                            result->set("2", makeStringValue(""));
                        }
                        result->set("__len__", Value(3));
                        return Value((Collectable*)result);
                    }
                    return NONE_VALUE;
                }
                if (method_name == "encode" || method_name == "decode") {
                    return makeStringValue(s);
                }
                if (method_name == "removeprefix") {
                    if (!args.empty()) {
                        std::string pfx = getStringValue(args[0]);
                        if (s.substr(0, pfx.size()) == pfx) return makeStringValue(s.substr(pfx.size()));
                    }
                    return makeStringValue(s);
                }
                if (method_name == "removesuffix") {
                    if (!args.empty()) {
                        std::string sfx = getStringValue(args[0]);
                        if (s.size() >= sfx.size() && s.substr(s.size() - sfx.size()) == sfx)
                            return makeStringValue(s.substr(0, s.size() - sfx.size()));
                    }
                    return makeStringValue(s);
                }
                if (method_name == "swapcase") {
                    std::string result;
                    for (char c : s) {
                        if (std::isupper((unsigned char)c)) result += (char)std::tolower((unsigned char)c);
                        else if (std::islower((unsigned char)c)) result += (char)std::toupper((unsigned char)c);
                        else result += c;
                    }
                    return makeStringValue(result);
                }
                if (method_name == "partition") {
                    if (!args.empty()) {
                        std::string sep = getStringValue(args[0]);
                        size_t pos = s.find(sep);
                        Object* r = new Object((Runnable*)runner, "list", Type::LIST);
                        if (pos != std::string::npos) {
                            r->set("0", makeStringValue(s.substr(0, pos)));
                            r->set("1", makeStringValue(sep));
                            r->set("2", makeStringValue(s.substr(pos + sep.size())));
                        } else { r->set("0", makeStringValue(s)); r->set("1", makeStringValue("")); r->set("2", makeStringValue("")); }
                        r->set("__len__", Value(3));
                        return Value((Collectable*)r);
                    }
                    return NONE_VALUE;
                }
                if (method_name == "removeprefix") {
                    if (!args.empty()) { std::string p = getStringValue(args[0]); if (s.substr(0, p.size()) == p) return makeStringValue(s.substr(p.size())); }
                    return makeStringValue(s);
                }
                if (method_name == "removesuffix") {
                    if (!args.empty()) { std::string sf = getStringValue(args[0]); if (s.size() >= sf.size() && s.substr(s.size()-sf.size()) == sf) return makeStringValue(s.substr(0, s.size()-sf.size())); }
                    return makeStringValue(s);
                }
                if (method_name == "encode" || method_name == "decode") { return makeStringValue(s); }
                if (method_name == "zfill") {
                    if (!args.empty() && args[0].type == ValueType::INTEGER) {
                        int width = (int)bigint_to_i64(args[0].value.i);
                        std::string r = s;
                        while ((int)r.size() < width) r = "0" + r;
                        return makeStringValue(r);
                    }
                    return makeStringValue(s);
                }
                if (method_name == "center") {
                    if (!args.empty() && args[0].type == ValueType::INTEGER) {
                        int width = (int)bigint_to_i64(args[0].value.i);
                        if ((int)s.size() >= width) return makeStringValue(s);
                        int pad = width - (int)s.size();
                        int left = pad / 2, right = pad - left;
                        return makeStringValue(std::string(left, ' ') + s + std::string(right, ' '));
                    }
                    return makeStringValue(s);
                }
                if (method_name == "isalpha") {
                    return Value(!s.empty() && std::all_of(s.begin(), s.end(), ::isalpha));
                }
            }
        }

        // Built-in list methods
        if (obj.isCollectable() && obj.value.gc) {
            auto* cont = dynamic_cast<Container*>(obj.value.gc);
            if (cont && cont->container) {
                if (method_name == "append" || method_name == "push") {
                    if (!args.empty()) {
                        int len = cont->size();
                        auto len_it = cont->container->find("__len__");
                        if (len_it != cont->container->end()) len = (int)bigint_to_i64(len_it->second.value.i);
                        (*cont->container)[std::to_string(len)] = args[0];
                        (*cont->container)["__len__"] = Value((int)(len + 1));
                    }
                    return NONE_VALUE;
                }
                // set.add(): append only if not already present
                if (method_name == "add") {
                    if (!args.empty()) {
                        auto len_it = cont->container->find("__len__");
                        int len = len_it != cont->container->end() ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        // Check for duplicate
                        std::string new_str = getStringValue(args[0]);
                        bool found = false;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                if (getStringValue(it->second) == new_str &&
                                    it->second.type == args[0].type) { found = true; break; }
                            }
                        }
                        if (!found) {
                            (*cont->container)[std::to_string(len)] = args[0];
                            (*cont->container)["__len__"] = Value((int)(len + 1));
                        }
                    }
                    return NONE_VALUE;
                }
                if ((method_name == "discard" || method_name == "remove")
                    && cont->container->count("__set__")) {
                    // SET semantics only. This branch used to be ungated, so it
                    // also swallowed map.remove() and list.remove(), applying
                    // set-element scanning to them and throwing "<x> not in set"
                    // (which aborted the interpreter) for a perfectly valid
                    // dict key removal.
                    if (!args.empty()) {
                        auto len_it = cont->container->find("__len__");
                        int len = len_it != cont->container->end() ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        std::string target_key = set_key_str(args[0]);
                        int found_idx = -1;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && set_key_str(it->second) == target_key) {
                                found_idx = i; break;
                            }
                        }
                        if (found_idx >= 0) {
                            // Shift elements down
                            for (int i = found_idx; i < len - 1; i++)
                                (*cont->container)[std::to_string(i)] = (*cont->container)[std::to_string(i+1)];
                            cont->container->erase(std::to_string(len-1));
                            (*cont->container)["__len__"] = Value((int)(len - 1));
                        } else if (method_name == "remove") {
                            throw std::string(getStringValue(args[0]) + " not in set");
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "pop") {
                    // Dict-style pop with key argument:
                    if (!args.empty() && args[0].type != ValueType::INTEGER) {
                        std::string key = getStringValue(args[0]);
                        auto it = cont->container->find(key);
                        if (it != cont->container->end()) {
                            Value val = it->second;
                            cont->container->erase(key);
                            return val;
                        }
                        if (args.size() >= 2) return args[1];
                        return NONE_VALUE;
                    }
                    // List-style pop (remove and return last element):
                    auto len_it = cont->container->find("__len__");
                    if (len_it != cont->container->end()) {
                        int len = static_cast<int>(bigint_to_i64(len_it->second.value.i));
                        if (len > 0) {
                            // Pop by index if provided, otherwise last
                            int idx = len - 1;
                            if (!args.empty() && args[0].type == ValueType::INTEGER)
                                idx = static_cast<int>(bigint_to_i64(args[0].value.i));
                            auto it = cont->container->find(std::to_string(idx));
                            if (it != cont->container->end()) {
                                Value val = it->second;
                                // Shift elements left if not last
                                for (int i = idx; i < len - 1; i++) {
                                    auto next = cont->container->find(std::to_string(i + 1));
                                    if (next != cont->container->end())
                                        (*cont->container)[std::to_string(i)] = next->second;
                                }
                                cont->container->erase(std::to_string(len - 1));
                                (*cont->container)["__len__"] = Value(len - 1);
                                return val;
                            }
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "contains" || method_name == "includes"
                    || method_name == "has" || method_name == "__contains__") {
                    // Previously unimplemented for lists, so [1,2,3].contains(2)
                    // silently returned none — which made `assert list.contains(x)`
                    // fail even when the element was present.
                    if (args.empty()) return Value(false);
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it == cont->container->end()) continue;
                        if (it->second == args[0]) return Value(true);
                        // Fall back to string comparison so 2 == "2" style
                        // cross-type lookups behave like the rest of Nython.
                        if (isStringValue(it->second) || isStringValue(args[0])) {
                            if (getStringValue(it->second) == getStringValue(args[0])) return Value(true);
                        }
                    }
                    return Value(false);
                }
                if (method_name == "indexOf" || method_name == "index") {
                    if (!args.empty()) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && it->second == args[0]) return Value(i);
                        }
                    }
                    return Value(-1);
                }
                if (method_name == "join") {
                    std::string sep = args.empty() ? ", " : getStringValue(args[0]);
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                    std::string result;
                    for (int i = 0; i < len; i++) {
                        if (i > 0) result += sep;
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) result += getStringValue(it->second);
                    }
                    return makeStringValue(result);
                }
                if (method_name == "forEach" || method_name == "each") {
                    if (!args.empty() && args[0].type == ValueType::USERDATA) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::vector<Value> ca = {it->second};
                                callFunctionValue(args[0], ca, ctx);
                            }
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "reduce") {
                    if (args.size() >= 2 && args[0].type == ValueType::USERDATA) {
                        Value accumulator = args[1];
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::vector<Value> ca = {accumulator, it->second};
                                accumulator = callFunctionValue(args[0], ca, ctx);
                            }
                        }
                        return accumulator;
                    }
                    return NONE_VALUE;
                }
                if (method_name == "slice") {
                    // List slice with optional step
                    auto len_it = cont->container->find("__len__");
                    int list_len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    int start = 0, end_idx = list_len, step = 1;
                    if (args.size() >= 1 && args[0].type == ValueType::INTEGER) start = static_cast<int>(bigint_to_i64(args[0].value.i));
                    if (args.size() >= 2 && args[1].type == ValueType::INTEGER) end_idx = static_cast<int>(bigint_to_i64(args[1].value.i));
                    else if (args.size() >= 2 && args[1].type == ValueType::NONE) end_idx = list_len;
                    if (args.size() >= 3 && args[2].type == ValueType::INTEGER) step = static_cast<int>(bigint_to_i64(args[2].value.i));
                    if (start < 0) start += list_len;
                    if (end_idx < 0) end_idx += list_len;
                    if (start < 0) start = 0;
                    if (end_idx > list_len) end_idx = list_len;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    if (step > 0) {
                        for (int i = start; i < end_idx; i += step) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) result->set(std::to_string(idx++), it->second);
                        }
                    } else if (step < 0) {
                        if (args.size() < 2 || args[1].type == ValueType::NONE) { start = list_len - 1; end_idx = -1; }
                        for (int i = start; i > end_idx; i += step) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) result->set(std::to_string(idx++), it->second);
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
                if (method_name == "sort" || method_name == "sorted") {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    // Check for key= and reverse= args
                    // Convention: args[0] = key func (optional), last bool arg = reverse
                    Value key_func; bool reverse = false;
                    for (auto& a : args) {
                        if (a.type == ValueType::BOOLEAN) reverse = a.value.b;
                        else if (a.type == ValueType::USERDATA && a.value.p && func_names.count(a.value.p)) key_func = a;
                    }
                    // Extract values
                    std::vector<Value> vals;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end()) vals.push_back(it->second);
                    }
                    // Sort with optional key function
                    auto get_sort_key = [&](const Value& v) -> Value {
                        if (key_func.type != ValueType::NONE && key_func.type != ValueType::UNDEFINED &&
                            key_func.value.p != nullptr) {
                            std::vector<Value> ka = {v};
                            return callFunctionValue(key_func, ka, ctx);
                        }
                        return v;
                    };
                    std::stable_sort(vals.begin(), vals.end(), [&](const Value& a, const Value& b) {
                        Value ka = get_sort_key(a), kb = get_sort_key(b);
                        bool less;
                        if (ka.type == ValueType::INTEGER && kb.type == ValueType::INTEGER)
                            less = bigint_to_i64(ka.value.i) < bigint_to_i64(kb.value.i);
                        else if (ka.type == ValueType::DOUBLE || kb.type == ValueType::DOUBLE) {
                            double da = ka.type == ValueType::DOUBLE ? (double)ka.value.d : (double)bigint_to_i64(ka.value.i);
                            double db = kb.type == ValueType::DOUBLE ? (double)kb.value.d : (double)bigint_to_i64(kb.value.i);
                            less = da < db;
                        } else if (isStringValue(ka) || isStringValue(kb)) {
                            less = getStringValue(ka) < getStringValue(kb);
                        } else less = ka.toString() < kb.toString();
                        return reverse ? !less : less;
                    });
                    // Write back (in-place modification)
                    for (int i = 0; i < len; i++) {
                        (*cont->container)[std::to_string(i)] = vals[static_cast<size_t>(i)];
                    }
                    return obj; // return self for chaining
                }

                if (method_name == "reverse" || method_name == "reversed") {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    for (int i = 0; i < len / 2; i++) {
                        int j = len - 1 - i;
                        auto a = cont->container->find(std::to_string(i));
                        auto b = cont->container->find(std::to_string(j));
                        if (a != cont->container->end() && b != cont->container->end()) {
                            Value tmp = a->second;
                            a->second = b->second;
                            b->second = tmp;
                        }
                    }
                    return obj;
                }

                if (method_name == "map") {
                    if (!args.empty() && args[0].type == ValueType::USERDATA) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::vector<Value> ca = {it->second};
                                result->set(std::to_string(i), callFunctionValue(args[0], ca, ctx));
                            }
                        }
                        result->set("__len__", Value((int)len));
                        return Value((Collectable*)result);
                    }
                    return obj;
                }
                if (method_name == "filter") {
                    if (!args.empty() && args[0].type == ValueType::USERDATA) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                        Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                        int out_idx = 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end()) {
                                std::vector<Value> ca = {it->second};
                                Value rv = callFunctionValue(args[0], ca, ctx);
                                if (rv.isTrue()) result->set(std::to_string(out_idx++), it->second);
                            }
                        }
                        result->set("__len__", Value((int)out_idx));
                        return Value((Collectable*)result);
                    }
                    return obj;
                }
                if (method_name == "extend") {
                    if (!args.empty() && args[0].isCollectable()) {
                        auto* src = dynamic_cast<Container*>(args[0].value.gc);
                        if (src && src->container) {
                            auto len_it = cont->container->find("__len__");
                            int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                            auto src_len_it = src->container->find("__len__");
                            int src_len = (src_len_it != src->container->end()) ? static_cast<int>(bigint_to_i64(src_len_it->second.value.i)) : 0;
                            for (int i = 0; i < src_len; i++) {
                                auto it = src->container->find(std::to_string(i));
                                if (it != src->container->end())
                                    (*cont->container)[std::to_string(len + i)] = it->second;
                            }
                            (*cont->container)["__len__"] = Value(len + src_len);
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "count") {
                    // List count: count occurrences of a value
                    if (!args.empty()) {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                        int count = 0;
                        std::string target = args[0].toString();
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && it->second.toString() == target) count++;
                        }
                        return Value(count);
                    }
                    return Value(0);
                }
                if (method_name == "insert") {
                    if (args.size() >= 2) {
                        int idx = static_cast<int>(bigint_to_i64(args[0].value.i));
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                        // Shift elements right
                        for (int i = len; i > idx; i--) {
                            auto it = cont->container->find(std::to_string(i - 1));
                            if (it != cont->container->end())
                                (*cont->container)[std::to_string(i)] = it->second;
                        }
                        (*cont->container)[std::to_string(idx)] = args[1];
                        (*cont->container)["__len__"] = Value(len + 1);
                    }
                    return NONE_VALUE;
                }
                if (method_name == "copy") {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it != cont->container->end())
                            result->set(std::to_string(i), it->second);
                    }
                    result->set("__len__", Value(len));
                    return Value((Collectable*)result);
                }
                if (method_name == "clear") {
                    cont->container->clear();
                    (*cont->container)["__len__"] = Value(0);
                    return NONE_VALUE;
                }
                if (method_name == "min" || method_name == "max" || method_name == "sum") {
                    auto len_it = cont->container->find("__len__");
                    int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                    if (len == 0) return NONE_VALUE;
                    if (method_name == "sum") {
                        double total = 0.0;
                        bool all_int = true;
                        int64_t itotal = 0;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it == cont->container->end()) continue;
                            if (it->second.type == ValueType::DOUBLE) {
                                all_int = false;
                                total += static_cast<double>(it->second.value.d);
                            } else {
                                int64_t v = bigint_to_i64(it->second.value.i);
                                total += static_cast<double>(v);
                                itotal += v;
                            }
                        }
                        return all_int ? Value(static_cast<int>(itotal)) : Value(total);
                    }
                    // min or max
                    Value best = NONE_VALUE;
                    double best_num = 0;
                    bool first = true;
                    for (int i = 0; i < len; i++) {
                        auto it = cont->container->find(std::to_string(i));
                        if (it == cont->container->end()) continue;
                        double num = (it->second.type == ValueType::DOUBLE) ? static_cast<double>(it->second.value.d)
                                     : static_cast<double>(bigint_to_i64(it->second.value.i));
                        if (first || (method_name == "min" ? num < best_num : num > best_num)) {
                            best = it->second;
                            best_num = num;
                            first = false;
                        }
                    }
                    return best;
                }

            }
        }

        // Built-in map methods
        if (obj.isCollectable() && obj.value.gc) {
            auto* cont = dynamic_cast<Container*>(obj.value.gc);
            if (cont && cont->container) {
                // Check if it's a map (no __len__ key = likely a map)
                bool is_map = true;
                if (method_name == "keys") {
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (k != "__len__") result->set(std::to_string(idx++), makeStringValue(k));
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
                if (method_name == "values") {
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (k != "__len__") result->set(std::to_string(idx++), v);
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
                if (method_name == "has_key" || method_name == "has" || method_name == "containsKey") {
                    if (!args.empty()) {
                        std::string key = getStringValue(args[0]);
                        return Value(cont->container->count(key) > 0);
                    }
                    return Value(false);
                }
                if (method_name == "pop") {
                    if (!args.empty()) {
                        std::string key = getStringValue(args[0]);
                        auto it = cont->container->find(key);
                        if (it != cont->container->end()) {
                            Value val = it->second;
                            cont->container->erase(key);
                            return val;
                        }
                        if (args.size() >= 2) return args[1]; // default value
                    }
                    return NONE_VALUE;
                }
                if (method_name == "update") {
                    if (!args.empty() && args[0].isCollectable()) {
                        auto* src = dynamic_cast<Container*>(args[0].value.gc);
                        if (src && src->container) {
                            for (auto& [k, v] : *src->container) {
                                if (k != "__len__" && !k.empty() && k[0] != '_')
                                    (*cont->container)[k] = v;
                            }
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "setdefault") {
                    if (!args.empty()) {
                        std::string key = getStringValue(args[0]);
                        auto it = cont->container->find(key);
                        if (it != cont->container->end()) return it->second;
                        Value def = (args.size() >= 2) ? args[1] : NONE_VALUE;
                        (*cont->container)[key] = def;
                        return def;
                    }
                    return NONE_VALUE;
                }
                if (method_name == "get") {
                    if (!args.empty()) {
                        std::string key = getStringValue(args[0]);
                        auto it = cont->container->find(key);
                        if (it != cont->container->end()) return it->second;
                        if (args.size() >= 2) return args[1]; // default value
                    }
                    return NONE_VALUE;
                }
                if (method_name == "remove" || method_name == "delete") {
                    if (args.empty()) return NONE_VALUE;
                    // Discriminate container kind: lists/sets carry "__len__",
                    // maps do not. Previously this block ran LIST logic on maps
                    // (scanning "0","1","2"...) and called args[0].toString(),
                    // which threw on USERDATA strings.
                    bool is_indexed = cont->container->count("__len__") > 0;
                    if (!is_indexed) {
                        // MAP: erase by key, return the removed value.
                        std::string key = getStringValue(args[0]);
                        auto it = cont->container->find(key);
                        if (it != cont->container->end()) {
                            Value removed = it->second;
                            cont->container->erase(it);
                            return removed;
                        }
                        if (args.size() >= 2) return args[1]; // default when absent
                        return NONE_VALUE;
                    }
                    // LIST: remove first element equal to args[0], shift left.
                    {
                        auto len_it = cont->container->find("__len__");
                        int len = (len_it != cont->container->end()) ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                        // Use getStringValue, not Value::toString(): toString()
                        // throws on USERDATA (interned string) values.
                        std::string target = getStringValue(args[0]);
                        int found = -1;
                        for (int i = 0; i < len; i++) {
                            auto it = cont->container->find(std::to_string(i));
                            if (it != cont->container->end() && getStringValue(it->second) == target) {
                                found = i;
                                break;
                            }
                        }
                        if (found >= 0) {
                            // Shift elements left
                            for (int i = found; i < len - 1; i++) {
                                auto next = cont->container->find(std::to_string(i + 1));
                                if (next != cont->container->end())
                                    (*cont->container)[std::to_string(i)] = next->second;
                            }
                            cont->container->erase(std::to_string(len - 1));
                            (*cont->container)["__len__"] = Value(len - 1);
                        }
                    }
                    return NONE_VALUE;
                }
                if (method_name == "size" || method_name == "length") {
                    int count = 0;
                    for (auto& [k, v] : *cont->container) { if (k != "__len__") count++; }
                    return Value(count);
                }
                if (method_name == "items" || method_name == "entries") {
                    Object* result = new Object((Runnable*)runner, "list", Type::LIST);
                    int idx = 0;
                    for (auto& [k, v] : *cont->container) {
                        if (k != "__len__") {
                            Object* pair = new Object((Runnable*)runner, "list", Type::LIST);
                            pair->set("0", makeStringValue(k));
                            pair->set("1", v);
                            pair->set("__len__", Value(2));
                            result->set(std::to_string(idx++), Value((Collectable*)pair));
                        }
                    }
                    result->set("__len__", Value(idx));
                    return Value((Collectable*)result);
                }
                if (method_name == "merge" || method_name == "update") {
                    if (!args.empty() && args[0].isCollectable()) {
                        auto* other = dynamic_cast<Container*>(args[0].value.gc);
                        if (other && other->container) {
                            for (auto& [k, v] : *other->container) {
                                if (k != "__len__") (*cont->container)[k] = v;
                            }
                        }
                    }
                    return obj;
                }
            }
        }

        // Find the class this instance belongs to
        void* class_ptr = nullptr;
        auto cit = instance_to_class.find(obj.value.p);
        if (cit != instance_to_class.end()) class_ptr = cit->second;
        // If obj IS a class itself (static method call), use it directly
        if (!class_ptr) {
            auto fn_it = func_names.find(obj.value.p);
            if (fn_it != func_names.end() && fn_it->second.find("__class__:") == 0) {
                class_ptr = obj.value.p;
            }
        }

        // Find the class node from func_ast_nodes or direct pointer
        Node* class_node = nullptr;
        if (class_ptr) {
            // class_ptr might be a unique function ID or direct node ptr
            auto ast_it = func_ast_nodes.find(class_ptr);
            if (ast_it != func_ast_nodes.end()) class_node = (Node*)ast_it->second;
            else class_node = (Node*)class_ptr;
        }


        if (class_node && func_names.find(class_ptr) != func_names.end() && class_node->type() == NodeType::CLASS) {
            auto* cn = static_cast<ClassNode*>(class_node);

            // Check class_ctx_map_ first — this respects @staticmethod/@property/@classmethod decorators
            auto class_ctx_it = class_ctx_map_.find((void*)class_node);
            if (class_ctx_it != class_ctx_map_.end()) {
                Context* ccx = class_ctx_it->second;
                Value method_val;
                try { method_val = ccx->getByName(method_name); } catch (...) {}
                if (method_val.type == ValueType::USERDATA && method_val.value.p) {
                    void* ast_ptr = method_val.value.p;
                    auto ast_it2 = func_ast_nodes.find(method_val.value.p);
                    if (ast_it2 != func_ast_nodes.end()) ast_ptr = ast_it2->second;
                    Node* raw = (Node*)ast_ptr;
                    std::string fn_tag = func_names.count(method_val.value.p) ? func_names[method_val.value.p] : "";
                    bool is_static = fn_tag.find("__static__") != std::string::npos;
                    bool is_classmethod = fn_tag.find("__classmethod__") != std::string::npos;
                    bool is_property = fn_tag.find("__property__") != std::string::npos;
                    // If the method is a decorated closure (not directly a FunctionNode),
                    // call it via callFunctionValue with self prepended to args
                    if (!raw || raw->type() != NodeType::FUNCTION) {
                        std::vector<Value> with_self;
                        with_self.push_back(obj);
                        for (auto& a : args) with_self.push_back(a);
                        return callFunctionValue(method_val, with_self, ctx);
                    }
                    if (raw && raw->type() == NodeType::FUNCTION) {
                        auto fn = static_cast<FunctionNode*>(raw);
                        Context* cp = ctx;
                        auto cit = closure_contexts.find(method_val.value.p);
                        if (cit != closure_contexts.end()) cp = cit->second;
                        Context* fc = new Context(runner, fn->name, nullptr, nullptr, cp);
                        CtxReaper _reap_fc3025(this, fc);
                        if (is_classmethod) {
                            // For @classmethod: bind cls = the class value (not instance)
                            // Look up the class value by name
                            Value cls_val;
                            for (auto& [cn2, cv2] : class_by_name) {
                                if (cv2 == class_ptr || cv2 == class_node) {
                                    try { cls_val = ctx->getByName(cn2); } catch (...) {}
                                    break;
                                }
                            }
                            if (cls_val.type == ValueType::UNDEFINED) cls_val = obj;
                            // Bind "cls" param (first param, skip it for arg binding)
                            size_t ps = (!fn->params.empty()) ? 1 : 0;
                            if (!fn->params.empty()) fc->defineByName(fn->params[0]->value(), cls_val);
                            for (size_t i = ps; i < fn->params.size(); i++) {
                                size_t ai = i - ps;
                                if (ai < args.size()) fc->defineByName(fn->params[i]->value(), args[ai]);
                                else fc->defineByName(fn->params[i]->value(), NONE_VALUE);
                            }
                        } else if (!is_static) {
                            bool has_self_param = (!fn->params.empty() && 
                                (fn->params[0]->value() == "self" || fn->params[0]->value() == "this"));
                            if (has_self_param) {
                                // Check if obj is a class (unbound method call like ClassName.method(instance, ...))
                                // vs an instance (bound method call like instance.method(...))
                                bool obj_is_class = false;
                                {
                                    auto fn_it2 = func_names.find(obj.value.p);
                                    if (fn_it2 != func_names.end() && fn_it2->second.find("__class__:") == 0)
                                        obj_is_class = true;
                                }
                                if (obj_is_class && !args.empty()) {
                                    // Unbound call: args[0] is self, rest are regular args
                                    fc->defineByName("self", args[0]);
                                    std::vector<Value> shifted(args.begin() + 1, args.end());
                                    bindParamsKw(fn, shifted, kw_args_in, fc, ctx, 1);
                                } else {
                                    fc->defineByName("self", obj);
                                    // Use bindParamsKw for *args support, skipping self
                                    std::vector<Value> shifted = args;
                                    bindParamsKw(fn, shifted, kw_args_in, fc, ctx, 1);
                                }
                            } else {
                                // First param is not `self`. That normally means a
                                // decorated wrapper (inner(*args)), which wants obj
                                // prepended. But when obj is the *class* rather than
                                // an instance, this is a static-style call —
                                // ClassName.method(x) — and prepending the class
                                // shifted every real argument one place right, so
                                // the first parameter received the class object.
                                bool obj_is_class_sm = false;
                                {
                                    auto fn_it_sm = func_names.find(obj.value.p);
                                    if (fn_it_sm != func_names.end() && fn_it_sm->second.find("__class__:") == 0)
                                        obj_is_class_sm = true;
                                }
                                if (obj_is_class_sm) {
                                    bindParamsKw(fn, args, kw_args_in, fc, ctx);
                                } else {
                                    std::vector<Value> with_self;
                                    with_self.push_back(obj);
                                    for (auto& a : args) with_self.push_back(a);
                                    bindParamsKw(fn, with_self, kw_args_in, fc, ctx);
                                    fc->defineByName("self", obj); // also bind self in case needed
                                }
                            }
                        } else {
                            size_t ps = 0;
                            for (size_t i = ps; i < fn->params.size(); i++) {
                                size_t ai = i - ps;
                                if (ai < args.size()) fc->defineByName(fn->params[i]->value(), args[ai]);
                                else if (i < fn->defaults.size() && fn->defaults[i])
                                    fc->defineByName(fn->params[i]->value(), evalNode(fn->defaults[i], ctx));
                                else fc->defineByName(fn->params[i]->value(), NONE_VALUE);
                            }
                        }
                        // Set __parent_class__ so super() works in this method
                        if (cn->bases.size() > 0)
                            fc->defineByName("__parent_class__", makeStringValue(cn->bases[0]->value()));
                        try { Value r = evalNode(fn->body, fc); return r; }
                        catch (nython::node::ReturnSignal& r) { return r.value; }
                        catch (std::string& e) { throw; }
                    }
                }
            }

            // Search class body for the method (fallback for non-decorated methods)
            if (cn->body) {
                for (auto& stmt : cn->body->statements()) {
                    if (stmt->type() == NodeType::FUNCTION) {
                        auto* fn = static_cast<FunctionNode*>(stmt.get());
                        if (fn->name == method_name) {
                            // Create method context with self bound
                            Context* fn_ctx = new Context(runner, method_name, nullptr, nullptr, ctx);
                            CtxReaper _reap_fn_ctx3103(this, fn_ctx);
                            // Check if obj is a class (unbound call) or instance (bound call)
                            bool obj_is_class2 = false;
                            {
                                auto fn_it3 = func_names.find(obj.value.p);
                                if (fn_it3 != func_names.end() && fn_it3->second.find("__class__:") == 0)
                                    obj_is_class2 = true;
                            }
                            if (obj_is_class2 && !args.empty()) {
                                fn_ctx->defineByName("self", args[0]);
                            } else {
                                fn_ctx->defineByName("self", obj);
                            }
                            // Set __parent_class__ so super() works
                            if (cn->bases.size() > 0)
                                fn_ctx->defineByName("__parent_class__", makeStringValue(cn->bases[0]->value()));
                            // Bind params (skip first "self" param)
                            size_t param_start = 0;
                            if (!fn->params.empty() && fn->params[0]->value() == "self") param_start = 1;
                            // Only skip args[0] as the explicit self when the method
                            // actually declares one; otherwise a static-style call
                            // lost its first argument entirely.
                            size_t arg_offset = (obj_is_class2 && !args.empty() && param_start == 1) ? 1 : 0;
                            for (size_t i = param_start; i < fn->params.size(); i++) {
                                size_t arg_idx = i - param_start + arg_offset;
                                if (arg_idx < args.size())
                                    fn_ctx->defineByName(fn->params[i]->value(), args[arg_idx]);
                            }
                            try {
                                Value result = evalNode(fn->body, fn_ctx);
                                return result;
                            } catch (nython::node::ReturnSignal& ret) {
                                return ret.value;
                            } catch (std::string& flow) {
                                if (flow.size()>7 && flow.substr(0,7)=="__exc__") throw;
                                return NONE_VALUE;
                            }
                        }
                    }
                }
            }
        }

        // Check ALL parent classes (multiple inheritance via MRO)
        if (class_node && func_names.find(class_ptr) != func_names.end() && class_node->type() == NodeType::CLASS) {
            auto* cn_check = static_cast<ClassNode*>(class_node);
            for (auto& base_node : cn_check->bases) {
                std::string parent_name = base_node->value();
                Value parent_class_val;
                try { parent_class_val = ctx->getByName(parent_name); } catch (...) { continue; }
                if (parent_class_val.type != ValueType::USERDATA || !parent_class_val.value.p) continue;
                void* parent_ast = parent_class_val.value.p;
                auto past_it = func_ast_nodes.find(parent_ast);
                if (past_it != func_ast_nodes.end()) parent_ast = past_it->second;
                Node* parent_node = (Node*)parent_ast;
                if (!parent_node || parent_node->type() != NodeType::CLASS) continue;
                auto* pcn = static_cast<ClassNode*>(parent_node);
                if (!pcn->body) continue;
                for (auto& stmt : pcn->body->statements()) {
                    if (stmt->type() != NodeType::FUNCTION) continue;
                    auto* fn = static_cast<FunctionNode*>(stmt.get());
                    if (fn->name != method_name) continue;
                    Context* fn_ctx = new Context(runner, method_name, nullptr, nullptr, ctx);
                    CtxReaper _reap_fn_ctx3162(this, fn_ctx);
                    fn_ctx->defineByName("self", obj);
                    size_t param_start = (!fn->params.empty() && fn->params[0]->value() == "self") ? 1 : 0;
                    for (size_t i = param_start; i < fn->params.size(); i++) {
                        size_t arg_idx = i - param_start;
                        if (arg_idx < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[arg_idx]);
                    }
                    try { return evalNode(fn->body, fn_ctx); }
                    catch (nython::node::ReturnSignal& ret) { return ret.value; }
                    catch (std::string& _exc) { if (_exc.size()>7 && _exc.substr(0,7)=="__exc__") throw; return NONE_VALUE; }
                }
            }
        }

        // Try parent class methods (inheritance) - walk full chain
        {
            void* search_class = class_ptr;
            for (int depth = 0; depth < 10; depth++) { // max 10 levels
                auto parent_it = class_parent.find(search_class);
                if (parent_it == class_parent.end()) break;
                auto parent_class_it = class_by_name.find(parent_it->second);
                if (parent_class_it == class_by_name.end()) break;
                Node* parent_node = (Node*)parent_class_it->second;
                if (parent_node->type() == NodeType::CLASS) {
                    auto* pcn = static_cast<ClassNode*>(parent_node);
                    if (pcn->body) {
                        for (auto& stmt : pcn->body->statements()) {
                            if (stmt->type() == NodeType::FUNCTION) {
                                auto* fn = static_cast<FunctionNode*>(stmt.get());
                                if (fn->name == method_name) {
                                    Context* fn_ctx = new Context(runner, method_name, nullptr, nullptr, ctx);
                                    CtxReaper _reap_fn_ctx3192(this, fn_ctx);
                                    fn_ctx->defineByName("self", obj);
                                    size_t param_start = 0;
                                    if (!fn->params.empty() && fn->params[0]->value() == "self") param_start = 1;
                                    for (size_t i = param_start; i < fn->params.size(); i++) {
                                        size_t arg_idx = i - param_start;
                                        if (arg_idx < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[arg_idx]);
                                    }
                                    try { Value result = evalNode(fn->body, fn_ctx); return result; }
                                    catch (nython::node::ReturnSignal& ret) { return ret.value; }
                                    catch (std::string& flow) { if (flow=="break"||flow=="continue") throw; if (flow.size()>7&&flow.substr(0,7)=="__exc__") throw; return NONE_VALUE; }
                                }
                            }
                        }
                    }
                }
                search_class = parent_class_it->second; // climb to next parent
            }
        }

         // Try parent class methods (inheritance)
        if (class_node && func_names.find(class_ptr) != func_names.end() && class_node->type() == NodeType::CLASS) {
            auto parent_it = class_parent.find(class_ptr);
            if (parent_it != class_parent.end()) {
                auto parent_class_it = class_by_name.find(parent_it->second);
                if (parent_class_it != class_by_name.end()) {
                    Node* parent_node = (Node*)parent_class_it->second;
                    if (parent_node->type() == NodeType::CLASS) {
                        auto* pcn = static_cast<ClassNode*>(parent_node);
                        if (pcn->body) {
                            for (auto& stmt : pcn->body->statements()) {
                                if (stmt->type() == NodeType::FUNCTION) {
                                    auto* fn = static_cast<FunctionNode*>(stmt.get());
                                    if (fn->name == method_name) {
                                        Context* fn_ctx = new Context(runner, method_name, nullptr, nullptr, ctx);
                                        CtxReaper _reap_fn_ctx3226(this, fn_ctx);
                                        fn_ctx->defineByName("self", obj);
                                        size_t param_start = 0;
                                        if (!fn->params.empty() && fn->params[0]->value() == "self") param_start = 1;
                                        for (size_t i = param_start; i < fn->params.size(); i++) {
                                            size_t arg_idx = i - param_start;
                                            if (arg_idx < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[arg_idx]);
                                        }
                                        try { Value result = evalNode(fn->body, fn_ctx); return result; }
                                        catch (nython::node::ReturnSignal& ret) { return ret.value; }
                                        catch (std::string& flow) { if (flow.size()>7&&flow.substr(0,7)=="__exc__") throw; return NONE_VALUE; }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Universal Object protocol ────────────────────────────────────────
        // Everything is an object in this language, so every instance should
        // answer a common set of queries without the author writing them.
        // Nothing provided them: a plain class had no to_string, no type_name,
        // no id, no is_a — hasattr() reported false for all of them.
        //
        // These are resolved only AFTER the class's own methods, so a class that
        // defines its own to_string() keeps it; the root supplies a default, it
        // does not override.
        {
            Value r = objectProtocol(obj, method_name, args, ctx);
            if (r.type != ValueType::UNDEFINED) return r;
        }

        // Fallback: try calling as a regular attribute
        Value method_val = evalAttribute(std::make_shared<AttributeNode>(
            Token(), std::make_shared<VariableNode>(Token()), method_name), ctx);
        return NONE_VALUE;
    }

    std::vector<std::unique_ptr<int64_t>> func_id_store;
    std::map<void*, void*> func_ast_nodes;
    std::vector<node_ptr> imported_asts; // keep imported ASTs alive // unique_ptr -> AST node ptr
    std::unordered_set<std::string> imported_modules_; // prevent circular imports

    Value evalClassDecl(node_ptr node, Context* ctx) {
        auto cn = static_pointer_cast<ClassNode>(node);
        Value class_val;
        class_val.type = ValueType::USERDATA;
        class_val.value.p = (void*)node.get();
        func_names[(void*)node.get()] = "__class__:" + cn->name;
        class_by_name[cn->name] = (void*)node.get();
        // Store parent class if exists
        if (!cn->bases.empty()) {
            // bases[0] is a VariableNode with parent class name
            class_parent[(void*)node.get()] = cn->bases[0]->value();
        }
        ctx->defineByName(cn->name, class_val);
        if (cn->body) {
            Context* class_ctx = new Context(runner, cn->name, nullptr, nullptr, ctx);
            evalNode(cn->body, class_ctx);
            // Store the evaluated class context so decorators (@property, @staticmethod) are visible
            class_ctx_map_[(void*)node.get()] = class_ctx;
            markEscaped(class_ctx);
        }
        return class_val;
    }

    Value evalLambda(node_ptr node, Context* ctx) {
        int64_t fid = ++closure_id_counter;
        auto unique_key = std::make_unique<int64_t>(fid);
        void* unique_ptr = (void*)unique_key.get();
        func_id_store.push_back(std::move(unique_key));

        // Create a persistent closure context that copies current bindings
        // This prevents dangling pointers when the enclosing function returns
        Context* closure_ctx = new Context(runner, "__closure__", nullptr, nullptr, ctx->parent);
        if (ctx->container) {
            for (auto& [k, v] : *ctx->container) {
                closure_ctx->defineByName(k, v);
            }
        }
        // Also walk up and copy parent bindings for nested closures
        Context* walk = ctx->parent;
        while (walk) {
            if (walk->container) {
                for (auto& [k, v] : *walk->container) {
                    // Only copy if not already defined (local takes priority)
                    try {
                        Value existing = closure_ctx->getByName(k);
                        if (existing.type == ValueType::UNDEFINED) {
                            closure_ctx->defineByName(k, v);
                        }
                    } catch (...) {
                        closure_ctx->defineByName(k, v);
                    }
                }
            }
            walk = walk->parent;
        }

        Value fn_val;
        fn_val.type = ValueType::USERDATA;
        fn_val.value.p = unique_ptr;
        func_names[unique_ptr] = "__lambda__";
        closure_contexts[unique_ptr] = closure_ctx;
        markEscaped(closure_ctx);
        func_ast_nodes[unique_ptr] = (void*)node.get();
        return fn_val;
    }


    // Helper: build a positional args list and a keyword map from a CallNode's arg list
    // Returns positional args in call_args, named args in kw_args (name->value)
    void evalCallArgs(const std::vector<node_ptr>& raw_args, Context* ctx,
                      std::vector<Value>& call_args,
                      std::unordered_map<std::string, Value>& kw_args) {
        for (auto& a : raw_args) {
            if (a->type() == NodeType::KEYWORD_ARG) {
                // Named argument: name=value
                auto kn = static_pointer_cast<KeywordArgNode>(a);
                kw_args[kn->name] = evalNode(kn->val, ctx);
            } else if (a->type() == NodeType::UNARY) {
                auto un = static_pointer_cast<UnaryNode>(a);
                if (un->op == "*") {
                    // *iterable spread: unpack list/range into positional args
                    Value spread_val = evalNode(un->operand, ctx);
                    if (spread_val.isCollectable() && spread_val.value.gc) {
                        auto* cont = dynamic_cast<Container*>(spread_val.value.gc);
                        if (cont && cont->container) {
                            auto len_it = cont->container->find("__len__");
                            int len = len_it != cont->container->end()
                                      ? static_cast<int>(bigint_to_i64(len_it->second.value.i)) : 0;
                            for (int i = 0; i < len; i++) {
                                auto it = cont->container->find(std::to_string(i));
                                if (it != cont->container->end()) call_args.push_back(it->second);
                            }
                        }
                    } else if (spread_val.type == ValueType::INTEGER) {
                        int64_t n = bigint_to_i64(spread_val.value.i);
                        for (int64_t i = 0; i < n; i++) call_args.push_back(Value((int)i));
                    } else {
                        call_args.push_back(spread_val);
                    }
                } else if (un->op == "**") {
                    // **dict spread into kw_args
                    Value spread_val = evalNode(un->operand, ctx);
                    if (spread_val.isCollectable() && spread_val.value.gc) {
                        auto* cont = dynamic_cast<Container*>(spread_val.value.gc);
                        if (cont && cont->container)
                            for (auto& [k, v] : *cont->container)
                                if (k != "__len__") kw_args[k] = v;
                    }
                } else {
                    call_args.push_back(evalNode(a, ctx));
                }
            } else {
                call_args.push_back(evalNode(a, ctx));
            }
        }
    }

    // Helper: bind function params with *args/*kwargs support and keyword arg map
    void bindParams(FunctionNode* fn, std::vector<Value>& call_args, Context* fn_ctx, Context* eval_ctx,
                    void* callee_ptr = nullptr) {
        bindParamsKw(fn, call_args, {}, fn_ctx, eval_ctx, 0, callee_ptr);
    }
    // `callee_ptr` is the Value pointer the call was made through, when known.
    // If it names a bound method, the captured instance is supplied here as the
    // first positional argument.
    //
    // This is deliberately the ONLY place that does it. Previously each
    // invocation path re-supplied `self` itself, and three separate paths
    // (direct call, callFunctionValue, attribute-stored callable) each had to be
    // fixed in turn — a path that forgot produced no error, just arguments
    // shifted left and attribute reads yielding none. Every invocation must bind
    // parameters, so putting it here means a new call path cannot miss it.
    void bindParamsKw(FunctionNode* fn, std::vector<Value>& call_args,
                      const std::unordered_map<std::string, Value>& kw_args,
                      Context* fn_ctx, Context* eval_ctx, size_t skip_params = 0,
                      void* callee_ptr = nullptr) {
        std::vector<Value> bound_args;
        std::vector<Value>* argp = &call_args;
        if (callee_ptr && skip_params == 0) {
            auto bs = bound_self_.find(callee_ptr);
            if (bs != bound_self_.end()) {
                bound_args.reserve(call_args.size() + 1);
                bound_args.push_back(bs->second);
                for (auto& a : call_args) bound_args.push_back(a);
                argp = &bound_args;
            }
        }
        std::vector<Value>& args_in = *argp;
        bindParamsImpl(fn, args_in, kw_args, fn_ctx, eval_ctx, skip_params);
    }
    void bindParamsImpl(FunctionNode* fn, std::vector<Value>& call_args,
                        const std::unordered_map<std::string, Value>& kw_args,
                        Context* fn_ctx, Context* eval_ctx, size_t skip_params) {
        size_t arg_idx = 0;
        for (size_t i = skip_params; i < fn->params.size(); i++) {
            std::string pname = fn->params[i]->value();
            if (pname.size() > 1 && pname[0] == '*' && pname[1] != '*') {
                // *args: collect remaining positional args into a list
                std::string real_name = pname.substr(1);
                Object* varargs = new Object((Runnable*)runner, "list", Type::LIST);
                int va_idx = 0;
                while (arg_idx < call_args.size()) {
                    varargs->set(std::to_string(va_idx++), call_args[arg_idx++]);
                }
                varargs->set("__len__", Value(va_idx));
                fn_ctx->defineByName(real_name, Value((Collectable*)varargs));
            } else if (pname.size() > 2 && pname[0] == '*' && pname[1] == '*') {
                // **kwargs: collect all keyword args into a dict
                std::string real_name = pname.substr(2);
                Object* kwargs_obj = new Object((Runnable*)runner, "map", Type::LIST);
                for (auto& [k, v] : kw_args) kwargs_obj->set(k, v);
                fn_ctx->defineByName(real_name, Value((Collectable*)kwargs_obj));
            } else {
                // Named match: check kw_args first, then positional
                auto kw_it = kw_args.find(pname);
                if (kw_it != kw_args.end()) {
                    fn_ctx->defineByName(pname, kw_it->second);
                } else if (arg_idx < call_args.size()) {
                    fn_ctx->defineByName(pname, call_args[arg_idx++]);
                } else if (i < fn->defaults.size() && fn->defaults[i]) {
                    fn_ctx->defineByName(pname, evalNode(fn->defaults[i], eval_ctx));
                } else {
                    fn_ctx->defineByName(pname, NONE_VALUE);
                }
            }
        }
    }

    // Helper: bind function params with *args/*kwargs support

    // ── Recursion guard ─────────────────────────────────────────────────────
    // A tree-walking interpreter consumes real C++ stack per Nython call, so
    // runaway recursion crashed the process with SIGSEGV and no diagnostic.
    // (Easiest way to hit this: give a method the same name as a builtin and
    // call that builtin by bare name inside it — e.g. `def read_file(self, f)`
    // containing `read_file(f)`. The bare name resolves back to the method, so
    // it calls itself forever.) Convert that into a catchable Nython error.
    int call_depth_ = 0;
    static const int kMaxCallDepth = 900;
    struct DepthGuard {
        int& d;
        explicit DepthGuard(int& x) : d(x) { ++d; }
        ~DepthGuard() { --d; }
        DepthGuard(const DepthGuard&) = delete;
        DepthGuard& operator=(const DepthGuard&) = delete;
    };

public:
    // ── Real profiling ───────────────────────────────────────────────────────
    // The IDE's PROFILER panel used to invent timings by scanning source text
    // for "def " lines. These are measured: every call routes through evalCall,
    // so counting and timing there yields real call counts and real wall time.
    //
    // self_ns excludes time spent inside nested calls (a caller's own cost),
    // total_ns includes it. Recursion is handled by only charging the outermost
    // activation of a frame, so a recursive function is not counted N times over.
    struct ProfEntry {
        long long calls = 0;
        long long total_ns = 0;
        long long self_ns = 0;
        int       depth = 0;      // active activations, for recursion handling
    };
    static bool& profiling_enabled() { static bool e = false; return e; }
    std::map<std::string, ProfEntry> prof_;
    long long prof_child_ns_ = 0;   // ns charged to callees of the current frame

    struct ProfScope {
        NythonExecutor* ex; std::string name; bool on;
        std::chrono::steady_clock::time_point t0;
        long long saved_child;
        ProfScope(NythonExecutor* e, const std::string& n) : ex(e), name(n) {
            on = profiling_enabled() && !name.empty();
            if (!on) return;
            auto& pe = ex->prof_[name];
            pe.calls++;
            pe.depth++;
            saved_child = ex->prof_child_ns_;
            ex->prof_child_ns_ = 0;
            t0 = std::chrono::steady_clock::now();
        }
        ~ProfScope() {
            if (!on) return;
            auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
                               std::chrono::steady_clock::now() - t0).count();
            auto& pe = ex->prof_[name];
            long long children = ex->prof_child_ns_;
            pe.self_ns += (elapsed - children);
            pe.depth--;
            // Only the outermost activation contributes total time, otherwise a
            // recursive chain would count the same interval once per level.
            if (pe.depth == 0) pe.total_ns += elapsed;
            ex->prof_child_ns_ = saved_child + elapsed;
        }
    };

    // "name,calls,total_ms,self_ms" sorted by self time — the shape the IDE
    // panel consumes, and readable enough to eyeball from a terminal.
    std::string profile_report() {
        std::vector<std::pair<std::string, ProfEntry>> rows(prof_.begin(), prof_.end());
        std::sort(rows.begin(), rows.end(), [](auto& a, auto& b){
            return a.second.self_ns > b.second.self_ns; });
        std::ostringstream os;
        os << "name,calls,total_ms,self_ms\n";
        for (auto& [n, e] : rows) {
            os << n << "," << e.calls << ","
               << std::fixed << std::setprecision(3) << (double)e.total_ns / 1e6 << ","
               << std::fixed << std::setprecision(3) << (double)e.self_ns / 1e6 << "\n";
        }
        return os.str();
    }
    // Restore the surrounding access level: this block sits inside a public
    // section, and closing it with `private:` silently made everything after it
    // — callBuiltin included — private.
public:

    // Best-effort display name for a call site: `f()`, `obj.m()` -> "obj.m".
    std::string callTargetName(const std::shared_ptr<CallNode>& cn) {
        if (!cn || !cn->callee) return std::string();
        if (cn->callee->type() == NodeType::ATTRIBUTE) {
            auto at = static_pointer_cast<AttributeNode>(cn->callee);
            std::string base;
            if (at->object && at->object->type() == NodeType::VARIABLE)
                base = at->object->token().value + ".";
            else if (at->object && at->object->type() == NodeType::SELF)
                base = "self.";
            return base + at->attr;
        }
        if (cn->callee->type() == NodeType::VARIABLE)
            return cn->callee->token().value;
        return std::string();
    }

    Value evalCall(node_ptr node, Context* ctx) {
        if (call_depth_ >= kMaxCallDepth)
            throw std::string("__exc__:RecursionError:maximum call depth exceeded ("
                              + std::to_string(kMaxCallDepth) + ") — check for unintended "
                              "self-recursion, e.g. a method with the same name as a builtin");
        DepthGuard _depth_guard(call_depth_);
        auto cn = static_pointer_cast<CallNode>(node);
        // Zero cost when profiling is off: ProfScope short-circuits on the flag.
        ProfScope _prof(this, profiling_enabled() ? callTargetName(cn) : std::string());

        // Special handling for method calls: obj.method(args)
        if (cn->callee->type() == NodeType::ATTRIBUTE) {
            auto attr = static_pointer_cast<AttributeNode>(cn->callee);
            std::string method_name = attr->attr;

            // ── super.method(args) — call parent class method with current self ──
            // Match both `super.method()` and `super().method()` patterns
            bool is_super_call = attr->object->type() == NodeType::SUPER;
            if (!is_super_call && attr->object->type() == NodeType::CALL) {
                auto* call_node = static_cast<CallNode*>(attr->object.get());
                if (call_node->callee && call_node->callee->type() == NodeType::SUPER)
                    is_super_call = true;
            }
            if (is_super_call) {
                Value self_val = ctx->getByName("self");
                // Find parent class name from __parent_class__ (set by child init dispatch)
                std::string parent_name;
                try { parent_name = getStringValue(ctx->getByName("__parent_class__")); } catch (...) {}
                if (parent_name.empty()) {
                    // Fallback: get from instance's class's first base
                    if (self_val.type == ValueType::USERDATA && self_val.value.p) {
                        auto cit2 = instance_to_class.find(self_val.value.p);
                        if (cit2 != instance_to_class.end()) {
                            auto ppit = class_parent.find(cit2->second);
                            if (ppit != class_parent.end()) parent_name = ppit->second;
                        }
                    }
                }
                std::vector<Value> args; std::unordered_map<std::string, Value> kw_args;
                evalCallArgs(cn->args, ctx, args, kw_args);
                if (!parent_name.empty()) {
                    auto pcit = class_by_name.find(parent_name);
                    if (pcit != class_by_name.end()) {
                        Node* pnode = (Node*)pcit->second;
                        if (pnode && pnode->type() == NodeType::CLASS) {
                            auto* pcn = static_cast<ClassNode*>(pnode);
                            if (pcn->body) {
                                for (auto& stmt : pcn->body->statements()) {
                                    if (stmt->type() != NodeType::FUNCTION) continue;
                                    auto* fn = static_cast<FunctionNode*>(stmt.get());
                                    if (fn->name != method_name) continue;
                                    Context* fn_ctx = new Context(runner, method_name, nullptr, nullptr, ctx);
                                    CtxReaper _reap_fn_ctx3513(this, fn_ctx);
                                    fn_ctx->defineByName("self", self_val);
                                    size_t ps = (!fn->params.empty() && fn->params[0]->value() == "self") ? 1 : 0;
                                    for (size_t i = ps; i < fn->params.size(); i++) {
                                        size_t ai = i - ps;
                                        if (ai < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[ai]);
                                        else if (i < fn->defaults.size() && fn->defaults[i])
                                            fn_ctx->defineByName(fn->params[i]->value(), evalNode(fn->defaults[i], ctx));
                                        else fn_ctx->defineByName(fn->params[i]->value(), NONE_VALUE);
                                    }
                                    // Set parent chain for chained super() calls
                                    if (!pcn->bases.empty())
                                        fn_ctx->defineByName("__parent_class__", makeStringValue(pcn->bases[0]->value()));
                                    fn_ctx->defineByName("__instance__", self_val);
                                    try { Value r = evalNode(fn->body, fn_ctx); return r; }
                                    catch (nython::node::ReturnSignal& r) { return r.value; }
                                    catch (...) {}
                                }
                            }
                        }
                    }
                }
                return NONE_VALUE;
            }

            Value obj = evalNode(attr->object, ctx);

            // Evaluate arguments
            std::vector<Value> args; std::unordered_map<std::string, Value> kw_args;
            evalCallArgs(cn->args, ctx, args, kw_args);

            // Check class_ctx_map_ FIRST for decorated methods (e.g. @decorator on class method)
            // This ensures we call the decorated wrapper with self injected into *args.
            if (obj.type == ValueType::USERDATA && obj.value.p && !string_ptrs_.count(obj.value.p) && instance_to_class.count(obj.value.p)) {
                void* cp2 = instance_to_class[obj.value.p];
                void* ast2 = cp2;
                auto ai2 = func_ast_nodes.find(cp2);
                if (ai2 != func_ast_nodes.end()) ast2 = ai2->second;
                Node* cn2 = (Node*)ast2;
                auto cctx_it = class_ctx_map_.find((void*)cn2);
                if (cctx_it == class_ctx_map_.end()) cctx_it = class_ctx_map_.find(cp2);
                if (cctx_it != class_ctx_map_.end()) {
                    Value decorated_method;
                    try { decorated_method = cctx_it->second->getByName(method_name); } catch (...) {}
                    if (decorated_method.type == ValueType::USERDATA && decorated_method.value.p &&
                        func_names.count(decorated_method.value.p)) {
                        const std::string& dmt = func_names[decorated_method.value.p];
                        bool is_deco_fn = dmt.find("__func__:") == 0;
                        bool is_deco_lam = dmt.find("__lambda__") == 0;
                        if (is_deco_fn || is_deco_lam) {
                            // Check if it's a decorated wrapper (first param != "self")
                            void* ast3 = decorated_method.value.p;
                            auto ai3 = func_ast_nodes.find(decorated_method.value.p);
                            if (ai3 != func_ast_nodes.end()) ast3 = ai3->second;
                            Node* raw3 = (Node*)ast3;
                            bool is_decorated_wrapper = false;
                            if (raw3 && raw3->type() == NodeType::FUNCTION) {
                                auto* fn3 = static_cast<FunctionNode*>(raw3);
                                is_decorated_wrapper = (fn3->params.empty() || 
                                    (fn3->params[0]->value() != "self" && fn3->params[0]->value() != "this"));
                            }
                            if (is_decorated_wrapper) {
                                // Prepend self to args so *args wrapper receives all
                                std::vector<Value> with_self2;
                                with_self2.push_back(obj);
                                for (auto& a : args) with_self2.push_back(a);
                                return callFunctionValue(decorated_method, with_self2, ctx);
                            }
                        }
                    }
                }
            }

            // In Nython, everything is an object. Attributes can store callables
            // (functions, lambdas, closures). Check the attribute VALUE first;
            // if it is a callable, invoke it directly rather than as a named method.
            if (obj.type == ValueType::USERDATA && obj.value.p) {
                auto pit = instance_properties.find(obj.value.p);
                if (pit != instance_properties.end()) {
                    try {
                        Value attr_val = pit->second->getByName(method_name);
                        if (attr_val.type == ValueType::USERDATA && attr_val.value.p) {
                            auto fname_it = func_names.find(attr_val.value.p);
                            if (fname_it != func_names.end()) {
                                const std::string& fn_type = fname_it->second;
                                bool is_fn  = fn_type.find("__func__:") == 0;
                                bool is_lam = fn_type.find("__lambda__") == 0;
                                bool is_bi  = fn_type.find("__builtin__:") == 0;
                                if (is_fn || is_lam || is_bi) {
                                    if (is_bi) return callBuiltin(fn_type.substr(12), args, ctx);
                                    // A bound method can be STORED in an attribute
                                    // (e.g. win.on_resize(self.on_resize) keeps it
                                    // in self._on_resize, then calls
                                    // self._on_resize(w, h)). Re-supply its captured
                                    // instance here too, or every argument shifts.
                                    // self is supplied by bindParamsKw via the callee pointer
                                    void* ast_ptr = attr_val.value.p;
                                    auto ast_it = func_ast_nodes.find(attr_val.value.p);
                                    if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                                    Node* raw = (Node*)ast_ptr;
                                    if (raw->type() == NodeType::LAMBDA) {
                                        auto lam = static_cast<LambdaNode*>(raw);
                                        Context* cp = ctx;
                                        auto cit = closure_contexts.find(attr_val.value.p);
                                        if (cit != closure_contexts.end()) cp = cit->second;
                                        Context* fc = new Context(runner, "<lambda>", nullptr, nullptr, cp);
                                        CtxReaper _reap_fc3618(this, fc);
                                        for (size_t i = 0; i < lam->params.size() && i < args.size(); i++)
                                            fc->defineByName(lam->params[i]->value(), args[i]);
                                        return evalNode(lam->body, fc);
                                    } else if (raw->type() == NodeType::FUNCTION) {
                                        auto fn = static_cast<FunctionNode*>(raw);
                                        Context* cp = ctx;
                                        auto cit = closure_contexts.find(attr_val.value.p);
                                        if (cit != closure_contexts.end()) cp = cit->second;
                                        Context* fc = new Context(runner, fn->name, nullptr, nullptr, cp);
                                        CtxReaper _reap_fc3627(this, fc);
                                        bindParams(fn, args, fc, ctx, attr_val.value.p);
                                        try { return evalNode(fn->body, fc); }
                                        catch (nython::node::ReturnSignal& r) { return r.value; }
                                        catch (...) { return NONE_VALUE; }
                                    }
                                }
                            }
                        }
                    } catch (...) {}
                }
            }

            // Also check collectable dict containers (e.g. math module, namespace objects)
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<Container*>(obj.value.gc);
                if (cont && cont->container) {
                    auto attr_it = cont->container->find(method_name);
                    if (attr_it != cont->container->end()) {
                        Value attr_val = attr_it->second;
                        if (attr_val.type == ValueType::USERDATA && attr_val.value.p) {
                            auto fn_it = func_names.find(attr_val.value.p);
                            if (fn_it != func_names.end()) {
                                if (fn_it->second.find("__builtin__:") == 0)
                                    return callBuiltin(fn_it->second.substr(12), args, ctx);
                                if (fn_it->second.find("__func__:") == 0 || fn_it->second.find("__lambda__") == 0) {
                                    void* ast_ptr = attr_val.value.p;
                                    auto ai = func_ast_nodes.find(attr_val.value.p);
                                    if (ai != func_ast_nodes.end()) ast_ptr = ai->second;
                                    Node* raw = (Node*)ast_ptr;
                                    if (raw && raw->type() == NodeType::FUNCTION) {
                                        auto fn = static_cast<FunctionNode*>(raw);
                                        Context* cp = ctx;
                                        auto ci = closure_contexts.find(attr_val.value.p);
                                        if (ci != closure_contexts.end()) cp = ci->second;
                                        Context* fc = new Context(runner, fn->name, nullptr, nullptr, cp);
                                        CtxReaper _reap_fc3662(this, fc);
                                        bindParamsKw(fn, args, kw_args, fc, ctx, 0, attr_val.value.p);
                                        try { Value r = evalNode(fn->body, fc); return r; }
                                        catch (nython::node::ReturnSignal& r) { return r.value; }
                                        catch (...) { return NONE_VALUE; }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Fallback: evaluate the callee as a full expression (e.g. math.sqrt -> builtin USERDATA)
            // then invoke it directly. This handles namespace modules and function objects in dicts.
            {
                // `obj` above already holds the evaluated receiver. Evaluating
                // cn->callee here re-ran attr->object, so every receiver with a
                // side effect fired twice — and because the doubling compounds
                // through nesting, an n-deep method chain performed 2^n - 1
                // calls instead of n (v.add(1).add(1).add(1) incremented by 7).
                // Reuse it via receiver_cache_ instead of evaluating again.
                receiver_cache_[attr->object.get()] = obj;
                Value callee_val = evalNode(cn->callee, ctx);
                receiver_cache_.erase(attr->object.get());
                // Only use the fallback for builtin functions stored in dict namespaces
                // (e.g. math.sqrt). For class methods (__func__), let callMethod handle
                // self-binding correctly.
                if (callee_val.type == ValueType::USERDATA && callee_val.value.p) {
                    auto fn_it = func_names.find(callee_val.value.p);
                    if (fn_it != func_names.end()) {
                        if (fn_it->second.find("__builtin__:") == 0)
                            return callBuiltin(fn_it->second.substr(12), args, ctx);
                        // Class value accessed via attribute (e.g. Outer.Inner()) -> instantiate
                        if (fn_it->second.find("__class__:") == 0) {
                            // Re-invoke evalCall with this as the callee directly
                            // Build a synthetic call: reuse current evalCall non-ATTRIBUTE path
                            std::string class_fname = fn_it->second;
                            std::string className = class_fname.substr(10);
                            Value instance;
                            instance.type = ValueType::USERDATA;
                            auto inst_ptr = std::make_unique<std::string>("__instance__:" + className);
                            instance.value.p = (void*)inst_ptr.get();
                            instance_store.push_back(std::move(inst_ptr));
                            instance_to_class[instance.value.p] = callee_val.value.p;
                            func_names[instance.value.p] = "__instance__:" + className;
                            Context* props = new Context(runner, className + "_props", nullptr, nullptr, nullptr);
                            instance_properties[instance.value.p] = props;
                            // Find and call init
                            Node* class_node_raw = (Node*)callee_val.value.p;
                            if (class_node_raw && class_node_raw->type() == NodeType::CLASS) {
                                auto* cn_inner = static_cast<ClassNode*>(class_node_raw);
                                if (cn_inner->body) {
                                    for (auto& stmt : cn_inner->body->statements()) {
                                        if (stmt->type() == NodeType::FUNCTION) {
                                            auto* fn = static_cast<FunctionNode*>(stmt.get());
                                            if (fn->name == "init" || fn->name == "__init__") {
                                                Context* fn_ctx = new Context(runner, "init", nullptr, nullptr, ctx);
                                                CtxReaper _reap_fn_ctx3711(this, fn_ctx);
                                                fn_ctx->defineByName("self", instance);
                                                size_t ps = (!fn->params.empty() && fn->params[0]->value() == "self") ? 1 : 0;
                                                for (size_t i = ps; i < fn->params.size(); i++) {
                                                    size_t ai = i - ps;
                                                    if (ai < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[ai]);
                                                    else if (i < fn->defaults.size() && fn->defaults[i]) fn_ctx->defineByName(fn->params[i]->value(), evalNode(fn->defaults[i], ctx));
                                                    else fn_ctx->defineByName(fn->params[i]->value(), NONE_VALUE);
                                                }
                                                try { evalNode(fn->body, fn_ctx); } catch (nython::node::ReturnSignal&) {} catch (...) {}
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                            return instance;
                        }
                    }
                }            }

            // Inject keyword args for built-in list methods that accept them
            if (method_name == "sort" || method_name == "sorted") {
                auto rev_it = kw_args.find("reverse");
                if (rev_it != kw_args.end()) args.push_back(rev_it->second);
                auto key_it = kw_args.find("key");
                if (key_it != kw_args.end() && args.size() == 0) args.push_back(key_it->second);
                else if (key_it != kw_args.end()) args.insert(args.begin(), key_it->second);
            }
            return callMethod(obj, method_name, args, ctx, &kw_args);
        }

        Value callee = evalNode(cn->callee, ctx);

        // Evaluate arguments (handles keyword args, *spread, **spread)
        std::vector<Value> args;
        std::unordered_map<std::string, Value> kw_args;
        evalCallArgs(cn->args, ctx, args, kw_args);

        // Check for built-in functions
        std::string fname;
        if (callee.type == ValueType::USERDATA) {
            if (callee.value.p) {
                auto it = func_names.find(callee.value.p);
                if (it != func_names.end()) fname = it->second;
                else if (!string_ptrs_.count(callee.value.p)) {
                    // Try to cast as Node and get type
                    // Get the AST node from our mapping
                void* ast_ptr = callee.value.p;
                auto ast_it = func_ast_nodes.find(callee.value.p);
                if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                Node* raw = (Node*)ast_ptr;
                    if (raw->type() == NodeType::FUNCTION) {
                        auto* fn = static_cast<FunctionNode*>(raw);
                        fname = "__func__:" + fn->name;
                    } else if (raw->type() == NodeType::LAMBDA) {
                        fname = "__lambda__";
                    }
                }
            } else {
                // nullptr = builtin marker
                auto it = func_names.find(nullptr);
                if (it != func_names.end()) fname = it->second;
            }
        }
        if (fname.empty()) fname = callee.token.value;
        if (fname.find("__builtin__:") == 0) {
            std::string builtin = fname.substr(12);
            // Flatten kwargs for builtins that accept them (key=, reverse=, default=)
            static const std::unordered_set<std::string> kw_builtins = {
                "sorted", "min", "max", "filter", "map", "reduce", "enumerate"
            };
            if (!kw_args.empty() && kw_builtins.count(builtin)) {
                auto kit = kw_args.find("key");
                if (kit != kw_args.end()) args.push_back(kit->second);
                auto rit = kw_args.find("reverse");
                if (rit != kw_args.end()) args.push_back(rit->second);
                auto dit = kw_args.find("default");
                if (dit != kw_args.end()) args.push_back(dit->second);
                auto sit = kw_args.find("start");
                if (sit != kw_args.end()) args.push_back(sit->second);
            }
            return callBuiltin(builtin, args, ctx);
        }
        // Also check callee token for builtin (for print etc parsed as keywords)


        // Check for user-defined function (stored as USERDATA pointing to FunctionNode)
        if (callee.type == ValueType::USERDATA && callee.value.p) {
            // Bound method read off an instance (e.g. `win.run(self._main_loop)`):
            // restore the captured `self` as the first argument.
            // self is supplied by bindParamsKw via the callee pointer
            if (fname.find("__func__:") == 0 || fname.find("__lambda__") == 0) {
                // Get the AST node from our mapping
                void* ast_ptr = callee.value.p;
                auto ast_it = func_ast_nodes.find(callee.value.p);
                if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                Node* raw = (Node*)ast_ptr;
                if (raw->type() == NodeType::FUNCTION) {
                    auto fn = static_cast<FunctionNode*>(raw);
                    // Use closure: parent is the context where function was defined
                    Context* closure_parent = ctx;
                    auto cit = closure_contexts.find(callee.value.p);
                    if (cit != closure_contexts.end()) closure_parent = cit->second;
                    // Generator detection: run with yield_sink_ set (only if yield exists in AST)
                    if (hasYield(fn->body)) {
                        std::vector<Value> yielded;
                        yield_sink_ = &yielded;
                        Context* probe_ctx = new Context(runner, fn->name, nullptr, nullptr, closure_parent);
                        CtxReaper _reapProbe(this, probe_ctx);
                        bindParamsKw(fn, args, kw_args, probe_ctx, ctx, 0, callee.value.p);
                        try { evalNode(fn->body, probe_ctx); }
                        catch (nython::node::ReturnSignal&) {}
                        catch (...) {}
                        yield_sink_ = nullptr;
                        if (!yielded.empty()) {
                            Object* gen_obj = new Object((Runnable*)runner, "__gen__", Type::LIST);
                            int glen = (int)yielded.size();
                            for (int gi = 0; gi < glen; gi++) gen_obj->set(std::to_string(gi), yielded[(size_t)gi]);
                            gen_obj->set("__len__", Value(glen));
                            gen_obj->set("__gen__", Value(1));
                            gen_obj->set("__idx__", Value(0));
                            return Value((Collectable*)gen_obj);
                        }
                    }
                    Context* fn_ctx = new Context(runner, fn->name, nullptr, nullptr, closure_parent);
                    CtxReaper _reap(this, fn_ctx);
                    // Bind parameters with keyword arg and *args support
                    bindParamsKw(fn, args, kw_args, fn_ctx, ctx, 0, callee.value.p);
                    try {
                        Value result = evalNode(fn->body, fn_ctx);
                        return result;
                    } catch (nython::node::ReturnSignal& ret) {
                        return ret.value;
                    } catch (std::string& _ex) {
                        throw; // re-propagate user exceptions (__exc__) and flow signals
                    }
                } else if (raw->type() == NodeType::LAMBDA) {
                    auto lam = static_cast<LambdaNode*>(raw);
                    // Use closure context if available (for returned lambdas)
                    Context* closure_parent = ctx;
                    auto cit2 = closure_contexts.find(callee.value.p);
                    if (cit2 != closure_contexts.end()) closure_parent = cit2->second;
                    Context* fn_ctx = new Context(runner, "<lambda>", nullptr, nullptr, closure_parent);
                    CtxReaper _reap_fn_ctx3854(this, fn_ctx);
                    for (size_t i = 0; i < lam->params.size(); i++) {
                        std::string pname = lam->params[i]->value();
                        auto kw_it = kw_args.find(pname);
                        if (kw_it != kw_args.end()) {
                            fn_ctx->defineByName(pname, kw_it->second);
                        } else if (i < args.size()) {
                            fn_ctx->defineByName(pname, args[i]);
                        } else if (i < lam->defaults.size() && lam->defaults[i]) {
                            fn_ctx->defineByName(pname, evalNode(lam->defaults[i], closure_parent));
                        } else {
                            fn_ctx->defineByName(pname, NONE_VALUE);
                        }
                    }
                    Value result = evalNode(lam->body, fn_ctx);
                    return result;
                }
            }
        }

        // __call__ protocol: if callee is an instance with __call__ method, invoke it
        if (callee.type == ValueType::USERDATA && callee.value.p && !string_ptrs_.count(callee.value.p) &&
            fname.find("__instance__:") == 0 && instance_to_class.count(callee.value.p)) {
            Value call_result = callMethod(callee, "__call__", args, ctx);
            if (call_result.type != ValueType::NONE) return call_result;
            // __call__ returned none — still return it (it IS the result)
            // Check if __call__ method exists at all before returning NONE
            void* class_ptr2 = instance_to_class[callee.value.p];
            auto cctx2 = class_ctx_map_.find(class_ptr2);
            if (cctx2 == class_ctx_map_.end()) {
                Node* cn2 = (Node*)class_ptr2;
                cctx2 = class_ctx_map_.find((void*)cn2);
            }
            bool has_call = false;
            if (cctx2 != class_ctx_map_.end()) {
                try { Value v = cctx2->second->getByName("__call__"); has_call = (v.type != ValueType::UNDEFINED); } catch (...) {}
            }
            if (!has_call) {
                // Also check body
                Node* cn3 = (Node*)class_ptr2;
                if (cn3 && cn3->type() == NodeType::CLASS) {
                    for (auto& stmt : static_cast<ClassNode*>(cn3)->body->statements()) {
                        if (stmt->type() == NodeType::FUNCTION && static_cast<FunctionNode*>(stmt.get())->name == "__call__") {
                            has_call = true; break;
                        }
                    }
                }
            }
            if (has_call) return call_result;
        }

        // Class instantiation: __class__:Name
        if (callee.type == ValueType::USERDATA && callee.value.p && fname.find("__class__:") == 0) {
            std::string className = fname.substr(10);
            // Create new instance object
            Value instance;
            instance.type = ValueType::USERDATA;
            auto inst_ptr = std::make_unique<std::string>("__instance__:" + className);
            instance.value.p = (void*)inst_ptr.get();
            instance_store.push_back(std::move(inst_ptr));
            instance_to_class[instance.value.p] = callee.value.p; // track class
            func_names[instance.value.p] = "__instance__:" + className;
            // Create property storage for this instance
            Context* props = new Context(runner, className + "_props", nullptr, nullptr, nullptr);
            instance_properties[instance.value.p] = props;

            // Create instance context inheriting class methods
            Context* inst_ctx = new Context(runner, className + "_instance", nullptr, nullptr, ctx);
            inst_ctx->defineByName("self", instance);

            // Look for __init__ / init method and call it
            Node* class_node = (Node*)callee.value.p;
            bool found_init = false;
            if (class_node->type() == NodeType::CLASS) {
                auto* cn_raw = static_cast<ClassNode*>(class_node);
                if (cn_raw->body) {
                    // Look for init method in class body
                    for (auto& stmt : cn_raw->body->statements()) {
                        if (stmt->type() == NodeType::FUNCTION) {
                            auto* fn = static_cast<FunctionNode*>(stmt.get());
                            if (fn->name == "init" || fn->name == "__init__") {
                                found_init = true;
                                Context* fn_ctx = new Context(runner, "init", nullptr, nullptr, ctx);
                                fn_ctx->defineByName("self", instance);
                                fn_ctx->defineByName("this", instance);
                                size_t ps = 0;
                                if (!fn->params.empty() && fn->params[0]->value() == "self") ps = 1;
                                for (size_t i = ps; i < fn->params.size(); i++) {
                                    size_t ai = i - ps;
                                    if (ai < args.size()) {
                                        fn_ctx->defineByName(fn->params[i]->value(), args[ai]);
                                    } else if (i < fn->defaults.size() && fn->defaults[i]) {
                                        fn_ctx->defineByName(fn->params[i]->value(), evalNode(fn->defaults[i], ctx));
                                    } else {
                                        fn_ctx->defineByName(fn->params[i]->value(), NONE_VALUE);
                                    }
                                }
                                // Set up super() - find parent class and bind its init
                                if (cn_raw->bases.size() > 0) {
                                    std::string pname = cn_raw->bases[0]->value();
                                    fn_ctx->defineByName("__parent_class__", makeStringValue(pname));
                                    fn_ctx->defineByName("__instance__", instance);
                                }
                                try { evalNode(fn->body, fn_ctx); } catch (nython::node::ReturnSignal&) {} catch (...) {}
                            }
                        }
                    }
                }
            }
            // If no init found in child, walk full inheritance chain to find init
            if (!found_init) {
                // Walk the MRO: start from current class, go to its parent, then grandparent, etc.
                Node* search_node = class_node;
                for (int depth = 0; depth < 10 && !found_init; depth++) {
                    if (!search_node || search_node->type() != NodeType::CLASS) break;
                    auto* cn_walk = static_cast<ClassNode*>(search_node);
                    if (cn_walk->bases.empty()) break;
                    // Try each base
                    bool advanced = false;
                    for (auto& base_node_ptr : cn_walk->bases) {
                        std::string parent_name = base_node_ptr->value();
                        Value parent_val;
                        try { parent_val = ctx->getByName(parent_name); } catch (...) { continue; }
                        if (parent_val.type != ValueType::USERDATA || !parent_val.value.p) continue;
                        void* past = parent_val.value.p;
                        auto pit = func_ast_nodes.find(past);
                        if (pit != func_ast_nodes.end()) past = pit->second;
                        Node* pnode = (Node*)past;
                        if (!pnode || pnode->type() != NodeType::CLASS) continue;
                        auto* pcn = static_cast<ClassNode*>(pnode);
                        if (pcn->body) {
                            for (auto& stmt : pcn->body->statements()) {
                                if (stmt->type() == NodeType::FUNCTION) {
                                    auto* fn = static_cast<FunctionNode*>(stmt.get());
                                    if (fn->name == "init" || fn->name == "__init__") {
                                        found_init = true;
                                        Context* fn_ctx = new Context(runner, "init", nullptr, nullptr, ctx);
                                        fn_ctx->defineByName("self", instance);
                                        size_t ps = (!fn->params.empty() && fn->params[0]->value() == "self") ? 1 : 0;
                                        for (size_t i = ps; i < fn->params.size(); i++) {
                                            size_t ai = i - ps;
                                            if (ai < args.size()) fn_ctx->defineByName(fn->params[i]->value(), args[ai]);
                                            else if (i < fn->defaults.size() && fn->defaults[i])
                                                fn_ctx->defineByName(fn->params[i]->value(), evalNode(fn->defaults[i], ctx));
                                            else fn_ctx->defineByName(fn->params[i]->value(), NONE_VALUE);
                                        }
                                        try { evalNode(fn->body, fn_ctx); }
                                        catch (nython::node::ReturnSignal&) {}
                                        catch (...) {}
                                        break;
                                    }
                                }
                            }
                        }
                        if (!advanced) { search_node = pnode; advanced = true; }
                        if (found_init) break;
                    }
                    if (!advanced) break;
                }
            }
            return instance;
        }

        // Check for Object.call if callee is collectable
        if (callee.isCollectable() && callee.value.gc) {
            auto* obj = dynamic_cast<Object*>(callee.value.gc);
            if (obj) return obj->call(args);
        }

        // Final fallback: if fname looks like a module builtin (contains '_' and callee was
        // unresolved), try dispatching through callBuiltin. This handles gui_*, os_*, etc.
        // functions that were not individually registered via registerBuiltin().
        if (!fname.empty() && callee.type == ValueType::NONE
            && fname.find("__") != 0   // not a dunder
            && fname.find('_') != std::string::npos) {  // contains underscore = module builtin pattern
            Value r = callBuiltin(fname, args, ctx);
            if (r.type != ValueType::NONE) return r;
            // return NONE even from callBuiltin so gui_clear() etc. still return none
            return NONE_VALUE;
        }

        // Calling something that does not exist used to return none and carry on.
        // `print(totally_undefined_fn(1))` printed "none" and the next statement
        // ran, so a typo in a method name produced a wrong answer instead of an
        // error — the same silent-failure class as the import bug in round 46,
        // and far harder to find because there is no diagnostic at all.
        //
        // Raise a located NameError instead. The token carries file, line and
        // column, so the message can say exactly where the call is.
        {
            // Use the callee's own token: `fname` is not the called name at this
            // point in the fallthrough, and reporting it named the wrong thing
            // ("'End' is not defined") at the wrong column.
            std::string called = fname;
            Token t = cn->token();
            if (cn->callee) {
                t = cn->callee->token();
                if (cn->callee->type() == NodeType::VARIABLE) called = t.value;
                else if (cn->callee->type() == NodeType::ATTRIBUTE)
                    called = static_pointer_cast<AttributeNode>(cn->callee)->attr;
            }
            if (called.empty()) return NONE_VALUE;

            // Only report a name that is absent EVERYWHERE. This fallthrough is
            // also reached for names that do resolve by another route -- classes
            // registered by an imported module, functions reached through the
            // builtin bridge -- and raising there broke 15 working examples on
            // the first attempt. Silence for a resolvable name is the lesser
            // error; a false NameError stops a correct program.
            if (builtin_set.count(called)) return NONE_VALUE;
            if (ctx && ctx->getByName(called).type != ValueType::UNDEFINED)
                return NONE_VALUE;
            for (auto& kv : func_names) {
                const std::string& n = kv.second;
                if (n == called
                    || (n.rfind("__func__:", 0) == 0  && n.substr(9)  == called)
                    || (n.rfind("__class__:", 0) == 0 && n.substr(10) == called)
                    || (n.rfind("__builtin__:", 0) == 0 && n.substr(12) == called))
                    return NONE_VALUE;
            }
            std::string where = " at line " + std::to_string(t.line())
                              + ", column " + std::to_string(t.column());
            std::string hint = suggestName(called);
            if (!hint.empty()) hint = "  (did you mean '" + hint + "'?)";
            throw std::string("__exc__:NameError:'" + called
                              + "' is not defined" + where + hint);
        }

        return NONE_VALUE;
    }

    // Closest known name by edit distance, for "did you mean" hints. Only
    // suggests when the candidate is genuinely close, so a wrong guess does not
    // send someone chasing an unrelated identifier.
    std::string suggestName(const std::string& want) {
        size_t best = std::string::npos;
        std::string bestName;
        auto consider = [&](const std::string& cand) {
            if (cand.empty() || cand.find("__") == 0) return;
            size_t la = want.size(), lb = cand.size();
            if (la > lb + 3 || lb > la + 3) return;
            std::vector<size_t> prev(lb + 1), cur(lb + 1);
            for (size_t j = 0; j <= lb; ++j) prev[j] = j;
            for (size_t i = 1; i <= la; ++i) {
                cur[0] = i;
                for (size_t j = 1; j <= lb; ++j) {
                    size_t cost = (want[i-1] == cand[j-1]) ? 0 : 1;
                    cur[j] = std::min({prev[j] + 1, cur[j-1] + 1, prev[j-1] + cost});
                }
                prev = cur;
            }
            size_t d = prev[lb];
            if (d < best) { best = d; bestName = cand; }
        };
        for (auto& kv : func_names) {
            const std::string& n = kv.second;
            if (n.rfind("__func__:", 0) == 0) consider(n.substr(9));
            else if (n.rfind("__class__:", 0) == 0) consider(n.substr(10));
        }
        for (auto& b : builtin_set) consider(b);
        if (best <= 2 && best != std::string::npos) return bestName;
        return std::string();
    }

    std::vector<std::unique_ptr<std::string>> instance_store;
    // ── Bound methods ───────────────────────────────────────────────────────
    // When a method is read off an instance as a VALUE (e.g. `cb = obj.method`,
    // or `win.run(self._main_loop)`) rather than called immediately, we must
    // remember which instance it came from. Without this, `self` is never
    // supplied at call time and every argument shifts left by one:
    //     obj.m(a, b)  ->  self=obj,  x=a,    y=b     (correct)
    //     f = obj.m; f(a, b)  ->  self=a, x=b, y=none (silently wrong)
    // That shift is invisible — attribute reads on the wrong `self` just yield
    // none — so it corrupts callback-driven code without raising an error.
    std::vector<std::unique_ptr<std::string>> bound_store_;
    std::map<void*, Value> bound_self_;   // bound-method ptr -> the instance
    // (method ptr, instance ptr) -> bound-method ptr, so re-reading the same
    // method off the same object reuses one binding instead of leaking a new one.
    std::map<std::pair<void*, void*>, void*> bound_cache_;
    std::map<void*, void*> instance_to_class; // instance ptr -> class node ptr
    std::map<void*, Context*> instance_properties;
    std::map<std::string, void*> class_by_name; // className -> class node ptr
    std::vector<std::string> super_parent_stack; // for chained super() calls
    std::map<void*, std::string> class_parent; // class node ptr -> parent class name
    std::unordered_map<void*, Value> exc_instance_map_; // raised instance ptr -> Value
    std::map<std::string, Value> class_vars_; // "ClassName.varName" -> Value (shared class-level variables)
    std::map<void*, Context*> class_ctx_map_; // class node ptr -> evaluated class body context (for decorators)


    // Public (struct default) so the VM builtin bridge can dispatch by name.
    Value callBuiltin(const std::string& name_orig, std::vector<Value>& args, Context* ctx) {
        // ── Exception type constructors ─────────────────────────────────────────
        // ── property() and staticmethod() ─────────────────────────────────────
        if (name_orig == "property") {
            // property(fn) — tag the function value with __property__ marker
            if (!args.empty() && args[0].type == ValueType::USERDATA && args[0].value.p) {
                func_names[args[0].value.p] += "__property__";
                return args[0];
            }
            return NONE_VALUE;
        }
        if (name_orig == "staticmethod") {
            // staticmethod(fn) — tag with __static__ so it's called without self
            if (!args.empty() && args[0].type == ValueType::USERDATA && args[0].value.p) {
                func_names[args[0].value.p] += "__static__";
                return args[0];
            }
            return NONE_VALUE;
        }
        if (name_orig == "classmethod") {
            // classmethod(fn) — tag with __classmethod__
            if (!args.empty() && args[0].type == ValueType::USERDATA && args[0].value.p) {
                func_names[args[0].value.p] += "__classmethod__";
                return args[0];
            }
            return NONE_VALUE;
        }
        static const std::unordered_set<std::string> exc_types_ = {
            "Exception","BaseException","Error",
            "ValueError","TypeError","KeyError","IndexError","AttributeError",
            "NameError","RuntimeError","IOError","OSError","FileNotFoundError",
            "ZeroDivisionError","OverflowError","MemoryError","RecursionError",
            "StopIteration","GeneratorExit","SystemExit","KeyboardInterrupt",
            "AssertionError","NotImplementedError","PermissionError","TimeoutError"
        };
        if (exc_types_.count(name_orig)) {
            // Create exception Value tagged as "__exc__:TypeName:message"
            std::string msg = args.empty() ? "" : args[0].type == ValueType::USERDATA
                ? getStringValue(args[0]) : args[0].toString();
            // Store as a special tagged string value so evalRaise can extract type
            return makeStringValue("__exc__:" + name_orig + ":" + msg);
        }
        // ── Name normalisation aliases ─────────────────────────────────────────
        std::string name = name_orig;
        if (name == "regex_match")   name = "re_match";
        if (name == "regex_replace") name = "re_sub";
        if (name == "regex_findall") name = "re_findall";
        if (name == "regex_split")   name = "re_split";

        // ── Module dispatch (try each module in priority order) ────────────────
        Value result;
        result = dispatch_lang(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_core(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_tensor(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_audio(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_string(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_io(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_network(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_math(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_os(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_data(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_threading(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        result = dispatch_gui(*this, name, args, ctx); if (result.type != ValueType::UNDEFINED) return result;
        return NONE_VALUE;
    }


    // ─── COLLECTIONS ────────────────────────────────────────────────────
    Value evalList(node_ptr node, Context* ctx) {
        auto ln = static_pointer_cast<ListNode>(node);
        bool is_tuple = (node->type() == NodeType::TUPLE);
        auto* obj = new Object((Runnable*)runner, is_tuple ? "tuple" : "list", Type::LIST);
        int idx = 0;
        for (auto& el : ln->elements) {
            obj->set(std::to_string(idx++), evalNode(el, ctx));
        }
        obj->set("__len__", Value((int)idx));
        if (is_tuple) obj->set("__tuple__", Value(1));
        return Value((Collectable*)obj);
    }

    Value evalMap(node_ptr node, Context* ctx) {
        auto mn = static_pointer_cast<MapNode>(node);
        auto* cont = new Object((Runnable*)runner, "map", Type::MAP);
        for (auto& e : mn->entries) {
            auto me = static_pointer_cast<MapEntryNode>(e);
            Value key = evalNode(me->key, ctx);
            Value val = evalNode(me->val, ctx);
            // Use string key for map storage
            std::string skey = getStringValue(key);
            (*cont->container)[skey] = val;
        }
        return Value((Collectable*)cont);
    }

    Value evalRange(node_ptr node, Context* ctx) {
        auto rn = static_pointer_cast<RangeNode>(node);
        Value start = evalNode(rn->start, ctx);
        Value end = evalNode(rn->end_node, ctx);
        // Build the SAME shape a list literal builds: an Object with string
        // indices and a __len__. It previously built a Container with
        // write(key,value) pairs, which len() understood but for-loops and the
        // printer did not — `1..4` had the right three elements and still
        // iterated zero times and printed as a map.
        auto* obj = new Object((Runnable*)runner, "list", Type::LIST);
        int idx = 0;
        if (start.type == ValueType::INTEGER && end.type == ValueType::INTEGER) {
            int64_t s = bigint_to_i64(start.value.i), e = bigint_to_i64(end.value.i);
            int64_t step = rn->step ? bigint_to_i64(evalNode(rn->step, ctx).value.i)
                                    : (s <= e ? 1 : -1);
            if (step > 0)      for (auto i = s; i < e; i += step) obj->set(std::to_string(idx++), Value(bigint(i)));
            else if (step < 0) for (auto i = s; i > e; i += step) obj->set(std::to_string(idx++), Value(bigint(i)));
        }
        obj->set("__len__", Value((int)idx));
        return Value((Collectable*)obj);
    }

    // ─── ATTRIBUTE / SUBSCRIPT ──────────────────────────────────────────
    // Receivers already evaluated by evalCall, keyed by the object node. Lets
    // the callee-lookup fallback reuse a receiver instead of re-running it.
    std::unordered_map<const void*, Value> receiver_cache_;

    Value evalAttribute(node_ptr node, Context* ctx) {
        auto an = static_pointer_cast<AttributeNode>(node);
        Value obj;
        {
            auto rc = receiver_cache_.find(an->object.get());
            if (rc != receiver_cache_.end()) obj = rc->second;
            else obj = evalNode(an->object, ctx);
        }
        // Check instance properties first (and invoke @property getters)
        if (obj.type == ValueType::USERDATA && obj.value.p) {
            auto pit = instance_properties.find(obj.value.p);
            if (pit != instance_properties.end()) {
                Value v = pit->second->getByName(an->attr);
                if (v.type != ValueType::UNDEFINED) {
                    // Check if this is a @property — if so, call it with self
                    if (v.type == ValueType::USERDATA && v.value.p) {
                        auto fn_it = func_names.find(v.value.p);
                        if (fn_it != func_names.end() && fn_it->second.find("__property__") != std::string::npos) {
                            // Invoke the getter
                            void* ast_ptr = v.value.p;
                            auto ast_it = func_ast_nodes.find(v.value.p);
                            if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
                            Node* raw = (Node*)ast_ptr;
                            if (raw && raw->type() == NodeType::FUNCTION) {
                                auto fn = static_cast<FunctionNode*>(raw);
                                Context* closure_parent = ctx;
                                auto cit = closure_contexts.find(v.value.p);
                                if (cit != closure_contexts.end()) closure_parent = cit->second;
                                Context* fc = new Context(runner, fn->name, nullptr, nullptr, closure_parent);
                                fc->defineByName("self", obj);
                                try { Value r = evalNode(fn->body, fc); return r; }
                                catch (nython::node::ReturnSignal& r) { return r.value; }
                                catch (...) {}
                            }
                        }
                    }
                    return v;
                }
            }
        }
        if (obj.isCollectable() && obj.value.gc) {
            auto* cont = dynamic_cast<Container*>(obj.value.gc);
            if (cont && cont->container) {
                auto it = cont->container->find(an->attr);
                if (it != cont->container->end()) return it->second;
            }
        }
        // Class variable / static method lookup: ClassName.var or ClassName.staticmethod
        // Also handles instance.property for @property getters not stored per-instance
        if (obj.type == ValueType::USERDATA && obj.value.p) {
            // If obj is an instance, find its class; if it IS a class, use directly
            void* class_ptr = obj.value.p;
            auto inst_it = instance_to_class.find(class_ptr);
            if (inst_it != instance_to_class.end()) class_ptr = inst_it->second;
            void* ast_ptr = class_ptr;
            auto ast_it = func_ast_nodes.find(class_ptr);
            if (ast_it != func_ast_nodes.end()) ast_ptr = ast_it->second;
            Node* class_node = (Node*)ast_ptr;
            if (class_node && func_names.find(class_ptr) != func_names.end() && class_node->type() == NodeType::CLASS) {
                auto* cn = static_cast<ClassNode*>(class_node);
                // Check class body context (handles @staticmethod, @property, class vars)
                auto ctx_it = class_ctx_map_.find((void*)class_node);
                if (ctx_it != class_ctx_map_.end()) {
                    Value cv;
                    try { cv = ctx_it->second->getByName(an->attr); } catch (...) {}
                    if (cv.type != ValueType::UNDEFINED && cv.type != ValueType::NONE) {
                        // Check if this is a @property getter — invoke it with self
                        if (cv.type == ValueType::USERDATA && cv.value.p) {
                            auto fn_it = func_names.find(cv.value.p);
                            if (fn_it != func_names.end() && fn_it->second.find("__property__") != std::string::npos) {
                                void* pst = cv.value.p;
                                auto pit2 = func_ast_nodes.find(cv.value.p);
                                if (pit2 != func_ast_nodes.end()) pst = pit2->second;
                                Node* raw = (Node*)pst;
                                if (raw && raw->type() == NodeType::FUNCTION) {
                                    auto fn = static_cast<FunctionNode*>(raw);
                                    Context* cp = ctx;
                                    auto cit2 = closure_contexts.find(cv.value.p);
                                    if (cit2 != closure_contexts.end()) cp = cit2->second;
                                    Context* fc = new Context(runner, fn->name, nullptr, nullptr, cp);
                                    fc->defineByName("self", obj);
                                    try { Value r = evalNode(fn->body, fc); return r; }
                                    catch (nython::node::ReturnSignal& r) { return r.value; }
                                    catch (...) {}
                                }
                            }
                        }
                        // A method read as a value off an INSTANCE must carry its
                        // instance with it, or `self` is lost at call time.
                        if (instance_to_class.count(obj.value.p))
                            return makeBoundMethod(cv, obj);
                        return cv;
                    }
                }
                // Check class_vars_ (mutable class-level variables set at runtime)
                std::string cv_key = cn->name + "." + an->attr;
                auto cv_it = class_vars_.find(cv_key);
                if (cv_it != class_vars_.end()) return cv_it->second;
                // Not yet set — evaluate class-level default from body
                if (cn->body) {
                    for (auto& stmt : cn->body->statements()) {
                        if (stmt->type() == NodeType::ASSIGNMENT) {
                            auto as = static_pointer_cast<AssignmentNode>(stmt);
                            if (as->target->type() == NodeType::VARIABLE && as->target->value() == an->attr) {
                                return evalNode(as->value_node, ctx);
                            }
                        }
                    }
                }
            }
        }
        return NONE_VALUE;
    }

    Value evalSubscript(node_ptr node, Context* ctx) {
        auto sn = static_pointer_cast<SubscriptNode>(node);
        Value obj = evalNode(sn->object, ctx);
        Value idx = evalNode(sn->index, ctx);

        // String indexing: s[0], s[-1]
        if (obj.type == ValueType::USERDATA && obj.value.p && !func_names.count(obj.value.p)) {
            std::string s = getStringValue(obj);
            if (idx.type == ValueType::INTEGER) {
                int64_t i = bigint_to_i64(idx.value.i);
                if (i < 0) i += (int64_t)s.size();
                if (i >= 0 && i < (int64_t)s.size())
                    return makeStringValue(std::string(1, s[(size_t)i]));
            }
            return NONE_VALUE;
        }

        // List/Map indexing with negative index support
        if (obj.isCollectable() && obj.value.gc) {
            auto* cont = dynamic_cast<Container*>(obj.value.gc);
            if (cont && cont->container) {
                if (idx.type == ValueType::INTEGER) {
                    int64_t i = bigint_to_i64(idx.value.i);
                    if (i < 0) {
                        auto len_it = cont->container->find("__len__");
                        if (len_it != cont->container->end())
                            i += bigint_to_i64(len_it->second.value.i);
                    }
                    auto it = cont->container->find(std::to_string(i));
                    if (it != cont->container->end()) return it->second;
                    // Index out of bounds: check if it's a list
                    auto len_it = cont->container->find("__len__");
                    if (len_it != cont->container->end()) {
                        throw std::string("__exc__:IndexError:index " + std::to_string(i) + " out of range (length " + std::to_string(bigint_to_i64(len_it->second.value.i)) + ")");
                    }
                }
                // String key lookup for maps
                std::string key = (idx.type == ValueType::USERDATA) ? getStringValue(idx) :
                                  idx.isCollectable() ? valueToKeyString(idx) : idx.toString();
                auto it = cont->container->find(key);
                if (it != cont->container->end()) return it->second;
            }
        }
        // Check for __getitem__ on instances
        if (obj.type == ValueType::USERDATA && obj.value.p && !string_ptrs_.count(obj.value.p) && instance_to_class.count(obj.value.p)) {
            std::vector<Value> call_args = {idx};
            Value result = callMethod(obj, "__getitem__", call_args, ctx);
            if (result.type != ValueType::NONE) return result;
        }
        return NONE_VALUE;
    }

    // ─── RETURN ─────────────────────────────────────────────────────────
    Value evalReturn(node_ptr node, Context* ctx) {
        auto rn = static_pointer_cast<ReturnNode>(node);
        Value val = rn->expr ? evalNode(rn->expr, ctx) : NONE_VALUE;
        throw nython::node::ReturnSignal{val};
    }

    // ─── TRY / EXCEPT ───────────────────────────────────────────────────
    Value evalComprehension(node_ptr node, Context* ctx) {
        auto cn = static_pointer_cast<ComplexNode>(node);
        if (cn->items.size() < 2) return NONE_VALUE;
        // List comprehension: [expr for var in iterable if cond]
        std::string var_name = cn->token().value;
        node_ptr expr_node = cn->items[0];
        node_ptr iter_node = cn->items[1];
        node_ptr filter_node = (cn->items.size() >= 3) ? cn->items[2] : nullptr;

        Value iterable = evalNode(iter_node, ctx);
        auto* result = new Object((Runnable*)runner, "list", Type::LIST);
        int idx = 0;

        if (iterable.isCollectable() && iterable.value.gc) {
            auto* cont = dynamic_cast<Container*>(iterable.value.gc);
            if (cont && cont->container) {
                auto len_it = cont->container->find("__len__");
                int len = (len_it != cont->container->end()) ? (int)bigint_to_i64(len_it->second.value.i) : 0;
                // Check for nested for (items[3] = var2, items[4] = iterable2)
                bool has_nested = (cn->items.size() >= 5 && cn->items[3] && cn->items[4]);
                for (int i = 0; i < len; i++) {
                    auto it = cont->container->find(std::to_string(i));
                    if (it == cont->container->end()) continue;
                    ctx->defineByName(var_name, it->second);
                    if (has_nested) {
                        std::string var2 = cn->items[3]->value();
                        Value iter2 = evalNode(cn->items[4], ctx);
                        if (iter2.isCollectable() && iter2.value.gc) {
                            auto* cont2 = dynamic_cast<Container*>(iter2.value.gc);
                            if (cont2 && cont2->container) {
                                auto li2 = cont2->container->find("__len__");
                                int len2 = (li2 != cont2->container->end()) ? (int)bigint_to_i64(li2->second.value.i) : 0;
                                for (int j = 0; j < len2; j++) {
                                    auto it2 = cont2->container->find(std::to_string(j));
                                    if (it2 == cont2->container->end()) continue;
                                    ctx->defineByName(var2, it2->second);
                                    if (filter_node && cn->items[2]) {
                                        Value fv = evalNode(filter_node, ctx);
                                        if (!isTruthy(fv)) continue;
                                    }
                                    result->set(std::to_string(idx++), evalNode(expr_node, ctx));
                                }
                            }
                        }
                    } else {
                        if (filter_node && cn->items.size() >= 3 && cn->items[2]) {
                            Value fv = evalNode(filter_node, ctx);
                            if (!isTruthy(fv)) continue;
                        }
                        result->set(std::to_string(idx++), evalNode(expr_node, ctx));
                    }
                }
            }
        }
        result->set("__len__", Value(idx));
        return Value((Collectable*)result);
        // =====================================================================

    }

    Value evalTry(node_ptr node, Context* ctx) {
        auto tn = static_pointer_cast<TryNode>(node);
        Value result = NONE_VALUE;

        try {
            result = evalNode(tn->body, ctx);
        }
        catch (nython::node::ReturnSignal& rs) {
            // Return signals: run finally, then re-throw
            if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
            throw;
        }
        catch (std::string& flow) {
            if (flow == "break" || flow == "continue") {
                if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
                throw;
            }
            // Determine exception type and message from tagged "__exc__:TypeName:msg" or plain string
            std::string exc_type, exc_msg;
            if (flow.size() > 7 && flow.substr(0, 7) == "__exc__") {
                // Format: "__exc__:TypeName:message"
                size_t colon1 = flow.find(':', 7);
                if (colon1 != std::string::npos) {
                    size_t colon2 = flow.find(':', colon1 + 1);
                    exc_type = flow.substr(colon1 + 1, colon2 == std::string::npos ? std::string::npos : colon2 - colon1 - 1);
                    exc_msg = colon2 != std::string::npos ? flow.substr(colon2 + 1) : "";
                }
            } else {
                exc_msg = flow;
            }
            // Find a matching except clause: typed or untyped
            for (auto& ec : tn->except_clauses) {
                auto en = static_pointer_cast<ExceptNode>(ec);
                bool has_type = !en->alias.empty();
                std::string type_filter = has_type ? en->name : "";
                std::string err_var = has_type ? en->alias : en->name;
                // Type filter: match exc_type or its parent classes, or generic Exception
                bool matches = type_filter.empty()
                    || exc_type == type_filter
                    || type_filter == "Exception" || type_filter == "BaseException" || type_filter == "Error";
                // Walk inheritance chain for user-defined exception classes
                if (!matches && !exc_type.empty() && !type_filter.empty()) {
                    std::string cur = exc_type;
                    for (int depth = 0; depth < 16 && !cur.empty(); depth++) {
                        auto cbit = class_by_name.find(cur);
                        if (cbit == class_by_name.end()) break;
                        auto pit = class_parent.find(cbit->second);
                        if (pit == class_parent.end()) break;
                        cur = pit->second;
                        if (cur == type_filter) { matches = true; break; }
                    }
                }
                if (!matches) continue;
                if (!err_var.empty()) {
                    // Check if this is a class instance exception: __exc__:Type:__obj__:<ptr>
                    bool bound_instance = false;
                    if (flow.find("__obj__:") != std::string::npos) {
                        size_t obj_pos = flow.find("__obj__:");
                        if (obj_pos != std::string::npos) {
                            uintptr_t ptr_val = 0;
                            std::istringstream iss(flow.substr(obj_pos + 8));
                            iss >> std::hex >> ptr_val;
                            void* inst_ptr = reinterpret_cast<void*>(ptr_val);
                            auto eit = exc_instance_map_.find(inst_ptr);
                            if (eit != exc_instance_map_.end()) {
                                ctx->defineByName(err_var, eit->second);
                                bound_instance = true;
                            }
                        }
                    }
                    if (!bound_instance) ctx->defineByName(err_var, makeStringValue(exc_msg));
                }
                try { result = evalNode(en->body, ctx); }
                catch (nython::node::ReturnSignal&) { if (tn->finally_clause) evalNode(tn->finally_clause, ctx); throw; }
                break;
            }
            if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
            return result;
        }
        catch (std::exception& e) {
            std::string exc_msg = e.what();
            for (auto& ec : tn->except_clauses) {
                auto en = static_pointer_cast<ExceptNode>(ec);
                bool has_type = !en->alias.empty();
                std::string err_var = has_type ? en->alias : en->name;
                if (!err_var.empty()) ctx->defineByName(err_var, makeStringValue(exc_msg));
                try { result = evalNode(en->body, ctx); }
                catch (nython::node::ReturnSignal&) { if (tn->finally_clause) evalNode(tn->finally_clause, ctx); throw; }
                break;
            }
            if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
            return result;
        }
        catch (...) {
            for (auto& ec : tn->except_clauses) {
                auto en = static_pointer_cast<ExceptNode>(ec);
                bool has_type = !en->alias.empty();
                std::string err_var = has_type ? en->alias : en->name;
                if (!err_var.empty()) ctx->defineByName(err_var, makeStringValue("unknown error"));
                try { result = evalNode(en->body, ctx); }
                catch (nython::node::ReturnSignal&) { if (tn->finally_clause) evalNode(tn->finally_clause, ctx); throw; }
                break;
            }
            if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
            return result;
        }

        // No exception: run else clause, then finally
        if (tn->else_clause) result = evalNode(tn->else_clause, ctx);
        if (tn->finally_clause) evalNode(tn->finally_clause, ctx);
        return result;
    }

    Value evalRaise(node_ptr node, Context* ctx) {
        auto rn = static_pointer_cast<RaiseNode>(node);
        if (rn->expr) {
            Value v = evalNode(rn->expr, ctx);
            // Class instance (user-defined exception class)
            if (v.type == ValueType::USERDATA && v.value.p && !string_ptrs_.count(v.value.p)) {
                // Check if it's a class instance
                auto cit = instance_to_class.find(v.value.p);
                if (cit != instance_to_class.end()) {
                    // Get class name from func_names for the instance ("__instance__:ClassName")
                    std::string class_name;
                    auto fn_it = func_names.find(v.value.p);
                    if (fn_it != func_names.end() && fn_it->second.find("__instance__:") == 0)
                        class_name = fn_it->second.substr(13);
                    if (class_name.empty()) {
                        // fallback: search class_by_name
                        for (auto& kv : class_by_name)
                            if (kv.second == cit->second) { class_name = kv.first; break; }
                    }
                    std::ostringstream oss;
                    oss << "__exc__:" << class_name << ":__obj__:" << std::hex << reinterpret_cast<uintptr_t>(v.value.p);
                    exc_instance_map_[v.value.p] = v;
                    throw std::string(oss.str());
                }
                // Check if it's a tagged __exc__ string
                std::string msg = getStringValue(v);
                if (msg.size() > 7 && msg.substr(0, 7) == "__exc__") throw msg;
                throw msg;
            } else if (v.type == ValueType::USERDATA && v.value.p && string_ptrs_.count(v.value.p)) {
                // Plain string raise
                throw getStringValue(v);
            } else if (v.type == ValueType::NONE) {
                throw std::string("Exception");
            } else {
                throw std::string(v.toString());
            }
        }
        throw std::string("Exception");
    }

    Value evalAssert(node_ptr node, Context* ctx) {
        auto an = static_pointer_cast<AssertNode>(node);
        if (!isTruthy(evalNode(an->condition, ctx))) {
            std::string msg;
            if (an->message) {
                Value mv = evalNode(an->message, ctx);
                msg = mv.type == ValueType::USERDATA ? getStringValue(mv) : mv.toString();
            } else {
                msg = "Assertion failed";
            }
            throw std::string("__exc__:AssertionError:" + msg);
        }
        return NONE_VALUE;
    }

    // ─── ENUM ───────────────────────────────────────────────────────────
    // Directory of the file containing this import, with a trailing separator.
    // Tokens carry their source file, so this needs no extra plumbing.
    std::string importerDir(const node_ptr& node) {
        if (!node) return std::string();
        std::string f = node->token().fileName();
        if (f.empty()) return std::string();
        size_t cut = f.find_last_of("/\\");
        if (cut == std::string::npos) return std::string();
        return f.substr(0, cut + 1);
    }

    // Top-level declarations of a module: functions, classes and vars. Used to
    // build an `import ... as` namespace without depending on scope state.
    void collectTopLevelNames(const node_ptr& root, std::set<std::string>& out) {
        if (!root) return;
        for (auto& st : root->statements()) {
            if (!st) continue;
            switch (st->type()) {
                case NodeType::FUNCTION:
                    out.insert(static_pointer_cast<FunctionNode>(st)->name); break;
                case NodeType::CLASS:
                    out.insert(static_pointer_cast<ClassNode>(st)->name); break;
                case NodeType::VARIABLE_DECL:
                    out.insert(static_pointer_cast<VarDeclNode>(st)->name); break;
                default: break;
            }
        }
    }

    // Default members every object inherits. Returns UNDEFINED when the name is
    // not part of the protocol, so the caller can continue its own lookup.
    // If `node` names a type (a bare identifier that is a known type name or a
    // declared class), return that name; otherwise "" so the caller falls back
    // to a value comparison. Only a bare VARIABLE counts: `1 is x` where x
    // holds 1 must still be a value test.
    std::string typeNameOperand(const node_ptr& node, Context* ctx) {
        if (!node || node->type() != NodeType::VARIABLE) return std::string();
        const std::string n = node->token().value;
        if (n.empty()) return std::string();
        static const std::set<std::string> type_names = {
            "int","Integer","integer","float","Float","double","Double",
            "str","String","string","bool","Boolean","boolean",
            "list","List","array","Array","map","Map","dict","Dict",
            "none","None","function","Function","Object","object","any","Any"
        };
        if (type_names.count(n)) return n;
        // A declared class name is a type; a variable holding a value is not.
        if (class_by_name.count(n) && ctx && ctx->getByName(n).type == ValueType::UNDEFINED)
            return n;
        if (class_by_name.count(n)) return n;
        return std::string();
    }

    bool valueIsOfType(Value v, const std::string& want, Context* ctx) {
        // Everything is an Object, so the root always matches. That is the
        // point of having a root at all.
        if (want == "Object" || want == "object" || want == "any" || want == "Any")
            return true;

        switch (v.type) {
            case ValueType::INTEGER:
                return want=="int"||want=="Integer"||want=="integer";
            case ValueType::DOUBLE:
                return want=="float"||want=="Float"||want=="double"||want=="Double";
            case ValueType::BOOLEAN:
                return want=="bool"||want=="Boolean"||want=="boolean";
            case ValueType::NONE:
                return want=="none"||want=="None";
            default: break;
        }

        // Strings, lists, maps and instances are all USERDATA/COLLECTABLE here.
        // Rather than duplicate the logic that tells them apart, ask the same
        // `type` builtin the language exposes — one source of truth, so `is`
        // and `type()` can never disagree.
        std::vector<Value> targs{v};
        std::string actual = getStringValue(callBuiltin("type", targs, ctx));
        if (actual == "string" && (want=="str"||want=="String"||want=="string")) return true;
        if (actual == "list"   && (want=="list"||want=="List"||want=="array"||want=="Array")) return true;
        if (actual == "map"    && (want=="map"||want=="Map"||want=="dict"||want=="Dict")) return true;
        if (actual == "function" && (want=="function"||want=="Function")) return true;
        if (actual == want) return true;

        // Class membership, walking the inheritance chain so
        // `child is Base` holds.
        std::string cur = actual;
        int guard = 0;
        while (!cur.empty() && guard++ < 64) {
            if (cur == want) return true;
            auto cbn = class_by_name.find(cur);
            if (cbn == class_by_name.end()) break;
            auto pit = class_parent.find(cbn->second);
            if (pit == class_parent.end()) break;
            cur = pit->second;
        }
        return false;
    }

    Value objectProtocol(Value obj, const std::string& name,
                         std::vector<Value>& args, Context* ctx) {
        // instance_to_class maps to the class NODE, not to a name; the name
        // comes from func_names, the same route type() uses.
        auto class_of = [&]() -> std::string {
            auto it = instance_to_class.find(obj.value.p);
            if (it == instance_to_class.end()) return std::string("object");
            auto nit = func_names.find(it->second);
            if (nit == func_names.end()) return std::string("object");
            const std::string& n = nit->second;
            if (n.rfind("__class__:", 0) == 0) return n.substr(10);
            return n;
        };

        if (name == "class_name" || name == "type_name")
            return makeStringValue(class_of());
        if (name == "to_string" || name == "str") {
            // getStringValue() renders an instance through func_names, which
            // produces "<function __instance__:Child>" — the internal handle,
            // not a description of the object. Use the same "<Class instance>"
            // form print uses, and honour a user __str__ if the class has one.
            std::vector<Value> noargs;
            Value custom = callMethod(obj, "__str__", noargs, ctx);
            if (custom.type == ValueType::USERDATA && !getStringValue(custom).empty()
                && getStringValue(custom).rfind("<function", 0) != 0)
                return custom;
            return makeStringValue("<" + class_of() + " instance>");
        }
        if (name == "id") {
            // A pointer can exceed what bigint(long long) round-trips through
            // the numeric path; reduce it rather than returning 0.
            unsigned long long raw = (unsigned long long)(size_t)obj.value.p;
            return Value(bigint((long long)(raw & 0x7fffffffULL)));
        }
        if (name == "hash")
            return Value(bigint((long long)std::hash<std::string>{}(getStringValue(obj))));
        if (name == "is_a" || name == "instance_of") {
            if (args.empty()) return Value(false);
            std::string want = getStringValue(args[0]);
            // Walks the inheritance chain, so is_a("Base") is true for a
            // subclass — the whole point of asking.
            // class_parent is keyed by class NODE pointer, not by name, so the
            // chain is walked by looking each name back up in class_by_name.
            std::string cur = class_of();
            int guard = 0;
            while (!cur.empty() && guard++ < 64) {
                if (cur == want) return Value(true);
                auto cbn = class_by_name.find(cur);
                if (cbn == class_by_name.end()) break;
                auto pit = class_parent.find(cbn->second);
                if (pit == class_parent.end()) break;
                cur = pit->second;
            }
            return Value(false);
        }
        if (name == "equals_to" || name == "same_as") {
            if (args.empty()) return Value(false);
            return Value(getStringValue(obj) == getStringValue(args[0]));
        }
        if (name == "fields" || name == "attributes") {
            auto* lst = new Object((Runnable*)runner, "list", Type::LIST);
            int n = 0;
            auto pit = instance_properties.find(obj.value.p);
            if (pit != instance_properties.end() && pit->second)
                pit->second->access_container_shared([&](ContainerType* c) {
                    if (c) for (auto& kv : *c) lst->set(std::to_string(n++), makeStringValue(kv.first));
                });
            lst->set("__len__", Value((int)n));
            return Value((Collectable*)lst);
        }
        return Value();   // UNDEFINED — not part of the protocol
    }

    Value evalImport(node_ptr node, Context* ctx) {
        auto in_node = static_pointer_cast<ImportNode>(node);
        std::string module_name = in_node->module_name;
        // Strip quotes if present
        if (module_name.size() >= 2 && (module_name[0] == '"' || module_name[0] == '\'')) {
            module_name = module_name.substr(1, module_name.size() - 2);
        }

        // Circular import guard.
        //
        // An ALIASED import must still build its namespace even when the module
        // has already been loaded: `import "m"` followed by `import "m" as x`
        // would otherwise return here, and the diff that populates `x` would
        // see nothing new, so the alias exposed only whatever happened to be
        // defined between the two imports. Re-running the module is safe — it
        // is idempotent by construction — and is what makes the alias complete.
        if (imported_modules_.count(module_name) && in_node->alias.empty())
            return NONE_VALUE;
        imported_modules_.insert(module_name);

        // Candidate paths. The importing script's OWN directory was missing, so
        // `import "mylib"` from examples/import2.ny never found
        // examples/mylib.ny sitting beside it — it only ever looked relative to
        // the working directory. A module next to the file that imports it is
        // the most obvious place to look and was the one place not searched.
        std::vector<std::string> paths;
        {
            std::string here = importerDir(node);
            if (!here.empty()) {
                paths.push_back(here + module_name + ".ny");
                paths.push_back(here + module_name);
                paths.push_back(here + "lib/" + module_name + ".ny");
            }
        }
        paths.push_back(module_name + ".ny");
        paths.push_back(module_name);
        paths.push_back("./" + module_name + ".ny");
        paths.push_back("./lib/" + module_name + ".ny");

        // Check builtin modules first
        if (module_name == "string") {
                registerBuiltin("isdigit_str");
                registerBuiltin("isalpha_str");
                return NONE_VALUE;
        }
        if (module_name == "io" || module_name == "fs" || module_name == "file") {
                registerBuiltin("read_file"); registerBuiltin("write_file");
                registerBuiltin("file_exists");
                registerBuiltin("open"); registerBuiltin("file_open");
                registerBuiltin("file_close"); registerBuiltin("fclose");
                registerBuiltin("file_read"); registerBuiltin("fread");
                registerBuiltin("file_write"); registerBuiltin("fwrite");
                registerBuiltin("file_readline"); registerBuiltin("freadline");
                registerBuiltin("file_readlines"); registerBuiltin("readlines");
                registerBuiltin("file_writelines"); registerBuiltin("writelines");
                registerBuiltin("file_append"); registerBuiltin("append_file");
                registerBuiltin("file_size"); registerBuiltin("file_delete");
                registerBuiltin("file_rename"); registerBuiltin("file_copy");
                registerBuiltin("print_to"); registerBuiltin("fprint");
                registerBuiltin("eprint"); registerBuiltin("print_err");
                registerBuiltin("flush"); registerBuiltin("remove_file");
                return NONE_VALUE;
        }
        if (module_name == "shell" || module_name == "sh") {
                registerBuiltin("shell"); registerBuiltin("system"); registerBuiltin("cmd");
                registerBuiltin("ls"); registerBuiltin("cat"); registerBuiltin("pwd");
                registerBuiltin("mkdir"); registerBuiltin("write"); registerBuiltin("exists");
                registerBuiltin("env");
                return NONE_VALUE;
        }
        if (module_name == "nytorch") {
                registerBuiltin("tensor");
                registerBuiltin("tensor_add"); registerBuiltin("tensor_sub");
                registerBuiltin("tensor_mul"); registerBuiltin("tensor_dot");
                registerBuiltin("tensor_sum"); registerBuiltin("tensor_mean");
                registerBuiltin("tensor_max"); registerBuiltin("tensor_min");
                registerBuiltin("tensor_scale"); registerBuiltin("tensor_apply");
                registerBuiltin("relu"); registerBuiltin("sigmoid"); registerBuiltin("tanh_fn");
                registerBuiltin("tanh_act"); registerBuiltin("leaky_relu"); registerBuiltin("softmax"); registerBuiltin("tensor_softmax");
                registerBuiltin("tensor_exp"); registerBuiltin("tensor_log"); registerBuiltin("tensor_sqrt");
                registerBuiltin("tensor_abs"); registerBuiltin("tensor_neg"); registerBuiltin("tensor_pow");
                registerBuiltin("tensor_matmul"); registerBuiltin("matmul");
                registerBuiltin("tensor_transpose"); registerBuiltin("tensor_concat");
                registerBuiltin("tensor_zeros"); registerBuiltin("zeros");
                registerBuiltin("tensor_ones"); registerBuiltin("ones");
                registerBuiltin("tensor_rand"); registerBuiltin("rand_tensor");
                registerBuiltin("tensor_randn"); registerBuiltin("randn_tensor");
                registerBuiltin("exp"); registerBuiltin("tanh"); registerBuiltin("atan2"); registerBuiltin("tensor_cumprod"); registerBuiltin("tensor_sign"); registerBuiltin("logsumexp"); registerBuiltin("tensor_scatter_add"); registerBuiltin("tensor_gather");
        registerBuiltin("http_get"); registerBuiltin("http_post");
        registerBuiltin("load_text"); registerBuiltin("read_text"); registerBuiltin("save_text"); registerBuiltin("write_text"); registerBuiltin("append_text");
        registerBuiltin("path_exists"); registerBuiltin("list_dir");
        // OS builtins (available with import nytorch for lib compatibility)
        registerBuiltin("os_path_join"); registerBuiltin("os_path_basename");
        registerBuiltin("os_path_dirname"); registerBuiltin("os_path_ext");
        registerBuiltin("os_path_abs"); registerBuiltin("os_exists");
        registerBuiltin("os_isfile"); registerBuiltin("os_isdir");
        registerBuiltin("os_mkdir"); registerBuiltin("os_remove");
        registerBuiltin("os_rename"); registerBuiltin("os_listdir");
        registerBuiltin("os_getcwd"); registerBuiltin("os_getenv");
        registerBuiltin("os_setenv"); registerBuiltin("os_exec");
        registerBuiltin("fs_stat"); registerBuiltin("fs_mkdirs");
        registerBuiltin("json_encode"); registerBuiltin("json_decode");
        registerBuiltin("string_split"); registerBuiltin("string_join"); registerBuiltin("string_replace");
        registerBuiltin("string_contains"); registerBuiltin("string_lower"); registerBuiltin("string_upper");
        registerBuiltin("string_strip"); registerBuiltin("string_startswith"); registerBuiltin("string_endswith");
        registerBuiltin("string_format"); registerBuiltin("string_count"); registerBuiltin("string_find");
        registerBuiltin("string_slice"); registerBuiltin("json_stringify");
        registerBuiltin("device_info"); registerBuiltin("time_now"); registerBuiltin("time_ms");
        registerBuiltin("process_exec"); registerBuiltin("env_get");
        registerBuiltin("base64_encode"); registerBuiltin("sha256");
        registerBuiltin("zip_list"); registerBuiltin("zip_extract_text");
        registerBuiltin("html_strip"); registerBuiltin("regex_extract");
        registerBuiltin("tensor_benchmark");
                registerBuiltin("tensor_arange"); registerBuiltin("tensor_linspace");
                registerBuiltin("linspace"); registerBuiltin("logspace");
                registerBuiltin("tensor_median"); registerBuiltin("tensor_cummax"); registerBuiltin("tensor_cummin");
                registerBuiltin("tensor_flip"); registerBuiltin("tensor_roll"); registerBuiltin("tensor_unique");
                registerBuiltin("tensor_abs"); registerBuiltin("tensor_pow"); registerBuiltin("tensor_sqrt");
                registerBuiltin("tensor_matmul"); registerBuiltin("matmul");
                registerBuiltin("mel_filterbank"); registerBuiltin("mfcc");
                registerBuiltin("stft_magnitude"); registerBuiltin("ctc_loss");
                registerBuiltin("softplus"); registerBuiltin("mish");
                registerBuiltin("mse_loss"); registerBuiltin("cross_entropy_loss");
                registerBuiltin("numerical_gradient");
                registerBuiltin("tensor_clip"); registerBuiltin("tensor_clamp");
                registerBuiltin("tensor_argmax"); registerBuiltin("argmax");
                registerBuiltin("tensor_argmin"); registerBuiltin("argmin");
                registerBuiltin("tensor_norm"); registerBuiltin("norm");
                registerBuiltin("tensor_normalize");
                registerBuiltin("tensor_slice"); registerBuiltin("tensor_reshape");
                registerBuiltin("one_hot"); registerBuiltin("binary_cross_entropy");
                registerBuiltin("accuracy");
                registerBuiltin("conv1d"); registerBuiltin("max_pool1d"); registerBuiltin("avg_pool1d");
                registerBuiltin("dropout"); registerBuiltin("embedding"); registerBuiltin("embedding_lookup");
                registerBuiltin("cosine_similarity"); registerBuiltin("cos_sim");
                registerBuiltin("attention"); registerBuiltin("scaled_dot_attention");
                registerBuiltin("batch_norm"); registerBuiltin("batchnorm");
                registerBuiltin("layer_norm"); registerBuiltin("layernorm");
                registerBuiltin("gelu"); registerBuiltin("elu"); registerBuiltin("swish"); registerBuiltin("silu");
                registerBuiltin("tensor_where"); registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_std"); registerBuiltin("tensor_cumsum");
                registerBuiltin("gelu"); registerBuiltin("swish"); registerBuiltin("silu");
                registerBuiltin("elu"); registerBuiltin("tensor_where");
                registerBuiltin("tensor_cumsum"); registerBuiltin("tensor_diff");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_std");
                registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_variance");
                registerBuiltin("tensor_std"); registerBuiltin("tensor_where");
                registerBuiltin("tensor_stack"); registerBuiltin("elu");
                registerBuiltin("gelu"); registerBuiltin("silu"); registerBuiltin("swish");
                registerBuiltin("layer_norm"); registerBuiltin("tensor_cumsum");
                registerBuiltin("tensor_diff"); registerBuiltin("tensor_outer");
                registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("variance");
                registerBuiltin("tensor_std"); registerBuiltin("std_dev");
                registerBuiltin("tensor_where"); registerBuiltin("where");
                registerBuiltin("tensor_stack"); registerBuiltin("tensor_split");
                registerBuiltin("huber_loss");
                registerBuiltin("multi_head_attention");
                registerBuiltin("gelu"); registerBuiltin("silu"); registerBuiltin("swish");
                registerBuiltin("elu"); registerBuiltin("layer_norm");
                // Agent I/O & Network
                registerBuiltin("tensor_save"); registerBuiltin("tensor_load");
                registerBuiltin("model_save");  registerBuiltin("model_load");
                registerBuiltin("kv_set"); registerBuiltin("kv_get");
                registerBuiltin("kv_del"); registerBuiltin("kv_keys"); registerBuiltin("kv_all");
                registerBuiltin("http_post_json"); registerBuiltin("http_get_json");
                registerBuiltin("http_request"); registerBuiltin("http_get"); registerBuiltin("http_post");
                registerBuiltin("agent_broadcast"); registerBuiltin("agent_listen");
                registerBuiltin("agent_send"); registerBuiltin("agent_recv");
                registerBuiltin("tcp_server_create"); registerBuiltin("tcp_accept"); registerBuiltin("tcp_connect");
                registerBuiltin("tcp_send"); registerBuiltin("tcp_recv"); registerBuiltin("tcp_recv_all"); registerBuiltin("tcp_close");
                registerBuiltin("http_respond"); registerBuiltin("http_parse_request");
                registerBuiltin("fs_mkdirs"); registerBuiltin("fs_stat"); registerBuiltin("fs_walk");
                registerBuiltin("path_join"); registerBuiltin("path_basename");
                registerBuiltin("path_dirname"); registerBuiltin("path_ext");
                registerBuiltin("read_bytes"); registerBuiltin("write_bytes");
                registerBuiltin("json_encode"); registerBuiltin("json_decode");
                registerBuiltin("json_stringify"); registerBuiltin("json_parse");
                registerBuiltin("time_now"); registerBuiltin("time_timestamp"); registerBuiltin("time_sleep");
                // File I/O
                registerBuiltin("read_file"); registerBuiltin("write_file");
                registerBuiltin("file_append"); registerBuiltin("append_file");
                registerBuiltin("file_delete"); registerBuiltin("file_exists");
                registerBuiltin("listdir"); registerBuiltin("mkdir");
                registerBuiltin("random_int"); registerBuiltin("random_float"); registerBuiltin("random_choice");
                // Vision 2D, extended tensor, NLP, signal
                registerBuiltin("tensor2d_get"); registerBuiltin("tensor2d_set");
                registerBuiltin("tensor2d_conv"); registerBuiltin("tensor2d_maxpool");
                registerBuiltin("tensor_sort"); registerBuiltin("tensor_topk");
                registerBuiltin("tensor_eye"); registerBuiltin("tensor_diag");
                registerBuiltin("tensor_flatten"); registerBuiltin("tensor_pad");
                registerBuiltin("tensor_dot_product"); registerBuiltin("tensor_cosine_sim");
                registerBuiltin("tensor_corr"); registerBuiltin("tensor_histogram");
                registerBuiltin("tensor_percentile"); registerBuiltin("tensor_zscore");
                registerBuiltin("text_tokenize"); registerBuiltin("text_ngrams");
                registerBuiltin("text_char_ids"); registerBuiltin("text_from_ids");
                registerBuiltin("text_bow");
                registerBuiltin("fft_magnitude"); registerBuiltin("signal_window");
                registerBuiltin("signal_rms"); registerBuiltin("signal_zero_crossings");
                return NONE_VALUE;
        }
        if (module_name == "nytorch_classes") {
                // Load nytorch builtins first (if not already)
                if (!imported_modules_.count("nytorch")) {
                    imported_modules_.insert("nytorch");
                    // Minimal builtin registration for tensor ops
                    registerBuiltin("tensor"); registerBuiltin("tensor_add"); registerBuiltin("tensor_sub");
                    registerBuiltin("tensor_mul"); registerBuiltin("tensor_dot");
                    registerBuiltin("tensor_sum"); registerBuiltin("tensor_mean");
                    registerBuiltin("tensor_zeros"); registerBuiltin("tensor_ones");
                    registerBuiltin("tensor_rand"); registerBuiltin("tensor_randn");
                    registerBuiltin("relu"); registerBuiltin("sigmoid"); registerBuiltin("softmax");
                }
                // Load the class library
                {
                    std::vector<std::string> ny_paths = {"lib/nytorch.ny", "./lib/nytorch.ny"};
                    for (auto& np : ny_paths) {
                        struct stat nst; if (stat(np.c_str(), &nst) == 0) {
                            try {
                                auto nsrc = SourceCode(np); auto nrep = std::make_shared<Reporter>(nsrc);
                                auto nlx = std::make_shared<Lexer>(nsrc); nlx->tokenize();
                                auto npr = std::make_shared<Parser>(nrep.get(), (Runnable*)runner, nlx.get());
                                auto nast = npr->parse();
                                if (nast) { imported_asts.push_back(nast); evalNode(nast, ctx); }
                            } catch (...) {}
                            break;
                        }
                    }
                }
                return NONE_VALUE;
        }
        if (module_name == "agent_net") {
                registerBuiltin("tensor_save"); registerBuiltin("tensor_load");
                registerBuiltin("model_save");  registerBuiltin("model_load");
                registerBuiltin("kv_set"); registerBuiltin("kv_get");
                registerBuiltin("kv_del"); registerBuiltin("kv_keys"); registerBuiltin("kv_all");
                registerBuiltin("http_post_json"); registerBuiltin("http_get_json");
                registerBuiltin("http_request"); registerBuiltin("http_get"); registerBuiltin("http_post");
                registerBuiltin("agent_broadcast"); registerBuiltin("agent_listen");
                registerBuiltin("agent_send"); registerBuiltin("agent_recv");
                registerBuiltin("tcp_server_create"); registerBuiltin("tcp_accept"); registerBuiltin("tcp_connect");
                registerBuiltin("tcp_send"); registerBuiltin("tcp_recv"); registerBuiltin("tcp_recv_all"); registerBuiltin("tcp_close");
                registerBuiltin("http_respond"); registerBuiltin("http_parse_request");
                registerBuiltin("fs_mkdirs"); registerBuiltin("fs_stat"); registerBuiltin("fs_walk");
                registerBuiltin("path_join"); registerBuiltin("path_basename");
                registerBuiltin("path_dirname"); registerBuiltin("path_ext");
                registerBuiltin("read_bytes"); registerBuiltin("write_bytes");
                registerBuiltin("json_encode"); registerBuiltin("json_decode");
                registerBuiltin("json_stringify"); registerBuiltin("json_parse");
                registerBuiltin("time_now"); registerBuiltin("time_timestamp"); registerBuiltin("time_sleep");
                return NONE_VALUE;
        }
        if (module_name == "ai" || module_name == "ml") {
                registerBuiltin("tensor");
                registerBuiltin("tensor_add"); registerBuiltin("tensor_sub");
                registerBuiltin("tensor_mul"); registerBuiltin("tensor_dot");
                registerBuiltin("tensor_sum"); registerBuiltin("tensor_mean");
                registerBuiltin("tensor_max"); registerBuiltin("tensor_min");
                registerBuiltin("tensor_scale"); registerBuiltin("tensor_apply");
                registerBuiltin("relu"); registerBuiltin("sigmoid"); registerBuiltin("tanh_fn");
                registerBuiltin("tanh_act"); registerBuiltin("leaky_relu"); registerBuiltin("softmax"); registerBuiltin("tensor_softmax");
                registerBuiltin("tensor_exp"); registerBuiltin("tensor_log"); registerBuiltin("tensor_sqrt");
                registerBuiltin("tensor_abs"); registerBuiltin("tensor_neg"); registerBuiltin("tensor_pow");
                registerBuiltin("tensor_matmul"); registerBuiltin("matmul");
                registerBuiltin("tensor_transpose"); registerBuiltin("tensor_concat");
                registerBuiltin("tensor_zeros"); registerBuiltin("zeros");
                registerBuiltin("tensor_ones"); registerBuiltin("ones");
                registerBuiltin("tensor_rand"); registerBuiltin("rand_tensor");
                registerBuiltin("tensor_randn"); registerBuiltin("randn_tensor");
                registerBuiltin("exp"); registerBuiltin("tanh"); registerBuiltin("atan2"); registerBuiltin("tensor_cumprod"); registerBuiltin("tensor_sign"); registerBuiltin("logsumexp"); registerBuiltin("tensor_scatter_add"); registerBuiltin("tensor_gather");
                registerBuiltin("tensor_arange"); registerBuiltin("tensor_linspace");
                registerBuiltin("linspace"); registerBuiltin("logspace");
                registerBuiltin("tensor_median"); registerBuiltin("tensor_cummax"); registerBuiltin("tensor_cummin");
                registerBuiltin("tensor_flip"); registerBuiltin("tensor_roll"); registerBuiltin("tensor_unique");
                registerBuiltin("tensor_abs"); registerBuiltin("tensor_pow"); registerBuiltin("tensor_sqrt");
                registerBuiltin("tensor_matmul"); registerBuiltin("matmul");
                registerBuiltin("mel_filterbank"); registerBuiltin("mfcc");
                registerBuiltin("stft_magnitude"); registerBuiltin("ctc_loss");
                registerBuiltin("softplus"); registerBuiltin("mish");
                registerBuiltin("mse_loss"); registerBuiltin("cross_entropy_loss");
                registerBuiltin("numerical_gradient");
                registerBuiltin("tensor_clip"); registerBuiltin("tensor_clamp");
                registerBuiltin("tensor_argmax"); registerBuiltin("argmax");
                registerBuiltin("tensor_argmin"); registerBuiltin("argmin");
                registerBuiltin("tensor_norm"); registerBuiltin("norm");
                registerBuiltin("tensor_normalize");
                registerBuiltin("tensor_slice"); registerBuiltin("tensor_reshape");
                registerBuiltin("one_hot"); registerBuiltin("binary_cross_entropy");
                registerBuiltin("accuracy");
                registerBuiltin("conv1d"); registerBuiltin("max_pool1d"); registerBuiltin("avg_pool1d");
                registerBuiltin("dropout"); registerBuiltin("embedding"); registerBuiltin("embedding_lookup");
                registerBuiltin("cosine_similarity"); registerBuiltin("cos_sim");
                registerBuiltin("attention"); registerBuiltin("scaled_dot_attention");
                registerBuiltin("batch_norm"); registerBuiltin("batchnorm");
                registerBuiltin("layer_norm"); registerBuiltin("layernorm");
                registerBuiltin("gelu"); registerBuiltin("elu"); registerBuiltin("swish"); registerBuiltin("silu");
                registerBuiltin("tensor_where"); registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_std"); registerBuiltin("tensor_cumsum");
                registerBuiltin("gelu"); registerBuiltin("swish"); registerBuiltin("silu");
                registerBuiltin("elu"); registerBuiltin("tensor_where");
                registerBuiltin("tensor_cumsum"); registerBuiltin("tensor_diff");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_std");
                registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("tensor_variance");
                registerBuiltin("tensor_std"); registerBuiltin("tensor_where");
                registerBuiltin("tensor_stack"); registerBuiltin("elu");
                registerBuiltin("gelu"); registerBuiltin("silu"); registerBuiltin("swish");
                registerBuiltin("layer_norm"); registerBuiltin("tensor_cumsum");
                registerBuiltin("tensor_diff"); registerBuiltin("tensor_outer");
                registerBuiltin("huber_loss");
                registerBuiltin("tensor_var"); registerBuiltin("variance");
                registerBuiltin("tensor_std"); registerBuiltin("std_dev");
                registerBuiltin("tensor_where"); registerBuiltin("where");
                registerBuiltin("tensor_stack"); registerBuiltin("tensor_split");
                registerBuiltin("huber_loss");
                registerBuiltin("multi_head_attention");
                registerBuiltin("gelu"); registerBuiltin("silu"); registerBuiltin("swish");
                registerBuiltin("elu"); registerBuiltin("layer_norm");
                registerBuiltin("matrix"); registerBuiltin("mat"); registerBuiltin("mat_mul");
                registerBuiltin("mat_transpose"); registerBuiltin("mat_get"); registerBuiltin("mat_shape");
                registerBuiltin("zeros"); registerBuiltin("ones"); registerBuiltin("random_tensor");
                registerBuiltin("softmax"); registerBuiltin("tensor_softmax"); registerBuiltin("kb_save"); registerBuiltin("kb_load");
                return NONE_VALUE;
        }
        if (module_name == "sys") {
                ctx->defineByName("argv", makeStringValue("nython"));
                ctx->defineByName("platform", makeStringValue("linux"));
                return NONE_VALUE;
        }
        if (module_name == "json") {
                registerBuiltin("json_encode");
                registerBuiltin("json_decode");
                registerBuiltin("json_parse");
                registerBuiltin("json_stringify");
                return NONE_VALUE;
        }
        if (module_name == "time" || module_name == "datetime") {
                registerBuiltin("time_now");
                registerBuiltin("time_clock");
                registerBuiltin("time_sleep");
                registerBuiltin("time_format");
                registerBuiltin("time_timestamp");
                registerBuiltin("time_date");
                registerBuiltin("time_elapsed");
                return NONE_VALUE;
        }
        if (module_name == "random") {
                registerBuiltin("random_int");
                registerBuiltin("random_float");
                registerBuiltin("random_choice");
                registerBuiltin("random_shuffle");
                registerBuiltin("random_seed");
                registerBuiltin("random_range");
                registerBuiltin("random_sample");
                registerBuiltin("randint");
                registerBuiltin("uniform");
                return NONE_VALUE;
        }
        if (module_name == "os" || module_name == "sys") {
                registerBuiltin("os_getenv");
                registerBuiltin("os_setenv");
                registerBuiltin("os_getcwd");
                registerBuiltin("getcwd");
                registerBuiltin("getenv");
                registerBuiltin("system");
                registerBuiltin("shell");
                registerBuiltin("popen");
                registerBuiltin("exec_cmd");
                registerBuiltin("sh");
                registerBuiltin("listdir");
                registerBuiltin("ls");
                registerBuiltin("mkdir");
                registerBuiltin("chdir");
                registerBuiltin("cd");
                registerBuiltin("path_exists");
                registerBuiltin("path_isdir");
                registerBuiltin("path_isfile");
                registerBuiltin("os_listdir");
                registerBuiltin("os_mkdir");
                registerBuiltin("os_remove");
                registerBuiltin("os_rename");
                registerBuiltin("os_exists");
                registerBuiltin("os_isdir");
                registerBuiltin("os_isfile");
                registerBuiltin("os_exec");
                registerBuiltin("os_path_join");
                registerBuiltin("os_path_basename");
                registerBuiltin("os_path_dirname");
                registerBuiltin("os_path_ext");
                registerBuiltin("os_path_abs");
                return NONE_VALUE;
        }
        if (module_name == "regex" || module_name == "re") {
                registerBuiltin("re_match");
                registerBuiltin("re_search");
                registerBuiltin("re_findall");
                registerBuiltin("re_replace");
                registerBuiltin("re_split");
                registerBuiltin("re_test");
                registerBuiltin("regex_match");
                registerBuiltin("regex_replace");
                registerBuiltin("regex_findall");
                registerBuiltin("regex_split");
                registerBuiltin("regex_search");
                registerBuiltin("re_sub");
                return NONE_VALUE;
        }
        if (module_name == "threading" || module_name == "thread") {
                registerBuiltin("thread_create");
                registerBuiltin("thread_sleep");
                registerBuiltin("mutex_create");
                registerBuiltin("mutex_lock");
                registerBuiltin("mutex_unlock");
                registerBuiltin("sleep");
                registerBuiltin("semaphore_create");
                registerBuiltin("semaphore_acquire");
                registerBuiltin("semaphore_release");
                registerBuiltin("atomic_inc");
                registerBuiltin("atomic_dec");
                registerBuiltin("atomic_get");
                return NONE_VALUE;
        }
        if (module_name == "net" || module_name == "http") {
                registerBuiltin("http_get");
                registerBuiltin("http_post");
                registerBuiltin("url_encode");
                registerBuiltin("url_decode");
                registerBuiltin("socket_create");
                registerBuiltin("socket_connect");
                registerBuiltin("socket_send");
                registerBuiltin("socket_recv");
                registerBuiltin("socket_udp"); registerBuiltin("socket_tcp");
                registerBuiltin("socket_sendto"); registerBuiltin("socket_recvfrom");
                registerBuiltin("socket_shutdown"); registerBuiltin("socket_setsockopt");
                registerBuiltin("socket_getpeername"); registerBuiltin("socket_getsockname");
                registerBuiltin("socket_select");
                registerBuiltin("gethostbyname"); registerBuiltin("dns_resolve");
                registerBuiltin("inet_ntoa"); registerBuiltin("inet_aton");
                registerBuiltin("ip_to_string"); registerBuiltin("string_to_ip");
                registerBuiltin("htons"); registerBuiltin("ntohs");
                registerBuiltin("htonl"); registerBuiltin("ntohl");
                registerBuiltin("http_request");
                registerBuiltin("socket_close");
                registerBuiltin("socket_bind");
                registerBuiltin("socket_listen");
                registerBuiltin("socket_accept");
                return NONE_VALUE;
        }
        if (module_name == "crypto" || module_name == "hash") {
                registerBuiltin("hash_sha256");
                registerBuiltin("hash_md5");
                registerBuiltin("base64_encode");
                registerBuiltin("base64_decode");
                registerBuiltin("hex_encode");
                registerBuiltin("hex_decode");
                registerBuiltin("url_encode");
                registerBuiltin("url_decode");
                registerBuiltin("md5");
                registerBuiltin("sha256");
                registerBuiltin("sha512");
                return NONE_VALUE;
        }
        if (module_name == "collections") {
                registerBuiltin("OrderedDict");
                registerBuiltin("Counter");
                registerBuiltin("defaultdict");
                registerBuiltin("deque");
                registerBuiltin("Set");
                return NONE_VALUE;
        }
        if (module_name == "math") {
            // Create a math module object (collectable dict)
            std::vector<Value> no_args;
            Value math_obj = callBuiltin("dict", no_args, ctx);
            if (!math_obj.isCollectable() || !math_obj.value.gc) {
                // Fallback: just register as globals and return none
                ctx->defineByName("PI", Value(3.14159265358979323846));
                ctx->defineByName("E", Value(2.71828182845904523536));
                ctx->defineByName("TAU", Value(6.28318530717958647692));
                registerBuiltin("sqrt"); registerBuiltin("sin"); registerBuiltin("cos");
                registerBuiltin("tan"); registerBuiltin("log"); registerBuiltin("floor"); registerBuiltin("ceil");
                return NONE_VALUE;
            }
            auto* cont = dynamic_cast<Container*>(math_obj.value.gc);
            if (cont && cont->container) {
                (*cont->container)["pi"] = Value(3.14159265358979323846);
                (*cont->container)["e"] = Value(2.71828182845904523536);
                (*cont->container)["tau"] = Value(6.28318530717958647692);
                (*cont->container)["inf"] = Value(std::numeric_limits<double>::infinity());
                (*cont->container)["nan"] = Value(std::numeric_limits<double>::quiet_NaN());
                // Register math function builtins and store them as attributes
                std::vector<std::string> math_fns = {"sqrt","sin","cos","tan","log","log2","log10",
                    "floor","ceil","abs","pow","exp","asin","acos","atan","atan2","hypot",
                    "degrees","radians","trunc","gcd","factorial","comb","perm"};
                for (auto& fn : math_fns) {
                    registerBuiltin(fn);
                    // Get the registered builtin value from global_ctx
                    Value bv = global_ctx->getByName(fn);
                    if (bv.type == ValueType::USERDATA && bv.value.p)
                        (*cont->container)[fn] = bv;
                }
            }
            ctx->defineByName("math", math_obj);
            // Also define pi/e as globals for convenience
            ctx->defineByName("PI", Value(3.14159265358979323846));
            ctx->defineByName("E", Value(2.71828182845904523536));
            return math_obj;
        }


        // ── lib/ module shortcuts ──────────────────────────────────────────────
        if (module_name == "stdlib") {
            std::string p = "lib/stdlib.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "os_lib" || module_name == "oslib") {
            std::string p = "lib/os.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "network_lib" || module_name == "netlib") {
            std::string p = "lib/network.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "sockets") {
            std::string p = "lib/sockets.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "webserver" || module_name == "httpserver") {
            std::string p = "lib/webserver.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "threads" || module_name == "threading_lib") {
            std::string p = "lib/thread.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "clientserver" || module_name == "cs_lib") {
            std::string p = "lib/clientserver.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "gui") {
            std::string p = "lib/gui.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }
        if (module_name == "aiagent" || module_name == "nyxai" || module_name == "nyx") {
            std::string p = "lib/aiagent.ny";
            struct stat st; if (stat(p.c_str(),&st)==0){
                auto src=SourceCode(p); auto rep=std::make_shared<Reporter>(src);
                auto lx=std::make_shared<Lexer>(src); lx->tokenize();
                auto pr=std::make_shared<Parser>(rep.get(),(Runnable*)runner,lx.get());
                auto ast=pr->parse(); if(ast){imported_asts.push_back(ast);evalNode(ast,ctx);}
            } return NONE_VALUE;
        }

                // Search filesystem for module file
        // The importing script's own directory comes FIRST. `import "mylib"`
        // from examples/foo.ny must find examples/mylib.ny sitting beside it;
        // previously every candidate was relative to the working directory, so
        // running the same file from a different cwd changed whether its
        // imports resolved.
        //
        // (Round 53 added this to a list named `paths` further up that is built
        // and never read — the resolver has always used `search_paths`. The fix
        // was real but landed in dead code, which is why it changed nothing.)
        std::vector<std::string> search_paths;
        {
            std::string here = importerDir(node);
            if (!here.empty()) {
                search_paths.push_back(here + module_name + ".ny");
                search_paths.push_back(here + module_name);
                search_paths.push_back(here + "lib/" + module_name + ".ny");
            }
        }
        search_paths.push_back(module_name + ".ny");
        search_paths.push_back(module_name);
        search_paths.push_back("./" + module_name + ".ny");
        search_paths.push_back("./lib/" + module_name + ".ny");
        search_paths.push_back("lib/" + module_name + ".ny");
        search_paths.push_back("lib/" + module_name + "/" + module_name + ".ny");

        std::string filepath;
        for (auto& p : search_paths) {
            struct stat buf;
            if (stat(p.c_str(), &buf) == 0) { filepath = p; break; }
        }
        // A module that cannot be found used to import silently, so every name
        // it would have defined then failed later with no hint that the import
        // was the cause. Name the module and where it was looked for.
        if (filepath.empty()) {
            std::string tried;
            for (size_t i = 0; i < search_paths.size(); ++i) {
                if (i) tried += ", ";
                tried += search_paths[i];
            }
            throw std::string("__exc__:ImportError:cannot find module \"" + module_name
                              + "\" (looked in: " + tried + ")");
        }

        // Read and execute the file
        try {
            auto source = SourceCode(filepath);
            auto reporter = std::make_shared<Reporter>(source);
            auto lex = std::make_shared<Lexer>(source);
            lex->tokenize();
            auto parser = std::make_shared<Parser>(reporter.get(), (Runnable*)runner, lex.get());
            auto ast = parser->parse();
            if (ast) {
                imported_asts.push_back(ast); // keep AST alive

                // `import "x" as m` must bind the module's names under `m`.
                // The parser has always recorded the alias in ImportNode::alias
                // and nothing ever read it, so the alias bound nothing and
                // `m.greet()` returned none with no diagnostic.
                //
                // Names are collected by diffing the scope across the module's
                // execution, so a module needs no cooperation to be aliasable.
                // Context inherits Container, whose access_container() gives the
                // iteration this needs.
                const bool aliased = !in_node->alias.empty() && ctx;

                // Collect the module's OWN top-level names from its AST rather
                // than by diffing scope before and after.
                //
                // The diff approach fails whenever the module has already been
                // loaded — `import "m"` then `import "m" as x` leaves nothing
                // new in scope, so the namespace came out empty. Reading the
                // module's declarations directly is independent of what is
                // already defined, so the alias is complete no matter how many
                // times the module has been imported.
                std::set<std::string> own;
                if (aliased) collectTopLevelNames(ast, own);

                evalNode(ast, ctx);

                if (aliased) {
                    auto* ns = new Object((Runnable*)runner, in_node->alias, Type::MAP);
                    for (const auto& n : own) {
                        Value v = ctx->getByName(n);
                        if (v.type != ValueType::UNDEFINED) ns->set(n, v);
                    }
                    ctx->defineByName(in_node->alias, Value((Collectable*)ns));
                }
            }
        } catch (nython::node::ReturnSignal&) {
            // A bare `return` at module scope is harmless; ignore it.
        } catch (std::string& e) {
            // A thrown Nython exception inside the module: propagate, otherwise
            // the module half-executes and the caller never learns why.
            throw;
        } catch (std::exception& e) {
            // This used to be `catch (...) {}`. A module with a SYNTAX ERROR
            // therefore imported "successfully" and silently: every class in it
            // constructed to none and every method returned none, with no
            // diagnostic anywhere. The failure looked like a broken class rather
            // than a broken file. Report the file and the reason.
            std::cerr << "[Nython] Failed to import \"" << filepath << "\": "
                      << e.what() << "\n";
            throw std::string("__exc__:ImportError:cannot import \"" + filepath
                              + "\": " + e.what());
        }

        return NONE_VALUE;
    }

        Value evalEnum(node_ptr node, Context* ctx) {
        auto en = static_pointer_cast<EnumNode>(node);
        // Create enum as Object with only named members (no numeric keys)
        auto* obj = new Object((Runnable*)runner, en->name, Type::MAP);
        int counter = 0;
        for (auto& item : en->items) {
            auto ei = static_pointer_cast<EnumItemNode>(item);
            Value val = ei->value_node ? evalNode(ei->value_node, ctx) : Value(counter);
            (*obj->container)[ei->name] = val;
            counter++;
        }
        // Store enum name for type() and printing
        (*obj->container)["__name__"] = makeStringValue(en->name);
        (*obj->container)["__type__"] = makeStringValue("enum");
        Value enum_val((Collectable*)obj);
        ctx->defineByName(en->name, enum_val);
        return enum_val;
    }

    Value evalDelete(node_ptr node, Context* ctx) {
        auto dn = static_pointer_cast<DeleteNode>(node);
        if (dn->target->type() == NodeType::VARIABLE) {
            ctx->defineByName(dn->target->value(), UNDEFINED_VALUE);
        } else if (dn->target->type() == NodeType::SUBSCRIPT) {
            // del dict[key] or del list[idx]
            auto sub = static_pointer_cast<SubscriptNode>(dn->target);
            Value obj = evalNode(sub->object, ctx);
            Value idx = evalNode(sub->index, ctx);
            if (obj.isCollectable() && obj.value.gc) {
                auto* cont = dynamic_cast<Container*>(obj.value.gc);
                if (cont && cont->container) {
                    std::string key;
                    if (idx.type == ValueType::INTEGER) key = std::to_string(bigint_to_i64(idx.value.i));
                    else key = getStringValue(idx);
                    cont->container->erase(key);
                    // Update __len__ for lists and reindex
                    auto len_it = cont->container->find("__len__");
                    if (len_it != cont->container->end()) {
                        int64_t old_len = bigint_to_i64(len_it->second.value.i);
                        // If the key was numeric, shift subsequent elements down
                        if (idx.type == ValueType::INTEGER) {
                            int64_t del_idx = bigint_to_i64(idx.value.i);
                            for (int64_t j = del_idx + 1; j < old_len; j++) {
                                std::string src = std::to_string(j);
                                std::string dst = std::to_string(j - 1);
                                auto it2 = cont->container->find(src);
                                if (it2 != cont->container->end()) {
                                    (*cont->container)[dst] = it2->second;
                                    cont->container->erase(src);
                                }
                            }
                        }
                        (*cont->container)["__len__"] = Value(static_cast<int>(old_len - 1));
                    }
                }
            }
        } else if (dn->target->type() == NodeType::ATTRIBUTE) {
            // del obj.attr
            auto attr = static_pointer_cast<AttributeNode>(dn->target);
            Value obj = evalNode(attr->object, ctx);
            if (obj.type == ValueType::USERDATA && obj.value.p) {
                auto pit = instance_properties.find(obj.value.p);
                if (pit != instance_properties.end())
                    pit->second->defineByName(attr->attr, UNDEFINED_VALUE);
            }
        }
        return NONE_VALUE;
    }


    // ── evalMacroCall ─────────────────────────────────────────────────────────
    // Invokes a user-registered Nython macro handler with collected token args.
    Value evalMacroCall(node_ptr node, Context* ctx) {
        auto* mn = static_cast<MacroCallNode*>(node.get());
        auto& reg = nython::DynamicLangRegistry::instance();

        // Look up the MACRO rule for this name
        const nython::DynamicRule* rule = reg.macro_rule_for(mn->macro_name);
        if (!rule || !rule->handler_value) return NONE_VALUE;

        // handler_value points to a heap-allocated Value (the Nython function)
        Value* hv = static_cast<Value*>(rule->handler_value);

        // Build argument list: each token string becomes a Nython string Value
        std::vector<Value> call_args;
        for (auto& s : mn->argv) {
            // Strip __dyntok: prefixes if any
            std::string raw = nython::is_dyntok_value(s) ? nython::decode_dyntok_name(s) : s;
            call_args.push_back(makeStringValue(raw));
        }

        return callFunctionValue(*hv, call_args, ctx);
    }

    // ── evalDynBinop ──────────────────────────────────────────────────────────
    // Evaluates lhs and rhs, then calls the registered handler(lhs, rhs).
    Value evalDynBinop(node_ptr node, Context* ctx) {
        auto* dn = static_cast<DynBinopNode*>(node.get());
        auto& reg = nython::DynamicLangRegistry::instance();

        Value lhs = evalNode(dn->lhs, ctx);
        Value rhs = evalNode(dn->rhs, ctx);

        // Look up INFIX_OP rule (for dynamic keyword operators)
        const nython::DynamicRule* rule = reg.infix_rule_for(dn->op_symbol);
        if (rule && rule->handler_value) {
            Value* hv = static_cast<Value*>(rule->handler_value);
            std::vector<Value> binop_args1 = {lhs, rhs};
            return callFunctionValue(*hv, binop_args1, ctx);
        }

        // Look up dynamic symbol operator
        nython::DynamicOperator* dop = reg.find_operator(dn->op_symbol);
        if (dop && dop->handler_value) {
            Value* hv = static_cast<Value*>(dop->handler_value);
            std::vector<Value> binop_args2 = {lhs, rhs};
            return callFunctionValue(*hv, binop_args2, ctx);
        }

        return NONE_VALUE;
    }

    Value evalWith(node_ptr node, Context* ctx) {
        auto wn = static_pointer_cast<WithNode>(node);
        Value v = evalNode(wn->expr, ctx);
        // Call __enter__ if it exists
        Value ctx_val = v;
        if (v.type == ValueType::USERDATA && v.value.p && !string_ptrs_.count(v.value.p) && instance_to_class.count(v.value.p)) {
            std::vector<Value> no_args;
            Value enter_result = callMethod(v, "__enter__", no_args, ctx);
            if (enter_result.type != ValueType::NONE) ctx_val = enter_result;
        }
        if (!wn->alias.empty()) ctx->defineByName(wn->alias, ctx_val);
        // Execute body, then call __exit__
        Value result = NONE_VALUE;
        try {
            result = evalNode(wn->body, ctx);
        } catch (...) {
            // Call __exit__ even on exception
            if (v.type == ValueType::USERDATA && v.value.p && !string_ptrs_.count(v.value.p) && instance_to_class.count(v.value.p)) {
                std::vector<Value> no_args;
                callMethod(v, "__exit__", no_args, ctx);
            }
            throw;
        }
        // Call __exit__ on normal completion
        if (v.type == ValueType::USERDATA && v.value.p && !string_ptrs_.count(v.value.p) && instance_to_class.count(v.value.p)) {
            std::vector<Value> no_args;
            callMethod(v, "__exit__", no_args, ctx);
        }
        return result;
    }

    Value evalNamespace(node_ptr node, Context* ctx) {
        auto nn = static_pointer_cast<NameSpaceNode>(node);
        Context* ns_ctx = new Context(runner, nn->name, nullptr, nullptr, ctx);
        if (nn->body) evalNode(nn->body, ns_ctx);
        return NONE_VALUE;
    }

    // ─── HELPER ─────────────────────────────────────────────────────────
    bool isTruthy(Value v) {
        if (v.isNone()) return false;
        if (v.type == ValueType::UNDEFINED) return false;
        if (v.type == ValueType::BOOLEAN) return v.value.b;
        if (v.type == ValueType::INTEGER) return bigint_to_i64(v.value.i) != 0;
        if (v.type == ValueType::DOUBLE) return v.value.d != 0.0;
        if (v.type == ValueType::USERDATA) {
            std::string s = getStringValue(v);
            return !s.empty();
        }
        if (v.isCollectable() && v.value.gc) {
            auto* cont = dynamic_cast<Container*>(v.value.gc);
            if (cont && cont->container) {
                auto li = cont->container->find("__len__");
                if (li != cont->container->end()) return bigint_to_i64(li->second.value.i) != 0;
            }
        }
        return true;
    }
};


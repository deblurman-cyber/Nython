#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/lang.cpp
// Runtime language-extension builtins for Nython
// ──────────────────────────────────────────────────────────────────────────────
// Exposes a `lang` namespace of functions so users can define new tokens,
// rewrite rules, macro handlers and operators at runtime — making the
// Nython language itself user-extensible.
//
// Builtin names (called via the executor):
//   lang_define_token(name[, pattern[, category[, description]]])  → int id
//   lang_define_rule(name, kind, trigger, pattern, expansion[, prec]) → int id
//   lang_define_macro(name, trigger, handler_fn)  → int id
//   lang_define_operator(symbol, arity, prec, handler_fn) → int id
//   lang_remove_token(name)    → bool
//   lang_remove_rule(name)     → bool
//   lang_remove_operator(sym)  → bool
//   lang_list_tokens()         → list[dict]
//   lang_list_rules()          → list[dict]
//   lang_list_operators()      → list[dict]
//   lang_registry_json()       → string
//   lang_eval(code)            → value   (apply rewrites, lex, parse, exec)
//   lang_version()             → int
//   lang_reset()               → none
// ──────────────────────────────────────────────────────────────────────────────

#include "platform_compat.hpp"
#include <string>
#include <vector>
#include <map>
#include <sstream>

#include "NythonExecutor.hpp"
#include "DynamicLang.hpp"
#include <utility>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

using namespace std;

// ── Helper: build a Nython dict from string pairs ────────────────────────────
static Value make_str_dict(NythonExecutor& E, const std::vector<std::pair<std::string,std::string>>& kv) {
    auto* obj = new nython::kernel::Object((Runnable*)E.runner, "dict", nython::kernel::Type::MAP);
    for (auto& p : kv) obj->set(p.first, E.makeStringValue(p.second));
    return Value((Collectable*)obj);
}
static Value make_int_dict_entry(NythonExecutor& E, Object* obj, const std::string& key, int val) {
    obj->set(key, Value(val));
    return Value((Collectable*)obj);
}

// ── Helper: store a Value on the heap so the registry can hold a void* ───────
// We use a simple global leak-resistant pool (registry owns them).
static Value* heap_value(const Value& v) {
    return new Value(v);  // registry is permanent; these live forever
}

// ─────────────────────────────────────────────────────────────────────────────
Value dispatch_lang(NythonExecutor& E, const std::string& name,
                    std::vector<Value>& args, Context* ctx)
{
    auto& reg = DynamicLangRegistry::instance();
    auto str  = [&](size_t i, const std::string& def="") -> std::string {
        if (i < args.size()) return E.getStringValue(args[i]);
        return def;
    };
    auto num = [&](size_t i, int def=0) -> int {
        if (i >= args.size()) return def;
        auto& v = args[i];
        if (v.type == ValueType::INTEGER) return (int)bigint_to_i64(v.value.i);
        if (v.type == ValueType::DOUBLE)   return (int)v.value.d;
        return def;
    };

    // ── lang_define_token ──────────────────────────────────────────────────
    if (name == "lang_define_token") {
        // lang_define_token(name[, pattern[, category[, description]]])
        if (args.empty()) return nython::kernel::Value();
        DynamicToken tok;
        tok.name        = str(0);
        tok.pattern     = str(1, "");
        tok.category    = str(2, "keyword");
        tok.description = str(3, "");
        int id = reg.add_token(std::move(tok));
        return Value(id);
    }

    // ── lang_define_rule ──────────────────────────────────────────────────
    // lang_define_rule(name, kind_str, trigger, pattern, expansion[, prec])
    // kind_str: "rewrite" | "macro" | "infix_op" | "prefix_op"
    if (name == "lang_define_rule") {
        if (args.size() < 5) return nython::kernel::Value();
        DynamicRule rule;
        rule.name          = str(0);
        std::string ks     = str(1);
        rule.trigger_token = str(2);
        rule.pattern       = str(3);
        rule.expansion     = str(4);
        rule.precedence    = num(5, 50);

        if      (ks == "rewrite"  ) rule.kind = DynamicRule::Kind::REWRITE;
        else if (ks == "macro"    ) rule.kind = DynamicRule::Kind::MACRO;
        else if (ks == "infix_op" ) rule.kind = DynamicRule::Kind::INFIX_OP;
        else if (ks == "prefix_op") rule.kind = DynamicRule::Kind::PREFIX_OP;
        else                        rule.kind = DynamicRule::Kind::REWRITE;

        int id = reg.add_rule(std::move(rule));
        return Value(id);
    }

    // ── lang_define_macro ─────────────────────────────────────────────────
    // lang_define_macro(name, trigger, handler_fn)
    // handler_fn is called with (token_arg_1, token_arg_2, ...) strings
    if (name == "lang_define_macro") {
        if (args.size() < 3) return nython::kernel::Value();
        DynamicRule rule;
        rule.name          = str(0);
        rule.trigger_token = str(1);
        rule.kind          = DynamicRule::Kind::MACRO;
        rule.handler_value = heap_value(args[2]);
        int id = reg.add_rule(std::move(rule));
        return Value(id);
    }

    // ── lang_define_infix ─────────────────────────────────────────────────
    // lang_define_infix(name, trigger_token, handler_fn[, prec])
    // handler_fn(lhs, rhs) → value
    if (name == "lang_define_infix") {
        if (args.size() < 3) return nython::kernel::Value();
        DynamicRule rule;
        rule.name          = str(0);
        rule.trigger_token = str(1);
        rule.kind          = DynamicRule::Kind::INFIX_OP;
        rule.handler_value = heap_value(args[2]);
        rule.precedence    = num(3, 50);
        int id = reg.add_rule(std::move(rule));
        return Value(id);
    }

    // ── lang_define_prefix ────────────────────────────────────────────────
    // lang_define_prefix(name, trigger_token, handler_fn)
    // handler_fn(operand) → value
    if (name == "lang_define_prefix") {
        if (args.size() < 3) return nython::kernel::Value();
        DynamicRule rule;
        rule.name          = str(0);
        rule.trigger_token = str(1);
        rule.kind          = DynamicRule::Kind::PREFIX_OP;
        rule.handler_value = heap_value(args[2]);
        int id = reg.add_rule(std::move(rule));
        return Value(id);
    }

    // ── lang_define_operator ──────────────────────────────────────────────
    // lang_define_operator(symbol, arity, prec, handler_fn[, desc])
    // arity: "prefix" | "infix" | "postfix"
    if (name == "lang_define_operator") {
        if (args.size() < 4) return nython::kernel::Value();
        DynamicOperator op;
        op.symbol      = str(0);
        std::string ar = str(1);
        op.precedence  = num(2, 50);
        op.handler_value = heap_value(args[3]);
        op.description = str(4, "");
        if      (ar == "prefix" ) op.arity = DynamicOperator::Arity::PREFIX;
        else if (ar == "postfix") op.arity = DynamicOperator::Arity::POSTFIX;
        else                      op.arity = DynamicOperator::Arity::INFIX;
        int id = reg.add_operator(std::move(op));
        return Value(id);
    }

    // ── Remove operations ─────────────────────────────────────────────────
    if (name == "lang_remove_token") {
        return Value(reg.remove_token(str(0)) ? 1 : 0);
    }
    if (name == "lang_remove_rule") {
        return Value(reg.remove_rule(str(0)) ? 1 : 0);
    }
    if (name == "lang_remove_operator") {
        return Value(reg.remove_operator(str(0)) ? 1 : 0);
    }

    // ── Listing operations ────────────────────────────────────────────────
    if (name == "lang_list_tokens") {
        auto* lst = new nython::kernel::Object((Runnable*)E.runner, "list", nython::kernel::Type::LIST);
        int i = 0;
        for (auto& t : reg.tokens()) {
            if (t.name.empty()) continue;
            auto* d = new nython::kernel::Object((Runnable*)E.runner, "dict", nython::kernel::Type::MAP);
            d->set("id",       Value(t.token_id));
            d->set("name",     E.makeStringValue(t.name));
            d->set("pattern",  E.makeStringValue(t.pattern));
            d->set("category", E.makeStringValue(t.category));
            d->set("desc",     E.makeStringValue(t.description));
            lst->set(std::to_string(i++), Value((Collectable*)d));
        }
        lst->set("__len__", Value(i));
        return Value((Collectable*)lst);
    }
    if (name == "lang_list_rules") {
        auto* lst = new nython::kernel::Object((Runnable*)E.runner, "list", nython::kernel::Type::LIST);
        int i = 0;
        const char* kind_names[] = {"rewrite","macro","infix_op","prefix_op"};
        for (auto& r : reg.rules()) {
            auto* d = new nython::kernel::Object((Runnable*)E.runner, "dict", nython::kernel::Type::MAP);
            d->set("name",      E.makeStringValue(r.name));
            d->set("kind",      E.makeStringValue(kind_names[(int)r.kind]));
            d->set("trigger",   E.makeStringValue(r.trigger_token));
            d->set("pattern",   E.makeStringValue(r.pattern));
            d->set("expansion", E.makeStringValue(r.expansion));
            d->set("prec",      Value(r.precedence));
            d->set("has_fn",    Value(r.handler_value ? 1 : 0));
            d->set("desc",      E.makeStringValue(r.description));
            lst->set(std::to_string(i++), Value((Collectable*)d));
        }
        lst->set("__len__", Value(i));
        return Value((Collectable*)lst);
    }
    if (name == "lang_list_operators") {
        auto* lst = new nython::kernel::Object((Runnable*)E.runner, "list", nython::kernel::Type::LIST);
        int i = 0;
        const char* ar_names[] = {"prefix","infix","postfix"};
        for (auto& op : reg.operators()) {
            auto* d = new nython::kernel::Object((Runnable*)E.runner, "dict", nython::kernel::Type::MAP);
            d->set("symbol", E.makeStringValue(op.symbol));
            d->set("arity",  E.makeStringValue(ar_names[(int)op.arity]));
            d->set("prec",   Value(op.precedence));
            d->set("desc",   E.makeStringValue(op.description));
            d->set("has_fn", Value(op.handler_value ? 1 : 0));
            lst->set(std::to_string(i++), Value((Collectable*)d));
        }
        lst->set("__len__", Value(i));
        return Value((Collectable*)lst);
    }

    // ── lang_registry_json ────────────────────────────────────────────────
    if (name == "lang_registry_json") {
        return E.makeStringValue(reg.dump_json());
    }

    // ── lang_version ──────────────────────────────────────────────────────
    if (name == "lang_version") {
        return Value(reg.version());
    }

    // ── lang_reset ────────────────────────────────────────────────────────
    if (name == "lang_reset") {
        reg.reset();
        return nython::kernel::Value();
    }

    // ── lang_eval ─────────────────────────────────────────────────────────
    // Re-lex and re-execute a source string with all REWRITE rules applied.
    // This is how you test your language extensions interactively.
    if (name == "lang_eval") {
        if (args.empty()) return nython::kernel::Value();
        std::string code = E.getStringValue(args[0]);

        // Apply all REWRITE rules before lexing
        code = reg.apply_rewrites(code);
        try {
            auto source   = SourceCode(code);
            auto reporter = std::make_shared<Reporter>(source);
            auto lex      = std::make_shared<Lexer>(source);
            lex->tokenize();
            auto parser = std::make_shared<Parser>(reporter.get(),
                                                   (Runnable*)E.runner, lex.get());
            auto ast = parser->parse();
            if (ast) {
                E.imported_asts.push_back(ast);
                return E.evalNode(ast, ctx);
            }
        } catch (nython::node::ReturnSignal& r) {
            return r.value;
        } catch (...) {}
        return nython::kernel::Value();
    }

    return Value::Undefined();  // not handled here
}
#pragma GCC diagnostic pop

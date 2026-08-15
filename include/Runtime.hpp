#ifndef NYTHON_RUNTIME_HPP
#define NYTHON_RUNTIME_HPP
/*=============================================================================
 * Nython — Runtime.hpp
 * Runtime helpers for AST evaluation: string creation, function objects,
 * built-in functions, and the eval() execution engine.
 *=============================================================================*/
#include "Object.hpp"
#include "Context.hpp"

namespace nython { namespace runtime {

using namespace nython::kernel;
using namespace nython::gc;

// ═══════════════════════════════════════════════════════════════════════════
// NString — A simple string object (Collectable) for the runtime
// ═══════════════════════════════════════════════════════════════════════════
struct NString : public Collectable {
    std::string data;

    NString(const std::string& s) : Collectable(Type::STRING), data(s) {}
    ~NString() override {}

    std::string toString() override { return data; }
    std::string getName() override { return data; }
    bigint length() { return (long int)data.size(); }
    Type getType() override { return Type::STRING; }

    bool operator==(const NString& other) const { return data == other.data; }
};

// ═══════════════════════════════════════════════════════════════════════════
// NFunction — A callable function object wrapping a C++ lambda
// ═══════════════════════════════════════════════════════════════════════════
struct NFunction : public Collectable {
    using FnType = std::function<Value(std::vector<Value>&)>;
    std::string name;
    int arity;
    FnType fn;

    NFunction(const std::string& n, int a, FnType f)
        : Collectable(Type::FUNCTION), name(n), arity(a), fn(f) {}
    ~NFunction() override {}

    std::string toString() override { return "<function " + name + ">"; }
    std::string getName() override { return name; }
    Type getType() override { return Type::FUNCTION; }

    Value call(std::vector<Value> args) {
        return fn(args);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// NList — A list object
// ═══════════════════════════════════════════════════════════════════════════
struct NList : public Collectable {
    std::vector<Value> items;

    NList() : Collectable(Type::LIST), items{} {}
    ~NList() override {}

    std::string toString() override {
        std::string s = "[";
        for (size_t i = 0; i < items.size(); i++) {
            if (i > 0) s += ", ";
            s += items[i].toString();
        }
        return s + "]";
    }
    std::string getName() override { return toString(); }
    Type getType() override { return Type::LIST; }
    bigint length() { return (long int)items.size(); }

    void append(Value v) { items.push_back(v); }
    Value get(int idx) {
        if (idx >= 0 && idx < (int)items.size()) return items[idx];
        return NONE_VALUE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// NMap — A map/dict object
// ═══════════════════════════════════════════════════════════════════════════
struct NMap : public Collectable {
    std::vector<std::pair<Value, Value>> entries;

    NMap() : Collectable(Type::MAP), entries{} {}
    ~NMap() override {}

    std::string toString() override {
        std::string s = "{";
        for (size_t i = 0; i < entries.size(); i++) {
            if (i > 0) s += ", ";
            s += entries[i].first.toString() + ": " + entries[i].second.toString();
        }
        return s + "}";
    }
    Type getType() override { return Type::MAP; }
    bigint length() { return (long int)entries.size(); }

    void set(Value k, Value v) {
        for (auto& e : entries) {
            if (e.first == k) { e.second = v; return; }
        }
        entries.push_back({k, v});
    }
    Value get(Value k) {
        for (auto& e : entries) { if (e.first == k) return e.second; }
        return NONE_VALUE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// NClass — A class blueprint object
// ═══════════════════════════════════════════════════════════════════════════
struct NClass : public Collectable {
    std::string name;
    std::unordered_map<std::string, Value> members;

    NClass(const std::string& n) : Collectable(Type::CLASS), name(n) , members{} {}
    ~NClass() override {}

    std::string toString() override { return "<class " + name + ">"; }
    std::string getName() override { return name; }
    Type getType() override { return Type::CLASS; }
};

// ═══════════════════════════════════════════════════════════════════════════
// Value factory functions (create Values from runtime types)
// ═══════════════════════════════════════════════════════════════════════════
inline Value makeString(const std::string& s) {
    return Value(static_cast<Collectable*>(new NString(s)));
}

inline Value makeFunction(const std::string& name, int arity, NFunction::FnType fn) {
    return Value(static_cast<Collectable*>(new NFunction(name, arity, fn)));
}

inline Value makeList() {
    return Value(static_cast<Collectable*>(new NList()));
}

inline Value makeList(std::vector<Value> items) {
    auto* list = new NList();
    list->items = items;
    return Value(static_cast<Collectable*>(list));
}

inline Value makeMap() {
    return Value(static_cast<Collectable*>(new NMap()));
}

inline Value makeClass(const std::string& name) {
    return Value(static_cast<Collectable*>(new NClass(name)));
}

// ═══════════════════════════════════════════════════════════════════════════
// Built-in functions
// ═══════════════════════════════════════════════════════════════════════════
inline Value builtin_len(std::vector<Value>& args) {
    if (args.empty()) return Value(0);
    Value& v = args[0];
    if (v.isCollectable() && v.value.gc) {
        auto t = v.value.gc->getType();
        if (t == Type::STRING) return Value((int)static_cast<NString*>(v.value.gc)->data.size());
        if (t == Type::LIST) return Value((int)static_cast<NList*>(v.value.gc)->items.size());
        if (t == Type::MAP) return Value((int)static_cast<NMap*>(v.value.gc)->entries.size());
    }
    return Value(0);
}

inline Value builtin_type(std::vector<Value>& args) {
    if (args.empty()) return makeString("none");
    Value& v = args[0];
    switch (v.type) {
        case ValueType::NONE: return makeString("none");
        case ValueType::BOOLEAN: return makeString("bool");
        case ValueType::INTEGER: return makeString("int");
        case ValueType::DOUBLE: return makeString("float");
        case ValueType::COLLECTABLE:
            if (v.value.gc) {
                switch (v.value.gc->getType()) {
                    case Type::STRING: return makeString("string");
                    case Type::LIST: return makeString("list");
                    case Type::MAP: return makeString("map");
                    case Type::FUNCTION: return makeString("function");
                    case Type::CLASS: return makeString("class");
                    default: return makeString("object");
                }
            }
            return makeString("none");
        default: return makeString("unknown");
    }
}

inline Value builtin_str(std::vector<Value>& args) {
    if (args.empty()) return makeString("");
    return makeString(args[0].toString());
}

inline Value builtin_int(std::vector<Value>& args) {
    if (args.empty()) return Value(0);
    Value& v = args[0];
    if (v.isString()) return Value((int)std::stoi(v.toString()));
    return Value((int)v.value.i);
}

inline Value builtin_float(std::vector<Value>& args) {
    if (args.empty()) return Value(0.0);
    Value& v = args[0];
    if (v.isString()) return Value(std::stod(v.toString()));
    return Value((double)v.value.d);
}

inline Value builtin_range(std::vector<Value>& args) {
    auto* list = new NList();
    int64_t start = 0, stop = 0, step = 1;
    if (args.size() == 1) { stop = (int64_t)args[0].value.i; }
    else if (args.size() >= 2) { start = (int64_t)args[0].value.i; stop = (int64_t)args[1].value.i; }
    if (args.size() >= 3) { step = (int64_t)args[2].value.i; if (step == 0) step = 1; }
    if (step > 0) { for (auto i = start; i < stop; i += step) list->items.push_back(Value((int)i)); }
    else { for (auto i = start; i > stop; i += step) list->items.push_back(Value((int)i)); }
    return Value(static_cast<Collectable*>(list));
}

inline Value builtin_abs(std::vector<Value>& args) {
    if (args.empty()) return Value(0);
    if (args[0].type == ValueType::INTEGER) {
        auto v = args[0].value.i; return Value((int)(v < bigint(0) ? bigint(0) - v : v));
    }
    if (args[0].type == ValueType::DOUBLE) return Value(std::abs(args[0].value.d));
    return Value(0);
}

inline Value builtin_max(std::vector<Value>& args) {
    if (args.empty()) return NONE_VALUE;
    Value m = args[0];
    for (size_t i = 1; i < args.size(); i++) {
        if (args[i].value.d > m.value.d || args[i].value.i > m.value.i) m = args[i];
    }
    return m;
}

inline Value builtin_min(std::vector<Value>& args) {
    if (args.empty()) return NONE_VALUE;
    Value m = args[0];
    for (size_t i = 1; i < args.size(); i++) {
        if (args[i].value.d < m.value.d || args[i].value.i < m.value.i) m = args[i];
    }
    return m;
}

inline Value builtin_input(std::vector<Value>& args) {
    if (!args.empty()) std::cout << args[0].toString();
    std::string line;
    std::getline(std::cin, line);
    return makeString(line);
}

// Register all builtins in a context
inline void registerBuiltins(Context* ctx) {
    ctx->defineByName("len",   makeFunction("len", 1, builtin_len));
    ctx->defineByName("type",  makeFunction("type", 1, builtin_type));
    ctx->defineByName("str",   makeFunction("str", 1, builtin_str));
    ctx->defineByName("int",   makeFunction("int", 1, builtin_int));
    ctx->defineByName("float", makeFunction("float", 1, builtin_float));
    ctx->defineByName("range", makeFunction("range", -1, builtin_range));
    ctx->defineByName("abs",   makeFunction("abs", 1, builtin_abs));
    ctx->defineByName("max",   makeFunction("max", -1, builtin_max));
    ctx->defineByName("min",   makeFunction("min", -1, builtin_min));
    ctx->defineByName("input", makeFunction("input", -1, builtin_input));
    // Constants
    ctx->defineByName("true",  Value(true));
    ctx->defineByName("false", Value(false));
    ctx->defineByName("none",  NONE_VALUE);
    ctx->defineByName("None",  NONE_VALUE);
    ctx->defineByName("True",  Value(true));
    ctx->defineByName("False", Value(false));
}

}} // nython::runtime

#endif

#ifndef NYTHON_RUNTIME_HELPER_HPP
#define NYTHON_RUNTIME_HELPER_HPP
/*=============================================================================
 * Nython — RuntimeHelper.hpp
 * Helpers to create runtime Values (strings, lists, maps, functions, classes)
 * from the AST eval() methods using the Runnable (VM/Interpreter) allocator.
 *=============================================================================*/
#include "Value.hpp"
#include "Object.hpp"
#include "Runnable.hpp"
#include "Context.hpp"

namespace nython::runtime {

using kernel::Value;
using kernel::Object;
using kernel::Context;
using kernel::Container;
using kernel::Type;
using kernel::ValueType;
using gc::Collectable;

// Create a string Value
inline Value makeString(Runnable* runner, const std::string& str) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, str, Type::STRING);
    obj->setName(str);
    return Value(static_cast<Collectable*>(obj));
}

// Create a list Value
inline Value makeList(Runnable* runner) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, "list", Type::LIST);
    return Value(static_cast<Collectable*>(obj));
}

// Create a map/dict Value
inline Value makeMap(Runnable* runner) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, "map", Type::MAP);
    return Value(static_cast<Collectable*>(obj));
}

// Create a tuple Value
inline Value makeTuple(Runnable* runner) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, "tuple", Type::TUPLE);
    return Value(static_cast<Collectable*>(obj));
}

// Create an array Value
inline Value makeArray(Runnable* runner) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, "array", Type::ARRAY);
    return Value(static_cast<Collectable*>(obj));
}

// Create a function Value
// We store the function body and params in the Object container
// The function is callable via Object::call
inline Value makeFunction(Runnable* runner, const std::string& name, Type type = Type::FUNCTION) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, name, type);
    return Value(static_cast<Collectable*>(obj));
}

// Create a class Value
inline Value makeClass(Runnable* runner, const std::string& name) {
    if (!runner) return NONE_VALUE;
    auto* obj = new Object(runner, name, Type::CLASS);
    return Value(static_cast<Collectable*>(obj));
}

// Get runner from Context (traverses Collectable hierarchy)
inline Runnable* getRunner(Context* ctx) {
    if (!ctx) return nullptr;
    return ctx->getRunner();
}

// Create a child Context for function/block scope
inline Context* makeChildContext(Context* parent, const std::string& name) {
    if (!parent) return nullptr;
    return parent->makeChildContext(name);
}

// Append a value to a list/array/tuple object
inline void appendToCollection(Value collection, Value item) {
    if (collection.isObject() && collection.value.gc) {
        auto* obj = dynamic_cast<Object*>(collection.value.gc);
        if (obj) {
            int idx = (int)obj->size();
            obj->set(idx, item);
        }
    }
}

// Get length of a collection
inline int64_t getLength(Value val) {
    if (val.isObject() && val.value.gc) {
        auto* obj = dynamic_cast<Object*>(val.value.gc);
        if (obj) return (int64_t)obj->length();
    }
    return 0;
}

// Get item from collection by index
inline Value getItem(Value val, int index) {
    if (val.isObject() && val.value.gc) {
        auto* obj = dynamic_cast<Object*>(val.value.gc);
        if (obj) return obj->get(index);
    }
    return NONE_VALUE;
}

// Create a range list [start, end) with step
inline Value makeRange(Runnable* runner, int64_t start, int64_t end, int64_t step = 1) {
    Value list = makeList(runner);
    if (step > 0) {
        for (int64_t i = start; i < end; i += step) {
            appendToCollection(list, Value((int)i));
        }
    } else if (step < 0) {
        for (int64_t i = start; i > end; i += step) {
            appendToCollection(list, Value((int)i));
        }
    }
    return list;
}

} // namespace nython::runtime
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"

#include "Lexer.hpp"
#include "Except.hpp"
#include "Context.hpp"


using nython::lexer::Token;
using nython::exception::RuntimeError;

/// -pthread -lpthread -Wl,--no-as-needed
namespace nython{
namespace kernel{

Context::Context(Runnable* runner, const std::string& name, Collectable* self, Collectable* klass, Context* parent): Container(runner, Type::CONTEXT), name{name},
self{self}, klass{klass}, parent{parent}, inFunction{},inClass{},inNameSpace{},inBlock{}, inModule{} {
}

Context::~Context(){
}

Context& Context::operator=(Context&& ctx){
    if(this!=&ctx){
        name        = std::move(ctx.name);
        parent      = std::move(ctx.parent);
        self        = std::move(ctx.self);
        klass       = std::move(ctx.klass);
        runner      = std::move(ctx.runner);
        /// are we in a function or in a class or in a name space or in  a block
        inBlock     = std::move(ctx.inBlock);
        inFunction  = std::move(ctx.inFunction);
        inClass     = std::move(ctx.inClass);
        inNameSpace = std::move(ctx.inNameSpace);
        inModule    = std::move(ctx.inModule);
    }
    return *this;
}

Context* Context::makeChildContext(const std::string& name) {
    return new Context(runner, name, self, klass, this);
}

Context& Context::ancestor(int distance) {
    auto context = this;
    for (int i = 0; i < distance; i++) {
        context = context->parent;
    }

    return *context;
}

void Context::set(const Value& name, Value value) {
    if (contains(name)) {
        assign(name, value);
        return;
    }
    if (parent) {
        parent->set(name, value);
        return;
    }
    Token token = name.token;
    throw RuntimeError(token.location(), "Undefined variable \'" + token.value + "\'.");
}

void Context::setAt(int distance, const Value& name, Value value) {
    ancestor(distance).write(name, value);
}

Value Context::get(const Value& name) {
    // try to retrieve the value referred to by name
    bool ok;
    auto value = find(name, &ok);

    // if a value exists, return it
    if (ok) {
        return value->second;
    }

    // if no value has been found yet, recursively look it up in the enclosing scope
    if (parent) {
        return parent->get(name);
    }

    // if it still has not been found, the variable doesn't exist
    Token token = name.token;
    throw RuntimeError(token.location(), "Undefined variable \'" + token.value + "\'.");
}

Value Context::getAt(int distance, const Value& name) {
    Value result;
    ancestor(distance).read(name, &result);
    return result;
}

void Context::define(const Value &name, Value value) {
    assign(name, value);
}

bool Context::has(const Value& name) {
    bool ok;
    find(name, &ok);
    if(!ok && parent) return parent->has(name);
    return ok;
}

bool Context::has(const Value& name,Value* obj) {
    bool ok;
    auto it = find(name, &ok);
    if(ok) *obj = it->second;
    if(!ok && parent) return parent->has(name, obj);
    return ok;
}

Object* Context::getParent() {
    return (Object*)parent;
}

void Context::setParent(Object* parent) {
    this->parent = (Context*)parent;
}


}
}



#pragma GCC diagnostic pop

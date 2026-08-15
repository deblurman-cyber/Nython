#include <memory>

#include <sstream>
#include <exception>
#include <algorithm>

#include "Type.hpp"
#include "Class.hpp"
#include "Object.hpp"
#include "Collectable.hpp"



namespace nython {
namespace gc {

Collectable::Collectable(Type type_arg): type{type_arg}, marked{false}, runner{nullptr} {
}

Collectable::Collectable(Runnable* runner_arg, Type type_arg): type{type_arg}, marked{false}, runner{runner_arg} {
}

Collectable::~Collectable() {
    clean();
}

void Collectable::clean() {
    // do nothing, this method is kept for possible future expansion
}

bool Collectable::equals(Collectable* that) {
    if(this->type!=that->type) return false;
    return this==that;
}

template<typename T>
T* Collectable::as(){
    T* ret = reinterpret_cast<T*>(this);
    if(ret==nullptr) throw std::runtime_error(std::string("Invalid Cast Error on : ").append(toString()));
    return ret;
}

Type Collectable::getType() {
    return type;
}

void Collectable::setType(Type type_arg){
    this->type = type_arg;
}

uint64_t Collectable::id(){
    return reinterpret_cast<uint64_t>(this);
}

std::string Collectable::toString() {
    std::stringstream ret;
    std::hex(ret);
    ret << this;
    return std::string("<collectable at ").append(ret.str()).append(">");
}

std::string Collectable::typeName() {
    return TypeToString(getType());
}

bool Collectable::get_gc_mark() {
  return this->marked;
}

void Collectable::set_gc_mark() {
  this->marked = true;
}

void Collectable::clear_gc_mark() {
  this->marked = false;
}

Object* Collectable::getParent() {
  return static_cast<Object*>(this);
}

Class* Collectable::getClass() {
  return static_cast<Class*>(this);
}

bool Collectable::isClass() {
    return type==Type::CLASS;
}

}
}

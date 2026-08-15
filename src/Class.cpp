#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include <sstream>
#include "Util.hpp"
#include "Class.hpp"
#include "Value.hpp"
#include "Except.hpp"

namespace nython::kernel {

Class::Class(Runnable* runner):Class(runner,"Class"){
}

Class::Class(Runnable* runner, const std::string& name):Class(runner,name,this,this,Modifier.PUBLIC) {
}

Class::Class(Runnable* runner, const std::string& name,Object* super):Class(runner,name,this,super,Modifier.PUBLIC) {
}

Class::Class(Runnable* runner, const std::string& name,int flags):Class(runner,name,this,this,flags) {
}

Class::Class(Runnable* runner, const std::string& name,Object* super,int flags):Class(runner,name,this,super,flags){
}

Class::Class(Runnable* runner, const std::string& name,Class* clazz,Object* super,int flags):Class(runner,name, clazz, super, flags, {})  {
}

Class::Class(Runnable* runner, const std::string& name,Class* clazz,Object* super,int flags, const kernel::ContainerType& fields):Object(runner,name, Type::CLASS, Value(this)),flags{flags},file{(char*)__FILE__},super{(Class*)super} {
    klass = Value(clazz);
    /*if(super!=nullptr && clazz!=nullptr && super!=this && clazz!=this){
		utils::merge(super,container);
		utils::merge(clazz,container);
	}else if(super!=nullptr && super!=this){
		utils::merge(super,container);
	}else if(clazz!=nullptr && clazz!=this){
		utils::merge(clazz,container);
	}*/
}

Class::~Class(){
}

std::string Class::qualifiedName(){
    std::string str;
   /* if(package!=null && package != this){
        str = package->getName();
        str.append(".");
    }
    if(module!=null && module != this){
		str += module->getName();
        str.append(".");
    }
    if(nameSpace!=null && nameSpace != this){
		str += nameSpace->getName();
        str.append(".");
    }  */
    str += getName();
    return str;
}

std::string Class::toString(){
	if(count("__toString__")){
		return ((Object*)container->at("__toString__").value.gc)->call(std::vector<Value>()).toString();
	}
	std::stringstream str;
	str<<"<class '"<<qualifiedName()<<"' at "<<this<<" >";
	return str.str();
}

Object* Class::getParent(){
	return super;
}

void Class::setParent(Object* parent){
	super = (Class*)parent;
	/// utils::merge(clazz,container);
}

void Class::setClass(Class* clazz){
	this->klass = Value(clazz);
	/// utils::merge(clazz,container);
}


bool Class::isMap(){
    return Modifier.isMap(flags);
}

bool Class::isList(){
    return Modifier.isList(flags);
}

bool Class::isEnum(){
    return Modifier.isEnum(flags);
}

bool Class::isTuple(){
    return Modifier.isTuple(flags);
}

bool Class::isFinal(){
    return Modifier.isFinal(flags);
}

bool Class::isArray(){
    return Modifier.isArray(flags);
}

bool Class::isStatic(){
    return Modifier.isStatic(flags);
}

bool Class::isLambda(){
    return Modifier.isLambda(flags);
}

bool Class::isPublic(){
    return Modifier.isPublic(flags);
}

bool Class::isPrivate(){
    return Modifier.isPrivate(flags);
}

bool Class::isMutable(){
    return Modifier.isMutable(flags);
}

bool Class::isFunction(){
    return Modifier.isFunction(flags);
}

bool Class::isAbstract(){
    return Modifier.isAbstract(flags);
}

bool Class::isProtected(){
    return Modifier.isProtected(flags);
}

bool Class::isInterface(){
    return Modifier.isInterface(flags);
}

bool Class::isPrimitive(){
    return Modifier.isPrimitive(flags);
}

bool Class::isImmutable(){
    return Modifier.isImmutable(flags);
}

bool Class::isSynchronized(){
    return Modifier.isSynchronized(flags);
}

Value Class::lookup(const std::string& name){
	auto it = container->find(name);
	if(container->end()!=it) return it->second;
	return NONE_VALUE;
}

Value Class::method(const std::string& name){
    return container->at(name);
}

bool Class::hasMethod(const std::string& name){
    return container->count(name)!=0;
}

Value Class::method(const std::string& name,Value o){
    return Object::method(name,o);
}

Value Class::method(const std::string& name,Object* o){
    return Object::method(name,o);
}

Value Class::property(const std::string& name){
    return Object::property(name);
}

bool Class::hasProperty(const std::string& name){
    return container->count(name)!=0;
}

Value Class::property(const std::string& name,Value o){
	return Object::property(name,o);
}

Value Class::property(const std::string& name,Object* o){
	return Object::property(name,o);
}

bool Class::equals(Value other){
	if(count("__eq__")) {
		return (*container)["__eq__"].toObject()->call(std::vector<Value>({ other })).value.b;
	}
    if(other.value.gc == this) return true;
    return (name == other.toObject()->getName()) && (toString() == other->toString()) && (other.toObject()->container->size()==container->size());
}

bool Class::equals(const Class& other){
	Class* that = (Class*)(&other);
    if(that == this) return true;
    return (name == that->getName()) && (toString() == that->toString()) && (that->container->size()==container->size());
}

bool Class::equals(Class* other){
	if(count("__eq__")){
		return (*container)["__eq__"].toObject()->call(std::vector<Value>({ Value(other) })).value.b;
	}
    if(other == this) return true;
    return (name==other->name)&&(flags==other->flags)&&(toString()==other->toString())&&(container->size()==other->container->size());
}

Value Class::call(std::vector<Value> args){
	if(count("__initialize__")){
		return (*container)["__initialize__"].toObject()->call(args);
	}
	throw new Exception("Class has no suitable constructor!");
}

auto Class::newInstance(const std::string& name) -> Class* {
	return nullptr;
}

auto Class::newSubclass(const std::string& name) -> Class*{
    return nullptr;
}

auto Class::subclass(const std::string& name)-> Class*{
    return newSubclass(name);
}

std::string Class::argTypesAsString(std::vector<Value> argTypes){
    std::string str;
    if(argTypes.size() == 0){
        str = "()";
    }else{
        str = "(" + argTypes[0].toString();
        for(unsigned int i = 1; i < argTypes.size(); i++){
            str += "," + argTypes[i].toString();
        }
        str += ")";
    }
    return str;
}

std::string Class::signatureFor(const std::string& name,std::vector<Value> argTypes){
    std::string signature = name + "(";
    if(argTypes.size() > 0){
        signature += argTypes[0]->toString();
        for(unsigned int i = 1; i < argTypes.size(); i++){
            signature += "," + argTypes[i].toString();
        }
    }
    signature += ")";
    return signature;
}

}


#pragma GCC diagnostic pop

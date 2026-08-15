#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include <sstream>
#include "Util.hpp"
#include "Class.hpp"
#include "Object.hpp"
#include "Context.hpp"
#include <utility>
#include <cstring>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

namespace nython::kernel {

Object::Object(Runnable* runner_arg, const std::string& name_arg, Type type_arg, Value klass_arg, uint32_t initial_capacity): Container(runner_arg, type_arg, initial_capacity), klass{}, name{} {
    this->klass = klass_arg;
    this->name  = name;
}

std::string Object::toString() {
    if(count("__toString__")) {
		return (*container)["__toString__"].toObject()->call(std::vector<Value>()).toString();
	}
    std::stringstream ret;
    std::hex(ret);
    ret << this;
    return std::string("<raw ").append(typeName()).append(" with name `").append(name).append("` at ").append(ret.str()).append(">");
}

void Object::clear(){
	if(hasMethod("__finalize__")){
        call("__finalize__",{});
    }
}

Context* Object::getContext() {
    return context;
}

bool Object::is(Type type){
    return this->type == type;
}

bool Object::is(Value obj){
    /// identity test
    return (Collectable*)obj==this;
}

size_t Object::count(const std::string& name) {
    if(!container) return 0;
	return container->count(name);
}

bigint Object::size(){
	if(count("__size__")) {
		return (*container)["__size__"].toObject()->call(std::vector<Value>()).value.i;
	}
	return (*container).size();
}

bigint Object::length(){
	if(count("__length__")) {
		return (*container)["__length__"].toObject()->call(std::vector<Value>()).value.i;
	}
	return (*container).size();
}

std::string Object::address(){
	return utils::hex(this);
}

uint64_t Object::hash(){
	char* s = (char*)toString().c_str();
	uint64_t hash_ = 5381;
	int c = 0;
	while ((c = *s++)) hash_ = ((hash_ << 5) + hash_) + c;
	return hash_;
}

uint64_t Object::id(){
    return *((uint64_t*)this);
}

void Object::setName(const std::string& name){
	this->name = name;
}

std::string Object::getName(){
	return this->name;
}

Object* Object::getParent(){
	return nullptr;
}

void Object::setParent(Object* parent){
}

Class* Object::getClass(){
	if(klass.value.gc==nullptr) return (Class*)this;
	return (Class*) klass.value.gc;
}

void Object::setClass(Class* clazz){
	klass = Value(clazz);
	utils::merge(clazz,this->container);
}

Value Object::getItem(int index){
	int i = 0;
	for(auto it = container->begin();it!=container->end();it++){
		if(i==index){
			return it->second;
		}
		i++;
	}
	return NONE_VALUE;
}

Value Object::getItem(const std::string& name){
	return (*container)[name];
}

void Object::setItem(int index,Value value){
	int i = 0;
	for(auto it:*container){
		if(i==index){
			it.second = value;
			break;
		}
		i++;
	}
}

void Object::setItem(int index,Object* value){
	setItem(index,Value(value));
}

void Object::setItem(const std::string& name,Value value){
	(*container)[name] = value;
}

void Object::setItem(const std::string& name,Object* value){
	setItem(name,Value(value));
}

std::string Object::shortName(){
    return getName().substr(getName().find_last_of(".")+1);
}

std::string Object::qualifiedName(){
    std::string str;
    /*if(this->package!=nullptr && this->package != this){
        str = this->package->getName();
        str.append(".");
    }
    if(this->module!=nullptr && this->module != this){
		str += this->module->getName();
        str.append(".");
    }
    if(this->nameSpace!=nullptr && this->nameSpace != this){
		str += this->nameSpace->getName();
        str.append(".");
    }             */
    str += getName();
    return str;
}

Object::operator bool(){
	if(count("__bool__")) {
		return (*container)["__bool__"].toObject()->call(std::vector<Value>({Value(this)})).value.b;
	}
    return toString().size()?true:false;
}

Object::operator int(){
    if(count("__int__")) {
		return (*container)["__int__"].toObject()->call(std::vector<Value>({Value(this)})).value.i;
	}
    return atoi(toString().c_str());
}

Object::operator int64_t(){
    if(count("__int__")) {
		return (*container)["__int__"].toObject()->call(std::vector<Value>({Value(this)})).value.i;
	}
    return atoi(toString().c_str());
}

Object::operator bigint(){
    if(count("__int__")) {
		return (*container)["__int__"].toObject()->call(std::vector<Value>({Value(this)})).value.i;
	}
    return atol(toString().c_str());
}

Object::operator float(){
    if(count("__double__")) {
		return (*container)["__double__"].toObject()->call(std::vector<Value>({Value(this)})).value.d;
	}
    return atof(toString().c_str());
}

Object::operator double(){
    if(count("__double__")) {
		return (*container)["__double__"].toObject()->call(std::vector<Value>({Value(this)})).value.d;
	}
    return atof(toString().c_str());
}

Object::operator ldouble(){
    if(count("__double__")) {
		return (*container)["__double__"].toObject()->call(std::vector<Value>({Value(this)})).value.d;
	}
    return atof(toString().c_str());
}

Object::operator char*(){
    if(count("__string__")) {
		return (char*)((*container)["__string__"].toObject()->call(std::vector<Value>({Value(this)})).toString().c_str());
	}
    return (char*)toString().c_str();
}

Object::operator std::string(){
    if(count("__string__")) {
		return (*container)["__string__"].toObject()->call(std::vector<Value>({Value(this)})).toString();
	}
    return toString();
}

Object::operator Object*(){
    if(count("__object__")) {
		return (Object*)((*container)["__object__"].toObject()->call(std::vector<Value>({Value(this)})).value.gc);
	}
    return this;
}

bool Object::instanceOf(Value clazz){
	if(clazz.type!=ValueType::COLLECTABLE) return false;
	if(this->type!=Type::INSTANCE) return false;
    return instanceOf(clazz->toString());
}

bool Object::instanceOf(Object* clazz){
	if(klass.isNull() or this->type!=Type::INSTANCE) return false;
    return instanceOf(clazz->toString());
}

bool Object::instanceOf(const std::string& name){
	if(this->type!=Type::INSTANCE) return false;
	//Instance* instance = (Instance*)this;
    return false;///(instance->ref!=null)&&(instance->ref->toString()==name || instance->ref->shortName()==name || instance->ref->subclassOf(name));
}

bool Object::subclassOf(Value obj){
    if(obj.type!=ValueType::COLLECTABLE) return false;
    return obj.value.gc&&subclassOf(obj->getName());
}

bool Object::subclassOf(Object* obj){
    return obj!=nullptr&&subclassOf(obj->getName());
}

bool Object::subclassOf(const std::string& name){
    if(getClass()==nullptr) return false;
    bool good = (getClass()->shortName()==name)||(getClass()->getName()==name)||(getClass()->toString()==name);
    Object* parent = getClass()->super;
    if(!good && parent!=this && parent!=nullptr && parent!=parent->getParent()){
        while(!good && parent!=this && parent!=nullptr && parent!=parent->getParent()){
            good = good||(parent->shortName()==name)||(parent->getName()==name)||(parent->toString()==name);
            parent = parent->getParent();
        }
        good = parent!=nullptr && (good||(parent->shortName()==name)||(parent->getName()==name)||(parent->toString()==name));
    }else if(!good&&parent!=nullptr){
        good = (parent->shortName()==name)||(parent->getName()==name)||(parent->toString()==name);
    }else good = (this->shortName()==name)||(this->getName()==name)||(this->toString()==name);
    return good;
}

bool Object::parentOf(Object* obj){
    return parentOf(Value(obj));
}

bool Object::parentOf(Value obj){
    if(obj.type!=ValueType::COLLECTABLE) return false;
    if(obj.value.gc==nullptr) return false;
    bool good = false;
    Object* o = (Object*)this;
    if(obj.value.gc==obj->getParent()){
        good = (obj->shortName()==o->getName())||(obj->getName()==o->getName())||(obj->toString()==o->getName())||(obj->toString()==toString());
        return good;
    }
    good = obj->getParent()!=nullptr && ((obj->getParent()->shortName()==o->getName())||(obj->getParent()->getName()==o->getName())||(obj->getParent()->toString()==o->getName())||(obj->getParent()->toString()==toString()));
    if(!good&&obj->getParent()!=this && obj->getParent()!=nullptr) good = parentOf(Value(obj->getParent()));
    return good;
}

bool Object::parentOf(const std::string& name){
    return false;///parentOf(Value(state->getClass(name)));
}

Value Object::property(const std::string& name){
    Value obj = UNDEFINED_VALUE;
    if(container->count(name)){
        obj = (*container)[name];
    }
    Object* p = getParent();
    if((obj==NONE_VALUE || obj==UNDEFINED_VALUE || obj.value.gc==nullptr)&&p!=nullptr&&p!=this&&p->container->size()){
        obj = p->property(name);
    }
    return obj;
}

bool Object::hasProperty(const std::string& name){
    bool ok = container->size()!=0&&container->count(name)!=0;
    Object* p = getParent();
    if(!ok&&p!=nullptr&&p!=this&&p->container->size()){
        ok = getParent()->hasProperty(name);
    }
    return ok;
}

Value Object::property(const std::string& name,Value o){
    /*if(o.isFunction()){
        Function* f = (Function*)o.value.gc;
        f->ref      = (Class*)this;
    }*/
	container->insert(container->end(), std::pair<std::string,Value>(name,o));
    return o;
}

Value Object::property(const std::string& name,Object* o){
    /*if(o.isFunction()){
        Function* f = (Function*)o;
        f->ref      = (Class*)this;
    }*/
	container->insert(container->end(), std::pair<std::string,Value>(name,Value(o)));
    return Value(o);
}

int Object::sizeOf(){
    return sizeof(*this);
}

 Value Object::method(const std::string& name){
	Value obj = NONE_VALUE;
    auto it = container->find(name);
    if(it!=container->end()){
		obj = it->second;
    }
    Object* p = getParent();
	if((obj==NONE_VALUE||obj.value.gc==nullptr)&&p!=nullptr&&p!=this&&p->container->size()){
		obj = getParent()->method(name);
	}
	return obj;
}

bool Object::hasMethod(const std::string& name){
	bool ok = container->size()!=0&&container->count(name)!=0;
	auto p = getParent();
	if(!ok&&p!=nullptr&&p!=this&&p->container->size()){
		ok = getParent()->hasMethod(name);
	}
    return ok;
}

Value Object::method(const std::string& name,Value o){
    /*if(o.isFunction()){
        Function* f = (Function*)o.value.gc;
        f->ref      = (Class*)this;
    }*/
    container->insert(container->end(), std::pair<std::string,Value>(name,o));
    return o;
}

Value Object::method(const std::string& name,Object* o){
    /*if(o.isFunction()){
        Function* f = (Function*)o;
        f->ref      = (Class*)this;
    }*/
    container->insert(container->end(), std::pair<std::string,Value>(name,Value(o)));
    return Value(o);
}

bool Object::has(int key){
    return hasProperty(Value(key).toString());
}

bool Object::has(Value key){
    return hasProperty(key.toString());
}

bool Object::key(Value key){
	bool ok = container->size()!=0&&container->count(key.toString())!=0;
	Object* p = getParent();
	if(!ok&&p!=nullptr&&p!=this&&p->container->size()){
		ok = p->key(key);
	}
    return ok;
}

bool Object::has(const std::string& key){
    return hasProperty(key);
}

bool Object::contains(Value value){
	for(auto child : *container)
		if(value == child.second)
			return true;
	return false;
}

Value Object::operator[](int key){
    return get(key);
}

Value Object::operator[](const char* key){
    return get(key);
}

Value Object::operator[](const std::string& key){
    return get(key);
}

Value Object::operator[](const Value key){
    return get(key);
}

Value Object::get(int key){
    return property(Value(key).toString());
}

Value Object::get(Value key){
    return property(key.toString());
}

Value Object::get(const std::string& key){
    return property(key);
}

Value Object::get(int start,int end){
    return NONE_VALUE;
}

void Object::set(int key,Value value){
	add(key,value);
}

void Object::set(Value key,Value value){
	add(key,value);
}

void Object::set(const std::string& key,Value value){
	add(key,value);
}


void Object::add(int key,Value value){
	add(Value(key),value);
}

void Object::add(Value key,Value value){
	property(key.toString(),value);
}

void Object::add(const std::string& key,Value value){
	property(key,value);
}

bool Object::unset(int key){
    return false;
}

bool Object::unset(Value key){
    return false;
}

bool Object::unset(const std::string& key){
    return false;
}

bool Object::remove(int index){
    return false;
}

void Object::extend(Value item){
}

void Object::append(Value item){
    add(item.toString(),item);
}

void Object::append(Value key,Value value){
    add(key,value);
}

void Object::append(const std::string& key,Value value){
    add(key, value);
}

void Object::prepend(Value item){
}

bool Object::isGenerator(){
    return (type==Type::GENERATOR) or subclassOf(std::string("Generator"));
}

Value Object::operator()(std::vector<Value> args){
    return call(args);
}

Value Object::call(std::vector<Value> args){
	if(args.size()){
		std::string name = args[0].toString();
		auto nargs       = utils::shift(1,args);
		Value m = method(name);
		if(m!=NONE_VALUE and m!=UNDEFINED_VALUE and m.value.gc!=nullptr) return  m->call(nargs);
		else throw new Exception(utils::format("NameError: name '",name,"' is not defined in file ",file(),", line ",line(),", and column ",column(),"\n"));
	}
    return NONE_VALUE;
}

Value Object::call(const std::string& name,std::vector<Value> args){
    Value tmp = ((Class*)klass.toObject())->lookup(name);
    if(tmp.value.gc==nullptr or tmp.isNone() or tmp.isUndefined()){
        throw new Exception(utils::format("NameError: name '",name,"' is not defined in file ",file(),", line ",line(),", and column ",column(),"\n"));
    }
    return tmp->call(args);
}

bool Object::equals(Value object){
    return compare(object)==0;
}

bool Object::equals(Object* object){
    return equals(Value(object));
}

bool Object::same(Value object){
    if(object.type!=ValueType::COLLECTABLE) return false;
    return object.value.gc&&equals(object)&& object->type==this->type && getClass()==object->getClass();
}

bool Object::same(Object* object){
    return same(Value(object));
}

int Object::compare(Value obj){
    return strcmp(toString().c_str(),obj.toString().c_str());
}

int Object::compare(Object* obj){
    return compare(Value(obj));
}

Value Object::operator+(Value value){
    if(!count("__add__")) throw new Exception("Object " + value.toString() + " does not support addition!");
    return (*container)["__add__"]->call(std::vector<Value>({ value }));
}

Value Object::operator-(Value value){
    if(!count("__sub__")) throw new Exception("Object " + value.toString() + " does not support subtraction!");
    return (*container)["__sub__"]->call(std::vector<Value>({ value }));
}

Value Object::operator*(Value value){
    if(!count("__mul__")) throw new Exception("Object " + value.toString() + " does not support multiplication!");
    return (*container)["__mul__"]->call(std::vector<Value>({ value }));
}

Value Object::operator/(Value value){
    if(!count("__div__")) throw new Exception("Object " + value.toString() + " does not support division!");
    return (*container)["__div__"]->call(std::vector<Value>({ value }));
}

Value Object::operator%(Value value){
    if(!count("__mod__")) throw new Exception("Object " + value.toString() + " does not support modulo!");
    return (*container)["__mod__"]->call(std::vector<Value>({ value }));
}

Value Object::operator+=(Value value){
    if(!count("__add_eq__")) throw new Exception("Object " + value.toString() + " does not support adding!");
    return (*container)["__add_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator-=(Value value){
    if(!count("__sub_eq__")) throw new Exception("Object " + value.toString() + " does not support subtraction!");
    return (*container)["__sub_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator*=(Value value){
    if(!count("__mul_eq__")) throw new Exception("Object " + value.toString() + " does not support multiplication!");
    return (*container)["__mul_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator/=(Value value){
    if(!count("__div_eq__")) throw new Exception("Object " + value.toString() + " does not support division!");
    return (*container)["__div_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator%=(Value value){
    if(!count("__mod_eq__")) throw new Exception("Object " + value.toString() + " does not support modulo!");
    return (*container)["__mod_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator&(Value value){
    if(!count("__band__")) throw new Exception("Object " + value.toString() + " does not support binary anding!");
    return (*container)["__band__"]->call(std::vector<Value>({ value }));
}

Value Object::operator|(Value value){
    if(!count("__bor__")) throw new Exception("Object " + value.toString() + " does not support binary oring!");
    return (*container)["__bor__"]->call(std::vector<Value>({ value }));
}

Value Object::operator^(Value value){
    if(!count("__bxor__")) throw new Exception("Object " + value.toString() + " does not support binary xoring!");
    return (*container)["__bxor__"]->call(std::vector<Value>({ value }));
}

Value Object::operator&=(Value value){
    if(!count("__band_eq__")) throw new Exception("Object " + value.toString() + " does not support anding!");
    return (*container)["__band_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator|=(Value value){
    if(!count("__bor_eq__")) throw new Exception("Object " + value.toString() + " does not support oring!");
    return (*container)["__bor_eq__"]->call(std::vector<Value>({ value }));
}

Value Object::operator^=(Value value){
    if(!count("__bxor_eq__")) throw new Exception("Object " + value.toString() + " does not support xoring!");
    return (*container)["__bxor_eq__"]->call(std::vector<Value>({ value }));
}

bool Object::operator==(Value value){
    if(count("__eq__")) return (*container)["__eq__"]->call(std::vector<Value>({ value })).value.b;
    return equals(value);
}

bool Object::operator!=(Value value){
    if(count("__ne__")) return (*container)["__ne__"]->call(std::vector<Value>({ value })).value.b;
    return !equals(value);
}

bool Object::operator>(Value value){
    if(count("__gt__")) return (*container)["__gt__"]->call(std::vector<Value>({ value })).value.b;
    return compare(value)==1;
}

bool Object::operator<(Value value){
    if(count("__lt__")) return (*container)["__let__"]->call(std::vector<Value>({ value })).value.b;
    return compare(value)==-1;
}

bool Object::operator>=(Value value){
    if(count("__ge__")) return (*container)["__ge__"]->call(std::vector<Value>({ value })).value.b;
    return(compare(value)==1)||equals(value);
}

bool Object::operator<=(Value value){
    if(count("__le__")) return (*container)["__le__"]->call(std::vector<Value>({ value })).value.b;
    return(compare(value)==-1)||equals(value);
}

Value Object::operator~(){
    if(!count("__complement__")) throw new Exception("Object " + toString() + " does not support not operation!");
    return (*container)["__complement__"]->call(std::vector<Value>());
}

Value Object::operator!(){
    if(!count("__not__")) throw new Exception("Object " + toString() + " does not support not operation!");
    return (*container)["__not__"]->call(std::vector<Value>());
}

Value Object::__cmp__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__ne__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__lt__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__gt__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__le__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__ge__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__pos__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__neg__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__pre_inc__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__pre_dec__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__post_inc__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__post_dec__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__abs__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__round__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__floor__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__ceil__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__trunc__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__add__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__sub__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__mul__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__div__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rdiv__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__mod__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__pow__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__invert__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__add_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__sub_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__mul_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__div_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rdiv_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__mod_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__pow_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__invert_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__shift__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__lshift__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rshift__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__shift_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rshift_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__lshift_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__divmod__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rdivmod__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__and__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__or__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__xor__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__not__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__and_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__or_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__xor_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__band__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bor__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bxor__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__band_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bor_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bxor_eq__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__int__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__float__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bool__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__cmplex__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__rational__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__bin__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__oct__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__hex__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__index__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__string__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__string__")) return (*container)["__string__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__format__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__format__")) return (*container)["__format__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__hash__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__hash__")) return (*container)["__hash__"]->call(tmp);
    return Value(hash());
}

Value Object::__nonzero__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__nonzero__")) return (*container)["__nonzero__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__dir__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__dir__")) return (*container)["__dir__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__sizeof__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__sizeof__")) return (*container)["__sizeof__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__type__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__type__")) return (*container)["__type__"]->call(tmp);
    String* str = nullptr; ///(String*)data->state->newString(typeName()).object();
    return Value(str);
}

Value Object::__getattr__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__getattr__")) return (*container)["__getattr__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        std::string name = args[0].toString();
        ret = property(name);
    }
    return ret;
}

Value Object::__setattr__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__setattr__")) return (*container)["__setattr__"]->call(tmp);
    if(args.size()>1){
        std::string name = args[0].toString();
        property(name,args[1]);
    }
    return NONE_VALUE;
}

Value Object::__delattr__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__delattr__")) return (*container)["__delattr__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__getitem__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__getitem__")) return (*container)["__getitem__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        std::string name = args[0].toString();
        ret = getItem(name);
    }
    return ret;
}

Value Object::__setitem__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__setitem__")) return (*container)["__setitem__"]->call(tmp);
    if(args.size()>1){
        std::string name = args[0].toString();
        setItem(name,args[1]);
    }
    return NONE_VALUE;
}

Value Object::__delitem__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__delitem__")) return (*container)["__delitem__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__length__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__length__")) return (*container)["__length__"]->call(tmp);
    return Value(length());
}

Value Object::__reverse__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__reverse__")) return (*container)["__reverse__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__has__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__has__")) return (*container)["__has__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        ret = Value(has(args[0].toString()));
    }
    return ret;
}

Value Object::__contains__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__contains__")) return (*container)["__contains__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        ret = Value(contains(args[0]));
    }
    return ret;
}

Value Object::__missing__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__missing__")) return (*container)["__missing__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__all__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__all__")) return (*container)["__all__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__any__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__any__")) return (*container)["__any__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__call__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__call__")) return (*container)["__call__"]->call(tmp);
    return call(args);
}

Value Object::__callable__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__callable__")) return (*container)["__callable__"]->call(tmp);
    return Value(hasMethod("__call__"));
}

Value Object::__chr__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__chr__")) return (*container)["__chr__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__odr__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__odr__")) return (*container)["__odr__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__filter__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__help__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__doc__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__id__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__iterator__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__next__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__list__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__tuple__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__array__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__map__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__funlist__(std::vector<Value> args){
    return NONE_VALUE;
}

Value Object::__file__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__file__")) return (*container)["__file__"]->call(tmp);
    String* str = nullptr;///(String*)data->state->newString(file()).object();
    return Value(str);
}

Value Object::__line__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__line__")) return (*container)["__line__"]->call(tmp);
    return Value(line());
}

Value Object::__column__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__column__")) return (*container)["__column__"]->call(tmp);
    return Value(column());
}

Value Object::__class__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__class__")) return (*container)["__class__"]->call(tmp);
    return Value(klass);
}

Value Object::__module__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__module__")) return (*container)["__module__"]->call(tmp);
    return Value(this->module);
}

Value Object::__package__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__package__")) return (*container)["__package__"]->call(tmp);
    return Value(this->package);
}

Value Object::__context__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__context__")) return (*container)["__context__"]->call(tmp);
    return Value(this->context);
}

Value Object::__namespace__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__namespace__")) return (*container)["__namespace__"]->call(tmp);
    return Value(this->nameSpace);
}

Value Object::__toString__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__toString__")) return (*container)["__toString__"]->call(tmp);
    String* str = nullptr;///(String*)data->state->newString(toString().c_str()).object();
    return Value(str);
}

Value Object::__subclassof__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__subclassof__")) return (*container)["__subclassof__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        ret = Value(subclassOf(args[0]));
    }
    return ret;
}

Value Object::__parentof__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__parentof__")) return (*container)["__parentof__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()){
        ret = Value(parentOf(args[0]));
    }
    return ret;
}

Value Object::__instanceof__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__instanceof__")) return (*container)["__instanceof__"]->call(tmp);
    Value ret = NONE_VALUE;
    if(args.size()) ret = Value(instanceOf(args[0]));
    return ret;
}

Value Object::__super__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__super__")) return (*container)["__super__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__parent__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__parent__")) return (*container)["__parent__"]->call(tmp);
    return Value(getParent());
}

Value Object::__locals__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__locals__")) return (*container)["__locals__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__max__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__max__")) return (*container)["__max__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__min__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__min__")) return (*container)["__min__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__open__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__open__")) return (*container)["__open__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__zip__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__zip__")) return (*container)["__zip__"]->call(tmp);
    return NONE_VALUE;
}

Value Object::__size__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__size__")) return (*container)["__size__"]->call(tmp);
    return Value(size());
}

Value Object::__invoke__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__invoke__")) return (*container)["__invoke__"]->call(tmp);
    return call(args);
}

Value Object::__complement__(std::vector<Value> args){
    std::vector<Value> tmp = {Value(this)};
    tmp = args.size()?args:tmp;
    if(count("__complement__")) return (*container)["__complement__"]->call(tmp);
    return NONE_VALUE;
}

std::ostream& Object::operator<<(std::ostream& os){
    os<<toString();
    return os;
}

std::ostream& operator<<(std::ostream& os,Object& that){
    os<<that.toString();
    return os;
}


}


#pragma GCC diagnostic pop

#include <sstream>
#include "Value.hpp"
#include "Class.hpp"
#include "Except.hpp"
#include "Collectable.hpp"
#include "Collectable.hpp"
#include <functional>
#include <cstring>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.


using nython::gc::Collectable;

namespace nython{
namespace kernel{

Value::Value() : type{ValueType::NONE},value{} {
}

Value::Value(bool b) : type{ValueType::BOOLEAN},value{b} {
}

Value::Value(int num) : Value(bigint(num)) {
}

Value::Value(uint64_t num) : Value(bigint(num)) {
}

Value::Value(long int num) : Value(bigint(num)) {
}

#if defined(__MINGW32__) || defined(__MINGW64__)
Value::Value(long long num) : Value(bigint(num)) {
}
#endif

Value::Value(bigint num) : type{ValueType::INTEGER},value{num} {
}

Value::Value(double num) : Value(ldouble(num)) {
}

Value::Value(long double num) : type{ValueType::DOUBLE},value{num} {
}

Value::Value(Collectable* obj) : type{ValueType::COLLECTABLE},value{obj} {
}

Value::Value(void* p) : type{ValueType::USERDATA},value{p} {
}

Value::Value(const Value& that)
	: access{that.access}, kind{that.kind}, type{that.type},
	  value{that.value}, token{that.token} {
}

Value::~Value(){
}

Value Value::Undefined(){
	Value v;
	///v.value.gc = state->undefinedObject;
	v.type     = ValueType::UNDEFINED;
	return v;
}

Object* Value::operator->() {
	if(value.gc==nullptr) return static_cast<Object*>(getClass());
	else if(!value.gc->isClass()){
        return value.gc->getClass();
	}
	return static_cast<Object*>(value.gc);
}

void Value::SetNone(){
	value.gc = nullptr;
	type     = ValueType::NONE;
}

void Value::SetBoolean(bool b){
	value.b = b;
	type    = ValueType::BOOLEAN;
}

Class* Value::getClass(){
	if(isCollectable()) return value.gc->getClass();
	Class* clazz = nullptr;
	/*switch(type){
		case ValueType::NONE:
			clazz = state->noneObject->data->clazz;
		break;
		case ValueType::DOUBLE:
			clazz = state->getClass("Float");
		break;
		case ValueType::BOOLEAN:
			if(value.b) clazz = state->trueObject->data->clazz;
			else clazz = state->falseObject->data->clazz;
		break;
		case ValueType::INTEGER:
			clazz = state->getClass("Integer");
		break;
		case ValueType::UNDEFINED:
			clazz = state->undefinedObject->data->clazz;
		break;
		default:
		break;
	}    */
	return clazz;
}

Value Value::call(std::vector<Value> args){
	return NONE_VALUE;
}

Value Value::call(const std::string& name,std::vector<Value> args){
	return NONE_VALUE;
}

uint64_t Value::hash() const{
	if(isCollectable() && value.gc) return std::hash<void*>()(value.gc);
	return std::hash<void*>()(value.p);
}

bigint Value::size() const{
	if(isCollectable() && value.gc) return bigint(1);
	bigint val;
	switch(type){
		case ValueType::DOUBLE:
			val = sizeof(value.d);
		break;
		case ValueType::BOOLEAN:
			val = sizeof(value.b);
		break;
		case ValueType::INTEGER:
			val = sizeof(value.i);
		break;
		case ValueType::COLLECTABLE:
		case ValueType::NONE:
			val = sizeof(value.gc);
		break;
		default:
			val = sizeof(value.p);
		break;
	}
	return val;
}

std::string Value::getName() const{
	if(isCollectable()) return value.gc->toString();
	std::string name;
	switch(type){
		case ValueType::NONE:
			name = "none";
		break;
		case ValueType::DOUBLE:
			name = std::to_string(value.d);
		break;
		case ValueType::BOOLEAN:
			if(value.b) name = "true";
			else name = "false";
		break;
		case ValueType::INTEGER:
			name = value.i.toString();
		break;
		default:
		break;
	}
	return name;
}

int Value::sizeOf() const{
	if(isCollectable() && value.gc) return 1;
	int sz = 1;
	switch(type){
		case ValueType::NONE:
			sz = sizeof(Collectable);
		break;
		case ValueType::DOUBLE:
			sz = sizeof(value.d);
		break;
		case ValueType::BOOLEAN:
			sz = sizeof(value.b);
		break;
		case ValueType::INTEGER:
			sz = sizeof(value.i);
		break;
		default:
			sz = sizeof(value.p);
		break;
	}
	return sz;
}

bool Value::isString() const{
	return isCollectable() && value.gc->getType()==Type::STRING;
}

bool Value::isFunction() const{
	return isCollectable() && value.gc->getType()==Type::FUNCTION;
}

bool Value::isPrimitive() const{
	return isCollectable() && value.gc->getType()==Type::NATIVE;
}

bool Value::isMethod() const{
	return isCollectable() && value.gc->getType()==Type::METHOD;
}

bool Value::isClass() const{
	return isCollectable() && value.gc->getType()==Type::CLASS;
}

bool Value::isList() const{
	return isCollectable() && value.gc->getType()==Type::LIST;
}

bool Value::isTuple() const{
	return isCollectable() && value.gc->getType()==Type::TUPLE;
}

bool Value::isArray() const{
	return isCollectable() && value.gc->getType()==Type::ARRAY;
}

bool Value::isSet() const{
	return isCollectable() && value.gc->getType()==Type::SET;
}

bool Value::isMap() const{
	return isCollectable() && value.gc->getType()==Type::MAP;
}

bool Value::isComplex() const{
	return isCollectable() && value.gc->getType()==Type::COMPLEX;
}

bool Value::isRational() const{
	return isCollectable() && value.gc->getType()==Type::RATIONAL;
}

Object* Value::toObject() {
    return static_cast<Object*>(value.gc);
}

static const char* _typeName(Value v){
    if(v.isCollectable()){
        return v.value.gc->typeName().c_str();
	}else switch(v.type){
		case ValueType::NONE: return "none";
		case ValueType::BOOLEAN: return "boolean";
		case ValueType::DOUBLE: return "double";
		case ValueType::INTEGER: return "integer";
		case ValueType::USERDATA:  return "user-data";
		default: return "unknown type";
	}
	return "unknown type";
}


const char* Value::typeName() const{
	return _typeName(*this);
}

template<class T>
inline std::string _format(T value){
    std::stringstream str;
    str<<value;
    return str.str();
}

// Format long double ensuring decimal point is always shown (5.0 not 5)
static std::string format_long_double(long double value) {
    char buf[64];
    if (value == (long long)value && value >= -1e15L && value <= 1e15L) {
        snprintf(buf, sizeof(buf), "%.1Lf", value);
        return std::string(buf);
    }
    // Use up to 15 significant digits, strip trailing zeros after decimal
    snprintf(buf, sizeof(buf), "%.15Lg", value);
    // Check if decimal point present; if not, add .0
    bool has_dot = false;
    for (int i = 0; buf[i]; i++) {
        char c = buf[i];
        if (c == '.' || c == 'e' || c == 'E' || c == 'n' || c == 'i') { has_dot = true; break; }
    }
    if (!has_dot) strncat(buf, ".0", sizeof(buf) - strlen(buf) - 1);
    return std::string(buf);
}
template<>
inline std::string _format<long double>(long double value){ return format_long_double(value); }

std::string Value::format() const{
	switch(type){
		case ValueType::NONE: return "none";
		case ValueType::USERDATA:  return "user-data";
		case ValueType::BOOLEAN: return value.b?"true":"false";
		case ValueType::DOUBLE:  return format_long_double(value.d);
		case ValueType::INTEGER: return _format(value.i);
		case ValueType::COLLECTABLE:  return value.gc->toString();
		case ValueType::UNDEFINED:  return "undefined";
		default: return "unknown";
	}
	return "unknown";
}

std::string _toString(Value* that){
	switch(that->type){
		case ValueType::NONE: return "none";
		case ValueType::USERDATA:  return "user-data";
		case ValueType::BOOLEAN: return that->value.b?"true":"false";
		case ValueType::DOUBLE: return format_long_double(that->value.d);
		case ValueType::INTEGER: return _format(that->value.i);
		case ValueType::UNDEFINED: return "undefined";
		case ValueType::COLLECTABLE:
			if(that->value.gc==nullptr) return "none";
		return that->value.gc->toString();
		default: return "unknown";
	}
	return "unknown";
}

bool Value::equals(const Value& that) const {
	if(type!=that.type){
		if(type==ValueType::DOUBLE&&that.type==ValueType::INTEGER){
			return value.d == static_cast<long double>(that.value.i);
		}else if(that.type==ValueType::DOUBLE&&type==ValueType::INTEGER){
			return that.value.d == static_cast<long double>(value.i);
		}else if(that.type==ValueType::BOOLEAN&&type==ValueType::INTEGER){
			return static_cast<int>(that.value.b) == static_cast<int>(value.i);
		}else if(type==ValueType::BOOLEAN&&that.type==ValueType::INTEGER){
			return static_cast<int>(value.b) == static_cast<int>(that.value.i);
		}else if(type==ValueType::BOOLEAN&&that.type==ValueType::DOUBLE){
			return static_cast<long double>(value.b) == that.value.d;
		}else if(that.type==ValueType::BOOLEAN&&type==ValueType::DOUBLE){
			return that.value.b  == value.d;
		}else if(that.type==ValueType::COLLECTABLE&&type==ValueType::DOUBLE){
			return that.value.gc->toString() == _format(value.d);
		}else if(type==ValueType::COLLECTABLE&&that.type==ValueType::DOUBLE){
			return value.gc->toString() == _format(that.value.d);
		}else if(that.type==ValueType::COLLECTABLE&&type==ValueType::INTEGER){
			return that.value.gc->toString() == _format(value.i);
		}else if(type==ValueType::COLLECTABLE&&that.type==ValueType::INTEGER){
			return value.gc->toString() == _format(that.value.i);
		}else if(that.type==ValueType::COLLECTABLE&&type==ValueType::BOOLEAN){
			return that.value.gc->toString() == _format(value.b);
		}else if(type==ValueType::COLLECTABLE&&that.type==ValueType::BOOLEAN){
			return value.gc->toString() == _format(that.value.b);
		}
	}
	if(type != that.type) return false;
    switch(type){
		case ValueType::NONE:
		case ValueType::BOOLEAN:     return value.b  == that.value.b;
		case ValueType::DOUBLE:      return value.d  == that.value.d;
		case ValueType::INTEGER:     return value.i  == that.value.i;
		case ValueType::USERDATA:    return value.p  == that.value.p;
		case ValueType::UNDEFINED:   return value.gc  == that.value.gc;
		case ValueType::COLLECTABLE: return (value.gc == that.value.gc) or (value.gc!=nullptr && value.gc->equals(that.value.gc));
		default:                     return false;
    }
	return false;
}

std::string Value::toString(){
	return _toString(this);
}

std::string Value::toString() const{
	return _toString(const_cast<Value*>(this));
}

std::ostream& operator<<(std::ostream& os,Value& that){
    os<<that.toString();
    return os;
}

std::ostream& operator<<(std::ostream& os,const Value& that){
    os<<that.toString();
    return os;
}

}
} // namespace nython

namespace std {

uint64_t __hash__(const nython::kernel::Value &t){
	switch(t.type){
		case nython::kernel::ValueType::NONE:
		return std::hash<int>()(0);
		case nython::kernel::ValueType::BOOLEAN:
		return std::hash<bool>()(t.value.b);
		case nython::kernel::ValueType::INTEGER:
		return std::hash<nython::kernel::bigint>()(t.value.i);
		case nython::kernel::ValueType::DOUBLE:
		return std::hash<long double>()(t.value.d);
		case nython::kernel::ValueType::UNDEFINED:
		case nython::kernel::ValueType::COLLECTABLE:
		return std::hash<void*>()(t.value.gc);
		case nython::kernel::ValueType::USERDATA:
		default:
		return std::hash<void*>()(t.value.p);
	}
	return std::hash<int>()(-1);
}

}


// ─── Missing operator implementations ───────────────────────────────────────
namespace nython { namespace kernel {

Value Value::operator+(Value that) {
    if (type == ValueType::INTEGER && that.type == ValueType::INTEGER)
        return Value(value.i + that.value.i);
    if (type == ValueType::DOUBLE || that.type == ValueType::DOUBLE) {
        double l = (type == ValueType::DOUBLE) ? value.d : (double)(long)value.i;
        double r = (that.type == ValueType::DOUBLE) ? that.value.d : (double)(long)that.value.i;
        return Value(l + r);
    }
    if (type == ValueType::BOOLEAN && that.type == ValueType::BOOLEAN)
        return Value(bigint(value.b + that.value.b));
    if (isCollectable() && that.isCollectable())
        return addCollectable(that);
    return NONE_VALUE;
}

Value Value::operator-(Value that) {
    if (type == ValueType::INTEGER && that.type == ValueType::INTEGER)
        return Value(value.i - that.value.i);
    if (type == ValueType::DOUBLE || that.type == ValueType::DOUBLE) {
        double l = (type == ValueType::DOUBLE) ? value.d : (double)(long)value.i;
        double r = (that.type == ValueType::DOUBLE) ? that.value.d : (double)(long)that.value.i;
        return Value(l - r);
    }
    return NONE_VALUE;
}

Value Value::operator*(Value that) {
    if (type == ValueType::INTEGER && that.type == ValueType::INTEGER)
        return Value(value.i * that.value.i);
    if (type == ValueType::DOUBLE || that.type == ValueType::DOUBLE) {
        double l = (type == ValueType::DOUBLE) ? value.d : (double)(long)value.i;
        double r = (that.type == ValueType::DOUBLE) ? that.value.d : (double)(long)that.value.i;
        return Value(l * r);
    }
    return NONE_VALUE;
}

Value Value::operator/(Value that) {
    if (type == ValueType::INTEGER && that.type == ValueType::INTEGER) {
        if (that.value.i == bigint(0)) return NONE_VALUE;
        return Value(value.i / that.value.i);
    }
    if (type == ValueType::DOUBLE || that.type == ValueType::DOUBLE) {
        double l = (type == ValueType::DOUBLE) ? value.d : (double)(long)value.i;
        double r = (that.type == ValueType::DOUBLE) ? that.value.d : (double)(long)that.value.i;
        if (r == 0.0) return NONE_VALUE;
        return Value(l / r);
    }
    return NONE_VALUE;
}

Value Value::operator%(Value that) {
    if (type == ValueType::INTEGER && that.type == ValueType::INTEGER) {
        if (that.value.i == bigint(0)) return NONE_VALUE;
        // Floor-modulo, to stay consistent with floor `//` in this same file:
        // -7 % 3 is 2, not -1. Truncating here broke the identity
        // a == (a // b) * b + a % b for mixed signs.
        bigint r = value.i % that.value.i;
        if (r != bigint(0) && ((r < bigint(0)) != (that.value.i < bigint(0))))
            r = r + that.value.i;
        return Value(r);
    }
    return NONE_VALUE;
}

Value Value::operator~(void) {
    if (type == ValueType::INTEGER)
        return Value(bigint(~value.i));
    if (type == ValueType::BOOLEAN)
        return Value(!value.b);
    return NONE_VALUE;
}

// Add/Sub/Mul/Div/Mod dispatch methods
Value Value::addNone(Value that) { return that; }
Value Value::addBoolean(Value that) { return Value(bigint(value.b + (that.type==ValueType::BOOLEAN ? that.value.b : 0))); }
Value Value::addInteger(Value that) { return *this + that; }
Value Value::addDouble(Value that) { return *this + that; }
Value Value::addCollectable(Value that) { return NONE_VALUE; }

Value Value::remNone(Value that) { return NONE_VALUE; }
Value Value::remBoolean(Value that) { return NONE_VALUE; }
Value Value::remInteger(Value that) { return *this - that; }
Value Value::remDouble(Value that) { return *this - that; }
Value Value::remCollectable(Value that) { return NONE_VALUE; }

Value Value::mulNone(Value that) { return NONE_VALUE; }
Value Value::mulBoolean(Value that) { return NONE_VALUE; }
Value Value::mulInteger(Value that) { return *this * that; }
Value Value::mulDouble(Value that) { return *this * that; }
Value Value::mulCollectable(Value that) { return NONE_VALUE; }

Value Value::divNone(Value that) { return NONE_VALUE; }
Value Value::divBoolean(Value that) { return NONE_VALUE; }
Value Value::divInteger(Value that) { return *this / that; }
Value Value::divDouble(Value that) { return *this / that; }
Value Value::divCollectable(Value that) { return NONE_VALUE; }

Value Value::modNone(Value that) { return NONE_VALUE; }
Value Value::modBoolean(Value that) { return NONE_VALUE; }
Value Value::modInteger(Value that) { return *this % that; }
Value Value::modDouble(Value that) { return NONE_VALUE; }
Value Value::modCollectable(Value that) { return NONE_VALUE; }

Value Value::comBoolean() { return Value(!value.b); }
Value Value::comInteger() { return ~(*this); }
Value Value::comDouble() { return NONE_VALUE; }
Value Value::comCollectable() { return NONE_VALUE; }


bool Value::isEnum() const {
    if (!isCollectable() || !value.gc) return false;
    return false; // simplified - enums handled at AST level
}

bool Value::isInterface() const {
    return false; // not yet implemented
}

bool Value::isLambda() const {
    return false; // lambdas tracked at AST level
}


}}

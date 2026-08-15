#ifndef __VALUE__HPP
#define __VALUE__HPP

#include <vector>
#include <memory>
#include "Type.hpp"
#include "Token.hpp"
#include "bigint.hpp"
#include "Modifier.hpp"
#include "Collectable.hpp"

#define NONE_VALUE  	((Value()))
#define TRUE_VALUE  	((Value(true)))
#define FALSE_VALUE 	((Value(false)))
#define UNDEFINED_VALUE ((Value::Undefined()))


#ifndef __ldouble__
#define __ldouble__
typedef long double ldouble;
#endif // __ldouble__

namespace nython {
namespace interpreter {
struct Interpreter;
}

namespace vm {
struct VirtualMachine;
}
struct Runnable;
}

using nython::Runnable;
using nython::lexer::Token;
using nython::vm::VirtualMachine;
using nython::interpreter::Interpreter;

namespace nython{
namespace gc {
class Collectable;
}

using gc::Collectable;

namespace kernel{

struct Object;
struct Class;
struct Value;

/*
** Type for C functions registered with Nool
*/
#ifndef __cfunction__
#define __cfunction__
typedef Value (*CFunction) (Runnable* runner, std::vector<Value>& args);
#endif //__cfunction__


/*
** Union of all Nool Values
*/
typedef struct TValue {

	Collectable* gc = nullptr;  /* collectable object */
	void* p = nullptr;          /* light user data */
	bool b = false;             /* boolean */
	bigint i{};                 /* integer numbers */
	long double d = 0.0L;       /* float numbers */

	TValue() = default;

	explicit TValue(bool b_) : b{b_} {}
	explicit TValue(int i_) : i{i_} {}
	explicit TValue(bigint i_) : i{std::move(i_)} {}
	explicit TValue(uint64_t i_) : i{i_} {}
	explicit TValue(long int i_) : i{i_} {}
#if defined(__MINGW32__) || defined(__MINGW64__)
	explicit TValue(long long i_) : i{i_} {}
#endif
	explicit TValue(double d_) : d{static_cast<long double>(d_)} {}
	explicit TValue(long double d_) : d{d_} {}
	explicit TValue(void* p_) : p{p_} {}
	explicit TValue(Collectable* gc_) : gc{gc_} {}

	TValue(const TValue& that) = default;
	TValue(TValue&& that) noexcept = default;
	~TValue() = default;

	TValue& operator=(const TValue& that) = default;
	TValue& operator=(TValue&& that) noexcept = default;

} TValue;

enum class ValueType: uint8_t  {
    // Types which are immediate encoded using nan-boxing
    NONE,
    BOOLEAN,
    INTEGER,
    DOUBLE,
    UNDEFINED,
    // Types which are allocated on the heap
    COLLECTABLE,
    // This should never appear anywhere
    USERDATA
};

enum class ValueKind: uint8_t  {
    _CONST,
    VAR,
    LET
};


struct Value {

    int  access = 0;
    ValueKind kind = ValueKind::VAR;
	ValueType type = ValueType::NONE;
	TValue    value{};
	Token     token{};

	explicit Value();
	explicit Value(bool b);
	explicit Value(int num);
	explicit Value(bigint num);
	explicit Value(uint64_t num);
	explicit Value(long int num);
#if defined(__MINGW32__) || defined(__MINGW64__)
	explicit Value(long long num);
#endif
	explicit Value(double num);
	explicit Value(long double num);
	explicit Value(Collectable* c);
	explicit Value(void* p);
	Value(const Value& that);
	~Value();

	Value& operator=(const Value& that) {
		if (this != &that) {
			type   = that.type;
			value  = that.value;
			access = that.access;
			kind   = that.kind;
			token  = that.token;
		}
		return *this;
	}

	// Move constructor
	Value(Value&& that) noexcept
		: access{that.access}, kind{that.kind}, type{that.type},
		  value{std::move(that.value)}, token{std::move(that.token)} {}

	// Move assignment
	Value& operator=(Value&& that) noexcept {
		if (this != &that) {
			type   = that.type;
			value  = std::move(that.value);
			access = that.access;
			kind   = that.kind;
			token  = std::move(that.token);
		}
		return *this;
	}

	void SetNone();
	void SetBoolean(bool b);
	void SetModifier(int mod);
	void SetValueKind(ValueKind kind);

	bool isNone() const {
		return is(ValueType::NONE);
	}

	bool isFalse() const {
		return isNone() || (isBoolean() && !value.b);
	}

	bool isTrue() const {
		return isBoolean() && value.b;
	}

	bool isBoolean() const {
		return is(ValueType::BOOLEAN);
	}

	bool isCollectable() const {
		return is(ValueType::COLLECTABLE) || value.gc != nullptr;
	}

	bool isObject() const {
        return isCollectable();
	}

	bool isUserData() const {
		return is(ValueType::USERDATA);
	}

	bool isFloat() const {
		return is(ValueType::DOUBLE);
	}

	bool isDouble() const {
		return is(ValueType::DOUBLE);
	}

	bool isNull() const {
        return is(ValueType::COLLECTABLE) && value.gc==nullptr;
	}

	bool isInteger() const {
		return is(ValueType::INTEGER);
	}

	bool isLiteral() const {
		return isNumber() || isBoolean() || isString() || isNone();
	}

	bool isNumber() const {
        return isInteger() or isDouble();
	}

	bool isUndefined() const {
        return is(ValueType::UNDEFINED);
	}

	bool isVariable() const {
        return is(ValueKind::VAR);
	}

	bool isConstant() const {
        return is(ValueKind::_CONST);
	}

	bool isLet() const {
        return is(ValueKind::LET);
	}

	bool isPublic() const {
        return Modifier.isPublic(access);
    }

    bool isPrivate() const {
        return Modifier.isPrivate(access);
    }

    bool isProtected() const {
        return Modifier.isProtected(access);
    }

    bool isAbstract() const {
        return Modifier.isAbstract(access);
    }

    bool isStatic() const {
        return Modifier.isStatic(access);
    }

    bool isFinal() const {
        return Modifier.isFinal(access) || isConstant();
    }

    bool isSynchronized() const {
        return Modifier.isSynchronized(access);
    }

    bool isRef() const {
        return Modifier.isRef(access);
    }

    bool isImmutable() const {
        return Modifier.isImmutable(access);
    }

    bool isMutable() const {
        return Modifier.isMutable(access);
    }

    bool isVarArgs() const {
        return Modifier.isVarArgs(access);
    }

    bool isAnnotation() const {
      return Modifier.isAnnotation(access);
    }

    static int classModifiers() {
        return Modifier.classModifiers();
    }

    static int accessModifiers() {
        return Modifier.accessModifiers();
    }

    static int interfaceModifiers() {
        return Modifier.interfaceModifiers();
    }

    static int constructorModifiers() {
        return Modifier.constructorModifiers();
    }

    static int methodModifiers() {
        return Modifier.methodModifiers();
    }

    static int functionModifiers() {
        return Modifier.functionModifiers();
    }

    static int fieldModifiers() {
        return Modifier.fieldModifiers();
    }

    static int parameterModifiers() {
        return Modifier.parameterModifiers();
    }

    static Value Undefined();

    bool isEnum() const;
	bool isString() const;
	bool isFunction() const;
	bool isPrimitive() const;
	bool isInterface() const;
	bool isLambda() const;
	bool isClass() const;
	bool isList() const;
	bool isTuple() const;
	bool isArray() const;
	bool isSet() const;
	bool isMap() const;
	bool isComplex() const;
	bool isRational() const;
	bool isMethod() const;

	bool is(ValueType t) const {
		return this->type == t;
	}

	bool is(ValueKind k) const {
		return this->kind == k;
	}

	Object* operator->();

	Object* toObject();

	template<typename T>
	T* as();

	uint64_t id() const{
        return reinterpret_cast<int64_t>(this);
	}

	bool operator < (const Value& that) const {
        return id() < that.id();
	}

	bool operator > (const Value& that) const {
        return id() > that.id();
	}

	bool operator <= (const Value& that) const {
        return id() <= that.id();
	}

	bool operator >= (const Value& that) const {
        return id() >= that.id();
	}

	// C++20: removed friend comparison operator

	// C++20: removed friend comparison operator

	// C++20: removed friend comparison operator

	// C++20: removed friend comparison operator

	explicit operator Collectable*() const {
		return value.gc;
	}

	explicit operator std::string() const {
		return toString();
	}

	explicit operator bool() const {
		return toString().size()?true:false;
	}

    explicit operator int() const {
    	if(isInteger()){
			return static_cast<int>(value.i);
    	}
    	if(isDouble()){
			return static_cast<int>(value.d);
    	}
		return atoi(toString().c_str());
	}

    explicit operator int64_t() const {
		if(isInteger()){
			return static_cast<int64_t>(static_cast<long long int>(value.i));
    	}
    	if(isDouble()){
			return static_cast<int64_t>(value.d);
    	}
		return atoi(toString().c_str());
	}

    explicit operator bigint() const {
		if(isInteger()){
			return value.i;
    	}
    	if(isDouble()){
			return bigint(static_cast<int>(value.d));
    	}
		return bigint(atoi(toString().c_str()));
	}

    explicit operator float() const {
		if(isInteger()){
			return static_cast<float>(static_cast<long long int>(value.i));
    	}
    	if(isDouble()){
			return static_cast<float>(value.d);
    	}
		return static_cast<float>(atof(toString().c_str()));
	}

    explicit operator double() const {
		if(isInteger()){
			return static_cast<double>(static_cast<long long int>(value.i));
    	}
    	if(isDouble()){
			return static_cast<double>(value.d);
    	}
		return atof(toString().c_str());
	}

    explicit operator ldouble() const {
		if(isInteger()){
			return static_cast<long double>(static_cast<long long int>(value.i));
    	}
    	if(isDouble()){
			return static_cast<double>(value.d);
    	}
		return atof(toString().c_str());
	}


	bool equals(const Value& that) const;

	bool operator==(const Value& that) const {
		return equals(that);
	}

	bool operator!=(const Value& that) const {
		return !equals(that);
	}

	const char* typeName() const;
	Value call(std::vector<Value> args);
	Value call(const std::string& name,std::vector<Value> args);
	Value operator+(Value that);
	Value operator-(Value that);
	Value operator*(Value that);
	Value operator/(Value that);
	Value operator%(Value that);
	Value operator~(void);

	Value addNone(Value that);
	Value addBoolean(Value that);
	Value addInteger(Value that);
	Value addDouble(Value that);
	Value addCollectable(Value that);

	Value remNone(Value that);
	Value remBoolean(Value that);
	Value remInteger(Value that);
	Value remDouble(Value that);
	Value remCollectable(Value that);

	Value mulNone(Value that);
	Value mulBoolean(Value that);
	Value mulInteger(Value that);
	Value mulDouble(Value that);
	Value mulCollectable(Value that);

	Value divNone(Value that);
	Value divBoolean(Value that);
	Value divInteger(Value that);
	Value divDouble(Value that);
	Value divCollectable(Value that);

	Value modNone(Value that);
	Value modBoolean(Value that);
	Value modInteger(Value that);
	Value modDouble(Value that);
	Value modCollectable(Value that);

	Value comBoolean();
	Value comInteger();
	Value comDouble();
	Value comCollectable();

	int sizeOf() const;
	Class* getClass();
	uint64_t hash() const;
	bigint size() const;
	[[nodiscard]] std::string getName() const;
	[[nodiscard]] std::string format() const;
	std::string modifiers() const;
	std::string toString();
	std::string toString() const;
	friend std::ostream& operator<<(std::ostream& os,Value& that);
	friend std::ostream& operator<<(std::ostream& os,const Value& that);

};

// C++20: inline bool operator == (const Value &left, const Value &right){
// C++20: 	if(left.type != right.type) return false;
// C++20: 	switch(left.type){
// C++20: 		case ValueType::NONE      : return true;
// C++20: 		case ValueType::BOOLEAN   : return left.value.b  == right.value.b;
// C++20: 		case ValueType::INTEGER   : return left.value.i  == right.value.i;
// C++20: 		case ValueType::DOUBLE    : return left.value.d  == right.value.d;
// C++20: 		case ValueType::COLLECTABLE    : return left.value.gc == right.value.gc;
// C++20: 		case ValueType::USERDATA  : return left.value.p  == right.value.p;
// C++20: 		default:
// C++20: 		break;
// C++20: 	}
// C++20: 	return false;
// C++20: }
// C++20: 
// C++20: inline bool operator != (const Value &left, const Value &right){
// C++20: 	return !(left == right);
// C++20: }

}///kernel
}///nython

namespace std{

inline uint32_t hashString(const char* key, int length) {
	uint32_t hash = 2166136261u;
	for(auto i = 0; i < length; i++){
		hash ^= key[i];
		hash *= 16777619;
	}
	return hash;
}

template<>
struct hash<nython::kernel::bigint>	{
	size_t operator () (const nython::kernel::bigint &t) const{
		std::string str = t.toString();
		return hashString(str.c_str(),static_cast<int>(str.size()));
	}
};

uint64_t __hash__(const nython::kernel::Value &t);

template<>
struct hash<nython::kernel::Value> {
	size_t operator () (const nython::kernel::Value &t) const{
		return __hash__(t);
	}
};

}

inline bool is_ptr(nython::kernel::Value v){
    return v.type == nython::kernel::ValueType::COLLECTABLE && v.value.gc != nullptr;
}

template<typename T>
inline T* as(nython::kernel::Value p) {
    return reinterpret_cast<T*>(p.value.gc);
}

inline nython::gc::Collectable* as_collectable(nython::kernel::Value value) {
    return reinterpret_cast<nython::gc::Collectable*>(value.value.gc);
}

inline bool is_dead(nython::kernel::Value value){
    nython::gc::Collectable* gc = as_collectable(value);
    return gc && gc->getType() == Type::DEAD;
}

inline bool is_dead(nython::gc::Collectable* gc){
    return gc && gc->getType() == Type::DEAD;
}

#endif // __VALUE__HPP


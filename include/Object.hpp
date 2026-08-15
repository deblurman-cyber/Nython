#ifndef __OBJECT__HPP
#define __OBJECT__HPP

#include "Container.hpp"

namespace nython{
namespace kernel{

struct Object extends Container {

protected:
    Value klass;
    std::string name;
    Package* package = nullptr;
    Module* module   = nullptr;
    NameSpace* nameSpace = nullptr;
    Context* context = nullptr;

public:

    Object(Runnable* runner, const std::string& name = "unnamed object", Type type = Type::OBJECT, Value klass = NONE_VALUE, uint32_t initial_capacity = 4);

    virtual bool is(Type type);
    virtual std::string toString();
    /**
    * Accessing and setting the name
    **/
	virtual std::string getName();
	virtual void setName(const std::string& name);
    virtual size_t count(const std::string& name);

    virtual int line() { return location.row; }
    virtual int column() { return location.column; }
    virtual std::string file() { return location.filename; }

    /**
    * Accessing and setting the parent
    **/
	virtual Object* getParent();
	virtual void setParent(Object* parent);

	virtual Context* getContext();

	/**
    * Accessing and setting the class
    **/
    virtual Class* getClass();
    virtual void  setClass(Class* klass);

	virtual Value getItem(int index);
	virtual Value getItem(const std::string& name);
	virtual void  setItem(int index,Value value);
	virtual void  setItem(int index,Object* value);
	virtual void  setItem(const std::string& name,Value value);
	virtual void  setItem(const std::string& name,Object* value);

	/**
    * Calls a callable object with some arguments
    * @param name
    * @param args
    * @return Value
    */
    virtual Value call(std::vector<Value> args);
	virtual Value operator()(std::vector<Value> args);
	virtual Value call(const std::string& name, std::vector<Value> args);

	// conditions
    virtual bool operator==(Value obj);
    virtual bool operator!=(Value obj);
    virtual bool operator> (Value obj);
    virtual bool operator< (Value obj);
    virtual bool operator>=(Value obj);
    virtual bool operator<=(Value obj);

    /**
     *  checks if two objects are equal
     *
     *  @param  object the other object
     *  @return bool
    */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Woverloaded-virtual"
    virtual bool equals(Value object);
    virtual bool equals(Object* object);
    using Collectable::equals;
#pragma GCC diagnostic pop

    /**
     *  checks if two objects are strictly equal
     *
     *  @param  object the other object
     *  @return bool
    */
    virtual bool same(Value object);
    virtual bool same(Object* object);

    /**
     *  compares two objects
     *
     *  @param  obj the object to compare with
     *  @return int
    */
    virtual int compare(Value obj);
    virtual int compare(Object* obj);

    /**
     *  Check whether this object is an instance of a certain class
     *
     *  @param  class The class of which this should be an instance
     *  @return bool
    */
    virtual bool instanceOf(Value clazz);
    virtual bool instanceOf(Object* clazz);
    virtual bool instanceOf(const std::string& name);

    /**
	 *  Check whether this object is a subclass of a certain class
     *
     *  @param  class   The class of which this should be an instance
     *  @return bool
    */
    virtual bool subclassOf(Value obj);
    virtual bool subclassOf(Object* obj);
    virtual bool subclassOf(const std::string& name);

    /**
     *  Check whether this object is a parent of a certain class
     *
     *  @param  class   The class of which this should be an instance
     *  @return bool
    */
    virtual bool parentOf(Value obj);
    virtual bool parentOf(Object* obj);
    virtual bool parentOf(const std::string& name);

    virtual const char* getTypeName(){
        // Store in a static thread-local buffer — avoids returning pointer to temporary
        static thread_local std::string _tn;
        _tn = TypeToString(type);
        return _tn.c_str();
    }

	 /**
    * Object features
    **/
    virtual Value property(const std::string& name);
    virtual bool  hasProperty(const std::string& name);
    virtual Value property(const std::string& name,Value o);
    virtual Value property(const std::string& name, Object* value);

    virtual Value method(const std::string& name);
    virtual bool  hasMethod(const std::string& name);
    virtual Value method(const std::string& name,Value o);
    virtual Value method(const std::string& name, Object* value);

    /**
     *  Check if a certain key exists in the object
     *  @param  name
     *  @return bool
    */
    virtual bool has(int key);
    virtual bool has(Value key);
    virtual bool key(Value key);
    virtual bool has(const std::string& key);

    /**
     *  Check if a certain property exists in the object
     *  @param  name
     *  @return bool
    */
    virtual bool contains(Value obj);

    /**
     *  array/collection access
     *  @param  value
     *  @return Object
     */
    virtual Value operator[](int key);
    virtual Value operator[](const char* key);
    virtual Value operator[](const std::string& key);
    virtual Value operator[](const Value key);

    /**
     *  Retrieve the value at a value index
     *  @param  key
     *  @return Object
    */
    virtual Value get(int key);
    virtual Value get(Value key);
    virtual Value get(const std::string& key);
    virtual Value get(int start,int end);

     /**
     *  Overwrite the value at a certain string index
     *  @param  key
     *  @param  value
    */
    virtual void set(int key,Value value);
    virtual void set(Value key,Value value);
    virtual void set(const std::string &key,Value value);

    /**
     *  Add the value at a certain string index without any checking
     *  @param  key
     *  @param  value
    */
    virtual void add(int key,Value value);
    virtual void add(Value key,Value value);
    virtual void add(const std::string &key,Value value);

     /**
     *  removes an object
     *
     *  @return bool
    */
    virtual bool unset(int key);
    virtual bool unset(Value key);
    virtual bool unset(const std::string& key);

    /**
    * Collection features
    **/
    virtual void extend(Value item);
    virtual void append(Value item);
    virtual void prepend(Value item);
    virtual void append(Value key,Value value);
	virtual void append(const std::string& key,Value value);
	virtual bool remove(int index);

    virtual Value operator+(Value base);
    virtual Value operator-(Value base);
    virtual Value operator*(Value base);
    virtual Value operator/(Value base);
    virtual Value operator%(Value base);

    virtual Value operator+=(Value base);
    virtual Value operator-=(Value base);
    virtual Value operator*=(Value base);
    virtual Value operator/=(Value base);
    virtual Value operator%=(Value base);

    virtual Value operator~();
    virtual Value operator!();
    virtual Value operator&(Value base);
    virtual Value operator|(Value base);
    virtual Value operator^(Value base);

    virtual Value operator&=(Value base);
    virtual Value operator|=(Value base);
    virtual Value operator^=(Value base);

	virtual bigint size();
	virtual bigint length();
	virtual void clear();
	virtual uint64_t id();
    virtual uint64_t hash();
    virtual std::string shortName();
    virtual std::string address();
    virtual std::string qualifiedName();


    virtual Value __cmp__(std::vector<Value> args);
	virtual Value __eq__(std::vector<Value> args);
	virtual Value __ne__(std::vector<Value> args);
	virtual Value __lt__(std::vector<Value> args);
	virtual Value __gt__(std::vector<Value> args);
	virtual Value __le__(std::vector<Value> args);
	virtual Value __ge__(std::vector<Value> args);
	virtual Value __pos__(std::vector<Value> args);
	virtual Value __neg__(std::vector<Value> args);
	virtual Value __pre_inc__(std::vector<Value> args);
    virtual Value __pre_dec__(std::vector<Value> args);
    virtual Value __post_inc__(std::vector<Value> args);
    virtual Value __post_dec__(std::vector<Value> args);
	virtual Value __abs__(std::vector<Value> args);
	virtual Value __round__(std::vector<Value> args);
	virtual Value __floor__(std::vector<Value> args);
	virtual Value __ceil__(std::vector<Value> args);
	virtual Value __trunc__(std::vector<Value> args);
	virtual Value __add__(std::vector<Value> args);
	virtual Value __sub__(std::vector<Value> args);
	virtual Value __mul__(std::vector<Value> args);
	virtual Value __div__(std::vector<Value> args);
	virtual Value __rdiv__(std::vector<Value> args);
	virtual Value __mod__(std::vector<Value> args);
	virtual Value __pow__(std::vector<Value> args);
	virtual Value __invert__(std::vector<Value> args);
	virtual Value __add_eq__(std::vector<Value> args);
	virtual Value __sub_eq__(std::vector<Value> args);
	virtual Value __mul_eq__(std::vector<Value> args);
	virtual Value __div_eq__(std::vector<Value> args);
	virtual Value __rdiv_eq__(std::vector<Value> args);
	virtual Value __mod_eq__(std::vector<Value> args);
	virtual Value __pow_eq__(std::vector<Value> args);
	virtual Value __invert_eq__(std::vector<Value> args);
	virtual Value __shift__(std::vector<Value> args);
	virtual Value __lshift__(std::vector<Value> args);
	virtual Value __rshift__(std::vector<Value> args);
	virtual Value __shift_eq__ (std::vector<Value> args);/// <<<=
    virtual Value __rshift_eq__(std::vector<Value> args);/// <<=
    virtual Value __lshift_eq__(std::vector<Value> args);/// >>=
	virtual Value __divmod__(std::vector<Value> args);
	virtual Value __rdivmod__(std::vector<Value> args);
	virtual Value __and__(std::vector<Value> args);
	virtual Value __or__(std::vector<Value> args);
	virtual Value __xor__(std::vector<Value> args);
	virtual Value __not__(std::vector<Value> args);
	virtual Value __and_eq__ (std::vector<Value> args);
    virtual Value __or_eq__  (std::vector<Value> args);
    virtual Value __xor_eq__ (std::vector<Value> args);
    virtual Value __band__   (std::vector<Value> args);
    virtual Value __bor__    (std::vector<Value> args);
    virtual Value __bxor__   (std::vector<Value> args);
    virtual Value __band_eq__(std::vector<Value> args);
    virtual Value __bor_eq__ (std::vector<Value> args);
    virtual Value __bxor_eq__(std::vector<Value> args);
	virtual Value __int__(std::vector<Value> args);
	virtual Value __float__(std::vector<Value> args);
	virtual Value __bool__(std::vector<Value> args);
	virtual Value __cmplex__(std::vector<Value> args);
	virtual Value __rational__(std::vector<Value> args);
	virtual Value __bin__(std::vector<Value> args);
	virtual Value __oct__(std::vector<Value> args);
	virtual Value __hex__(std::vector<Value> args);
	virtual Value __index__(std::vector<Value> args);
	virtual Value __string__(std::vector<Value> args);
	virtual Value __format__(std::vector<Value> args);
	virtual Value __hash__(std::vector<Value> args);
	virtual Value __nonzero__(std::vector<Value> args);
	virtual Value __dir__(std::vector<Value> args);
	virtual Value __sizeof__(std::vector<Value> args);
	virtual Value __type__(std::vector<Value> args);
	virtual Value __getattr__(std::vector<Value> args);
	virtual Value __setattr__(std::vector<Value> args);
	virtual Value __delattr__(std::vector<Value> args);
	virtual Value __getitem__(std::vector<Value> args);
	virtual Value __setitem__(std::vector<Value> args);
	virtual Value __delitem__(std::vector<Value> args);
	virtual Value __length__(std::vector<Value> args);
	virtual Value __reverse__(std::vector<Value> args);
	virtual Value __has__(std::vector<Value> args);
	virtual Value __contains__(std::vector<Value> args);
	virtual Value __missing__(std::vector<Value> args);
	virtual Value __all__(std::vector<Value> args);
	virtual Value __any__(std::vector<Value> args);
	virtual Value __call__(std::vector<Value> args);
	virtual Value __callable__(std::vector<Value> args);
	virtual Value __chr__(std::vector<Value> args);
	virtual Value __odr__(std::vector<Value> args);
	virtual Value __filter__(std::vector<Value> args);
	virtual Value __help__(std::vector<Value> args);
	virtual Value __doc__(std::vector<Value> args);
	virtual Value __id__(std::vector<Value> args);
	virtual Value __iterator__(std::vector<Value> args);
    virtual Value __next__(std::vector<Value> args);
	virtual Value __list__(std::vector<Value> args);
	virtual Value __tuple__(std::vector<Value> args);
	virtual Value __array__(std::vector<Value> args);
	virtual Value __map__(std::vector<Value> args);
	virtual Value __funlist__(std::vector<Value> args);
	virtual Value __file__(std::vector<Value> args);
	virtual Value __line__(std::vector<Value> args);
	virtual Value __column__(std::vector<Value> args);
	virtual Value __class__(std::vector<Value> args);
	virtual Value __module__(std::vector<Value> args);
	virtual Value __package__(std::vector<Value> args);
	virtual Value __context__(std::vector<Value> args);
	virtual Value __namespace__(std::vector<Value> args);
    virtual Value __toString__(std::vector<Value> args);
    virtual Value __subclassof__(std::vector<Value> args);
    virtual Value __parentof__(std::vector<Value> args);
    virtual Value __instanceof__(std::vector<Value> args);
    virtual Value __super__(std::vector<Value> args);
    virtual Value __parent__(std::vector<Value> args);
    virtual Value __locals__(std::vector<Value> args);
    virtual Value __max__(std::vector<Value> args);
    virtual Value __min__(std::vector<Value> args);
    virtual Value __open__(std::vector<Value> args);
    virtual Value __zip__(std::vector<Value> args);
    virtual Value __size__(std::vector<Value> args);
    virtual Value __invoke__(std::vector<Value> args);
    virtual Value __complement__(std::vector<Value> args);

    virtual int sizeOf();
    /**
    * Checks if they are exactly the same OBJECT
    * @param obj
    * @return bool
    */
    virtual bool is(Value obj);
    virtual std::ostream& operator<<(std::ostream& os);
    friend  std::ostream& operator<<(std::ostream& os,Object& that);

    bool isGenerator();

    // Definitions for global types

    virtual operator bool();
    virtual operator int();
    virtual operator int64_t();
    virtual operator bigint();
    virtual operator float();
    virtual operator double();
    virtual operator ldouble();
    virtual operator std::string();
    virtual operator char*();
	virtual operator Object*();

	DISALLOW_COPY_AND_ASSIGN(Object)
};



}
}

#endif // __OBJECT__HPP


#ifndef __CLASS__HPP
#define __CLASS__HPP

#include "Object.hpp"
#include "Modifier.hpp"

namespace nython::kernel {

struct Class extends Object{

	int flags = Modifier.PUBLIC;
	std::string file;
	Class* super = nullptr;

	Class(Runnable* runner);
	Class(Runnable* runner, const std::string& name);
	Class(Runnable* runner, const std::string& name,int flags);
	Class(Runnable* runner, const std::string& name,Object* super);
	Class(Runnable* runner, const std::string& name,Object* super,int flags);
	Class(Runnable* runner, const std::string& name,Class* clazz,Object* super,int flags);
	Class(Runnable* runner, const std::string& name,Class* clazz,Object* super,int flags, const kernel::ContainerType& fields);
	virtual ~Class();

	std::string toString() override;
	Object* getParent();
	void setParent(Object* parent);
	void setClass(Class* clazz);
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Woverloaded-virtual"
	bool equals(Value obj);
    bool equals(Class* obj);
    bool equals(const Class& obj);
    using Object::equals;
#pragma GCC diagnostic pop
    Value lookup(const std::string& name);

    Value property(const std::string& name);
    bool  hasProperty(const std::string& name);
    Value property(const std::string& name,Value o);
    Value property(const std::string& name, Object* value);

    Value method(const std::string& name);
    bool  hasMethod(const std::string& name);
    Value method(const std::string& name,Value o);
    Value method(const std::string& name, Object* value);

    Value call(std::vector<Value> args);

    virtual std::string qualifiedName();

    /**
    Creates a new instance of the class.
    */
    auto newInstance(const std::string& name) -> Class*;
    /**
    Creates a new subclass of this class.
    */
    auto newSubclass(const std::string& name) -> Class*;
    /**
    Creates or returns a subclass if it already exists.
    */
    auto subclass(const std::string& name) -> Class*;

    int sizeOf(){
        return sizeof(*this);
    }

    static std::string argTypesAsString(std::vector<Value> argTypes);
    /**
     * Check the accessibility of a type.
     *
     * @param line            the line in which the access occurs.
     * @param referencingType the type attempting the access.
     * @param type            the type that we want to access.
     * @return true if access is valid; false otherwise.
    */
    static bool checkAccess(int line,Class* referencingType,Class* type);
    /**
     * A helper for constructing method signatures for reporting unfound methods
     * and constructors.
     *
     * @param name     the message or Type name.
     * @param argTypes the actual argument types.
     * @return a printable signature.
    */
    static std::string signatureFor(const std::string& name,std::vector<Value> argTypes);
    /**
     * Check the accessibility of a member from this type (that is, this type is
     * the referencing type).
     *
     * @param line   the line in which the access occurs.
     * @param member the member being accessed.
     * @return true if access is valid; false otherwise.
    */
    bool checkAccess(int line,Value member);
    /**
     * Check the accessibility of a target type (from this type)
     *
     * @param line       line in which the access occurs.
     * @param targetType the type being accessed.
     * @return true if access is valid; false otherwise.
    */
    bool checkAccess(int line,Class* targetType);
    /**
     * Return a list of this class' abstract methods? It does has abstract
     * methods if(1) Any method declared in the class is abstract, or (2) Its
     * superclass has an abstract method which is not overridden here.
     *
     * @return a list of abstract methods.
    */
    //std::vector<std::shared_ptr<Method>> abstractMethods();
    /**
     * Return a list of this class' declared abstract methods.
     *
     * @return a list of declared abstract methods.
    */
    //std::vector<std::shared_ptr<Method>> declaredAbstractMethods();
    /**
     * Return a list of this class' declared concrete methods.
     *
     * @return a list of declared concrete methods.
    */
    //std::vector<std::shared_ptr<Method>> declaredConcreteMethods();

    bool isMap();
    bool isList();
    bool isEnum();
    bool isTuple();
    bool isFinal();
    bool isArray();
    bool isStatic();
    bool isLambda();
    bool isPublic();
    bool isPrivate();
    bool isMutable();
    bool isFunction();
    bool isAbstract();
    bool isProtected();
    bool isInterface();
    bool isPrimitive();
    bool isImmutable();
    bool isSynchronized();

    DISALLOW_COPY_AND_ASSIGN(Class)

};

}

#endif // __CLASS__HPP


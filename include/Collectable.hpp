#ifndef __COLLECTABLE__HPP
#define __COLLECTABLE__HPP

#include <string>
#include "Type.hpp"
#include "Runnable.hpp"
#include "Definitions.hpp"


using nython::kernel::Type;
using nython::kernel::Class;
using nython::kernel::Object;

namespace nython::gc {

// Metadata which is stores in every heap Value
class Collectable {
public:
    Collectable(const Collectable&) = default;
    Collectable& operator=(const Collectable&) = default;


protected:
    Type  type{};
    bool marked = false;   // set by the GC to mark reachable Values
    Runnable* runner = nullptr;

public:

    Collectable(Type type_arg);
    Collectable(Runnable* runner_arg, Type type_arg);
    Runnable* getRunner() const { return runner; }
    virtual ~Collectable();

    virtual void clean();
    virtual std::string toString();
    virtual std::string typeName();

    virtual std::string getName() {
        return "";
    }

    virtual std::string shortName(){
        return "";
    }

    virtual std::string address(){
        return "";
    }

    virtual std::string qualifiedName(){
        return "";
    }

    virtual Type getType();
    virtual void setType(Type type_arg);
    virtual uint64_t id();
    virtual Object* getParent();
    virtual Class* getClass();
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Woverloaded-virtual"
    virtual bool equals(Collectable* that);
#pragma GCC diagnostic pop
    virtual bool isClass();

    bool get_gc_mark();
    void set_gc_mark();
    void clear_gc_mark();

    template<typename T>
    T* as();

};
}


#endif // __COLLECTABLE__HPP


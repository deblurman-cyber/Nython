#ifndef __CONTEXT__HPP
#define __CONTEXT__HPP

#include <memory>
#include "Value.hpp"
#include "Object.hpp"
#include "Runnable.hpp"
#include "Container.hpp"

using nython::Runnable;

namespace nython{
namespace kernel{

struct Context extends Container {

    std::string name;
	Collectable* self;
	Collectable* klass;
	Context* parent;

	/// are we in a function or in a class or in a namespace or in a block or in module
    bool inFunction  = false;
    bool inClass     = false;
    bool inNameSpace = false;
    bool inBlock     = false;
    bool inModule    = false;

	Context(Runnable* runner,const std::string& name, Collectable* self = nullptr, Collectable* klass = nullptr, Context* parent = nullptr);
	~Context();

	Context& operator=(Context&& that);

	Context* makeChildContext(const std::string& name);

	Value get(const Value& name);
	void set(const Value& name,Value value);
	void define(const Value& name,Value value);

    // String-key convenience methods for AST eval
    Value getByName(const std::string& varName) {
        if (!container) return NONE_VALUE;
        auto it = container->find(varName);
        if (it != container->end()) return it->second;
        if (parent) return parent->getByName(varName);
        return UNDEFINED_VALUE;
    }
    void setByName(const std::string& varName, Value val) {
        if (!container) return;
        // Check if variable exists in current scope
        if (container->count(varName)) {
            (*container)[varName] = val;
            return;
        }
        // Walk up parent scopes
        Context* p = parent;
        while (p) {
            if (p->container && p->container->count(varName)) {
                (*p->container)[varName] = val;
                return;
            }
            p = p->parent;
        }
        // Fallback: define in current scope
        (*container)[varName] = val;
    }
    void defineByName(const std::string& varName, Value val) {
        if (!container) return;
        (*container)[varName] = val;
    }
    bool hasByName(const std::string& varName) {
        if (!container) return false;
        if (container->count(varName)) return true;
        if (parent) return parent->hasByName(varName);
        return false;
    }
	Value getAt(int distance, const Value& name);
	void setAt(int distance, const Value &name, Value value);

    bool has(const Value& name);
    bool has(const Value& name,Value* obj);
    bool remove(const Value& name);

    Object* getParent();
    void setParent(Object* parent);


    Context& ancestor(int distance);

    bigint size(){
        return container->size();
    }

    std::string toString(){
        std::stringstream s;
        s << "<Context name = " << name << ">\n";
        s << "</Context>";
        return s.str();
    }

	Value eval(const std::string& code);

	DISALLOW_COPY_AND_ASSIGN(Context)

};

}
}

#endif // __CONTEXT__HPP



#ifndef __RUNNABLE__HPP
#define __RUNNABLE__HPP

#include "Value.hpp"
#include "Except.hpp"

namespace nython {

enum class RunnableType: uint8_t  {
    COMPILER,
    INTERPRETER
};

using kernel::Value;
using exception::Reporter;
using exception::ReporterAware;

class Runnable: public ReporterAware {

    friend class gc::GarbageCollector;

public:
    Runnable(Reporter* reporter): ReporterAware(reporter), stack_{}, type{RunnableType::COMPILER} {}
    Runnable(Reporter* reporter, RunnableType t): ReporterAware(reporter), stack_{}, type{t} {}

    bool isCompiler() {
        return type==RunnableType::COMPILER;
    }

    bool isInterpreter() {
        return type==RunnableType::INTERPRETER;
    }

    template<typename T>
    T* create() {
        throw std::runtime_error("Can't create an allocate memory with interface class Runnable.\n");
    }

    template<class T,class First,class...Rest>
    T* create(First&& first, Rest&&... rest) {
        throw std::runtime_error("Can't create an allocate memory with interface class Runnable.\n");
    }

protected:
    // The stack of the virtual machine or the interpreter
    std::vector<Value> stack_;
private:
    RunnableType type;
};

}

#endif // __RUNNABLE__HPP

#pragma once

#include <vector>
#include <thread>
#include "Value.hpp"
#include "Object.hpp"

using nython::interpreter::Interpreter;

namespace nython {
namespace kernel {
// Represents a worker thread started by the VM
struct Thread extends Object {
    Thread(const Thread&) = delete;
    Thread& operator=(const Thread&) = delete;


    using Object::call;
    using Object::operator();

    CFunction cfunc;
    Function* callback;
    Value return_value;
    std::vector<Value> arguments;
    std::thread thread;

    Thread(Runnable* r,CFunction _cf, const std::vector<Value>& _args, Function* _cb) :Object(r,"thread",Type::THREAD), cfunc(_cf), callback(_cb), return_value{}, arguments(_args), thread{} {
    }

    ~Thread() {
        if (std::this_thread::get_id() == this->thread.get_id()) {
            this->thread.detach();
        } else {
            this->thread.join();
        }
    }

    void detach() {
        if (std::this_thread::get_id() == this->thread.get_id()) {
            this->thread.detach();
        }
    }

    void join() {
        if (this->thread.joinable()) this->thread.join();
    }

    Value call(Runnable* r);

    Value operator()(Runnable* r) {
        return call(r);
    }

    Value getValue() {
        return this->return_value;
    }
};
}
}

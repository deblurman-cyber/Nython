#include "Thread.hpp"
#include "Interpreter.hpp"
#include <thread>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.



namespace nython {
namespace kernel {
Value Thread::call(Runnable* r) {
    this->thread = std::thread([this, &r]() {
        // Invoke c function
        this->return_value = this->cfunc(r, this->arguments);
        // Return our value to the VM
    });
    return this->return_value;
}
}
}

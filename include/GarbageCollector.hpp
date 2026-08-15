
#ifndef __GARBAGE_COLLECTOR__HPP
#define __GARBAGE_COLLECTOR__HPP

#include <unordered_set>
#include <vector>
#include <mutex>
#include <set>

#include "List.hpp"
#include "Value.hpp"
#include "Object.hpp"
#include "Container.hpp"
#include "Collectable.hpp"
#include "GarbageCollectorConfig.hpp"


namespace nython{
namespace interpreter {
struct Interpreter;
}

namespace vm {
struct VirtualMachine;
}

struct Runnable;
}


namespace nython {
namespace gc {

using kernel::List;
using kernel::Value;
using kernel::Object;
using kernel::Container;
using nython::Runnable;

// Item inside the MemoryCell
struct MemoryCell {
    Collectable* value;
    MemoryCell* next;
    bool isDead = false;

    template <typename T>
    inline T* as() {
        return reinterpret_cast<T*>(value);
    }

    inline Value as_value() {
        return Value(value);
    }
};

using nython::vm::VirtualMachine;
using nython::interpreter::Interpreter;

class GarbageCollector : public std::enable_shared_from_this<GarbageCollector>  {

    friend class Interpreter;
    friend class VirtualMachine;
    GarbageCollectorConfig config;
    Runnable* runner;
    MemoryCell* free_cell;
    size_t remaining_free_cells = 0;
    std::vector<MemoryCell*> heaps;
    std::multiset<Value> temporaries;
    std::recursive_mutex g_mutex;

    void add_heap();
    void grow_heap();
    void collect();

    void deallocate(MemoryCell* value);
    template <typename T>
    inline void deallocate(T value) {
        this->deallocate(reinterpret_cast<MemoryCell*>(value));
    }

public:

    GarbageCollector(Runnable* r):  GarbageCollector(GarbageCollectorConfig{}, r){
    }

    GarbageCollector(GarbageCollectorConfig cfg, Runnable* r);

    ~GarbageCollector() {
        for (MemoryCell* heap : this->heaps) {
            std::free(heap);
        }
    }

    MemoryCell* allocate();

    void mark(Value cell);

    template <typename T>
    inline void mark(T* cell) {
        this->mark(Value(cell));
    }

    void do_collect();
    void mark_persistent(Value value);
    void unmark_persistent(Value value);

    void lock();
    void unlock();

    DISALLOW_COPY_AND_ASSIGN(GarbageCollector)
};

}
}

#endif // __GARBAGE_COLLECTOR__HPP

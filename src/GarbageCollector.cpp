#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include <cassert>
#include <iomanip>
#include <iostream>

#include "Context.hpp"
#include "Interpreter.hpp"
#include "GarbageCollector.hpp"
#include <chrono>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

using nython::kernel::Value;
using nython::kernel::Class;
using nython::kernel::Object;
using nython::kernel::Context;
using nython::interpreter::Interpreter;

namespace nython {
namespace gc {


using nython::kernel::ContainerType;

GarbageCollector::GarbageCollector(GarbageCollectorConfig cfg, nython::Runnable* runner) : config(cfg), runner(runner), free_cell(nullptr), remaining_free_cells{0}, heaps{}, temporaries{}, g_mutex{} {
    this->free_cell = nullptr;
    // Allocate the initial heaps
    size_t heapc = cfg.initial_heap_count;
    while (heapc--) {
        this->add_heap();
    }
}

void GarbageCollector::add_heap() {
  MemoryCell* heap = static_cast<MemoryCell*>(std::calloc(this->config.heap_cell_count, sizeof(MemoryCell)));
  heap->isDead = false;
  this->heaps.push_back(heap);
  this->remaining_free_cells += this->config.heap_cell_count;

  // Add the newly allocated cells to the free list
  MemoryCell* last_cell = this->free_cell;
  for(size_t i = 0; i < this->config.heap_cell_count; i++) {
    heap[i].next   = last_cell;
    heap[i].isDead = false;
    last_cell = heap + i;
  }
  this->free_cell = last_cell;
}

void GarbageCollector::grow_heap() {
  size_t heap_count   = this->heaps.size();
  size_t heaps_to_add = (heap_count * this->config.heap_growth_factor + 1) - heap_count;
  while (heaps_to_add--) this->add_heap();
}

void GarbageCollector::mark_persistent(Value value) {
  std::unique_lock<std::recursive_mutex> g_lock(this->g_mutex);
  this->temporaries.insert(value);
}

void GarbageCollector::unmark_persistent(Value value) {
  std::unique_lock<std::recursive_mutex> g_lock(this->g_mutex);

  // Check if this Value is a registered temporary variable
  if (this->temporaries.count(value)) {
    auto it = this->temporaries.find(value);
    if (it != this->temporaries.end()) {
      this->temporaries.erase(it);
    }
  }
}

void GarbageCollector::do_collect() {
  std::unique_lock<std::recursive_mutex> g_lock(this->g_mutex);
  this->collect();
}

void GarbageCollector::collect() {
  std::unique_lock<std::recursive_mutex> gc_lock(this->g_mutex);

  auto gc_start_time = std::chrono::high_resolution_clock::now();
  if (this->config.trace) {
    this->config.out_stream << "#-- GC: Pause --#" << '\n';
  }

  // Stack
  for (Value item : this->runner->stack_) {
    this->mark(item);
  }

  // Mark all temporaries
  for (auto temp_item_iter : this->temporaries) {
    this->mark(temp_item_iter);
  }

  // Sweep Phase
  int freed_cells_count = 0;
  for (MemoryCell* heap : this->heaps) {
    for (size_t i = 0; i < this->config.heap_cell_count; i++) {
      MemoryCell* cell = heap + i;
      if(cell->value && cell->value->get_gc_mark()) {
        cell->value->clear_gc_mark();
      } else {
        // This cell might already be on the free list
        // Make sure we don't double free cells
        if (!cell->isDead or !is_dead(cell->value)) {
          freed_cells_count++;
          this->deallocate(cell);
        }
      }
    }
  }

  if (this->config.trace) {
    std::chrono::duration<double> gc_collect_duration = std::chrono::high_resolution_clock::now() - gc_start_time;
    this->config.out_stream << std::fixed;
    this->config.out_stream << std::setprecision(0);
    this->config.out_stream << "#-- GC: Freed " << (freed_cells_count * sizeof(MemoryCell)) << " bytes --#" << '\n';
    this->config.out_stream << "#-- GC: Finished in " << gc_collect_duration.count() * 1000000000 << " nanoseconds --#"<< '\n';
    this->config.out_stream << std::setprecision(6);
  }
}

void GarbageCollector::mark(Value value) {
  if (!is_ptr(value)) {
    return;
  }

  if (value->get_gc_mark()) {
    return;
  }

  value->set_gc_mark();

  switch (value->getType()) {
    case Type::LIST:
    case Type::STRING :
    case Type::COMPLEX :
    case Type::RATIONAL :
    case Type::TUPLE :
    case Type::ARRAY :
    case Type::MAP :
    case Type::SET :
    case Type::ENUM :
    case Type::RANGE :
    case Type::SLICE :
    case Type::METHOD :
    case Type::FUNCTION :
    case Type::LAMBDA :
    #undef INTERFACE
    case Type::INTERFACE :
    case Type::INSTANCE :
    case Type::PACKAGE :
    case Type::MODULE :
    case Type::NAMESPACE :
    case Type::PROPERTY :
    case Type::FUNLIST :
    case Type::ITERATOR :
    case Type::GENERATOR :
    case Type::PARAMETER :
    case Type::ARGUMENT :
    case Type::ELLIPSIS :
    case Type::FILE :
    case Type::EXCEPTION :
    case Type::REGEXP :
    case Type::COROUTINE :
    case Type::DATE :
    case Type::TIME :
    case Type::DATETIME :
    case Type::CODE :
    case Type::CONTEXT :
    case Type::UNIT :
    case Type::NATIVE :
    case Type::DEAD :
    case Type::THREAD :
    case Type::CLASS:
    case Type::OBJECT: {
      Object* obj = as<Object>(value);
      this->mark(obj->getClass());
      this->mark(obj->getParent());
      this->mark(obj->getContext());
      /// mark eventually package, module and namespace
      obj->access_container_shared([&](ContainerType* container) {
        for (auto entry : *container) {
            this->mark(entry.second);
        }
      });
      if(obj->is(Type::CONTEXT)) {
        Context* ctx = (Context*)obj;
        this->mark(ctx->self);
        this->mark(ctx->klass);
      }
      break;
    }
    default: {
      // This type doesn't reference any other types
    }
  }
}

MemoryCell* GarbageCollector::allocate() {
  std::unique_lock<std::recursive_mutex> g_lock(this->g_mutex);

  MemoryCell* cell = this->free_cell;
  this->free_cell  = this->free_cell->next;

  // If we've just allocated the last available cell,
  // we do a collect in order to make sure we never get a failing
  // allocation in the future
  if (this->free_cell == nullptr || this->remaining_free_cells <= this->config.min_free_cells) {
    this->collect();

    // If a collection didn't yield new available space,
    // allocate more heaps
    if (this->free_cell == nullptr) {
      this->grow_heap();

      if (!this->free_cell) {
        this->config.err_stream << "Failed to expand heap, the next allocation will cause a segfault." << '\n';
      }
    }
  }

  this->remaining_free_cells--;
  memset(reinterpret_cast<void*>(cell), 0, sizeof(MemoryCell));
  return cell;
}

void GarbageCollector::deallocate(MemoryCell* cell) {
  std::unique_lock<std::recursive_mutex> dealloc_lock(this->g_mutex);
  if(cell == nullptr or cell->value == nullptr) return;
  // Run the type specific cleanup function
  cell->value->clean();
  // Clear the cell and link it into the free list
  cell->value->setType(Type::DEAD);
  ///std::wcout << to_wstring(cell->value->toString()) << std::endl;
  delete cell->value;
  cell->value  = nullptr;
  cell->isDead = true;
  memset(reinterpret_cast<void*>(cell), 0, sizeof(MemoryCell));
  cell->next = this->free_cell;
  this->free_cell = cell;
  this->remaining_free_cells++;
}

void GarbageCollector::lock() {
  this->g_mutex.lock();
}

void GarbageCollector::unlock() {
  this->g_mutex.unlock();
}

}
}

#pragma GCC diagnostic pop

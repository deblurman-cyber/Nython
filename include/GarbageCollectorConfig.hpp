#pragma once

#include <iostream>

// Flagas for the memory manager
struct GarbageCollectorConfig {
  size_t initial_heap_count = 4;
  size_t heap_cell_count    = 1 << 12;
  float heap_growth_factor  = 2;
  size_t min_free_cells     = 32;

  bool trace = true;
  std::ostream& out_stream = std::cerr;
  std::ostream& err_stream = std::cout;
};

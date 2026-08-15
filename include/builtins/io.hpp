#pragma once
// builtins/io.hpp
// File I/O (handle + path), KV store, ZIP
// Part of the Nython builtin module system.
// Each dispatch_* function returns the result Value, or UNDEFINED_VALUE if
// the builtin name is not handled by this module (pass to next module).

#include "Value.hpp"
#include "Context.hpp"
#include <string>
#include <vector>

struct NythonExecutor;   // forward declaration — full def in NythonExecutor.hpp

/// Dispatch builtins belonging to the Io module.
/// Returns UNDEFINED_VALUE when `name` is not handled here.
Value dispatch_io(NythonExecutor& E,
                       const std::string& name,
                       std::vector<Value>& args,
                       Context* ctx);

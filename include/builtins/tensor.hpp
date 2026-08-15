#pragma once
// builtins/tensor.hpp
// Tensor math, ML ops, NyTorch v1-v3
// Part of the Nython builtin module system.
// Each dispatch_* function returns the result Value, or UNDEFINED_VALUE if
// the builtin name is not handled by this module (pass to next module).

#include "Value.hpp"
#include "Context.hpp"
#include <string>
#include <vector>

struct NythonExecutor;   // forward declaration — full def in NythonExecutor.hpp

/// Dispatch builtins belonging to the Tensor module.
/// Returns UNDEFINED_VALUE when `name` is not handled here.
Value dispatch_tensor(NythonExecutor& E,
                       const std::string& name,
                       std::vector<Value>& args,
                       Context* ctx);

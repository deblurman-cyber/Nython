#pragma once
#include "NythonExecutor.hpp"
Value dispatch_lang(NythonExecutor& E, const std::string& name,
                    std::vector<Value>& args, Context* ctx);

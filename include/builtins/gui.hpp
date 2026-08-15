#pragma once
// builtins/gui.cpp  / gui.hpp
// SDL3 + SDL3_ttf + SDL3_image GUI backend for Nython
// ─────────────────────────────────────────────────────────────────────────────
// IMPORTANT: define SDL_MAIN_HANDLED before any SDL3 include to prevent
// SDL3 from redefining main→SDL_main on Windows, which causes linker errors.
// This is done at the top of gui.cpp and via -DSDL_MAIN_HANDLED in the build.
//
// Windows link order (MinGW): -lmingw32 -lSDL3 -lSDL3_ttf -lSDL3_image -lws2_32 -lpthread
// Linux link:                 -lSDL3 -lSDL3_ttf -lSDL3_image -lpthread

#include "Value.hpp"
#include "Context.hpp"
#include <string>
#include <vector>

struct NythonExecutor;   // forward declaration

/// Dispatch builtins belonging to the GUI module.
/// Returns UNDEFINED_VALUE when `name` is not handled here.
Value dispatch_gui(NythonExecutor& E,
                   const std::string& name,
                   std::vector<Value>& args,
                   Context* ctx);

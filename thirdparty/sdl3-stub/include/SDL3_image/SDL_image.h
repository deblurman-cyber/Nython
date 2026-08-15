// thirdparty/sdl3-stub/include/SDL3_image/SDL_image.h
//
// Headless stand-in for the real SDL3_image <SDL3_image/SDL_image.h>. Only
// the symbol referenced by src/builtins/gui.cpp is declared.
#pragma once

#include <SDL3/SDL.h>

#ifdef __cplusplus
extern "C" {
#endif

SDL_Surface* IMG_Load(const char* file);

#ifdef __cplusplus
}
#endif

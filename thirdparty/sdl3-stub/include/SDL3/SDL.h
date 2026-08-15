// thirdparty/sdl3-stub/include/SDL3/SDL.h
//
// Headless stand-in for the real SDL3 <SDL3/SDL.h>. This is NOT SDL — it
// exists only so that src/builtins/gui.cpp (written against the real SDL3
// API) compiles and links in an environment with no SDL3 available. Every
// function is a no-op or returns plausible fake data; nothing is ever
// rendered to a real display.
//
// Scope: only the symbols actually referenced by src/builtins/gui.cpp (and
// the couple of guard lines in include/platform_compat.hpp) are declared.
// Struct field layouts for SDL_Event and its member structs are laid out to
// match how gui.cpp accesses them (ev.type, ev.key.key, ev.motion.x, ...).
//
// See thirdparty/sdl3-stub/README.md (if present) / HANDOFF.md for the
// environment variables this stub honours: NY_STUB_AUTOQUIT, NY_STUB_DPI_SCALE.
#pragma once

#include <cstdint>
#include <cstddef>

#ifdef __cplusplus
extern "C" {
#endif

// ── Integer typedefs (SDL_stdinc.h) ─────────────────────────────────────
typedef int8_t   Sint8;
typedef uint8_t  Uint8;
typedef int16_t  Sint16;
typedef uint16_t Uint16;
typedef int32_t  Sint32;
typedef uint32_t Uint32;
typedef int64_t  Sint64;
typedef uint64_t Uint64;

// SDL3 uses C99 bool via <stdbool.h> in C, and plain bool in C++.

// ── Geometry ─────────────────────────────────────────────────────────────
typedef struct SDL_Rect {
    int x, y, w, h;
} SDL_Rect;

typedef struct SDL_FRect {
    float x, y, w, h;
} SDL_FRect;

typedef struct SDL_Point {
    int x, y;
} SDL_Point;

typedef struct SDL_FPoint {
    float x, y;
} SDL_FPoint;

// ── Colour ───────────────────────────────────────────────────────────────
typedef struct SDL_Color {
    Uint8 r, g, b, a;
} SDL_Color;

// ── Opaque handle types ──────────────────────────────────────────────────
struct SDL_Window;
struct SDL_Renderer;
struct SDL_Texture;
struct SDL_Cursor;

typedef struct SDL_Surface {
    int w, h;
    void* pixels;
} SDL_Surface;

// ── Window flags (SDL3: Uint64 bitmask) ─────────────────────────────────
typedef Uint64 SDL_WindowFlags;
#define SDL_WINDOW_FULLSCREEN            ((SDL_WindowFlags)0x0000000000000001ULL)
#define SDL_WINDOW_RESIZABLE             ((SDL_WindowFlags)0x0000000000000020ULL)
#define SDL_WINDOW_BORDERLESS            ((SDL_WindowFlags)0x0000000000000010ULL)
#define SDL_WINDOW_ALWAYS_ON_TOP         ((SDL_WindowFlags)0x0000000000008000ULL)
#define SDL_WINDOW_HIGH_PIXEL_DENSITY    ((SDL_WindowFlags)0x0000000000002000ULL)
#define SDL_WINDOW_HIDDEN                ((SDL_WindowFlags)0x0000000000000008ULL)

#define SDL_WINDOWPOS_CENTERED ((int)0x2FFF0000)
#define SDL_WINDOWPOS_UNDEFINED ((int)0x1FFF0000)

// ── Init flags ───────────────────────────────────────────────────────────
typedef Uint32 SDL_InitFlags;
#define SDL_INIT_VIDEO  ((SDL_InitFlags)0x00000020u)
#define SDL_INIT_AUDIO  ((SDL_InitFlags)0x00000010u)
#define SDL_INIT_EVENTS ((SDL_InitFlags)0x00004000u)

// ── Blend modes ──────────────────────────────────────────────────────────
typedef Uint32 SDL_BlendMode;
#define SDL_BLENDMODE_NONE  ((SDL_BlendMode)0x00000000u)
#define SDL_BLENDMODE_BLEND ((SDL_BlendMode)0x00000001u)
#define SDL_BLENDMODE_ADD   ((SDL_BlendMode)0x00000002u)
#define SDL_BLENDMODE_MOD   ((SDL_BlendMode)0x00000004u)

// ── Message box ──────────────────────────────────────────────────────────
typedef Uint32 SDL_MessageBoxFlags;
#define SDL_MESSAGEBOX_ERROR       ((SDL_MessageBoxFlags)0x00000010u)
#define SDL_MESSAGEBOX_WARNING     ((SDL_MessageBoxFlags)0x00000020u)
#define SDL_MESSAGEBOX_INFORMATION ((SDL_MessageBoxFlags)0x00000040u)

bool SDL_ShowSimpleMessageBox(SDL_MessageBoxFlags flags, const char* title,
                               const char* message, SDL_Window* window);

// ── Core lifecycle ───────────────────────────────────────────────────────
void SDL_SetMainReady(void);
bool SDL_Init(SDL_InitFlags flags);
void SDL_Quit(void);
const char* SDL_GetError(void);
bool SDL_SetError(const char* fmt, ...);

// SDL3 packs (major, minor, micro) into one int: major*1000000+minor*1000+micro
int SDL_GetVersion(void);

// ── Window management ────────────────────────────────────────────────────
SDL_Window* SDL_CreateWindow(const char* title, int w, int h, SDL_WindowFlags flags);
void SDL_DestroyWindow(SDL_Window* window);
bool SDL_SetWindowPosition(SDL_Window* window, int x, int y);
bool SDL_GetWindowPosition(SDL_Window* window, int* x, int* y);
bool SDL_SetWindowSize(SDL_Window* window, int w, int h);
bool SDL_GetWindowSize(SDL_Window* window, int* w, int* h);
bool SDL_SetWindowTitle(SDL_Window* window, const char* title);
const char* SDL_GetWindowTitle(SDL_Window* window);
bool SDL_ShowWindow(SDL_Window* window);
bool SDL_HideWindow(SDL_Window* window);
bool SDL_RaiseWindow(SDL_Window* window);
bool SDL_MaximizeWindow(SDL_Window* window);
bool SDL_MinimizeWindow(SDL_Window* window);
bool SDL_RestoreWindow(SDL_Window* window);
bool SDL_StartTextInput(SDL_Window* window);
bool SDL_StopTextInput(SDL_Window* window);
float SDL_GetWindowDisplayScale(SDL_Window* window);
const char* SDL_GetCurrentVideoDriver(void);

// ── Displays ─────────────────────────────────────────────────────────────
typedef Uint32 SDL_DisplayID;
SDL_DisplayID SDL_GetPrimaryDisplay(void);
float SDL_GetDisplayContentScale(SDL_DisplayID displayID);
bool SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect* rect);
bool SDL_GetDisplayBounds(SDL_DisplayID displayID, SDL_Rect* rect);

// ── Cursors ──────────────────────────────────────────────────────────────
typedef enum SDL_SystemCursor {
    SDL_SYSTEM_CURSOR_DEFAULT,
    SDL_SYSTEM_CURSOR_TEXT,
    SDL_SYSTEM_CURSOR_WAIT,
    SDL_SYSTEM_CURSOR_CROSSHAIR,
    SDL_SYSTEM_CURSOR_PROGRESS,
    SDL_SYSTEM_CURSOR_NWSE_RESIZE,
    SDL_SYSTEM_CURSOR_NESW_RESIZE,
    SDL_SYSTEM_CURSOR_EW_RESIZE,
    SDL_SYSTEM_CURSOR_NS_RESIZE,
    SDL_SYSTEM_CURSOR_MOVE,
    SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    SDL_SYSTEM_CURSOR_POINTER,
    SDL_SYSTEM_CURSOR_COUNT
} SDL_SystemCursor;

SDL_Cursor* SDL_CreateSystemCursor(SDL_SystemCursor id);
bool SDL_SetCursor(SDL_Cursor* cursor);
void SDL_DestroyCursor(SDL_Cursor* cursor);

// ── Renderer ─────────────────────────────────────────────────────────────
SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
void SDL_DestroyRenderer(SDL_Renderer* renderer);
bool SDL_SetRenderDrawColor(SDL_Renderer* renderer, Uint8 r, Uint8 g, Uint8 b, Uint8 a);
bool SDL_SetRenderDrawBlendMode(SDL_Renderer* renderer, SDL_BlendMode mode);
bool SDL_SetRenderVSync(SDL_Renderer* renderer, int vsync);
bool SDL_RenderClear(SDL_Renderer* renderer);
bool SDL_RenderPresent(SDL_Renderer* renderer);
bool SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_FRect* rect);
bool SDL_RenderRect(SDL_Renderer* renderer, const SDL_FRect* rect);
bool SDL_RenderLine(SDL_Renderer* renderer, float x1, float y1, float x2, float y2);
bool SDL_RenderPoint(SDL_Renderer* renderer, float x, float y);
bool SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture* texture,
                        const SDL_FRect* srcrect, const SDL_FRect* dstrect);
bool SDL_SetRenderClipRect(SDL_Renderer* renderer, const SDL_Rect* rect);
bool SDL_SetRenderViewport(SDL_Renderer* renderer, const SDL_Rect* rect);

// ── Textures / surfaces ──────────────────────────────────────────────────
SDL_Texture* SDL_CreateTextureFromSurface(SDL_Renderer* renderer, SDL_Surface* surface);
void SDL_DestroyTexture(SDL_Texture* texture);
bool SDL_SetTextureBlendMode(SDL_Texture* texture, SDL_BlendMode mode);
void SDL_DestroySurface(SDL_Surface* surface);

// ── Keyboard / modifiers ─────────────────────────────────────────────────
typedef Sint32 SDL_Keycode;
typedef Sint32 SDL_Scancode;
typedef Uint16 SDL_Keymod;
#define SDL_KMOD_NONE   ((SDL_Keymod)0x0000)
#define SDL_KMOD_LSHIFT ((SDL_Keymod)0x0001)
#define SDL_KMOD_RSHIFT ((SDL_Keymod)0x0002)
#define SDL_KMOD_LCTRL  ((SDL_Keymod)0x0040)
#define SDL_KMOD_RCTRL  ((SDL_Keymod)0x0080)
#define SDL_KMOD_LALT   ((SDL_Keymod)0x0100)
#define SDL_KMOD_RALT   ((SDL_Keymod)0x0200)
#define SDL_KMOD_SHIFT  ((SDL_Keymod)(SDL_KMOD_LSHIFT|SDL_KMOD_RSHIFT))
#define SDL_KMOD_CTRL   ((SDL_Keymod)(SDL_KMOD_LCTRL|SDL_KMOD_RCTRL))
#define SDL_KMOD_ALT    ((SDL_Keymod)(SDL_KMOD_LALT|SDL_KMOD_RALT))
#define SDL_KMOD_GUI    ((SDL_Keymod)0x0400)

SDL_Keymod SDL_GetModState(void);
const char* SDL_GetKeyName(SDL_Keycode key);

// ── Events ───────────────────────────────────────────────────────────────
typedef Uint32 SDL_EventType;
#define SDL_EVENT_QUIT                     0x100u
#define SDL_EVENT_WINDOW_SHOWN             0x202u
#define SDL_EVENT_WINDOW_EXPOSED           0x205u
#define SDL_EVENT_WINDOW_RESIZED           0x207u
#define SDL_EVENT_WINDOW_RESTORED          0x20Bu
#define SDL_EVENT_WINDOW_FOCUS_GAINED      0x20Fu
#define SDL_EVENT_WINDOW_CLOSE_REQUESTED   0x213u
#define SDL_EVENT_KEY_DOWN                 0x300u
#define SDL_EVENT_KEY_UP                   0x301u
#define SDL_EVENT_TEXT_INPUT               0x303u
#define SDL_EVENT_MOUSE_MOTION             0x400u
#define SDL_EVENT_MOUSE_BUTTON_DOWN        0x401u
#define SDL_EVENT_MOUSE_BUTTON_UP          0x402u
#define SDL_EVENT_MOUSE_WHEEL              0x403u

typedef struct SDL_CommonEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
} SDL_CommonEvent;

typedef struct SDL_WindowEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    Sint32 data1;
    Sint32 data2;
} SDL_WindowEvent;

typedef struct SDL_KeyboardEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    Uint32 which;
    SDL_Scancode scancode;
    SDL_Keycode key;
    SDL_Keymod mod;
    Uint16 raw;
    bool down;
    bool repeat;
} SDL_KeyboardEvent;

typedef struct SDL_TextInputEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    const char* text;
} SDL_TextInputEvent;

typedef struct SDL_MouseMotionEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    Uint32 which;
    Uint32 state;
    float x, y;
    float xrel, yrel;
} SDL_MouseMotionEvent;

typedef struct SDL_MouseButtonEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    Uint32 which;
    Uint8 button;
    bool down;
    Uint8 clicks;
    Uint8 padding;
    float x, y;
} SDL_MouseButtonEvent;

typedef enum SDL_MouseWheelDirection {
    SDL_MOUSEWHEEL_NORMAL,
    SDL_MOUSEWHEEL_FLIPPED
} SDL_MouseWheelDirection;

typedef struct SDL_MouseWheelEvent {
    Uint32 type;
    Uint32 reserved;
    Uint64 timestamp;
    Uint32 windowID;
    Uint32 which;
    float x, y;
    SDL_MouseWheelDirection direction;
    float mouse_x, mouse_y;
} SDL_MouseWheelEvent;

typedef union SDL_Event {
    Uint32 type;
    SDL_CommonEvent common;
    SDL_WindowEvent window;
    SDL_KeyboardEvent key;
    SDL_TextInputEvent text;
    SDL_MouseMotionEvent motion;
    SDL_MouseButtonEvent button;
    SDL_MouseWheelEvent wheel;
    Uint8 padding[128];
} SDL_Event;

bool SDL_PollEvent(SDL_Event* event);

#ifdef __cplusplus
}
#endif

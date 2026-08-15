// thirdparty/sdl3-stub/src/sdl3_stub.cpp
//
// Headless implementation of the SDL3 / SDL3_ttf / SDL3_image surface
// declared under thirdparty/sdl3-stub/include/. Nothing here talks to a
// real display, font rasteriser, or image decoder — every call is a no-op
// or returns plausible fake data, so that code written against the real
// SDL3 API (src/builtins/gui.cpp) can run to completion without a GPU,
// window system, or the real libraries installed.
//
// Environment variables (see HANDOFF.md / CLAUDE.md):
//   NY_STUB_AUTOQUIT=<n>    After n consecutive *empty* SDL_PollEvent polls
//                           (no other event pending), synthesize exactly one
//                           SDL_EVENT_QUIT and never again (latched). Lets
//                           GUI/IDE event loops terminate headlessly.
//   NY_STUB_DPI_SCALE=<f>   Fake content/display scale returned by the
//                           display- and window-scale queries.
//
// Every "object" (window, renderer, texture, surface, font, cursor) is a
// heap-allocated opaque struct with a non-null address, so identity/pointer
// checks in calling code behave sanely; nothing is ever double-freed because
// each destroy function nulls out via the caller's own handle registries in
// gui.cpp (this file does not need to track that).

#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>
#include <SDL3_image/SDL_image.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdarg>
#include <string>
#include <atomic>

// ── Opaque struct definitions ───────────────────────────────────────────
struct SDL_Window   { std::string title; int w = 0, h = 0; int x = 0, y = 0; };
struct SDL_Renderer { SDL_Window* window = nullptr; };
struct SDL_Texture  { int w = 0, h = 0; };
struct SDL_Cursor   { SDL_SystemCursor id = SDL_SYSTEM_CURSOR_DEFAULT; };
struct TTF_Font     { float ptsize = 16.0f; TTF_FontStyleFlags style = TTF_STYLE_NORMAL; };

// ── Error string ─────────────────────────────────────────────────────────
static thread_local std::string g_last_error;

bool SDL_SetError(const char* fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    g_last_error = buf;
    return false;
}

const char* SDL_GetError(void) {
    return g_last_error.c_str();
}

// ── Message box (headless: print to stderr) ─────────────────────────────
bool SDL_ShowSimpleMessageBox(SDL_MessageBoxFlags flags, const char* title,
                               const char* message, SDL_Window* window) {
    (void)flags; (void)window;
    fprintf(stderr, "[SDL3-stub] messagebox: %s: %s\n",
            title ? title : "", message ? message : "");
    return true;
}

// ── Core lifecycle ───────────────────────────────────────────────────────
static bool g_inited = false;

void SDL_SetMainReady(void) { /* no-op: headless, no real main entry to hand off */ }

bool SDL_Init(SDL_InitFlags flags) {
    (void)flags;
    g_inited = true;
    return true;
}

void SDL_Quit(void) {
    g_inited = false;
}

int SDL_GetVersion(void) {
    // Fake "3.2.0" — matches the shape real SDL3 uses (major*1e6+minor*1e3+micro).
    return 3 * 1000000 + 2 * 1000 + 0;
}

// ── Window management ─────────────────────────────────────────────────────
SDL_Window* SDL_CreateWindow(const char* title, int w, int h, SDL_WindowFlags flags) {
    (void)flags;
    auto* win = new SDL_Window();
    win->title = title ? title : "";
    win->w = w;
    win->h = h;
    win->x = 0;
    win->y = 0;
    return win;
}

void SDL_DestroyWindow(SDL_Window* window) {
    delete window;
}

bool SDL_SetWindowPosition(SDL_Window* window, int x, int y) {
    if (!window) return false;
    window->x = x;
    window->y = y;
    return true;
}

bool SDL_GetWindowPosition(SDL_Window* window, int* x, int* y) {
    if (!window) return false;
    if (x) *x = window->x;
    if (y) *y = window->y;
    return true;
}

bool SDL_SetWindowSize(SDL_Window* window, int w, int h) {
    if (!window) return false;
    window->w = w;
    window->h = h;
    return true;
}

bool SDL_GetWindowSize(SDL_Window* window, int* w, int* h) {
    if (!window) return false;
    if (w) *w = window->w;
    if (h) *h = window->h;
    return true;
}

bool SDL_SetWindowTitle(SDL_Window* window, const char* title) {
    if (!window) return false;
    window->title = title ? title : "";
    return true;
}

const char* SDL_GetWindowTitle(SDL_Window* window) {
    static const char* empty = "";
    return window ? window->title.c_str() : empty;
}

bool SDL_ShowWindow(SDL_Window* window)   { return window != nullptr; }
bool SDL_HideWindow(SDL_Window* window)   { return window != nullptr; }
bool SDL_RaiseWindow(SDL_Window* window)  { return window != nullptr; }
bool SDL_MaximizeWindow(SDL_Window* window) { return window != nullptr; }
bool SDL_MinimizeWindow(SDL_Window* window) { return window != nullptr; }
bool SDL_RestoreWindow(SDL_Window* window)  { return window != nullptr; }
bool SDL_StartTextInput(SDL_Window* window) { return window != nullptr; }
bool SDL_StopTextInput(SDL_Window* window)  { return window != nullptr; }

static float dpi_scale_from_env() {
    const char* s = getenv("NY_STUB_DPI_SCALE");
    if (!s || !*s) return 1.0f;
    float f = (float)atof(s);
    return f > 0.0f ? f : 1.0f;
}

float SDL_GetWindowDisplayScale(SDL_Window* window) {
    (void)window;
    return dpi_scale_from_env();
}

const char* SDL_GetCurrentVideoDriver(void) {
    return "ny-stub";
}

// ── Displays ───────────────────────────────────────────────────────────
SDL_DisplayID SDL_GetPrimaryDisplay(void) {
    return 1u;
}

float SDL_GetDisplayContentScale(SDL_DisplayID displayID) {
    (void)displayID;
    return dpi_scale_from_env();
}

bool SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect* rect) {
    (void)displayID;
    if (!rect) return false;
    rect->x = 0; rect->y = 0; rect->w = 1920; rect->h = 1080;
    return true;
}

bool SDL_GetDisplayBounds(SDL_DisplayID displayID, SDL_Rect* rect) {
    return SDL_GetDisplayUsableBounds(displayID, rect);
}

// ── Cursors ────────────────────────────────────────────────────────────
SDL_Cursor* SDL_CreateSystemCursor(SDL_SystemCursor id) {
    auto* c = new SDL_Cursor();
    c->id = id;
    return c;
}

bool SDL_SetCursor(SDL_Cursor* cursor) {
    (void)cursor;
    return true;
}

void SDL_DestroyCursor(SDL_Cursor* cursor) {
    delete cursor;
}

// ── Renderer ───────────────────────────────────────────────────────────
SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name) {
    (void)name;
    auto* r = new SDL_Renderer();
    r->window = window;
    return r;
}

void SDL_DestroyRenderer(SDL_Renderer* renderer) {
    delete renderer;
}

bool SDL_SetRenderDrawColor(SDL_Renderer* renderer, Uint8, Uint8, Uint8, Uint8) {
    return renderer != nullptr;
}

bool SDL_SetRenderDrawBlendMode(SDL_Renderer* renderer, SDL_BlendMode) {
    return renderer != nullptr;
}

bool SDL_SetRenderVSync(SDL_Renderer* renderer, int) {
    return renderer != nullptr;
}

bool SDL_RenderClear(SDL_Renderer* renderer) {
    return renderer != nullptr;
}

bool SDL_RenderPresent(SDL_Renderer* renderer) {
    return renderer != nullptr;
}

bool SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_FRect*) {
    return renderer != nullptr;
}

bool SDL_RenderRect(SDL_Renderer* renderer, const SDL_FRect*) {
    return renderer != nullptr;
}

bool SDL_RenderLine(SDL_Renderer* renderer, float, float, float, float) {
    return renderer != nullptr;
}

bool SDL_RenderPoint(SDL_Renderer* renderer, float, float) {
    return renderer != nullptr;
}

bool SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture*, const SDL_FRect*, const SDL_FRect*) {
    return renderer != nullptr;
}

bool SDL_SetRenderClipRect(SDL_Renderer* renderer, const SDL_Rect*) {
    return renderer != nullptr;
}

bool SDL_SetRenderViewport(SDL_Renderer* renderer, const SDL_Rect*) {
    return renderer != nullptr;
}

// ── Textures / surfaces ──────────────────────────────────────────────────
SDL_Texture* SDL_CreateTextureFromSurface(SDL_Renderer* renderer, SDL_Surface* surface) {
    (void)renderer;
    auto* t = new SDL_Texture();
    if (surface) { t->w = surface->w; t->h = surface->h; }
    return t;
}

void SDL_DestroyTexture(SDL_Texture* texture) {
    delete texture;
}

bool SDL_SetTextureBlendMode(SDL_Texture* texture, SDL_BlendMode) {
    return texture != nullptr;
}

void SDL_DestroySurface(SDL_Surface* surface) {
    if (!surface) return;
    free(surface->pixels);
    delete surface;
}

// ── Keyboard ───────────────────────────────────────────────────────────
SDL_Keymod SDL_GetModState(void) {
    return SDL_KMOD_NONE;
}

const char* SDL_GetKeyName(SDL_Keycode key) {
    // The stub never synthesizes real key-down events with printable names
    // (only a latched QUIT is ever produced), so this is only reachable if
    // calling code invents its own SDL_Event by hand. Return a stable,
    // harmless placeholder rather than crashing on an unmapped keycode.
    (void)key;
    static thread_local std::string name;
    name = "Unknown";
    return name.c_str();
}

// ── Events ───────────────────────────────────────────────────────────────
// NY_STUB_AUTOQUIT=<n>: after n consecutive empty polls, deliver ONE
// SDL_EVENT_QUIT and never again (latched), so `while (SDL_PollEvent(&e))`
// drain loops terminate instead of spinning forever headlessly.
static long autoquit_threshold() {
    static long cached = -2; // -2 = not yet read
    if (cached == -2) {
        const char* s = getenv("NY_STUB_AUTOQUIT");
        cached = (s && *s) ? atol(s) : -1; // -1 = disabled
    }
    return cached;
}

bool SDL_PollEvent(SDL_Event* event) {
    static std::atomic<long> empty_polls{0};
    static std::atomic<bool> quit_delivered{false};

    long threshold = autoquit_threshold();
    if (threshold >= 0 && !quit_delivered.load()) {
        long n = ++empty_polls;
        if (n >= threshold) {
            quit_delivered.store(true);
            if (event) {
                memset(event, 0, sizeof(SDL_Event));
                event->type = SDL_EVENT_QUIT;
            }
            return true;
        }
    }
    (void)event;
    return false; // no events pending
}

// ── SDL3_ttf ───────────────────────────────────────────────────────────
bool TTF_Init(void) { return true; }
void TTF_Quit(void) {}

TTF_Font* TTF_OpenFont(const char* file, float ptsize) {
    (void)file;
    auto* f = new TTF_Font();
    f->ptsize = ptsize > 0 ? ptsize : 16.0f;
    return f;
}

void TTF_CloseFont(TTF_Font* font) {
    delete font;
}

void TTF_SetFontStyle(TTF_Font* font, TTF_FontStyleFlags style) {
    if (font) font->style = style;
}

TTF_FontStyleFlags TTF_GetFontStyle(TTF_Font* font) {
    return font ? font->style : TTF_STYLE_NORMAL;
}

SDL_Surface* TTF_RenderText_Blended(TTF_Font* font, const char* text, size_t text_len,
                                     SDL_Color fg) {
    (void)fg;
    size_t len = text_len ? text_len : (text ? strlen(text) : 0);
    int ptsize = font ? (int)font->ptsize : 16;
    auto* surf = new SDL_Surface();
    // Plausible fake glyph-run metrics: ~0.6em advance per character.
    surf->w = (int)len > 0 ? (int)(len * (size_t)(ptsize * 0.6 + 0.5)) : 1;
    surf->h = ptsize > 0 ? ptsize + 4 : 16;
    if (surf->w < 1) surf->w = 1;
    size_t bytes = (size_t)surf->w * (size_t)surf->h * 4;
    surf->pixels = bytes ? calloc(1, bytes) : nullptr;
    return surf;
}

bool TTF_GetStringSize(TTF_Font* font, const char* text, size_t text_len,
                        int* w, int* h) {
    size_t len = text_len ? text_len : (text ? strlen(text) : 0);
    int ptsize = font ? (int)font->ptsize : 16;
    if (w) *w = (int)(len * (size_t)(ptsize * 0.6 + 0.5));
    if (h) *h = ptsize > 0 ? ptsize + 4 : 16;
    return true;
}

// ── SDL3_image ────────────────────────────────────────────────────────
SDL_Surface* IMG_Load(const char* file) {
    (void)file;
    // No real decoder available headlessly: report failure the same way the
    // real library does for an unreadable/unsupported file, rather than
    // fabricating pixel data callers might mistake for a real image.
    g_last_error = "IMG_Load: image loading unavailable in headless SDL3 stub";
    return nullptr;
}

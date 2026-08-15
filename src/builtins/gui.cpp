#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wunused-function"
// builtins/gui.cpp
// SDL3 + SDL3_ttf + SDL3_image GUI backend for Nython
// ─────────────────────────────────────────────────────────────────────────────
// Implements all gui_* builtins called by lib/gui.ny.
// Link: -lSDL3 -lSDL3_ttf -lSDL3_image
// ─────────────────────────────────────────────────────────────────────────────

#include "NythonExecutor.hpp"
#include "builtins/gui.hpp"

using namespace nython::kernel;
using nython::kernel::bigint;

// SDL_MAIN_HANDLED is defined via -DSDL_MAIN_HANDLED in the build flags
// and also guarded in platform_compat.hpp — do not redefine here.
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3_ttf/SDL_ttf.h>
#include <SDL3_image/SDL_image.h>
#include <unordered_map>
#include <utility>      // std::pair  (used by the metrics cache)
#include <functional>   // std::hash  (used by the cache key hashers)
#include <string>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#include <cmath>
#include <algorithm>

// ── Handle registries ───────────────────────────────────────────────────────
static int next_win_id  = 1;
static int next_font_id = 1;
static int next_img_id  = 1;

struct WinEntry { SDL_Window* win; SDL_Renderer* ren; };
static std::unordered_map<int, WinEntry>      g_windows;
static std::unordered_map<int, TTF_Font*>     g_fonts;
static std::unordered_map<int, SDL_Texture*>  g_images;

// ── Rendered-text cache ─────────────────────────────────────────────────────
// Keyed by font handle + packed RGBA + the string itself.
struct TextKey {
    int         font;
    Uint32      rgba;
    std::string text;
    bool operator==(const TextKey& o) const {
        return font==o.font && rgba==o.rgba && text==o.text;
    }
};
struct TextKeyHash {
    size_t operator()(const TextKey& k) const {
        size_t h = std::hash<std::string>{}(k.text);
        h ^= std::hash<int>{}(k.font)      + 0x9e3779b9 + (h<<6) + (h>>2);
        h ^= std::hash<Uint32>{}(k.rgba)   + 0x9e3779b9 + (h<<6) + (h>>2);
        return h;
    }
};
struct TextEntry { SDL_Texture* tex; int w; int h; };
static std::unordered_map<TextKey, TextEntry, TextKeyHash> g_text_cache;
static const size_t kTextCacheMax = 4096;

// Metrics cache: (font handle, string) -> (w, h)
struct MeasureKey {
    int         font;
    std::string text;
    bool operator==(const MeasureKey& o) const { return font==o.font && text==o.text; }
};
struct MeasureKeyHash {
    size_t operator()(const MeasureKey& k) const {
        size_t h = std::hash<std::string>{}(k.text);
        h ^= std::hash<int>{}(k.font) + 0x9e3779b9 + (h<<6) + (h>>2);
        return h;
    }
};
static std::unordered_map<MeasureKey, std::pair<int,int>, MeasureKeyHash> g_measure_cache;
static const size_t kMeasureCacheMax = 8192;
static void clear_text_cache() {
    for(auto& kv : g_text_cache) if(kv.second.tex) SDL_DestroyTexture(kv.second.tex);
    g_text_cache.clear();
}

static bool g_sdl_inited  = false;
static bool g_sdl_ok      = false;   // true only if SDL_Init succeeded
static std::string g_sdl_error;      // last SDL error string for Nython scripts

// ── Error reporting ──────────────────────────────────────────────────────────
// On Windows GUI builds (type=0, no console), fprintf(stderr) is invisible.
// Use SDL_ShowSimpleMessageBox so the user always sees what went wrong.
static void nython_gui_error(const std::string& msg) {
    fprintf(stderr, "[Nython] %s\n", msg.c_str());
    // Show a message box — works before SDL is fully initialised
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nython — Cannot open window",
                             msg.c_str(), nullptr);
}

// Only called from gui_create_window — not from every gui_ dispatch
static bool ensure_sdl_for_window() {
    if (g_sdl_inited) return g_sdl_ok;
    g_sdl_inited = true;
    // SDL_SetMainReady(): required when SDL_MAIN_HANDLED is defined.
    SDL_SetMainReady();
    // Let SDL3 auto-select the best renderer for this platform.
    // On Windows: Direct3D 11 (native, fast, correct colors).
    // On macOS:   Metal.
    // On Linux:   OpenGL or Vulkan.
    // Do NOT force "opengl" on Windows — the OpenGL renderer renders
    // to a white/invisible buffer on many Windows GPU configurations.
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        const char* sdl_err = SDL_GetError();
        g_sdl_error = (sdl_err && *sdl_err)
            ? std::string("SDL_Init failed: ") + sdl_err
            : "SDL_Init failed (no error detail — check SDL3.dll is present and correct architecture)";
        nython_gui_error(g_sdl_error);
        return false;
    }
    if (!TTF_Init()) {
        fprintf(stderr, "[Nython] TTF_Init failed: %s\n", SDL_GetError());
        // Non-fatal — continue without font rendering
    }
    g_sdl_ok = true;
    return true;
}

// ── Value helpers ───────────────────────────────────────────────────────────
static inline int64_t bi64(bigint bi) {
    if (bi == 0) return 0;
    bool neg = bi < 0; if (neg) bi = -bi;
    int64_t r = 0; int shift = 0;
    while (bi > 0) { r |= ((int64_t)(bi % 256)) << shift; shift += 8; bi /= 256; }
    return neg ? -r : r;
}
static int    VI(const Value& v) { return v.type==ValueType::INTEGER?(int)bi64(v.value.i):v.type==ValueType::DOUBLE?(int)v.value.d:0; }
static float  VF(const Value& v) { return (float)(v.type==ValueType::DOUBLE?(double)v.value.d:v.type==ValueType::INTEGER?(double)bi64(v.value.i):0.0); }
static Uint8  VU(const Value& v) { return (Uint8)std::clamp(VI(v),0,255); }
static std::string VS(NythonExecutor& E, const Value& v) { return E.getStringValue(v); }

// ── Event dict builder ──────────────────────────────────────────────────────
static Value make_evt(NythonExecutor& E, const std::string& type,
                      int x=0,int y=0,int btn=0,const std::string& key="",
                      int kc=0,const std::string& txt="",int delta=0,int w=0,int h=0,
                      bool ctrl=false,bool shift=false,bool alt=false) {
    auto* o = new Object((Runnable*)E.runner, "event", Type::MAP);
    o->set("type",   E.makeStringValue(type));
    o->set("x",      Value(x));  o->set("y",     Value(y));
    o->set("button", Value(btn));o->set("key",   E.makeStringValue(key));
    o->set("keycode",Value(kc)); o->set("text",  E.makeStringValue(txt));
    o->set("delta",  Value(delta));o->set("w",   Value(w)); o->set("h", Value(h));
    o->set("ctrl",   Value(ctrl)); o->set("shift", Value(shift)); o->set("alt", Value(alt));
    return Value(static_cast<Collectable*>(o));
}

// ── Geometry helpers (SDL3 uses SDL_FRect for rendering) ─────────────────────
static void fill_rounded_rect(SDL_Renderer* r,float x,float y,float w,float h,float rad,Uint8 cr,Uint8 cg,Uint8 cb,Uint8 ca) {
    SDL_SetRenderDrawColor(r,cr,cg,cb,ca);
    SDL_SetRenderDrawBlendMode(r,SDL_BLENDMODE_BLEND);
    rad=std::min(rad,std::min(w/2,h/2));
    SDL_FRect rects[3]={{x+rad,y,w-2*rad,h},{x,y+rad,rad,h-2*rad},{x+w-rad,y+rad,rad,h-2*rad}};
    for(auto& rc:rects) SDL_RenderFillRect(r,&rc);
    float cx[4]={x+rad,x+w-rad-1,x+rad,x+w-rad-1};
    float cy[4]={y+rad,y+rad,y+h-rad-1,y+h-rad-1};
    for(int c=0;c<4;c++) for(int dy=-(int)rad;dy<=(int)rad;dy++){
        float dx=std::sqrt(rad*rad-(float)(dy*dy));
        SDL_RenderLine(r,cx[c]-dx,cy[c]+dy,cx[c]+dx,cy[c]+dy);
    }
}
static void draw_rounded_rect(SDL_Renderer* r,float x,float y,float w,float h,float rad,Uint8 cr,Uint8 cg,Uint8 cb,Uint8 ca,int bw) {
    (void)bw;
    SDL_SetRenderDrawColor(r,cr,cg,cb,ca);
    rad=std::min(rad,std::min(w/2,h/2));
    SDL_RenderLine(r,x+rad,y,x+w-rad,y);
    SDL_RenderLine(r,x+rad,y+h-1,x+w-rad,y+h-1);
    SDL_RenderLine(r,x,y+rad,x,y+h-rad);
    SDL_RenderLine(r,x+w-1,y+rad,x+w-1,y+h-rad);
    float ccx[4]={x+rad,x+w-rad-1,x+rad,x+w-rad-1};
    float ccy[4]={y+rad,y+rad,y+h-rad-1,y+h-rad-1};
    for(int c=0;c<4;c++) for(int a=0;a<90;a++){
        double ar=a*M_PI/180.0;float dx=(float)(rad*cos(ar)),dy=(float)(rad*sin(ar));
        float px,py;
        if(c==0){px=ccx[0]-dx;py=ccy[0]-dy;}else if(c==1){px=ccx[1]+dx;py=ccy[1]-dy;}
        else if(c==2){px=ccx[2]-dx;py=ccy[2]+dy;}else{px=ccx[3]+dx;py=ccy[3]+dy;}
        SDL_RenderPoint(r,px,py);
    }
}
static void fill_circle_sdl(SDL_Renderer* r,float cx,float cy,float rad,Uint8 cr,Uint8 cg,Uint8 cb,Uint8 ca){
    SDL_SetRenderDrawColor(r,cr,cg,cb,ca);
    for(int dy=-(int)rad;dy<=(int)rad;dy++){
        float dx=std::sqrt(rad*rad-(float)(dy*dy));
        SDL_RenderLine(r,cx-dx,cy+dy,cx+dx,cy+dy);
    }
}
static void draw_circle_sdl(SDL_Renderer* r,float cx,float cy,float rad,Uint8 cr,Uint8 cg,Uint8 cb,Uint8 ca){
    SDL_SetRenderDrawColor(r,cr,cg,cb,ca);
    int ix=(int)rad,iy=0,err=0;
    while(ix>=iy){
        SDL_RenderPoint(r,cx+ix,cy+iy);SDL_RenderPoint(r,cx+iy,cy+ix);
        SDL_RenderPoint(r,cx-iy,cy+ix);SDL_RenderPoint(r,cx-ix,cy+iy);
        SDL_RenderPoint(r,cx-ix,cy-iy);SDL_RenderPoint(r,cx-iy,cy-ix);
        SDL_RenderPoint(r,cx+iy,cy-ix);SDL_RenderPoint(r,cx+ix,cy-iy);
        iy++;err+=1+2*iy;if(2*(err-ix)+1>0){ix--;err+=1-2*ix;}
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// DISPATCH
// ═════════════════════════════════════════════════════════════════════════════
Value dispatch_gui(NythonExecutor& E,const std::string& name,std::vector<Value>& args,Context* ctx) {
    (void)ctx;
    if(name.size()<4||name.substr(0,4)!="gui_") return UNDEFINED_VALUE;
    // NOTE: SDL is NOT initialised here — only gui_create_window triggers init.
    // This prevents SDL_Init from running at import time before a display is ready.

    // gui_get_error() -> string: surface last SDL error to Nython scripts
    if(name=="gui_get_error") return E.makeStringValue(g_sdl_error);

    // gui_sdl_version() -> string: returns SDL3 runtime version (e.g. "3.2.4")
    // Useful to confirm SDL3.dll is loaded correctly on Windows.
    if(name=="gui_sdl_version"){
        int v=SDL_GetVersion();
        int major=v/1000000, minor=(v/1000)%1000, patch=v%1000;
        return E.makeStringValue(std::to_string(major)+"."+std::to_string(minor)+"."+std::to_string(patch));
    }

    // ── WINDOW ──────────────────────────────────────────────────────────
    // gui_create_window(title, x, y, w, h, flags) -> handle
    if(name=="gui_create_window"){
        if(args.size()<6){
            // Previously returned NONE silently, leaving g_sdl_error empty — which
            // made gui.ny report a phantom "SDL_CreateWindow returned NULL" failure.
            g_sdl_error = "gui_create_window() needs 6 arguments "
                          "(title, x, y, w, h, flags) but got "
                          + std::to_string(args.size());
            nython_gui_error(g_sdl_error);
            return NONE_VALUE;
        }
        if(!ensure_sdl_for_window()){
            return NONE_VALUE;
        }
        std::string title=VS(E,args[0]);
        int x=VI(args[1]),y=VI(args[2]),w=VI(args[3]),h=VI(args[4]),fl=VI(args[5]);
        // Guard against non-numeric / zero dimensions (e.g. arguments passed in the
        // wrong order). SDL3 will happily produce a 0-sized or failed window here,
        // which is very hard to diagnose from the Nython side.
        if(w<=0||h<=0){
            fprintf(stderr,"[Nython] Invalid window size %dx%d — falling back to 640x480\n",w,h);
            if(w<=0) w=640;
            if(h<=0) h=480;
        }
        // Do NOT use SDL_WINDOW_OPENGL here — that flag means "I will manage OpenGL
        // myself via SDL_GL_CreateContext". SDL_CreateRenderer manages its own context.
        // Using SDL_WINDOW_OPENGL + SDL_CreateRenderer("opengl") causes a context
        // conflict and makes rendering unreliable (text invisible, crashes).
        SDL_WindowFlags sf = 0;
        if(fl&1) sf|=SDL_WINDOW_RESIZABLE;
        if(fl&2) sf|=SDL_WINDOW_BORDERLESS;
        if(fl&4) sf|=SDL_WINDOW_ALWAYS_ON_TOP;
        SDL_Window* win=SDL_CreateWindow(title.c_str(),w,h,sf);
        if(!win){
            const char* sdl_err = SDL_GetError();
            const char* drv     = SDL_GetCurrentVideoDriver();
            std::string where = std::string(" [video driver: ")
                              + (drv && *drv ? drv : "none") + ", size "
                              + std::to_string(w) + "x" + std::to_string(h) + "]";
            g_sdl_error = (sdl_err && *sdl_err)
                ? std::string("SDL_CreateWindow failed: ") + sdl_err + where
                : std::string("SDL_CreateWindow failed with no SDL error") + where;
            nython_gui_error(g_sdl_error);
            return NONE_VALUE;
        }
        if(x>=0&&y>=0) SDL_SetWindowPosition(win,x,y);
        else           SDL_SetWindowPosition(win,SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED);
        // Try auto-select first (Direct3D 11 on Windows), fall back to software
        SDL_Renderer* ren = SDL_CreateRenderer(win, NULL);
        if(!ren){
            fprintf(stderr,"[Nython] Hardware renderer failed (%s), trying software...\n",SDL_GetError());
            ren = SDL_CreateRenderer(win, "software");
        }
        if(!ren){
            const char* sdl_err = SDL_GetError();
            g_sdl_error = (sdl_err && *sdl_err)
                ? std::string("SDL_CreateRenderer failed: ") + sdl_err
                : "SDL_CreateRenderer failed — no rendering backend available";
            nython_gui_error(g_sdl_error);
            SDL_DestroyWindow(win);
            return NONE_VALUE;
        }
        SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);
        // VSync: optional — don't fail if unsupported
        SDL_SetRenderVSync(ren, 1);
        // Make sure the window is actually mapped and in front. Harmless when it
        // already is, but avoids an invisible window on some window managers.
        SDL_ShowWindow(win);
        SDL_RaiseWindow(win);
        // Enable text input events (SDL3: per-window)
        SDL_StartTextInput(win);
        int id=next_win_id++;
        g_windows[id]={win,ren};
        return Value(id);
    }
    // gui_set_cursor(name) -> bool.  Named system cursors, created lazily and
    // cached; SDL owns them until SDL_Quit.
    // gui_display_scale() -> float.  Content scale of the primary display: 1.0
    // on a standard monitor, 2.0 on a Retina/4K panel. Nothing queried this, so
    // every size in the UI was a raw pixel count and the whole interface
    // rendered at half size (and text blurry) on a HiDPI screen.
    // ── Immediate-mode ID hashing ────────────────────────────────────────────
    // Dear ImGui derives a widget's identity from a hash of its label combined
    // with the enclosing ID stack, so a widget needs no persistent object — the
    // ID alone locates its state. That hash runs for EVERY widget EVERY frame,
    // so it is the one piece of the IM core that must not be interpreted.
    //
    // ImGui uses CRC32 with a seed; this uses FNV-1a 32-bit, which has the same
    // properties that matter here (good avalanche on short ASCII labels, seed
    // chaining for the ID stack) and needs no lookup table.
    //
    //   gui_hash_id(label)          -> id
    //   gui_hash_id(label, seed)    -> id chained under a parent scope
    //
    // ImGui's "###" convention is honoured: everything before it is display
    // text and is excluded from the hash, so a button whose caption changes
    // every frame ("Frame 12###status") keeps a stable identity.
    if(name=="gui_hash_id"){
        if(args.empty()) return Value((int64_t)0);
        std::string s0 = VS(E,args[0]);
        uint32_t seed = args.size()>=2 ? (uint32_t)VI(args[1]) : 0u;
        size_t start = 0;
        size_t hh = s0.find("###");
        if(hh != std::string::npos) start = hh;          // hash from ### onward
        uint32_t h = seed ? seed : 2166136261u;
        for(size_t i=start;i<s0.size();++i){
            h ^= (uint32_t)(unsigned char)s0[i];
            h *= 16777619u;
        }
        // "##" hides the suffix from display but keeps it in the hash, which is
        // already the case here since the whole string is hashed.
        return Value((int64_t)(h & 0x7fffffffu));
    }

    if(name=="gui_display_scale"){
        float sc = 1.0f;
        SDL_DisplayID d = SDL_GetPrimaryDisplay();
        if(d){
            float q = SDL_GetDisplayContentScale(d);
            if(q > 0.0f) sc = q;
        }
        return Value((double)sc);
    }

    // gui_window_scale() -> float.  Per-window scale, which can differ from the
    // primary display's when a window is dragged to a second monitor.
    if(name=="gui_window_scale"){
        float sc = 1.0f;
        int wid = args.empty() ? -1 : VI(args[0]);
        SDL_Window* w = nullptr;
        if(wid >= 0){
            auto it = g_windows.find(wid);
            if(it != g_windows.end()) w = it->second.win;
        } else if(!g_windows.empty()){
            w = g_windows.begin()->second.win;
        }
        if(w){
            float q = SDL_GetWindowDisplayScale(w);
            if(q > 0.0f) sc = q;
        }
        return Value((double)sc);
    }

    if(name=="gui_set_cursor"){
        if(args.empty()) return Value(false);
        std::string want = VS(E,args[0]);
        static const std::unordered_map<std::string, SDL_SystemCursor> kMap = {
            {"arrow",   SDL_SYSTEM_CURSOR_DEFAULT},
            {"default", SDL_SYSTEM_CURSOR_DEFAULT},
            {"ibeam",   SDL_SYSTEM_CURSOR_TEXT},
            {"text",    SDL_SYSTEM_CURSOR_TEXT},
            {"hand",    SDL_SYSTEM_CURSOR_POINTER},
            {"pointer", SDL_SYSTEM_CURSOR_POINTER},
            {"wait",    SDL_SYSTEM_CURSOR_WAIT},
            {"progress",SDL_SYSTEM_CURSOR_PROGRESS},
            {"crosshair",SDL_SYSTEM_CURSOR_CROSSHAIR},
            {"sizewe",  SDL_SYSTEM_CURSOR_EW_RESIZE},
            {"sizens",  SDL_SYSTEM_CURSOR_NS_RESIZE},
            {"move",    SDL_SYSTEM_CURSOR_MOVE},
            {"no",      SDL_SYSTEM_CURSOR_NOT_ALLOWED}
        };
        auto mit = kMap.find(want);
        if(mit == kMap.end()) return Value(false);
        static std::unordered_map<int, SDL_Cursor*> cache;
        int key = (int)mit->second;
        auto cit = cache.find(key);
        SDL_Cursor* cur = nullptr;
        if(cit != cache.end()) cur = cit->second;
        else { cur = SDL_CreateSystemCursor(mit->second); if(cur) cache[key] = cur; }
        if(!cur) return Value(false);
        SDL_SetCursor(cur);
        return Value(true);
    }
    if(name=="gui_get_display_size"){
        // Returns [w,h] of the usable primary display area, so callers can size
        // a window that actually fits the screen. Without this the IDE asked for
        // a fixed 1600x960 window, which Windows silently clamped on a smaller
        // display while the layout kept drawing at the unclamped size.
        int dw=0, dh=0;
        if(ensure_sdl_for_window()){
            SDL_DisplayID d = SDL_GetPrimaryDisplay();
            SDL_Rect r;
            if(d && SDL_GetDisplayUsableBounds(d,&r)){ dw=r.w; dh=r.h; }
            else if(d && SDL_GetDisplayBounds(d,&r)){ dw=r.w; dh=r.h; }
        }
        if(dw<=0||dh<=0){ dw=1280; dh=720; }
        auto* lst=new Object((Runnable*)E.runner,"list",Type::LIST);
        lst->set("0",Value(dw)); lst->set("1",Value(dh)); lst->set("__len__",Value(2));
        return Value((Collectable*)lst);
    }
    if(name=="gui_get_window_size"){
        int ww=0, hh=0;
        if(!args.empty()){
            auto it=g_windows.find(VI(args[0]));
            if(it!=g_windows.end()) SDL_GetWindowSize(it->second.win,&ww,&hh);
        }
        auto* lst=new Object((Runnable*)E.runner,"list",Type::LIST);
        lst->set("0",Value(ww)); lst->set("1",Value(hh)); lst->set("__len__",Value(2));
        return Value((Collectable*)lst);
    }
    if(name=="gui_set_window_size"){
        if(args.size()>=3){
            auto it=g_windows.find(VI(args[0]));
            if(it!=g_windows.end()) SDL_SetWindowSize(it->second.win,VI(args[1]),VI(args[2]));
        }
        return NONE_VALUE;
    }
    if(name=="gui_destroy_window"){
        if(args.empty()) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            SDL_StopTextInput(it->second.win);
            // Cached text textures belong to this renderer — destroy them BEFORE
            // the renderer goes away, otherwise they become dangling pointers.
            clear_text_cache();
            SDL_DestroyRenderer(it->second.ren);
            SDL_DestroyWindow(it->second.win);
            g_windows.erase(it);
            if(g_windows.empty()){ SDL_Quit(); g_sdl_inited=false; g_sdl_ok=false; }
        }
        return NONE_VALUE;
    }
    if(name=="gui_center_window"){
        if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_SetWindowPosition(it->second.win,SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED);}
        return NONE_VALUE;
    }
    if(name=="gui_maximize_window"){if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_MaximizeWindow(it->second.win);}return NONE_VALUE;}
    if(name=="gui_minimize_window"){if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_MinimizeWindow(it->second.win);}return NONE_VALUE;}
    if(name=="gui_restore_window") {if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_RestoreWindow(it->second.win);}return NONE_VALUE;}
    if(name=="gui_set_window_title"){
        if(args.size()>=2){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_SetWindowTitle(it->second.win,VS(E,args[1]).c_str());}
        return NONE_VALUE;
    }
    if(name=="gui_set_window_icon") return NONE_VALUE; // stub

    // ── RENDERING ───────────────────────────────────────────────────────
    if(name=="gui_clear"){
        if(args.size()<5) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){SDL_SetRenderDrawColor(it->second.ren,VU(args[1]),VU(args[2]),VU(args[3]),VU(args[4]));SDL_RenderClear(it->second.ren);}
        return NONE_VALUE;
    }
    if(name=="gui_present"){
        if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_RenderPresent(it->second.ren);}
        return NONE_VALUE;
    }
    // gui_fill_rect(handle, x, y, w, h, r, g, b, a)
    if(name=="gui_fill_rect"){
        if(args.size()<9) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            SDL_FRect rc={VF(args[1]),VF(args[2]),VF(args[3]),VF(args[4])};
            SDL_SetRenderDrawColor(it->second.ren,VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8]));
            SDL_SetRenderDrawBlendMode(it->second.ren,SDL_BLENDMODE_BLEND);
            SDL_RenderFillRect(it->second.ren,&rc);
        }
        return NONE_VALUE;
    }
    // gui_draw_rect(handle, x, y, w, h, r, g, b, a, border_w)
    if(name=="gui_draw_rect"){
        if(args.size()<10) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            SDL_SetRenderDrawColor(it->second.ren,VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8]));
            int bw=std::max(1,VI(args[9]));
            for(int i=0;i<bw;i++){SDL_FRect r2={VF(args[1])+(float)i,VF(args[2])+(float)i,VF(args[3])-2.0f*i,VF(args[4])-2.0f*i};SDL_RenderRect(it->second.ren,&r2);}
        }
        return NONE_VALUE;
    }
    // gui_fill_rounded_rect(handle, x, y, w, h, r, g, b, a, radius)
    if(name=="gui_fill_rounded_rect"){
        if(args.size()<10) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()) fill_rounded_rect(it->second.ren,VF(args[1]),VF(args[2]),VF(args[3]),VF(args[4]),VF(args[9]),VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8]));
        return NONE_VALUE;
    }
    // gui_draw_rounded_rect(handle, x, y, w, h, r, g, b, a, radius, border_w)
    if(name=="gui_draw_rounded_rect"){
        if(args.size()<11) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()) draw_rounded_rect(it->second.ren,VF(args[1]),VF(args[2]),VF(args[3]),VF(args[4]),VF(args[9]),VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8]),VI(args[10]));
        return NONE_VALUE;
    }
    // gui_draw_text(handle, text, x, y, font_handle, r, g, b, a)
    if(name=="gui_draw_text"){
        if(args.size()<9) return NONE_VALUE;
        auto wit=g_windows.find(VI(args[0]));
        auto fit=g_fonts.find(VI(args[4]));
        if(wit!=g_windows.end()&&fit!=g_fonts.end()){
            std::string text=VS(E,args[1]);
            if(text.size()==0) return NONE_VALUE;
            SDL_Color c={VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8])};
            // ── Glyph cache ────────────────────────────────────────────────
            // The IDE issues ~85 draw_text calls per frame, and previously each
            // one re-rasterised the string with TTF_RenderText_Blended and
            // re-uploaded a GPU texture, every frame, for text that rarely
            // changes. Cache by (font, colour, string) and reuse the texture.
            TextKey key{VI(args[4]),
                        ((Uint32)c.r<<24)|((Uint32)c.g<<16)|((Uint32)c.b<<8)|(Uint32)c.a,
                        text};
            TextEntry* entry=nullptr;
            auto cit=g_text_cache.find(key);
            if(cit!=g_text_cache.end()){
                entry=&cit->second;
            } else {
                SDL_Surface* surf=TTF_RenderText_Blended(fit->second,text.c_str(),0,c);
                if(!surf) return NONE_VALUE;
                SDL_Texture* tex=SDL_CreateTextureFromSurface(wit->second.ren,surf);
                int sw=surf->w, sh=surf->h;
                SDL_DestroySurface(surf);
                if(!tex) return NONE_VALUE;
                // Text textures have alpha — without this the text is invisible.
                SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
                // Bound the cache so long editing sessions cannot grow without limit.
                if(g_text_cache.size()>=kTextCacheMax) clear_text_cache();
                entry=&(g_text_cache[key]={tex,sw,sh});
            }
            SDL_FRect dst={VF(args[2]),VF(args[3]),(float)entry->w,(float)entry->h};
            SDL_RenderTexture(wit->second.ren,entry->tex,nullptr,&dst);
        }
        return NONE_VALUE;
    }
    // gui_draw_image(handle, image_handle, x, y, w, h)
    if(name=="gui_draw_image"){
        if(args.size()<6) return NONE_VALUE;
        auto wit=g_windows.find(VI(args[0]));
        auto iit=g_images.find(VI(args[1]));
        if(wit!=g_windows.end()&&iit!=g_images.end()){
            SDL_FRect dst={VF(args[2]),VF(args[3]),VF(args[4]),VF(args[5])};
            SDL_RenderTexture(wit->second.ren,iit->second,nullptr,&dst);
        }
        return NONE_VALUE;
    }
    // gui_draw_line(handle, x1, y1, x2, y2, r, g, b, a, thickness)
    if(name=="gui_draw_line"){
        if(args.size()<10) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            SDL_SetRenderDrawColor(it->second.ren,VU(args[5]),VU(args[6]),VU(args[7]),VU(args[8]));
            SDL_SetRenderDrawBlendMode(it->second.ren,SDL_BLENDMODE_BLEND);
            float x1=VF(args[1]),y1=VF(args[2]),x2=VF(args[3]),y2=VF(args[4]);
            int thick=std::max(1,VI(args[9]));
            if(thick==1){
                SDL_RenderLine(it->second.ren,x1,y1,x2,y2);
            } else {
                // Offset perpendicular to the line direction for correct thick lines
                float dx=x2-x1, dy=y2-y1;
                float len=std::sqrt(dx*dx+dy*dy);
                if(len>0){
                    float nx=-dy/len, ny=dx/len; // perpendicular unit vector
                    for(int t=-thick/2;t<=thick/2;t++)
                        SDL_RenderLine(it->second.ren,
                                       x1+nx*(float)t, y1+ny*(float)t,
                                       x2+nx*(float)t, y2+ny*(float)t);
                } else {
                    SDL_RenderLine(it->second.ren,x1,y1,x2,y2);
                }
            }
        }
        return NONE_VALUE;
    }
    // gui_draw_circle(handle, cx, cy, radius, r, g, b, a)
    if(name=="gui_draw_circle"){
        if(args.size()<8) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()) draw_circle_sdl(it->second.ren,VF(args[1]),VF(args[2]),VF(args[3]),VU(args[4]),VU(args[5]),VU(args[6]),VU(args[7]));
        return NONE_VALUE;
    }
    // gui_fill_circle(handle, cx, cy, radius, r, g, b, a)
    if(name=="gui_fill_circle"){
        if(args.size()<8) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()) fill_circle_sdl(it->second.ren,VF(args[1]),VF(args[2]),VF(args[3]),VU(args[4]),VU(args[5]),VU(args[6]),VU(args[7]));
        return NONE_VALUE;
    }
    // gui_draw_shadow(handle, x, y, w, h, blur, ox, oy, r, g, b, a)
    // gui_draw_shadow(handle, x, y, w, h, blur, ox, oy, r, g, b, a)
    if(name=="gui_draw_shadow"){
        if(args.size()<12) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            float x=VF(args[1])+VF(args[6]),y=VF(args[2])+VF(args[7]),w=VF(args[3]),h=VF(args[4]);
            int blur=std::max(1,VI(args[5]));
            Uint8 sr=VU(args[8]),sg=VU(args[9]),sb=VU(args[10]),sa=VU(args[11]);
            SDL_SetRenderDrawBlendMode(it->second.ren,SDL_BLENDMODE_BLEND);
            // Layer from outermost (most transparent) inward (most opaque)
            // alpha = sa * (1 - i/blur)^2  (quadratic falloff outward)
            for(int i=blur;i>0;i--){
                float t=(float)(blur-i)/(float)blur; // 0 at edge, 1 at centre
                Uint8 alpha=(Uint8)(sa*(1.0f-t*t)*0.7f);
                SDL_SetRenderDrawColor(it->second.ren,sr,sg,sb,alpha);
                SDL_FRect rc={x-(float)i,y-(float)i,w+2.0f*i,h+2.0f*i};
                SDL_RenderFillRect(it->second.ren,&rc);
            }
        }
        return NONE_VALUE;
    }
    // gui_draw_gradient(handle, x, y, w, h, r1, g1, b1, r2, g2, b2, vertical)
    if(name=="gui_draw_gradient"){
        if(args.size()<12) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            float x=VF(args[1]),y=VF(args[2]),w=VF(args[3]),h=VF(args[4]);
            int r1=VI(args[5]),g1=VI(args[6]),b1=VI(args[7]),r2=VI(args[8]),g2=VI(args[9]),b2=VI(args[10]);
            bool vert=VI(args[11])!=0; int steps=vert?(int)h:(int)w; if(steps<1)steps=1;
            SDL_SetRenderDrawBlendMode(it->second.ren,SDL_BLENDMODE_BLEND);
            for(int i=0;i<steps;i++){
                float t=(float)i/(float)steps;
                SDL_SetRenderDrawColor(it->second.ren,(Uint8)(r1+t*(r2-r1)),(Uint8)(g1+t*(g2-g1)),(Uint8)(b1+t*(b2-b1)),255);
                if(vert) SDL_RenderLine(it->second.ren,x,y+(float)i,x+w,y+(float)i);
                else     SDL_RenderLine(it->second.ren,x+(float)i,y,x+(float)i,y+h);
            }
        }
        return NONE_VALUE;
    }
    // gui_draw_polygon(handle, points_list, n, r, g, b, a)
    // gui_fill_polygon(handle, points_list, n, r, g, b, a)
    // points_list = [[x0,y0],[x1,y1],...]
    if(name=="gui_draw_polygon"||name=="gui_fill_polygon"){
        if(args.size()<7) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()&&args[1].isCollectable()&&args[1].value.gc){
            auto* pts=dynamic_cast<Container*>(args[1].value.gc);
            if(pts&&pts->container){
                int n=VI(args[2]);
                SDL_SetRenderDrawColor(it->second.ren,VU(args[3]),VU(args[4]),VU(args[5]),VU(args[6]));
                SDL_SetRenderDrawBlendMode(it->second.ren,SDL_BLENDMODE_BLEND);
                std::vector<float> xs,ys;
                for(int i=0;i<n;i++){
                    auto pi=pts->container->find(std::to_string(i));
                    if(pi!=pts->container->end()&&pi->second.isCollectable()&&pi->second.value.gc){
                        auto* p=dynamic_cast<Container*>(pi->second.value.gc);
                        if(p&&p->container){
                            float px=0,py=0;
                            auto x0=p->container->find("0"); if(x0!=p->container->end()) px=VF(x0->second);
                            auto y0=p->container->find("1"); if(y0!=p->container->end()) py=VF(y0->second);
                            xs.push_back(px); ys.push_back(py);
                        }
                    }
                }
                int np=(int)xs.size();
                if(name=="gui_draw_polygon"){
                    for(int i=0;i<np;i++){
                        int j=(i+1)%np;
                        SDL_RenderLine(it->second.ren,xs[i],ys[i],xs[j],ys[j]);
                    }
                } else {
                    // Fill polygon using scanline (simple fan triangulation from centroid)
                    float cx=0,cy=0;
                    for(int i=0;i<np;i++){cx+=xs[i];cy+=ys[i];}
                    cx/=np; cy/=np;
                    for(int i=0;i<np;i++){
                        int j=(i+1)%np;
                        // Fill triangle (cx,cy)-(xs[i],ys[i])-(xs[j],ys[j]) with scan lines
                        float ax=xs[i],ay=ys[i],bx=xs[j],by=ys[j];
                        int miny=(int)std::min({cy,ay,by}), maxy=(int)std::max({cy,ay,by});
                        for(int y2=miny;y2<=maxy;y2++){
                            float fy=(float)y2;
                            float xmin=cx,xmax=cx;
                            auto intersect=[&](float x1,float y1,float x2,float y2,float fy2,float&xi){
                                if((y1<=fy2&&fy2<y2)||(y2<=fy2&&fy2<y1)){
                                    xi=x1+(x2-x1)*(fy2-y1)/(y2-y1); return true;
                                } return false;
                            };
                            float xi; if(intersect(cx,cy,ax,ay,fy,xi)){xmin=std::min(xmin,xi);xmax=std::max(xmax,xi);}
                            if(intersect(cx,cy,bx,by,fy,xi)){xmin=std::min(xmin,xi);xmax=std::max(xmax,xi);}
                            if(intersect(ax,ay,bx,by,fy,xi)){xmin=std::min(xmin,xi);xmax=std::max(xmax,xi);}
                            SDL_RenderLine(it->second.ren,xmin,fy,xmax,fy);
                        }
                    }
                }
            }
        }
        return NONE_VALUE;
    }
    // gui_set_clip(handle, x, y, w, h)
    if(name=="gui_set_clip"){
        if(args.size()<5) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){SDL_Rect rc={VI(args[1]),VI(args[2]),VI(args[3]),VI(args[4])};SDL_SetRenderClipRect(it->second.ren,&rc);}
        return NONE_VALUE;
    }
    // gui_clear_clip(handle)
    if(name=="gui_clear_clip"){
        if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_SetRenderClipRect(it->second.ren,nullptr);}
        return NONE_VALUE;
    }
    // gui_set_viewport(handle, x, y, w, h) — shifts render origin + clips
    if(name=="gui_set_viewport"){
        if(args.size()<5) return NONE_VALUE;
        auto it=g_windows.find(VI(args[0]));
        if(it!=g_windows.end()){
            SDL_Rect rc={VI(args[1]),VI(args[2]),VI(args[3]),VI(args[4])};
            SDL_SetRenderViewport(it->second.ren,&rc);
        }
        return NONE_VALUE;
    }
    // gui_clear_viewport(handle) — restore full viewport
    if(name=="gui_clear_viewport"){
        if(!args.empty()){auto it=g_windows.find(VI(args[0]));if(it!=g_windows.end())SDL_SetRenderViewport(it->second.ren,nullptr);}
        return NONE_VALUE;
    }

    // ── FONTS ───────────────────────────────────────────────────────────
    // gui_load_font(family, size [, bold, italic]) -> handle
    // GUARD: only call TTF_OpenFont if TTF is initialized (after gui_create_window).
    // Called before SDL init (e.g. from Font.__init__ at class-definition time)
    // silently returns NONE so Font.ensure_loaded() can retry later.
    if(name=="gui_load_font"){
        if(args.size()<2) return NONE_VALUE;
        if(!g_sdl_ok) return NONE_VALUE;  // TTF not initialized — retry later via ensure_loaded()
        std::string family=VS(E,args[0]); int size=VI(args[1]);
        bool bold   = args.size()>=3 && VI(args[2])!=0;
        bool italic = args.size()>=4 && VI(args[3])!=0;
        std::vector<std::string> paths;
        // Try the family as a literal path first, so an application can ship its
        // own font — Font("assets/fonts/codicon.ttf", 16, ...). Without this the
        // family was only ever matched against a fixed list of system font
        // names, and a bundled font could not be loaded at all.
        if(family.size()>4){
            std::string tail=family.substr(family.size()-4);
            for(auto& c:tail) c=(char)tolower((unsigned char)c);
            if(tail==".ttf"||tail==".otf"||tail==".ttc") paths.push_back(family);
        }
#ifdef _WIN32
        if(bold && (family=="monospace"||family=="mono"||family=="Consolas"))
            paths.push_back("C:\\Windows\\Fonts\\consolab.ttf");
        if(family=="monospace"||family=="mono"||family=="Consolas")
            paths.push_back("C:\\Windows\\Fonts\\consola.ttf");
        if(bold) paths.push_back("C:\\Windows\\Fonts\\segoeuib.ttf");
        paths.push_back("C:\\Windows\\Fonts\\segoeui.ttf");
        if(bold) paths.push_back("C:\\Windows\\Fonts\\arialbd.ttf");
        paths.push_back("C:\\Windows\\Fonts\\arial.ttf");
        paths.push_back("C:\\Windows\\Fonts\\tahoma.ttf");
#else
        if(family=="monospace"||family=="mono"){
            if(bold)
                paths.push_back("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf");
            paths.push_back("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf");
        }
        if(bold){
            paths.push_back("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf");
            paths.push_back("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf");
        }
        paths.push_back("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
        paths.push_back("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf");
        paths.push_back("/usr/share/fonts/truetype/freefont/FreeSans.ttf");
#endif
        paths.insert(paths.begin(),family);
        TTF_Font* font=nullptr;
        for(auto& p:paths){font=TTF_OpenFont(p.c_str(),(float)size);if(font)break;}
        if(!font) return NONE_VALUE;
        int style = TTF_STYLE_NORMAL;
        if(bold)   style |= TTF_STYLE_BOLD;
        if(italic) style |= TTF_STYLE_ITALIC;
        if(style != TTF_STYLE_NORMAL) TTF_SetFontStyle(font, (TTF_FontStyleFlags)style);
        int id=next_font_id++; g_fonts[id]=font;
        return Value(id);
    }
    // gui_measure_text_w(font_handle, text) -> w
    // Same metrics as gui_measure_text but returns a plain number. The list
    // form allocates an Object per call, and callers that only need the width
    // (caret placement, selection spans, right-aligned labels, tab widths) were
    // paying that on every draw call of every frame.
    if(name=="gui_measure_text_w"){
        if(args.size()<2) return Value(0);
        if(!g_sdl_ok) return Value(0);
        auto fit=g_fonts.find(VI(args[0]));if(fit==g_fonts.end()) return Value(0);
        MeasureKey mk{VI(args[0]), VS(E,args[1])};
        auto mit=g_measure_cache.find(mk);
        if(mit!=g_measure_cache.end()) return Value(mit->second.first);
        int w=0,h=0;
        TTF_GetStringSize(fit->second,mk.text.c_str(),0,&w,&h);
        if(g_measure_cache.size()>=kMeasureCacheMax) g_measure_cache.clear();
        g_measure_cache[mk]=std::make_pair(w,h);
        return Value(w);
    }

    // gui_measure_text(font_handle, text) -> [w, h]
    if(name=="gui_measure_text"){
        if(args.size()<2) return NONE_VALUE;
        if(!g_sdl_ok) return NONE_VALUE;  // TTF not initialized
        auto fit=g_fonts.find(VI(args[0]));if(fit==g_fonts.end()) return NONE_VALUE;
        // Metrics for a given (font, string) never change, but UI code calls this
        // once per text run per frame for layout. TTF_GetStringSize does a full
        // glyph walk each time, so memoise it the same way rendered text is cached.
        MeasureKey mk{VI(args[0]), VS(E,args[1])};
        int w=0,h=0;
        auto mit=g_measure_cache.find(mk);
        if(mit!=g_measure_cache.end()){
            w=mit->second.first; h=mit->second.second;
        } else {
            TTF_GetStringSize(fit->second,mk.text.c_str(),0,&w,&h);
            if(g_measure_cache.size()>=kMeasureCacheMax) g_measure_cache.clear();
            g_measure_cache[mk]=std::make_pair(w,h);
        }
        // Return as a 2-element list [w, h]
        auto* lst=new Object((Runnable*)E.runner,"measure",Type::LIST);
        lst->set("0",Value(w)); lst->set("1",Value(h)); lst->set("__len__",Value(2));
        return Value(static_cast<Collectable*>(lst));
    }

    // ── IMAGES ──────────────────────────────────────────────────────────
    // gui_load_image(path) -> handle
    if(name=="gui_load_image"){
        if(args.empty()||g_windows.empty()) return NONE_VALUE;
        SDL_Renderer* ren=g_windows.begin()->second.ren;
        SDL_Surface* surf=IMG_Load(VS(E,args[0]).c_str());if(!surf) return NONE_VALUE;
        SDL_Texture* tex=SDL_CreateTextureFromSurface(ren,surf);SDL_DestroySurface(surf);
        if(!tex) return NONE_VALUE;
        SDL_SetTextureBlendMode(tex,SDL_BLENDMODE_BLEND); // required for PNG alpha
        int id=next_img_id++; g_images[id]=tex;
        return Value(id);
    }

    // ── EVENTS ──────────────────────────────────────────────────────────
    // gui_poll_events(window_handle) -> list of event dicts
    if(name=="gui_poll_events"){
        auto* list=new Object((Runnable*)E.runner,"events",Type::LIST); int idx=0;
        SDL_Event ev;
        while(SDL_PollEvent(&ev)){
            Value v=NONE_VALUE;
            switch(ev.type){
                // SDL3 event types
                case SDL_EVENT_QUIT: v=make_evt(E,"quit"); break;
                case SDL_EVENT_WINDOW_RESIZED:
                    v=make_evt(E,"resize",0,0,0,"",0,"",0,ev.window.data1,ev.window.data2);
                    break;
                // The window can be mapped or uncovered AFTER the first frame
                // was presented. A caller that only repaints on change would
                // otherwise leave a blank window forever, because these events
                // used to be dropped here.
                case SDL_EVENT_WINDOW_EXPOSED:
                case SDL_EVENT_WINDOW_SHOWN:
                case SDL_EVENT_WINDOW_RESTORED:
                case SDL_EVENT_WINDOW_FOCUS_GAINED:
                    v=make_evt(E,"expose",0,0,0,"",0,"",0,0,0);
                    break;
                case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                    v=make_evt(E,"quit"); break;
                case SDL_EVENT_MOUSE_MOTION:
                    v=make_evt(E,"mousemove",(int)ev.motion.x,(int)ev.motion.y); break;
                case SDL_EVENT_MOUSE_BUTTON_DOWN:
                    v=make_evt(E,"mousedown",(int)ev.button.x,(int)ev.button.y,ev.button.button); break;
                case SDL_EVENT_MOUSE_BUTTON_UP:
                    v=make_evt(E,"mouseup",(int)ev.button.x,(int)ev.button.y,ev.button.button); break;
                case SDL_EVENT_MOUSE_WHEEL: {
                    // wheel.x/y = scroll amount (not screen position)
                    // wheel.mouse_x/y = cursor position relative to window
                    // Handle natural-scroll (FLIPPED) direction
                    float wy = ev.wheel.direction == SDL_MOUSEWHEEL_FLIPPED
                               ? -ev.wheel.y : ev.wheel.y;
                    v=make_evt(E,"wheel",
                               (int)ev.wheel.mouse_x,(int)ev.wheel.mouse_y,
                               0,"",0,"",(int)wy);
                    break;
                }
                case SDL_EVENT_KEY_DOWN: {
                    SDL_Keymod mod=SDL_GetModState();
                    // SDL_GetKeyName returns mixed-case ("Return","Escape","Backspace",...).
                    // All Nython widgets compare against lowercase ("enter","escape","backspace",...).
                    std::string kname=SDL_GetKeyName(ev.key.key);
                    // Lowercase the whole name
                    for(auto& c:kname) c=(char)tolower((unsigned char)c);
                    // Normalise common names to what widgets expect
                    if(kname=="return")          kname="enter";
                    else if(kname=="escape")     kname="escape";
                    else if(kname=="backspace")  kname="backspace";
                    else if(kname=="delete")     kname="delete";
                    else if(kname=="tab")        kname="tab";
                    else if(kname=="space")      kname="space";
                    else if(kname=="up")         kname="up";
                    else if(kname=="down")       kname="down";
                    else if(kname=="left")       kname="left";
                    else if(kname=="right")      kname="right";
                    else if(kname=="home")       kname="home";
                    else if(kname=="end")        kname="end";
                    else if(kname=="page up")    kname="pageup";
                    else if(kname=="page down")  kname="pagedown";
                    else if(kname=="left ctrl"||kname=="right ctrl")  kname="ctrl";
                    else if(kname=="left shift"||kname=="right shift") kname="shift";
                    else if(kname=="left alt"||kname=="right alt")    kname="alt";
                    else if(kname=="left gui"||kname=="right gui")    kname="super";
                    // F-keys: "f1"..."f12" stay as-is after lowercasing
                    v=make_evt(E,"keydown",0,0,0,kname,(int)ev.key.key,"",0,0,0,
                               (mod&SDL_KMOD_CTRL)!=0,(mod&SDL_KMOD_SHIFT)!=0,(mod&SDL_KMOD_ALT)!=0);
                    break;
                }
                case SDL_EVENT_KEY_UP: {
                    SDL_Keymod mod=SDL_GetModState();
                    std::string kname=SDL_GetKeyName(ev.key.key);
                    for(auto& c:kname) c=(char)tolower((unsigned char)c);
                    if(kname=="return")          kname="enter";
                    else if(kname=="backspace")  kname="backspace";
                    else if(kname=="delete")     kname="delete";
                    else if(kname=="tab")        kname="tab";
                    else if(kname=="space")      kname="space";
                    else if(kname=="up")         kname="up";
                    else if(kname=="down")       kname="down";
                    else if(kname=="left")       kname="left";
                    else if(kname=="right")      kname="right";
                    else if(kname=="home")       kname="home";
                    else if(kname=="end")        kname="end";
                    else if(kname=="page up")    kname="pageup";
                    else if(kname=="page down")  kname="pagedown";
                    else if(kname=="left ctrl"||kname=="right ctrl")  kname="ctrl";
                    else if(kname=="left shift"||kname=="right shift") kname="shift";
                    else if(kname=="left alt"||kname=="right alt")    kname="alt";
                    else if(kname=="left gui"||kname=="right gui")    kname="super";
                    v=make_evt(E,"keyup",0,0,0,kname,(int)ev.key.key,"",0,0,0,
                               (mod&SDL_KMOD_CTRL)!=0,(mod&SDL_KMOD_SHIFT)!=0,(mod&SDL_KMOD_ALT)!=0);
                    break;
                }
                case SDL_EVENT_TEXT_INPUT:
                    v=make_evt(E,"textinput",0,0,0,"",0,std::string(ev.text.text)); break;
                default: break;
            }
            if(v.type!=ValueType::NONE) list->set(std::to_string(idx++),v);
        }
        list->set("__len__",Value(idx));
        return Value(static_cast<Collectable*>(list));
    }

    // ── VIDEO STUBS ─────────────────────────────────────────────────────
    if(name=="gui_load_video")     return NONE_VALUE;
    if(name=="gui_video_play")     return NONE_VALUE;
    if(name=="gui_video_pause")    return NONE_VALUE;
    if(name=="gui_video_stop")     return NONE_VALUE;
    if(name=="gui_video_seek")     return NONE_VALUE;
    if(name=="gui_video_time")     return Value(0.0);
    if(name=="gui_video_duration") return Value(0.0);
    if(name=="gui_video_volume")   return NONE_VALUE;
    if(name=="gui_video_render")   return NONE_VALUE;

    return UNDEFINED_VALUE;
}

#pragma GCC diagnostic pop

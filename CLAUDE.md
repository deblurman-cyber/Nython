# CLAUDE.md — Nython Project Context

> **Resuming work in a new session? Read `HANDOFF.md` first.**
> This file describes the project as designed. `HANDOFF.md` describes it as it
> currently *is* — build instructions for the headless environment, the traps
> that have cost real time (two IDE files, dead code that looks live), the
> outstanding work in priority order, and how to verify a change.

## What is Nython

Nython is a Python-like interpreted language implemented in C++20, with its own lexer, parser, bytecode compiler, and virtual machine. Version **v0.2.1**.

## Repository Layout

```
nython/
├── src/                      ← C++ source files
│   ├── main.cpp              ← entry point, REPL, IDE launcher
│   ├── builtins/             ← 12 builtin dispatch modules
│   │   ├── core.cpp          ← print, len, str, int, type, range, ...
│   │   ├── math.cpp          ← abs, sqrt, sin, cos, pow, ...
│   │   ├── string.cpp        ← string_split, string_find, string_lower, ...
│   │   ├── io.cpp            ← file I/O, read_file, write_file, ...
│   │   ├── os.cpp            ← os_listdir, os_mkdir, os_exec, ...
│   │   ├── data.cpp          ← json_encode, json_decode, ...
│   │   ├── tensor.cpp        ← tensor ops for nytorch
│   │   ├── network.cpp       ← http_get, http_post, sockets
│   │   ├── audio.cpp         ← audio builtins (stubs)
│   │   ├── threading.cpp     ← thread_create, thread_sleep, mutex_*
│   │   ├── lang.cpp          ← lang_define_token, lang_eval, ...
│   │   └── gui.cpp           ← SDL3 GUI backend (38 gui_* functions)
│   └── ...                   ← Lexer, Parser, Value, GarbageCollector, etc.
├── include/                  ← C++ headers
│   ├── NythonExecutor.hpp    ← main executor, callBuiltin dispatch chain
│   ├── VirtualMachine.hpp    ← bytecode VM (~3800+ lines)
│   ├── Value.hpp             ← Value type system
│   ├── builtins/             ← 12 dispatch headers (gui.hpp, core.hpp, ...)
│   └── ...
├── lib/                      ← Nython standard libraries
│   ├── gui.ny                ← GUI widget library (150+ classes)
│   │                            NOTE: nython_ide.ny does NOT import this
│   ├── nyimgui.ny            ← immediate-mode core (after Dear ImGui)
│   ├── gui_motion.ny         ← easing curves, Flex layout solver, fuzzy match
│   ├── gui_piecetable.ny     ← piece-table buffer, operation-based undo
│   ├── icons.ny              ← 460 Codicon name → codepoint (class Icons_Codicon)
│   ├── ide_commands.ny       ← :cmd / >expr / @agent command line
│   ├── ide_toolchain.ny      ← real compile/run bridge for the IDE
│   ├── ide_selection.ny      ← multi-cursor selection model
│   ├── ide_inspector.ny      ← universal value inspector
│   ├── stdlib.ny             ← standard library
│   ├── nytorch.ny            ← ML framework entry point
│   ├── nytorch/              ← 17 nytorch sub-modules
│   └── ...                   ← network.ny, thread.ny, os.ny, etc.
├── nython_ide.ny             ← THE SHIPPED IDE (v4, ~3,700 lines) ← --ide loads this
├── ide_editor.ny             ← editor buffer used by the shipped IDE
├── ide_icons.ny              ← icon set: Codicon glyphs, vector fallback
├── ide_project.ny            ← workspace / project model
├── ide_workshop.ny           ← language workshop panel
├── assets/fonts/codicon.ttf  ← VS Code icon font (CC BY 4.0, licence beside it)
├── examples/nython_ide.ny    ← a v3 DEMO, not shipped — see IDE_FILES.md
├── examples/                 ← 356 example scripts
├── examples/gui_tests/       ← test_13 … test_27, GUI/IDE/language regressions
├── tests/                    ← test suites
├── HANDOFF.md                ← START HERE when resuming
├── FIXES_v0.2.1.md           ← round-by-round log: every bug and why
├── GC_NOTES.md               ← the container leak: diagnosis and three fixes
├── MEMORY_NOTES.md           ← writing Nython the runtime can afford
├── IDE_FILES.md              ← which IDE file is real (this has bitten before)
├── nython.cbp                ← Code::Blocks project (SDL3 pre-configured)
├── Makefile                  ← Linux build (SDL3 always required)
├── SDL3_SETUP.md             ← Step-by-step SDL3 setup guide
└── CLAUDE.md                 ← this file
```

## Build System

### Linux (Makefile)
```bash
make cli        # Build CLI binary (SDL3 required)
make            # Build IDE binary (SDL3 required)
./build/nython-cli --ide   # Launch IDE
```

SDL3 is always required. Install dependencies:
```bash
apt install libsdl3-dev libsdl3-ttf-dev libsdl3-image-dev
```

### Windows (Code::Blocks)
- `.cbp` is pre-configured with SDL3 include/lib paths to `C:\SDL3\`
- Link libraries: `ws2_32`, `SDL3`, `SDL3_ttf`, `SDL3_image`
- Copy `SDL3.dll`, `SDL3_ttf.dll`, `SDL3_image.dll` next to `nython.exe`
- See `SDL3_SETUP.md` for detailed instructions

### Development environment (no SDL3 available)

The dev container has no SDL3 and cannot install it. A headless stub in
`/home/claude/work/stub/` provides the 111 SDL symbols the project uses, so
everything builds and every GUI/IDE test runs without a display.

```bash
rm -rf /tmp/vbuild && /tmp/vbuild.sh     # ~5 minutes
cp /tmp/vbuild/nython ./ny_test
NY_STUB_AUTOQUIT=120 ./ny_test nython_ide.ny    # IDE runs and exits cleanly
```

`NY_STUB_AUTOQUIT=<n>` makes the stub deliver one quit event after *n* empty
polls so event loops terminate; `NY_STUB_DPI_SCALE=<f>` fakes a HiDPI display.
Full detail in `HANDOFF.md`.

### Key build flags
- `-DNYTHON_WITH_IDE=1` (default) — no-arg launch opens IDE; `=0` opens REPL
- SDL3 is unconditional — `NYTHON_HAS_SDL3` flag removed; guards removed from `gui.cpp`

## Architecture

### Builtin dispatch chain (NythonExecutor.hpp callBuiltin)
```
callBuiltin("gui_create_window", args, ctx)
  → dispatch_core()       → UNDEFINED (not handled)
  → dispatch_tensor()     → UNDEFINED
  → ...
  → dispatch_gui()        → Value(handle)  ← matches "gui_" prefix
```

Each `dispatch_*` function returns `UNDEFINED_VALUE` if it doesn't handle the name, and the chain continues to the next module.

### GUI pipeline
```
nython_ide.ny                     ← IDE application (2,110 lines)
  └── import "lib/gui.ny"        ← Widget library (12,932 lines, 150+ classes)
       ├── import nytorch         ← Registers tensor builtins (fast, no classes)
       └── calls gui_*()          ← 38 native functions
            └── src/builtins/gui.cpp  ← SDL3 always active
                 └── SDL3 API calls (SDL_CreateWindow, SDL_RenderFillRect, ...)
```

### SDL3 API usage (no OpenGL)
- `SDL_CreateWindow(title, w, h, flags)` — no x,y in constructor
- `SDL_CreateRenderer(win, NULL)` — no driver index or flags
- `SDL_FRect` (float) for all rendering, not `SDL_Rect` (int)
- `SDL_RenderLine`, `SDL_RenderPoint` — float coordinates
- `SDL_RenderTexture` replaces `SDL_RenderCopy`
- `SDL_DestroySurface` replaces `SDL_FreeSurface`
- `SDL_SetRenderVSync(ren, 1)` — replaces `SDL_RENDERER_PRESENTVSYNC`
- Event types: `SDL_EVENT_QUIT`, `SDL_EVENT_KEY_DOWN`, `SDL_EVENT_MOUSE_MOTION`, etc.
- `ev.key.key` not `ev.key.keysym.sym`
- `TTF_RenderText_Blended(font, text, 0, color)` — extra length param
- `TTF_GetStringSize(font, text, 0, &w, &h)` — replaces `TTF_SizeUTF8`
- `TTF_OpenFont(path, (float)size)` — size is float
- `IMG_Init()` not needed in SDL3_image

### Window constructor
```python
# gui.ny — Window(width, height, title)
var w = Window(1600, 960, "NythonIDE v3.0")
w.run(callback)   # callback(renderer, event) — custom render loop
```
- `x` and `y` default to `-1` (centered)
- `run(callback)` sends `"idle"` events when no SDL events (continuous redraw)
- Without SDL3: `create()` returns `false`, prints message, exits gracefully

### Event modifiers
```python
# Event class has ctrl, shift, alt booleans
if event.key == "p" and event.ctrl:
    spotlight.visible = true
```
SDL3 backend passes modifiers via `SDL_GetModState()`.

## Key Patterns & Gotchas

### Stale object files
At least one "bug" (SIGABRT) was caused by stale `.o` files. Always `make clean && make` after header changes.

### Header-only changes need forced recompile
After editing `NythonExecutor.hpp`: `touch src/main.cpp` then rebuild.

### Kwargs must be explicitly forwarded
Collecting kwargs at the call site is insufficient — they must be passed through to `callBuiltin` or they are silently dropped (e.g., `sorted(key=, reverse=)` bug).

### Closures capture by reference
Like JavaScript, closures in loops see the final value. Use factory functions for per-iteration capture:
```python
# BAD: all closures see i=4
while i < 5:
    def fn(): return i * i
    ...

# GOOD: each closure gets its own n
def make_fn(n):
    def inner(): return n * n
    return inner
```

### GarbageCollector lock bug (fixed)
Lines 77 and 228 in `GarbageCollector.cpp` had temporary locks that were immediately destroyed. Fixed to named variables (`gc_lock`, `dealloc_lock`).

### IDE import weight
`nython_ide.ny` must NOT import `"lib/nytorch.ny"` (loads 220+ classes, causes OOM). The builtins are already registered via `gui.ny`'s bare `import nytorch`.

### Widget constructor signatures
These were aligned to match how the IDE calls them:

| Widget | Constructor |
|--------|-------------|
| Window | `(width, height, title)` |
| ActivityBar | `(x, y, w, h)` + `add_item(icon, label, active)` |
| Spotlight | `(x, y, w, h)` + `add_item(label, id)` |
| AutoComplete | `(x_or_w, y=0, w=0, h=0)` — works with 1 or 4 args |
| TabBar.add_tab | `(name, filename="", path="")` — works with 1 arg |
| TextInput | `(x, y, w, h, placeholder="")` — placeholder optional |
| FileTree | `(x, y, w, h)` + `add_node(path, label, depth, expanded, type)` + `node_count` |

## Test Suites (24 suites, all passing)

| Suite | Tests | Category |
|-------|-------|----------|
| test_vm | 12 | Core VM |
| test_vm2 | 48 | Core VM |
| test_vm3 | 27 | Core VM |
| test_vm4 | 56 | Core VM |
| test_vm_extended | 30 | Core VM |
| test_vm_stress | 37 | Core VM |
| vm_audit22 | 88 | Advanced patterns |
| vm_audit23 | 66 | Advanced patterns |
| vm_audit24 | 49 | Advanced patterns |
| vm_audit25 | 80 | Advanced patterns |
| vm_audit26 | 88 | Closures, generators, inheritance, walrus, etc. |
| vm_audit27 | 84 | enumerate start=, *args/**kwargs, try/else, string methods, isinstance, __repr__, callable classes, dict.items, chained comparisons |
| test_stdlib | 94 | Standard library |
| test_os | 25 | OS operations |
| test_gui | 1053 | GUI widget class logic |
| test_ide_smoke | 40 | IDE widget constructors |
| test_nytorch9 | — | ML agents |
| test_nytorch10 | — | ML distributed |
| test_nytorch11 | — | ML vision |
| test_nytorch12 | — | ML reinforcement |
| test_nytorch13 | 110 | ML LLM |
| test_nytorch14 | 151 | ML optimization |
| test_nytorch15 | 184 | ML cognitive |
| test_nytorch16 | 153 | ML pipeline |
| test_nytorch17 | 199 | ML device-agnostic |

Run all: `for t in examples/test_*.ny examples/vm_audit*.ny; do ./build/nython-cli "$t"; done`

## Language changes since this file was written

These entries are now **fixed**; they are listed so old notes are not trusted:

- ~~C-style negative modulo~~ — now floor-modulo, `-7 % 3 == 2`, consistent with
  floor `//` on both engines.
- ~~32-bit integer overflow~~ — results were computed at full width and then
  truncated by a cast to `(int)`. `100000 * 100000` is now correct.
- `**` no longer demotes exact integers to double below 2^63.

### Added

| Feature | Notes |
|---|---|
| `1..5` / `1...5` | half-open and inclusive ranges; `a..b..step` |
| `is` / `is not` | membership: `1 is int`, `1 is Object`, `c is Base` (walks the chain) |
| `import X as Y` | binds a namespace; `from "m" import n` also works |
| `catch` | alias for `except`, matching the existing `throw`/`raise` alias |
| Located errors | `file:line:column`, source line, caret — both engines.<br>Mid-file only: an error at EOF still reports `stdin:1:1` (see HANDOFF 5.6). |
| `NameError` / `ImportError` | undefined calls and missing modules were silent |
| Object protocol | `class_name`, `to_string`, `is_a`, `fields`, … (**interpreter only**) |
| `--profile` | real per-function counts and self/total time |
| `gui_hash_id` | native FNV-1a for immediate-mode widget identity |
| `gui_display_scale` | HiDPI content scale |

### Known limitations

- **Containers are never reclaimed by the interpreter** — see `GC_NOTES.md`.
  The VM does not have this problem (it uses `shared_ptr`).
- The object protocol is implemented on the interpreter only; the VM has no
  equivalent and `test_25` skips there.
- `len()` counts characters but `s[i]` / `s[a:b]` index bytes.
- `1.+(2, 3)` parses but evaluates to `none` — primitives have no members.
- Integer `/` differs between engines (`5.0` vs `5`) — a design decision, not a
  bug; `examples/arith_test.ny` asserts the VM's answer.
- `generator.send()` not implemented (eager-collection architecture).
- Video builtins are stubs (need ffmpeg).

## Session Workflow

1. **Read `HANDOFF.md`** — environment, traps, outstanding work.
2. Build (`rm -rf /tmp/vbuild && /tmp/vbuild.sh`), copy to `./ny_test`.
3. Run the full sweep on **both engines** before changing anything, so any
   failure afterwards is attributable.
4. Reproduce a defect minimally, trace it to source, fix **both engines
   together**, and add a test asserting values rather than termination.
5. Re-run the sweep and compare divergence *sets* against
   `/tmp/obuild/nython_orig`, not counts.
6. Package to `/mnt/user-data/outputs/`.
7. State plainly what was not done. A green suite that hides an unadopted module
   or a one-engine feature is worse than an honest gap.

## Bug fixes — GUI & IDE audit (multi-session)

### src/builtins/gui.cpp
- **`gui_get_error()` / `gui_sdl_version()` always returned `none`**: Root cause — the `evalCall` path in `NythonExecutor.hpp` only routes through `callBuiltin` when the function is registered in `registerBuiltins()`. Unregistered `gui_*` names evaluated to `NONE_VALUE` callee and fell through to `return NONE_VALUE` without ever calling `callBuiltin`/`dispatch_gui`. Fixed by registering `gui_get_error`, `gui_sdl_version`, `gui_create_window`, `gui_load_font`, `gui_measure_text`, `gui_load_image`, `gui_poll_events`, `gui_video_time`, `gui_video_duration` in `registerBuiltins()`. Also added `evalCall` fallback for underscore-prefixed module functions.
- **`ensure_sdl_for_window()`** — removed `SDL_HINT_RENDER_DRIVER "direct3d11"` pre-init hint that caused `SDL_CreateWindow` to silently fail on systems without D3D11.
- **`SDL_WINDOW_HIGH_PIXEL_DENSITY`** removed from window flags — caused `SDL_CreateWindow` to return NULL on some Windows 11 GPU drivers.
- **Software renderer fallback** added: if default renderer fails, tries `"software"` renderer.
- Added `gui_sdl_version()` builtin — returns SDL3 runtime version string (e.g. `"3.2.4"`).
- Added `examples/check_sdl.ny` — diagnostic script to verify SDL3 DLLs and runtime.
- **Removed `SDL_VIDEODRIVER` hint** that forced wayland/x11/offscreen on Windows, preventing window creation.
- **`SDL_WINDOW_HIGH_PIXEL_DENSITY`** flag added to all windows for proper HiDPI.
- **`SDL_HINT_RENDER_DRIVER`** set per-platform (direct3d11 on Windows, metal on macOS).
- **`SDL_Quit()`** called when last window destroyed.
- **`gui_draw_text`**: removed `if(text.empty()) return` guard that skipped space characters.
- **`gui_draw_line`**: fixed thickness — was always offsetting Y (broke vertical/diagonal lines). Now offsets perpendicular to the line direction using `(-dy/len, dx/len)`.
- **`gui_poll_events` wheel**: `ev.wheel.x/y` (scroll amount) was used as cursor position. Fixed to `ev.wheel.mouse_x/y` for position. Added `SDL_MOUSEWHEEL_FLIPPED` correction.
- **`gui_load_font`**: ignored bold/italic — all fonts loaded as regular. Now accepts 4 args `(family, size, bold, italic)`, tries bold-specific font files first, then calls `TTF_SetFontStyle` for synthesis.
- **Key names lowercase + normalised**: `SDL_GetKeyName` returns `"Return"`, `"Escape"`, `"Backspace"`, `"Up"` etc. All widgets expect lowercase `"enter"`, `"escape"`, `"backspace"`, `"up"`. Key names are now lowercased and normalised (`"return"→"enter"`, `"page up"→"pageup"`, etc.) — **keyboards were completely broken before this fix**.
- **`-DNYTHON_WITH_IDE=1`** added to both Release and Debug targets in `nython.cbp`.

### lib/gui.ny
- **`Font.load()` never called**: `Font.__init__` now auto-calls `self.load()`. Added `ensure_loaded()` lazy-retry for fonts built before SDL/TTF was ready. `Renderer.draw_text()` calls `font.ensure_loaded()` before use.
- **`Font.load()` ignored bold/italic**: now passes `self.bold, self.italic` to `gui_load_font`.
- **`"wheel"` vs `"scroll"` event mismatch**: C++ emits `"wheel"` but all 20+ widget scroll handlers check `"scroll"`. Fixed by normalising in `Window._process_event()` and `Window.run()`.
- **`ToastManager.__init__`**: required `window_w` arg but IDE called `ToastManager()` with no args → crash. Made `window_w` required but callers now pass `1600`.
- **`ToastManager.update()`**: `new_count` declared but never incremented → all toasts dropped every frame.
- **`ToastManager.show()`**: `self.toasts[self.count] = t` dict-style assignment on list. Changed to append.
- **`Widget.add_child()`**: `self.children[self.child_count] = widget` dict-style assignment on list. Fixed to append.
- **`Widget.remove_child()`**: `new_count` never incremented → child_count zeroed after any remove.
- **`Panel.add()`, `VBox.add()`, `HBox.add()`**: same dict-style index assignment bugs. All fixed to append.
- **`Card.handle_event()`**: no visibility guard — forwarded events to children even when hidden.
- **Per-frame Font allocations eliminated**: `Toast`, `Modal`/`Dialog`, `VideoPlayer`, `Image`, `ActivityBar` all cached fonts as instance attributes instead of constructing new Font objects every draw call.

### nython_ide.ny
- **`ToastManager(1600)`**: was `ToastManager()` — crash on `window_w` access.
- **Panel tab strip fonts**: `Font(...)` created every frame in `_draw_panel_tab_strip` → cached as `self._font_panel_tab/bold`.
- **Status bar fonts**: `Font(...)` created every frame in `_draw_status_bar` → cached as `self._font_status/bold`.

- **`enumerate(lst, start=N)` kwarg form fixed**: Root cause was two-part —
  (1) `NythonExecutor.hpp` kw_builtins set didn't include `"enumerate"`, so `start=` was silently dropped before reaching callBuiltin; (2) a duplicate `globals_["enumerate"]` in VirtualMachine.hpp (line ~4346) overwrote the correct version that had start-support. Both fixed: `enumerate` added to kw_builtins with `start` key extraction; both VM enumerate definitions updated with full positional + kwarg start support.
- **vm_audit27 added**: 84 tests covering the above plus *args/**kwargs, try/else, string .replace()/.count()/.join(), isinstance with inheritance, __repr__, callable classes (__call__), dict.items()/keys()/values(), chained comparisons, lambda multi-arg, map+filter, method chaining, sorted key=/reverse=, recursion, string %, dict.get(), `in` operator.

## Transcripts

- `/mnt/transcripts/journal.txt` — catalog of all session transcripts
- `/mnt/transcripts/2026-03-26-22-45-41-nython-v021-gui-sdl3-full-session.txt` — latest full session

## IDE Launch Fix (multi-session debug)

**Root cause 1 — LangWorkshopPanel defined after `var ide = NythonIDE()`**
`_build_layout()` tried to instantiate LangWorkshopPanel before the class was defined.
Fixed by moving LangWorkshopPanel before the launch block.

**Root cause 2 — Compound boolean expression with outer parens**
Line 762 of nython_ide.ny:
```python
# BROKEN — Nython parser can't handle (A and B) or C before a colon:
if (string_find(lower, "debug") >= 0 and string_find(lower, "session") >= 0) or string_find(lower, "breakpoint") >= 0:
```
The Nython parser sees `if (expr)` as complete, then hits `or` after `)` and throws
`SyntaxError: Unexpected token: :`. The error was caught silently by `evalImport()`'s
try/catch, making the IDE appear to "return immediately" with no output.
Fixed by removing the outer parentheses.

**Root cause 3 — Nython lexer `optimize()` out-of-bounds**
`optimize()` in Lexer.cpp accessed `tk[i+1]` without checking `i < nb-1`.
For large files (15K+ lines from combined imports), corrupted Dedent tokens.
Fixed: all `i < nb` guards changed to `i < nb-1` before any `tk[i+1]` access.

**Root cause 4 — Unicode characters in string literals**
Em-dashes (—), arrows (→), box-drawing chars (═─│), emoji in string literals
caused the Nython lexer to error. All replaced with ASCII equivalents.

**File split for parser depth limit:**
- `nython_ide.ny` — NythonIDE class + launch (imports the two below)
- `ide_editor.ny` — EditorBuffer, SyntaxHighlighter, RichEditor, OutputConsole
- `ide_workshop.ny` — LangWorkshopPanel

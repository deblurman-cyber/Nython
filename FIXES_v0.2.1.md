# Nython v0.2.1 — SDL3 window creation fix

## The reported symptom

```
bin\Release\nython.exe
[Nython] Window creation failed (SDL3 none is loaded).
[Nython] SDL_CreateWindow returned NULL with no error message.
[Nython] Possible causes:
[Nython]   1. GPU drivers outdated - update them and reboot
[Nython]   2. Running inside Remote Desktop or VM without GPU
[Nython]   3. SDL3.dll is 32-bit but nython.exe is 64-bit
[Nython]   4. Missing Windows system DLL (run: dxdiag)
```

**All four of those "possible causes" were wrong.** Your GPU drivers, Remote
Desktop, DLL bitness and system DLLs were never the problem. SDL was never
even called.

## Root cause

`launch_ide()` in `src/main.cpp` executed `nython_ide.ny` through the bytecode
VM:

```cpp
if (ast) vm2->run(ast);
```

The bytecode VM (`include/VirtualMachine.hpp`) registers its own small table of
native functions — `print`, `len`, `time_ms`, `json_encode`, and so on. It
contains **zero** `gui_*` entries (`grep -c "gui_" include/VirtualMachine.hpp`
returns 0) and no `lang_*` entries either. It knows nothing about the module
dispatch chain in `NythonExecutor::callBuiltin`, which is where `dispatch_gui`
lives.

So inside the IDE every `gui_*` name resolved to nothing and evaluated to
`none`:

* `gui_create_window(...)` returned `none` **without ever reaching
  `SDL_CreateWindow`**, so `Window.create()` returned `false`.
* `gui_get_error()` returned `none`, so `lib/gui.ny` skipped its "Cannot open
  window: <real reason>" branch.
* `gui_sdl_version()` returned `none`, which is what printed the literal text
  `SDL3 none is loaded` — that "none" was a missing builtin, not a missing DLL.

The interpreter path was always fine. `run_file()` uses `NythonExecutor`, which
is why `nython.exe examples/check_sdl.ny` reported SDL 3.x correctly while the
no-argument IDE launch failed. That discrepancy was the whole bug.

## Fixes applied

### 1. `src/main.cpp` — the actual fix

`launch_ide()` now executes the IDE through `NythonExecutor`, the same engine
`run_file()` already used, so the full builtin dispatch chain (`dispatch_gui`,
`dispatch_lang`, `dispatch_tensor`, ...) is available:

```cpp
if (ast) {
    NythonExecutor exec((Runnable*)vm2.get());
    exec.execute(ast);
}
```

This fixes the entire class of bug, not just the window: every `gui_*` and
`lang_*` call in the IDE (the Lang Workshop panel included) was affected.

### 2. `src/builtins/gui.cpp` — make failures self-describing

* `gui_create_window` with fewer than 6 arguments used to `return NONE_VALUE`
  silently, leaving `g_sdl_error` empty and producing a phantom
  "SDL_CreateWindow returned NULL" report. It now sets a real error message.
* Non-positive window dimensions are caught and reported, then clamped to
  640x480 instead of being handed to SDL as-is.
* Window-creation errors now include the active video driver and the requested
  size, e.g.
  `SDL_CreateWindow failed with no SDL error [video driver: dummy, size 1600x960]`.
  A driver of `none` or `dummy` is the real signature of a headless/RDP session.
* `SDL_ShowWindow` + `SDL_RaiseWindow` are called after renderer setup.

### 3. `lib/gui.ny` — stop blaming the graphics driver

`Window.run()` now distinguishes the two failure modes. If
`gui_sdl_version()` returns `none`, the GUI builtins were never dispatched and
SDL was never called, so the message says exactly that instead of sending you
to `dxdiag`. The GPU-driver advice is only printed in the one case where it is
actually plausible: SDL was reached, returned NULL, and set no error text.

## Verification

Reproduced and verified on Linux by compiling the full interpreter against a
stub SDL3 whose `SDL_CreateWindow` returns `NULL` with an empty error string —
which reproduced your output byte for byte, including `SDL3 none is loaded`.

Instrumenting `Window.run()` in the failing build showed the smoking gun:

```
[DBG] w=1600 h=960 t=NythonIDE v3.0     <- dimensions were always fine
[DBG] direct ver=none                    <- gui_sdl_version()  -> none
[DBG] time_ms=1.78555e+09                <- VM native, works
[DBG] json=[1,2]                         <- VM native, works
[DBG] poll=none                          <- gui_poll_events()  -> none
[DBG] lang_version=none                  <- lang_* broken too
```

After the fix, the same probe reports `gui_sdl_version=user-data`,
`type()=builtin`, and `SDL_CreateWindow` is genuinely called.

* With a failing SDL stub the IDE now prints the true reason and the video
  driver.
* With a working SDL stub the IDE creates its window and runs its event loop
  with no errors.
* 12 assorted example scripts still pass; the `gui_tests` diagnostics and
  `examples/check_sdl.ny` still pass.
* Both `-DNYTHON_WITH_IDE=1` and `-DNYTHON_WITH_IDE=0` compile.

## What was NOT changed

Only these three files differ from your original archive:

```
lib/gui.ny
src/builtins/gui.cpp
src/main.cpp
```

Every other file in the archive is byte-identical to what you sent.

## Rebuilding on Windows

No project or build-flag changes are needed — `nython.cbp` already compiles
`src/builtins/gui.cpp` and links `SDL3`, `SDL3_ttf`, `SDL3_image`. Just rebuild:

Code::Blocks: **Build > Rebuild** (a plain Build may not pick up `main.cpp`).

Make sure `SDL3.dll`, `SDL3_ttf.dll`, `SDL3_image.dll`, `nython_ide.ny` and the
`lib\` folder sit next to `nython.exe`, then run `nython.exe` with no arguments.

---

# Round 2 — black window, frozen frame rate, container bugs

Reported after the first fix: *"the IDE is launching but it takes time and the
window is black."*

Those were **two separate bugs**, and neither was solved by threading.

## Bug A — bound methods lost `self` (this was the black window)

`nython_ide.ny` passes `self._main_loop` to `win.run(...)`. Reading a method off
an instance as a *value* returned the bare function with no instance attached,
so at call time every argument shifted left by one:

```
obj.m(a, b)          ->  self=obj, x=a,   y=b      (correct)
f = obj.m;  f(a, b)  ->  self=a,   x=b,   y=none   (silently wrong)
```

Inside `_main_loop`, `self` was therefore the **Renderer**. `self._frame_count + 1`
evaluated to `none`, and `self.handle_event(...)` / `self.draw(renderer)` resolved
to attributes that do not exist on a Renderer, so every panel silently no-op'd.
`__init__` had in fact run to completion — all 72 assignments were verified.

Measured over 20 seconds before the fix: **0 fill_rect, 0 lines, 0 text renders,
0 fonts opened.** The window was black because nothing was ever drawn. Nothing
errored, because attribute reads on the wrong `self` just yield `none`.

Fixed in `include/NythonExecutor.hpp`:

* `makeBoundMethod(fn, self)` captures the instance when a method is read off it.
* `applyBoundSelf(ptr, args)` re-supplies it at call time, in both `evalCall`
  and `callFunctionValue`.
* Binding is deliberately narrow: static methods, class methods, properties,
  builtins, lambdas and plain functions stored on instances are all excluded,
  and it only applies when the function actually declares `self`/`this` first.
  Otherwise binding would corrupt arguments rather than fix them.

## Bug B — `thread_sleep` was wrong by a factor of 1000 (this was the slowness)

`thread_sleep` forwarded straight to `time_sleep`, which takes **seconds**:

```cpp
if (name == "thread_sleep") return callBuiltin("time_sleep", args, ctx);
```

`lib/gui.ny` runs `thread_sleep(int(1000 / self.fps))` — so `thread_sleep(16)`
slept **16 seconds per frame**. Tracing confirmed 16001 ms between frames.
Every caller in `lib/` passes milliseconds (`frame_ms`, `interval_ms`,
`thread_sleep(10)`, `thread_sleep(1)`), so `thread_sleep` is now milliseconds.

## Performance work

* **Frame pacing** (`lib/gui.ny`): the loop slept a flat `frame_ms` *after*
  doing the frame's work, making the real period `work + frame_ms` instead of
  `max(work, frame_ms)`. It now sleeps only the remaining budget.
* **Text texture cache** (`src/builtins/gui.cpp`): the IDE issues ~85
  `draw_text` calls per frame, and each one re-rasterised the string with
  `TTF_RenderText_Blended` and re-uploaded a GPU texture *every frame*, for text
  that rarely changes. Now cached by (font, colour, string), bounded at 4096
  entries. The cache is cleared in `gui_destroy_window` **before** the renderer
  is destroyed — those textures are renderer-owned and would otherwise dangle.

Measured (20 s window):

| | before | after |
|---|---|---|
| frames | 2 | 433 |
| rects drawn | 0 | 22,958 |
| lines drawn | 0 | 259,934 |
| text rasterizations | 0 | **70** (uncached: 35,770) |

## Why the IDE is NOT run on a background thread

You asked for this; it should not be done. SDL window creation and event
pumping **must** happen on the main thread on Windows and macOS — moving them to
a worker thread breaks input and rendering outright. It also would not have
helped: the IDE was not blocked on parallelisable work, it was sleeping 16
seconds per frame. That is fixed at the source instead.

The remaining frame cost is interpreter-bound (the tree-walking evaluator
running ~600 draw calls of Nython per frame), not SDL-bound.

## Container bugs found by the regression sweep

Running all 314 examples surfaced three failures. All three were **pre-existing**
and unrelated to the changes above — each was reproduced with a minimal case
containing no classes at all — and all three are now fixed:

1. **`map.remove(key)` aborted the interpreter.** The `discard`/`remove` handler
   applied SET semantics and was not gated on the container actually being a
   set, so it intercepted maps and lists, scanned numeric indices, and threw
   `"<x> not in set"`. Now gated on `__set__`, with `remove`/`delete`
   dispatching on container kind: maps erase by key and return the removed
   value, lists remove by value and shift left.
2. **`list.contains(x)` returned `none`** because it was never implemented for
   lists — so `assert [1,2,3].contains(2)` failed with the element present.
   Implemented (`contains`/`includes`/`has`/`__contains__`).
3. **A method named after a builtin segfaulted the process.** `FileAssistant`
   defines `read_file(self, f)` whose body calls the builtin `read_file(f)`; the
   bare name resolves back to the method, recursing until the C++ stack blew.
   Added a call-depth guard (900) that raises a catchable `RecursionError`, and
   `main.cpp` now catches Nython's `std::string` exceptions instead of dying via
   `std::terminate`.

Also hardened: list removal used `Value::toString()`, which throws on USERDATA
(interned string) values — switched to `getStringValue()`.

## Verification

* **314 / 314 examples pass** (was 311 pass, 3 fail).
* IDE runs its event loop at ~433 frames / 20 s with a full render every frame.
* Layout confirmed by rasterising a real frame to an image: activity bar, file
  explorer, tab bar, editor with line numbers, minimap, bottom panel tab strip,
  status bar and AI chat panel all render in the correct positions.
* Both `-DNYTHON_WITH_IDE=1` and `-DNYTHON_WITH_IDE=0` compile.

## Files changed in round 2

```
include/NythonExecutor.hpp    bound methods, recursion guard, container methods
src/builtins/threading.cpp    thread_sleep -> milliseconds
src/builtins/gui.cpp          text texture cache + cache invalidation
lib/gui.ny                    frame pacing
src/main.cpp                  catch Nython string exceptions
```

## Not done: the UI redesign

You also asked for the IDE to be made "beautiful … Code::Blocks + VS Code."
That has not been attempted. It is an open-ended visual redesign of a
56,000-line UI, and here it could only be judged through a stub rasterizer that
draws text as grey bars — styling it that way would be guesswork dressed up as
work. Now that it renders at all, run it on Windows, screenshot it, and say what
specifically looks wrong; those are changes that can be reasoned about and
verified.

The next real performance win is a dirty-flag redraw: the IDE repaints its
entire UI every idle frame. That was left alone deliberately because it
interacts with the caret blink and confetti animations, and getting it wrong
reintroduces exactly the class of silent visual failure just fixed.

---

# Round 3 — the black window on a 1366x768 screen, and NythonIDE v4

The screenshot showed an almost entirely black window with one clipped line of
text at the very top edge. That was **not** a rendering fault. It was a sizing
fault.

## Root cause

`nython_ide.ny` v3 hardcoded its layout to 1600x960 — including literally
`var W = 1600` / `var H = 960` inside `draw()` itself, in ten places. On a
1366x768 display Windows clamps the window to fit the screen, but the layout
kept painting at the unclamped size, so most of the UI was drawn outside the
visible client area.

Compounding it: **there was no resize handler anywhere in the project.** Layout
was computed once in `__init__` and never recomputed, so the window could never
adapt.

## Two more bugs found while fixing it

1. **`gui.ny` aborted on every resize event.** The handler did
   `self.root.rect.w = self.width` with no null check. The IDE drives its own
   layout and never installs a root widget, so `root` is `none` — resize
   handling died there before `_on_resize` could ever fire.

2. **Bound methods stored in an attribute still lost `self`.** Round 2 fixed
   direct calls and callbacks, but not `self._on_resize(w, h)` — invoking a
   callable held in an instance attribute. Reproduced minimally:

   ```
   h.set_cb(o.handler); h.fire(1024, 600)
     ->  handler self.n=none w=600 h=none      (before)
     ->  handler self.n=7    w=1024 h=600      (after)
   ```

   Fixed by applying `applyBoundSelf` in the attribute-call path of `evalCall`
   as well. This is the third distinct call path needing it; see the note at the
   end.

## New builtins

`gui_get_display_size`, `gui_get_window_size`, `gui_set_window_size` — so the
IDE can size itself to the actual desktop instead of assuming one.

## NythonIDE v4

`nython_ide.ny` rewritten (1005 lines). Every coordinate derives from the live
window size, recomputed in `_layout()` and re-run on every resize event.

Layout follows the VS Code / Code::Blocks arrangement:

* menu bar with eight dropdown menus (shadowed, with shortcut hints)
* toolbar: Run button plus Run/Debug/Tokenize/AST/Disasm/Profile mode pills
* activity rail (Explorer, Search, Source Control, Run, Extensions)
* collapsible **and drag-resizable** sidebar with an indented file tree
* editor: tab strip, line-number gutter, syntax highlighting, current-line
  highlight, minimap
* bottom panel with a **drag-resizable splitter**: Output, Problems, Terminal,
  Debug, Tokens, Workshop
* status bar with live cursor position and current window size
* Ctrl+P / Ctrl+K command palette with live filtering and keyboard selection

Event handling covers hover tracking, per-region click routing, wheel, drag
state for both splitters, text input, and shortcuts (Ctrl+B sidebar, Ctrl+J
panel, Ctrl+P/K palette, F5 run, Escape dismiss).

## Performance

The first v4 build ran at 7.3 fps — worse than v3 — because it re-tokenised
every visible line and re-measured every token on every frame. Two caches fixed
it:

* **C++ metrics cache** in `gui_measure_text` — (font, string) metrics never
  change, but layout code asks once per text run per frame.
* **Nython highlight cache** in `_draw_code_line` — stores the finished layout
  (text, colour, resolved x offset) keyed by line content, so a frame does no
  tokenising and no measuring at all for unchanged lines.

| build | fps |
|---|---|
| v4 initial | 7.3 |
| + metrics cache | 15.6 |
| + highlight/offset cache | **19.6** |

That is with v4 drawing roughly twice the content per frame that v3 did.

## Verification

Layout was checked by rasterising real frames and scanning them, not by eye.

Horizontal scan at y=300 (window 1326x678):

```
x    0- 51   rail
x   52-309   sidebar
x  310-365   gutter
x  367-1233  editor
x 1235-1325  minimap
```

Vertical scan at x=700:

```
y    0-105   menu + toolbar + tab strip
y  106-123   current-line highlight
y  124-477   editor
y  479-651   bottom panel
y  652-677   status bar
```

Coverage test (framebuffer reset to sentinel magenta between frames so stale
pixels cannot fake a pass):

| case | undrawn inside window | painted past edges |
|---|---|---|
| startup 1326x678 | 0 / 899,028 | 1 px |
| resized to 1024x600 | 0 / 614,400 | 1 px |
| resized to 1500x900 | 0 / 1,350,000 | 1 px |
| clamped 960x560 | 0 / 537,600 | 1 px |
| narrow 900x560 | 0 / 504,000 | 1 px |

Before the resize fix the 1024x600 case painted 6,880 px past the right edge and
11,466 px past the bottom.

Also: **314 / 314 examples pass**, GUI tests pass, and both
`-DNYTHON_WITH_IDE=1` and `=0` compile.

## Note on the recurring bound-method bug

`self` has now had to be re-supplied in three separate places: direct calls,
`callFunctionValue`, and attribute-stored callables. Attribute reads, callbacks
and stored callables each resolve functions through their own code, so a fourth
path would fail the same silent way — arguments shift left, attribute reads
return `none`, and nothing raises. Consolidating function resolution into one
routine is the durable fix; the three patches are correct but they are patches.

---

# Round 4 — consolidating the calling convention

Round 3 ended with a warning: `self` had been re-supplied for bound methods in
three separate places, and a fourth call path would fail the same silent way.
This round removes the class of bug rather than patching another instance.

## The consolidation

Every invocation, on every path, must bind parameters — and `bindParams()`
already delegates to `bindParamsKw()`. That makes `bindParamsKw()` the one
choke point through which all calls pass.

`bindParamsKw()` now takes the callee pointer and supplies the captured instance
itself. The three scattered fixes and the `applyBoundSelf()` helper are gone;
call sites pass the pointer they already have. A new invocation path physically
cannot forget, because it cannot bind parameters without going through here.

The consolidation immediately proved itself: **bound methods stored in a list or
a map now work, and those paths were never patched individually.** They were
latent bugs that would have surfaced later.

It also got faster — removing the per-call argument-vector copy took the IDE
from 19.6 to **22.4 fps**.

## A fourth bug, found while testing the consolidation

Keyword arguments were silently dropped for **methods** (plain functions were
fine):

```
def plain(a, b): ...     plain(b=20, a=10)   ->  a=10   b=20    correct
class C: def m(self,a,b) c.m(b=20, a=10)     ->  a=none b=none   wrong
                         c.m(10, b=20)       ->  a=10   b=none   wrong
```

`callMethod()` had no keyword-argument parameter at all. It constructed an empty
map and threw the caller's real one away. It now accepts the map and forwards
it, and `evalCall` passes the keyword arguments it had already parsed.

## Regression test added

`examples/test_bound_methods.ny` pins the calling convention so none of this can
regress silently. It covers 22 checks:

* a method called directly, passed as an argument, stored in an attribute,
  stored in a list, stored in a map, and assigned to a variable
* zero-argument methods, varargs methods, and varargs through a bound reference
* keyword / mixed / positional arguments on both plain functions and methods
* `map.remove`, `list.remove`, `list.contains`, `set.remove`

All 22 pass.

## Verification

* **316 / 316 examples pass** (the only non-passing entry is `nython_ide.ny`
  itself, which opens a window and runs until the test timeout — expected).
* IDE layout still pixel-exact: 0 undrawn pixels inside the window and 1 pixel
  past the edge, both at startup (1326x678) and after a live resize to 1024x600.
* 22.4 fps, up from 19.6.
* Both `-DNYTHON_WITH_IDE=1` and `=0` compile.

## Cumulative summary

| round | bug | effect |
|---|---|---|
| 1 | IDE ran on the bytecode VM, which has no `gui_*` natives | window never opened; message blamed GPU drivers |
| 2 | bound methods lost `self` | black window — 0 draw calls per frame |
| 2 | `thread_sleep` forwarded to `time_sleep` (seconds) | 16 s per frame |
| 2 | `map.remove` hit the set handler | interpreter abort |
| 2 | `list.contains` unimplemented | returned none |
| 2 | method named after a builtin | stack overflow / SIGSEGV |
| 3 | layout hardcoded 1600x960, no resize handler | blank window on a 1366x768 screen |
| 3 | `gui.ny` resize path dereferenced a null root | resize handling never ran |
| 3 | bound methods in attributes lost `self` | resize callback got shifted arguments |
| 4 | `self` re-supplied in three separate paths | list/map-stored callables still broken |
| 4 | `callMethod` discarded keyword arguments | keyword args silently ignored on methods |

---

# Round 5 — the parser bug behind the original screenshot

To judge the UI I had to stop guessing at it, so the test harness was upgraded:
the SDL stub now uses **real DejaVu font metrics** (baked advance-width tables,
so `TTF_GetStringSize` agrees with what will actually be drawn) and emits a
**draw log** of every rect, line and text run with its string, colour, size and
position. A replay script re-renders that log with PIL using real fonts, and an
audit script checks every text run for clipping and overlap.

That immediately found the bug.

## Root cause of the original screenshot

The audit reported the output console drawing at **y=2 and y=20** — on top of the
menu bar, at the very top of the window. That is exactly what the first
screenshot showed: `.../project | 7 files loaded` clipped against the top edge
with the rest of the window dark.

`ide_editor.ny` defines:

```
def set_pos(self, x, y): self.x = x; self.y = y
def set_size(self, w, h): self.rect.w = w; self.rect.h = h
```

`Parser::blockOrStmt()` handled an inline suite by parsing **one** statement:

```cpp
if(see(TokenType::BraceOpen)||see(TokenType::Do)||see(TokenType::Indent))
    return block();
return statement();          // <- everything after the first ';' discarded
```

So `set_pos()` assigned `x` and silently ignored `y`; `set_size()` set `w` and
ignored `h`. The console kept its constructor `y` of 0 and drew at the top of the
window. Semicolons worked correctly at top level (`script()` and `stmt()` both
loop over them), which is why this was never noticed.

**This was a parser bug, not a layout bug.** It predates every version of the
IDE and would silently corrupt any inline multi-statement method in any Nython
program.

## Fix

`blockOrStmt()` now collects all semicolon-separated statements into a block.
The statement parsers consume the `;` themselves, so a `consumed_semi_` flag on
the parser records that an inline suite continues; `expressionStmt()` sets it and
no longer eats the newline when a semicolon terminated the statement.

Two mistakes made on the way, both worth recording:

* The first attempt rewrote *every* statement terminator in `Parser.cpp`. Leaving
  a stray newline unconsumed corrupted the parse. Reverted to the single site
  that matters.
* Adding `consumed_semi_` to `Parser.hpp` changed the class layout, and only
  `Parser.cpp` was rebuilt — an ODR mismatch that produced a glibc heap
  assertion on any input, including `print "hi"`. Rebuilding every dependent TU
  fixed it. Worth remembering when editing a header in this project.

## Verification

With real glyph metrics and the full draw log:

```
text runs:            178
outside window:       0
overlapping pairs:    0
console line at y=518  'NythonIDE v4 ready'
console line at y=536  'Workspace: /project  |  3 files loaded'
```

Panel body starts at y=516, so the console is now inside the panel. Before the
fix those two lines were at y=2 and y=20 and overlapped the "Tools" and "Help"
menu labels.

* **315 / 315 examples pass.**
* `examples/test_bound_methods.ny` extended to 25 checks — inline suites with
  two and three statements, and top-level semicolons. All pass.
* Layout still exact at 1326x678 and after a live resize to 1024x600: 0 undrawn
  pixels inside the window, 1 pixel past the edge.
* Both build variants compile.

## Performance — an honest note

Frame rate is **~15-16 fps** in this Linux harness with `main.cpp` built at
`-O2` (the level your Release build uses); `-O1` gives ~14. Profiling the frame
from inside Nython:

```
chrome=13ms  sidebar=6ms  editor=40ms  panel+minimap=15ms
```

The cost is ~178 interpreted `draw_text` calls per frame. Each runs
`Renderer.draw_text` -> `Font.ensure_loaded` -> builtin, so interpreter overhead
exceeds the actual drawing. Calling the builtin directly in the editor's inner
loop (resolving the font handle once per frame rather than once per token)
gained about 1 fps.

Two things were checked and ruled out as causes:

* **The highlight cache works.** Instrumented over 40 frames it performed
  **11 `tokenise_line` calls total** — one per distinct line, zero re-tokenising.
* **Optimisation level is not the explanation.** `-O2` measured 15.0 / 15.3 /
  15.7 fps across three runs, `-O1` 13.0 / 13.7 / 14.1.

Round 4 reported 22.4 fps. That figure is **not reproducible** and should be
disregarded. Per-frame draw counts are byte-identical between the two
measurements (178 text runs, 65 rects per frame in both), so no extra work is
being done — the same work simply took twice as long in the later runs. The most
likely explanation is contention on this single-core build container after
several hours of compilation, but that is a hypothesis, not something that was
demonstrated. **~15 fps is the number that has been reproduced repeatedly; treat
it as the measurement.**

Note this is a software-only environment. A real Windows build renders through
the GPU, so the drawing half of each frame will be cheaper; the interpreter half
will not.

The real fix is architectural, not another cache: the IDE repaints its entire UI
every idle frame. A dirty-flag redraw would cut that to near zero when nothing
changes, and it is the single largest win available. It remains deliberately
undone — the callback cannot skip the `present()` that `Window.run()` issues, so
suppressing the repaint without also suppressing the present risks showing an
undefined backbuffer, and that is not something this harness can detect. Doing
it properly means changing the `Window.run()` contract so the callback can
report "nothing changed", which is a design decision rather than a bug fix.

---

# Round 6 — dirty-flag repainting

The performance note in round 5 said the real fix was architectural and left it
undone because a callback could not skip the `present()` that `Window.run()`
issues. That contract belongs to this project, so it was changed rather than
worked around.

## The contract change

`Window.run()` now inspects the callback's return value:

* returning **`false`** means "nothing changed" — the frame is neither drawn nor
  presented
* returning anything else, **including `none`**, presents exactly as before

Both the draw and the present are skipped together, deliberately. After
`SDL_RenderPresent` the backbuffer contents are undefined, so skipping the
repaint while still presenting would show garbage. Skipping neither or both are
the only safe options.

Backward compatibility was tested rather than assumed: a callback that returns
nothing still presents every frame (31 frames drawn, 30 presented), and
`none != false` evaluates true in Nython, so no existing code changes behaviour.

## The IDE side

`NythonIDE` keeps a `_dirty` flag. It is set by any non-idle event, by
`on_resize`, and by `_layout()`. `_frame()` returns `false` when nothing is
dirty. The terminal panel draws a blinking caret, so it forces `_dirty` while it
is the active panel — that animation is the reason this was treated as risky,
and it is handled explicitly rather than hoped for.

## Measured

Over a 20-second idle run at 1366x768:

| | before | after |
|---|---|---|
| presents | ~300 | **1** |
| rects drawn | ~19,500 | **65** |
| lines drawn | ~109,000 | **364** |
| text draws | ~53,400 | **178** |

The UI is drawn once and then costs nothing until something happens.

Three behaviours were verified, not assumed:

1. **Idle** — one frame, then silence.
2. **Resize** — a synthetic `SDL_EVENT_WINDOW_RESIZED` triggers a second frame,
   laid out correctly at 1024x600 with 0 undrawn pixels inside the window.
3. **Animation** — with the Terminal panel active, presents continue normally
   (178 in 15 s), so the blinking caret still blinks.

Note the stub's synthetic-resize trigger had to be changed from counting frames
to counting event polls, because frames no longer advance while idle — the
harness was measuring something that had stopped existing.

"Frames per second" is no longer the right metric for this UI. The number that
matters now is the cost of one repaint, which is ~65 ms at `-O2` in this
software-only harness and will be lower on Windows where drawing goes to the
GPU.

## Verification

* **315 / 315 examples pass.**
* 24 regression checks in `examples/test_bound_methods.ny` pass.
* Text audit on a real frame: 178 runs, 0 outside the window, 0 overlapping
  pairs, console correctly inside the panel at y=518 / y=536.
* Layout exact at 1326x678 and after a live resize to 1024x600.
* Legacy `Window.run()` callbacks unaffected.
* Both `-DNYTHON_WITH_IDE=1` and `=0` compile.

---

# Round 7 — "the IDE is not even opening"

Reported immediately after round 6 shipped dirty-flag repainting. Two causes were
found; both are Windows-specific, which is why the Linux harness kept passing.

## Cause 1 — missing headers (likely build failure)

`src/builtins/gui.cpp` uses `std::pair` (metrics cache) and `std::hash` (cache
key hashers) but included neither `<utility>` nor `<functional>`. libstdc++ on
Linux pulls both in transitively via `<unordered_map>`; MinGW does not guarantee
that. A build that fails here leaves the previous `nython.exe` in place, and an
old executable running the new `.ny` files will not start the IDE correctly —
the old interpreter has neither the bound-method fix nor the parser fix.

Fixed by including `<utility>`, `<functional>` and `<string>` explicitly.

## Cause 2 — a real bug introduced in round 6

`gui_poll_events` only ever surfaced `SDL_EVENT_WINDOW_RESIZED` and
`SDL_EVENT_WINDOW_CLOSE_REQUESTED`. Every other window event was dropped.

That was harmless while the IDE repainted unconditionally. With dirty-flag
repainting it is not: if the window is mapped or exposed *after* the single
initial present — which is normal on Windows — no event ever marks the UI dirty,
so it never repaints and the window stays blank forever.

`SDL_EVENT_WINDOW_EXPOSED`, `SHOWN`, `RESTORED` and `FOCUS_GAINED` are now
surfaced as an `"expose"` event, which the IDE treats as a change like any other
non-idle event.

## Safety net

Relying on the platform to deliver expose events is exactly the kind of
assumption this project has already been burned by, so it is no longer the only
line of defence. The IDE now forces a repaint after 30 consecutive skipped
frames — about twice a second at 60 Hz. Worst case, if every expose event were
missed, the window still updates rather than freezing.

There is also an explicit off-switch at the top of `NythonIDE.__init__`:

```
self.repaint_on_change_only = true
```

Set it to `false` to restore unconditional per-frame repainting. **Change this
first if the window is ever blank or stops updating.** Verified: `false` gives
270 presents in 15 s, `true` gives 34 in 20 s.

## A harness bug found while fixing this

The stub's SDL event constants were wrong — `SDL_EVENT_WINDOW_RESIZED` was
0x204 where real SDL3 uses 0x206, and `CLOSE_REQUESTED` was 0x20E where SDL3
uses 0x210. Because the stub and its consumer shared the same header the tests
passed anyway. They now match SDL3's actual enum ordering, taken from the
upstream headers rather than from memory.

## Verification

* **315 / 315 examples pass**; 24 regression checks pass.
* Idle: 34 repaints per 20 s (safety net), down from ~300 before round 6.
* Resize still repaints correctly at 1024x600, 0 undrawn pixels.
* Off-switch verified in both positions.
* Both build variants compile.

## If it still does not open

The two causes above are fixed blind — without the actual error, one of them is
a guess. To narrow it down:

1. Run `nython.exe` from `cmd.exe` rather than by double-clicking, so any
   message is visible instead of vanishing with the console window.
2. Note whether the **build** succeeded. If Code::Blocks reported errors, the
   old executable is still there and nothing in this archive is running yet.
   Use **Build > Rebuild**, not Build — `NythonExecutor.hpp` and `Parser.hpp`
   both changed, so every translation unit needs recompiling.
3. `nython.exe examples/check_sdl.ny` exercises the SDL path without the IDE.
   If that prints a version, SDL and the builtins are fine and the problem is in
   the IDE layer.

---

# Round 8 — systematic bug sweep

## 1. Portability: 14 missing standard headers (probable cause of the failed build)

`gui.cpp` was not the only file using standard-library symbols without including
the header that declares them. libstdc++ supplies them transitively; **MinGW does
not guarantee that**, so these are exactly the kind of thing that fails on
Windows while passing on Linux.

An audit of every source file found 14 cases, all now fixed:

| file | added |
|---|---|
| `src/Container.cpp` | `<utility>` `<functional>` |
| `src/GarbageCollector.cpp` | `<chrono>` |
| `src/Lexer.cpp` | `<sstream>` |
| `src/Object.cpp` | `<utility>` `<cstring>` |
| `src/Thread.cpp` | `<thread>` |
| `src/Value.cpp` | `<functional>` `<cstring>` |
| `src/builtins/core.cpp` | `<utility>` |
| `src/builtins/lang.cpp` | `<utility>` |
| `src/builtins/network.cpp` | `<cstring>` |
| `src/main.cpp` | `<algorithm>` `<sstream>` |

Re-audit reports 0 remaining. POSIX-only includes (`unistd.h`, `dirent.h`,
`termios.h`, `pthread.h`) were checked separately and are all correctly
`_WIN32`-guarded.

## 2. A memory leak introduced in round 4 — fixed

`makeBoundMethod()` allocated a fresh binding every time a method was read as a
value, and never released any of them. The dedup check looked up
`fn_val.value.p` in `bound_self_`, but that map is keyed by the *new* bound
pointer, so it could never hit.

```
var f = o.m   (in a loop)
   200k iterations ->  109 MB
     2M iterations -> 1023 MB
```

Fixed with a `(method ptr, instance ptr) -> bound ptr` cache so re-reading the
same method off the same object reuses one binding. After:

```
   200k iterations -> 7.5 MB
     2M iterations -> 7.6 MB    (flat)
```

## 3. The interpreter never garbage collects — PRE-EXISTING, NOT FIXED

This is the most serious thing in this document and it is **not fixed**, because
fixing it safely is a refactor, not a patch.

Measured, 300,000 iterations each:

| workload | peak RSS |
|---|---|
| arithmetic only, no calls | **7.5 MB** (flat) |
| plain function calls | **171 MB** |
| string building | **96 MB** |
| list + map allocation | **753 MB** |

Arithmetic is flat, so this is not general heap growth. **Every interpreted
function call leaks roughly 550 bytes** — the per-call `Context` is allocated
with `new` and never freed — and every container allocation leaks its `Object`.

`GarbageCollector` exists and is fully written, but `NythonExecutor` never calls
it, and it manages its own `MemoryCell` heap that the executor's
`new Object(...)` allocations never enter. Wiring it up means routing every
allocation through the collector and implementing correct root marking across
contexts, closures and generators.

**It was deliberately not attempted here.** A partially-correct mark phase frees
objects that are still reachable, which turns a leak into use-after-free
crashes — strictly worse. This needs to be done deliberately, with the existing
regression suite as a safety net.

### What this means for the IDE

Measured RSS growth over 20 seconds of an idle IDE:

| | growth |
|---|---|
| repaint every frame | **533 MB / 20 s** |
| dirty-flag repainting (round 6) | **45 MB / 20 s** |

The dirty-flag change reduces the bleed about 12x purely by making far fewer
interpreted calls, which is a mitigation, not a cure. At ~1.1 MB per repaint the
IDE will still exhaust memory over a long editing session. **Until the collector
is wired up, treat the IDE as something to restart periodically.**

## Verification

* **315 / 315 examples pass**, **30 / 30 tests in `tests/` pass** (that
  directory had never been run before this round — all 30 pass).
* 24 bound-method regression checks pass.
* Warning sweep with `-Wall -Wextra` on all changed files: clean.
* Header audit: 0 remaining issues.

---

# Round 9 — feature-by-feature IDE testing

Previous rounds verified geometry: that regions land where the layout says and
nothing overlaps. That says nothing about whether clicking anything *works*. So
the harness gained a scripted event driver, and every IDE feature was driven and
its rendered result asserted.

## Harness: scripted UI walkthrough

The SDL stub now reads `NY_SCRIPT` and injects real SDL events, one per poll:
`move / down / up / wheel / key / text / resize / wait / shot / quit`. `shot`
captures the last presented frame's full draw log — every rect, line and text
run with string, colour, size and position — so assertions run against what was
actually painted.

Shipped as `tests/ide/`: `ui_script.txt` (the walkthrough), `expectations.py`
(assertions), `check_shots.py` (the evaluator), `README.md`.

**21 UI states, all passing.**

## Bug: the IDE repainted once per event instead of once per frame

`Window.run()` invokes the callback for every event in a poll batch, and the IDE
repainted on each one. A three-event batch (move, down, up) did three full
repaints for one present. Measured on a menu-open frame: **552 text runs where
187 was correct** — a 3x waste on every click, and far worse during a drag,
where motion events arrive in bursts.

`Event.is_last` now marks the final event of a batch, and the IDE repaints only
on that one. Verified: 552 -> 187.

## Omissions found by driving the UI — all fixed

These were drawn but wired to nothing, so they looked functional and were not:

1. **Dropdown menu items did nothing.** Any click inside an open menu simply
   dismissed it. Items are now hit-tested and dispatched through
   `_menu_action()`: Toggle Sidebar / Panel / Minimap, Command Palette, Run,
   Tokenize, Show AST, Disassemble, Lang Workshop, Terminal, New File, Save,
   Exit.
2. **Tab close buttons did nothing.** The `x` glyph was painted but never
   hit-tested. Closing now works, refuses to close the last remaining tab, and
   re-points the active tab safely.
3. **The terminal could not be typed into.** Prompt and blinking caret were
   drawn but no keystroke reached them. It now accepts text, backspace and
   Enter, and implements `help`, `clear`, `files`, `version`, with an unknown
   command message.

## What was verified working

Activity rail switching (Explorer / Search / Source Control), sidebar collapse
and restore, sidebar drag-resize (258 -> 368 px confirmed in the draw log),
editor tab switching (buffer contents change), file-tree selection opening
files, all six bottom-panel tabs, panel splitter drag (panel top 478 -> 380
confirmed), toolbar mode pills, Run / F5, command palette open / live filter /
arrow selection / Enter execution / Escape, Ctrl+B, Ctrl+J, Ctrl+P, editor click
and typing, mouse wheel, and window resize to 1024x600 and 1500x900.

## Test-harness bugs found in the process

Worth recording, because three "failures" were the test being wrong:

* Click coordinates were guessed instead of derived. Clicking (27,180) hits
  Source Control, not Search. Coordinates are now taken from the rendered
  positions in the draw log.
* `mustnot=['main.ny']` for a sidebar assertion was wrong — the tab bar always
  shows `main.ny`. Region-scoped assertions were added for exactly this.
* The overlap checker flagged modal overlays. A dropdown paints an opaque panel
  over the UI beneath, so sharing coordinates with covered text is correct; the
  checker reasons about draw order, not occlusion. Overlay shots are now exempt,
  and the reason is documented rather than the check silently weakened.

## Verification

* **21 / 21 IDE UI checks pass.**
* **315 / 315 examples pass**, **30 / 30 `tests/` pass**, 24 bound-method checks.
* Layout: 0 undrawn pixels inside the window.
* Both build variants compile.

---

# Round 10 — projects, folders, icons, and 332 unreachable builtins

## The big one: 347 builtins were implemented but never registered

Building "Open Folder" surfaced this. The module dispatchers implement **537**
builtins; the registration vector listed **197**. The other 340 were unreachable
— calling them returned `none` silently, exactly like the `gui_*` bug from round
1 but far wider.

Casualties included essentially the whole filesystem layer:

```
os_listdir  os_isdir  os_isfile  os_mkdir  os_path_join  os_path_basename
os_path_dirname  os_path_ext  os_exists  getcwd  listdir  path_join
read_file  write  fs_stat  fs_walk  ...
```

332 names are now registered (event/key-name string literals such as `"down"`,
`"escape"`, `"backspace"` were filtered out — they are compared against event
fields, not builtins). Verified before/after:

```
os_exists("/tmp")   none  ->  true
os_isdir("/tmp")    none  ->  true
os_listdir(...)     none  ->  13 entries
os_path_join("/a","b")  none  ->  /a/b
```

A related trap found while wiring this: `file_write`/`file_read` take a **file
handle**, not a path. The path-based pair is `write(path, text)` /
`read_file(path)`.

## Icons — drawn, not downloaded

`ide_icons.ny` draws 21 icons from renderer primitives on a 16-unit grid:
folder, folder_open, file, file_code, explorer, search, git, run, debug, ext,
settings, terminal, warning, close, chevrons, save, new_file, project,
breakpoint, output.

Downloaded SVGs were considered and rejected: SDL3_image does not rasterise SVG,
so an `.svg` could not be drawn without a new rendering dependency; bitmap
exports would need one asset per size and per theme colour; and third-party icon
sets carry attribution obligations that would ship with the project. Drawn icons
scale to any size, take the theme colour as a parameter, need no files and no
licence.

## Real projects and folders

`ide_project.ny` adds `Workspace` and `Project`, backed by the real filesystem.

* **Open Folder** scans an actual directory (`os_listdir` / `os_isdir`),
  directories before files, each group sorted, dot-entries hidden, lazily
  expanded per node.
* **New Project** creates the folder, a `src/` directory, a `main.ny` and a
  `.nyproj` manifest, then opens it as the workspace and opens its target.
* **Open Project** parses the manifest and restores that state.
* A `.nyproj` is plain `key = value` text in the Code::Blocks spirit, readable
  and editable without the IDE.

Because there is no native file chooser, these use a modal path prompt with
inline editing, Enter to confirm and Escape to cancel.

File menu is now: New File, New Project…, Open File…, Open Folder…, Open
Project…, Save, Save All, Close Folder, Exit — with `Ctrl+O`, `Ctrl+K` and
`Ctrl+Shift+N` bound.

Clicking a file in the tree now opens the **real file** into a new editor tab.

## Visual work

Vertical gradients on menu bar, toolbar and status bar instead of flat fills;
the active editor tab is lifted with side separators; the Run button has a
gradient highlight and a drawn play icon; the Problems tab carries a count badge
(with its tab widened so the badge cannot sit on the label — caught by the
overlap check); the file tree uses folder / chevron / file-type icons with the
workspace root shown in the sidebar header.

## Verification

* **25 / 25 IDE UI checks pass**, now including the project workflow: File menu
  contents, dialog open, typed path, and project creation — verified by finding
  `main.ny` and `NyIdeTestProj.nyproj` **on disk** afterwards.
* **315 / 315 examples**, **30 / 30 tests**, 24 bound-method checks.

---

# Round 11 — Code::Blocks editor features

## Find and Replace (Ctrl+F / Ctrl+H)

A floating bar over the editor, styled like the VS Code widget. Live search as
you type, match count shown as "3 of 17", Enter cycles forward, the active match
is highlighted in the editor and the view jumps to its line. Ctrl+H adds a
replace field; Tab switches fields, Enter replaces the current match,
Ctrl+Enter replaces all. Replacing invalidates the syntax-highlight cache so the
edited lines re-tokenise.

## Go to Line (Ctrl+G)

Reuses the modal prompt, clamped to the buffer length.

## Breakpoints (F9, or click the gutter)

Code::Blocks-style gutter breakpoints, stored per file as `title:line` and drawn
as a red dot beside the line number. The **Debug** panel lists them with a live
count and tells you how to set one when empty.

## Verification

The suite grew from 25 to **32 UI states, all passing**: find bar opening with
"0 matches", live matching, cycling, replace-all applying to the buffer,
breakpoint set via gutter click, and the Debug panel listing it.

Two harness lessons, both worth recording because they were my errors rather
than the IDE's:

* The Problems count badge widened its tab, which shifted every panel tab to the
  right. A hard-coded click coordinate then landed on Terminal instead of Debug.
  Coordinates are now read back from the draw log.
* The suite resizes the window to 1500x900 near the end, so steps appended after
  that ran against different geometry. The script now restores 1326x678 before
  the appended block. A test that silently measures the wrong thing is worse
  than one that fails.

Full status: **32 / 32 UI checks**, **315 / 315 examples**, **30 / 30 tests**,
24 bound-method checks.

---

# Round 12 — caret, real compilation, debugging, full menu coverage

## The text cursor, and why clicks were landing in the wrong place

There was no caret at all. Worse, click-to-position was silently wrong:
`RichEditor` uses `line_h = 20` and subtracts its own `gutter_w = 56`, but the
IDE paints the gutter itself and sets the editor's rect to start *after* it. So
every click was offset by about seven columns and one row.

Fixed by giving the editor the IDE's real metrics (`gutter_w = 0`,
`line_h = LINE_H`, `char_w` measured from the actual mono font) and adding a
blinking caret drawn at the measured pixel width of the text before the cursor,
so it lands correctly on proportional as well as fixed-width glyphs. The caret
marks the frame dirty while blinking, the same mechanism the terminal prompt
uses, and is forced solid while typing.

Verified in the draw log: a 2x16 accent rect at the cursor position.

## Compilation and run are real now

`Run` / `F5` previously printed a hard-coded "finished in 12 ms". It now:

1. saves the active buffer to its real path,
2. locates the interpreter (`./nython`, `./nython.exe`, `bin/`, `bin/Release/`,
   `$NYTHON_EXE`, then PATH),
3. executes it with the appropriate flag for Run / Tokenize / AST / Disasm,
4. captures stdout and stderr, strips ANSI escapes, and writes them to Output,
5. parses diagnostics into the Problems panel and sets the build state.

Confirmed end to end: running `main.ny` printed `1` and reported
`finished in 754 ms`. With no interpreter on PATH it correctly reports
`sh: 1: nython: not found` and `failed with 1 problem(s)` — a missing
interpreter is a failed build, not a silent success.

## Every menu entry now does something

Previously only a handful were wired. Now implemented: Undo (50-deep snapshot
stack), Cut / Copy / Paste (line-based, with a clipboard), Find, Replace, Go to
Line, **Find in Files** (searches every code file in the workspace and lists hits
in Problems), Start Debugging, Step Over / Step Into, Toggle / Clear All /
Show Breakpoints, Settings, Documentation, Keyboard Shortcuts, About Nython
(reports live `lang_version()` and `gui_sdl_version()`).

## Debugging

Start Debugging stops at the first breakpoint and marks that line with an amber
highlight and a gutter arrow; F10 / F11 step; the Debug panel lists breakpoints
live. With no breakpoints set it runs to completion instead.

## Status bar is interactive

Segments for cursor position, problem count, breakpoint count, encoding,
language and window size. The first three highlight on hover and are clickable —
they open Go to Line, the Problems panel and the Debug panel. The brand block
turns red when the last build failed.

## Other

Editor scrolling now drives the drawn viewport (previously the editor always
painted from line 1 regardless of scroll), with a proportional scrollbar.
Modified tabs show a dot instead of a close glyph. Ctrl+S / Z / C / X / V bound.

## Verification

**36 / 36 UI checks** (up from 32), **315 / 315 examples**, **30 / 30 tests**,
24 bound-method checks. The suite now covers caret placement, typing, undo and
clipboard.

---

# Round 13 — real cursors, breadcrumbs, and editor polish

## Mouse cursors (new builtin)

`gui_set_cursor(name)` wraps `SDL_CreateSystemCursor` / `SDL_SetCursor` with
lazy creation and caching. Names: arrow, ibeam, hand, wait, progress, crosshair,
sizewe, sizens, move, no.

The IDE now changes the pointer by region: **I-beam** over editor text,
**EW-resize** on the sidebar grip, **NS-resize** on the panel splitter, **hand**
over the menu bar, activity rail and clickable status segments, arrow elsewhere.
Verified in the draw log by the cursor id actually set: `2` (TEXT) over code,
`12` (POINTER) on the rail, `8` (EW_RESIZE) on the sidebar grip, `9` (NS_RESIZE)
on the splitter.

While testing this the splitter grab zone turned out to be 4px, which is hard to
hit deliberately. Both splitters are now 6px and the sidebar grip 5px, matching
the feel of VS Code's.

## Breadcrumbs

A path strip between the tab bar and the editor: workspace › folder › file ›
enclosing symbol, with chevron separators. The last crumb is resolved live by
scanning upward from the cursor for the nearest `def` or `class`, so it tracks
where you are in the file.

## Editor rendering

* **Indent guides** — a faint rule every four columns of leading whitespace.
* **Bracket matching** — the bracket under the cursor and its partner are
  outlined; scans in the correct direction for both opening and closing
  brackets and respects nesting depth.
* **Scrollbar** — proportional, appears only when the buffer overflows.

## Toasts and tooltips

Transient notifications in the lower right with a coloured accent bar and icon,
expiring after ~3 s, used for save and build results. Hovering an activity-rail
icon shows its label in a tooltip, since the rail is icon-only.

## Verification

**36 / 36 UI checks**, **315 / 315 examples**, **30 / 30 tests**, 24
bound-method checks, both build variants compile. The breadcrumb bar moved the
editor down 24 px and every existing UI check still passed, which is the point
of asserting on rendered output rather than on coordinates.

---

# Round 14 — context menus, autocomplete, and a parser bug they exposed

## Parser: `if (A) or (B):` was a syntax error

Writing autocomplete needed `if (ch >= "a" and ch <= "z") or ch == "_":`, which
would not parse. `Parser::ifStmt()` consumed the opening paren unconditionally,
then `expression()` stopped at the closing paren, then `mustBe(ParenClose)` ran —
so anything following the group hit the colon check and failed:

```
if (a > 0) or (b < 5):     ->  Unexpected token: :
var r = (a > 0) or (b < 5) ->  fine
if (a > 0 and b < 5):      ->  fine
```

The paren is now only consumed for the walrus form `if (var n = expr):`;
otherwise `expression()` owns it and parses the whole condition including
sub-groups. Same fix applied to `elif`. Four checks added to
`examples/test_bound_methods.ny` covering `if (A) or (B)`, `if (A) and (B)`,
`elif (A) or (B)`, and that the walrus form still parses.

## Right-click context menus

Menus for the editor (Cut / Copy / Paste / Go to Line / Toggle Breakpoint /
Run), the file tree (Open / Reveal / Copy Path / Set as Workspace), the tab bar
(Close / Close Others / Copy Path / Save) and empty chrome (view toggles). They
flip to stay on screen near an edge, highlight on hover, and dismiss on Escape
or an outside click. The harness gained an `rdown` command to inject
right-clicks.

## Autocomplete (Ctrl+Space)

Suggestions are language keywords plus every `def`, `class` and `var` name in
the current buffer, de-duplicated and filtered by the word before the cursor.
Arrow keys move, Enter or Tab accepts and inserts only the missing suffix,
Escape dismisses. The popup follows the caret and flips left near the window
edge.

## Testing notes

Every feature was driven through the harness, and three of the failures were the
test rather than the code:

* A context-menu click at y=260 hit "Paste", not "Toggle Breakpoint" — menu item
  coordinates are computed from the item list, not guessed.
* The autocomplete test passed for the wrong reason: `must=['class','def']`
  matched the *editor text* behind the popup rather than the popup itself.
* Made deterministic by typing a known prefix — which then failed twice more,
  first because the cursor sat after a word ending in "ny" (prefix "nyc"), then
  because End left it at the end of that same word. It now opens a fresh line
  first, so the prefix is exactly what the test typed.

The second of those is the one worth remembering: a test that passes by matching
unrelated content is worse than one that fails.

## Verification

**42 / 42 UI checks** (up from 36), **315 / 315 examples**, **30 / 30 tests**,
28 bound-method and parser checks.

---

# Round 15 — text selection

The editor had a caret but no selection: you could not highlight a range, and
Copy/Cut always worked on the whole line.

## Model

An anchor plus the buffer cursor as the moving head. `_sel_range()` returns the
pair in document order and reports `none` for an empty selection, so callers
never have to reason about direction.

* **Shift + arrows / Home / End** extend; the same keys without Shift collapse.
* **Click and drag** selects; the anchor is set on mousedown, the head follows
  the pointer, `_pos_at()` converts pixels to (row, col) by measuring the actual
  glyph widths rather than assuming a fixed character cell.
* **Copy / Cut** use the selection when there is one and fall back to the whole
  line when there isn't.
* **Typing, Enter or Backspace with a selection replaces it**, taking an undo
  snapshot first.

## Testing

Each path was driven through the harness. The selection is asserted **as
painted pixels**, not just by its status message: a new `has_selection_highlight()`
check scans the draw log for a rect in the selection colour wider than 5 px.
That matters here — `Copied selection` in the status bar proves the code ran,
not that anything was highlighted.

One failure was again the test rather than the code: the drag test picked
y=166, which is a blank line in `main.ny`, so the selection was legitimately
empty and no highlight was drawn. Moved to a line with content.

## Verification

**47 / 47 UI checks** (up from 42), **315 / 315 examples**, **30 / 30 tests**,
28 bound-method and parser checks, both build variants compile.

---

# Round 16 — symbol outline and a light theme

## Symbol outline

A sixth activity-rail view, in the spirit of Code::Blocks' symbol browser: every
`class` and `def` in the active buffer, indented by nesting depth, with its line
number on the right and a distinct icon per kind. Clicking a symbol jumps the
editor to that line. The list is rebuilt from the buffer on each draw, so it
follows edits without a refresh step.

## Light theme

`IDETheme` now holds a `dark` flag and an `apply()` that assigns a full palette
for either mode, including semantic entries the code previously hard-coded:
`chrome_hi`, `gutter_bg`, `minimap_bg`, `status_bg`, `overlay`, `field` and
`scrim`. Every literal colour in the drawing code was replaced with the
corresponding theme entry, so overlays, dialogs, input fields and the modal scrim
all follow the theme rather than staying dark on a light background.

Toggled by **Ctrl+Shift+T**, the View menu, or the command palette.

## Testing

Both features driven through the harness, and the theme is asserted **from the
painted background pixel**, not from its status message — a toggle that updated
the label but not the palette would otherwise pass:

```
theme_dark        background (13, 15, 26)
theme_light       background (243, 244, 248)
theme_dark_again  background (13, 15, 26)
```

The outline jump test initially failed because it clicked the fourth row of a
list with three symbols, so nothing happened. That is the test being wrong
again, not the code — corrected to a row that exists.

## Verification

**52 / 52 UI checks** (up from 47), **315 / 315 examples**, **30 / 30 tests**,
28 bound-method and parser checks.

---

# Round 17 — the light theme made usable

Round 16 shipped a light theme and I flagged that it was incomplete: the chrome
followed the theme but `SyntaxHighlighter` kept its own hard-coded palette, tuned
for a near-black editor background. Keywords at `(196, 148, 255)` on a
`(252, 252, 254)` background are washed out to the point of being unreadable, so
the theme was present rather than usable.

## Fix

`SyntaxHighlighter.set_dark(on)` now swaps all thirteen token colours. The light
palette darkens and saturates every entry — keywords `(126, 42, 190)`, strings
`(150, 62, 30)`, comments `(38, 128, 60)`, numbers `(96, 118, 24)` — for contrast
against white rather than against black.

Switching the theme goes through `_set_theme()`, which repaints the chrome,
swaps the syntax palette **and drops the highlight cache**. That last part
matters: the cache stores each line's resolved token colours, so without
invalidation the editor would keep drawing the old palette until the text
changed.

## Testing

A new `token_color_is()` check asserts the colour a keyword is actually drawn
with, which is what distinguishes a working theme from one that only repaints
the chrome:

```
theme_dark   'class' drawn (196, 148, 255)
hl_light     'class' drawn (126, 42, 190)
```

## Verification

**53 / 53 UI checks**, **315 / 315 examples**, **30 / 30 tests**, 28
bound-method and parser checks.

---

# Round 18 — extensible highlighting, and an O(n²) that made large files unopenable

## Adding your own highlight tokens

`SyntaxHighlighter` gained an extension API:

```
add_keyword(word)          put a word in the keyword category
add_builtin(word)          ... the builtin category
add_type(word)             ... the type category
add_token(word, colour)    give a word its own colour (none removes it)
add_tokens(words, colour)  same, for a list
clear_tokens()             drop all custom colours
token_list()               list the custom words
load_rules(path)           read rules from a file; -1 if unreadable
```

Category members follow that category's colour in **both** themes
automatically; `add_token` colours are exact and win over every built-in
category.

Rules can live in a `.nyhighlight` file at the workspace root, loaded on startup
and whenever a folder is opened, so a project can colour its own vocabulary
without touching IDE source. A documented sample ships in the project root:

```
keyword spawn await defer
builtin emit assert_eq
type Vec3 Matrix Tensor2
255,120,0 TODO FIXME HACK NOTE
```

Also reachable from **Tools > Add Highlight Token…** (accepts `word` or
`word=r,g,b`) and **Tools > Reload Highlight Rules**.

Verified by the colour each token is actually drawn with, after typing them into
a buffer: `spawn` (196,148,255) as a keyword, `Vec3` (252,176,98) as a type,
`TODO` (255,120,0) from the custom rule.

## The bug this uncovered: opening a large file killed the IDE

Testing minimap scrolling needed a file long enough to scroll, so I opened
`lib/gui.ny` (13,036 lines). The process was **killed by the OOM reaper**.

`EditorBuffer._parse_content` walked the text one line at a time doing
`self.lines = self.lines + [line]` — copying the whole list every iteration —
and `rem = rem[nl+1:]` — copying the remainder of the file every iteration.
Both O(n²), and since the interpreter reclaims nothing, the cost showed up as
resident memory:

| file | before | after |
|---|---|---|
| 690 lines | 99 MB | **47 MB** |
| 3,087 lines | 1,353 MB | **47 MB** |
| 13,036 lines | OOM-killed | **56 MB** |

Now a single `string_split`. Worth recording: my first rewrite still measured
1.35 GB, because the trailing-newline handling I added rebuilt the list with
`keep = keep + [...]` — the same O(n²) pattern, reintroduced two lines below the
comment explaining why it was being removed. Shortening the count instead of
copying fixed it.

## Editor zoom and minimap navigation

**Ctrl +/- /0** resize the code font (8-30 pt). Line height, character width,
gutter, caret, selection and minimap all follow, and the highlight cache is
dropped because it stores pixel offsets measured at the old size. Also on the
View menu.

The minimap now shows a **viewport box that tracks the real scroll position**,
and clicking or dragging in it scrolls the document. Confirmed on the 13,036-line
file: clicks jumped to line 10,100 and line 2,619.

## Verification

**56 / 56 UI checks**, **315 / 315 examples**, **30 / 30 tests**, 28
bound-method and parser checks.

---

# Round 19 — the O(n²) accumulation pattern, project-wide

Round 18 found `x = x + [item]` inside a loop making large files unopenable.
That pattern was not unique to one function.

## The cost, measured

```
60,000 iterations of  l.append(i)     ->    26 MB
60,000 iterations of  l = l + [i]     ->  3,940 MB, then OOM-killed
```

Each `l = l + [i]` allocates a fresh list holding every element so far. The
interpreter reclaims nothing, so the whole quadratic series stays resident.

## Conversion

622 occurrences exist across the tree; most are in `examples/` with small,
fixed N. The shipped IDE and library code was converted — **271 sites**:

| file | sites | | file | sites |
|---|---|---|---|---|
| `lib/gui.ny` | 108 | | `lib/aiagent.ny` | 25 |
| `nython_ide.ny` | 32 | | `lib/webserver.ny` | 18 |
| `lib/stdlib.ny` | 31 | | `ide_editor.ny` | 17 |
| `lib/clientserver.ny` | 15 | | `lib/network.ny` | 8 |
| `ide_project.ny` | 5 | | `lib/sockets.ny` | 5 |
| `lib/os.ny` | 4 | | `lib/thread.ny` | 2 |
| `ide_workshop.ny` | 1 | | | |

The transform was applied only where the accumulator is declared as a list
literal in the same file and the appended expression is a single element, since
`append` mutates in place while `x = x + [e]` rebinds — the two differ if the
list is aliased.

## One regression, caught by the suite

`resized_small` reported overlapping text: at a 600px-tall window the file tree
drew a half-height row underneath the status bar. The clip rect hid the pixels,
so it was cosmetic, but the tree and outline now stop at the last row that fits
entirely rather than relying on the clip to cut one in half.

## What this fixed, and what it did not

It fixed **loading**: the 13,036-line `lib/gui.ny` went from OOM-killed to 56 MB,
and buffer parsing is now flat with file size.

It did **not** fix idle growth. The IDE still grows while running, and now grows
faster than the 45 MB / 20 s recorded in round 8 — around 95 MB / 20 s — because
it does considerably more per repaint than it did then (breadcrumbs, selection,
minimap viewport, caret blink forcing two repaints a second). Tokenising all
13,036 lines of a file in one pass still peaks at 1.6 GB.

Both remaining figures have the same cause, unchanged since round 8: **the
interpreter never garbage collects**. Accumulation was one avoidable multiplier
on top of it, and removing it was worth doing, but the underlying leak is what
sets the ceiling. Nothing here should be read as having addressed that.

## Verification

**56 / 56 UI checks**, **315 / 315 examples**, **30 / 30 tests**, 28
bound-method and parser checks, and `lib/stdlib.ny` and `lib/gui.ny` both still
import and run after conversion.

---

# Round 21 — reclamation extended to method calls

Round 20 reaped contexts for plain function calls only. The IDE barely improved,
because almost everything it does is a *method* call, and those allocate their
contexts at fourteen other sites.

## Coverage

`CtxReaper` is now installed at all fourteen per-call context sites: class
method dispatch, the four attribute-call paths, `callFunctionValue`, lambdas,
generator probes and `__init__`. Four sites are deliberately excluded because
their contexts are not per-call — class bodies, closure contexts, and the two
property tables.

The escape set moved from `std::set` to `std::unordered_set`. It is probed once
per call return against a set that grows with every closure and class, so an
O(log n) lookup was a per-call tax on the hot path.

## Result

| | before round 20 | now |
|---|---|---|
| 300k function calls | 171 MB | **8.3 MB** |
| IDE idle growth / 20 s | 96 MB | **25 MB** |
| `xor_training.ny` runtime | ~14 s | **3.6 s** |

The runtime drop is the interesting one: not allocating and then not touching
hundreds of megabytes is faster than doing so, so reclaiming memory made the
interpreter roughly four times quicker on allocation-heavy work.

## Fewer allocations at the source

Two additions let hot paths avoid allocating at all:

* `gui_measure_text_w(font, text)` returns a plain width instead of a `[w, h]`
  list, exposed as `Font.width()`. Callers that only need the width — caret
  placement, selection spans, right-aligned labels, tab widths — no longer
  allocate an Object per call per frame.
* `Renderer.fill_xywh()` and `fill_round_xywh()` take raw coordinates instead of
  a `Rect`.

87 call sites in `nython_ide.ny` were converted mechanically (30 width-only
measures, 32 fills, 25 rounded fills), verified by `Font.width(t) == measure(t)[0]`
and by the UI suite rendering identically afterwards.

## Still not fixed

Container allocation is untouched and still dominates what remains:

| 300k iterations | before | now |
|---|---|---|
| list + map allocation | 753 MB | **753 MB** |
| string building | 96 MB | **96 MB** |

Every `Object` created for a list, map or string is still never freed. The
conservative argument that works for contexts does not transfer: `Value`s hold
`Collectable*`, are returned, stored in other containers and aliased freely, so
their lifetime cannot be settled locally. That needs tracing collection.

## A harness change worth flagging

`xor_training.ny` began failing the example sweep — not from a crash, but by
exceeding the sweep's 20 s per-file limit under the load of 315 back-to-back
runs on a single core. It passes 8 times out of 8 in isolation at 3.6 s. The
sweep limit was raised to 45 s. That is a change to the harness, not a fix to
the code, and it is recorded as such.

## Verification

**315 / 315 examples**, **30 / 30 tests**, **56 / 56 IDE UI checks**, and the
escape-analysis checks (closure over a local, nested closures, 100 live
closures, 200-deep recursion) all pass.

---

# Round 22 — navigation, and a wheel-routing bug

## Container allocation: investigated, not fixed

The remaining leak is `new Object(...)` for lists, maps and strings. One cheap
hypothesis was tested and rejected: `Container`'s constructor calls
`container->reserve(4)`, so eager bucket allocation looked like a candidate.
Removing it changed nothing (753 MB -> 790 MB, i.e. noise), because the cost is
in the map **nodes** — a three-element list stores four keys ("0", "1", "2",
"__len__"), each a `std::string` keyed node. The change was reverted rather than
left in as a plausible-looking no-op.

That confirms the remaining leak needs tracing collection, as stated in round 20.

## Clickable Problems

Entries in the Problems panel now navigate: clicking one opens the reported file
from the workspace root if it exists and jumps to the reported line. The list
also scrolls.

## Wheel scrolling for the sidebar and panel

The wheel previously only reached the editor. It now routes by region — file
tree and outline, bottom panel, or editor.

Writing the test exposed a real bug: routing used `self.mx` / `self.my`, which
are only updated on **mousemove**. A wheel event carries its own pointer
position, so scrolling without moving first was dispatched to whichever region
the pointer had last been *moved* over. Wheel events now set the position from
the event itself. This would have shown up in normal use as the wheel scrolling
the wrong pane after a click.

## Recent files

Files opened through the tree, dialogs or Problems navigation are remembered
(most recent first, capped at 8) and listed by **File > Recent Files**.

## Testing notes

Three assertions were wrong before the code was, and each is worth recording:

* Sidebar scrolling was asserted against a tree with 19 rows in a viewport that
  fits 24 — there was nothing to scroll, so a passing scroll and a broken one
  looked identical. The test now expands a large directory first.
* The appended block ran after earlier steps had changed the workspace to the
  test project and dragged the panel splitter, so every coordinate was off. The
  block now resets the splitter and reopens the source folder before it starts.
* The Problems list holds whatever the last build produced — one entry after the
  suite's F5, not the three seeded at startup — so clicking "row 1" hit nothing.
  It now clicks row 0 and asserts that navigation happened rather than a fixed
  line number.

Scrolling is asserted from the **first row actually drawn** in the sidebar, so a
scroll that does nothing cannot pass.

## Verification

**61 / 61 IDE UI checks** (up from 56), **315 / 315 examples**, **30 / 30
tests**, escape-analysis checks, and both build variants compile.

---

# Round 23 — line operations, and three bugs found while testing them

## Added

* **Toggle Comment** (`Ctrl+/`) — comments the selection or cursor line, and
  uncomments if every non-blank line in the range is already commented, which is
  how editors behave on mixed input. Inserts at the indentation, not column 0.
* **Duplicate Line** (`Ctrl+D`), **Delete Line** (`Ctrl+Shift+K`),
  **Move Line Up/Down** (`Alt+Up` / `Alt+Down`).
* **Bracket and quote completion** — typing `(`, `[`, `{`, `"` or `'` inserts the
  partner and leaves the caret between them.

All are on the Edit menu as well as the shortcuts.

## Three bugs the tests exposed

**1. `Ctrl+Shift+K` opened the Open Folder dialog.** The `Ctrl+K` branch was
tested first and matched regardless of Shift, so the new shortcut could never
fire. `Ctrl+K` now requires Shift to be up. Any shortcut sharing a key with a
modifier-extended one has this hazard.

**2. Auto-indent was applied twice.** I added indentation after Enter without
checking that `EditorBuffer.newline()` already copies the previous line's indent
and adds a level after `:`. New lines came out at eight spaces where four was
correct. The addition was removed rather than the existing behaviour changed —
the editor was already right.

**3. `insert_char` advanced the caret by one regardless of input length.** A
text-input event can carry several characters (paste, IME, a fast key sequence),
so typing `foo` left the caret after `f`, and the next character landed inside
the word — `foo` then `(` produced `f()oo`. Now advances by `len(ch)`.

That third one was pre-existing and would have shown up as corrupted text on any
multi-character paste.

## Testing notes

The line-operation block initially asserted against `main.ny`, whose contents
depend on what earlier steps in the suite left open and saved. It now starts
from **File > New File** and types its own known content, so the assertions hold
regardless of what ran before.

A new `code_row_at()` check reads a rendered code line back: its joined token
text and the x of its first non-blank glyph. Indentation can only be measured
that way, because leading whitespace is drawn as its own segment starting at the
left margin. One exception is documented in the expectations: a commented line
is emitted by the highlighter as a **single token covering the whole line
including its leading whitespace**, so for those the text is asserted and the
position is not.

## Verification

**66 / 66 IDE UI checks** (up from 61), **315 / 315 examples**, **30 / 30
tests**, escape-analysis checks all pass.

---

# Round 24 — execution modes, introspection, and the AI assistant

## Tokenize was running the file, not tokenising it

The build runner passed `--tokens`. `src/main.cpp` accepts **`--tokenize`**.
An unrecognised flag was treated as a filename-adjacent argument, so "Tokenize"
quietly executed the program instead of dumping its token stream. Verified
against the interpreter directly: `--tokenize`, `--ast`, `--disasm` and `--vm`
all produce their expected output.

## Run modes

Now `Run · VM · Debug · Tokenize · AST · Disasm`, with **Run on VM** added to the
Build menu. `--vm` executes through the bytecode VM instead of the interpreter.

## Introspection panel

Tokenize / AST / Disassemble produce a dump rather than program output, so their
result now goes to the **Tokens** panel (which the IDE switches to
automatically) instead of being interleaved with console output. Captured
368 lines of token XML in testing.

## AI assistant

A seventh rail view backed by `lib/aiagent.ny`'s `CodeAnalyzer`. It reviews the
active buffer and lists findings — debug prints, TODO/FIXME, infinite loops,
null assignments — each with its line and source text, and clicking one jumps
there. Results are cached per file rather than recomputed each frame, and
**Tools > Analyse Buffer** forces a re-run.

## What the tests established, including one real limitation

`vm_run` reports **"VM failed"** on a file the interpreter runs without
complaint: the VM rejects it with a SyntaxError. That is not a bug in this
round's work — it is the second-class-engine problem first recorded in round 1,
where the VM lacks most of the interpreter's capability. The check therefore
asserts that the VM path is *invoked and reported*, not that the file runs on
it, and the reason is written into the expectations file so it is not later
mistaken for a weakened test.

Three other assertions were adjusted to test the right thing:

* `problem_click` depended on the previous build having failed. With a working
  interpreter present it succeeded, leaving Problems empty and nothing to click.
  The block now populates Problems deterministically via **Find in Files**.
* `ai_jump` asserted `Line 14`, but the line number depends on the file on disk,
  which earlier steps may have saved. It now asserts that navigation happened.
* A stray `nython` binary copied into the tree during testing changed build
  outcomes for the whole suite. Removed; the suite instead points at an
  interpreter through `NYTHON_EXE`, which `_interpreter_path()` already honours.
  `tests/ide/README.md` documents this.

## Verification

**70 / 70 IDE UI checks** (up from 66), **315 / 315 examples**, **30 / 30
tests**, escape-analysis checks all pass.

---

# Round 25 — keyword arguments have never worked on the bytecode VM

Round 24 recorded that the VM rejected a file the interpreter ran. Rather than
leave that as an unexplained note, this round measured it: **302 of 315 examples
passed under `--vm`**, and several of the failures were segfaults, not errors.

## Root cause

Bisecting `vm_audit22.ny` narrowed the crash to `sorted(words, key=lambda w: len(w))`,
then to any keyword call at all — `g(1, key=2)` segfaults. AddressSanitizer put
it in `pop()`: an **operand-stack underflow**. Disassembly showed why:

```
LOAD_NAME     g
LOAD_CONST    1
NOP                 <- the keyword argument
CALL_FUNCTION 2     <- argc counted it anyway
```

The VM compiler detects keyword arguments with
`arg->type() == NT::ASSIGNMENT`. The parser emits **`KeywordArgNode`**
(`NT::KEYWORD_ARG`). The test never matched, so every keyword argument fell
through to the positional branch, where `visit()` had no case for it and emitted
`NOP` — while `argc` still counted it. `CALL_FUNCTION` then popped one item too
many and took the callee as an argument, running off the bottom of the stack.

Keyword arguments have therefore never worked on the VM.

## Fixes

* The compiler now handles `NT::KEYWORD_ARG` (and still accepts `ASSIGNMENT`).
* `sorted` computes keys **before** sorting rather than calling the key function
  from inside `std::stable_sort`'s comparator, which re-entered the VM mid-sort.
  This also calls the key function n times instead of O(n log n) and keeps the
  comparator consistent for impure key functions. Both definitions of `sorted`
  were patched — the second overrides the first.
* The active `sorted` now reads `key` and `reverse` from the keyword map;
  previously `sorted(xs, reverse=true)` silently ignored `reverse`.
* `pop()` and `peek()` are bounds-checked. A stack imbalance is a compiler bug,
  but it should surface as a diagnosable error instead of a segfault.
* `call_stack_` is a `deque` rather than a `vector`: `run_loop()` holds
  `CallFrame& fr` across an instruction while several opcodes push a frame, and
  vector growth invalidated that reference.
* The `--vm` entry point catches `SyntaxError` and `UnexpectedCharError`, so a
  construct the VM cannot compile reports a message instead of aborting through
  `std::terminate`.

## Result

| | before | after |
|---|---|---|
| examples passing under `--vm` | 302 / 315 | **307 / 315** |
| segfaults among the failures | 6 | **2** |

Four new checks were added to `examples/test_bound_methods.ny` covering keyword
arguments, out-of-order keywords, `sorted(key=…)` and `sorted(reverse=…)`. They
pass on **both** engines.

## What is still wrong with the VM — stated plainly

Running that same test file under `--vm` fails **9 of its checks**, all
pre-existing and untouched here:

* bound methods lose `self` on the VM in five of the six ways a method can be
  referenced (the interpreter fix from round 4 was never applied to the VM)
* `varargs when bound`, `map.remove`, and `set.remove` behave differently

Six examples also still fail to compile on the VM (`await`, some numeric
literals), and two still segfault. The VM remains a second-class engine; this
round removed one whole class of crash from it, not the gap.

## Verification

**315 / 315 examples** and **30 / 30 tests** on the interpreter, **70 / 70 IDE
UI checks**, and the new keyword-argument checks pass on both engines.

---

# Round 26 — the VM's calling convention brought in line with the interpreter

Round 25 ended by listing 9 checks that `examples/test_bound_methods.ny` failed
under `--vm`. This round closes all of them.

## Bound methods on the VM

`get_attr()` returned `VMVal::make_func(sub)` for an instance method — a bare
function with no instance attached — so `var f = obj.m; f(1)` lost `self` and
shifted every argument left. Exactly the interpreter defect from round 4, in a
different engine.

The VM already had a `__super_bound__` convention for `super()` bindings that
`vm_call` understands, so instance methods now use the same shape: a map tagged
`__bound_method__` holding `__fn__` and `__self__`. That covers a method read as
a value, passed as an argument, stored in a list, stored in a map, or assigned
to a variable.

## Callables held in attributes

`vm_call_method()` only recognised a raw `FUNCTION` in an instance attribute,
and called it with the *containing* object as `self`. So `self.cb = other.method`
followed by `self.cb(a, b)` either failed or rebound to the wrong instance.
A `__bound_method__` or a native now dispatches through `vm_call`, which honours
the self the value already carries; a bare `FUNCTION` keeps its previous
behaviour.

## Container methods

* `map.remove(k)` / `map.delete(k)` did not exist on the VM — only `pop`. The
  call returned `none` and left the key in place. They are now aliases of `pop`.
* **`Set` was not a VM global at all**, so `Set([1,2,3])` produced nothing and
  `len()` reported 0. The VM's set methods already represent sets as
  deduplicated lists; `Set(iterable)` now builds one.

## Result

`examples/test_bound_methods.ny` — 28 checks covering the calling convention,
containers, parenthesised conditions, escape analysis and keyword arguments —
now **passes completely on both engines**:

```
interpreter : PASS
--vm        : PASS      (was 9 failures at the start of this round)
```

## Still outstanding on the VM

Eight examples still fail under `--vm`: six are compiler gaps (`await`, some
numeric literals) reported cleanly as `VM SyntaxError` since round 25, and
**two still segfault** — `sentiment_classifier.ny` and `transformer_demo.ny`.
Those have not been diagnosed. The VM is much closer to the interpreter than it
was, but it is not yet equivalent, and nothing here should be read as claiming
otherwise.

## Verification

**315 / 315 examples** and **30 / 30 tests** on the interpreter, **307 / 315**
under `--vm`, **70 / 70 IDE UI checks**, and the calling-convention suite green
on both engines.

---

# Round 27 — the last two VM segfaults

Round 26 left `sentiment_classifier.ny` and `transformer_demo.ny` crashing under
`--vm`, undiagnosed. Both are fixed.

## Diagnosis

Bisecting each file put the crash inside a tensor expression. AddressSanitizer
put it precisely: a null dereference in `register_nytorch_builtins()`.

```cpp
globals_["tensor_add"] = ... {
    if(a.size()<2 || a[0].type!=VMType::LIST) return VMVal::make_list();
    auto& la=*a[0].list;  auto& lb=*a[1].list;   // a[1] never checked
```

The first argument was guarded; the second was dereferenced blind. Passing
`none` — which happens as soon as any earlier tensor call returns `none` —
dereferenced a null `shared_ptr` and killed the process. 28 such dereferences
existed across the tensor builtins.

Note the line numbers ASan first reported were wrong: the binary had been built
several edits earlier. Rebuilding it before trusting the trace was necessary,
and worth remembering — a stale sanitizer build points confidently at the wrong
function.

## Fix

A `vm_arg_list(args, i)` accessor returns the argument's list when it really is
one and an empty list otherwise. All 102 affected lines in the nytorch block now
go through it, so a missing or wrong-typed argument degrades rather than
crashing.

Results on valid input are unchanged, verified against the interpreter:

```
tensor_add([1,2,3],[10,20,30])  ->  [11.0, 22.0, 33.0]   both engines
tensor_dot                      ->  140.0                both engines
tensor_sum / mean / max         ->  6.0 / 2.0 / 3.0      both engines
```

## Result

| | round 25 | round 26 | now |
|---|---|---|---|
| examples passing under `--vm` | 307 / 315 | 307 / 315 | **309 / 315** |
| segfaults | 2 | 2 | **0** |

**No VM crashes remain.** All six remaining failures exit cleanly with
`VM SyntaxError` — compiler gaps (`await`, some numeric literals), not memory
faults.

`examples/test_vm_tensor_guard.ny` was added, covering both the numeric results
and the degrade-don't-crash behaviour, and passes on both engines.

## Verification

**315 / 315 examples** and **30 / 30 tests** on the interpreter, **309 / 315**
under `--vm` with zero crashes, **70 / 70 IDE UI checks**, and the
calling-convention suite green on both engines.

---

# Round 28 — the example sweep was counting failures as passes

Chasing the VM's remaining `SyntaxError`s turned up something more important
than the errors themselves.

## `run_file()` swallowed every error and exited 0

The interpreter fails `chain2.ny` and `showcase_v2.ny` with exactly the same
syntax errors the VM reports. It printed a `[DBG SyntaxError]` line to stderr —
and then **returned success**. `run_file()` was `void`, every catch block fell
through, and `main` returned 0 regardless.

Any harness that judged success by exit status counted those files as passing.
That includes this project's own example sweep, which is how the number stayed
at "315 / 315" while three files were failing to parse.

`run_file()` now returns a status: 2 if the file cannot be read, 1 on lex,
parse, runtime or uncaught-exception failure, 0 otherwise. The true numbers:

| | reported before | actual |
|---|---|---|
| examples passing (interpreter) | 316 / 316 | **311 / 316** |

Five real failures, previously invisible. Three are now fixed.

## Fixed: `lib/aiagent.ny` recursed until the stack ran out

`FileAssistant.read_file(self, filename)` called `read_file(path)`. Inside a
method of that name the bare call resolves back to the method, so it recursed
until the guard added in round 2 stopped it. Changed to `cat(path)`, the same
path-based read under a different name. `test_aiagent.ny` now passes all 39 of
its checks.

## Fixed: `repeat N:`

Only `repeat: ... until cond` parsed. A count was read as the start of the body
and the parser then demanded `until`, reporting "Expected Until, but found
Colon". `repeatStmt()` now also accepts a count and desugars it to a counted
while-loop with a generated counter. Both forms verified on both engines.

## Not fixed: method chains across lines

```
var a = [1,2,3]
    .filter(lambda x: x > 1)
```

fails with "Unexpected token: 4"; the single-line form works. The token stream
is exactly `BracketClose NewLine Indent Dot`, and a skip for that sequence was
added to `Parser::postfix()` — it did not take effect, and the cause was not
found before this round ended. **The change was reverted rather than left in**:
inert code that looks like a fix is worse than a known gap. `chain2.ny`,
`demo_realworld.ny` and `edge_dbg5.ny` still fail on both engines for this
reason.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **313 / 316** | **311 / 316** |
| tests | 30 / 30 | — |
| IDE UI checks | 70 / 70 | — |

The VM is now within two files of the interpreter, and both remaining
differences are `await` support, not crashes.

---

# Round 29 — everything passes, on both engines

Starting point: 313 / 316 on the interpreter, 311 / 316 on the VM, with the
sweep newly reporting honest exit codes after round 28.

## Method chains across lines

```
var a = [1,2,3]
    .filter(lambda x: x > 4)
    .map(lambda x: x * 2)
```

The lexer emits `NewLine Indent` between the receiver and the `.`, which ended
the statement. Round 28's attempt failed and was reverted; a parse trace showed
why the second attempt was needed too:

1. `postfix()` now looks ahead past `NewLine` / `Indent` / `Dedent` and joins the
   chain **only when a `.` genuinely follows**, so statement boundaries are
   untouched. The first version used `peek(1)` where `peek(0)` was the current
   token, so the lookahead was off by one.
2. Joining left the lexer's paired `Dedent` orphaned — that indent never opened
   a block — and the statement parser rejected it ("Unexpected token: 4").
   `postfix()` now counts the indents it consumed and retires the matching
   dedents, including the case where the statement's terminating `NewLine` sits
   in front of the `Dedent`.

## `repeat N:` and keywords as names

`repeat N:` desugars to a counted while-loop (round 28). `await` and `async` are
now accepted as identifiers, because `lib/thread.ny` declares `def await(self)`
— which had made `test_thread.ny` and `test_all_libs.ny` unparseable on the VM.

## A pass that was not a pass

With chaining fixed, `chain2.ny` "passed" under `--vm` — and printed nothing
useful, because the VM has no `filter`, `map`, `each` or `reduce` on lists.
Those calls returned `none`, and printing `none` exits 0, so the sweep counted
it. The dedicated check caught what the sweep could not.

All four are now implemented on the VM, dispatching the callback through
`vm_call`. `list_method` had to stop being `static` to reach the VM instance.

## Result

| | interpreter | `--vm` |
|---|---|---|
| examples | **317 / 317** | **317 / 317** |
| `tests/` | 30 / 30 | — |
| calling convention | PASS | PASS |
| tensor guard | PASS | PASS |
| syntax forms | PASS | PASS |
| IDE UI checks | 70 / 70 | — |

Both build variants compile. `examples/test_syntax_forms.ny` was added covering
multi-line and single-line chains, both `repeat` forms, and a method named
`await`; it runs on both engines.

One note on that test: its first version asserted `[20, 16, 24]` and failed on
both engines — because 5 > 4 and I had dropped it from the expected output. The
engines agreed with each other and disagreed with me, which is the right way
round. The expectation was corrected, not the code.

---

# Round 30 — the Search view, and preferences that persist

## Workspace search

The Search rail view had been a painted placeholder since it was added: an input
box and the words "Search code / files", wired to nothing.

It now scans every code and text file in the workspace for the query and lists
each match with its file, line and the source line itself. Typing filters live
(from two characters), clicking a result opens that file at that line, and the
count appears in the status bar. Selecting the Search icon focuses the box, so
typing goes to it rather than the editor; global shortcuts still pass through.

Measured on this project's own tree: `tensor` returns 13 results across 2 files,
and clicking one opens `CLAUDE.md` at line 78.

## Settings persistence

Preferences are written to a `.nyide` file beside the workspace as plain
`key = value` lines: theme, font size, sidebar width, minimap and panel
visibility. Loaded at startup, saved from **Tools > Save Settings** and on Exit.

Verified across a restart rather than by inspection: with the theme toggled to
light and the font zoomed to 15, a fresh launch painted background
`(243, 244, 248)` and drew code at size 15.

## A UTF-8 bug found while testing

Search snippets were truncated with `string_slice(text, 0, 40)`. `string_slice`
cuts by **byte** offset, so a snippet ending mid-character produced invalid
UTF-8 — the draw log became undecodable, which is how it surfaced. The sidebar
is clipped anyway, so the truncation was removed rather than made
character-aware. The shot checker also now reads logs with `errors='replace'`,
so a malformed byte reports a failing check instead of crashing the checker.

That cut is a real defect wherever `string_slice` meets non-ASCII text, not only
here.

## Checker exemption, stated plainly

Three search shots are exempt from the overlapping-text check. Result snippets
are drawn full-length and cut by the sidebar's clip rect; the checker reasons
about draw order, not clipping, so it sees them running under the editor text.
This is the same blind spot already documented for modal overlays. The exemption
is recorded in `expectations.py` next to the reason.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **317 / 317** | **317 / 317** |
| `tests/` | 30 / 30 | — |
| calling convention / tensor / syntax | PASS | PASS |
| IDE UI checks | **74 / 74** | — |

---

# Round 31 — strings measured in characters, on both engines

Round 30 noted in passing that `string_slice` cuts by byte offset, and that this
is a defect wherever it meets non-ASCII text. Measuring it showed the problem was
wider than the one call site.

## The inconsistency

On the interpreter:

```
len("héllo wörld")               ->  11    characters
string_slice(s, 0, 5)            ->  "héll"  four characters, five bytes
string_find(s, "ö")              ->  8      byte index; the character index is 7
```

`len()` counted characters while `string_slice` and `string_find` worked in
bytes, so the two could not be combined. `string_slice(s, 0, len(s))` did not
round-trip, `string_slice(s, string_find(s, x), ...)` mixed units, and a slice
landing mid-character emitted invalid UTF-8 — which is exactly how this surfaced
in round 30, when a truncated search snippet made the draw log undecodable.

The VM was internally consistent but disagreed with the interpreter: it measured
**everything** in bytes, so `len("héllo wörld")` returned 13 there.

## Fix

UTF-8 index helpers were added to both engines — character count, character
index to byte offset, byte offset to character index — and `len`,
`string_slice`, `string_find` and `string_rfind` now all speak characters.
Both engines agree, and ASCII behaviour is unchanged.

```
len(s)                  11      both engines
string_slice(s, 0, 5)   "héllo" both engines
string_find(s, "ö")     7       both engines
string_slice(jp, 2, 5)  "語テキ"  both engines
```

`examples/test_string_unicode.ny` pins this down with 15 checks: character
lengths, slicing at the start, middle and tail, round-tripping through `len()`,
find returning a character index, find and slice composing, and ASCII left
alone. It passes on both engines.

## Known limitation, not fixed

`string_upper` and `string_lower` remain ASCII-only: `string_upper("héllo")`
returns `"HéLLO"`. Correct case mapping for non-ASCII needs Unicode case tables,
which is a larger piece of work than index arithmetic and was not attempted.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **318 / 318** | **318 / 318** |
| `tests/` | 30 / 30 | — |
| calling convention / tensor / syntax / unicode | PASS | PASS |
| IDE UI checks | **74 / 74** | — |

---

# Round 32 — the standard library reachable from the VM

"Are all features accessible from the language?" turned out to have a measurable
answer, and it was bad.

## Measurement

A probe was generated from the interpreter's registration table — 536 names,
each tested for whether it resolves — and run on both engines:

| | unreachable |
|---|---|
| interpreter | **0** of 536 |
| bytecode VM | **472** of 536 |

The VM implements about 64 natives of its own. Every other builtin silently
evaluated to `none` there, so roughly 88% of the standard library was unusable
from a program run with `--vm` — the whole filesystem, hashing, encoding, JSON
and networking surface among it.

## Bridge

`load_var()` now falls back to the interpreter's builtin table when a name is
not a VM global, wrapping it as a native. Only names the interpreter actually
registers are wrapped, so an undefined variable still reads as `none` rather
than becoming callable.

The conversion between `Value` and `VMVal` lives in `main.cpp`, where both types
are complete (`VirtualMachine.hpp` is included *by* `NythonExecutor.hpp`, so the
VM header cannot name `Value`). The VM exposes two function-pointer hooks that
`main` installs. Scalars, strings, lists and maps convert in both directions, so
a list built in the program can be passed to an interpreter builtin and a map
returned from one can be indexed.

| | before | after |
|---|---|---|
| builtins unreachable on the VM | 472 | **9** |

The remaining nine are not builtins at all — `and`, `break`, `continue`, `self`,
`none`, `undefined` and similar, which the probe picked up from the registration
table's string literals.

## Two bugs found while building it

* **Wrong union member.** `value_to_vm` read `Value::value.p` for containers;
  collectables live in `value.gc`. Scalars converted fine, so the bridge looked
  like it worked — but every builtin returning a list or map came back empty.
  `os_listdir("/tmp")` returned `none` while `os_path_join` returned correctly.
  Caught by comparing engine output rather than by the suite.
* **Access-specifier damage.** `NythonExecutor` is a `struct`, so members
  default to public. A `private:` added to scope two new accessors flipped
  everything after it, including `execute()`. The compiler caught it; it is
  recorded because the same edit on a `class` would have been correct.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **319 / 319** | **319 / 319** |
| `tests/` | 30 / 30 | — |
| bound methods / tensor / syntax / unicode / bridge | PASS | PASS |
| IDE UI checks | **74 / 74** | — |

`examples/test_vm_builtin_bridge.ny` covers scalars, containers in both
directions, and arguments crossing the bridge; it passes on both engines.

---

# Round 33 — the two engines now answer the same

Round 32 made the standard library reachable from the VM. That raised the
obvious follow-up: where a builtin exists on *both* engines, the VM's own
version shadows the bridged one — do they agree?

## Coverage first

The bridge is installed at the only VM site that executes code (`--vm`). The
others were checked: `--disasm` compiles without running, and `run_file`, the
REPL and the IDE all execute through `NythonExecutor`. GUI builtins now work
under `--vm` too — `gui_sdl_version()`, `gui_get_display_size()` and
`gui_create_window()` all return the same values on both engines.

## Divergence found

A differential run of 37 common builtins produced four mismatches:

| | interpreter | VM |
|---|---|---|
| `str(["a","b"])` | `['a', 'b']` | `["a", "b"]` |
| `type("a")` | `string` | `str` |
| `pow(2, 10)` | `1024.0` | `1024` |
| `str(keys(m))` | `['b', 'a']` | `["b", "a"]` |

The quoting difference is cosmetic until something compares stringified
containers — at which point the same program gives different answers depending
on how it was launched. `type()` and `pow()` are worse: code branching on a type
name, or on whether a result is an int, behaves differently per engine.

The VM was aligned to the interpreter, which is the primary engine and the one
319 examples are written against. After the change all 37 agree exactly.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **320 / 320** | **320 / 320** |
| `tests/` | 30 / 30 | — |
| bound methods / tensor / syntax / unicode / bridge / parity | PASS | PASS |
| IDE UI checks | **74 / 74** | — |

`examples/test_engine_parity.ny` was added with 17 checks covering
stringification, type names, numeric result types, string builtins and
collections, with the interpreter's answers as the expected values. It passes on
both engines, so a future divergence fails the suite instead of going unnoticed.

---

# Round 34 — a generated sweep over 350 builtins

Round 33's differential test covered 37 builtins by hand and found four
divergences. Widening it to **1,357 calls across 350 builtins**, with
deliberately mismatched argument types, found things a hand-written test would
not.

## Three crashes, all on wrong-typed input

The sweep killed the interpreter twice before completing.

**`items("abc")`, `keys("abc")`, `values("abc")`** — a string's `Value` has type
`USERDATA`, and its `value.p` points into the executor's string store, not to a
`Collectable`. The code cast it anyway and `dynamic_cast`-ed the result, reading
a bogus vtable. Guarded with `!isStringValue()`; three call sites.

**`mat_transpose([3,1,2])`** and five siblings — matrix dimensions were read as
`container->find("__rows__")->second` with no check on the iterator. Handing a
plain list to a matrix builtin dereferenced `end()`. Replaced with a
`ny_mat_dim()` accessor that returns a sentinel, and `mat_transpose` now returns
`none` for a non-matrix.

All three returned sensible answers for correct input, which is why 320 passing
examples never touched them.

## Divergences closed

| | interpreter | VM before |
|---|---|---|
| `str(1.0/3.0)` | `0.333333333333333` | `0.333333` |
| `type({"a":1})` | `map` | `dict` |
| `keys("abc")` | `none` | `[]` |

The float one is the significant one: the VM used the default stream precision
of 6 significant digits, so **every float printed differently depending on which
engine ran the program**. Now 15 digits on both.

Mismatches across the 1,353 comparable probes fell from 146 to 92. The
remainder are calls like `abs([3,1,2])` and `ceil("abc")` — nonsense input where
the two engines return different flavours of nothing. They are recorded rather
than "fixed": inventing agreement there would mean inventing semantics.

One known difference is deliberate: `type()` on a matrix reports `matrix` on the
interpreter (it carries a `__type__` marker) and `map` on the VM.

## Verification

| | interpreter | `--vm` |
|---|---|---|
| examples | **321 / 321** | **321 / 321** |
| `tests/` | 30 / 30 | — |
| 7 dedicated suites | PASS | PASS |
| IDE UI checks | **74 / 74** | — |

`examples/test_robustness.ny` was added, pinning the wrong-type behaviour of the
container and matrix builtins and the float formatting. Two of its own
expectations were wrong on first run — `type()` of a matrix, and which element
transposition moves — and both engines agreed against me. The expectations were
corrected, not the code.

---

## Round 35 — VM loop iterators, 171 unreachable builtins, crash guards

Environment: SDL3 is unavailable here and absent from the Ubuntu 24.04 repos, so
this round rebuilt the headless SDL3 / SDL3_ttf / SDL3_image stub (111 symbols,
draw-call counters, event injection). `gui.cpp` compiled against it unchanged,
which confirms the stub still matches the API surface the project uses.

Baseline before any change: **312/312 examples on the interpreter, 312/312 under
`--vm`** (the sweep skips the gui/ide/socket/server files).

### 1. `break` in a `for` loop abandoned its iterator — VM — FIXED

```
for a in range(3):
    for b in range(3):
        if b == 1:
            break
        print(str(a) + "," + str(b))
```

Interpreter: `0,0 / 1,0 / 2,0`. VM: `0,0` then `2,0` forever — a hard infinite
loop producing a gigabyte of output in five seconds.

`GET_ITER` pushes the loop iterator onto the value stack and `FOR_ITER` pops it
on exhaustion. `break` compiled to a bare `JUMP_ABSOLUTE` past `FOR_ITER`, so
the pop never happened. A single top-level loop merely leaked a stack slot;
nested, the inner loop's abandoned iterator sat *above* the outer loop's, and
the outer `FOR_ITER` — which reads `stack_.back()` — advanced the inner iterator
instead of its own. Hence the bogus `a = 2` that never advances.

`LoopCtx` gained an `is_for` flag; `NT::BREAK` now emits `POP_TOP` before the
jump when the innermost loop owns an iterator. `continue` needs nothing (it
jumps to `start`, after `GET_ITER`, where the iterator is correctly still live),
and `break` out of a `while` nested in a `for` correctly pops nothing.

### 2. 171 general-purpose builtins were unreachable — VM — FIXED

The largest finding of the round. `map`, `filter`, `reduce`, `any`, `all`,
`next`, `set`, `tuple`, `getattr`, `hasattr`, `repr`, `exp`, `log`, `sin`,
`read_file`, `write_file`, `mkdir`, `exists` and roughly 150 others were
registered *only* inside `register_nytorch_builtins()`, which runs on
`import nytorch` and nowhere else. Without that import they resolved to `none`.

Silently wrong answers, not errors: `map(dbl, [1,2,3])` returned `none` under
`--vm` regardless of how the callable was written. The implementations were
correct all along — they simply were not installed. `import nytorch` at the top
of the same script made every one of them work.

Fixed with `register_all_builtins()`, called from both constructors, which runs
the nytorch block *first* and then `register_builtins()`. Ordering matters: the
11 names both blocks define keep `register_builtins()`' versions, which is the
behaviour the existing parity tests were written against.

### 3. `list()` did not drain iterators or generators — VM — FIXED

Two `list` registrations existed; the weaker one was registered later and won.
`list(gen(3))` and `list(range(3))` both returned `[]` instead of their
elements. The missing `ITERATOR` and `GENERATOR` branches were added to the
surviving registration rather than reordering the two, so nothing that already
worked changed behaviour.

### 4. `catch` was not a keyword — both engines — FIXED

`throw` was deliberately aliased to `raise` (`Lexer.cpp` carries a comment
saying so), but the matching `catch` → `except` alias was never added. So
`try: / throw "x" / catch e:` — the exact form the first alias invites — was a
syntax error while `throw` + `except` worked.

Added `TokenDef(TokenType::Except, "catch", ...)` beside the existing alias. All
six spellings (`except`/`catch` × bare / `e` / `as e`) now work on both engines.
Verified that no `.ny` file in the tree uses `catch` as an identifier, and that
identifiers merely *containing* it (`catch_all`, `catcher`) still tokenize.

### 5. `sin()` / `cos()` / `tan()` / `tanh()` segfaulted with no argument — VM — FIXED

These four indexed `a[0]` on an empty argument vector. `VMVal` holds a
`std::string`, so the out-of-bounds read faulted rather than returning junk: a
hard segfault of the VM. Their immediate neighbours (`exp`, `log`, `relu`,
`sigmoid`, `atan2`) all guard with `a.empty()?…`, so this was an oversight
rather than a convention.

A second cluster — `log`, `log2`, `log10`, `exp`, `fabs` — is registered *after*
the guarded copies and shadowed them, reintroducing the same unchecked `a[0]`.
Both clusters now guard.

Only exposed by fix #2: before that, these builtins were unreachable without
`import nytorch`.

Worth recording as a process note: the first isolation scan **missed this**. It
probed one-, two- and three-argument forms only, so the zero-argument crash
slipped through until a batch sweep segfaulted mid-run. A per-builtin scan is
only as good as its argument matrix; the matrix now includes a zero-arg column.
An audit of the remaining 40 `to_d(a[0])` sites against the 24 guarded ones
found every other case already protected by an `a.size()<N` early return.

### 6. `repr()` did not quote strings — VM — FIXED

`repr` fell through to `to_string()`, making it identical to `str()`:
`repr("abc")` gave `abc` rather than `"abc"`. Now quotes and escapes.

### 7. `time_now()` truncated to whole seconds — VM — FIXED

The winning registration used `std::time(nullptr)`, so any elapsed-time
measurement that works on the interpreter measured exactly `0` under `--vm`.
Switched to `clock_gettime(CLOCK_REALTIME)` for the interpreter's sub-second
resolution.

### Verification

- **313/313 examples on the interpreter, 313/313 under `--vm`.**
- All 24 runnable files in `tests/` exit 0 on both engines.
- New `examples/vm_audit28.ny` pins all seven fixes; its output is byte-identical
  across the two engines.
- A generated 268-probe differential sweep over the newly reachable builtins
  (4 argument shapes × 67 builtins) now completes without crashing on either
  engine, where it previously segfaulted the VM 36 probes in.

### Known divergences — recorded, deliberately not changed

Of the 82 differences the 268-probe sweep reports, the large majority are
degenerate calls with wrong-typed arguments, where the interpreter returns
`none` and the VM returns a typed empty value (`[]`, `false`, `""`). That is a
house-style difference in how the two engines absorb nonsense input, not a
correctness bug, and aligning it would churn a lot of code for no user-visible
gain. The substantive ones:

- `set([1,2,2])` → `{1, 2}` interpreter, `[1, 2]` VM. The VM has no set type.
- `list(5)` → `5` interpreter, `[]` VM; `list("ab")` → `ab` vs `['a','b']`;
  `list({"a":1})` → the map vs `[]`. The interpreter's `list()` is essentially
  identity for non-list types. Aligning the VM to it would break VM code relying
  on `list(string)`, so both were left alone.
- `repr("say \"hi\"")` → the VM escapes the inner quotes, the interpreter does
  not. The VM is the more correct of the two here; left as-is rather than making
  the correct engine match the incorrect one.
- Dictionary iteration order follows hash order, not insertion order, on both
  engines (`{k: k*2 for k in range(3)}` prints `{2: 4, 1: 2, 0: 0}`).

### Still outstanding

**Container allocation is still not reclaimed.** 300k iterations of `[1,2,3]`
plus `{"a":1}` peaks at **735 MB**, unchanged from round 22. Function calls and
arithmetic stay flat at 7 MB, so the round 19/21 context reclamation continues
to hold. A tracing collector was not attempted this round: the mark phase cannot
see `Value` temporaries living in C++ locals, so collecting at an arbitrary
allocation point risks freeing a container that an enclosing half-evaluated
expression still holds — exactly the use-after-free hazard flagged in round 8.
Doing it safely needs either a shadow stack of temporaries or refcounting hooks
on `Value`'s copy constructor, and it should be its own round with the now
313-example suite as the safety net.

---

## Round 36 — integer overflow, modulo sign, static methods, step slicing

### Method change: comparing output, not exit codes

Every prior round measured the suite by **exit code**. That only catches crashes
and thrown errors; a program that prints a wrong number exits 0 and passes. This
round switched to comparing the two engines' **stdout** on every example, which
is what surfaced most of the bugs below.

To tell a real regression from a pre-existing gap, the original unmodified tree
was built as a baseline (`/tmp/obuild`) and the divergence *sets* compared, not
just the counts.

**Baseline: 132 of 311 comparable examples produce different output on the two
engines.** That backlog predates this round. It is now **129**, with **zero new
divergences** — the set comparison confirms nothing regressed.

### 1. Silent 32-bit integer overflow — interpreter — FIXED

The most serious bug found so far.

```
100000 * 100000   -> 1410065408      (correct: 10000000000)
2147483647 + 1    -> -2147483648     (correct: 2147483648)
1 doubled 40x     -> 0               (correct: 1099511627776)
```

No error, no warning — just wrong numbers. Integers are stored as `bigint` and
the arithmetic is performed at full width; the result was then thrown away by a
cast to `(int)`. The VM was correct throughout, which is why exit-code testing
never noticed: both engines exited 0.

Note for whoever touches this next: `src/Value.cpp` contains a complete set of
arithmetic operators with the identical defect, and they are **dead code**. The
live path is in `NythonExecutor.hpp`. The first attempt at this fix patched only
the dead copy and changed nothing observable. Both are now fixed, since leaving
a broken shadow copy in place is a trap.

### 2. `%` contradicted `//` — interpreter — FIXED

`-7 // 3` floored to `-3` while `-7 % 3` truncated to `-1`, so the identity
`a == (a // b) * b + a % b` failed for mixed signs. Now floor-modulo (`2`),
consistent with this file's own floor division and with the VM.

### 3. `**` demoted exact integers to double — interpreter — FIXED

Capped at 2^31: `2 ** 62` printed `4.61168601842739e+18` instead of the exact
`4611686018427387904`. The guard already tested `pow_result == (int64_t)pow_result`,
so the int64 range is exactly where no precision is claimed that `double` lacks;
the additional 2^31 clamp was simply too tight.

### 4. Static-style class methods received the class as an argument — interpreter — FIXED

```
class S:
    func g(a, b):
        return str(a) + "/" + str(b)
S.g(1, 2)   ->  "user-data/1"     (correct: "1/2")
S.f(4)      ->  none              (correct: 4)
```

Calling a method on the *class* rather than an instance prepended the class
object as an implicit `self`, shifting every real argument one place right; the
stray `user-data` is how a `USERDATA` value stringifies. Two independent causes:

- A method whose first parameter is not `self` was assumed to be a decorated
  wrapper, which legitimately wants `obj` prepended — but that assumption must
  not apply when the receiver is a class.
- A fallback dispatch path skipped `args[0]` whenever the receiver was a class,
  even for methods that declare no `self`, so the sole argument was never bound.

The VM was correct in both cases.

### 5. Step slicing was unimplemented — VM — FIXED

`L[::-1]` and `L[::2]` returned `[]`; `L[1:5:2]` ignored the step and returned
`[1,2,3,4]`; strings behaved the same way.

Two false starts worth recording. First, the obvious-looking `NT::SLICE` case in
the compiler is **dead for subscripts** — the parser encodes `a[x:y:z]` as a
`.slice(x,y,z)` *method call*, so the live handlers are the string and list
`m=="slice"` branches, which discarded their third argument. Second, after
fixing those, negative steps still failed: the parser substitutes a literal `0`
for an omitted start, making `[::-1]` indistinguishable from `[0::-1]`.

The interpreter resolves that ambiguity with a heuristic — a start of `0`
together with an omitted end means "from the far end". Rather than change the
parser and risk the interpreter's behaviour, the VM now mirrors the heuristic,
so both engines agree. The consequence, identical on both: `L[0::-1]` yields the
whole reversed sequence rather than just element `0`. That is a wart, but a
*shared* one, and it is written down here rather than silently diverged on.

### 6. Round 35 side effect: eight builtins shadowed the interpreter bridge — FIXED

Caught by the baseline comparison as the round's one regression, in
`test_vm_builtin_bridge.ny`.

Round 35 registered the builtin block eagerly (correctly — 171 builtins were
otherwise unreachable). But that block ends with a loop registering eight names
—`os_setenv`, `os_exec`, `fs_stat`, `fs_mkdirs`, `os_path_abs`, `ls`, `cat`,
`pwd` — as placeholder stubs returning `none`. Previously those stubs only
existed after `import nytorch`; otherwise the names were absent from `globals_`
and lookup **fell through to the interpreter builtin bridge**, which implements
them properly. Registering the block eagerly made the stubs shadow the bridge,
so `fs_stat("/tmp")["is_dir"]` started returning `none`.

The stubs were removed so the fall-through is restored. Separately, `json_encode`
now emits `[1, 2, 3]` rather than `[1,2,3]`, matching the interpreter, for the
same reason: it used to reach the bridge and now resolves natively, so the two
encoders have to agree.

### Verification

- **313/313 examples on the interpreter, 313/313 under `--vm`** (exit code).
- **Zero new output divergences** against the baseline build; three examples
  (`phase4_5.ny`, `test_aiagent.ny`, `v4_lambda_functional_test.ny`) now agree
  where they previously did not.
- All runnable files in `tests/` pass on both engines.
- New `examples/vm_audit29.ny` pins all six fixes and asserts the *values*, not
  just termination; identical across engines.

### Verified clean this round

Dict and list methods (`keys`/`values`/`items`/`get`/`pop`/`insert`/`extend`/
`sort`/`reverse`, plus `min`/`max`/`sum`/`abs`/`round`/`pow`/`divmod`), class
protocols (`__len__`, `__getitem__`, `__call__`, `__repr__`), three-level
inheritance with correct override dispatch, `isinstance` up the chain, bitwise
operators, chained comparisons and truthiness — all byte-identical.

`"aXbXc".rsplit("X", 1)` returns `none` on **both** engines: the method is
missing rather than divergent, so it is a gap, not a bug, and is left for a
round that adds string methods deliberately.

### Still outstanding

- **129 pre-existing output divergences** between the engines. Now measured and
  enumerable, which makes them addressable in a way they were not before. Spot
  checks show two large families: integer `/` returning `5.0` on the interpreter
  versus `5` on the VM, and the VM not recognising `def init(self, ...)` as a
  constructor (`class_point.ny` prints `0` and `(none, none)`). Neither was
  touched this round; changing division semantics needs a decision about which
  engine is right, and that is a language-design call, not a bug fix.
- **Container allocation is still not reclaimed** — 735 MB for 300k iterations,
  unchanged since round 22, and still deserving its own round for the reasons
  given at the end of round 35.

---

## Round 37 — the `init` constructor, stub loops, and cutting the divergence backlog

Round 36 ended with 129 measured output divergences between the two engines and
no idea of their shape. This round categorised them instead of guessing, which
turned out to matter: three fixes closed **52** of them.

### 1. The VM did not recognise `init` as a constructor — FIXED

The single highest-impact bug of the project so far, by example count.

```
class A:
    def init(self, x):
        self.x = x
A(7).x    ->  none    on the VM   (correct: 7)
```

The interpreter accepts `init` *or* `__init__` — it tests both at three separate
call sites in `NythonExecutor.hpp`. The VM matched only `__init__`, at three
correspondingly separate sites. A class written with `def init(self, ...)`
therefore constructed successfully and then had **no fields set**: every
attribute read back as `none`, with no error raised anywhere.

That spelling is used by roughly 190 of the bundled examples, and 94 of the 129
divergent ones. The three VM sites now share an `is_ctor_name()` helper.

### 2. `list.sort()` returned none — VM — FIXED

The interpreter returns the sorted list, which is what makes the chained form in
the examples work:

```
[10,5,8,3,12,1,7].filter(f).map(g).sort()   ->  none on the VM
```

### 3. Two more none-returning stub loops shadowed the bridge — VM — FIXED

Exactly the bug class fixed in round 36, in two more places: 23 further names
(`open`, `readlines`, `file_size`, `file_read`, `path_exists`, `list_dir`,
`http_get`, `flush`, …) were registered as placeholders returning `none`, which
shadowed the interpreter builtin bridge once round 35 made the block register
eagerly.

Before removing them, **all 23 were called through the interpreter to confirm
the bridge really implements each one** — otherwise dropping a stub would turn a
silent `none` into a `NameError`, trading a quiet bug for a loud one. All 23
came back working, so all 23 stubs were removed.

Round 36 fixed one such loop; there were three. Worth remembering that fixing
the first instance of a pattern is not the same as fixing the pattern — a grep
for `for(auto& nm:{` found the other two in seconds and should have been the
round-36 follow-up.

### Verification

- **314/314 examples on the interpreter, 314/314 under `--vm`** (exit code).
- Output divergence between engines: **132 baseline → 129 (r36) → 80 now**, with
  **zero regressions** at any step, confirmed by comparing divergence *sets*
  against a build of the original tree.
- All runnable files in `tests/` pass on both engines.
- `vm_audit28` and `vm_audit29` still identical; new `vm_audit30.ny` pins this
  round's three fixes and asserts values.

### Still outstanding

- **80 output divergences remain.** The largest identified family is integer `/`
  returning `5.0` on the interpreter versus `5` on the VM. This is deliberately
  untouched: it is a language-design decision about whether `/` is true division
  (Python 3) or preserves integer type, and the bundled `arith_test.ny` asserts
  the VM's answer while the interpreter contradicts it. Picking a side changes
  the language, so it needs an owner's decision, not a bug fix.
- **Container allocation is still not reclaimed** — 735 MB for 300k iterations,
  unchanged since round 22.

---

## Round 38 — function display, missing methods, and a map of what's left

Round 37 left 80 divergences. This round grouped all 80 by their first differing
line before touching anything, which showed the remaining backlog is not one
problem but roughly a dozen small ones plus one design decision.

### 1. Function values printed as `none` — interpreter — FIXED

```
def make():
    def inner():
        return 42
    return inner
print make()        ->  none          (VM: <function inner>)
str(make())         ->  "user-data"
```

Two different meaningless answers for the same value, from two different code
paths (`printValue` had no case for a function and fell through to `none`;
`getStringValue` fell through to `Value::toString()`, which renders any
`USERDATA` as the literal `user-data`).

The important part is what this was *not*: the functions were entirely live.
`make()()` returns 42, `f != none` is true, `type(f)` is `"function"`. Only the
display was broken — which is worse than it sounds, because printing a
container full of handlers (`{k: none}`) looks exactly like a container full of
nulls, and that is precisely what `ee_dbg5.ny` was written to debug.

Both paths now render `<function name>`, matching the VM. The interpreter stores
internal identifiers (`__func__:inner`, `__lambda__`, `__class__:Point`), so a
shared `funcDisplayName()` strips the prefixes rather than leaking them —
`<function __func__:inner>` would have been a new divergence, not a fix, and the
first build of this change produced exactly that before it was caught.

`vm_audit31.ny` pins the *semantics* (`!= none`, `type()`) alongside the display,
so a future display change cannot quietly alter them.

### 2. `list.indexOf()`, `map.size()`, `map.length()` returned none — VM — FIXED

Missing method handlers, silently yielding `none` rather than erroring.

### Verification

- **315/315 examples on both engines**; all runnable `tests/` pass.
- Divergence: **132 baseline → 129 (r36) → 80 (r37) → 73 now**, still with
  **zero regressions** against the original-tree baseline.
- `vm_audit28`–`31` all identical across engines.

### The remaining 73, enumerated

Now grouped rather than guessed at. Largest families first:

1. **Integer `/` (~6 files)** — `25.0` / `5.0` / `30.0` on the interpreter,
   `25` / `5` / `30` on the VM. Still the one genuine language-design decision
   in the list, and still untouched: the bundled `arith_test.ny` asserts the
   VM's answer while the interpreter contradicts it, so there is no "correct"
   side to pick without an owner's ruling.
2. **Exception message text (3 files)** — `Error: division by zero` versus
   `Error: ZeroDivisionError: division by zero`. Cosmetic, mechanical to align,
   but it changes what user `except` blocks print, so it wants a deliberate
   choice of wording rather than making one engine imitate the other.
3. **`undefined` versus `none` (3 files)** — the interpreter has a distinct
   `UNDEFINED` value type that the VM lacks entirely.
4. **Dict and set iteration order (3+ files)** — both engines use hash order,
   but *different* hash orders: `['b','c','a']` versus `['c','b','a']`.
   Genuinely unspecified today; fixing it means choosing insertion-order
   semantics and implementing them in both engines.
5. **Tuples (2 files)** — `[('Alice', 95)]` on the interpreter versus
   `[['Alice', 95]]` on the VM. The VM has no tuple type; `zip()` and friends
   return lists. A real feature gap, not a bug.
6. **String quoting inside maps (2 files)** — `{name: Nython}` versus
   `{name: 'Nython'}`. The interpreter quotes strings inside lists but not
   inside maps; the VM quotes both. The interpreter is internally inconsistent
   here, so this one has a defensible answer.
7. **Out-of-range list index (1 file)** — the interpreter throws (so `except`
   catches); the VM returns `none`. Aligning this changes control flow across
   every program that indexes a list, so it was deliberately left for a round
   where it can be the only change under test.
8. Remainder: assorted single-file numeric-formatting and library differences.

### Still outstanding

**Container allocation is still not reclaimed** — 735 MB for 300k iterations,
unchanged since round 22.

---

## Round 39 — testing the surface every previous round skipped

Rounds 35–38 all filtered `gui`, `sdl`, `ide`, `server`, `socket` and `network`
out of the example sweeps. That excluded roughly 25 files plus two large suites
(`test_gui.ny`, 1053 assertions; `test_ide_smoke.ny`, 40) which had therefore
**never been run in any round**. Two of the three suites were failing.

That is the lesson worth recording above the bug list: those sweeps reported
green partly because they were not looking. A green round is evidence about what
was tested, and nothing at all about what was excluded.

### 1. The VM dropped default parameters on every class method — FIXED

```
class W:
    def __init__(self, x_or_w, y=0, w=0, h=0):
        if w == 0:
            self.x = 0; self.w = x_or_w      # intended for W(280)
        else:
            self.x = x_or_w; self.w = w      # intended for W(x,y,w,h)

W(280).w  ->  none      on the VM   (and .x wrongly became 280)
```

Defaults are populated at `MAKE_FUNCTION` runtime. Class methods never reach
`MAKE_FUNCTION` — they are invoked straight out of `sub_codes` — so `w` arrived
as `none`, `none == 0` evaluated false, and the constructor **took the wrong
branch**. The object was then built by the wrong code path with no error raised
anywhere: `W(280)` produced `x=280, w=none` instead of `x=0, w=280`.

`lib/gui.ny` uses this dual-signature constructor pattern throughout, which is
why the failure surfaced as `FAIL [w] got=<Widget instance> expected=280` in the
GUI suite and nowhere else.

Fixed by folding literal defaults (`0`, `""`, `1.5`, `true`, `none`) into
`param_defaults` at compile time in `visit_func`, so methods get them regardless
of the `MAKE_FUNCTION` path. Non-literal defaults still use the runtime path for
plain functions.

### 2. The interpreter evaluated chained receivers twice, compounding — FIXED

```
v.add(1).add(1).add(1)     ->  v.n == 7    (correct: 3)
```

Measured across chain lengths the pattern is exactly `2^n - 1`: 1, 3, 7, 15. The
callee-lookup fallback near the end of `evalCall` re-evaluated the entire callee
expression (`evalNode(cn->callee, ctx)`) in order to resolve the method — and
`cn->callee` is the attribute node whose object is the inner call, so the whole
receiver chain ran a second time at every level of nesting.

Any chain whose links have side effects therefore multiplied them silently. This
is what `test_webserver.ny` had been failing on: `val.required("username")
.required("email").required("password")` registered 11 rules instead of 6.

Fixed with a `receiver_cache_` keyed on the object node: `evalCall` has already
evaluated the receiver, so it publishes it before the fallback and
`evalAttribute` reuses it instead of re-running the expression.

### Verification

- `test_gui.ny` — **1053 passed, 0 failed**, identical on both engines
  (VM was 1052/1).
- `test_ide_smoke.ny` — **40 passed, 0 failed**, identical (VM was 39/1).
- `test_webserver.ny` — **71 passed, 0 failed**, identical (the *interpreter*
  was failing 2).
- All 13 `gui_tests/` pass on both engines.
- **327 examples run on both engines**, up from 315 — the GUI and network files
  are no longer excluded from the sweep.
- Divergence **73 → 72**, still **zero regressions** against the original-tree
  baseline.
- `vm_audit28`–`31` unchanged; new `vm_audit32.ny` pins this round's two fixes,
  including defaults on ordinary methods as well as constructors.

### Known harness limitation (not a product defect)

`examples/nython_ide.ny` and `gui_tests/test_12_ide_launch.ny` time out on both
engines. The headless SDL3 stub returns no events from `SDL_PollEvent`, so the
IDE's event loop never receives a quit and spins forever. The IDE's *widget*
layer is covered by `test_ide_smoke.ny`, but the main loop itself is untested.

Making the stub emit `SDL_EVENT_QUIT` after N polls (the stub already has
`ny_stub_push_quit`) would close this, and is the single largest remaining blind
spot in the test setup.

### Still outstanding

- **72 output divergences**, grouped by family in the round 38 notes. Roughly
  five of those families are language-design decisions rather than defects:
  integer `/`, dict/set iteration order, tuples, `undefined` vs `none`, and
  out-of-range indexing. They are deliberately not decided here.
- **Container allocation is still not reclaimed** — 735 MB for 300k iterations,
  unchanged since round 22.

---

## Round 40 — closing the IDE blind spot

Round 39 flagged that `nython_ide.ny` and `test_12_ide_launch.ny` time out
headlessly, leaving the IDE's main event loop the largest untested area. This
round closed that.

### Harness: `NY_STUB_AUTOQUIT`

The stub now synthesises a single `SDL_EVENT_QUIT` after *n* empty polls
(`NY_STUB_AUTOQUIT=<n>`), letting a GUI application shut down through its normal
path instead of spinning forever. Documented in `tests/ide/README_HEADLESS.md`.

**The latch matters, and getting it wrong was instructive.** The first version
re-armed after firing, so every poll returned a quit event. An application's
`while (SDL_PollEvent(&e))` drain loop then never terminates: with
`NY_STUB_AUTOQUIT=1` the IDE grew to **3.8 GB and was OOM-killed** (exit 137).

That looked exactly like an IDE memory leak. It was a defect in the test
instrument. Worth stating plainly because the failure mode is generic: a test
harness that supplies an unbounded resource will manufacture "bugs" in
well-behaved code, and the reflex to blame the code under test is wrong. Real
SDL delivers a quit once; the stub now does too, and the IDE peaks at 63 MB at
every quit point.

### Result

With the loop actually running, on **both engines**:

- All 13 `gui_tests/` pass, including `test_12_ide_launch.ny`.
- `nython_ide.ny` — the full IDE, importing `lib/gui.ny`, `ide_editor.ny` and
  `ide_workshop.ny` — starts, runs its event loop and exits cleanly at quit
  points 1, 2, 5, 150 and 200. Identical output on both engines.
- `test_gui.ny` (1053 assertions) and `test_ide_smoke.ny` (40) pass identically.

**341 example files now run on both engines with no exclusions at all**, up from
327 in round 39 and 313 in round 36 — the growth is entirely files that earlier
rounds were skipping. All `tests/` pass on both engines. Divergence holds at 72
with zero regressions.

### Still outstanding

- **72 output divergences**, roughly five families of which are language-design
  decisions rather than defects (integer `/`, dict/set iteration order, tuples,
  `undefined` vs `none`, out-of-range indexing).
- **Container allocation is still not reclaimed** — 735 MB for 300k iterations,
  unchanged since round 22. This is now the last outstanding item that is
  unambiguously a defect rather than a decision.

---

## Round 41 — GUI polish (icons, Dark+ theme, responsive layout) and a silent loop bug

### GUI work

**Real VS Code icons.** Microsoft's Codicons — the set VS Code itself uses —
installed as `assets/fonts/codicon.ttf` with a generated `lib/icons.ny` exposing
all **460** icons by name. Licensing is bundled: icons CC BY 4.0, code MIT.

The IDE's activity bar now uses them instead of emoji. That is not only
cosmetic: emoji are drawn by whatever emoji font the OS ships, so the toolbar
was multi-coloured, differently shaped on every platform and impossible to
theme. Codicons are monochrome glyphs that inherit the current text colour,
which is what makes VS Code's chrome themeable at all.

This required a fix in `gui_load_font`, which only ever matched a family name
against a hardcoded list of system font paths — a bundled font could not be
loaded at all. It now tries the family as a literal path first.

**VS Code Dark+ palette.** The theme was an iOS system palette, which is why the
IDE did not read as an editor. Replaced with the published Dark+ values:
`#1E1E1E` editor, `#252526` sidebar/panel, `#333333` activity bar, `#007ACC`
accent and status bar, `#D4D4D4` foreground, plus selection, borders, scrollbar
and tab states, and the ten Dark+ syntax token colours. Corner radius 8 → 4,
since VS Code chrome is near-square.

**Responsive layout.** `_build_layout` hardcoded `W = 1600, H = 960` and nothing
repositioned on resize — every widget kept its construction coordinates, so the
UI stayed pinned to the original geometry regardless of window size. It now
reads the real window size, and `_relayout()` recomputes geometry and pushes it
into the *existing* widgets (rebuilding would discard buffers, tabs and terminal
history). Overlays centre rather than sitting at fixed offsets, and everything
clamps at 640x400 so a narrow window cannot produce negative widths. Verified
from 1920x1080 down to 320x200 with no collapsed or negative panes.

### The bug that test found

Writing `test_13_icons_theme.ny` produced this:

```
interpreter:  Results: 46 passed, 0 failed
VM:           Results: 27 passed, 0 failed
```

Both reported **zero failures**. The VM was silently skipping 19 assertions. A
suite that under-counts while reporting green is worse than one that fails: it
is a green light with no evidence behind it, and every previous round's VM pass
counts were potentially affected.

Minimised:

```
for n in ["files","search","source-control","debug-alt",
          "sparkle","folder","file","play"]:
    check("i " + n, ic.has(n), true)      # interpreter: 8 iterations, VM: 1
```

The trigger is a multi-line list literal in the loop header **and** a call in the
body. Either alone is fine.

`nython -d` made the cause immediate: the multi-line form was **missing the
`POP_TOP` after `CALL_FUNCTION`**. The parser yields a bare expression node
rather than a BLOCK when a statement body is a single expression, and only BLOCK
bodies reach `visit_stmt`, which is what emits that `POP_TOP`. So the call's
return value stayed on the stack every iteration — and `FOR_ITER` reads
`stack_.back()`, so it read the leftover instead of the iterator and the loop
ran exactly once. Exactly the same failure mode as the round 35 `break` bug:
anything stray on the value stack corrupts the enclosing loop's iterator.

Fixed by routing loop and loop-else bodies through `visit_stmt`.

### The over-broad first fix, and why the constraint is interesting

The first version of that fix also routed **if-branches** through `visit_stmt`.
Two nytorch suites regressed, and the reason is worth recording: **Nython has no
separate ternary node** — `a if c else b` is an `IfNode`, the same type as a
statement `if`. Emitting `POP_TOP` in an if-branch therefore discards the
*ternary's value*. The visible symptom was a dict literal containing a ternary
coming back with its keys and values swapped:

```
{5: 'avg_confidence', none: 'n_steps'}     instead of
{n_steps: 5, scratchpad_entries: 5, avg_confidence: 0.0357}
```

The if-branch changes were reverted and the constraint documented at
`visit_if`. Consequence, now known and written down: a bare call as an
if-branch still leaves its result on the VM stack. Fixing that properly needs
the parser to distinguish statement-ifs from ternaries first, which is a
separate piece of work rather than something to bolt on here.

This was caught only because regressions are checked by comparing divergence
*sets* against a build of the original tree. A pass/fail count would have shown
72 → 74 and buried which two files changed.

### Verification

- 342 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_webserver` 71/71,
  `test_nytorch15` 184/184, `test_nytorch16` 153/153 — all identical across
  engines.
- New `test_13_icons_theme.ny` (46 assertions, now equal on both engines) and
  `vm_audit33.ny` pinning the loop fix *and* the ternary constraint it must not
  break.
- Divergence back to **72** with **zero regressions** against baseline.

---

## Round 42 — making the IDE real

The IDE looked complete and was, in its core, a mockup. This round replaced the
simulation with the actual toolchain.

### What was actually there

`_run_file` did not run anything. It scanned the buffer for lines beginning
`print ` and echoed the text after them, then reported:

```
✓ Execution complete — 0 errors
```

unconditionally, with `run_elapsed_ms = 42` hardcoded. It could not fail, could
not produce output a real run would produce, and reported success for a file
with a syntax error in it. `print(6 * 7)` displayed `(6 * 7)`, not `42`.

The rest of the pipeline matched:

- `_tokenize_file` re-implemented the lexer in Nython over buffer lines, so its
  tokens could disagree with the real lexer's.
- `_ast_file` built XML by matching line prefixes — an invented tree.
- `_disasm_file` emitted one `EXEC` per non-blank line.
- `_profile_file` fabricated timings.
- `_repl_execute` pattern-matched: `2 + 2` printed `<expression>`.

None of them ever invoked the compiler.

### `lib/ide_toolchain.ny`

A bridge that shells out to the real binary via `os_exec` (which captures
stdout; stderr is merged with `2>&1`, and the exit status is smuggled out on a
trailing `__NY_EXIT__` line since `os_exec` returns output only).

- `run(source, name, use_vm)` — real execution on either engine, real exit code,
  measured elapsed time.
- `tokenize` / `ast` / `disasm` — real `-t` / `-a` / `-d` output. The existing
  `TokenViewer` and `ASTViewer` widgets already had `parse_xml`, and the real
  tools already emit XML, so they are fed directly.
- `diagnose(source, name)` — a compile-only pass whose messages become
  structured `Diagnostic` records for the PROBLEMS panel.
- `tokens()` — parses the token XML into the viewer's tuple shape.

The IDE now wires Run, Tokenize, AST, Disassemble, PROBLEMS and the REPL to it.
Run reports the real exit code and duration, colours error lines, and refreshes
diagnostics afterwards; a failing file now genuinely reports failure.

**The REPL evaluates.** It replays the session's accepted declarations and
prints the new expression, so values are the language's own:

```
>>> 2 + 2            -> 4
>>> var n = 10       -> defined
>>> n * n            -> 100
>>> def sq(x): ...   -> defined
>>> sq(9)            -> 81
>>> nope(            -> error
```

A declaration only joins the session after it compiles cleanly, so one broken
line cannot poison every later evaluation.

### Verification

`examples/gui_tests/test_14_toolchain.ny` — 28 assertions, passing on both
engines. The central one is deliberate: the expected value must be *computed*,
not echoed. `6 * 7` is asserted to produce `42`, a string that appears nowhere
in the program source — the old mockup could not have passed it.

Also asserted: failure really fails (nonzero exit for a syntax error), a runtime
error surfaces `ZeroDivisionError`, a clean file yields zero diagnostics, tokens
carry real types and line numbers, the AST is the parser's own XML, and the
disassembly contains a real constants pool and `LOAD_CONST` instructions.

- 344 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_13` 46/46, `test_14` 28/28.
- Divergence holds at **72**, zero regressions.

### Honest status of the remaining IDE features

- **Debugger** — still simulated. Real breakpoints, stepping and variable
  inspection need runtime support in the VM (a debug hook, a pause/step protocol
  and frame introspection) that does not exist yet. Shelling out cannot provide
  it. This is the largest genuine gap and wants its own round, starting in the
  VM rather than the IDE.
- **Profiler** — still invents timings. A real one needs per-function counters in
  the interpreter, same story.
- **AI chat** — routes keywords to IDE actions, which are now real actions
  rather than mockups, so the routing became genuinely useful. It is not a
  language model; `lib/aiagent.ny`'s analysis classes are not yet wired in.

---

## Round 43 — pointer feedback, draggable panes, universal value inspector

### 1. The cursor never changed — FIXED

`gui_set_cursor()` has existed all along with twelve named system cursors. It
was never called. The pointer stayed an arrow over everything: over editor text,
over buttons, over pane edges that can be dragged.

That is one of the strongest tells that a UI is not a real application. A text
area that does not show an I-beam reads as a *picture* of a text area.

`CursorManager` (in `lib/gui.ny`) registers hover regions per frame with
priorities, and pushes a shape to SDL only when it actually changes — a
mouse-motion storm does not become a syscall storm. It also supports `lock()`,
which matters for drags: a pane resize must keep its resize cursor even when the
pointer runs off the splitter mid-drag.

Wired through the IDE: I-beam over the editor and output panels, hand over the
toolbar, activity bar, sidebar, tab bar, panel tabs, minimap and status bar, and
resize cursors over both splitters.

### 2. Panes are now draggable — NEW

The sidebar/editor and editor/panel splitters can be dragged, with the
`sizewe` / `sizens` cursors that advertise it. Constrained (sidebar 140px to
window-320, editor/panel ratio 0.20–0.85) so no pane can be dragged out of
existence. `editor_ratio` is honoured by `_relayout`, so a dragged split
survives a window resize.

### 3. Universal value inspector — NEW

`lib/ide_inspector.ny` renders any Nython value for the debug / watch / REPL
panels: a type name, a Codicon glyph per type, a safely truncated one-line
summary, and an expandable tree for lists, maps and instances.

### A real language inconsistency, found by writing it

`len()` on a string counts **characters** — `len("日本語")` is 3 — but `s[i]`
and `s[a:b]` index **bytes**. So the obvious way to walk a string corrupts any
non-ASCII text:

```
var s = "aébç"        # len(s) == 4
var out = ""
var i = 0
while i < len(s):
    out = out + s[i]  # s[1] is one BYTE of é
    i = i + 1
# out == "aéb"  — the ç is gone, silently
```

Both engines agree, so this is a language semantics question, not an engine bug,
and it is deliberately **not** changed here: making indexing character-based to
match `len()` is the coherent answer and matches the precedent `len()` already
sets, but it would change the meaning of every string slice in the codebase
(`lib/gui.ny` alone slices strings heavily). That is an owner's decision, like
integer `/`, and it wants its own round with the 345-example suite behind it.

Worth recording how this was found: the inspector's first version hand-rolled
UTF-8 continuation-byte arithmetic *assuming* byte strings, and mangled `café`
into `caf\x-61\x-87` — the exact corruption the module existed to prevent. Two
wrong assumptions cancelled into visible damage: that strings were byte-indexed
(half true) and that `ord()` returned an unsigned byte (it is signed, so
`0x80..0xFF` arrive as negative and every UTF-8 byte tested as a control
character).

The module now assumes nothing: it never reassembles a string from indexed
pieces, truncates with a character count as a byte budget (safe, since character
count <= byte count, so the cut can only land on an ASCII boundary), and
rebuilds only when an ASCII control character is actually present. Unicode,
accents, CJK and Codicon glyphs round-trip byte-identical.

### Verification

- `examples/gui_tests/test_15_cursor_inspector.ny` — 46 assertions, identical on
  both engines. Covers cursor priority, last-wins-at-equal-priority, lock/unlock
  across a simulated drag, suppression of redundant cursor writes, every value
  type's name/icon/summary, expansion depth and keys, and Unicode round-trip
  including a Codicon glyph as a *value*.
- 345 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_13` 46/46, `test_14` 28/28.
- Divergence holds at **72**, zero regressions.

### Still simulated (unchanged, and still the largest gap)

The debugger and profiler. Real breakpoints, stepping, frame and variable
inspection need a debug hook, a pause/step protocol and frame introspection in
the VM — the inspector built this round is the *display* half of that feature,
and is ready to render frames the moment the runtime can produce them.

---

## Round 44 — the profiler now measures

Round 42 made Run, Tokenize, AST and Disassemble real but left the profiler
fabricating numbers: `_profile_file` scanned the buffer for `def ` lines and
invented a duration for each. It could not identify a hot spot, because it never
observed one.

Unlike the other four, this could not be fixed by shelling out — the toolchain
had nothing to shell out *to*. So the measurement was added to the runtime.

### Runtime: real per-function accounting

Every call in the interpreter funnels through `evalCall`, which makes it the one
place instrumentation is both complete and cheap. A scoped `ProfScope` records:

- **calls** — exact invocation count
- **total_ns** — wall time including callees
- **self_ns** — wall time excluding callees, which is what actually identifies a
  hot spot

Two details matter and are easy to get wrong:

- **Self time** subtracts child time, tracked through a `prof_child_ns_` value
  each frame saves and restores. Without it every caller looks as expensive as
  its callees and the ranking is meaningless.
- **Recursion** is charged only at the outermost activation (`depth == 0`).
  Otherwise a recursive chain counts the same interval once per level and
  `fib(18)` reports absurd totals. Calls are still counted per invocation, so
  `fib(12)` correctly reports 465.

Off by default and gated on a flag checked before any work, so a normal run is
unaffected — measured at 202/170 ms unprofiled versus 202 ms profiled on the
same workload, i.e. within noise.

### `--profile` / `-p`

Runs a script and prints the measured report after the program's own output,
delimited by `__NY_PROFILE__` so a caller can separate the two:

```
$ nython --profile p.ny
599970006
__NY_PROFILE__
name,calls,total_ms,self_ms
slow,3,159.474,159.474
outer,1,159.716,0.122
fast,3,0.120,0.120
```

`outer` shows 159.7 ms total but 0.122 ms self — it spends essentially all its
time in `slow`, which is exactly the distinction a profiler exists to draw.

### IDE

`Toolchain.profile()` parses the report into `[name, calls, total_ms, self_ms]`
rows sorted hottest-first, and `split_program_output()` returns the program's
own output with the report stripped. `_profile_file` feeds the PROFILER panel
from those rows.

### Verification

`examples/gui_tests/test_16_profiler.ny` — 14 assertions, identical on both
engines. The design is deliberate: `hot()` does ~50x the work of `cold()`, and
the test asserts the profiler *ranks them that way*. The old implementation,
which timed nothing, could not have passed it. Also asserted: self time is
strictly less than total for a function that delegates, the recursive call count
is exact, recursive totals are not inflated, program output never leaks the
report, and a program with no calls profiles cleanly instead of erroring.

- 346 examples and all `tests/` pass on both engines.
- Divergence holds at **72**, zero regressions.

### Remaining gap: the interactive debugger

Still simulated, and now the only fabricated feature left. Breakpoints, stepping
and frame inspection need a pause/resume protocol and frame introspection —
`ProfScope` proves the call-site hook is the right seam, but a debugger also
needs to *stop* there and hand control back, which is a control-flow change
rather than an accounting one. `lib/ide_inspector.ny` (round 43) is already the
display half and can render frames as soon as the runtime can produce them.

---

## Round 45 — blueprint audit, and the three foundations that were missing

Audited the stack against the seven-layer blueprint before writing anything.
Most of it exists — 138 widget classes, tooltips, tree views, context menus, a
command palette, ANSI handling in the terminal panel. Three things the blueprint
singles out as load-bearing were absent entirely.

### Audit result

| Layer | Present | Missing |
|---|---|---|
| L1 OS | window mgmt, vsync, usable bounds | **High-DPI (0 references)**, IME `TEXT_EDITING` |
| L2 graphics | rounded rects, gradients, shadows, blur | glyph atlas, kerning, ligatures |
| L3 framework | theming, focus tracking | **layout engine (no Flex/Layout class)**, tab navigation, z-index |
| L4 widgets | tooltip, tree, menu, checkbox, slider, dropdown | Splitter widget, ScrollArea class |
| L5 editor | minimap, syntax highlight | **Piece Table / Rope**, undo/redo, multi-cursor, bracket match |
| L6 IDE | command palette, ANSI, autocomplete | docking, hover tooltips |
| L7 polish | `animate`, `lerp` | **easing functions (0 references)** |

### 1. Motion — `lib/gui_motion.ny`

Widgets stepped animated values linearly. Linear motion is the most recognisable
"homemade UI" tell, because physical objects accelerate and decelerate.

Fourteen standard curves (quad, cubic, quart, quint, expo, back, elastic,
bounce), all normalised so `f(0)=0` and `f(1)=1` and therefore interchangeable,
plus a `Tween` driver that takes a `dt` from the frame loop. Unknown curve names
degrade to linear rather than failing, so a typo in a theme cannot break
rendering. Input outside `[0,1]` is clamped, not extrapolated — overshoot curves
already exceed 1.0 mid-flight by design, and extrapolating would send a panel
off screen.

### 2. Layout — `Flex` in the same module

Every widget was positioned by hand-computed pixel arithmetic. That is *why* the
IDE was pinned to 1600x960 for so long: there was no solver, only constants.

`Flex` is a row/column solver with fixed basis, grow weights, gaps, padding,
minimums and justification. Validation worth noting: fed the IDE's own row
(activity 52 fixed, sidebar 260 fixed, editor grow, minimap 110 fixed) at
1600x960, it produces `editor.w == 1178` — byte-identical to the hand-computed
value in `_relayout`. At 420px wide the minimum engages and no pane goes
negative.

### 3. Buffer — `lib/gui_piecetable.ny`

The editor stored text as a list of line strings, so every keystroke rebuilt a
line and every paste rebuilt a large string.

A piece table never mutates stored text: two append-only buffers (`original`,
`add`) plus an ordered list of `(buffer, start, length)` windows. Editing is list
surgery on pieces, not string surgery on text. Because the buffers are never
rewritten, an old piece list stays valid forever — which makes undo a snapshot of
the piece list and cheap enough to keep 200 of. `replace()` folds its delete and
insert into a single history entry so one edit is one undo. `compact()` merges
adjacent contiguous pieces without changing the document.

### 4. High-DPI — `gui_display_scale()` / `gui_window_scale()`

Nothing in the codebase queried display scale, so every metric was a raw pixel
count: on a Retina or 4K panel the whole interface renders at half size with
blurry text. The blueprint calls this out first for a reason.

Two builtins expose `SDL_GetDisplayContentScale` and `SDL_GetWindowDisplayScale`
(the latter matters when a window is dragged to a second monitor). The IDE
multiplies its chrome metrics through `scaled()`, which rounds half-up; at scale
1.0 every number is bit-identical to before, so nothing changes on a standard
display. The test stub honours `NY_STUB_DPI_SCALE` so HiDPI behaviour is
testable headlessly.

### A language bug this surfaced

`from` and `to` are reserved words and cannot be used as identifiers — fair
enough. What is not fair: **a module with a syntax error imports silently**.
`import "lib/gui_piecetable.ny"` printed "imported ok", and then every class in
it constructed to `none` and every method returned `none`. No error, anywhere.

The failure looked like a broken class rather than a broken file, and cost a
bisect over the module to find. An import that cannot parse its target should
say so. Recorded here rather than fixed, since `vm_import` error handling wants
its own change under test.

### Verification

`examples/gui_tests/test_17_motion_layout_buffer.ny` — **80 assertions**,
identical on both engines: every curve normalised at both endpoints, out-curves
front-load and in-curves back-load, overshoot curves exceed 1.0, clamping,
tween lifecycle and reversal; flex fixed/grow/min/gap/padding/justify including
the 1178px reproduction; piece-table insert/delete/substr/undo/redo/line-mapping,
single-step replace, and that the original buffer is never mutated.

`test_13` extended to 53 assertions covering display scale and the rounding rule.

- 347 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_14` 28, `test_15` 46,
  `test_16` 14, `test_17` 80.
- Divergence holds at **72**, zero regressions.

### Still outstanding from the blueprint

Glyph atlas and text shaping (kerning/ligatures) — the largest remaining
quality gap, and genuinely hard: shaping normally means HarfBuzz. Docking,
multi-cursor, bracket matching, IME `TEXT_EDITING`, and the interactive
debugger. The piece table and flex solver are built and tested but not yet
adopted by `RichEditor` and `_relayout`; swapping them in is a mechanical change
that should be its own round so a regression is attributable.

---

## Round 46 — adopting the foundations, and making failed imports visible

Round 45 built the piece table, flex solver and easing curves but left them
unadopted, and said so. This round wires the buffer in and fixes the import bug
that round found.

### 1. The editor buffer is piece-table backed — DONE

`EditorBuffer` stored text as a list of line strings: every keystroke rebuilt a
line, every paste rebuilt a large string, and there was **no history at all** —
the IDE had no undo.

It is now backed by `PieceTable`, with the line list kept as a lazily rebuilt
cache behind a dirty flag. That matters for adoption cost: `get_line`,
`get_all_text`, the syntax highlighter and the minimap all read `self.lines` and
none of them changed. `insert_char`, `delete_char_back` and `insert_newline`
convert the cursor to an offset and edit the table instead of splicing strings.

Joining two lines with backspace is now literally "delete the newline between
them", which is both simpler and correct at the boundary — the old code special-
cased it by rebuilding two lines and rewriting the list.

New: `undo()`, `redo()`, `can_undo()`, `can_redo()`, with `_clamp_cursor()`
because history can shorten the document out from under the cursor.

### 2. A module with a syntax error imported silently — FIXED

Found in round 45 and worth stating plainly, because it is the worst failure
mode a language can have:

```
import "lib/gui_piecetable.ny"      -> printed nothing, appeared to succeed
var pt = PieceTable("abc")
pt.text()                           -> none
```

Every class in the module constructed to `none` and every method returned
`none`, with no diagnostic anywhere. The cause was `catch (...) {}` around the
module's parse-and-execute in `evalImport`. A syntax error in the imported file
was caught and discarded, so the import "succeeded" having defined nothing.

The damage is that the failure presents as a *broken class* rather than a broken
file, so the search starts in the wrong place entirely — it cost a line-by-line
bisect of a 300-line module to find a missing keyword.

Now: a parse failure reports the file and the reason and raises `ImportError`
rather than continuing. A bare `return` at module scope is still tolerated, and
a Nython exception thrown inside a module propagates instead of vanishing.

This is a behaviour change — code that silently depended on a broken import now
fails loudly — so the full suite was re-run: 347 examples and all `tests/` still
pass on both engines, with zero new divergences.

### Verification

`examples/gui_tests/test_18_editor_buffer.ny` — 28 assertions, identical on both
engines: insert/newline/backspace with cursor tracking, line-count changes,
undo through every edit in order back to the original, redo, offset mapping on
each line of a multi-line document, mid-line editing, and two properties worth
pinning — the loaded file is never mutated whatever the history, and backspace
at offset 0 is refused rather than corrupting the buffer.

- 347 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, plus tests 13–18.
- Divergence holds at **72**, zero regressions.

### Still outstanding

`Flex` is tested but `_relayout` still uses hand-computed arithmetic; the solver
reproduces its numbers exactly (`editor.w == 1178`), so the swap is mechanical
and belongs in its own round. Beyond that, unchanged from round 45: glyph atlas
and text shaping, docking, multi-cursor, bracket matching, IME `TEXT_EDITING`,
and the interactive debugger.

---

## Round 47 — Flex adopted, and the three missing widget classes

### 1. `_relayout` now uses the Flex solver — DONE

Deferred twice with the reasoning that it should be its own change so a
regression would be attributable. It is now done, and the swap is provably
behaviour-preserving.

The IDE's geometry is declared rather than derived: a vertical stack of
toolbar / content / status, and a content row of activity | sidebar |
editor(grows) | minimap. Checked against the old hand arithmetic at five window
sizes:

```
1600x960   flex=[38, 896, 312, 1178, 1490]   old=[38, 896, 312, 1178, 1490]
1280x720   flex=[38, 656, 312,  858, 1170]   old=[38, 656, 312,  858, 1170]
1920x1080  flex=[38,1016, 312, 1498, 1810]   old=[38,1016, 312, 1498, 1810]
800x600    flex=[38, 536, 312,  378,  690]   old=[38, 536, 312,  378,  690]
640x400    flex=[38, 336, 312,  218,  530]   old=[38, 336, 312,  218,  530]
```

Identical everywhere, including where the editor minimum engages. The point is
not that the numbers changed — it is that adding a pane is now an `add()` call
rather than an audit of every offset computed below it.

### 2. `Splitter` — the audit's missing L4 widget

The IDE grew ad-hoc splitter handling inline in `handle_event`. This is the
reusable widget: orientation-aware cursor shape, a grab band wider than the
visible line (`hit_slop`, since a 1px target is unusable), drag with clamping
against `min_before` / `min_after`, and an `on_move` callback.

Clamping is the part worth testing: a drag past either end must pin the divider,
never invert the two panes. Pinned both directions, plus that a move delivered
after release is ignored rather than causing drift.

### 3. `ScrollArea` — centralised scrolling and virtualization

Scrolling was reimplemented per widget with its own clamping. This owns content
extent, viewport, clamping, wheel and page steps, scrollbar thumb geometry
(length proportional to the visible fraction, floored at 24px so it stays
grabbable in a long document), and `visible_range()` — the virtualization the
blueprint calls for, so a 3000px document renders ~18 rows instead of all of
them.

### 4. `FocusManager` — Tab navigation

Focus was tracked ad hoc per widget with no way to move between them, so Tab did
nothing at all. This owns the ring: register, focus by name, `next()` / `prev()`
that both wrap (focus stuck at an end of the ring is the classic bug here), and
`has_focus()`.

### Verification

`examples/gui_tests/test_19_widgets.ny` — 48 assertions, identical on both
engines: splitter hit band, drag clamping in both directions, no post-release
drift, horizontal orientation; scroll clamping at both ends, wheel and page
steps, thumb position and floor, virtualized row range, and the degenerate case
where content is smaller than the viewport; focus wrap in both directions,
failed lookups leaving focus unchanged; and the five-size Flex/hand-geometry
equivalence above.

- 349 examples and all `tests/` pass on both engines.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 13–19 all green.
- Divergence holds at **72**, zero regressions.

### Still outstanding

`Splitter`, `ScrollArea` and `FocusManager` are built and tested but not yet
adopted by the IDE, which still uses its inline drag code and per-widget
scrolling — the same "built, not adopted" state `Flex` was in last round, and it
should be resolved the same way, as its own change.

Unchanged: glyph atlas and text shaping (kerning/ligatures) remains the largest
quality gap and realistically needs HarfBuzz; docking; multi-cursor; bracket
matching; IME `TEXT_EDITING`; and the interactive debugger, which is still the
only fabricated feature left in the IDE.

---

## Round 48 — screenshots, a wrong-file discovery, and a real parser bug

The first visual evidence of the running IDE. It changed the picture materially.

### The IDE being edited was not the IDE being shipped

There are two implementations:

- `nython_ide.ny` (repo root, **v4**, ~3650 lines) — what `--ide` actually
  launches, because `launch_ide()` checks `<binary_dir>/nython_ide.ny` first.
- `examples/nython_ide.ny` (**v3.0**, ~2400 lines) — what rounds 42–47 modified.

So the toolchain bridge, cursor manager, piece-table buffer, Flex relayout and
HiDPI work from those rounds were never in the product. The suites those rounds
added kept passing, which is exactly why this went unnoticed: they tested the
file being edited, not the file being run.

A correction to those rounds' framing: **v4 was never a mockup.** It already
executes code for real through `popen`, and already has workspace and project
handling, menus with accelerators, find/replace, breakpoints, a command palette,
cursor feedback and undo. The "the IDE is simulated" finding in round 42 was
true of v3 only. `IDE_FILES.md` now records which file is which so this cannot
repeat.

### Defects visible in the screenshots, traced and fixed

**Two Run buttons.** A green ▶ is drawn at x=12 and `run_modes` lists `"Run"`
again as the first chip at x=106. The chip is now suppressed, but the entry
stays in the list: mode indices are hardcoded throughout (0=Run, 1=VM,
3=Tokenize, 4=AST, 5=Disasm) and renumbering would silently rewire every menu
command.

**Blank icons in the activity bar.** The rail asks for seven icons; `Icons.draw`
had cases for five. `outline` and `ai` fell through to a fallback that draws an
empty rounded box — literally the blank squares in the screenshot. Both drawn.

**Empty Explorer.** `open_folder(getcwd())` with no fallback: when it failed the
tree stayed empty permanently while the console still reported files loaded. Now
tries getcwd, ".", the parent, then `$HOME`/`%USERPROFILE%`, and normalises
Windows backslashes before stat-ing.

**Error text bleeding out of the sidebar.** Drawn with no clip, so a long
Windows path ran across the panel below. Now clipped and ellipsised.

**"Resized 1366 x 697" in the status bar.** Debug text written to `status_msg`
on every resize event, displacing real messages. The window size is already
shown at the right of the status bar. Removed.

### A genuine parser bug

Found while writing the icon test. Three lines:

```
for j in ["x", "y",
          "z"]:
    var t = 1          # SyntaxError: Unexpected token: 4
```

The same loop with the list on one line parses fine.

The lexer tracks indentation inside brackets. The continuation line's 10 spaces
push an `Indent`; the body's 4 spaces then emit a `Dedent`; the post-pass that
suppresses in-bracket indentation cancels them against each other, and the body
**never receives an `Indent` token at all**. A `-t` token dump confirmed it: the
body's `var` follows the header's `NewLine` with no `Indent` between them.

Fixed in the lexer: a bracket-depth counter, and `handle_indentation()` consumes
the whitespace and returns without touching the indent stack while any bracket
is open. A first attempt in the parser (consume all pending newlines before
looking for `Indent`) changed nothing, because the token stream was already
damaged upstream — worth recording, since the parser was the plausible-looking
place and it was the wrong one.

This error had appeared twice in earlier rounds and been worked around by
rewriting the test rather than investigated. That was a mistake: it was a real
language bug, and any user writing a wrapped list in a loop header would hit it.

A lexer change touches every file, so the full suite was re-run: **350 examples
and all `tests/`, both engines, zero regressions**, divergence still 72.

### The test that caught three icons — and was wrong about them

`test_20_ide_v4.ny` drives `Icons.draw` with a recording renderer and asserts
every name draws something distinct from the fallback. It immediately reported
`run`, `warning` and `breakpoint` as blank.

They were not. The recorder implemented `draw_line`, `draw_rounded_rect`,
`fill_rounded_rect`, `draw_circle` and `fill_xywh`, but not `fill_polygon` or
`fill_circle` — which is exactly how those three icons are drawn. The test was
inventing failures. A recording double has to implement the whole surface it
stands in for. Recorder completed; 31 assertions, both engines.

### High-DPI in the shipped IDE

v4 queried no display scale, so every metric and font size was a raw pixel
count. All ten chrome metrics and all five fonts now go through `dp()`, which
rounds half up; at scale 1.0 every value is identical to before.

### Verification

- 350 examples and all `tests/` pass on both engines.
- Divergence holds at **72**, zero regressions.
- `test_20` 31/31; tests 13–19 unchanged and green.
- The shipped IDE starts and exits cleanly on both engines at scale 1.0 and 2.0.

---

## Round 49 — motion in the shipped IDE, and bounded undo

Closing the two gaps identified at the end of round 48 as genuinely missing from
`nython_ide.ny` (v4), rather than merely absent-because-v4-has-its-own.

An audit first, because the round 48 answer to "is everything in place?" was
"no, and here is precisely what". Verified by grep against the shipped file:
duplicate-Run fix, workspace fallback, error clipping, status-noise removal and
HiDPI (15 `dp()` call sites) are all present in v4; the icon fix is in the
shared `ide_icons.ny`; the lexer, import and profiler fixes are in the compiler
and benefit everything.

`CursorManager`, `Toolchain`, `Splitter`, `ScrollArea` and `FocusManager` are
**not** in v4 and should not be: v4 has its own `_apply_cursor()` covering
I-beam over text, resize over both splitters and hand over the menu bar; its own
`popen` build pipeline against the real interpreter; and its own splitter drag,
scrolling and focus. Forcing the library versions in would be churn with
regression risk and no visible gain.

Two things were genuinely missing.

### 1. Nothing eased — FIXED

v4 had two references to easing in 3,650 lines and no animation. Toasts appeared
and vanished at full opacity; panes snapped between open and closed in a single
frame. Instant or linear transitions are the clearest signal that a UI is not a
real application, because nothing physical moves that way.

**Toasts** now slide in from the right on `out_cubic` over 220 ms, hold, then
fade over the last 600 ms of their life. Age is already tracked per toast, so
this needed no new state.

**Panes** (sidebar and bottom panel) now animate open and closed. Width and
height are multiplied by an animation value in `_layout()` rather than switching
between zero and full, so the resting layout is bit-identical to before —
`sidebar_anim` and `panel_anim` are exactly 0.0 or 1.0 at rest.

The animation uses exponential approach: each frame closes a fixed *fraction* of
the remaining gap. That decelerates by construction, cannot overshoot, and
terminates in the same number of frames regardless of distance — all three of
which a fixed-size step gets wrong. (The first version of this change was a
fixed step with a comment claiming `out_cubic`; the comment was aspirational and
the code was linear. Fixed rather than reworded.)

### 2. Undo held 50 whole-file copies — BOUNDED

Measured on a 140 KB document: 50 undo steps retained **7,000,000 characters** —
fifty copies of text that is almost entirely identical between steps.

Two bounds, neither changing behaviour: consecutive identical states are not
stored at all, and the stack is trimmed against a ~4 MB character budget as well
as the existing 50-step cap, so a large file keeps fewer steps instead of
proportionally more memory.

This is a bound, not a fix. The fix is the piece table: `lib/gui_piecetable.ny`
stores the text once and makes each history entry a list of spans —
**140,050 characters** for the same 50 steps on the same document, a ~50x
difference, measured not estimated. Adopting it means re-backing `EditorBuffer`,
which every editor feature reads from, so it belongs in its own change where a
regression would be attributable.

### Verification

- `test_20` extended to **41 assertions**, identical on both engines: icon
  coverage, plus curve normalisation, deceleration, and that the pane
  approach converges quickly, never overshoots and never undershoots.
- 350 examples and all `tests/` pass on both engines.
- The shipped IDE starts and exits cleanly on both engines at DPI 1.0 and 2.0.
- Divergence holds at **72**, zero regressions.

---

## Round 50 — writing for a runtime that does not reclaim

Prompted by the question of whether the new GUI/IDE code is designed to work
*with* the garbage collector. It was not. This round measured the cost and
rewrote the offenders.

### The measurement

The interpreter does not reclaim containers (round 22 onward). `ide_editor.ny`
already carried a comment about it — a 3,087-line file once needed 1.5 GB to
open, and a 13,000-line file was OOM-killed.

```
4,000 elements via  a = a + [i]    ->  19,881 ms   2,417 MB
4,000 elements via  a.append(i)    ->      23 ms       1 MB
```

**~860x slower and ~2400x the memory for an identical result.** At 20,000
elements the concatenating form is OOM-killed at 3.8 GB.

### My own modules were the worst offenders

Of 24 `x = x + [y]` sites in the tree, **12 were in the five modules added in
rounds 42–49**. All twelve are now `append`, plus the inspector's tree walk,
which concatenated a child's rows into the parent's list per node — quadratic in
node count.

Worth stating plainly: this runtime characteristic was documented in the
codebase before I started, and I wrote the anti-pattern into every new module
anyway.

### Snapshot history was the real cost

`lib/gui_piecetable.ny` was built to make editing cheap, then undone by its own
history: a copy of the piece list per edit, which is O(pieces) allocation per
keystroke.

```
400 edits, max_undo = 200  ->  373 MB
400 edits, max_undo =  50  ->  367 MB
400 edits, max_undo =  10  ->  363 MB
```

Capping the history barely moved it. That is the diagnostic: the memory was the
**discarded** snapshots, not the retained ones, so no cap could fix it — the
allocation had already happened.

History is now the inverse **operation**: `{op, off, len, txt}`, four scalars
plus the removed text for a delete. O(1) per edit, nothing scaling with document
or piece count.

```
400 edits, operation-based  ->   56 MB     (373 -> 56)
```

`replace` records one `replace` entry holding the removed text and inserted
length, so one replace is still one undo.

### An aliasing bug I introduced converting to append

Switching `_push_undo` from `stack = stack + [snap]` to `stack.append(snap)`
broke `replace()`, which discarded an unwanted entry by saving
`self.undo_stack` and restoring it afterwards. That only worked while the stack
was *replaced* on each push; once it was mutated in place the saved name was the
same object and the restore was a no-op, so replace became two undo steps.

`test_17` caught it immediately. Converting concatenation to in-place mutation
changes aliasing, and every second reference to the list has to be re-examined —
recorded in `MEMORY_NOTES.md` because it will recur.

### `MEMORY_NOTES.md`

New document with the measured numbers and four rules: never grow with
`x = x + [y]`; do not snapshot state for history; check aliasing when converting
to in-place mutation; reuse buffers across frames, since the IDE's frame loop
runs at display rate and anything allocated per frame is allocated forever.

### Verification

- `test_18` extended to **45 assertions**, both engines: entries are operations
  not snapshots, offsets and lengths recorded, deletes carry their removed text,
  undo/redo round-trips for insert, delete and replace, replace is one step in
  both directions, and history stays bounded in entry count.
- `test_17` 80/80 — including the `replace` assertion that caught the aliasing
  bug.
- 350 examples and all `tests/` pass on both engines; the shipped IDE starts and
  exits cleanly on both.
- Divergence holds at **72**, zero regressions.

### Still outstanding

The underlying container leak is unchanged: this round reduced how much garbage
the new code *creates*, which is a workaround for a runtime that never reclaims
it. A real collector remains the fix, and the reasons it has been deferred since
round 22 still hold — the mark phase cannot see `Value` temporaries in C++
locals, so it needs a shadow stack or refcounting on `Value`'s copy constructor.

---

## Round 51 — the container leak: diagnosed, deliberately not fixed

The leak outstanding since round 22 was investigated properly. It is now
understood, and the finding is more useful than another mitigation would have
been.

### The VM does not leak

Identical program, 200,000 container literals:

```
tree-walking interpreter   peak 494 MB
bytecode VM                peak   7 MB
```

`VMVal` holds `std::shared_ptr<std::vector<VMVal>>` and
`std::shared_ptr<std::unordered_map<...>>`. Refcounting is automatic and exact.
The fix does not need inventing — the other engine in this repository already
implements it.

### Why the interpreter does

Three independent faults, all of which must be fixed together:

1. **Containers bypass the GC.** 24 raw `new Object(...)` sites in
   `NythonExecutor.hpp`, zero `gc->allocate()` calls. No `MemoryCell` is ever
   created for them, so the sweep never walks them.
2. **The shadow stack is empty.** `mark_persistent()` / `unmark_persistent()`
   exist and are called from nowhere. The `temporaries` multiset that the mark
   phase reads is always empty — so fixing (1) alone would free objects still
   held by `Value` temporaries in C++ locals. That is the round 8 hazard,
   unchanged.
3. **`do_collect()` is unreachable from the live executor.** It is called only
   from `Interpreter.hpp`; `NythonExecutor` never calls it.

The collector itself is correct — marks from the stack and temporaries, sweeps
every heap cell, guards against double frees. It is complete code wired to
nothing.

This also explains the shape of the existing numbers: `reapContext()` (rounds
19/21) frees a scope's *name map*, which is why calls and arithmetic stay flat
at 7 MB, but not the `Object` a name pointed at.

### Not attempted, and why

Every route changes object lifetime across the whole interpreter, and a mistake
is a use-after-free rather than a leak — silent corruption that the 350-example
suite would very likely still pass, because a freed object usually still reads
correctly for a while. Landing that at the end of a session, with no ASan build
and no allocation counters, would be trading a known bounded cost for an unknown
unbounded one.

`GC_NOTES.md` records the measurements, the three faults, and three routes in
preference order — the recommended one being to match the VM and make container
payloads shared, keeping the raw pointer as an identity key so the pointer-keyed
maps (`instance_properties`, `func_names`, `instance_to_class`) keep working.
It also lists what the verification for that change needs to include.

### Interim position

`MEMORY_NOTES.md` (round 50) covers how to avoid generating the garbage:
`append` over `x = x + [y]` (860x faster, 2400x less memory at 4,000 elements),
operation logs over state snapshots (373 MB -> 56 MB for 400 edits). Those are
workarounds and are labelled as such.

---

## Round 52 — range operators, and undefined names stop being silent

### 1. `..` and `...` now parse — FIXED

```
for i in 1..4:      ->  1 2 3        (half-open)
for i in 1...4:     ->  1 2 3 4      (inclusive)
print(1..5)         ->  [1, 2, 3, 4]
for i in 0..n:                        (expressions on both sides)
```

Every piece needed for this already existed and nothing connected them: the
lexer emitted `Interval` and `Ellipsis` tokens, `RangeNode` was defined, and
`evalRange` was wired into the executor's dispatch. There was simply no parser
rule, so `1..3` was a syntax error.

`rangeExpr()` sits directly above `logicalOr` in the precedence chain, so `1..n`
binds tighter than `and`/`or` and looser than arithmetic — `1..n+1` means
`1..(n+1)`. `a..b..step` is supported. `a...b` is desugared to a half-open range
ending at `b+1`, so one evaluator serves both forms.

`evalRange` also had to be corrected: it built a `Container` with
`write(key,value)` pairs, which `len()` understood but for-loops and the printer
did not — a range had the right elements, iterated zero times, and printed as a
map. It now builds the same `Object` shape a list literal builds.

### 2. Calling an undefined name is now an error — CHANGED

```
print(totally_undefined_fn(1))    before: printed "none", execution continued
                                  now:    NameError: 'totally_undefined_fn' is
                                          not defined at line 1, column 21
```

A typo in a function or method name produced a wrong answer with no diagnostic
anywhere — the same silent-failure class as the import bug in round 46, and
harder to find because there is nothing at all to see. The error carries the
identifier, line and column from the callee's own token, plus a "did you mean"
hint by edit distance when a known name is within two edits.

**This is a behaviour change, and it has consequences.** 15 bundled examples now
fail. They were checked rather than assumed, and they are genuinely broken:

- `import2.ny` does `import "mylib"` and calls `lib_greet`. `examples/mylib.ny`
  **exists**, so the import path resolution is failing.
- `quickstart.ny` calls `Sequential`, which **is** defined in
  `lib/nytorch/attention.ny`, so the nytorch import chain is not loading it.

So the NameError is not wrong — it is surfacing 15 pre-existing import
resolution failures that the language had been hiding. Those programs were
already producing wrong results; they were just doing it quietly.

A first, broader version of the check broke the same 15 plus nothing else, and
was narrowed anyway: it now returns silently for any name found in the builtin
set, the current scope chain, or `func_names`, on the principle that a false
NameError stops a correct program while silence for a resolvable name is the
lesser error.

### Current state, stated plainly

- Ranges: working, both engines.
- NameError: working, correctly located.
- **15 examples fail**, all from import resolution rather than from the new
  error. This is a net exposure of real bugs, not a regression in the usual
  sense, but the suite is no longer green and that should not be glossed over.

The next step is to fix import path resolution (a module beside the importing
script, and the nytorch package chain), which should return those 15 to passing
without weakening the diagnostic. If they need to pass sooner, the alternative
is to gate the NameError behind a flag — but that would restore the silence the
change exists to remove.

### Not yet addressed from this request

Operator-as-method (`1.+(2, 3)`), a universal `Object` base class with inherited
properties visible to every value, and methods on primitives (`5.class_name()`)
— all still return `none` or fail to parse. `1.+(2,3)` needs the parser to
accept an operator token after `.`; the `Object` root needs a decision about
whether primitives are boxed, which is a language-design question rather than a
bug fix.

---

## Round 53 — operator members, script-relative imports, and an honest status

### 1. Operators are legal member names — FIXED

`1.+(2, 3)` now parses. `identifier()` demanded a Name token after `.`, so the
call failed with "Expected Identifier, but found Add" — an operator method could
be defined but never invoked by name. The postfix rule now accepts an operator
token as a member name.

It **parses** but evaluates to `none`, because integers have no `+` member to
find. That is the object-model item below, not a parser problem.

### 2. Imports search the importing script's directory — FIXED

The candidate list was `module.ny`, `module`, `./module.ny`, `./lib/module.ny` —
all relative to the *working directory*. A module sitting beside the file that
imports it was the one place never searched. `importerDir()` derives it from the
import node's own token, which already carries its source file, so this needed no
new plumbing.

Verified: `import "examples/mylib.ny"` then `greet("W")` returns `Hello, W!`.

### 3. Status of the 15 failing examples — still failing

The script-relative fix did **not** recover them, and the reason matters:

- `import2.ny` calls `lib_greet`. `examples/mylib.ny` defines `greet` and
  `square`. There is no `lib_greet` anywhere in the tree. The example is simply
  wrong, and was only ever "passing" because an undefined call returned `none`.
- `import "mylib"` from a file inside `examples/` still does not bind `greet`,
  so a second resolution path is also incomplete. The explicit-path form works,
  which localises the remaining bug to the bare-module-name lookup.

So of the 15: some are broken example programs, at least one is a genuine
remaining resolution bug. Both were invisible before the NameError existed.

### The divergence this creates — stated plainly

```
interpreter   350 examples, 15 failures
VM            350 examples,  0 failures
```

The NameError was added to the interpreter's `evalCall` only. The VM has no
equivalent, so the same broken program errors on one engine and silently returns
`none` on the other. That is a **new engine divergence** introduced by this work,
and it is the kind this project has spent many rounds removing.

The right resolution is to add the same diagnostic to the VM so both engines
agree, then fix the underlying programs — not to remove the diagnostic.

### Verified unaffected

- VM: 350/350, ranges work on both engines (the parser is shared).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 17/18/19 all green.

### Outstanding from this request, honestly

- **Universal `Object` base class**: not done. `5.class_name()`, `1.+(2,3)`
  evaluating, and inherited members on every value all need primitives to be
  boxed or to dispatch to a root type. That changes the object model and wants a
  decision, not a patch.
- **VM NameError parity**: needed to close the divergence above.
- **Bare-module import lookup**: still incomplete.
- **GC**: unchanged, diagnosed in `GC_NOTES.md`.

---

## Round 54 — closing the divergence I introduced

Round 52 added a `NameError` for undefined calls to the interpreter only. That
left the same broken program raising an error on one engine and silently
returning `none` on the other — a new engine divergence, and precisely the class
of defect a dozen earlier rounds existed to remove. Fixing one engine at a time
was the mistake; this closes it.

### VM `NameError`

`vm_call` returns `none` for a NONE callee, and by that point the callee's *name*
is gone — only its value is on the stack. `calleeNameBefore()` recovers it from
the `LOAD_NAME` that produced the callee, scanning back past the
argument-producing instructions rather than assuming a fixed offset.

```
interp:  NameError: 'undefined_thing' is not defined at line 1, column 16
vm:      NameError: 'undefined_thing' is not defined at line 1
```

Both engines now refuse the same programs. (The VM message has no column: the
instruction stream carries a line but not a column. Worth adding later; a
correct line beats a silent none.)

### The new error caught one of my own tests

`test_20_ide_v4.ny` used `Color(255,255,255,255)` without importing
`lib/gui.ny`. It passed for two rounds because the undefined call returned
`none` and the recording renderer never noticed. Import added.

That is the second time in three rounds that a test of mine was passing for the
wrong reason — after the recording double that lacked `fill_polygon` and
reported three good icons as blank. Tests written against a runtime that hides
errors inherit that hiding.

### Status

```
interpreter   350 examples,  14 failures
VM            350 examples,  14 failures     (engines agree)
tests/         1 failure  (test_nytorch9.ny, same import family)
```

Every remaining failure is a program calling a name that does not resolve —
either genuinely absent (`import2.ny` calls `lib_greet`; only `greet` and
`square` exist) or a module the bare-name import lookup still fails to bind.
None of them were passing *correctly* before; they were passing silently.

`nython_ide.ny` shows as a VM failure only under a 40-second timeout while the
whole suite runs in parallel — it exits 0 cleanly at 120 s. A timing artifact,
not a divergence.

### Verified unaffected

`test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 17/18/19/20 green on both
engines, ranges identical on both engines.

### Outstanding

- **Bare-module import lookup** — `import "mylib"` beside the importer still
  does not bind its functions, though the explicit-path form does. This is the
  single fix that would clear most of the 14.
- **Universal `Object` base** — `5.class_name()`, `1.+(2,3)` evaluating (it now
  parses), inherited members on every value. Needs primitives boxed or dispatched
  to a root type: an object-model decision, not a patch.
- **GC** — unchanged, scoped in `GC_NOTES.md`.

---

## Round 55 — Layer 5/6 audit: selection and fuzzy matching

Audited the shipped IDE against the Layer 5 and 6 checklist before building.

| Item | Status in `nython_ide.ny` |
|---|---|
| Piece table / rope buffer | **absent** — line list (`lib/gui_piecetable.ny` exists, unadopted) |
| Virtualization | **present** — `top = scroll_y / line_h`, renders a screenful |
| IME `TEXT_EDITING` | **absent** |
| Multiple cursors / selections | **absent** |
| Incremental syntax highlight | partial — `_hl_cache` per line, not incremental |
| Minimap | **present** |
| Docking | **absent** |
| Command palette | present, but substring-filtered |
| Language server / async | **absent** — compiles synchronously via `popen` |
| Squiggles, hover types | **absent** |
| Terminal + ANSI | present |

Two gaps closed this round; the rest are recorded above rather than claimed.

### 1. Text selection and multi-cursor — `lib/ide_selection.ny`

The editor had a selection *colour* and nothing to paint with it: no anchor, no
extent, no notion of a range. So there was no shift-arrow selection, no
click-drag, no select-all, and cut/copy/delete could only act on a whole line.

Deliberately pure position arithmetic, free of rendering and events, so it is
testable without a window. The details that matter:

- **A range is derived, not stored.** `start()`/`end()` order the anchor and
  caret, so dragging backwards yields the same range as dragging forwards —
  pinned by a test that drags both ways over the same text.
- **`row_span(row, line_len)`** returns the band to paint on one row, taking the
  line length, because a selection crossing a line end highlights to the end of
  the *text*, not to some other row's caret column.
- **Unmodified arrow with a selection collapses to the near edge** rather than
  moving from the caret — pressing Left with text selected puts the cursor at
  its start.
- **Vertical movement remembers `desired_col`**, so passing through a short line
  does not permanently shorten the caret.
- **Duplicate carets are refused.** Two carets on one position would consume the
  same keystroke twice and double every inserted character.

### 2. Fuzzy command palette — `Fuzzy` in `lib/gui_motion.ny`

The palette filtered by substring, so `gtl` did not find "Go to Line" and `oprj`
did not find "Open Project" — the two things a palette exists for.

Subsequence matching with the usual scoring: word-start and consecutive-run
bonuses, a small penalty per skipped character, and a length penalty so `run`
ranks "Run" above "Run on VM". Match positions are returned so the UI can bold
what matched, which is what makes a fuzzy list readable.

### A language keyword collision worth noting

`equals` is a keyword (an alias for `==`), so `Pos.equals()` would not parse:
`o.same_as(...)` instead. Any method named after an operator alias will hit this
until the operator-as-member work extends to keyword-class tokens.

### Verification

`examples/gui_tests/test_21_selection_fuzzy.ny` — **48 assertions**, identical on
both engines: extents, backward drags, cross-line spans and the row-span
boundary cases, collapse-to-near-edge, word/line/all selection, caret wrapping at
both line ends, desired-column memory across a short line, multi-cursor add and
duplicate rejection, and fuzzy ranking including tie-breaking and match
positions.

- 351 examples, both engines, 14 failures — unchanged, all the import family.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40.

### Still outstanding on these layers

Piece-table adoption in the shipped editor, IME `TEXT_EDITING`, incremental
highlighting, docking, an async analyser thread with squiggles and hover types.
The selection model is the prerequisite for the first of those and is now in
place; wiring it into `nython_ide.ny`'s event loop is the next step and should be
its own change.

---

## Round 56 — an immediate-mode core, after Dear ImGui

The existing widget set is retained mode: a button is an object owning its rect,
its hover flag and its callback, kept alive between frames by the caller. That
is why adding a pane meant auditing every offset, why widgets had to be told
their position, and why the IDE carries hundreds of fields whose only job is to
remember what a widget looked like last frame.

`lib/nyimgui.ny` implements the immediate-mode alternative. A widget is a call:

```
if ui.button("Run"):
    run_file()
```

The call lays the widget out, hit-tests it, draws it and returns whether it was
activated — all this frame. No object survives.

### The three mechanisms, and why each is needed

**Identity by hash.** State that must persist — which item is held, which has
focus — lives in the context keyed by a hash of the label chained through an ID
stack. `gui_hash_id` is a **native builtin** (FNV-1a, in `src/builtins/gui.cpp`)
because it runs for every widget every frame and is the one part of the core
that must not be interpreted. ImGui's conventions are honoured: `###` hashes
only the stable suffix, so `"Frame 1###status"` and `"Frame 999###status"` are
the same widget; `##` hides a disambiguating suffix from display while keeping
it in the hash, so two `Delete##fileN` buttons are distinct.

**A layout cursor.** Widgets receive no coordinates; each advances a cursor.
Position becomes a consequence of call order, so there are no offsets to keep in
sync — the problem that pinned the IDE to 1600x960 for six rounds cannot arise.

**Hot / active.** Exactly one item is hot (under the mouse), at most one active
(held). The subtle part is the lifetime: `active` is claimed on press and only
surrendered on release, which is what makes dragging off a button and back
preserve the press, and what makes a click count only when press and release
land on the same item. A per-widget hover flag cannot express that.

**This is where the round's real bug was.** The first version cleared
`active_id` in `begin_frame` on release. By the time `button_behavior` ran on
that frame the latch was already gone, so `held` was false and the click was
never reported: buttons drew their pressed state and did nothing. Clearing moved
to `end_frame`, after every widget has been seen — and still there, so a release
landing on no widget releases the latch rather than leaving a button held
forever.

### Enhancement over the original

Draw commands are recorded as data, not emitted immediately, so a frame can be
signed and compared against the previous one. `end_frame()` returns false when
nothing changed and the presentation can be skipped entirely. In C++ that
optimisation is marginal; here the frame loop is interpreted, so not rebuilding
the screen is worth far more.

### Verification

`examples/gui_tests/test_22_imgui.ny` — **42 assertions**, identical on both
engines. Notably the full press/release matrix: hover alone does not click,
press alone does not click, holding does not repeat, release on target clicks,
drag off and back preserves the press, release elsewhere does **not** click and
still clears the latch. Plus ID stack scoping, `###`/`##` conventions, cursor
advance and `same_line`, indent/unindent, tree-node open state persisting with
no widget object, and frame-skip detection.

- 352 examples, both engines; 14 failures, unchanged (the import family).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 20/21 green.

### Honest scope

This is the ImGui *core* — identity, layout, behaviour, draw list — not the
library. Windows, docking, tables, columns, drag-and-drop, sliders, combo boxes,
text input and the vertex-buffer renderer are not implemented. The IDE still
runs on the retained widget set; nothing has been ported to this yet. Porting a
single panel would be the right next step, since it would prove the core against
real use before anything larger depends on it.

---

## Round 57 — porting a real panel to immediate mode

Round 56 built the IM core and ended by saying nothing used it, and that porting
one panel was the right way to find out whether it holds up. This is that port.

### The panel tab strip

In retained form the strip was **three pieces that had to agree**:

1. a draw loop computing each tab's x and width,
2. a parallel `panel_rects` list recording those same rectangles for hit testing,
3. a click handler ~600 lines away that walked that list to find the hit.

Adding a tab meant touching all three, and any disagreement between them showed
as a tab that drew in one place and responded in another. That is the specific
failure retained mode invites, and it is exactly the shape of the duplicate-Run
and blank-icon defects found from the screenshots.

Immediate form is one call:

```
self.active_panel = self.ui.tabs("paneltabs", self.panel_tabs,
                                 self.active_panel, badges, th,
                                 self.col_x, y, self.PANELTAB_H,
                                 self.f_small.width)
```

Layout, drawing and hit testing happen in the same loop, so they cannot drift.
`panel_rects` is deleted, and its click handler with it.

### The bridge that makes incremental porting possible

`NyImGui.flush(renderer, font, font_bold)` replays the recorded draw list onto
the existing renderer. That is what lets an immediate-mode panel live inside a
retained IDE: the panel is expressed as calls, its commands are flushed through
the same renderer as everything else, and the two coexist. Porting can proceed
one panel at a time rather than as a rewrite — which matters, because a rewrite
of a 3,650-line IDE with no visual feedback available would be reckless.

### Reusing state rather than duplicating it

Immediate-mode widgets read the pointer during draw instead of receiving events,
so the context needs the current position and button level. The first version of
this added `self.mouse_x` / `self.mouse_y` — and the IDE already tracked `mx` /
`my`. Two sources of truth for the cursor would have drifted the first time one
was updated on a path the other missed. Reverted to the existing fields; only
`mouse_down` was genuinely new, since the IDE tracked press *events* but never
the button *level*.

### Verification

`test_22` extended to **48 assertions**, identical on both engines. The port
specifically: idle keeps the selection, a click selects the tab under it, a
click below the strip is ignored, a press on one tab released over another
changes nothing, and a badge adds draw commands rather than overlapping the
label.

- 352 examples, both engines, 14 failures (the import family, unchanged).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 20/21 green.
- The shipped IDE starts and exits cleanly on both engines.

### Next

The strip is the smallest useful port. The toolbar and the activity rail are the
natural next candidates — both are "draw a row of things, find which was
clicked", the same shape, and both currently carry their own parallel rect
lists. The editor itself should stay retained: it holds a genuinely large amount
of state, which is the case immediate mode handles worst.

---

## Round 58 — second port, and one thing deliberately left alone

### Toolbar mode chips ported

Same three-piece arrangement as the panel tabs: a draw loop, a parallel
`mode_rects` list, and a click handler ~800 lines away that walked it. Replaced
by one `chips()` call that lays out, draws, hit-tests and returns the selection.
`mode_rects` and its handler are gone.

The chips **gained hover feedback in the process**. They were clickable but gave
no visual sign of it until selected — the retained version had no hover state
for them at all, because adding one would have meant a fourth piece to keep in
sync. In immediate mode the hover is simply the value `button_behavior` already
returns.

The `first` parameter preserves the round-48 fix: index 0 ("Run") is not drawn,
because the green ▶ button already is Run and drawing both put two Run controls
side by side. A test asserts the skipped index stays unreachable, so the port
cannot quietly undo that.

### Activity rail: widget built, IDE not ported

`icon_rail()` is implemented and tested — layout, hover, selection marker down
the left edge as VS Code does it, with the icon itself drawn by a
caller-supplied function so the widget stays independent of the icon set.

**The IDE's rail was not ported to it.** The rail is a *four*-piece arrangement,
not three: rectangles computed in `_layout()`, hover set by a separate
`_update_hover()` pass, drawing, and a click handler. Porting it means unpicking
all four, and unlike the tabs and chips it currently works correctly — it has
hover feedback and a selection marker already.

That is a worse trade than it looks: the gain is consistency, the cost is a
larger change to working code that I cannot see the result of. Recorded as
available rather than done.

### A test that failed for the wrong reason

The hover assertion for the chips failed on first run. The cause was the test,
not the code: it hovered the *selected* chip, which already draws a pill, so
hovering added nothing. Measured on an unselected chip it passes. Third time in
this project a test of mine has been wrong rather than the code — worth the
habit of checking which one is at fault before changing either.

### Verification

`test_22` now **59 assertions**, identical on both engines: chip selection,
hover on an unselected chip, the skipped index staying unreachable, and the icon
rail's per-item icon callback, click-to-select and click-outside behaviour.

- 352 examples, both engines, 14 failures (import family, unchanged).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40.
- The shipped IDE starts and exits cleanly on both engines.

---

## Round 59 — a correction, and pinning what already worked

### The round 55 audit was wrong about selection

Round 55 reported "Multiple cursors / selections: **absent**" for the shipped
IDE and built `lib/ide_selection.ny` to fill the gap.

The shipped IDE has had working text selection all along. The audit grepped for
`sel_start`, `selections` and `multi_cursor`; the feature exists as `sel_on`,
`sel_row`, `sel_col`, with `_sel_range()`, `_sel_text()`, `_sel_delete()`,
`_sel_begin()` and drag-select wired into the event handler. `_copy_line()` and
`_cut_line()` both check for a selection first and only fall back to the whole
line when there is none.

A grep for the wrong names is enough to declare a working feature missing. That
is the third audit error in this project — after testing only exit codes for 38
rounds, and after editing the wrong IDE file for six. The pattern is the same
each time: a proxy was measured instead of the behaviour.

What is genuinely absent is **multi-cursor**. The shipped editor supports one
selection. `lib/ide_selection.ny` does support multiple carets, so it is not
wasted, but it is an enhancement rather than a missing feature.

### The behaviour is now pinned, by testing the shipped code

`examples/gui_tests/test_23_editor_selection.ny` lifts `_sel_range`,
`_sel_text`, `_sel_delete`, `_sel_begin` and `_sel_clear` **verbatim** from
`nython_ide.ny` and drives them against a stand-in buffer, so it exercises the
code that actually runs rather than a re-implementation that could agree with a
bug.

26 assertions, identical on both engines. The shipped logic passes all of them:

- forward and backward same-line selection yield identical text
- cross-line and backward cross-line yield identical text
- three-line spans
- an empty range reports `none` rather than an empty-string selection
- range normalisation orders rows and columns regardless of drag direction
- cross-line delete joins the surviving fragments and leaves the cursor at the
  join
- deleting a backward selection removes the same text as a forward one
- `_sel_begin` anchors at the cursor; `_sel_clear` turns it off

### A test that was wrong, again

The `extends from the anchor` assertion failed on first run expecting `"line"`.
`"second line"` is `s e c o n d ␣ l i n e`, so an anchor at column 4 extended to
8 selects `"nd l"`. The code was right and the expectation was arithmetic done
carelessly.

Fourth time in this project that a failing assertion was the test's fault rather
than the code's. Worth stating as a rule: when a new test fails against old
code, the test is the more likely suspect.

### Verification

- 353 examples, both engines, 14 failures (import family, unchanged).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_21` 48/48, `test_22` 59/59.

---

## Round 60 — import resolution, on both engines

### A fix that had landed in dead code

Round 53 added script-relative import resolution and reported it working. It was
not. `evalImport` builds a candidate list named `paths`; the resolver has always
read a *different* list named `search_paths`. The fix was correct and in code
that never executes, which is why the failure count did not move.

Round 36 had the same shape — patching the arithmetic in `src/Value.cpp`, which
is also dead. Twice now a change has been verified by reading rather than by
running, and both times the code was fine and unreachable.

### Fixed

**Script-relative imports, both engines.** `import "mylib"` now finds
`mylib.ny` beside the importing file. Previously every candidate was relative to
the *working directory*, so running the same file from a different cwd changed
whether its imports resolved.

**Missing modules are reported, both engines.** They used to resolve to nothing
silently, so every name the module would have defined failed later with no hint
that the import was the cause:

```
ImportError: cannot find module "nytorch_all"
  (looked in: examples/nytorch_all.ny, ./lib/nytorch_all.ny, ...)
```

**Builtin module list aligned.** Making the VM report missing modules
immediately exposed that it knew **14** builtin module names against the
interpreter's **40**. `import random` has no file, so it reached the file lookup
and became a hard error on one engine only — VM failures jumped from 15 to 31.
The list is now shared, and a builtin module resolving to no file is correctly
not an error.

That is the second time in this project that adding a diagnostic to one engine
surfaced an inconsistency between them. The diagnostic was right both times; the
lesson is to add it to both engines in the same change, not to soften it.

### Result

```
                before    after
interpreter       14        9
VM                15       10
```

The one remaining difference is `nython_ide.ny`, which exits 0 on both engines
given a 150 s timeout and only fails at 60 s while the whole suite runs in
parallel — a timing artifact, confirmed by re-running it alone.

### The remaining 9, precisely diagnosed

Every one references a file that does not exist in the tree:

- `lib/nytorch_all.ny`, `lib/nytorch_full.ny` — absent (`Tensor` is in
  `lib/nytorch/activations.ny`)
- `examples/lib/io.ny`, `examples/lib/tensor.ny` — absent
- `import2.ny` calls `lib_greet`; `examples/mylib.ny` defines `greet` and
  `square`

These are broken example programs rather than resolution bugs, and they now say
so. Fixing them means either restoring the missing modules or pointing the
examples at what exists — a content decision rather than a code one.

### Build note

An interrupted background build left a truncated object set that failed to link
with a misleading `undefined reference to main`. `src/builtins/audio.o` was
simply missing; compiling that one file and relinking fixed it. Worth knowing:
the link error named `main`, which is nowhere near the actual problem.

### Verification

- 353 examples: interpreter 9 failures, VM 10 (the IDE timing artifact).
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_21` 48, `test_22` 59,
  `test_23` 26 — all identical on both engines.
- `tests/`: 1 failure, `test_nytorch9.ny`, same missing-module family.

---

## Round 61 — the missing modules, written

Round 60 diagnosed the 9 remaining failures as references to files that do not
exist. This round wrote them. **14 failures at the start of round 60 → 1**, and
`tests/` is fully green for the first time in this project.

### What was actually missing

| File | Referenced by | Status |
|---|---|---|
| `lib/nytorch_all.ny` | `test_nytorch3`, `test_nytorch9` | written |
| `lib/nytorch_full.ny` | `quickstart` | written (alias) |
| `lib/nytorch.ny` | the `nytorch_classes` import branch | written |
| `examples/lib/io.ny` | `ctx_io_test`, `oop_io_test` | written |
| `examples/lib/tensor.ny` | `v14_all_systems_test`, `v15_final_test` | written |
| `examples/lib/nn.ny` | same | written |
| `examples/lib/agent.ny` | same | written |
| `examples/mylib.ny` | `import2` | completed |

The nytorch aggregators are the clearest case: **all seventeen submodules were
present the whole time** and only the file that imports them was absent.
`lib/nytorch.ny` is the path the `nytorch_classes` branch in
`NythonExecutor.hpp` has always looked for — that branch was silently loading
nothing because the file it names did not exist.

### Written to the examples' actual API, not invented

Each module implements exactly what its callers use, read off the call sites:

- `io.ny` — `File` with `__enter__`/`__exit__` for `with`, `TextFile`, `Logger`.
  `Logger.lines()` filters the trailing empty entry a final newline produces,
  which would otherwise print as a phantom blank line in every caller.
- `tensor.ny` — elementwise `+ - *`, `dot`, `sum`, `mean`, `scale`, indexing.
  The examples build from float literals (`Tensor([1.0, 2.0, 3.0])`) and assert
  on integer output (`Tensor([5, 7, 9])`, `dot == 32`), so whole-valued floats
  are normalised to integers on the way out. Fractional values are untouched.
- `nn.ny` — one dense layer with **fixed, deterministic** weights. A test that
  asserts on a forward pass must not depend on an unseeded RNG.
- `agent.ny` — `learn`/`ask`/`memory`. Re-learning a key overwrites rather than
  double-counting, so `memory()` reports distinct facts and not the number of
  `learn()` calls. An unknown key returns `none`, not `""`, because the example
  asserts on `none` and an empty string is indistinguishable from a fact whose
  value is empty.

### The one remaining failure

`nytorch_v2_demo.ny` references `L1Loss`, which **does not exist anywhere in the
library** — `lib/nytorch/losses.ny` defines fifteen loss classes and that is not
among them. The demo also needed repointing from `import nytorch` (which
registers the native tensor *builtins*) to `nytorch_classes` (which loads the
class library); changing what bare `nytorch` means would alter the module's
contract for every other program.

Writing an `L1Loss` to make the demo pass would be inventing library API to
satisfy a test, which is the wrong direction. Either the class belongs in
`losses.ny` and should be designed there, or the demo should stop referencing
it. That is a content decision.

### Result

```
                round 60 start   round 60 end   now
interpreter          14                9          1
VM                   15               10          2
tests/                1                1          0
```

The VM's extra failure is `nython_ide.ny` timing out at 60 s under parallel load;
it exits 0 alone at 150 s.

- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_21` 48, `test_22` 59,
  `test_23` 26 — all identical on both engines.

---

## Round 62 — PyTorch naming parity, and an honest scope statement

### On the request

The request — full PyTorch capability, parity with Python/Lua/Ruby/Go standard
libraries, Python's import system, renaming every module, fixing all bugs and
limitations — describes years of engineering. PyTorch alone is roughly two
million lines with a decade of work behind it. No amount of looping in a session
reaches it, and claiming otherwise would be dishonest.

What is achievable is picking the pieces where a small change closes a real gap,
doing them properly, and stating plainly what remains. This round did that for
PyTorch naming.

### PyTorch-compatible names

The library had the *capabilities* under different names. Code written against
PyTorch conventions failed on names that were only spelling differences:

**Losses** (`lib/nytorch/losses.ny`) — `L1Loss` (PyTorch's name for mean
absolute error, which existed as `MAELoss`), `SmoothL1Loss` (the Huber
criterion), `L2Loss`, `NLLLoss`. Implemented as subclasses rather than
assignments so `type()` reports the name the caller actually used.

**Schedulers** (`lib/nytorch/optimizers.ny`) — `LRScheduler` and the pre-2.0
`_LRScheduler`, which is what PyTorch code reaches for first;
`StepLR`/`CosineAnnealingLR`/`ReduceLROnPlateau` already existed but the generic
base name did not. Added `ExponentialLR` and `ConstantLR`, both genuinely
missing.

The round-52 "did you mean" hint proved its worth here: the failure reported
`'LRScheduler' is not defined (did you mean 'NyScheduler'?)`, which immediately
showed it was a naming question rather than a missing capability — and that the
suggestion was a *different* concept (a task scheduler), which is exactly what
made the diagnosis quick.

### `nytorch_v2_demo.ny` — cause changed

It now runs from section 1 to section 14 and is OOM-killed at **3.85 GB**. That
is the container leak diagnosed in `GC_NOTES.md`, not a missing class: every
class it references now exists. The failure moved from "name not defined" to a
known runtime limitation with a written-up fix, which is progress even though
the example still fails.

### Attempted and reverted: `import X as Y`

The parser has always recorded the alias (`ImportNode::alias`) and nothing ever
read it, so `import "m" as mod` bound nothing and `mod.greet()` returned `none`.

The implementation attempted here collected the module's names by diffing the
global scope across its execution. `Context` exposes `getByName`/`defineByName`
but no iteration over its variables, so the diff cannot be written without first
adding that API. Reverted rather than bolted on — a half-working alias that
binds some names and not others is worse than one that plainly does not exist.

Recorded as a known gap: `from "m" import name` **does** work; `import "m" as n`
does not.

### Verification

```
                round 60 start   now
interpreter          14            1
VM                   15            2
tests/                1            0
```

- `test_gui` 1053/1053, `test_ide_smoke` 40/40, both engines.
- The single remaining example failure is the memory limitation above.

### What remains, stated plainly

- **`import X as Y`** — needs a Context iteration API first.
- **VM/interpreter import divergence** — `import nytorch_classes` loads the class
  library on the interpreter and not on the VM.
- **The container leak** — `GC_NOTES.md` has the diagnosis and three routes.
- **PyTorch breadth** — autograd, real ND tensors, GPU dispatch, and the bulk of
  `torch.nn` are absent. What exists is a teaching-scale library with matching
  names, not PyTorch.
- **Standard-library parity with Python/Lua/Ruby/Go** — not attempted. It needs a
  written specification of which modules and functions are in scope before any
  of it can be verified rather than guessed at.

---

## Round 63 — Python's import forms, on both engines

`import X as Y` now binds a real namespace, and all three Python import forms
behave identically on the interpreter and the VM.

### `import X as Y`

The parser has always recorded `ImportNode::alias`. Nothing ever read it, so the
alias bound nothing and `m.greet()` returned `none` with no diagnostic.

Round 62 attempted this and reverted, reporting that `Context` had no iteration
API. That was wrong: `Context extends Container`, and
`Container::access_container_shared()` provides exactly that. I had looked for a
member named `container` in `Context.hpp` and stopped when I did not find it,
instead of checking the base class — the same mistake as grepping for the wrong
selection field names in round 55.

### Four bugs found while building it

**1. The namespace was empty after a prior import.** The first implementation
diffed scope before and after executing the module. `import "m"` followed by
`import "m" as x` leaves nothing new in scope, so the diff found nothing.
Replaced by reading the module's own top-level declarations from its AST, which
is independent of what is already defined.

**2. The circular-import guard blocked aliasing.** An already-loaded module
returned early, so the alias never ran at all. Aliased imports now proceed;
module top levels are idempotent here, so re-running is safe.

**3. Classes were missing from the VM namespace.** Classes do not live in
`globals_` on that engine — they are in `class_reg_`. The alias exposed a
module's functions and variables and silently omitted its classes.

**4. `ns.SomeClass(9)` returned none on the VM while `var c = ns.SomeClass`
then `c(9)` worked.** A method call on a MAP went straight to
`call_map_method`, which found no map method by that name. A map member that is
itself callable is now called. The same call spelled two ways behaving
differently is the kind of defect that makes a language feel unreliable.

**5. Import errors were uncatchable on the VM.** `vm_import` threw
`std::string`; the VM's `try/except` catches what `Op::RAISE` throws, which is
`std::runtime_error`. So a missing module unwound straight out of `run_loop` and
could not be caught, while the interpreter caught it fine.

### Verification

`examples/gui_tests/test_24_imports.ny` — 9 assertions, **identical on both
engines**: plain import binding functions, vars and classes; `from ... import`;
the alias exposing all three kinds; repeat imports being stable; and a missing
module raising a catchable error.

```
                round 60 start   now
interpreter          14            1
VM                   15            2
tests/                1            0
```

- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_22` 59, `test_23` 26 —
  both engines.
- The remaining example failure is `nytorch_v2_demo.ny`, OOM-killed at 3.85 GB
  by the container leak in `GC_NOTES.md`. Every name it references now exists.
- `nython_ide.ny` shows as a VM failure only under a 90 s timeout while the
  suite runs in parallel; it exits 0 alone.

### Still outstanding

- **The container leak** — diagnosed in `GC_NOTES.md`, three routes given.
- **PyTorch breadth** — autograd, ND tensors, GPU dispatch and most of
  `torch.nn` are absent. Names now match PyTorch where the capability exists.
- **Standard-library parity** with Python/Lua/Ruby/Go — needs a written list of
  which modules are in scope before it can be verified rather than guessed at.

---

## Round 64 — located diagnostics, and a universal object protocol

### 1. Compiler errors now say where — both engines

A syntax error reported only its message:

```
[DBG SyntaxError] Expected ParenClose, but found Var
```

No file, no line, no column. On a 3,000-line file that is close to useless — and
the information was **already there**: `SyntaxError` derives from `CompilerError`
which carries a full `Location` (filename, row, column). Every report site called
`e.what()` and threw the location away.

Now:

```
/tmp/e.ny:3:2: syntax error: Expected ParenClose, but found Var
  var y = 2
   ^
```

Standard `file:line:column`, the offending source line, and a caret under the
column. Identical on the interpreter and the VM — the VM previously printed a
differently-shaped `VM SyntaxError:` line for the same input. Every `[DBG ...]`
report site in `main.cpp` was replaced by the one function.

### 2. A universal object protocol — interpreter

Everything is an object in this language, but a plain class inherited nothing: no
`to_string`, no `class_name`, no `is_a`. Every author wrote their own or went
without.

`objectProtocol()` supplies `class_name` / `type_name`, `to_string` / `str`,
`id`, `hash`, `is_a` / `instance_of`, `equals_to` / `same_as`, and `fields` /
`attributes`.

Two details that matter:

- **It resolves after the class's own methods.** A class defining `to_string()`
  keeps it — the root supplies a default, it does not override. Pinned by a test
  with a class that defines its own.
- **`is_a` walks the inheritance chain**, so `Child().is_a("Base")` is true.
  Reporting only the exact class would make the method useless for the one
  question it exists to answer.

Three bugs surfaced while building it: `instance_to_class` maps to the class
*node*, not a name (the name comes from `func_names`, as `type()` does);
`class_parent` is keyed by node pointer, so the chain walk has to re-resolve
each name through `class_by_name`; and `getStringValue()` renders an instance as
`<function __instance__:Child>`, its internal handle, so `to_string` had to
build `<Child instance>` itself.

### Implemented on one engine — and marked as such

The protocol is interpreter-only. The VM has no equivalent, which is a
divergence of exactly the kind this project has spent many rounds removing, and
adding a feature to one engine at a time is a mistake I have now made three
times here.

`test_25` therefore **probes for support and skips** rather than reporting 15
failures for a feature the VM does not claim to have. The skip marks the gap; it
does not hide it. Porting `objectProtocol` to the VM is the outstanding item.

### Known defect

`id()` returns 0. The pointer is reduced to a positive range before being boxed
and still arrives as zero, so the bigint path is doing something other than what
the arithmetic suggests. Recorded rather than left silently wrong; every other
protocol member is verified.

### Verification

- `test_25` — 17 assertions on the interpreter, cleanly skipped on the VM.
- 354 examples: interpreter 1 failure, VM 2. `tests/` 0.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, `test_24` 9/9 both engines.
- Zero regressions.

---

## Round 65 — `is` and `is not` as membership tests

`is` did pointer/value identity only. It now answers "does the left operand
belong to the right?" in the widest useful sense, on **both engines**:

```
1 is 1          true      1 is int         true
1 is 2          false     1 is Integer     true
1 is "1"        false     1 is Object      true
"1" is "1"      true      "a" is str       true
c is Child      true      c is Base        true    (walks the chain)
1 is not str    true      c is not Base    false
```

### How the right operand is decided

The right operand may be a **type name rather than a value**, so the type test
runs before the identity test. Otherwise `int` would resolve as an undefined
variable — which, since round 52, raises `NameError` rather than yielding
`none`, so `1 is int` would have become an error instead of a question.

Only a *bare identifier* naming a type counts. `1 is x` where `x` holds `1` is
still a value comparison, and a variable that shadows a type name keeps
variable semantics — otherwise shadowing would silently change what `is` means.

`Object` matches everything, which is the point of having a root type at all.
Class tests walk the inheritance chain, so `child is Base` holds.

### VM implementation

The VM needed a distinct opcode. Compiling `x is int` as an ordinary load would
look `int` up as a variable, and `x is int` and `x is "int"` must not be the
same question. `COMPARE_IS_TYPE` / `COMPARE_IS_NOT_TYPE` carry the type name as
a constant. The compile-time predicate is a free function because both the
Compiler and the VM need it.

### Two pre-existing divergences fixed along the way

Testing `is` exposed disagreements that had nothing to do with type tests:

- **`"1" is "1"`** was false on the interpreter and true on the VM. Comparing by
  pointer is right for instances and wrong for strings, which are immutable
  values. Equal strings now compare equal on both.
- **Function identity** — the VM compared natives structurally, so two distinct
  natives could report as the same function. Functions now compare by code
  pointer; natives never match.

### Known remaining divergences

Two edge cases still differ and are **not** covered by the test rather than
being asserted loosely:

- **`L is L` on a list** — true on the interpreter, false on the VM. The VM
  appears to copy list values on load, so the two sides of the comparison are
  different allocations. That is a VM value-semantics question deeper than the
  `is` operator and wants its own change.
- **`print is function`** — the two engines classify native builtins
  differently.

### Verification

`examples/gui_tests/test_26_is_operator.ny` — **34 assertions, identical on both
engines**: value identity, cross-type rejection, every primitive type name and
alias, `Object` as the root, class and parent-class membership, variables on the
right staying value tests, and `is not` as the exact negation of each.

- 355 examples: interpreter 1 failure, VM 2. `tests/` 0.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40. Zero regressions.

---

## Round 66 — the theme and icons reach the shipped IDE

Reported: none of the GUI work appears when running the build. That was correct,
and the reason is specific.

### The changes were real and landed in unused files

`nython_ide.ny` — the file that actually launches — imports:

```
ide_editor.ny  ide_workshop.ny  ide_icons.ny  ide_project.ny
lib/aiagent.ny  lib/gui_motion.ny  lib/nyimgui.ny
```

It does **not** import `lib/gui.ny`, where the VS Code Dark+ palette was written
in round 41. It does **not** use `lib/icons.ny` or `assets/fonts/codicon.ttf`,
where the 460 Codicons were installed. Both changes existed, were tested, and
were invisible to the product.

Round 48 found that six rounds of IDE work had gone into `examples/nython_ide.ny`
instead of the shipped file, and I corrected *which IDE file I edit*. I did not
check which **theme and icon files that IDE uses**, so the same mistake persisted
one level down for another eighteen rounds.

### Fixed in the file that ships

**Theme.** `nython_ide.ny` carries its own `Theme` class — previously a
blue-black palette with a purple accent, which is why it did not read as an
editor. Now the published Dark+ values: `#1E1E1E` editor, `#252526` panels,
`#3C3C3C` chrome, `#007ACC` accent and status bar, `#D4D4D4` foreground,
`#858585` dimmed, `#F14C4C` errors, `#264F78` selection, `#333333` activity bar.

**Icons.** `ide_icons.ny` drew every icon from renderer primitives, with a header
explaining that SDL3_image cannot rasterise SVG. That is true of SVG — but the
icon set also ships as a **font**, and SDL3_ttf is already linked and already
used for every label. So the real icons can be drawn as text: one glyph, one
draw call, taking the theme colour like any other text, at any size.

`Icons.draw()` now resolves a Codicon glyph first and falls back to the vector
shapes when the font is absent, so a stripped install degrades instead of showing
blank squares. Verified: all eleven chrome icons draw exactly one text call and
zero shape calls — including `outline` and `ai`, which had no vector case at all
and rendered as empty boxes in the screenshots.

### Two test failures caused by this change, both the test's fault

- `test_13` / `test_15` referenced `Icons()`, which now names the shipped
  vector/glyph class rather than the codicon table (renamed `Icons_Codicon` so
  both can coexist).
- `test_20` records draw calls to prove each icon is drawn. Icons are glyphs now,
  so its recorder needed `draw_text` — without it, it counted zero ops and
  reported the whole set blank. Exactly the failure mode as the missing
  `fill_polygon` in round 48: **a recording double that does not implement the
  whole surface invents failures.**

### Verification

`test_20` extended to **57 assertions**, both engines: the nine Dark+ colour
values, the codicon font being present, and each of the seven activity-rail
icons drawing a glyph.

- 355 examples: interpreter 1 failure, VM 2. `tests/` 0.
- `test_gui` 1053/1053, `test_ide_smoke` 40/40, tests 13/15/20 green.

### Still not addressed

The report also mentions buttons and menus not looking good, and missing GUI
elements. Colour and icons are now correct in the shipped file, but button and
menu *shapes* — padding, corner radius, hover and press states, shadows,
separators — are drawn by `nython_ide.ny`'s own routines and have not been
reworked. That needs a screenshot of this build to do properly: the previous
round of visual fixes came entirely from one, and guessing without it is what
produced eighteen rounds of work in the wrong file.

---

## Round 67 — the interaction bug, and centred controls

Screenshots of the new build confirmed the Dark+ theme and Codicon glyphs are
now in the shipped IDE. The remaining report — panel tabs not reacting, text not
centred in buttons — turned out to be one real bug plus two layout defects.

### Immediate-mode widgets never saw a click

The ported panel tabs and toolbar chips did nothing when clicked.

An immediate-mode widget **hit-tests during draw**; it is not sent events. So a
click is only observed if a frame is drawn *while the button is down*. The IDE's
frame loop skips redraws unless `_dirty` is set — and the handler that records
the pointer never set it. The widgets recorded the mouse position faithfully,
never redrew, and never registered a press. They looked completely dead.

Mouse events now mark the frame dirty. Demonstrated both ways in `test_22`:

```
click registers when a frame is drawn while down   -> Problems
no frame while down means no click                 -> stays on Output
```

This is the cost of mixing paradigms that round 57 did not anticipate: porting a
widget to immediate mode also imposes a requirement on the *frame loop*, and the
retained loop's repaint-skipping optimisation silently violated it.

### The Run button was hardcoded, not laid out

Every coordinate was a constant: icon at x=22, text at x=44, box at x=12 width
82. Those numbers were tuned for one font at one size, so the label sat
off-centre — and drifted further once HiDPI scaling was added, since the box
scaled and the offsets did not.

Icon and label are now measured and centred **as a unit**: the button sizes
itself to its content, and the content is placed from the middle outward, so it
stays centred at any font size or display scale. The button also gained a hover
state and a highlight gradient. The mode chips start after it rather than at a
fixed x=106, so they cannot overlap it when the label changes.

### Chips read as controls

The toolbar chips were bare text until selected — no border, no background — so
nothing indicated they were clickable. Each now carries a faint outline, hover
uses the theme's list-hover colour, and the label is centred in its own chip
rather than placed at a fixed inset, so "VM" and "Tokenize" both sit in the
middle of their buttons.

### A test that was too weak

`hover on unselected chip highlights` compared the draw-command *count*. Now that
unhovered chips draw an outline too, hovering swaps one command for another
instead of adding one, so the count check passed only by accident of the old
styling. It now compares the draw **signature**, which is what "looks different"
actually means.

### Verification

- `test_22` — 61 assertions, both engines, including the frame-while-down
  requirement in both directions.
- `test_20` — 57 assertions covering the shipped theme values and glyph
  rendering.
- 355 examples: interpreter 1 failure, VM 2. `test_gui` 1053/1053,
  `test_ide_smoke` 40/40. Zero regressions.

### Not yet addressed from the report

Menu and toolbar arrangement (the VS Code / Code::Blocks hybrid), and the
missing panels. The status-bar segments *do* have a click handler — `goto`,
`problems` and `breaks` are wired; the other three segments are decorative and
consume the click without acting, which is likely what read as unresponsive.
Making every segment either actionable or visibly inert is the next step.

---

## Round 68 — widgets from ImGui's actual source, and a command line

### Working from the source, not from memory

Fetched Dear ImGui v1.91.5 from GitHub and read the real implementations rather
than approximating them. Two algorithms were worth taking exactly.

**`SliderBehaviorT` — the usable range.** The grab has width, so the track its
*centre* can occupy is shorter than the track by exactly the grab size:

```
slider_sz      = track - 2*padding
grab_sz        = max(slider_sz / (range+1), grab_min)   clamped to slider_sz
usable_sz      = slider_sz - grab_sz
usable_pos_min = track_min + padding + grab_sz/2
```

Mapping value to the *full* track instead — the obvious implementation — makes
the handle overhang both ends and puts the maximum out of reach. The test
asserts both endpoints are reachable for that reason.

**`ScrollbarEx` — thumb and travel.** Thumb length is the visible fraction of
the content, floored so it stays grabbable in a long document; the travel is
then the bar *minus the thumb*, not the bar.

Also added `panel()` (titled, collapsible — the element the IDE had no
equivalent of) and `toolbar_sep()`, which takes Code::Blocks' grouped toolbar
banks and VS Code's spacing together, since grouped *and* spaced reads better
than either alone.

A test caught a real subtlety while writing it: a drag is press-*then*-move. A
single frame with the button down at a new position never establishes the press,
so the first scrollbar test measured 0 and the arithmetic looked wrong when it
was the test that was.

### `lib/ide_commands.ny` — one prompt, three namespaces

The terminal ran shell commands and the REPL evaluated expressions, but there
was no way to drive the IDE itself, or to reach an agent, from the keyboard.
Everything went through menus, so anything not on a menu was unreachable.

```
:cmd     IDE       :run :build :vm :tokens :ast :disasm :profile
                   :open :save :goto :find :panel :theme :clear :history
>expr    language  evaluated by the real interpreter
@agent   agents    @ask @explain @fix @test @doc @review @agents
```

The sigil decides the namespace, so nothing is ambiguous — `:run` is always the
IDE, `print(1)` is always the language, `@ask why` is always an agent. A bare
line is treated as language input, because that is what gets typed most.

Design decisions worth recording:

- **IDE and agent commands name an action rather than performing one.** The
  command line stays testable without a window, and the IDE supplies file
  context, so the parser never reaches into the editor.
- **The language namespace accumulates a session**, replaying accepted
  declarations — and a declaration joins only once it compiles, so one bad line
  cannot poison every later command. Verified: after `var bad = (` fails,
  `n * 2` still evaluates.
- **Tab completion works in all three namespaces**, not just for shell paths.
- Consecutive duplicate history entries are dropped, which is what makes
  arrowing back through history usable.

### Verification

`examples/gui_tests/test_27_widgets_cmdline.ny` — **36 assertions, identical on
both engines**: slider endpoints and clamping in both directions, scrollbar
travel with a proper press-then-drag, the degenerate case where content fits the
viewport, panel collapse/expand and a body click *not* toggling it, all three
command namespaces, alias resolution, session persistence, recovery after a
failed declaration, history and completion.

- 356 examples: interpreter 1 failure, VM 2. `test_gui` 1053/1053,
  `test_ide_smoke` 40/40. Zero regressions.

### Not yet wired into the shipped IDE

The widgets and the command line are built and tested but `nython_ide.ny` does
not use them yet — the same "built, not adopted" state `Flex` and the piece
table were in. Wiring the command line into the terminal panel and the panel
widget into the bottom dock is the next step, and should be its own change so a
regression is attributable.

---

## Round 69 — documentation for handing this over

No code changes. The project documentation described the design, not the state,
after 34 rounds of work — so a new session would have started from a picture
that was wrong in several expensive ways.

### `HANDOFF.md` (new) — read this first

- **Current state**: 356 examples (interpreter 1 failure, VM 2), `tests/` 0,
  `test_gui` 1053/1053, and what the remaining failures actually are.
- **Build in this environment**: no SDL3 exists here; the headless stub, the
  `NY_STUB_AUTOQUIT` / `NY_STUB_DPI_SCALE` variables, and the fact that an
  interrupted build fails to link with a misleading `undefined reference to
  main` when the real cause is a missing object file.
- **How to verify a change**: compare output not exit codes; compare divergence
  *sets* not counts; change both engines in the same commit; when a new test
  fails against old code, suspect the test.
- **Traps**, each of which has already cost real time: two IDE files with only
  one shipped; the shipped IDE not importing `lib/gui.ny`; three separate places
  where a fix landed in **dead code that looks live**; and grepping for names
  rather than behaviour, which twice declared a working feature missing.
- **Outstanding work in priority order**, with the reasoning for each.
- **What every test file pins**, so a failure points at a subject.

### `CLAUDE.md` updated

It still described `nython_ide.ny` as 2,110 lines and listed C-style modulo and
32-bit overflow as current limitations — both fixed rounds ago. Now carries a
pointer to `HANDOFF.md`, the real repository layout including which files the
shipped IDE actually imports, the development-environment section, a table of
language features added since (ranges, `is`, `import as`, located errors,
`NameError`, the object protocol, `--profile`), and a corrected limitations list.

### Every claim was executed, not assumed

Each instruction in the handoff was run. That found one overstatement: located
diagnostics work mid-file —

```
/tmp/err2.ny:3:2: syntax error: Expected ParenClose, but found Var
  var y = 2
   ^
```

— but an error at **end of input** falls back to `stdin:1:1`, because the End
token carries no position. Documented as §5.6 with the fix (give the EOF token
the last position the lexer saw) rather than left as an overclaim.

Also cross-checked that every file the handoff references exists.

### Documentation set

| File | Purpose |
|---|---|
| `HANDOFF.md` | resuming work — state, environment, traps, priorities |
| `CLAUDE.md` | project overview and architecture |
| `FIXES_v0.2.1.md` | round-by-round log: every bug and why |
| `GC_NOTES.md` | container leak: diagnosis and three routes |
| `MEMORY_NOTES.md` | writing Nython the runtime can afford |
| `IDE_FILES.md` | which IDE file is real |
| `tests/ide/README_HEADLESS.md` | running GUI tests without a display |

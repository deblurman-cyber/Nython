# HANDOFF.md — resuming this work in a new session

Read this first. `CLAUDE.md` describes the project as it was designed;
this file describes it **as it actually is**, including the traps.

Last updated: end of round 70 (see §0 for what changed).

---

## 0. Round 70 — a fresh container, no stub, and a real content-level sweep

This round started from a **container with no SDL3 and no stub** — the stub
built in round-68-era sessions lived under `/home/claude/work/stub/`, outside
the repo, and was gone. Nothing built until one was written from scratch; see
`thirdparty/sdl3-stub/` and the updated `Makefile` (`NYTHON_SDL_STUB=1|0|auto`,
auto-detects and falls back to the stub when no real SDL3 is found). The stub
mirrors the interface `src/builtins/gui.cpp` actually calls, headless, with the
same `NY_STUB_AUTOQUIT` / `NY_STUB_DPI_SCALE` contract this file already
documented. `make cli` and `make` both need nothing else in a clean container.

With a working build, this round also did what §3 always recommended and
earlier rounds mostly didn't: ran every `examples/*.ny`, `examples/gui_tests/*.ny`
and `tests/*.ny` file on **both engines** and grepped the *output*, not just the
exit code, for `N failed` (a file can print "3 failed" and still exit 0 if its
own `check()` helper doesn't call `exit`). That surfaced real bugs the
exit-code-only sweep had never seen, alongside a large pile of **pre-existing**
content-level failures in old version-numbered example files (`v3_..v16_*`,
`arith_test`, `oop_test`, `stdlib_test`, `enhance_test`, `ultimate_test`, …)
that were never part of any documented pass-count claim — those are catalogued
in §5.8 rather than fixed, since chasing ~50 undocumented pre-existing
assertions is its own dedicated project.

Fixed, both engines unless noted (see git log for the individual commits):
- **EOF errors losing their location (§5.6, closed)**: `Lexer::next()`/`curr()`
  returned a bare `Token()` — default `Location{1,1,"stdin"}` — once the parser
  read past the last real token. Now they return the last valid token (the
  lexer's own `End` token, which already carried the right position).
- **`id()`/`hash()` as global functions**: registered as recognised builtin
  names but never actually dispatched anywhere — interpreter fell through
  every `dispatch_*` module to `UNDEFINED`; the VM's `id()` read only
  `a[0].list`, so anything but a `LIST` (an instance, a map, a string, a
  number…) always came back `0`. This is almost certainly what §5.2's "known
  defect: `id()` returns 0" was actually seeing — the *method* form
  `obj.id()` (objectProtocol) already worked.
- **Interpreter silently swallowing exceptions raised inside `__init__`**: the
  three call sites that invoke a class's `__init__` had `catch (...) {}` after
  the `ReturnSignal` catch, discarding *any* exception — NameError, a raised
  user exception, anything — instead of only swallowing the early-`return`
  signal every other call site treats specially. A constructor that hit a real
  error silently produced a half-built instance and kept going. This is what
  finally exposed the next two bugs, both of which were being hidden by it.
- **`examples/nython_ide.ny` (the *unshipped* v3 demo — see `IDE_FILES.md`,
  this is not the same file `--ide` launches) had three real, independent
  bugs**, previously invisible because of the swallow above:
  `Icons()` was called without importing the file that defines it
  (`../ide_icons.ny`, added); `LangWorkshopPanel` was defined ~900 lines
  *after* the class that instantiates it (moved earlier, same fix already
  applied to the shipped IDE per this file's own "IDE Launch Fix" section);
  and DPI-scaling ran on layout constants (`self.TOOLBAR_H` etc.) before their
  base values were ever assigned, reading `none` and poisoning every metric
  derived from it downstream, down to `float(none)`.
- **`json_decode`'s hand-rolled parser could crash the whole process**:
  `std::stod`/`std::stol` on a malformed numeric field were unguarded, so a
  parse failure threw an uncaught C++ exception straight past every Nython
  `try`/`except`, landing in `main.cpp`'s outermost handler as an unhelpful
  `error: stol`. Now falls back to `0` for that one field, matching the
  top-level-primitive parse a few lines above it (and matching the VM's own
  `json_decode`, which already never crashed here).
- **`EditorTab`'s `.ny` file icon was `"?"` instead of `"◈"`**: `tests/test_gui.ny`
  already asserted `"◈"`; `lib/gui.ny`'s `_ext_icon()` still set `"?"`, and the
  duplicate `examples/test_gui.ny` still asserted the stale `"?"` to match.
  `tests/test_gui.ny` was quietly at 1052/1053 because of it.
- **`import nytorch_classes` was a no-op on the VM**: the comment claiming
  "the functions are already registered as globals" was true of the native
  `tensor_*` ops but not of the Nython-level class library (`Tensor` and
  everything built on it) — `Tensor(...)` read as an undefined name. Wired it
  to actually load `lib/nytorch.ny`, the same file the interpreter's handler
  loads. The concern that blocked this before (loading 220+ classes is
  OOM-risky — see `CLAUDE.md`'s IDE-import-weight note) is specific to the
  interpreter's unreclaimed containers (§5.1); the VM's `shared_ptr`-backed
  containers don't have that problem. `examples/nytorch_v2_demo.ny` now runs
  to completion on the VM (previously: `NameError: 'Tensor' is not defined`).
- **VM compound assignment**: `aug_op()` mapped `+= -= *= /= %=` to opcodes and
  silently NOP'd everything else. `x //= 5` compiled to "load x, load 5, NOP,
  store" — the NOP left `5` on the stack to be stored, so `x` became the
  divisor, not the quotient. Added `//= **= &= |= ^= <<= >>=`.
- **VM `isinstance(x, list)`** (the bare builtin, not a string): only a
  `CLASS` or `STRING` second argument was recognised, so this always read
  `false`. The type-constructor builtins (`int`/`float`/`bool`/`str`/`list`/
  `tuple`/`dict`/`set`) are now tagged with the type name they build, and
  `isinstance` accepts that tag. This is what was silently breaking every
  `isinstance(item, list)`-based recursive flatten in the VM audits.
- **VM `case _:`**: compiled as an ordinary `subject == <value of _>`
  comparison — `_` read as an undefined variable, so the wildcard/default arm
  of a `match` never ran. The interpreter's `evalSwitch` already special-cases
  a case value of exactly `"_"`; the VM compiler now does too.
- **VM `list.min()`/`.max()`/`.sum()`** (method-call form): only the global
  `min(list)`/`max(list)`/`sum(list)` form was implemented; the method form
  fell through `call_list_method` and read `none`. Delegated to the existing
  globals.
- **VM `clamp()` vs `tensor_clip()`**: aliased to the same native, which is
  list-only (clips every element of a list). `clamp(-5, 0, 10)` — the scalar
  form the interpreter has always had — hit `tensor_clip`'s "must be a list"
  guard and returned `[]`. Split them; `clamp` is now the scalar builtin,
  `tensor_clip` keeps the list behaviour under its own name.
- **VM object protocol** (§5.2, VM half): ported `class_name`/`type_name`/
  `to_string`/`id`/`hash`/`is_a`/`instance_of`/`equals_to`/`fields` to
  `vm_call_method`, mirroring the interpreter's `objectProtocol`. This is
  exactly the interface `test_25_object_protocol.ny` probes for and used to
  skip on the VM. **Not done**: the interpreter's protocol lives in one
  function and was straightforward to mirror; nothing here touches the deeper
  gaps in §5.9 (property descriptors, typed `except`), which are a different
  and larger kind of VM/interpreter divergence.
- **Stale test**: `vm_audit25`'s "neg modulo" still asserted the pre-fix
  C-style `-7 % 3 == -1`. `CLAUDE.md` documents this was deliberately changed
  to floor-modulo (`== 2`) rounds ago; the assertion was never updated to
  match. Fixed in both the `examples/` and `tests/` copies.

Net result — every suite in `CLAUDE.md`'s 24-suite table now matches its
documented count **on both engines**, except the two items in §5.9 (both
pre-existing, both real, neither touched this round) and the one item in §5.4
that is a design decision, not a bug (`5.0` vs `5` for `10 / 2`).

---

## 1. Current state

```
356 examples    interpreter 1 failure, VM 0 failures (was: interpreter 1, VM 2)
tests/          0 failures
test_gui        1053 / 1053   (both engines; was 1052/1053, see §0)
test_ide_smoke  40 / 40
gui_tests       test_13 … test_27, all green on both engines
24-suite table  matches CLAUDE.md exactly on both engines, except §5.9
```

The one remaining interpreter failure is `examples/nytorch_v2_demo.ny`,
OOM-killed by the container leak (§5.1) — unchanged and not attempted this
round (see §5.1 for why: a mistake there is a use-after-free, not a test
failure, and needs its own ASan-verified change). The VM now runs this same
file **to completion** (§0) — it was the `nytorch_classes` no-op, not the
container leak, that was failing it before.

---

## 2. Build and test

SDL3 is **not** available in most dev containers and is not in the Ubuntu
24.04 repositories. A headless stub, committed in this repo since round 70,
stands in for it — no external setup needed:

```
thirdparty/sdl3-stub/include/    SDL3 / SDL3_ttf / SDL3_image headers (headless)
thirdparty/sdl3-stub/src/        sdl3_stub.cpp — the implementation
Makefile                         auto-detects: uses the stub unless a real
                                  SDL3 is found (sdl3-config/pkg-config or the
                                  usual header paths). Force with
                                  NYTHON_SDL_STUB=1 (stub) or =0 (real SDL3,
                                  fails loudly if not actually present).
```

```bash
make clean && make cli    # ~2-3 min, build/nython-cli (REPL by default)
make                       # ~2-3 min, build/nython (IDE by default)
cp build/nython-cli ./ny_test   # lib/ide_toolchain.ny's Toolchain looks for
                                 # ./nython, ./ny_test, ./build/nython in that
                                 # order — gui_tests/test_14 and test_16 (real
                                 # compile/run/profile via popen) need one of
                                 # these to exist, or they report a toolchain
                                 # as "unavailable" and fail for an
                                 # environment reason that has nothing to do
                                 # with the change you're testing.
```

**Header changes need a full rebuild, not an incremental one.** The Makefile
has no header-dependency tracking, so `make cli` after editing
`VirtualMachine.hpp` or `NythonExecutor.hpp` silently relinks the *old*
object files for every `.cpp` that wasn't itself touched. `rm -rf build &&
make cli` before trusting a test run against a header-only change — this cost
real time this round (a fix "worked", the object file just hadn't rebuilt).

**Interrupted builds leave a truncated object set** and fail to link with a
misleading `undefined reference to main`. Do not trust that message — check
`build/cli/` (or `build/ide/`) for missing `.o` files against `src/*.cpp
src/builtins/*.cpp` first; compile the missing ones and relink rather than
assuming a full rebuild is required.

### Stub environment variables

| Variable | Effect |
|---|---|
| `NY_STUB_AUTOQUIT=<n>` | Synthesises one `SDL_EVENT_QUIT` after *n* empty polls, so GUI/IDE event loops terminate headlessly. Use ~120 for sweeps. |
| `NY_STUB_DPI_SCALE=<f>` | Fakes a HiDPI display, for testing `gui_display_scale()`. |

The quit is **latched** — delivered once. An unlatched version made an
application's `while (SDL_PollEvent(&e))` drain loop never terminate and drove
the IDE to 3.8 GB. If you touch the stub, keep the latch.

### Sweep

Exit-code only — catches crashes and timeouts, not wrong answers:

```bash
for x in examples/*.ny examples/gui_tests/*.ny tests/*.ny; do
  NY_STUB_AUTOQUIT=150 timeout 90 ./ny_test "$x" </dev/null >/dev/null 2>&1 || echo "I $x"
  NY_STUB_AUTOQUIT=150 timeout 90 ./ny_test --vm "$x" </dev/null >/dev/null 2>&1 || echo "V $x"
done
```

**Also grep the output**, not just the exit code (§3, and see §0/§5.8 for what
this caught that the loop above didn't): most of this repo's own test files
use a `check(name, got, want)` helper that prints `"N failed"` and keeps
going rather than exiting non-zero, so a file with real failures still shows
up as a pass above.

```bash
for x in examples/*.ny examples/gui_tests/*.ny tests/*.ny; do
  out=$(NY_STUB_AUTOQUIT=150 timeout 90 ./ny_test "$x" </dev/null 2>&1)
  n=$(echo "$out" | grep -oE '[0-9]+ failed' | grep -oE '^[0-9]+' | head -1)
  [ -n "$n" ] && [ "$n" != "0" ] && echo "I $x -> $n failed"
  out=$(NY_STUB_AUTOQUIT=150 timeout 90 ./ny_test --vm "$x" </dev/null 2>&1)
  n=$(echo "$out" | grep -oE '[0-9]+ failed' | grep -oE '^[0-9]+' | head -1)
  [ -n "$n" ] && [ "$n" != "0" ] && echo "V $x -> $n failed"
done
```

---

## 3. How to verify a change (this matters more than it sounds)

**Compare output, not exit codes.** For 38 rounds the suite was measured by exit
status, which only catches crashes; a program that prints a wrong number exits 0
and passes. Most bugs found since came from diffing the two engines' stdout.

**Compare divergence *sets*, not counts.** A build of the original tree lives at
`/tmp/obuild/nython_orig` (rebuild it from `/home/claude/work/nython/src_tree`
if lost). Comparing which *files* diverge, rather than how many, is what caught a
regression that was hidden behind two simultaneous fixes.

**Change both engines in the same commit.** Adding a diagnostic or a feature to
one engine has repeatedly created a divergence — the interpreter and the VM must
agree on what is an error. This happened with `NameError`, with `ImportError`,
and with the object protocol (§5).

**When a new test fails against old code, suspect the test.** Four times a
failing assertion was the test's fault: a recording double missing
`fill_polygon`, then missing `draw_text`; a column arithmetic slip; a hover check
comparing draw *counts* when the styling changed. Check which side is wrong
before changing either.

---

## 4. Traps that have cost real time

**Two IDE files.** `nython_ide.ny` at the repository root (v4, ~3700 lines) is
what `--ide` launches. `examples/nython_ide.ny` (v3) is a demo and is **not**
shipped. Six rounds of work went into the wrong one. See `IDE_FILES.md`.

**The shipped IDE does not import `lib/gui.ny`.** It uses its own `Theme` class
and `ide_icons.ny`. A VS Code Dark+ palette written into `lib/gui.ny` was
invisible for eighteen rounds for this reason. Check what the file you are
editing actually imports:

```bash
grep -n "^import" nython_ide.ny
```

**Dead code that looks live.** Two fixes landed in code that never executes and
were reported as working:
- `src/Value.cpp` has a complete set of arithmetic operators — **dead**. The live
  path is in `NythonExecutor.hpp`.
- `evalImport` builds a candidate list named `paths` — **dead**. The resolver
  reads `search_paths`.
- The `NT::SLICE` case in the VM compiler is **dead for subscripts**; the parser
  emits `.slice(...)` method calls.

Verify a fix by running it, not by reading it.

**Grep for behaviour, not names.** Selection was declared "absent" because the
grep looked for `sel_start`/`selections`; the feature exists as
`sel_on`/`sel_row`/`sel_col`. A universal object protocol was built to fill a gap
that was partly already filled.

---

## 5. Outstanding work, in priority order

### 5.1 Container leak — the last unambiguous defect
Full diagnosis in **`GC_NOTES.md`**. Summary: identical program, 200k container
literals — interpreter 494 MB, VM 7 MB. The VM uses `shared_ptr` and is fine.
The interpreter's collector is *correct code wired to nothing*: 24 raw
`new Object(...)` sites and zero `gc->allocate()` calls; `mark_persistent()` is
never called so the shadow stack is always empty; `do_collect()` is unreachable
from `NythonExecutor`.

Three routes are given, in preference order. A mistake here is a use-after-free,
not a leak, and the 356-example suite would very likely still pass — so this
needs an ASan build and allocation counters as part of the change.

`MEMORY_NOTES.md` covers how to write Nython that avoids generating the garbage
(`append` over `x = x + [y]`: 860× faster, 2400× less memory at 4,000 elements;
operation logs over state snapshots: 373 MB → 56 MB for 400 edits).

### 5.2 Object protocol is interpreter-only — CLOSED (round 70)
`objectProtocol()` in `NythonExecutor.hpp` gives every instance `class_name`,
`to_string`, `id`, `hash`, `is_a`, `fields` and aliases. Ported the same
interface to the VM's `vm_call_method` (`class_name`/`type_name`/`to_string`/
`id`/`hash`/`is_a`/`instance_of`/`equals_to`/`fields`) — `test_25` no longer
skips on the VM. The previously-noted `id() == 0` defect turned out to be a
different bug (see §0: `id`/`hash` were never dispatched as *global*
functions on either engine — only the *method* form `obj.id()` worked, which
is what this section's `objectProtocol()` already covered).

### 5.3 Built but not adopted by the shipped IDE
Tested, working, unused by `nython_ide.ny`:

| Module | What it provides |
|---|---|
| `lib/ide_commands.ny` | `:cmd` / `>expr` / `@agent` command line |
| `lib/nyimgui.ny` | slider, scrollbar, panel, toolbar separator |
| `lib/gui_piecetable.ny` | piece-table buffer with operation-based undo |
| `lib/ide_selection.ny` | multi-cursor selection model |
| `lib/gui_motion.ny` | `Flex` solver, easing curves, `Fuzzy` matcher |

Wiring the command line into the terminal panel and the panel widget into the
bottom dock is the natural next step. Do each as its own change so a regression
is attributable.

Note: `CursorManager`, `Splitter`, `ScrollArea` and `FocusManager` in
`lib/gui.ny` are **deliberately** unused — v4 has its own working equivalents,
and replacing them would be churn with regression risk and no visible gain.

### 5.4 Remaining engine divergences
- `L is L` on a list: true on the interpreter, false on the VM. The VM appears to
  copy list values on load. Deeper than the `is` operator.
- `print is function`: the engines classify native builtins differently.
- Integer `/`: `5.0` on the interpreter, `5` on the VM. **A language-design
  decision, not a bug** — `examples/arith_test.ny` asserts the VM's answer while
  the interpreter contradicts it. Needs an owner's ruling.
- Similarly undecided: dict/set iteration order, tuples (the VM has no tuple
  type), `undefined` vs `none`, out-of-range indexing (interpreter throws, VM
  returns `none`).

### 5.5 Language gaps
- `len()` counts **characters** but `s[i]` and `s[a:b]` index **bytes**. Both
  engines agree, so it is a semantics question. Making indexing character-based
  matches what `len()` implies but changes every string slice in the codebase.
- `1.+(2, 3)` parses (operators are legal member names) but evaluates to `none` —
  integers have no `+` member. Needs primitives boxed or dispatched to a root
  type.
- PyTorch breadth: autograd, real ND tensors, GPU dispatch and most of `torch.nn`
  are absent. Names match PyTorch where the capability exists (`L1Loss`,
  `SmoothL1Loss`, `LRScheduler`, `ExponentialLR`, …).

### 5.6 End-of-input errors lose their location — CLOSED (round 70)

Located diagnostics worked mid-file but an error at **end of input** used to
fall back to `stdin:1:1`, because `Lexer::next()`/`curr()` returned a
default-constructed `Token()` once the parser read past the last real token,
discarding the position the lexer's own `End` token already carried. Fixed by
returning that `End` token (or the first token, for underflow) instead of a
positionless default. `/tmp/eof.ny` with an unclosed paren now reports
`/tmp/eof.ny:3:1: ...` — the real end-of-file position — instead of
`stdin:1:1`.

### 5.7 IDE visual work
Not addressed: menu and toolbar rearrangement (the VS Code / Code::Blocks
hybrid), and three status-bar segments (UTF-8, Nython, size) that are decorative
but consume the click, which reads as unresponsive.

**Visual work needs a screenshot.** Every attempt to fix appearance without one
produced work in the wrong file. Ask for one.

### 5.8 Content-level failures in old version-numbered example files (found, not fixed)

Round 70's content-level sweep (§0/§2) found real `N failed` output — not
crashes, not caught by any exit-code sweep — in about three dozen files:
`arith_test.ny`, `enhance_test.ny`, `features_test.ny`, `features_v2_test.ny`,
`oop_test.ny`, `oop_v2_test.ny`, `stdlib_test.ny`, `stdlib_v2_test.ny`,
`ultimate_test.ny`, `v3_comprehensive_test.ny` through `v16_final_test.ny`, and
`test_webserver.ny` (both engines; the last one is plausibly a sandboxed-socket
environment issue rather than a language bug — not investigated).

These are **not** part of any documented pass-count claim — `CLAUDE.md`'s
24-suite table and this file's own historical "N examples: M failures" figure
were always exit-code-only, and these files predate the `vm_audit*` /
`check()`-with-real-assertions convention. Whether each failure is a real
bug, an intentional-but-undocumented divergence, or a stale expectation (the
`vm_audit25` "neg modulo" case in §0 was the third kind) needs the same
per-file "reproduce, trace, decide" treatment as everything else in this
file — it just hasn't been given it yet. Left alone this round rather than
fixed blind, given the volume (~50 individual assertions across ~35 files)
and the risk of a wrong fix in a file nobody has looked at closely before.

### 5.9 Two more VM/interpreter divergences found this round, not fixed

Both are architectural gaps in how the VM compiles/dispatches, not surface
bugs — same risk class as §5.1, scoped out of this round for the same reason
(a rushed fix here is more likely to be subtly wrong than visibly broken).

**`@property`-decorated class methods don't work on the VM.** `x = property(x)`
written as an explicit call (`self.x = property(getter)`) works — `get_attr`
checks for a `{__is_property__: ...}` map and calls `__get__`. But
`@property` as *decorator syntax* on a class method desugars at parse time to
`name = property(name)` as a synthesized assignment following the `def`
(`src/Parser.cpp`, the general decorator path) — and the VM's class compiler
(`visit_class`/`visit_func`) doesn't execute class bodies as a live sequence
of statements the way the interpreter does; it extracts `FUNCTION` nodes
straight into `sub_codes` and has no mechanism for a later statement to
retroactively mark one of them as a property. `obj.decorated_prop` returns the
raw `{__self__:..., __fn__:...}` bound-method map instead of calling it
(`vm_audit23`'s "property fahrenheit", `vm_audit25`'s "prop area"/"prop circ").
A real fix needs the compiler to recognize the `name = property(name)`
pattern immediately after a same-named method definition, at class-compile
time, and tag that `sub_codes` entry — touching class compilation and every
method-resolution path (`get_attr`, `set_attr`, `vm_call_method`).

**Typed `except` clauses don't discriminate by exception type on the VM.**
`ExceptionEntry` (`try_start, try_end, handler, alias`) carries no type
information at all, so `except ValueError as e: ...` / `except TypeError as
e: ...` / `except as e: ...` in sequence all just... whichever the VM's
handler-selection logic picks, which in practice is always the *first*
handler after the `try`, regardless of the raised exception's actual type
(`vm_audit24`'s "typed except type": raising `TypeError` is caught by the
`except ValueError` clause). Fixing this needs the compiler to record a type
per handler and the runtime dispatch to actually compare it against the
raised exception's type before choosing a handler — not attempted here.

Also observed in passing, same underlying cause as the typed-except gap:
`try`/`else` (the block that runs only if the `try` body did **not** raise)
returns `none` on the VM instead of running (`vm_audit27`'s three "try/else
*" failures) — the VM appears to have no `else`-clause handling in its
exception-table compilation at all, independent of typing.

---

## 6. Test files and what they pin

| File | Covers |
|---|---|
| `examples/vm_audit28`–`33.ny` | engine parity for language fixes |
| `gui_tests/test_13` | Codicons, Dark+ palette, HiDPI scaling |
| `gui_tests/test_14` | toolchain — real compile/run/AST/disasm |
| `gui_tests/test_15` | cursor manager, value inspector, Unicode |
| `gui_tests/test_16` | profiler — measured, not estimated |
| `gui_tests/test_17` | easing, Flex solver, piece table |
| `gui_tests/test_18` | editor buffer, operation-based undo |
| `gui_tests/test_19` | splitter, scroll area, focus ring |
| `gui_tests/test_20` | shipped IDE theme + glyph rendering |
| `gui_tests/test_21` | selection model, fuzzy matching |
| `gui_tests/test_22` | immediate-mode core, ported tabs and chips |
| `gui_tests/test_23` | shipped editor selection (code lifted verbatim) |
| `gui_tests/test_24` | import system, all three forms |
| `gui_tests/test_25` | object protocol (skips on VM) |
| `gui_tests/test_26` | `is` / `is not` |
| `gui_tests/test_27` | ImGui widgets, IDE command line |

`FIXES_v0.2.1.md` is the full round-by-round log — every bug, why it happened,
and what was decided. It is long, but it is the record of *why* things are the
way they are.

---

## 7. Working agreement that produced the best results

1. Reproduce the defect first, minimally.
2. Trace it to a cause in the source before changing anything.
3. Fix both engines together.
4. Write a test that would have caught it — asserting **values**, not just
   termination.
5. Run the full sweep and compare divergence sets against the baseline.
6. Say plainly what was *not* done. A green suite that hides an unadopted module
   or a one-engine feature is worse than an honest gap.

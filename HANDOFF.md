# HANDOFF.md — resuming this work in a new session

Read this first. `CLAUDE.md` describes the project as it was designed;
this file describes it **as it actually is**, including the traps.

Last updated: end of round 68.

---

## 1. Current state

```
356 examples    interpreter 1 failure, VM 2
tests/          0 failures
test_gui        1053 / 1053
test_ide_smoke  40 / 40
gui_tests       test_13 … test_27, all green on both engines
```

The single interpreter failure is `examples/nytorch_v2_demo.ny`, OOM-killed at
3.85 GB by the container leak (§5). Every name it references now exists — the
failure is memory, not a missing class. The VM's extra failure is
`nython_ide.ny` timing out at 60–90 s while the suite runs in parallel; it exits
0 when run alone with a longer timeout.

---

## 2. Build and test

SDL3 is **not** available in the dev container and is not in the Ubuntu 24.04
repositories. A headless stub stands in for it.

```
/home/claude/work/stub/          SDL3 / SDL3_ttf / SDL3_image stub (111 symbols)
/home/claude/work/ny/            the project
/tmp/vbuild.sh                   build script -> /tmp/vbuild/nython
```

Build takes about five minutes. Rebuild from clean after any header change:

```bash
rm -rf /tmp/vbuild && /tmp/vbuild.sh          # ~5 min
cp /tmp/vbuild/nython ./ny_test
```

**Interrupted builds leave a truncated object set** and fail to link with a
misleading `undefined reference to main`. Do not trust that message — check for
missing objects first:

```bash
for f in src/*.cpp src/builtins/*.cpp ../stub/sdl3_stub.cpp; do
  o=/tmp/vbuild/$(echo "$f" | tr '/' '_' | sed 's/\.\.//; s/\.cpp$/.o/')
  [ -f "$o" ] || echo "MISSING $f"
done
```

Compile the missing ones and relink; a full rebuild is rarely needed.

### Stub environment variables

| Variable | Effect |
|---|---|
| `NY_STUB_AUTOQUIT=<n>` | Synthesises one `SDL_EVENT_QUIT` after *n* empty polls, so GUI/IDE event loops terminate headlessly. Use ~120 for sweeps. |
| `NY_STUB_DPI_SCALE=<f>` | Fakes a HiDPI display, for testing `gui_display_scale()`. |

The quit is **latched** — delivered once. An unlatched version made an
application's `while (SDL_PollEvent(&e))` drain loop never terminate and drove
the IDE to 3.8 GB. If you touch the stub, keep the latch.

### Sweep

```bash
for x in examples/*.ny examples/gui_tests/*.ny; do
  NY_STUB_AUTOQUIT=120 timeout 90 ./ny_test "$x" </dev/null >/dev/null 2>&1 || echo "I $x"
  NY_STUB_AUTOQUIT=120 timeout 90 ./ny_test --vm "$x" </dev/null >/dev/null 2>&1 || echo "V $x"
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

### 5.2 Object protocol is interpreter-only
`objectProtocol()` in `NythonExecutor.hpp` gives every instance `class_name`,
`to_string`, `id`, `hash`, `is_a`, `fields` and aliases. **The VM has no
equivalent.** `test_25` probes for support and skips there — the skip marks the
gap, it does not hide it. Porting it is the fix.

Known defect while you are there: `id()` returns 0. The pointer is reduced to a
positive range and still arrives as zero, so the bigint boxing is not doing what
the arithmetic suggests.

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

### 5.6 End-of-input errors lose their location

Located diagnostics work mid-file:

```
/tmp/err2.ny:3:2: syntax error: Expected ParenClose, but found Var
  var y = 2
   ^
```

but an error at **end of input** falls back to the default Location:

```
stdin:1:1: syntax error: Expected ParenClose, but found End
```

The End token carries no position, so the report has nothing to use. The fix is
to give the EOF token the last real position the lexer saw, so an unterminated
construct points at where it started rather than at nothing. Small, contained,
and worth doing — an unclosed paren at the end of a file is a common mistake and
currently gets the least useful message.

### 5.7 IDE visual work
Not addressed: menu and toolbar rearrangement (the VS Code / Code::Blocks
hybrid), and three status-bar segments (UTF-8, Nython, size) that are decorative
but consume the click, which reads as unresponsive.

**Visual work needs a screenshot.** Every attempt to fix appearance without one
produced work in the wrong file. Ask for one.

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

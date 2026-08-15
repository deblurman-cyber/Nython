# HANDOFF.md — resuming this work in a new session

Read this first. `CLAUDE.md` describes the project as it was designed;
this file describes it **as it actually is**, including the traps.

Last updated: end of round 72 (see §0/§0b for the language-level work,
§5.3 for the IDE terminal command line, operation-based undo, and
multi-cursor editing wired in across rounds 71b/71c, §0c for nytorch's new
autograd engine and the VM closure bug it surfaced).

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
- **VM object protocol** (§5.2, closed): ported `class_name`/`type_name`/
  `to_string`/`id`/`hash`/`is_a`/`instance_of`/`equals_to`/`fields` to
  `vm_call_method`, mirroring the interpreter's `objectProtocol`. This is
  exactly the interface `test_25_object_protocol.ny` probes for and used to
  skip on the VM.
- **VM typed `except` and `try`/`else`** (§5.9, closed): `ExceptionEntry` held
  one handler total, so only the *first* `except` clause's body was even
  compiled — every clause after it was dead code, and which one ran had
  nothing to do with the raised exception's type. Rewrote it to hold one
  `{type_name, bind_var, handler}` per clause plus an `else_handler`, with a
  new `match_except_handler()` doing the type walk at runtime (mirroring the
  interpreter's `evalTry`). `vm_audit24` now passes 49/49. See §5.9 for the
  two further bugs this closure surfaced — `int()` never raising and a
  genuine infinite loop it exposed in `with`'s exception handling — both also
  fixed, and why that combination is worth reading if you're touching VM
  exception handling again.
- **Stale test**: `vm_audit25`'s "neg modulo" still asserted the pre-fix
  C-style `-7 % 3 == -1`. `CLAUDE.md` documents this was deliberately changed
  to floor-modulo (`== 2`) rounds ago; the assertion was never updated to
  match. Fixed in both the `examples/` and `tests/` copies.

Net result — every suite in `CLAUDE.md`'s 24-suite table now matches its
documented count **on both engines**, except one item in §5.9 (`@property`
decorator syntax on the VM — pre-existing, real, not touched) and one item in
§5.4 that is a design decision, not a bug (`5.0` vs `5` for `10 / 2`).

---

## 0b. Round 71 — division ruling, dead operators wired up, new language constructs

This round had an explicit product decision from the project owner, resolving
the design question §5.4 had been carrying open since round 70: **`/` is
always true division** (returns float — `10 / 2 == 5.0`, matching Python);
**`//` and `\` are floor division** (return int — `10 // 2 == 10 \ 2 == 5`).
The VM's `op_div()` used to special-case exact int/int division and return an
int for `/`, contradicting the interpreter and this ruling — fixed to always
return float for `/`. `examples/arith_test.ny`'s stale assertions were
updated to match.

The rest of the round worked through operators and keywords that exist as
real tokens (`IToken.hpp`) and are documented in `CLAUDE.md`'s grammar notes
but were dead at the parser, the compiler, or both — "there are many
operators to use that are not even used." Fixed, both engines, verified with
`examples/vm_audit35.ny` (new — diffs interpreter vs VM output line for
line) plus the full exit-code and content-level sweeps:

- **`\` (RevDiv) was completely unreachable**: the lexer's backslash
  handling had inverted logic that only ever produced escape/line-
  continuation tokens, never a `RevDiv` token, regardless of context.
  Restructured to check for line-continuation (backslash immediately before
  a newline) first, and emit `RevDiv` otherwise.
- **`instanceof`**: unimplemented on the interpreter (silently evaluated to
  `none`), and a stack-leaking NOP on the VM (left both operands on the
  stack, corrupting everything compiled after it). Now a true alias for
  `is` on both engines, including the VM's compile-time type-name special
  case (`COMPARE_IS_TYPE`) that `is` already had — needed separately, since
  aliasing the runtime opcode alone wasn't enough for `x instanceof SomeType`
  to resolve `SomeType` as a type name rather than a value comparison.
- **`===` / `!==` (strict equality) and `xor` / `^^`**: same stack-
  corrupting NOP pattern on the VM. Added dedicated `COMPARE_SEQ` /
  `COMPARE_SNE` / `LOGICAL_XOR` opcodes; the interpreter already handled
  these correctly.
- **`>>>=`**: silently degraded to a plain assignment (`x >>>= 2` set `x` to
  `2`) on both engines. Now treated as equivalent to `>>=` — Nython's
  integers are arbitrary-width, so there is no fixed-width sign bit to make
  "unsigned" vs "arithmetic" shift meaningfully different; documented as a
  judgment call, not a distinct semantic.
- **`~=`**: not parseable at all (`isAugAssign()` didn't recognise
  `ComplementAssign`). Added, and implemented as `x = ~y` (bitwise-complement
  the right-hand value and assign — the left operand's old value plays no
  part, matching the "complement in place" reading of every other
  `~`-family use in the language). The VM needed a dedicated compile path
  since it doesn't fit the generic load/binary-op/store pattern every other
  compound assignment uses.
- **VM postfix `++` / `--`**: compiled to a no-op (`UNARY_POS`), so `i++`
  parsed but did nothing. Now emits a load/dup/add-or-subtract-1/store
  sequence matching the interpreter's post-increment semantics (evaluates
  to the *old* value, writes back the new one).
- **`enum` / `namespace` / `interface`**: the VM compiler silently dropped
  these entire subtrees — unmatched `visit()` cases fell to a `default:`
  that emitted nothing. All three now compile for real (enum → a map of
  member name to ordinal-or-explicit-value; namespace → a map of the
  block's top-level declarations, bound under the namespace's own name;
  interface → compiled identically to a class, so `implements`/`is` see it
  as a real type in the inheritance chain). Confirmed `package` is
  correctly a no-op on both engines already (matches `PackageNode::eval()`
  on the interpreter — nothing to fix there).
- **Interpreter `namespace` never bound its own name**: `ns.member` always
  read `none ` because `evalNamespace()` evaluated the body and threw the
  result away. Now builds a member map from the namespace's top-level
  var/function/class declarations and binds it under the namespace's name,
  same shape as the VM's new namespace compilation above.
- **Interpreter `interface` was an explicit no-op**: `case
  NodeType::INTERFACE: return NONE_VALUE;` bypassed `InterfaceNode`'s own
  (already-working) `eval()` entirely. Routed through a new
  `evalInterfaceDecl()`, registered exactly like a class, so `implements`
  plus `is`/`isinstance` chain-walking actually sees interface types.
- **`new` had no parser production**: `new A()` and `new A` both silently
  discarded the `new` token and whatever followed enough to keep parsing,
  with no distinct behaviour from bare `A()`/`A`. Added a dedicated rule in
  `unary()` that gives all four forms their own, distinct meaning: `A` is
  the class value itself; `A()` calls it with no `new`; `new A()` and
  `new A` both construct an instance (with and without explicit empty
  parens) — `new` and bare-call construction are equivalent for a
  zero-arg constructor, which is the existing convention every other
  callable in the language already follows.
- **`struct` was entirely missing** (no token, no grammar). Added as a new
  keyword that desugars at *parse time*: `struct Point: x, y=0` becomes a
  synthesized `class Point: def __init__(self, x, y=0): self.x=x; self.y=y`
  — no new evaluation code needed on either engine, since it reuses the
  existing class machinery entirely. The first implementation used a plain
  `VariableNode` for the generated body's `self` reference and passed on
  the interpreter but silently read `none` for every field on the VM —
  traced via `--disasm` to the VM compiling `self.x` through a distinct
  `SelfNode` → `LOAD_SELF` opcode, which a same-named ordinary variable
  node doesn't get (the VM has no bound local literally named `"self"` to
  fall back to). Fixed by generating a real `SelfNode`, not a
  `VariableNode`, for the synthesized body.
- **`module` was entirely missing**. Added as a pure lexer-level alias for
  `namespace` (same `TokenType::NameSpace`, a second literal spelling) —
  confirmed via grep that no existing file in the corpus uses `module` as a
  bare identifier, so there is no collision risk.
- **Hex/octal/binary integer literals evaluated to `0` on the VM**
  (`0xFF`, `0o17`, `0b1010`) — found incidentally while investigating sweep
  counts, not part of the operator/keyword work above, but the same class
  of "dead code path" bug. `NT::INTEGER` compilation called
  `std::stoll(token.value)` directly, which stops parsing at the `x`/`o`/`b`
  and returns `0` for the digits-only prefix. Added `parse_int_literal()`,
  mirroring the interpreter's existing correct prefix-detection logic, used
  at both `NT::INTEGER` compile sites (the literal itself, and default-value
  folding).

Net result: the design-decision half of §5.4 is now closed (see below); the
"many operators … not even used" and "interface, enum, struct, module,
namespace … packages" requests are substantially done — the remaining gap is
multiple inheritance / multiple `implements` beyond `bases[0]`, not tracked
by either engine, and `block:` not opening its own scope (still open, not
addressed this round).

---

## 0c. Round 72 — nytorch gets real autograd, and a genuine VM closure bug

`lib/nytorch/autograd.ny` is new: a `Variable` wrapper implementing actual
reverse-mode automatic differentiation — a dynamic computation graph built
as operations run, and `.backward()` walking it in reverse topological
order to accumulate `d(output)/d(x)` into `x.grad`. This is the mechanism
the word "autograd" in "PyTorch breadth: autograd... absent" (§5.5) refers
to, and nothing in nytorch's ~15,000 existing lines had it — every
optimizer in `optimizers.ny` (`AdamW`, `AdaGrad`, `RMSProp`, `NAdam`,
`Lion`) takes `grads` as an argument the *caller* must already have worked
out by hand. Scoped deliberately to scalars and 1D tensors (the same flat
representation `Tensor` in `activations.ny` already uses — real ND tensor
support doesn't exist, per §5.5, and this doesn't add it). `LinearVar` +
`mse_loss` + `SGDVar` are included as a minimal real layer/loss/optimizer
triple. Verified by `examples/vm_audit38.ny`: hand-derived gradients for
every op, a shared-Variable-used-twice case, vector dot/sum/mean, numerical
gradient checking via finite differences against a composed expression
(the strongest available check — a wrong derivative rule trains silently
in the wrong direction rather than crashing), and an end-to-end 50-step SGD
run whose loss collapses to exactly `0.0` on both engines.

Building it surfaced a real, previously-unknown **VM bug**: `vm_call_method`'s
path for "a callable stored in an instance attribute... then `self.cb(a,
b)`" — exactly the shape every `Variable` op uses (`out._backward_fn = _bw`,
called later as `node._backward_fn()`) — called `exec_code(held.code, args,
obj)` without passing `held.closure_env`, unlike every other call path in
the same file. A closure stored as an attribute and invoked via `obj.attr()`
therefore silently lost every variable it had captured (they read back as
`none`), while the *same* closure called through a plain local reference
(`f = obj.attr; f()`) worked correctly — confirmed with a minimal repro
before trusting the fix. The interpreter never had this bug. Fixed in
`VirtualMachine.hpp` by threading `held.closure_env` through.

Also found and fixed, same root cause, in the **already-shipped**
`activations.ny`: `Tensor.relu()`/`.sigmoid()`/`.gelu()`/`.silu()`/
`.swish()`/`.elu()`/`.softmax()` each call a bare global function of the
*same name* as the method itself (e.g. `def relu(self): return
tensor_apply(self.data, lambda v: relu(v))`). A bare call inside a method
resolves back to that method, not the builtin, on both engines — the
interpreter's own `RecursionError` message even names this exact gotcha
("check for unintended self-recursion, e.g. a method with the same name as
a builtin"). All seven methods were silently wrong (either a stack
overflow or `none` per element, depending on the call path) before this.
`Tensor.tanh()` had already dodged it by calling the builtin under its
other name, `tanh_fn`; the rest now get small differently-named helpers
(`_relu_bi`, `_sigmoid_bi`, …). `autograd.ny`'s own `exp`/`log`/`relu`/
`sigmoid` were written with the identical latent bug and fixed the same
way before being trusted. No existing test asserted the old (wrong) output
— the one file calling these methods directly, `test_nytorch3.ny`, is an
unassertive print-dump predating the `vm_audit` convention.

Verified: `rm -rf build && make cli && make`, headless `--ide` launch exits
0, full exit-code sweep (one known pre-existing failure) and full
content-level sweep (53 known pre-existing failures, all matching §5.8/
§5.9's already-documented debt — nothing new) on both engines.

**Same round, follow-up**: `LinearVar`/`mse_loss`/`SGDVar` alone only prove
the engine is *correct*, not that it can train anything a single linear
unit can't already fit. Added what a real hidden layer needs: `Variable.
select(i)` (pick one element out of a vector Variable) and its exact
inverse `stack_vars(list)` (combine independent scalar Variables into one
vector), since nytorch has no real 2D tensor to hold a weight matrix —
`LinearLayerVar(n_in, n_out)` is `n_out` independent `LinearVar` units
combined via `stack_vars` instead. `MLPVar(sizes)` stacks those with `relu`
between layers. `softmax_cross_entropy(logits, target)` is the standard
numerically-stable log-sum-exp formula built entirely from already-verified
ops (`sub`/`exp`/`sum`/`log`/`select`), not by differentiating through the
native `softmax`/`cross_entropy_loss` builtins (which return raw tensors,
no gradient at all). `AdamVar` is real bias-corrected Adam operating on
`Variable.grad` directly. `LinearVar`'s init now scales by `1/sqrt(n_in)`
(simplified Xavier/He) instead of a fixed range — a fixed-width init left a
multi-layer network badly conditioned as fan-in grew between layers,
caught when a first XOR attempt plateaued at a suspiciously round loss;
confirmed **not** a gradient bug first (numerical check: max
`|analytic − numeric|` ≈ 1e-12, i.e. machine precision, across all 12
parameters of a `[2,4,2]` network) before touching the init. `examples/
vm_audit39.ny` trains `MLPVar([2,6,2])` + `AdamVar` for 400 steps on the
XOR truth table — unsolvable by any single linear layer — collapsing loss
from 2.88 to 0.00046 and classifying all four rows correctly, byte-identical
on both engines (interpreter ~15s, VM ~28ms for the same 400 steps).

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

Round 71 (§0b) added `examples/vm_audit35.ny` and re-ran the full exit-code
and content-level sweeps afterward: still exactly the one known failure
above, nothing new.

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

**`lib/ide_commands.ny` — CLOSED (round 71b)**: the `:cmd` / `>expr` /
`@agent` terminal command line (paired with `lib/ide_toolchain.ny`'s real
compile/run bridge) is now wired into `nython_ide.ny`'s terminal panel —
`NythonIDE.__init__` constructs a `Toolchain` + `CommandLine`, and
`_term_run`/`_term_dispatch`/`_term_agent`/`_term_profile` execute the
action the command line names. `:run` `:vm` `:tokens` `:ast` `:disasm`
`:build` reuse the existing `_build_run()` pipeline; `:save` `:open <f>`
`:goto <n>` `:find <t>` `:panel <name>` `:theme` `:quit` reuse existing IDE
methods; `:profile` is new — the IDE had no way to reach the profiler at
all before this. `@explain`/`@fix` are backed by `lib/aiagent.ny`'s
pattern-based `CodeAnalyzer` (the same one "Analyse Buffer" already used);
`@ask`/`@test`/`@doc`/`@review` say plainly they are not wired to a live
model rather than fabricating output. Command history (up/down) and
tab-completion also wired. Verified: `make` builds clean, headless
`--ide` launch exits 0 (constructor succeeds), the module's own dedicated
test (`gui_tests/test_27_widgets_cmdline.ny`) still passes 36/36 on both
engines. **Not verified**: the headless SDL3 stub has no synthetic
keyboard/text-input injection, so the new terminal code paths could not be
exercised through a real keydown/textinput sequence in this environment —
only through static review and the construction smoke test above.

**`lib/gui_piecetable.ny` — CLOSED differently than planned (round 71c)**:
adopting `PieceTable` itself as `EditorBuffer`'s storage was assessed and
rejected — it is offset-addressed, `EditorBuffer` is a line-list read
directly (`buf.lines[i]`) at 13+ call sites across `nython_ide.ny`, and a
full swap would mean rewriting every one of those with no headless way to
keyboard-test the result. Instead, `EditorBuffer` (`ide_editor.ny`) learned
the same *technique* `PieceTable` demonstrates — record an inverse, pop-
apply-push between an undo and a redo stack (see `PieceTable.
_apply_inverse`) — applied to its existing line-list storage instead of a
new offset-addressed one. `insert_char`/`delete_char_back`/`insert_newline`
now record four scalars per edit instead of `nython_ide.ny` snapshotting
`buf.get_all_text()) before every keystroke (`self.undo_stack`, capped at 50
snapshots, removed); a new `push_snapshot()` covers the coarser edits that
still reach into `buf.lines` directly (comment toggle, cut/paste, move
line, find/replace-all — the last of these was not undoable at all before
this). This also made undo per-tab rather than one history shared across
every open file, fixing the old behaviour's occasional surprise of Ctrl+Z
switching tabs, and gave `_redo()` — a hardcoded `"Nothing to redo"` stub
before this — a real implementation (Ctrl+Y / Ctrl+Shift+Z, "Redo" menu
item). Verified with `examples/vm_audit36.ny` (new, 53/53 both engines —
`EditorBuffer` is a plain class and directly testable without a window).

**`lib/ide_selection.ny` — CLOSED (round 71c)**: adopted for real
multi-cursor editing, additively — the existing single-selection code
(`sel_on`/`sel_row`/`sel_col`, `_sel_begin`/`_sel_range`/`_sel_delete`,
`_draw_selection`) is untouched, since it already correctly handles
shift-arrow, click-drag, word-select and cut/copy/paste over a selection,
and `SelectionModel` has nothing better to offer there. What's new: `self.
selmodel = SelectionModel()` holds *extra* carets beyond the primary.
Alt+Click adds one; Ctrl+Alt+Down/Up add one below/above the last-added
caret (plain Alt+Up/Down already means "move this line" here, hence
requiring Ctrl too); Escape or a plain click collapses back to one caret.
Typing/Backspace/Enter apply to the primary as before, then replay onto
every extra caret (`_apply_to_extra_carets`, processed last-caret-to-first
so an earlier edit never invalidates a not-yet-processed caret's saved
position; bounds-checked against the current buffer so a caret left over
from a shorter/closed file can't index past the end and crash the IDE).
Verified with `examples/vm_audit37.ny` (new, 10/10 both engines) —
replicates the exact sort-then-apply algorithm against `EditorBuffer` +
`SelectionModel` directly, including the case where two carets share one
line (where processing order actually matters) and a backspace-at-three-
carets case. **Known limitations, not solved this round**: a multi-caret
edit is not one undo step (each caret's edit records its own entry, so one
undo only reverts the last caret processed); arrow-key navigation moves
only the primary caret, extras stay put until the next edit or click;
`nython_ide.ny`'s own new glue code could not be exercised through real
mouse/keyboard events, same headless-stub limitation noted above.

Still tested, working, and unused by `nython_ide.ny`:

| Module | What it provides | Notes |
|---|---|---|
| `lib/nyimgui.ny` | **Partially adopted.** `chips`/`tabs` are used (mode switcher, panel tabs). `slider`/`scrollbar`/`panel`/`toolbar_sep`/`checkbox`/`button`/`tree_node`/`icon_rail` are still unused — the IDE has its own hand-rolled scrollbars/sliders already working; per the note below, swapping them is not a clear win. |
| `lib/gui_motion.ny` | **Partially adopted.** `Fuzzy` is used (command palette ranking, `self.fuzzy.rank(...)`). The `Flex` solver and easing curves beyond pane-open/close animation are unused. |

Note: `CursorManager`, `Splitter`, `ScrollArea` and `FocusManager` in
`lib/gui.ny` are **deliberately** unused — v4 has its own working equivalents,
and replacing them would be churn with regression risk and no visible gain.
The same reasoning is why `nyimgui.ny`'s `slider`/`scrollbar`/`panel` were
left alone this round rather than swapped in speculatively.

### 5.4 Remaining engine divergences
- `L is L` on a list: true on the interpreter, false on the VM. The VM appears to
  copy list values on load. Deeper than the `is` operator.
- `print is function`: the engines classify native builtins differently.
- ~~Integer `/`: `5.0` on the interpreter, `5` on the VM~~ — **CLOSED (round
  71)**: owner's ruling is `/` is always true division (float,
  `10 / 2 == 5.0`), `//` and `\` are floor division (int, `10 // 2 == 10 \
  2 == 5`). VM's `op_div()` no longer special-cases exact int/int division;
  `examples/arith_test.ny` updated to match. See §0b.
- Still undecided: dict/set iteration order, tuples (the VM has no tuple
  type), `undefined` vs `none`, out-of-range indexing (interpreter throws, VM
  returns `none`).

### 5.5 Language gaps
- `len()` counts **characters** but `s[i]` and `s[a:b]` index **bytes**. Both
  engines agree, so it is a semantics question. Making indexing character-based
  matches what `len()` implies but changes every string slice in the codebase.
- `1.+(2, 3)` parses (operators are legal member names) but evaluates to `none` —
  integers have no `+` member. Needs primitives boxed or dispatched to a root
  type.
- PyTorch breadth: real ND tensors and GPU dispatch are absent, and most of
  `torch.nn` beyond activations/losses/a handful of layers is thin. Names
  match PyTorch where the capability exists (`L1Loss`, `SmoothL1Loss`,
  `LRScheduler`, `ExponentialLR`, …). ~~autograd absent~~ — **partially
  closed, round 72**: `lib/nytorch/autograd.ny`'s `Variable`/`.backward()` is
  a real reverse-mode automatic differentiation engine (dynamic graph +
  topological sort), scoped to scalars and 1D tensors — see §0c. Extending
  it to real ND tensors needs the ND tensor gap above closed first.

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

### 5.9 VM/interpreter divergences found this round

**Typed `except`, `try`/`else`, and `int()` raising — CLOSED (round 70, second pass).**
`ExceptionEntry` used to be `{try_start, try_end, handler, alias}` — one
handler total — so only the *first* `except` clause's body was even
compiled; every clause after it was dead code, and which one ran had nothing
to do with the raised exception's type (`vm_audit24`'s "typed except type":
raising `TypeError` was caught by the `except ValueError` clause). `try`/`else`
wasn't compiled at all and read `none`. Rewrote `ExceptionEntry` to hold one
`{type_name, bind_var, handler}` per clause plus an `else_handler`, and added
`match_except_handler()` to pick the right one at runtime — by type equality,
the generic `Exception`/`BaseException`/`Error` names, or a walk up the raised
type's parent chain via `class_reg_` — mirroring the interpreter's `evalTry`
(`NythonExecutor.hpp`), including its behaviour when *no* clause matches
(silently falls through to `finally` rather than re-raising). `vm_audit24` now
passes 49/49.

Fixing this exposed two more real bugs on the way to green, both worth noting
because of what they reveal about testing this codebase:
- **`int(s)` on the VM silently returned `0`** for anything `std::stoll`
  couldn't parse, instead of raising — `int("abc")` looked like a successful
  parse of `0`, not an error a `try`/`except` could catch. It also never
  supported the base argument or `0x`/`0b`/`0o` prefix auto-detection. Brought
  to parity with the interpreter's `int()` (`src/builtins/tensor.cpp`).
- **Fixing `int()` to actually raise surfaced an independent, older bug that
  was previously unreachable**: an uncaught exception raised anywhere after a
  completed `with` block, with nothing else to catch it, walked backward into
  that block's now-stale `SETUP_EXCEPT` handler instead of propagating — the
  backward scan for a `with`'s exception handler never checked whether that
  block had already exited normally via a matching `END_EXCEPT`. This re-ran
  the code after the `with` block, hit the same raise again, and **looped
  forever** (`examples/v10_final_test.ny` and `v11_complete_test.ny` hung on
  `--vm` for the first time only once `int()` started raising). Fixed by
  tracking `SETUP_EXCEPT`/`END_EXCEPT` nesting depth in the backward scan.
  This is exactly why §3's "run the full sweep before *and* after" matters: a
  fix that is locally correct (`int()` raising is right) can awaken a
  completely unrelated latent bug the moment something finally exercises the
  path it lives on. Verified with a full exit-code sweep (no hangs, no new
  crashes) and a full content-level sweep (no new `N failed` files) across
  every example/test file on both engines before committing.

**`@property`-decorated class methods still don't work on the VM.** Not
attempted — an architectural gap in a different part of the compiler, same
risk class as §5.1. `x = property(x)` written as an explicit call
(`self.x = property(getter)`) works fine — `get_attr` checks for a
`{__is_property__: ...}` map and calls `__get__`. But `@property` as
*decorator syntax* on a class method desugars at parse time to
`name = property(name)` as a synthesized assignment following the `def`
(`src/Parser.cpp`, the general decorator path) — and the VM's class compiler
(`visit_class`/`visit_func`) doesn't execute class bodies as a live sequence
of statements the way the interpreter does; it extracts `FUNCTION` nodes
straight into `sub_codes` and has no mechanism for a later statement to
retroactively mark one of them as a property. `obj.decorated_prop` returns the
raw `{__self__:..., __fn__:...}` bound-method map instead of calling it
(`vm_audit23`'s "property fahrenheit", `vm_audit25`'s "prop area"/"prop circ" —
these are now the *only* remaining failures in either file on either engine).
A real fix needs the compiler to recognize the `name = property(name)`
pattern immediately after a same-named method definition, at class-compile
time, and tag that `sub_codes` entry — touching class compilation and every
method-resolution path (`get_attr`, `set_attr`, `vm_call_method`).

---

## 6. Test files and what they pin

| File | Covers |
|---|---|
| `examples/vm_audit28`–`34.ny` | engine parity for language fixes |
| `examples/vm_audit35.ny` | division ruling, instanceof/===/!==/xor/>>>=/~=, postfix ++/--, enum/namespace/module/interface/struct/new, hex/oct/binary literals (round 71) |
| `examples/vm_audit36.ny` | `EditorBuffer` operation-based undo/redo (round 71c) |
| `examples/vm_audit37.ny` | multi-cursor typing algorithm, `EditorBuffer` + `SelectionModel` (round 71c) |
| `examples/vm_audit38.ny` | `lib/nytorch/autograd.ny` reverse-mode autodiff, hand-derived + numerical gradient checks, end-to-end SGD convergence (round 72) |
| `examples/vm_audit39.ny` | `autograd.ny` multi-output layers (`select`/`stack_vars`/`LinearLayerVar`/`MLPVar`), `softmax_cross_entropy`, `AdamVar`; MLP solves XOR (round 72) |
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

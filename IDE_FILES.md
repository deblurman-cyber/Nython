# Which IDE file is the real one

There are two IDE implementations in this tree. This note exists because the
distinction is not obvious and cost several rounds of work aimed at the wrong
file.

## `nython_ide.ny` (repository root) — THIS IS THE SHIPPED IDE

Version 4. Roughly 3,650 lines. This is what `nython --ide` launches and what
runs when the binary is started with no arguments.

`launch_ide()` in `src/main.cpp` searches, in order:

    <binary_dir>/nython_ide.ny        <-- almost always wins
    <binary_dir>/../nython_ide.ny
    <binary_dir>/../examples/nython_ide.ny
    nython_ide.ny
    examples/nython_ide.ny
    ...

Because the root copy is found first, `examples/nython_ide.ny` is effectively
never launched.

v4 has: a real build pipeline (`popen` to the actual interpreter for Run / VM /
Tokenize / AST / Disasm), workspace and project files, a menu bar with
accelerators, find/replace, go-to-line, breakpoints, a command palette,
cursor feedback, undo, and a repaint-skipping frame loop.

**Edit this file when changing the IDE.**

## `examples/nython_ide.ny` — a v3 demo, NOT shipped

Version 3.0. Around 2,400 lines. Kept as a smaller, self-contained example of
building an editor shell with `lib/gui.ny`, and exercised by the test sweep, but
it is not the product. It carries some machinery v4 does not use
(`lib/ide_toolchain.ny`, `lib/gui_piecetable.ny`, `CursorManager`, a Flex-solved
`_relayout`).

If the two ever need to merge, v4 is the base: it is ahead on every feature that
matters, and the v3 pieces worth keeping are the piece-table buffer and the Flex
layout solver.

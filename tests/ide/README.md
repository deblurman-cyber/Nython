# IDE UI tests

`ui_script.txt` is a scripted walkthrough of NythonIDE v4: menus, activity rail,
sidebar, editor tabs, bottom panel, terminal, command palette, keyboard
shortcuts, tab closing and window resizing.

It is replayed by a test build of the SDL layer that reads the script and
injects the corresponding SDL events, one per poll, while logging every draw
call (rects, lines and text runs with their strings, colours, sizes and
positions). `check_shots.py` then evaluates `expectations.py` against those
logs.

This checks what was actually painted, rather than that the code ran. Assertions
are of three kinds:

* content — a named UI state must contain, or must not contain, given strings
* region  — the same assertion limited to a rectangle, needed where a string
            legitimately appears elsewhere (a closed tab still appears in the
            status message and in the file tree)
* structure — no text overlapping other text, no text at negative coordinates

Modal overlays (dropdown menus, the command palette) are exempt from the overlap
check: they paint an opaque panel over the UI beneath, so sharing coordinates
with covered text is correct. The checker reasons about draw order, not
occlusion.

Current status: 21 UI states, all passing.

## Running

```
NY_STUB_DISPLAY=1366x768 NYTHON_EXE=<path to nython> \
NY_DRAWLOG=/tmp/draw.log NY_SCRIPT=tests/ide/ui_script.txt <nython with test SDL layer>
python3 tests/ide/check_shots.py tests/ide/expectations.py
```

`NYTHON_EXE` matters: the Build/Run checks invoke a real interpreter, and
without it they exercise the "interpreter not found" path instead.

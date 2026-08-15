# Test 27: ImGui-derived widgets, and the IDE command line.
import "lib/gui.ny"
import "lib/nyimgui.ny"
import "lib/ide_toolchain.ny"
import "lib/ide_commands.ny"

var npass = 0
var nfail = 0
def check(name, got, want):
    if got == want:
        npass = npass + 1
    else:
        nfail = nfail + 1
        print "  FAIL [" + name + "] got=" + str(got) + " want=" + str(want)
def check_true(name, c):
    check(name, c, true)

print "=== Test 27: widgets + command line ==="

class TH:
    def __init__(self):
        self.text = Color(212,212,212,255)
        self.text_dim = Color(133,133,133,255)
        self.text_faint = Color(106,106,106,255)
        self.accent = Color(0,122,204,255)
        self.accent_soft = Color(0,122,204,60)
        self.hover = Color(42,45,46,255)
        self.border = Color(59,59,59,255)
        self.panel = Color(37,37,38,255)
        self.err = Color(241,76,76,255)
        self.on_badge = Color(255,255,255,255)
        self.button = Color(60,60,60,255)
        self.button_hover = Color(80,80,80,255)
        self.button_active = Color(0,122,204,255)
var th = TH()
var ui = NyImGui()

# ── Slider ───────────────────────────────────────────────────────────────────
# Geometry from ImGui's SliderBehaviorT. The subtle part is the USABLE range:
# the grab has width, so the track its CENTRE can occupy is shorter than the
# track by exactly the grab size. Mapping to the full track makes the handle
# overhang and puts the maximum out of reach — so both ends are asserted.
def sframe(mx, down, v):
    ui.io.mouse_x = mx
    ui.io.mouse_y = 10
    ui.io.mouse_down = down
    ui.begin_frame(0, 0, 300, 40)
    var out = ui.slider("vol", v, 0, 100, th, 20, 0, 200, 20)
    ui.end_frame()
    return out

check("idle keeps value", sframe(999, false, 50), 50)
var v = 50
v = sframe(20, true, v)
check("minimum is reachable", v, 0)
v = sframe(220, true, v)
check("maximum is reachable", v, 100)
v = sframe(120, true, v)
check("midpoint", v, 50)
v = sframe(999, true, v)
check("dragging past the end clamps", v, 100)
v = sframe(0 - 500, true, v)
check("dragging before the start clamps", v, 0)

# ── Scrollbar ────────────────────────────────────────────────────────────────
# From ImGui's ScrollbarEx: thumb length is the visible fraction, travel is the
# bar minus the thumb.
def bframe(my, down, sc):
    ui.io.mouse_x = 5
    ui.io.mouse_y = my
    ui.io.mouse_down = down
    ui.begin_frame(0, 0, 20, 200)
    var out = ui.scrollbar("sb", sc, 200, 1000, th, 0, 0, 12, 200)
    ui.end_frame()
    return out

check("scroll starts at zero", bframe(999, false, 0), 0)
var sc = 0
sc = bframe(20, true, sc)          # press claims the thumb
sc = bframe(200, true, sc)
check("drag to bottom reaches max", sc, 800)
sc = bframe(0, true, sc)
check("drag to top returns to zero", sc, 0)
sc = bframe(100, true, sc)
check("drag to middle", sc, 400)
# content smaller than the viewport cannot scroll
ui.io.mouse_down = false
ui.begin_frame(0, 0, 20, 200)
check("no scroll when content fits", ui.scrollbar("s2", 0, 500, 100, th, 0, 0, 12, 200), 0)
ui.end_frame()

# ── Panel ────────────────────────────────────────────────────────────────────
var pui = NyImGui()
def pframe(mx, my, down):
    pui.io.mouse_x = mx
    pui.io.mouse_y = my
    pui.io.mouse_down = down
    pui.begin_frame(0, 0, 300, 200)
    var open = pui.panel("Output", th, 0, 0, 300, 200, none)
    pui.end_frame()
    return open

check("panel starts open", pframe(999, 999, false), true)
pframe(50, 10, true)
check("header click collapses", pframe(50, 10, false), false)
check("stays collapsed", pframe(999, 999, false), false)
pframe(50, 10, true)
check("clicking again expands", pframe(50, 10, false), true)
# a click in the body must not toggle the panel
pframe(50, 120, true)
check("body click does not toggle", pframe(50, 120, false), true)

# ── Command line ─────────────────────────────────────────────────────────────
var tc = Toolchain()
var cl = CommandLine(tc, none)

# IDE namespace
var r = cl.execute(":run", none)
check("ide command ok", r.ok, true)
check("ide command names its action", r.action, "run")
r = cl.execute(":goto 42", none)
check("argument is captured", r.arg, "42")
r = cl.execute(":r", none)
check("alias resolves", r.action, "run")
r = cl.execute(":nope", none)
check("unknown command fails", r.ok, false)

# agent namespace
r = cl.execute("@explain this file", none)
check("agent action", r.action, "agent:explain")
check("agent argument", r.arg, "this file")
r = cl.execute("@agents", none)
check_true("agent list is non-empty", len(r.lines) > 1)
r = cl.execute("@nosuch", none)
check("unknown agent fails", r.ok, false)

# language namespace — the value must be COMPUTED, not echoed
r = cl.execute("2 + 3", none)
check("expression evaluates", r.lines[0], "5")
r = cl.execute("var n = 7", none)
check("declaration accepted", r.lines[0], "defined")
r = cl.execute("n * 6", none)
check("session persists across commands", r.lines[0], "42")
r = cl.execute("> n + 1", none)
check("explicit > prefix evaluates", r.lines[0], "8")
# a broken declaration must not poison the session
r = cl.execute("var bad = (", none)
check("broken declaration rejected", r.ok, false)
r = cl.execute("n * 2", none)
check("session still usable after an error", r.lines[0], "14")

# history
check_true("history recorded", len(cl.history) > 0)
var last = cl.history_prev()
check_true("history_prev returns something", len(last) > 0)

# completion
check_true("ide completion", len(cl.complete(":r")) > 0)
check_true("agent completion", len(cl.complete("@a")) > 0)
check("no completion without a sigil", len(cl.complete("pri")), 0)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 27 PASSED ==="
else:
    print "=== TEST 27 FAILED ==="

# Test 22: the immediate-mode core (NyImGui), modelled on Dear ImGui.
import "lib/gui.ny"
import "lib/nyimgui.ny"

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

print "=== Test 22: Immediate-mode core ==="

class T:
    def __init__(self):
        self.text = Color(212,212,212,255)
        self.button = Color(60,60,60,255)
        self.button_hover = Color(80,80,80,255)
        self.button_active = Color(0,122,204,255)
        self.accent = Color(0,122,204,255)
var th = T()

# ── ID hashing: identity without objects ─────────────────────────────────────
check("hash is stable", gui_hash_id("Run"), gui_hash_id("Run"))
check_true("different labels differ", gui_hash_id("Run") != gui_hash_id("Save"))
check_true("seed changes identity", gui_hash_id("Run", 99) != gui_hash_id("Run"))
# ### keeps identity stable while the caption changes every frame
check("### gives a stable id", gui_hash_id("Frame 1###st"), gui_hash_id("Frame 999###st"))
check_true("hash is non-negative", gui_hash_id("x") >= 0)

var ui = NyImGui()
# ## hides the disambiguating suffix from display but not from the hash
check("## hides suffix", ui.visible_label("Delete##file1"), "Delete")
check("no marker shows all", ui.visible_label("Delete"), "Delete")
check_true("## suffix still disambiguates",
           gui_hash_id("Delete##a") != gui_hash_id("Delete##b"))

# ── ID stack: same label, different scope, different widget ──────────────────
ui.push_id("panelA")
var id_a = ui.get_id("Delete")
ui.pop_id()
ui.push_id("panelB")
var id_b = ui.get_id("Delete")
ui.pop_id()
check_true("same label scopes apart", id_a != id_b)
check("stack restores seed", ui.id_seed, 0)

# ── layout cursor: position is a consequence of call order ───────────────────
var lay = NyImGui()
lay.io.mouse_x = 0
lay.io.mouse_y = 0
lay.begin_frame(10, 20, 300, 200)
check("cursor starts at origin", lay.cursor_y, 20)
lay.label("one", th.text)
var after_one = lay.cursor_y
check_true("label advanced cursor", after_one > 20)
lay.label("two", th.text)
check_true("second label advanced again", lay.cursor_y > after_one)
check("x returns to origin", lay.cursor_x, 10)
lay.same_line()
var y_before = lay.cursor_y
lay.label("three", th.text)
check("same_line keeps the row", lay.cursor_y, y_before)
check_true("same_line advanced x", lay.cursor_x > 10)
lay.indent()
check("indent moves origin", lay.origin_x, 26)
lay.unindent()
check("unindent restores", lay.origin_x, 10)

# ── ButtonBehavior: the state machine that needs press AND release ───────────
var ui2 = NyImGui()
def frame(mx, my, down):
    ui2.io.mouse_x = mx
    ui2.io.mouse_y = my
    ui2.io.mouse_down = down
    ui2.begin_frame(10, 10, 300, 200)
    var r = ui2.button("Run")
    ui2.end_frame()
    return r

check("hover alone does not click", frame(30, 25, false), false)
check("press alone does not click", frame(30, 25, true), false)
check("holding does not repeat", frame(30, 25, true), false)
check("release on target clicks", frame(30, 25, false), true)

# dragging off and back must preserve the press
check("press again", frame(30, 25, true), false)
check("drag off does not click", frame(300, 300, true), false)
check_true("still held while off target", ui2.active_id != 0)
check("drag back does not click yet", frame(30, 25, true), false)
check("release after round trip clicks", frame(30, 25, false), true)

# a release somewhere else must NOT count as a click
check("press", frame(30, 25, true), false)
check("release elsewhere does not click", frame(300, 300, false), false)
check("latch released anyway", ui2.active_id, 0)

# hover tracking
frame(30, 25, false)
check_true("hot id set when hovered", ui2.hot_id != 0)
frame(300, 300, false)
check("hot id cleared when away", ui2.hot_id, 0)

# ── per-widget state without a widget object ─────────────────────────────────
var tw = NyImGui()
def tframe(mx, my, down):
    tw.io.mouse_x = mx
    tw.io.mouse_y = my
    tw.io.mouse_down = down
    tw.begin_frame(0, 0, 200, 200)
    var open = tw.tree_node("src")
    tw.end_frame()
    return open
check("tree starts closed", tframe(500, 500, false), false)
tframe(20, 5, true)
check("tree opens on click", tframe(20, 5, false), true)
check("stays open across frames", tframe(500, 500, false), true)
tframe(20, 5, true)
check("toggles closed", tframe(20, 5, false), false)

# checkbox returns its new value rather than storing one
var cb = NyImGui()
cb.io.mouse_x = 500
cb.io.mouse_y = 500
cb.io.mouse_down = false
cb.begin_frame(0, 0, 200, 200)
check("checkbox unchanged when untouched", cb.checkbox("Wrap", false, th), false)
cb.end_frame()

# ── draw list and frame skipping ─────────────────────────────────────────────
var d = NyImGui()
d.io.mouse_x = 500
d.io.mouse_y = 500
d.begin_frame(0, 0, 200, 200)
d.button("A")
d.button("B")
check("two buttons emit four commands", d.draw.count, 4)
check_true("first frame is a change", d.end_frame())
d.begin_frame(0, 0, 200, 200)
d.button("A")
d.button("B")
check("identical frame is skipped", d.end_frame(), false)
check("skip counted", d.skipped_frames, 1)
d.begin_frame(0, 0, 200, 200)
d.button("A")
d.button("C")
check_true("different content redraws", d.end_frame())


# ── the ported panel tab strip (round 57) ────────────────────────────────────
# This strip used to be three pieces that had to agree: a draw loop, a parallel
# list of hit rectangles, and a click handler 600 lines away that walked it.
# One call now lays out, draws and hit-tests.
class TH2:
    def __init__(self):
        self.text = Color(212,212,212,255)
        self.text_faint = Color(133,133,133,255)
        self.accent = Color(0,122,204,255)
        self.err = Color(241,76,76,255)
        self.on_badge = Color(255,255,255,255)
        self.button = Color(60,60,60,255)
        self.button_hover = Color(80,80,80,255)
        self.button_active = Color(0,122,204,255)
var th2 = TH2()
var tb = NyImGui()
var tlabels = ["Output", "Problems", "Terminal", "Debug", "Tokens", "Workshop"]
def tmeasure(s):
    return len(s) * 7
def tabframe(mx, my, down, active, probs):
    tb.io.mouse_x = mx
    tb.io.mouse_y = my
    tb.io.mouse_down = down
    tb.begin_frame(0, 100, 900, 32)
    var sel = tb.tabs("paneltabs", tlabels, active, [0, probs, 0, 0, 0, 0], th2, 0, 100, 32, tmeasure)
    tb.end_frame()
    return sel

check("idle keeps selection", tabframe(500, 500, false, 0, 0), 0)
var sel = 0
sel = tabframe(120, 110, true, sel, 3)
sel = tabframe(120, 110, false, sel, 3)
check("click selects second tab", sel, 1)
check("selected label", tlabels[sel], "Problems")
# a click below the strip must not change the tab
sel = tabframe(120, 500, true, sel, 3)
sel = tabframe(120, 500, false, sel, 3)
check("click outside is ignored", sel, 1)
# press on one tab, release on another: no selection change
sel = tabframe(30, 110, true, sel, 3)
sel = tabframe(300, 110, false, sel, 3)
check("press and release on different tabs", sel, 1)
# a badge adds draw commands rather than overlapping the label
tabframe(500, 500, false, 1, 0)
var without = tb.draw.count
tabframe(500, 500, false, 1, 7)
check_true("badge emits extra commands", tb.draw.count > without)


# ── ported toolbar chip row (round 58) ───────────────────────────────────────
# Was a draw loop + a parallel mode_rects list + a click handler elsewhere.
var ch = NyImGui()
var modes = ["Run", "VM", "Debug", "Tokenize", "AST", "Disasm"]
def cframe(mx, my, down, active):
    ch.io.mouse_x = mx
    ch.io.mouse_y = my
    ch.io.mouse_down = down
    ch.begin_frame(106, 8, 800, 24)
    var sel = ch.chips("modechips", modes, active, 1, th2, 106, 8, 24, tmeasure)
    ch.end_frame()
    return sel

check("chips idle keeps selection", cframe(999, 999, false, 1), 1)
var cs = 1
cs = cframe(120, 15, true, cs)
cs = cframe(120, 15, false, cs)
check("chip click selects", modes[cs], "VM")
cs = cframe(220, 15, true, cs)
cs = cframe(220, 15, false, cs)
check("another chip selects", modes[cs], "Tokenize")
# `first` skips index 0: the green Run button already is Run, and drawing both
# put two Run controls side by side. The skip must survive the port.
check("skipped chip is unreachable", cframe(0, 15, false, cs), cs)
cs = cframe(0, 15, true, cs)
check("clicking the skipped area does nothing", cframe(0, 15, false, cs), cs)
# Hover feedback the retained chips never had. Must be measured on a chip that
# is NOT selected: the selected chip already draws a pill, so hovering it adds
# nothing and the check would fail for the wrong reason.
cs = cframe(120, 15, true, cs)
cs = cframe(120, 15, false, cs)      # select VM, so Tokenize is unselected
# Compare the DRAW SIGNATURE, not the command count: every chip now carries a
# faint outline so it reads as a control, so hovering swaps one command for
# another rather than adding one. A count check passed only while unhovered
# chips drew nothing but text.
cframe(999, 999, false, cs)
var sig_cold = ch.draw.signature()
cframe(220, 15, false, cs)           # hover Tokenize, which is not selected
check_true("hover on unselected chip changes its drawing",
           ch.draw.signature() != sig_cold)
check("selection unchanged by hover", modes[cs], "VM")

# ── icon rail widget ─────────────────────────────────────────────────────────
class RI:
    def __init__(self, key):
        self.key = key
var rail_items = [RI("explorer"), RI("search"), RI("git")]
var rl = NyImGui()
var icon_calls = 0
def draw_icon(it, ix, iy, lit):
    icon_calls = icon_calls + 1
def rframe(mx, my, down, active):
    icon_calls = 0
    rl.io.mouse_x = mx
    rl.io.mouse_y = my
    rl.io.mouse_down = down
    rl.begin_frame(0, 40, 52, 300)
    var k = rl.icon_rail("rail", rail_items, active, th2, 0, 40, 52, 36, 6, draw_icon)
    rl.end_frame()
    return k

check("rail idle keeps view", rframe(999, 999, false, "explorer"), "explorer")
check("icon drawn per item", icon_calls, 3)
var rk = "explorer"
rk = rframe(25, 100, true, rk)
rk = rframe(25, 100, false, rk)
check_true("rail click changes view", rk != "explorer")
check("rail click outside keeps view", rframe(999, 999, false, rk), rk)


# ── a click needs a FRAME while the button is down (round 67) ────────────────
# Immediate-mode widgets hit-test during draw; they are not sent events. The
# IDE's loop skips redraws unless _dirty is set, and mouse events did not set
# it — so the ported panel tabs and toolbar chips recorded the pointer, never
# redrew, and never registered a click. They looked completely dead.
var dz = NyImGui()
def dzframe(mx, my, down, active):
    dz.io.mouse_x = mx
    dz.io.mouse_y = my
    dz.io.mouse_down = down
    dz.begin_frame(0, 100, 900, 32)
    var sel = dz.tabs("t", tlabels, active, none, th2, 0, 100, 32, tmeasure)
    dz.end_frame()
    return sel

# with a frame drawn while down: the click lands
var sel_ok = 0
sel_ok = dzframe(120, 110, true, sel_ok)
sel_ok = dzframe(120, 110, false, sel_ok)
check("click registers when a frame is drawn while down", sel_ok, 1)

# without one, the press is never observed and nothing happens
var sel_bad = 0
dz.io.mouse_x = 120
dz.io.mouse_y = 110
dz.io.mouse_down = true
dz.io.mouse_down = false
sel_bad = dzframe(120, 110, false, sel_bad)
check("no frame while down means no click", sel_bad, 0)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 22 PASSED ==="
else:
    print "=== TEST 22 FAILED ==="

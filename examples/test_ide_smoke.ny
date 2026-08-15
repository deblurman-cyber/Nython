# test_ide_smoke.ny — Validate IDE + GUI classes load without SDL3
import "lib/gui.ny"

var passed = 0
var failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "]"

def section(name):
    print "  " + name + " ..."

print "=== IDE SMOKE TEST ==="

# ── Window constructor (width, height, title) ────────────────────────────
section("Window constructor")
var w = Window(800, 600, "Test")
assert_eq("width", w.width, 800)
assert_eq("height", w.height, 600)
assert_eq("title", w.title, "Test")
assert_eq("x default", w.x, -1)
assert_eq("y default", w.y, -1)
assert_true("resizable", w.resizable == true)
assert_true("handle none", w._handle == none)

# ── Event with modifiers ─────────────────────────────────────────────────
section("Event modifiers")
var ev = Event("keydown")
ev.ctrl = true
ev.shift = false
ev.alt = true
assert_true("ctrl", ev.ctrl == true)
assert_true("shift", ev.shift == false)
assert_true("alt", ev.alt == true)
assert_true("consumed default", ev.consumed == false)
ev.consume()
assert_true("consumed after", ev.consumed == true)

# ── Theme ────────────────────────────────────────────────────────────────
section("Theme")
var t = Theme()
assert_true("theme bg", t.bg != none)
assert_true("theme text", t.text != none)
assert_true("theme accent", t.accent != none)

# ── Button ───────────────────────────────────────────────────────────────
section("Button")
var btn = Button(10, 20, 100, 30, "Click")
assert_eq("button label", btn.label, "Click")
assert_eq("button x", btn.rect.x, 10)

# ── TextInput ────────────────────────────────────────────────────────────
section("TextInput")
var inp = TextInput(0, 0, 200, 30, "placeholder")
assert_eq("textinput value", inp.value, "")
assert_eq("textinput placeholder", inp.placeholder, "placeholder")
var inp2 = TextInput(0, 0, 200, 30)
assert_eq("textinput no-placeholder", inp2.placeholder, "")

# ── TabBar ───────────────────────────────────────────────────────────────
section("TabBar")
var tabs = TabBar(0, 0, 400, 30)
tabs.add_tab("main.ny")
tabs.add_tab("utils.ny")
assert_eq("tab count", tabs.tab_count, 2)

# ── FileTree ─────────────────────────────────────────────────────────────
section("FileTree")
var tree = FileTree(0, 0, 200, 400)
tree.add_node("/root", "root", 0, true, "folder")
tree.add_node("/root/a.ny", "a.ny", 1, false, "file")
assert_eq("tree nodes", tree.node_count, 2)

# ── Spotlight ────────────────────────────────────────────────────────────
section("Spotlight")
var spot = Spotlight(100, 100, 400, 300)
spot.add_item("Test Command", "test-cmd")
spot.add_item("Another", "another")
assert_eq("spotlight cmds", spot.cmd_count, 2)

# ── ActivityBar ──────────────────────────────────────────────────────────
section("ActivityBar")
var ab = ActivityBar(0, 0, 52, 600)
ab.add_item("X", "Explorer", false)
ab.add_item("S", "Search", false)
assert_eq("activity items", ab.item_count, 2)

# ── AutoComplete ─────────────────────────────────────────────────────────
section("AutoComplete")
var ac = AutoComplete(0, 0, 320, 200)
assert_eq("ac width", ac.w, 320)
assert_eq("ac height", ac.h, 200)

# ── RunConfigBar ─────────────────────────────────────────────────────────
section("RunConfigBar")
var rcb = RunConfigBar(0, 0, 800, 38)
assert_eq("rcb modes", len(rcb.modes), 7)

# ── MiniMap ──────────────────────────────────────────────────────────────
section("MiniMap")
var mm = MiniMap(0, 0, 110, 400)
assert_eq("minimap w", mm.rect.w, 110)

# ── SearchPanel ──────────────────────────────────────────────────────────
section("SearchPanel")
var sp = SearchPanel(0, 0, 260, 600)
assert_eq("search query", sp.query, "")

# ── KeybindPanel ─────────────────────────────────────────────────────────
section("KeybindPanel")
var kp = KeybindPanel(0, 0, 1200, 800)
kp.add("run", "Ctrl+Enter", "Run file")
assert_eq("keybind rows", kp.row_count, 1)

# ── Renderer stub ────────────────────────────────────────────────────────
section("Renderer stub")
var r = Renderer(none)
assert_true("renderer", r.handle == none)

# ── ToastManager ─────────────────────────────────────────────────────────
section("ToastManager")
var tm = ToastManager()
tm.show("hello", "info", 3000)
assert_true("toast active", tm.count > 0)

# ── Panels ───────────────────────────────────────────────────────────────
section("Panel widgets")
var tp = TerminalPanel(0, 0, 800, 200)
assert_true("terminal", tp != none)
var dp = DiagnosticPanel(0, 0, 800, 200)
assert_true("diagnostic", dp != none)
var tv = TokenViewer(0, 0, 800, 200)
assert_true("tokenviewer", tv != none)
var av = ASTViewer(0, 0, 800, 200)
assert_true("astviewer", av != none)
var pp = ProfilerPanel(0, 0, 800, 200)
assert_true("profiler", pp != none)
var rp = REPLPanel(0, 0, 800, 200)
assert_true("repl", rp != none)
var cp = ChatPanel(0, 0, 360, 600)
assert_true("chat", cp != none)
var gp = GitPanel(0, 0, 260, 600)
assert_true("git", gp != none)

# ── Report ───────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL IDE SMOKE TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

# Test 15: pointer feedback + universal value inspector.
import "lib/gui.ny"
import "lib/icons.ny"
import "lib/ide_inspector.ny"

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

print "=== Test 15: Cursors + Inspector ==="

# ── CursorManager ────────────────────────────────────────────────────────────
var cm = CursorManager()
cm.begin()
cm.add(Rect(0, 0, 200, 100), "ibeam")
cm.add(Rect(0, 0, 200, 20), "hand")
cm.add_p(Rect(195, 0, 10, 100), "sizewe", 20)

check("default outside", cm.shape_at(900, 900), "arrow")
check("text area", cm.shape_at(100, 60), "ibeam")
check("later region wins at equal priority", cm.shape_at(100, 10), "hand")
check("higher priority wins", cm.shape_at(197, 60), "sizewe")

# a drag must keep its cursor even when the pointer leaves the splitter
cm.lock("sizens")
check("lock overrides hit-test", cm.shape_at(100, 60), "sizens")
check("lock holds off-screen", cm.shape_at(9999, 9999), "sizens")
cm.unlock()
check("unlock restores", cm.shape_at(100, 60), "ibeam")

# only real changes are pushed to SDL
cm.changes = 0
cm.apply(100, 60)
cm.apply(101, 61)
cm.apply(102, 62)
check("no redundant cursor writes", cm.changes, 1)
cm.apply(197, 60)
check("change on shape switch", cm.changes, 2)

# ── Inspector: every value type ──────────────────────────────────────────────
var ins = Inspector()
check("int type", ins.type_of(42), "int")
check("float type", ins.type_of(3.5), "float")
check("bool type", ins.type_of(true), "bool")
check("string type", ins.type_of("x"), "string")
check("list type", ins.type_of([1]), "list")
check("none type", ins.type_of(none), "none")

check_true("int has icon", len(ins.icon_for(42)) > 0)
check_true("string has icon", len(ins.icon_for("x")) > 0)
check_true("list has icon", len(ins.icon_for([1])) > 0)
check_true("map has icon", len(ins.icon_for({"a":1})) > 0)
check_true("none has icon", len(ins.icon_for(none)) > 0)

check("none summary", ins.summarize(none), "none")
check("empty list summary", ins.summarize([]), "[] (empty)")
check("string is quoted", ins.summarize("hi"), "\"hi\"")

# ── Unicode / glyphs must survive intact ─────────────────────────────────────
# len() counts characters while slicing counts bytes, so anything that rebuilds
# a string from indexed pieces corrupts non-ASCII text. These pin that the
# inspector never does.
var uni = "café — Ünïcödé ✓ 日本語"
check("char count", len(uni), 20)
check("escape leaves unicode untouched", ins.escape(uni), uni)
check("cjk length", len("日本語"), 3)
check("accent length", len("café"), 4)
check("no-op truncate is identity", ins.truncate(uni, 100), uni)
check("truncate marks elision", ins.truncate(uni, 5), "café…")
check("control chars escaped", ins.escape("a\tb"), "a\\tb")
check("newline escaped", ins.escape("a\nb"), "a\\nb")
check("plain text untouched", ins.escape("plain"), "plain")

# a codicon glyph is itself a value the inspector may be asked to show
var ic = Icons_Codicon()
var glyph = ic.get("folder")
check("glyph survives escape", ins.escape(glyph), glyph)
check_true("glyph summarizes", len(ins.summarize(glyph)) > 0)

# ── expansion ────────────────────────────────────────────────────────────────
check("scalar not expandable", ins.is_expandable(42), false)
check("empty list not expandable", ins.is_expandable([]), false)
check("list expandable", ins.is_expandable([1, 2]), true)

var rows = ins.inspect("v", [1, [2, 3]])
check("nested rows", len(rows), 5)
check("root indent", rows[0].indent, 0)
check("child indent", rows[1].indent, 1)
check("grandchild indent", rows[3].indent, 2)
check("root key", rows[0].key, "v")
check("child key", rows[1].key, "[0]")

var mrows = ins.inspect("m", {"a": 1})
check("map rows", len(mrows), 2)
check("map child key", mrows[1].key, "a")

check_true("render_line non-empty", len(ins.render_line(rows[0])) > 0)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 15 PASSED ==="
else:
    print "=== TEST 15 FAILED ==="

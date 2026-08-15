# Test 17: easing curves, flex layout solver, piece-table buffer.
import "lib/gui_motion.ny"
import "lib/gui_piecetable.ny"

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

print "=== Test 17: Motion / Layout / Buffer ==="

# ── easing: every curve must be normalised f(0)=0, f(1)=1 ────────────────────
var e = Ease()
var curves = ["linear","in_quad","out_quad","in_out_quad","in_cubic","out_cubic",
              "in_out_cubic","out_quart","out_quint","in_expo","out_expo",
              "out_back","out_elastic","out_bounce"]
for c in curves:
    check_true(c + " f(0)~0", e.apply(c, 0.0) < 0.0001)
    check_true(c + " f(1)==1", e.apply(c, 1.0) > 0.9999)

# out-curves decelerate: past halfway by the midpoint
check_true("out_cubic front-loads", e.out_cubic(0.5) > 0.5)
check_true("in_cubic back-loads", e.in_cubic(0.5) < 0.5)
check("in_out symmetric at mid", e.in_out_cubic(0.5), 0.5)
# overshoot curves are allowed to exceed 1 mid-flight
check_true("out_back overshoots", e.out_back(0.5) > 1.0)
# out of range input is clamped, not extrapolated
check("clamp below", e.apply("out_cubic", -3.0), 0.0)
check("clamp above", e.apply("out_cubic", 7.0), 1.0)
check("unknown curve degrades to linear", e.apply("no-such-curve", 0.25), 0.25)

var tw = Tween(0.0, 100.0, 200, "linear")
check("tween starts at start", tw.value(), 0.0)
tw.advance(100)
check("tween midpoint", tw.value(), 50.0)
check("tween not done", tw.done, false)
tw.advance(500)
check("tween clamps at end", tw.value(), 100.0)
check_true("tween done", tw.done)
tw.reverse()
check("reverse swaps ends", tw.value(), 100.0)

# ── flex layout ──────────────────────────────────────────────────────────────
# Reproduces the IDE's own row; the hand-computed editor width was 1178.
var row = Flex("row")
row.add("activity", 52, 0)
row.add("sidebar", 260, 0)
row.add_min("editor", 0, 1, 120)
row.add("minimap", 110, 0)
var r = row.solve(0, 38, 1600, 896)
check("fixed item width", row.get("activity").w, 52)
check("second item offset", row.get("sidebar").x, 52)
check("grower takes remainder", row.get("editor").w, 1178)
check("last item right-aligned", row.get("minimap").x, 1490)
check("cross axis stretches", row.get("editor").h, 896)

# a narrow window must respect the minimum instead of going negative
row.solve(0, 38, 420, 896)
check("min size honoured", row.get("editor").w, 120)
check_true("no negative widths", row.get("minimap").w > 0)

var col = Flex("column")
col.spacing(8).padding(10, 10, 10, 10)
col.add("head", 40, 0)
col.add("body", 0, 1)
col.add("foot", 30, 0)
col.solve(0, 0, 300, 400)
check("padding applied", col.get("head").y, 10)
check("gap applied", col.get("body").y, 58)
check("column width respects padding", col.get("head").w, 280)
check("body grows", col.get("body").h, 294)

var two = Flex("row")
two.add("a", 0, 1)
two.add("b", 0, 1)
two.solve(0, 0, 500, 100)
check("equal growers split evenly", two.get("a").w, 250)
check("second grower placed after", two.get("b").x, 250)

var j = Flex("row")
j.justify = "center"
j.add("x", 100, 0)
j.solve(0, 0, 500, 50)
check("justify centers", j.get("x").x, 200)

# ── piece table ──────────────────────────────────────────────────────────────
var pt = PieceTable("hello world")
check("initial text", pt.text(), "hello world")
check("initial length", pt.length(), 11)
check("single initial piece", pt.piece_count, 1)

pt.insert(5, ",")
check("insert mid", pt.text(), "hello, world")
pt.insert(pt.length(), "!")
check("append", pt.text(), "hello, world!")
pt.delete(0, 1)
check("delete head", pt.text(), "ello, world!")
check("substr", pt.substr(0, 4), "ello")
check("substr mid", pt.substr(5, 5), " worl")
check("length tracks edits", pt.length(), 12)

# original buffer is never mutated - that is the whole point
check("original untouched", pt.original, "hello world")

# undo/redo walks the history
check_true("can undo", pt.can_undo())
pt.undo()
check("undo one step", pt.text(), "hello, world!")
pt.undo()
check("undo two steps", pt.text(), "hello, world")
pt.redo()
check("redo", pt.text(), "hello, world!")
var deep = PieceTable("x")
check("fresh buffer cannot undo", deep.can_undo(), false)
check("undo on empty history is false", deep.undo(), false)

# line mapping
var m = PieceTable("a\nb\nc")
check("line count", m.line_count(), 3)
check("lines split", len(m.lines()), 3)
check("line_start(0)", m.line_start(0), 0)
check("line_start(1)", m.line_start(1), 2)
check("offset_of", m.offset_of(2, 0), 4)

# replace is one undo step, not two
var rp = PieceTable("abcdef")
rp.replace(0, 3, "XY")
check("replace result", rp.text(), "XYdef")
rp.undo()
check("replace undoes in one step", rp.text(), "abcdef")

# compaction shortens the piece list without changing the document
var cp = PieceTable("")
cp.insert(0, "a")
cp.insert(1, "b")
cp.insert(2, "c")
var before = cp.text()
var saved = cp.compact()
check("compact preserves text", cp.text(), before)
check_true("compact reduced pieces", saved >= 0)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 17 PASSED ==="
else:
    print "=== TEST 17 FAILED ==="

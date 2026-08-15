# Test 21: editor selection / multi-cursor model, and fuzzy command matching.
import "lib/ide_selection.ny"
import "lib/gui_motion.ny"

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

print "=== Test 21: Selection + Fuzzy ==="

class B:
    def __init__(self, lines):
        self.lines = lines
        self.line_count = len(lines)
    def get_line(self, i):
        if i >= 0 and i < self.line_count:
            return self.lines[i]
        return ""

var buf = B(["hello world", "second line", "third"])
var m = SelectionModel()

# ── basic extent ─────────────────────────────────────────────────────────────
m.set_single(0, 0)
check("starts empty", m.primary().is_empty(), true)
check("no selection", m.has_selection(), false)
m.move_all(0, 5, true, buf)
check("shift-right extends", m.primary().is_empty(), false)
check("selected text", m.text_of(m.primary(), buf), "hello")
check("row span", str(m.primary().row_span(0, 11)), "[0, 5]")
check("single line", m.primary().spans_lines(), false)

# ── dragging backwards must give the same range as forwards ──────────────────
var back = SelectionModel()
back.set_single(0, 5)
back.move_all(0, 0 - 5, true, buf)
check("backward drag same text", back.text_of(back.primary(), buf), "hello")
check("start normalised", back.primary().start().col, 0)
check("end normalised", back.primary().end().col, 5)

# ── across lines ─────────────────────────────────────────────────────────────
m.move_all(1, 0, true, buf)
check("spans lines", m.primary().spans_lines(), true)
check("line count", m.primary().line_count(), 2)
# a crossing selection highlights to end of the first line, not to a caret column
check("first row to line end", str(m.primary().row_span(0, 11)), "[0, 11]")
check("last row from zero", str(m.primary().row_span(1, 11)), "[0, 5]")
check("row outside is none", m.primary().row_span(2, 5), none)
check("multiline text", m.text_of(m.primary(), buf), "hello world\nsecon")

# ── collapsing ───────────────────────────────────────────────────────────────
var c = SelectionModel()
c.set_single(0, 2)
c.move_all(0, 4, true, buf)
check("has selection before collapse", c.has_selection(), true)
# unmodified Left with a selection goes to its START, it does not move the caret
c.move_all(0, 0 - 1, false, buf)
check("collapses to start", c.primary().caret.col, 2)
check("collapsed empty", c.primary().is_empty(), true)

# ── word / line / all ────────────────────────────────────────────────────────
m.select_word(0, 7, buf)
check("word select", m.text_of(m.primary(), buf), "world")
m.select_word(0, 2, buf)
check("word at other offset", m.text_of(m.primary(), buf), "hello")
m.select_line(1, buf)
check("line select", m.text_of(m.primary(), buf), "second line")
m.select_all(buf)
check("select all", m.text_of(m.primary(), buf), "hello world\nsecond line\nthird")

# ── caret movement edges ─────────────────────────────────────────────────────
var e = SelectionModel()
e.set_single(0, 0)
e.move_all(0, 0 - 1, false, buf)
check("left at origin stays", e.primary().caret.col, 0)
e.set_single(0, 11)
e.move_all(0, 1, false, buf)
check("right at line end wraps down", e.primary().caret.row, 1)
check("wraps to column 0", e.primary().caret.col, 0)
e.move_all(0, 0 - 1, false, buf)
check("left at line start wraps up", e.primary().caret.row, 0)
check("wraps to line end", e.primary().caret.col, 11)

# vertical movement remembers the desired column across a short line
var v = SelectionModel()
v.set_single(0, 9)
v.move_all(1, 0, false, buf)
check("down keeps column", v.primary().caret.col, 9)
v.move_all(1, 0, false, buf)
check("clamped on short line", v.primary().caret.col, 5)
v.move_all(0 - 1, 0, false, buf)
check("restores desired column", v.primary().caret.col, 9)

var last = SelectionModel()
last.set_single(2, 0)
last.move_all(1, 0, false, buf)
check("down at last line stays", last.primary().caret.row, 2)

# ── multi-cursor ─────────────────────────────────────────────────────────────
var mc = SelectionModel()
mc.set_single(0, 0)
check_true("adds caret", mc.add_caret(1, 2))
check("two carets", mc.count, 2)
# stacking two carets on one spot would consume a keystroke twice
check("duplicate caret refused", mc.add_caret(1, 2), false)
check("still two", mc.count, 2)
mc.move_all(0, 1, false, buf)
check("all carets moved", mc.sels[0].caret.col, 1)
check("second caret moved too", mc.sels[1].caret.col, 3)
mc.clear_secondary()
check("secondary cleared", mc.count, 1)

# ── fuzzy ────────────────────────────────────────────────────────────────────
var f = Fuzzy()
var cmds = ["Go to Line", "Open Project", "Open Folder", "Run", "Run on VM",
            "Toggle Comment", "Save File", "Find in Files"]
check("initials match", f.rank("gtl", cmds)[0][0], "Go to Line")
check("acronym match", f.rank("oprj", cmds)[0][0], "Open Project")
check("shorter wins on tie", f.rank("run", cmds)[0][0], "Run")
check("two-letter acronym", f.rank("tc", cmds)[0][0], "Toggle Comment")
check("no match is empty", len(f.rank("zzzz", cmds)), 0)
check("empty query matches all", f.match("", "anything")[0], true)
check_true("case insensitive", f.match("GTL", "Go to Line")[0])
# positions are returned so the UI can bold what matched
var mres = f.match("gtl", "Go to Line")
check("match positions count", len(mres[2]), 3)
check("first position", mres[2][0], 0)
check("longer than haystack fails", f.match("abcdefghij", "abc")[0], false)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 21 PASSED ==="
else:
    print "=== TEST 21 FAILED ==="

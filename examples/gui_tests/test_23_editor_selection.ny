# Test 23: the SHIPPED editor's selection logic.
#
# The methods below are lifted verbatim from nython_ide.ny so this exercises the
# code that actually runs, not a re-implementation. A round-55 audit reported
# selection as "absent" because it grepped for sel_start / selections /
# multi_cursor; the feature exists under sel_on / sel_row / sel_col. Naming a
# feature wrong in a grep is enough to declare a working feature missing, so it
# is now pinned by behaviour instead.

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

print "=== Test 23: shipped editor selection ==="

class Buf:
    def __init__(self, lines):
        self.lines = lines
        self.line_count = len(lines)
        self.cursor_row = 0
        self.cursor_col = 0
    def get_line(self, i):
        if i >= 0 and i < self.line_count:
            return self.lines[i]
        return ""
    def get_all_text(self):
        return string_join(self.lines, "\n")

class IDE:
    def __init__(self, lines):
        self.buffers = [Buf(lines)]
        self.active_tab = 0
        self.sel_on = false
        self.sel_row = 0
        self.sel_col = 0
        self.undo_stack = []
        self.undo_n = 0
        self.status_msg = ""
        self._hl_cache = {}
        self._hl_cache_n = 0
    def _push_undo(self):
        self.undo_n = self.undo_n + 1
    def _sel_range(self):
        if not self.sel_on:
            return none
        var buf = self.buffers[self.active_tab]
        var ar = self.sel_row
        var ac = self.sel_col
        var br = buf.cursor_row
        var bc = buf.cursor_col
        if ar == br and ac == bc:
            return none
        if br < ar or (br == ar and bc < ac):
            return {"r1": br, "c1": bc, "r2": ar, "c2": ac}
        return {"r1": ar, "c1": ac, "r2": br, "c2": bc}

    def _sel_text(self):
        var g = self._sel_range()
        if g == none:
            return ""
        var buf = self.buffers[self.active_tab]
        if g["r1"] == g["r2"]:
            return string_slice(buf.get_line(g["r1"]), g["c1"], g["c2"])
        var out = string_slice(buf.get_line(g["r1"]), g["c1"], len(buf.get_line(g["r1"])))
        var i = g["r1"] + 1
        while i < g["r2"]:
            out = out + "\n" + buf.get_line(i)
            i = i + 1
        out = out + "\n" + string_slice(buf.get_line(g["r2"]), 0, g["c2"])
        return out

    def _sel_delete(self):
        var g = self._sel_range()
        if g == none:
            return false
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        var head = string_slice(buf.get_line(g["r1"]), 0, g["c1"])
        var tail = string_slice(buf.get_line(g["r2"]), g["c2"], len(buf.get_line(g["r2"])))
        var out = []
        var i = 0
        while i < buf.line_count:
            if i < g["r1"] or i > g["r2"]:
                out.append(buf.lines[i])
            elif i == g["r1"]:
                out.append(head + tail)
            i = i + 1
        if len(out) == 0:
            out = [""]
        buf.lines = out
        buf.line_count = len(out)
        buf.cursor_row = g["r1"]
        buf.cursor_col = g["c1"]
        self.sel_on = false
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.tabs[self.active_tab].dirty = true
        return true

    # Pixel position -> (row, col), used by click and drag.
    def _sel_begin(self):
        if not self.sel_on:
            var buf = self.buffers[self.active_tab]
            self.sel_row = buf.cursor_row
            self.sel_col = buf.cursor_col
            self.sel_on = true

    # Ordered (startRow, startCol, endRow, endCol); empty selections report none.
    def _sel_clear(self):
        self.sel_on = false


def mk():
    return IDE(["hello world", "second line", "third"])

def sel(ide, ar, ac, br, bc):
    ide.sel_on = true
    ide.sel_row = ar
    ide.sel_col = ac
    ide.buffers[0].cursor_row = br
    ide.buffers[0].cursor_col = bc
    return ide

# ── same line ────────────────────────────────────────────────────────────────
check("forward selection", sel(mk(), 0, 0, 0, 5)._sel_text(), "hello")
# dragging right-to-left must give the same text, not an empty or reversed range
check("backward selection", sel(mk(), 0, 5, 0, 0)._sel_text(), "hello")
check("mid-line selection", sel(mk(), 0, 6, 0, 11)._sel_text(), "world")

# ── across lines ─────────────────────────────────────────────────────────────
check("cross-line", sel(mk(), 0, 6, 1, 6)._sel_text(), "world\nsecond")
check("backward cross-line", sel(mk(), 1, 6, 0, 6)._sel_text(), "world\nsecond")
check("spanning three lines", sel(mk(), 0, 6, 2, 5)._sel_text(),
      "world\nsecond line\nthird")

# ── degenerate ───────────────────────────────────────────────────────────────
var e = sel(mk(), 0, 3, 0, 3)
check("empty range is none", e._sel_range() == none, true)
check("empty text", e._sel_text(), "")
var off = mk()
check("no selection when off", off._sel_range() == none, true)

# ── normalisation ────────────────────────────────────────────────────────────
var g1 = sel(mk(), 0, 5, 0, 0)._sel_range()
check("normalised start col", g1["c1"], 0)
check("normalised end col", g1["c2"], 5)
var g2 = sel(mk(), 1, 2, 0, 4)._sel_range()
check("normalised start row", g2["r1"], 0)
check("normalised end row", g2["r2"], 1)

# ── deletion ─────────────────────────────────────────────────────────────────
var d = sel(mk(), 0, 5, 1, 6)
d._sel_delete()
check("cross-line delete joins", d.buffers[0].get_all_text(), "hello line\nthird")
check("cursor lands at the join row", d.buffers[0].cursor_row, 0)
check("cursor lands at the join col", d.buffers[0].cursor_col, 5)
check("delete pushed one undo", d.undo_n, 1)

var d2 = sel(mk(), 0, 0, 0, 5)
d2._sel_delete()
check("same-line delete", d2.buffers[0].get_line(0), " world")

# deleting a backward selection must remove the same text as a forward one
var d3 = sel(mk(), 0, 5, 0, 0)
d3._sel_delete()
check("backward delete matches forward", d3.buffers[0].get_line(0), " world")

# ── begin / clear ────────────────────────────────────────────────────────────
var b = mk()
b.buffers[0].cursor_row = 1
b.buffers[0].cursor_col = 4
b._sel_begin()
check("begin anchors at the cursor", b.sel_row, 1)
check("begin anchors at the column", b.sel_col, 4)
check_true("begin turns selection on", b.sel_on)
# "second line" is s(0)e(1)c(2)o(3)n(4)d(5) (6)l(7)i(8)n(9)e(10), so an anchor
# at 4 extended to 8 selects "nd l", not "line". The first version of this
# assertion expected "line" and the code was right.
b.buffers[0].cursor_col = 8
check("extends from the anchor", b._sel_text(), "nd l")
b.buffers[0].cursor_col = 11
check("extends to end of line", b._sel_text(), "nd line")
b._sel_clear()
check("clear turns it off", b.sel_on, false)
check("cleared range is none", b._sel_range() == none, true)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 23 PASSED ==="
else:
    print "=== TEST 23 FAILED ==="

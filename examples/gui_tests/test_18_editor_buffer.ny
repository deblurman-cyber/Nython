# Test 18: the editor buffer is piece-table backed and has real undo/redo.
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

print "=== Test 18: Editor buffer ==="

# Mirrors EditorBuffer's use of the table: cursor -> offset -> edit -> resync.
class Buf:
    def __init__(self, content):
        self.pt = PieceTable(content)
        self.cursor_row = 0
        self.cursor_col = 0
        self.modified = false
        self.lines = []
        self.line_count = 0
        self._sync()
    def _sync(self):
        self.lines = string_split(self.pt.text(), "\n")
        self.line_count = len(self.lines)
        return self.line_count
    def get_line(self, i):
        if i >= 0 and i < self.line_count:
            return self.lines[i]
        return ""
    def text(self):
        return self.pt.text()
    def _offset(self):
        return self.pt.offset_of(self.cursor_row, self.cursor_col)
    def insert_char(self, ch):
        self.pt.insert(self._offset(), ch)
        self.cursor_col = self.cursor_col + 1
        self.modified = true
        self._sync()
    def insert_newline(self):
        self.pt.insert(self._offset(), "\n")
        self.cursor_row = self.cursor_row + 1
        self.cursor_col = 0
        self.modified = true
        self._sync()
    def backspace(self):
        var off = self._offset()
        if off <= 0:
            return false
        if self.cursor_col > 0:
            self.cursor_col = self.cursor_col - 1
        else:
            var prev = self.get_line(self.cursor_row - 1)
            self.cursor_row = self.cursor_row - 1
            self.cursor_col = len(prev)
        self.pt.delete(off - 1, 1)
        self.modified = true
        self._sync()
        return true
    def undo(self):
        var r = self.pt.undo()
        self._sync()
        return r
    def redo(self):
        var r = self.pt.redo()
        self._sync()
        return r

var b = Buf("hello\nworld")
check("initial lines", b.line_count, 2)
check("initial text", b.text(), "hello\nworld")
check("line 0", b.get_line(0), "hello")
check("line 1", b.get_line(1), "world")

b.cursor_row = 0
b.cursor_col = 5
b.insert_char("!")
check("insert at end of line", b.text(), "hello!\nworld")
check("cursor advanced", b.cursor_col, 6)
check("line count unchanged", b.line_count, 2)

b.insert_newline()
check("newline splits", b.text(), "hello!\n\nworld")
check("cursor moved to new line", b.cursor_row, 1)
check("cursor at column 0", b.cursor_col, 0)
check("line count grew", b.line_count, 3)

b.backspace()
check("backspace joins lines", b.text(), "hello!\nworld")
check("line count shrank", b.line_count, 2)

# undo walks back through every edit, in order
check_true("history available", b.pt.can_undo())
b.undo()
check("undo join", b.text(), "hello!\n\nworld")
b.undo()
check("undo newline", b.text(), "hello!\nworld")
b.undo()
check("undo insert", b.text(), "hello\nworld")
check("back at original", b.pt.can_undo(), false)

b.redo()
check("redo replays", b.text(), "hello!\nworld")

# the file as loaded is never mutated, whatever the edit history
check("original buffer intact", b.pt.original, "hello\nworld")

# editing in the middle of a line
var m = Buf("abcdef")
m.cursor_col = 3
m.insert_char("-")
check("mid-line insert", m.text(), "abc-def")
m.backspace()
check("mid-line backspace", m.text(), "abcdef")

# backspace at the very start is a no-op, not a crash or a corruption
var z = Buf("x")
z.cursor_col = 0
check("backspace at origin refused", z.backspace(), false)
check("text unchanged", z.text(), "x")

# a multi-line document maps offsets correctly on every line
var t = Buf("aa\nbb\ncc")
check("offset line 0", t.pt.offset_of(0, 0), 0)
check("offset line 1", t.pt.offset_of(1, 0), 3)
check("offset line 2", t.pt.offset_of(2, 1), 7)
t.cursor_row = 2
t.cursor_col = 2
t.insert_char("!")
check("insert on last line", t.text(), "aa\nbb\ncc!")


# ── history is operation-based, not snapshot-based (round 50) ────────────────
# A snapshot per edit is O(pieces) allocation per keystroke, and the interpreter
# does not reclaim containers, so the cost is permanent. Entries are now the
# inverse operation: four scalars plus, for a delete, the removed text.
var h = Buf("abcdef")
h.pt.insert(3, "XY")
check("insert applied", h.pt.text(), "abcXYdef")
check("one history entry", len(h.pt.undo_stack), 1)
check("entry is an op not a snapshot", h.pt.undo_stack[0]["op"], "insert")
check("entry records offset", h.pt.undo_stack[0]["off"], 3)
check("entry records length", h.pt.undo_stack[0]["len"], 2)
h.pt.undo()
check("undo insert", h.pt.text(), "abcdef")
check("redo available", h.pt.can_redo(), true)
h.pt.redo()
check("redo insert", h.pt.text(), "abcXYdef")

var d = Buf("abcdef")
d.pt.delete(1, 3)
check("delete applied", d.pt.text(), "aef")
check("delete keeps removed text", d.pt.undo_stack[0]["txt"], "bcd")
d.pt.undo()
check("undo delete restores", d.pt.text(), "abcdef")

var rp = Buf("abcdef")
rp.pt.replace(0, 3, "XY")
check("replace applied", rp.pt.text(), "XYdef")
check("replace is one entry", len(rp.pt.undo_stack), 1)
rp.pt.undo()
check("replace undoes in one step", rp.pt.text(), "abcdef")
rp.pt.redo()
check("replace redoes in one step", rp.pt.text(), "XYdef")

# history stays bounded in ENTRY COUNT regardless of document size
var many = Buf("seed")
var q = 0
while q < 30:
    many.pt.insert(0, "z")
    q = q + 1
check_true("history capped", len(many.pt.undo_stack) <= many.pt.max_undo)
many.pt.undo()
many.pt.undo()
check_true("undo still works deep in history", len(many.pt.text()) < 34)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 18 PASSED ==="
else:
    print "=== TEST 18 FAILED ==="

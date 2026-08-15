# ─── Selection / multi-cursor model ──────────────────────────────────────────
# The editor had a selection COLOUR and nothing to paint with it: no anchor, no
# extent, no notion of a selected range at all. So there was no shift-arrow
# selection, no click-drag, no select-all, and cut/copy/delete could only ever
# act on a whole line.
#
# Pure position arithmetic, deliberately free of rendering and event handling so
# it can be tested without a window. Positions are (row, col) with col counted in
# characters; a Selection is an anchor plus a caret, and the ordered pair is
# derived rather than stored — dragging backwards must produce the same range as
# dragging forwards.

class Pos:
    def __init__(self, row, col):
        self.row = row
        self.col = col

    def clone(self):
        return Pos(self.row, self.col)

    def same_as(self, o):
        return o != none and self.row == o.row and self.col == o.col

    # Ordering, so a range can be normalised regardless of drag direction.
    def before(self, o):
        if self.row != o.row:
            return self.row < o.row
        return self.col < o.col

    def to_string(self):
        return str(self.row) + ":" + str(self.col)


class Selection:
    def __init__(self, row, col):
        self.anchor = Pos(row, col)     # where the drag started; fixed
        self.caret = Pos(row, col)      # where the cursor is now; moves
        self.desired_col = col          # column to aim for on vertical movement

    def is_empty(self):
        return self.anchor.same_as(self.caret)

    def collapse_to_caret(self):
        self.anchor = self.caret.clone()
        return self

    # Normalised bounds: start is always before end.
    def start(self):
        if self.anchor.before(self.caret):
            return self.anchor
        return self.caret

    def end(self):
        if self.anchor.before(self.caret):
            return self.caret
        return self.anchor

    def spans_lines(self):
        return self.start().row != self.end().row

    def line_count(self):
        return self.end().row - self.start().row + 1

    def contains(self, row, col):
        var s = self.start()
        var e = self.end()
        if row < s.row or row > e.row:
            return false
        if row == s.row and col < s.col:
            return false
        if row == e.row and col >= e.col:
            return false
        return true

    # The horizontal band to paint on one row: [from, to) in columns.
    # Returns none when the row is outside the selection. `line_len` is needed
    # because a selection crossing a line end highlights to the end of the text,
    # not to the caret column of some other row.
    def row_span(self, row, line_len):
        if self.is_empty():
            return none
        var s = self.start()
        var e = self.end()
        if row < s.row or row > e.row:
            return none
        var a = 0
        var b = line_len
        if row == s.row:
            a = s.col
        if row == e.row:
            b = e.col
        if a > line_len:
            a = line_len
        if b > line_len:
            b = line_len
        if b < a:
            b = a
        return [a, b]


class SelectionModel:
    def __init__(self):
        # Multiple carets. Index 0 is the primary; it is the one that scrolls
        # into view and the one single-caret operations act on.
        self.sels = [Selection(0, 0)]
        self.count = 1

    def primary(self):
        return self.sels[0]

    def clear_secondary(self):
        var first = self.sels[0]
        self.sels = [first]
        self.count = 1
        return first

    def add_caret(self, row, col):
        # Never stack two carets on the same spot: they would consume the same
        # keystroke twice and duplicate every inserted character.
        var i = 0
        while i < self.count:
            if self.sels[i].caret.row == row and self.sels[i].caret.col == col:
                return false
            i = i + 1
        self.sels.append(Selection(row, col))
        self.count = self.count + 1
        return true

    def set_single(self, row, col):
        self.sels = [Selection(row, col)]
        self.count = 1
        return self.sels[0]

    def has_selection(self):
        var i = 0
        while i < self.count:
            if not self.sels[i].is_empty():
                return true
            i = i + 1
        return false

    def collapse_all(self):
        var i = 0
        while i < self.count:
            self.sels[i].collapse_to_caret()
            i = i + 1
        return true

    # Move every caret. `extend` keeps the anchor (shift-arrow); otherwise the
    # selection collapses first, which is what an unmodified arrow key does when
    # text is selected.
    def move_all(self, drow, dcol, extend, buf):
        var i = 0
        while i < self.count:
            var s = self.sels[i]
            if not extend and not s.is_empty():
                # Collapse to the near edge rather than moving from the caret:
                # pressing Left with a selection puts the cursor at its start.
                if dcol < 0 or drow < 0:
                    s.caret = s.start().clone()
                else:
                    s.caret = s.end().clone()
                s.collapse_to_caret()
            else:
                self._move_one(s, drow, dcol, buf)
                if not extend:
                    s.collapse_to_caret()
            i = i + 1
        return true

    def _move_one(self, s, drow, dcol, buf):
        var row = s.caret.row
        var col = s.caret.col
        if dcol != 0:
            col = col + dcol
            if col < 0:
                # Wrap to the end of the previous line rather than sticking at 0.
                if row > 0:
                    row = row - 1
                    col = len(buf.get_line(row))
                else:
                    col = 0
            elif col > len(buf.get_line(row)):
                if row < buf.line_count - 1:
                    row = row + 1
                    col = 0
                else:
                    col = len(buf.get_line(row))
            s.desired_col = col
        if drow != 0:
            row = row + drow
            if row < 0:
                row = 0
            if row > buf.line_count - 1:
                row = buf.line_count - 1
            # Vertical movement remembers the column it wants, so passing
            # through a short line does not permanently shorten the caret.
            col = s.desired_col
            var ll = len(buf.get_line(row))
            if col > ll:
                col = ll
        s.caret = Pos(row, col)
        return s

    def select_all(self, buf):
        var last = buf.line_count - 1
        var s = Selection(0, 0)
        s.caret = Pos(last, len(buf.get_line(last)))
        self.sels = [s]
        self.count = 1
        return s

    def select_line(self, row, buf):
        var s = Selection(row, 0)
        s.caret = Pos(row, len(buf.get_line(row)))
        self.sels = [s]
        self.count = 1
        return s

    # Word under a position, for double-click selection.
    def select_word(self, row, col, buf):
        var line = buf.get_line(row)
        var n = len(line)
        if n == 0:
            return self.set_single(row, 0)
        var i = col
        if i >= n:
            i = n - 1
        if not self._is_word(line[i]):
            return self.set_single(row, col)
        var a = i
        while a > 0 and self._is_word(line[a - 1]):
            a = a - 1
        var b = i
        while b < n and self._is_word(line[b]):
            b = b + 1
        var s = Selection(row, a)
        s.caret = Pos(row, b)
        self.sels = [s]
        self.count = 1
        return s

    def _is_word(self, c):
        if c >= "a" and c <= "z":
            return true
        if c >= "A" and c <= "Z":
            return true
        if c >= "0" and c <= "9":
            return true
        return c == "_"

    # Text covered by a selection, joined with newlines.
    def text_of(self, s, buf):
        if s.is_empty():
            return ""
        var a = s.start()
        var b = s.end()
        if a.row == b.row:
            return buf.get_line(a.row)[a.col:b.col]
        var out = buf.get_line(a.row)[a.col:]
        var r = a.row + 1
        while r < b.row:
            out = out + "\n" + buf.get_line(r)
            r = r + 1
        return out + "\n" + buf.get_line(b.row)[0:b.col]

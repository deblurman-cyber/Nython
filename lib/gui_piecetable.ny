# ─── Piece Table ─────────────────────────────────────────────────────────────
# The editor buffer stored text as a list of line strings, so every insertion
# rebuilt the affected line and every large paste rebuilt a large string. That
# is O(n) per keystroke against line length and O(file) for a paste — fine for a
# demo, visibly slow on a real source file.
#
# A piece table never mutates stored text. It keeps two immutable buffers —
# `original` (the file as loaded) and `add` (everything ever typed, append-only)
# — and represents the document as an ordered list of PIECES, each a (buffer,
# start, length) window into one of them. Editing is list surgery on the pieces,
# not string surgery on the text.
#
# The properties that matter for an editor:
#   * insert/delete cost is proportional to the piece count, not the file size
#   * the text you typed is never copied again after it is appended once
#   * undo/redo is just remembering a previous piece list, so history costs
#     almost nothing to keep
#
#   var pt = PieceTable("hello world")
#   pt.insert(5, ",")
#   pt.delete(0, 1)
#   pt.text()

class Piece:
    def __init__(self, which, start, length):
        self.which = which        # "orig" | "add"
        self.start = start
        self.length = length


class PieceTable:
    def __init__(self, initial):
        self.original = initial
        self.add = ""
        self.pieces = []
        self.piece_count = 0
        if len(initial) > 0:
            self.pieces = [Piece("orig", 0, len(initial))]
            self.piece_count = 1
        self.undo_stack = []
        self.redo_stack = []
        self.max_undo = 10
        self.dirty = false

    # ── reading ──────────────────────────────────────────────────────────────
    def _buffer(self, which):
        if which == "orig":
            return self.original
        return self.add

    def length(self):
        var n = 0
        var i = 0
        while i < self.piece_count:
            n = n + self.pieces[i].length
            i = i + 1
        return n

    def text(self):
        var out = ""
        var i = 0
        while i < self.piece_count:
            var p = self.pieces[i]
            out = out + self._buffer(p.which)[p.start:p.start + p.length]
            i = i + 1
        return out

    # Text in [start, start+count) without materialising the whole document.
    def substr(self, start, count):
        var out = ""
        var pos = 0
        var i = 0
        while i < self.piece_count:
            var p = self.pieces[i]
            var p_end = pos + p.length
            if p_end > start and pos < start + count:
                var lo = start - pos
                if lo < 0:
                    lo = 0
                var hi = start + count - pos
                if hi > p.length:
                    hi = p.length
                out = out + self._buffer(p.which)[p.start + lo:p.start + hi]
            pos = p_end
            i = i + 1
        return out

    # ── history ──────────────────────────────────────────────────────────────
    # Operation-based, not snapshot-based.
    #
    # The first version stored a copy of the whole piece list per edit. That is
    # O(pieces) allocation on every keystroke, and since the interpreter does
    # not reclaim containers the cost is permanent: 400 edits peaked at 373 MB.
    # Capping the history at 10 entries instead of 200 changed that to 363 MB —
    # proof that the memory was the DISCARDED snapshots, not the retained ones,
    # so no cap could ever fix it.
    #
    # An entry is now the inverse operation: four scalars and, for a delete, the
    # removed text. That is O(1) per edit and allocates nothing that scales with
    # document or piece count.
    def _record(self, op, offset, length, text):
        self.undo_stack.append({"op": op, "off": offset, "len": length, "txt": text})
        if len(self.undo_stack) > self.max_undo:
            var kept = []
            var i = 1
            while i < len(self.undo_stack):
                kept.append(self.undo_stack[i])
                i = i + 1
            self.undo_stack = kept
        self.redo_stack = []

    def can_undo(self):
        return len(self.undo_stack) > 0

    def can_redo(self):
        return len(self.redo_stack) > 0

    # Apply an entry's inverse without recording new history, and return the
    # entry that would undo THIS change, for the opposite stack.
    def _apply_inverse(self, e):
        if e["op"] == "insert":
            self._raw_delete(e["off"], e["len"])
            return {"op": "delete", "off": e["off"], "len": e["len"], "txt": e["txt"]}
        if e["op"] == "replace":
            # Undo a replace in one step: remove what was inserted, put back
            # what was removed. A replace recorded as two entries would take two
            # undos, which is not what the user performed.
            var was = self.substr(e["off"], e["len"])
            self._raw_delete(e["off"], e["len"])
            self._raw_insert(e["off"], e["txt"])
            return {"op": "replace", "off": e["off"], "len": len(e["txt"]), "txt": was}
        self._raw_insert(e["off"], e["txt"])
        return {"op": "insert", "off": e["off"], "len": len(e["txt"]), "txt": e["txt"]}

    def undo(self):
        if not self.can_undo():
            return false
        var n = len(self.undo_stack)
        var e = self.undo_stack[n - 1]
        var kept = []
        var i = 0
        while i < n - 1:
            kept.append(self.undo_stack[i])
            i = i + 1
        self.undo_stack = kept
        self.redo_stack.append(self._apply_inverse(e))
        self.dirty = true
        return true

    def redo(self):
        if not self.can_redo():
            return false
        var n = len(self.redo_stack)
        var e = self.redo_stack[n - 1]
        var kept = []
        var i = 0
        while i < n - 1:
            kept.append(self.redo_stack[i])
            i = i + 1
        self.redo_stack = kept
        self.undo_stack.append(self._apply_inverse(e))
        self.dirty = true
        return true

    # ── editing ──────────────────────────────────────────────────────────────
    # Split the piece containing `offset` so a boundary exists there. Returns the
    # index of the piece that begins at offset.
    def _split_at(self, offset):
        if offset <= 0:
            return 0
        var pos = 0
        var i = 0
        while i < self.piece_count:
            var p = self.pieces[i]
            if pos == offset:
                return i
            if pos + p.length > offset:
                var left_len = offset - pos
                var left = Piece(p.which, p.start, left_len)
                var right = Piece(p.which, p.start + left_len, p.length - left_len)
                var rebuilt = self.pieces[0:i] + [left, right] + self.pieces[i + 1:self.piece_count]
                self.pieces = rebuilt
                self.piece_count = len(rebuilt)
                return i + 1
            pos = pos + p.length
            i = i + 1
        return self.piece_count

    def insert(self, offset, s):
        if len(s) == 0:
            return false
        self._record("insert", offset, len(s), s)
        return self._raw_insert(offset, s)

    def _raw_insert(self, offset, s):
        if len(s) == 0:
            return false
        # Typed text is appended once and never moved again.
        var start = len(self.add)
        self.add = self.add + s
        var at = self._split_at(offset)
        var np = Piece("add", start, len(s))
        var rebuilt = self.pieces[0:at] + [np] + self.pieces[at:self.piece_count]
        self.pieces = rebuilt
        self.piece_count = len(rebuilt)
        self.dirty = true
        return true

    def delete(self, offset, count):
        if count <= 0:
            return false
        var total = self.length()
        if offset >= total:
            return false
        if offset + count > total:
            count = total - offset
        # Capture the text being removed so the inverse can restore it.
        self._record("delete", offset, count, self.substr(offset, count))
        return self._raw_delete(offset, count)

    def _raw_delete(self, offset, count):
        if count <= 0:
            return false
        var total = self.length()
        if offset >= total:
            return false
        if offset + count > total:
            count = total - offset
        var a = self._split_at(offset)
        var b = self._split_at(offset + count)
        var rebuilt = self.pieces[0:a] + self.pieces[b:self.piece_count]
        self.pieces = rebuilt
        self.piece_count = len(rebuilt)
        self.dirty = true
        return true

    def replace(self, offset, count, s):
        # One replace is one undo step. Record it as a single "replace" entry
        # holding the removed text and the inserted length, then perform both
        # halves without recording either.
        var total = self.length()
        if offset + count > total:
            count = total - offset
        var removed = self.substr(offset, count)
        self._record("replace", offset, len(s), removed)
        self._raw_delete(offset, count)
        return self._raw_insert(offset, s)

    # ── line mapping ─────────────────────────────────────────────────────────
    # Editors address text by line; the table addresses it by offset.
    def line_count(self):
        var t = self.text()
        var n = 1
        var i = 0
        while i < len(t):
            if t[i] == "\n":
                n = n + 1
            i = i + 1
        return n

    def lines(self):
        return string_split(self.text(), "\n")

    def line_start(self, line_no):
        var t = self.text()
        var seen = 0
        var i = 0
        while i < len(t):
            if seen == line_no:
                return i
            if t[i] == "\n":
                seen = seen + 1
                if seen == line_no:
                    return i + 1
            i = i + 1
        return len(t)

    def offset_of(self, line_no, col):
        return self.line_start(line_no) + col

    # Compact adjacent pieces that reference contiguous text. Purely an
    # optimisation: the document is unchanged, the piece list gets shorter.
    def compact(self):
        if self.piece_count < 2:
            return 0
        var merged = [self.pieces[0]]
        var i = 1
        while i < self.piece_count:
            var prev = merged[len(merged) - 1]
            var cur = self.pieces[i]
            if prev.which == cur.which and prev.start + prev.length == cur.start:
                prev.length = prev.length + cur.length
            else:
                merged.append(cur)
            i = i + 1
        var saved = self.piece_count - len(merged)
        self.pieces = merged
        self.piece_count = len(merged)
        return saved

import "lib/gui.ny"
import "lib/icons.ny"
import "../ide_icons.ny"
import "lib/ide_toolchain.ny"
import "lib/gui_piecetable.ny"
import "lib/gui_motion.ny"

# ═══════════════════════════════════════════════════════════════════════════════
# NythonIDE v3.0 — Full-featured IDE with compiler pipeline inspection
# ═══════════════════════════════════════════════════════════════════════════════

# ─── EditorBuffer ─────────────────────────────────────────────────────────────
class EditorBuffer:
    def __init__(self, name, content):
        self.name = name
        self.lines = []
        self.line_count = 0
        self.cursor_row = 0
        self.cursor_col = 0
        self.modified = false
        self.language = "nython"
        # Backed by a piece table. Line-list editing rebuilt a whole line per
        # keystroke and had no history at all; the table edits in O(pieces) and
        # gives undo/redo for free. The line list is kept as a lazily rebuilt
        # cache so every existing call site (get_line, syntax highlighting, the
        # minimap) keeps working unchanged.
        self.pt = PieceTable(content)
        self.lines_dirty = true
        self._parse_content(content)

    # ── piece-table integration ──────────────────────────────────────────────
    def _sync(self):
        if not self.lines_dirty:
            return 0
        self._parse_content(self.pt.text())
        self.lines_dirty = false
        return self.line_count

    def _offset(self):
        self._sync()
        return self.pt.offset_of(self.cursor_row, self.cursor_col)

    def _touch(self):
        self.lines_dirty = true
        self.modified = true
        self._sync()

    def can_undo(self):
        return self.pt.can_undo()

    def can_redo(self):
        return self.pt.can_redo()

    def undo(self):
        if not self.pt.undo():
            return false
        self._touch()
        self._clamp_cursor()
        return true

    def redo(self):
        if not self.pt.redo():
            return false
        self._touch()
        self._clamp_cursor()
        return true

    # History can shorten the document under the cursor, so keep it in range.
    def _clamp_cursor(self):
        if self.cursor_row >= self.line_count:
            self.cursor_row = self.line_count - 1
        if self.cursor_row < 0:
            self.cursor_row = 0
        var ln = self.get_line(self.cursor_row)
        if self.cursor_col > len(ln):
            self.cursor_col = len(ln)
        if self.cursor_col < 0:
            self.cursor_col = 0
        return 0

    def _parse_content(self, text):
        self.lines = []
        var rem = text
        while len(rem) > 0:
            var nl = string_find(rem, "\n")
            if nl < 0:
                self.lines = self.lines + [rem]
                rem = ""
            else:
                self.lines = self.lines + [rem[0:nl]]
                rem = rem[nl + 1:]
        if len(self.lines) == 0:
            self.lines = [""]
        self.line_count = len(self.lines)

    def get_line(self, idx):
        if idx >= 0 and idx < self.line_count:
            return self.lines[idx]
        return ""

    def get_all_text(self):
        var out = ""
        var i = 0
        while i < self.line_count:
            if i > 0:
                out = out + "\n"
            out = out + self.lines[i]
            i = i + 1
        return out

    def insert_char(self, ch):
        var off = self._offset()
        self.pt.insert(off, ch)
        self.cursor_col = self.cursor_col + 1
        self._touch()

    def delete_char_back(self):
        var row = self.cursor_row
        var col = self.cursor_col
        if col > 0:
            var off = self._offset()
            self.pt.delete(off - 1, 1)
            self.cursor_col = col - 1
            self._touch()
        elif row > 0:
            # Joining lines is just deleting the newline between them.
            var prev = self.get_line(row - 1)
            var off2 = self._offset()
            self.pt.delete(off2 - 1, 1)
            self.cursor_row = row - 1
            self.cursor_col = len(prev)
            self._touch()
        return 0

    def insert_newline(self):
        var off = self._offset()
        self.pt.insert(off, "\n")
        self.cursor_row = self.cursor_row + 1
        self.cursor_col = 0
        self._touch()
        return 0

    def move_cursor(self, drow, dcol):
        self.cursor_row = self.cursor_row + drow
        if self.cursor_row < 0:
            self.cursor_row = 0
        if self.cursor_row >= self.line_count:
            self.cursor_row = self.line_count - 1
        var line_len = len(self.get_line(self.cursor_row))
        if dcol != 0:
            self.cursor_col = self.cursor_col + dcol
        if self.cursor_col < 0:
            self.cursor_col = 0
        if self.cursor_col > line_len:
            self.cursor_col = line_len

    def get_stats(self):
        var words = 0
        var chars = 0
        var i = 0
        while i < self.line_count:
            chars = chars + len(self.lines[i])
            var parts = string_split(string_strip(self.lines[i]), " ")
            var j = 0
            while j < len(parts):
                if len(parts[j]) > 0:
                    words = words + 1
                j = j + 1
            i = i + 1
        return {"lines": self.line_count, "chars": chars, "words": words}


# ─── SyntaxHighlighter — full Nython tokeniser ────────────────────────────────
class SyntaxHighlighter:
    def __init__(self):
        self.keywords = ["def", "class", "if", "elif", "else", "while", "for", "in",
                         "return", "import", "var", "not", "and", "or", "true", "false",
                         "none", "print", "self", "do", "end", "break", "continue",
                         "try", "except", "finally", "raise", "with", "as", "pass",
                         "lambda", "yield", "from", "global", "del", "assert"]
        self.builtins = ["len", "str", "int", "float", "bool", "type", "range",
                         "list", "dict", "set", "tuple", "abs", "min", "max",
                         "sum", "sorted", "reversed", "enumerate", "zip", "map",
                         "filter", "input", "open", "print", "repr", "hash",
                         "isinstance", "hasattr", "getattr", "setattr", "dir",
                         "string_find", "string_split", "string_strip", "string_upper",
                         "string_lower", "string_replace", "string_startswith",
                         "string_endswith", "string_join", "keys", "values"]
        self.type_names = ["Color", "Rect", "Font", "Widget", "Window", "Button",
                           "Label", "Panel", "VBox", "HBox", "Theme", "Event",
                           "Tensor", "Module", "Linear", "Conv2d", "ReLU", "LSTM"]
        # Colours
        self.c_keyword  = Color(196, 148, 255, 255)
        self.c_builtin  = Color(86, 196, 255, 255)
        self.c_string   = Color(206, 145, 120, 255)
        self.c_comment  = Color(106, 153, 85, 200)
        self.c_number   = Color(180, 215, 120, 255)
        self.c_class_n  = Color(78, 201, 176, 255)
        self.c_type     = Color(252, 176, 98, 255)
        self.c_operator = Color(248, 186, 80, 220)
        self.c_self     = Color(196, 148, 255, 230)
        self.c_default  = Color(212, 214, 220, 230)
        self.c_decorator= Color(220, 175, 85, 240)
        self.c_lineno   = Color(80, 84, 112, 180)
        self.c_active_ln= Color(200, 200, 255, 220)

    def tokenise_line(self, line):
        var segments = []
        if len(line) == 0:
            return segments
        var stripped = string_strip(line)
        if string_startswith(stripped, "#"):
            segments = segments + [{"text": line, "color": self.c_comment}]
            return segments
        if string_startswith(stripped, "@"):
            segments = segments + [{"text": line, "color": self.c_decorator}]
            return segments
        var i = 0
        var j = 0
        var ch = ""
        var word = ""
        var wc = Color(0,0,0,0)
        while i < len(line):
            ch = line[i:i + 1]
            if ch == "#":
                segments = segments + [{"text": line[i:], "color": self.c_comment}]
                i = len(line)
            elif ch == "\"":
                j = i + 1
                while j < len(line) and line[j:j + 1] != "\"":
                    j = j + 1
                if j < len(line):
                    j = j + 1
                segments = segments + [{"text": line[i:j], "color": self.c_string}]
                i = j
            elif (ch >= "0" and ch <= "9"):
                j = i
                while j < len(line) and line[j:j+1] >= "0" and line[j:j+1] <= "9":
                    j = j + 1
                segments = segments + [{"text": line[i:j], "color": self.c_number}]
                i = j
            elif self._is_id_char(ch) and (ch < "0" or ch > "9"):
                j = i
                while j < len(line) and self._is_id_char(line[j:j+1]):
                    j = j + 1
                word = line[i:j]
                wc = self._word_color(word)
                segments = segments + [{"text": word, "color": wc}]
                i = j
            elif self._is_op_char(ch):
                segments = segments + [{"text": ch, "color": self.c_operator}]
                i = i + 1
            else:
                segments = segments + [{"text": ch, "color": self.c_default}]
                i = i + 1
        return segments

    def _is_op_char(self, ch):
        if ch == "+": return true
        if ch == "-": return true
        if ch == "*": return true
        if ch == "/": return true
        if ch == "%": return true
        if ch == "=": return true
        if ch == "<": return true
        if ch == ">": return true
        if ch == "!": return true
        return false

    def _is_id_char(self, ch):
        if ch >= "a" and ch <= "z": return true
        if ch >= "A" and ch <= "Z": return true
        if ch >= "0" and ch <= "9": return true
        if ch == "_": return true
        return false

    def _word_color(self, word):
        if word == "self":
            return self.c_self
        var found_kw = false
        var ki = 0
        while ki < len(self.keywords):
            if word == self.keywords[ki]:
                found_kw = true
            ki = ki + 1
        if found_kw:
            return self.c_keyword
        var found_bi = false
        var bi = 0
        while bi < len(self.builtins):
            if word == self.builtins[bi]:
                found_bi = true
            bi = bi + 1
        if found_bi:
            return self.c_builtin
        var found_ty = false
        var ti = 0
        while ti < len(self.type_names):
            if word == self.type_names[ti]:
                found_ty = true
            ti = ti + 1
        if found_ty:
            return self.c_type
        if len(word) > 0 and word[0:1] >= "A" and word[0:1] <= "Z":
            return self.c_type
        return self.c_default


# ─── RichEditor — GPU-style syntax-highlighted editor ─────────────────────────
class RichEditor:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.buffer = none
        self.hl = SyntaxHighlighter()
        self.scroll_y = 0
        self.scroll_x = 0
        self.line_h = 20
        self.char_w = 8
        self.gutter_w = 56
        self.font = Font("monospace", 13, false, false)
        self.font_bold = Font("monospace", 13, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.focused = false
        self.blink_t = 0.0
        self.blink_v = true
        self.bg = Color(18, 20, 34, 255)
        self.gutter_bg = Color(14, 16, 28, 255)
        self.active_line_bg = Color(255, 255, 255, 6)
        self.cursor_c = Color(99, 102, 241, 255)
        self.selection_c = Color(99, 102, 241, 40)
        self.visible = true
        self.id = ""
        self._on_change = none
        self._on_gutter_click = none

    def set_buffer(self, buf):
        self.buffer = buf
        self.scroll_y = 0
        self.scroll_x = 0
        return self

    def on_change(self, fn):
        self._on_change = fn
        return self

    def on_gutter_click(self, fn):
        self._on_gutter_click = fn
        return self

    def _visible_lines(self):
        return int(self.rect.h / self.line_h) + 2

    def handle_event(self, event):
        if not self.visible or self.buffer == none:
            return
        if event.type == "mousedown":
            if self.rect.contains(event.x, event.y):
                self.focused = true
                var ex = event.x - self.rect.x
                var ey = event.y - self.rect.y
                if ex < self.gutter_w:
                    var row = int((ey + self.scroll_y) / self.line_h)
                    if row >= 0 and row < self.buffer.line_count:
                        if self._on_gutter_click != none:
                            self._on_gutter_click(row + 1)
                else:
                    row = int((ey + self.scroll_y) / self.line_h)
                    var col = int((ex - self.gutter_w + self.scroll_x) / self.char_w)
                    if row < 0: row = 0
                    if row >= self.buffer.line_count: row = self.buffer.line_count - 1
                    var line_len = len(self.buffer.get_line(row))
                    if col < 0: col = 0
                    if col > line_len: col = line_len
                    self.buffer.cursor_row = row
                    self.buffer.cursor_col = col
                event.consume()
            else:
                self.focused = false
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 3
            if self.scroll_y < 0: self.scroll_y = 0
            var max_scroll = self.buffer.line_count * self.line_h - self.rect.h + 40
            if max_scroll < 0: max_scroll = 0
            if self.scroll_y > max_scroll: self.scroll_y = max_scroll
        elif event.type == "keydown" and self.focused and self.buffer != none:
            var consumed = true
            if event.key == "up":
                self.buffer.move_cursor(-1, 0)
                self._ensure_cursor_visible()
            elif event.key == "down":
                self.buffer.move_cursor(1, 0)
                self._ensure_cursor_visible()
            elif event.key == "left":
                self.buffer.move_cursor(0, -1)
            elif event.key == "right":
                self.buffer.move_cursor(0, 1)
            elif event.key == "home":
                var line = self.buffer.get_line(self.buffer.cursor_row)
                var indent = 0
                var li = 0
                while li < len(line) and line[li:li+1] == " ":
                    indent = indent + 1
                    li = li + 1
                if self.buffer.cursor_col == indent:
                    self.buffer.cursor_col = 0
                else:
                    self.buffer.cursor_col = indent
            elif event.key == "end":
                self.buffer.cursor_col = len(self.buffer.get_line(self.buffer.cursor_row))
            elif event.key == "enter":
                self.buffer.insert_newline()
                self._ensure_cursor_visible()
                if self._on_change != none: self._on_change(self.buffer)
            elif event.key == "backspace":
                self.buffer.delete_char_back()
                if self._on_change != none: self._on_change(self.buffer)
            elif event.key == "tab":
                self.buffer.insert_char(" ")
                self.buffer.insert_char(" ")
                self.buffer.insert_char(" ")
                self.buffer.insert_char(" ")
                if self._on_change != none: self._on_change(self.buffer)
            else:
                consumed = false
            if consumed:
                event.consume()
        elif event.type == "textinput" and self.focused and self.buffer != none:
            self.buffer.insert_char(event.text)
            if self._on_change != none: self._on_change(self.buffer)
            event.consume()

    def _ensure_cursor_visible(self):
        if self.buffer == none: return
        var cy = self.buffer.cursor_row * self.line_h
        var view_top = self.scroll_y
        var view_bot = self.scroll_y + self.rect.h - self.line_h * 2
        if cy < view_top:
            self.scroll_y = cy - self.line_h
            if self.scroll_y < 0: self.scroll_y = 0
        if cy > view_bot:
            self.scroll_y = cy - self.rect.h + self.line_h * 3

    def draw(self, renderer):
        if not self.visible or self.buffer == none:
            return
        renderer.fill_rect(self.rect, self.bg)
        self.blink_t = self.blink_t + 0.03
        if self.blink_t > 1.0:
            self.blink_t = 0.0
            self.blink_v = not self.blink_v
        var first = max(0, int(self.scroll_y / self.line_h))
        var vis = self._visible_lines()
        renderer.set_clip(self.rect)
        var i = first
        while i < self.buffer.line_count and i < first + vis:
            var ly = self.rect.y + i * self.line_h - self.scroll_y
            if i == self.buffer.cursor_row and self.focused:
                renderer.fill_rect(Rect(self.rect.x, ly, self.rect.w, self.line_h), self.active_line_bg)
            var lx = self.rect.x + self.gutter_w - self.scroll_x
            var segments = self.hl.tokenise_line(self.buffer.get_line(i))
            var si = 0
            while si < len(segments):
                var seg = segments[si]
                renderer.draw_text(seg["text"], lx, ly + 3, self.font, seg["color"])
                lx = lx + len(seg["text"]) * self.char_w
                si = si + 1
            if i == self.buffer.cursor_row and self.focused and self.blink_v:
                var cx = self.rect.x + self.gutter_w + self.buffer.cursor_col * self.char_w - self.scroll_x
                renderer.fill_rect(Rect(cx, ly + 2, 2, self.line_h - 4), self.cursor_c)
            i = i + 1
        renderer.clear_clip()
        renderer.fill_rect(Rect(self.rect.x, self.rect.y, self.gutter_w, self.rect.h), self.gutter_bg)
        renderer.draw_line(self.rect.x + self.gutter_w, self.rect.y, self.rect.x + self.gutter_w, self.rect.bottom(), Color(255,255,255,10), 1)
        renderer.set_clip(Rect(self.rect.x, self.rect.y, self.gutter_w, self.rect.h))
        var gi = first
        while gi < self.buffer.line_count and gi < first + vis:
            var gy = self.rect.y + gi * self.line_h - self.scroll_y
            var ln_str = str(gi + 1)
            var lc = self.hl.c_active_ln if gi == self.buffer.cursor_row else self.hl.c_lineno
            renderer.draw_text(ln_str, self.rect.x + self.gutter_w - 10 - len(ln_str) * 7, gy + 3, self.font_ui, lc)
            gi = gi + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h


# ─── OutputConsole — pretty output panel ──────────────────────────────────────
class OutputConsole:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.entries = []
        self.entry_count = 0
        self.scroll_y = 0
        self.bg = Color(12, 14, 24, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.line_h = 18
        self.visible = true
        self.id = ""

    def _kind_color(self, kind):
        if kind == "stdout": return Color(200, 210, 200, 230)
        if kind == "stderr": return Color(255, 100, 80, 240)
        if kind == "info":   return Color(100, 180, 255, 220)
        if kind == "ok":     return Color(80, 220, 120, 230)
        if kind == "warn":   return Color(255, 189, 46, 230)
        if kind == "cmd":    return Color(99, 102, 241, 230)
        return Color(180, 182, 220, 200)

    def write(self, text, kind):
        self.entries = self.entries + [{"text": text, "kind": kind}]
        self.entry_count = self.entry_count + 1
        var total = self.entry_count * self.line_h
        var max_scroll = total - self.rect.h + 20
        if max_scroll > 0: self.scroll_y = max_scroll
        return self

    def clear(self):
        self.entries = []
        self.entry_count = 0
        self.scroll_y = 0
        return self

    def handle_event(self, event):
        if not self.visible: return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 3
            if self.scroll_y < 0: self.scroll_y = 0

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.set_clip(self.rect)
        var first = max(0, int(self.scroll_y / self.line_h))
        var vis = int(self.rect.h / self.line_h) + 2
        var i = first
        while i < self.entry_count and i < first + vis:
            var e = self.entries[i]
            var ly = self.rect.y + i * self.line_h - self.scroll_y + 2
            var lc = self._kind_color(e["kind"])
            if e["kind"] == "cmd":
                renderer.draw_text("$ " + e["text"], self.rect.x + 8, ly, self.font_bold, lc)
            elif e["kind"] == "stderr":
                renderer.fill_rect(Rect(self.rect.x, ly - 1, self.rect.w, self.line_h), Color(255,80,60,8))
                renderer.fill_rect(Rect(self.rect.x, ly - 1, 3, self.line_h), Color(255,80,60,180))
                renderer.draw_text(e["text"], self.rect.x + 10, ly, self.font, lc)
            else:
                renderer.draw_text(e["text"], self.rect.x + 8, ly, self.font, lc)
            i = i + 1
        renderer.clear_clip()
        if self.entry_count == 0:
            renderer.draw_text("No output yet. Run a file to see results here.", self.rect.x + int(self.rect.w / 2) - 140, self.rect.y + int(self.rect.h / 2), self.font_ui, Color(50, 52, 80, 120))

    def set_pos(self, x, y): self.rect.x = x; self.rect.y = y
    def set_size(self, w, h): self.rect.w = w; self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false



# ═══════════════════════════════════════════════════════════════════════════════
# Language Workshop — Runtime Language Extension Panel
# ═══════════════════════════════════════════════════════════════════════════════
# Adds a LANGDEF tab to the bottom panel strip that lets users define new
# tokens, rewrite rules, macro handlers and operators live in the IDE.
#
# Layout (inside the panel content area):
#
#  ┌─────────────────────────────────────────────────────────────────┐
#  │  DEFINITION FORM          │  REGISTRY VIEWER  │  LIVE TEST      │
#  │  ─────────────────────    │  ────────────────  │  ─────────────  │
#  │  Kind: [Token▾]           │  ▸ Tokens (n)     │  Input:         │
#  │  Name: [____________]     │    • unless        │  [____________] │
#  │  Trigger/Pattern: [____]  │    • or_else       │                 │
#  │  Expansion: [__________]  │  ▸ Rules (n)       │  [  Apply  ]   │
#  │  [ Register ][ Clear ]    │    • unless_rule   │                 │
#  │                           │  ▸ Operators (n)   │  Output:        │
#  │  STATUS: ✓ Registered     │    • ??            │  result here    │
#  └─────────────────────────────────────────────────────────────────┘

class LangWorkshopPanel:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.visible = false

        # ── Colours ────────────────────────────────────────────────────────
        self.BG       = Color(14, 16, 28, 255)
        self.PANEL_BG = Color(18, 20, 36, 255)
        self.BORDER   = Color(255, 255, 255, 10)
        self.ACCENT   = Color(99, 102, 241, 255)
        self.DIM      = Color(100, 102, 140, 160)
        self.TEXT     = Color(200, 202, 230, 220)
        self.TEXT_BR  = Color(220, 222, 255, 240)
        self.OK       = Color(74, 222, 128, 200)
        self.WARN     = Color(251, 191, 36, 200)
        self.ERR      = Color(248, 113, 113, 200)
        self.TOK_CLR  = Color(196, 148, 198, 220)
        self.RULE_CLR = Color(86, 196, 186, 220)
        self.OP_CLR   = Color(252, 176, 90, 220)

        # ── Fonts ─────────────────────────────────────────────────────────
        self.F_BODY  = Font("monospace", 11, false, false)
        self.F_BOLD  = Font("monospace", 11, true, false)
        self.F_SMALL = Font("sans-serif", 10, false, false)
        self.F_HEAD  = Font("sans-serif", 12, true, false)

        # ── Layout constants ───────────────────────────────────────────────
        self.FORM_W   = int(w * 0.35)
        self.REG_W    = int(w * 0.35)
        self.TEST_W   = w - self.FORM_W - self.REG_W
        self.PAD      = 12

        # ── Form state ─────────────────────────────────────────────────────
        self.kind_options = ["token", "rewrite", "macro", "infix", "prefix", "operator"]
        self.kind_idx     = 0
        self.f_name       = TextInput(x + self.PAD, y + 60, self.FORM_W - self.PAD * 2, 26)
        self.f_name.placeholder = "name"
        self.f_trigger    = TextInput(x + self.PAD, y + 106, self.FORM_W - self.PAD * 2, 26)
        self.f_trigger.placeholder = "trigger / pattern"
        self.f_expansion  = TextInput(x + self.PAD, y + 152, self.FORM_W - self.PAD * 2, 26)
        self.f_expansion.placeholder = "expansion / description"
        self.f_prec       = TextInput(x + self.PAD, y + 198, 80, 26)
        self.f_prec.text  = "50"
        self.status_msg   = ""
        self.status_kind  = "ok"    # "ok" | "warn" | "err"

        # ── Registry mirror (for display) ─────────────────────────────────
        self.reg_tokens    = []
        self.reg_rules     = []
        self.reg_ops       = []
        self.reg_version   = -1
        self.reg_scroll    = 0
        self.reg_max_rows  = int((h - 30) / 18)

        # ── Live test ─────────────────────────────────────────────────────
        self.test_input  = TextInput(x + self.FORM_W + self.REG_W + self.PAD,
                                     y + 60, self.TEST_W - self.PAD * 2, 26)
        self.test_input.placeholder = "enter code to test, e.g: unless x > 5:"
        self.test_output = []
        self.test_scroll = 0

        # ── Quick-examples dropdown ────────────────────────────────────────
        self.examples = [
            ["unless keyword (rewrite)", "rewrite", "unless_kw", "unless\\s+(.+?)\\s*:", "if not \\1:", "0"],
            ["until keyword (rewrite)",  "rewrite", "until_kw",  "until\\s+(.+?)\\s*:",  "while not \\1:", "0"],
            ["log macro (macro)",        "token+macro", "log", "log", "", "0"],
            ["has operator (infix)",     "token+infix", "has", "has", "", "60"],
            ["pipe |> (rewrite+infix)",  "rewrite", "pipe_rw", "\\|>", " __pipe__ ", "0"],
            ["?? null-coal (token+infix)","token+infix", "or_else", "or_else", "", "15"],
        ]
        self.ex_scroll = 0

        # Selected item for deletion
        self.selected_tok = -1
        self.selected_rule = -1
        self.selected_op = -1

    def show(self):
        self.visible = true
        self._refresh_registry()

    def hide(self):
        self.visible = false

    def _refresh_registry(self):
        self.reg_tokens = lang_list_tokens()
        self.reg_rules  = lang_list_rules()
        self.reg_ops    = lang_list_operators()
        self.reg_version = lang_version()

    def _do_register(self):
        var kind = self.kind_options[self.kind_idx]
        var name = string_strip(self.f_name.text)
        var trig = string_strip(self.f_trigger.text)
        var exp  = string_strip(self.f_expansion.text)
        var prec = 50
        var prec_s = string_strip(self.f_prec.text)
        if len(prec_s) > 0:
            prec = int(prec_s)

        if len(name) == 0:
            self.status_msg  = "✗ Name is required"
            self.status_kind = "err"
            return

        if kind == "token":
            lang_define_token(name, trig, "keyword", exp)
            self.status_msg  = "✓ Token '" + name + "' registered"
            self.status_kind = "ok"

        elif kind == "rewrite":
            if len(trig) == 0:
                self.status_msg = "✗ Pattern required for rewrite"
                self.status_kind = "err"
                return
            lang_define_rule(name, "rewrite", "", trig, exp, prec)
            self.status_msg  = "✓ Rewrite rule '" + name + "' registered"
            self.status_kind = "ok"

        elif kind == "macro":
            if len(trig) == 0:
                self.status_msg = "✗ Trigger token required for macro"
                self.status_kind = "err"
                return
            # Auto-register the trigger token if not already present
            lang_define_token(trig, "", "keyword", "auto-registered by macro " + name)
            # Macro with identity handler (prints args)
            lang_define_macro(name, trig, lambda a: print("[macro:" + name + "] " + str(a)))
            self.status_msg  = "✓ Macro '" + name + "' registered (trigger: '" + trig + "')"
            self.status_kind = "ok"

        elif kind == "infix":
            if len(trig) == 0:
                self.status_msg = "✗ Trigger token required for infix"
                self.status_kind = "err"
                return
            lang_define_token(trig, "", "operator", "auto-registered by infix rule " + name)
            # Placeholder infix: returns [lhs, rhs] tuple representation
            lang_define_infix(name, trig,
                lambda a, b: str(a) + " " + trig + " " + str(b), prec)
            self.status_msg  = "✓ Infix op '" + trig + "' registered (rule: " + name + ")"
            self.status_kind = "ok"

        elif kind == "prefix":
            if len(trig) == 0:
                self.status_msg = "✗ Trigger token required for prefix"
                self.status_kind = "err"
                return
            lang_define_token(trig, "", "operator", "auto-registered by prefix rule " + name)
            lang_define_prefix(name, trig, lambda a: a)
            self.status_msg  = "✓ Prefix op '" + trig + "' registered (rule: " + name + ")"
            self.status_kind = "ok"

        elif kind == "operator":
            if len(trig) == 0:
                self.status_msg = "✗ Symbol required for operator"
                self.status_kind = "err"
                return
            lang_define_operator(trig, "infix", prec,
                lambda a, b: str(a) + trig + str(b), exp)
            self.status_msg  = "✓ Symbol operator '" + trig + "' registered"
            self.status_kind = "ok"

        self._refresh_registry()

    def _do_test(self):
        var code = string_strip(self.test_input.text)
        if len(code) == 0:
            return
        var result = lang_eval(code)
        var line = "> " + code + " → " + str(result)
        self.test_output = self.test_output + [line]
        if len(self.test_output) > 50:
            self.test_output = self.test_output[1:]

    def _do_clear_form(self):
        self.f_name.text      = ""
        self.f_trigger.text   = ""
        self.f_expansion.text = ""
        self.f_prec.text      = "50"
        self.status_msg       = ""

    def handle_event(self, event):
        if not self.visible: return

        # Kind selector click (top of form)
        if event.type == "mousedown":
            var kind_y = self.y + 26
            var kind_x = self.x + self.PAD
            var kw     = 72
            var i = 0
            while i < len(self.kind_options):
                var bx = kind_x + i * (kw + 4)
                if event.x >= bx and event.x < bx + kw and event.y >= kind_y and event.y < kind_y + 22:
                    self.kind_idx = i
                    event.consume()
                    return
                i = i + 1

            # Register button
            var btn_x  = self.x + self.PAD
            var btn_y  = self.y + 228
            var btn_w  = 90
            var btn_h  = 26
            if event.x >= btn_x and event.x < btn_x + btn_w and event.y >= btn_y and event.y < btn_y + btn_h:
                self._do_register()
                event.consume()
                return

            # Clear button
            var clr_x = btn_x + btn_w + 10
            if event.x >= clr_x and event.x < clr_x + 70 and event.y >= btn_y and event.y < btn_y + btn_h:
                self._do_clear_form()
                event.consume()
                return

            # Reset all button
            var rst_x = clr_x + 80
            if event.x >= rst_x and event.x < rst_x + 90 and event.y >= btn_y and event.y < btn_y + btn_h:
                lang_reset()
                self._refresh_registry()
                self.test_output = []
                self.status_msg  = "✓ Registry cleared"
                self.status_kind = "warn"
                event.consume()
                return

            # Test button
            var test_btn_x = self.x + self.FORM_W + self.REG_W + self.PAD
            var test_btn_y = self.y + 96
            if event.x >= test_btn_x and event.x < test_btn_x + 80 and event.y >= test_btn_y and event.y < test_btn_y + 24:
                self._do_test()
                event.consume()
                return

            # Example buttons (right of registry)
            var ex_x = self.x + self.FORM_W + self.PAD
            var ex_y = self.y + 30
            var ex_row_h = 17
            var i2 = 0
            while i2 < len(self.examples):
                var ey = ex_y + i2 * ex_row_h
                if event.x >= ex_x and event.x < ex_x + self.REG_W - self.PAD and event.y >= ey and event.y < ey + ex_row_h - 1:
                    var ex = self.examples[i2]
                    self.kind_idx = 0
                    var k = 0
                    while k < len(self.kind_options):
                        if self.kind_options[k] == ex[0][0:len(self.kind_options[k])]:
                            self.kind_idx = k
                        k = k + 1
                    self.f_name.text      = ex[2]
                    self.f_trigger.text   = ex[3]
                    self.f_expansion.text = ex[4]
                    self.f_prec.text      = ex[5]
                    event.consume()
                    return
                i2 = i2 + 1

        # Delegate to text inputs
        self.f_name.handle_event(event)
        self.f_trigger.handle_event(event)
        self.f_expansion.handle_event(event)
        self.f_prec.handle_event(event)
        self.test_input.handle_event(event)

        # Refresh if version changed
        if lang_version() != self.reg_version:
            self._refresh_registry()

    def draw(self, renderer):
        if not self.visible: return

        var full_rect = Rect(self.x, self.y, self.w, self.h)
        renderer.fill_rect(full_rect, self.BG)
        renderer.draw_line(self.x, self.y, self.x + self.w, self.y, self.BORDER, 1)

        self._draw_form(renderer)
        self._draw_registry(renderer)
        self._draw_test(renderer)

        # Column dividers
        var div1 = self.x + self.FORM_W
        var div2 = div1 + self.REG_W
        renderer.draw_line(div1, self.y + 4, div1, self.y + self.h - 4, self.BORDER, 1)
        renderer.draw_line(div2, self.y + 4, div2, self.y + self.h - 4, self.BORDER, 1)

    def _draw_form(self, renderer):
        var x = self.x + self.PAD
        var y = self.y + 6

        renderer.draw_text("DEFINE EXTENSION", x, y, self.F_BOLD, self.ACCENT)

        # Kind selector tabs
        var kind_y = self.y + 22
        var kw = 72
        var i = 0
        while i < len(self.kind_options):
            var bx   = x + i * (kw + 4)
            var is_active = (i == self.kind_idx)
            var bg   = Color(99, 102, 241, is_active * 60)
            var tc   = self.ACCENT if is_active else self.DIM
            renderer.fill_rect(Rect(bx, kind_y, kw, 22), bg)
            renderer.draw_rect(Rect(bx, kind_y, kw, 22), Color(255, 255, 255, is_active * 30 + 8), 1)
            renderer.draw_text(self.kind_options[i], bx + 6, kind_y + 5, self.F_SMALL, tc)
            i = i + 1

        # Fields
        var fields = [
            ["name",              self.f_name],
            ["trigger / pattern", self.f_trigger],
            ["expansion / desc",  self.f_expansion],
            ["precedence",        self.f_prec]
        ]
        var fy = self.y + 48
        var fi = 0
        while fi < len(fields):
            renderer.draw_text(fields[fi][0], x, fy, self.F_SMALL, self.DIM)
            fields[fi][1].y = fy + 12
            fields[fi][1].draw(renderer)
            fy = fy + 50
            fi = fi + 1

        # Buttons row
        var btn_y = fy + 2
        renderer.fill_rect(Rect(x, btn_y, 90, 26), Color(99, 102, 241, 80))
        renderer.draw_rect(Rect(x, btn_y, 90, 26), Color(99, 102, 241, 120), 1)
        renderer.draw_text("Register", x + 16, btn_y + 7, self.F_BOLD, Color(200, 202, 255, 230))

        var clr_x = x + 100
        renderer.fill_rect(Rect(clr_x, btn_y, 70, 26), Color(255, 255, 255, 8))
        renderer.draw_rect(Rect(clr_x, btn_y, 70, 26), self.BORDER, 1)
        renderer.draw_text("Clear", clr_x + 16, btn_y + 7, self.F_SMALL, self.DIM)

        var rst_x = clr_x + 80
        renderer.fill_rect(Rect(rst_x, btn_y, 90, 26), Color(248, 113, 113, 30))
        renderer.draw_rect(Rect(rst_x, btn_y, 90, 26), Color(248, 113, 113, 60), 1)
        renderer.draw_text("Reset All", rst_x + 8, btn_y + 7, self.F_SMALL, Color(248, 113, 113, 180))

        # Status message
        if len(self.status_msg) > 0:
            var sc = self.OK if self.status_kind == "ok" else (self.WARN if self.status_kind == "warn" else self.ERR)
            renderer.draw_text(self.status_msg, x, btn_y + 34, self.F_SMALL, sc)

    def _draw_registry(self, renderer):
        var x  = self.x + self.FORM_W + self.PAD
        var y  = self.y + 6
        var rw = self.REG_W - self.PAD * 2

        renderer.draw_text("REGISTRY  v" + str(self.reg_version), x, y, self.F_BOLD, self.ACCENT)

        var row_y = self.y + 22
        var rh    = 16

        # Tokens section
        renderer.draw_text("▸ TOKENS  (" + str(len(self.reg_tokens)) + ")",
                           x, row_y, self.F_SMALL, self.TOK_CLR)
        row_y = row_y + rh
        var i = 0
        while i < len(self.reg_tokens):
            if row_y > self.y + self.h - 10: break
            var t   = self.reg_tokens[i]
            var pat = ""
            if len(t["pattern"]) > 0: pat = "  ~/" + t["pattern"] + "/"
            renderer.draw_text("  • " + t["name"] + pat,
                               x, row_y, self.F_BODY,
                               Color(self.TOK_CLR.r, self.TOK_CLR.g, self.TOK_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Rules section
        renderer.draw_text("▸ RULES  (" + str(len(self.reg_rules)) + ")",
                           x, row_y, self.F_SMALL, self.RULE_CLR)
        row_y = row_y + rh
        i = 0
        while i < len(self.reg_rules):
            if row_y > self.y + self.h - 10: break
            var r     = self.reg_rules[i]
            var brief = "[" + r["kind"] + "] " + r["name"]
            if len(r["trigger"]) > 0:
                brief = brief + "  '" + r["trigger"] + "'"
            if r["kind"] == "rewrite" and len(r["expansion"]) > 0:
                var exp = r["expansion"]
                if len(exp) > 18: exp = exp[0:16] + "…"
                brief = brief + " → " + exp
            renderer.draw_text("  • " + brief,
                               x, row_y, self.F_BODY,
                               Color(self.RULE_CLR.r, self.RULE_CLR.g, self.RULE_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Operators section
        renderer.draw_text("▸ OPERATORS  (" + str(len(self.reg_ops)) + ")",
                           x, row_y, self.F_SMALL, self.OP_CLR)
        row_y = row_y + rh
        i = 0
        while i < len(self.reg_ops):
            if row_y > self.y + self.h - 10: break
            var o = self.reg_ops[i]
            renderer.draw_text("  • '" + o["symbol"] + "'  " + o["arity"] + "  prec=" + str(o["prec"]),
                               x, row_y, self.F_BODY,
                               Color(self.OP_CLR.r, self.OP_CLR.g, self.OP_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Quick-examples hint
        if len(self.reg_tokens) == 0 and len(self.reg_rules) == 0:
            renderer.draw_text("(no extensions defined yet)", x + 8, self.y + 50,
                               self.F_SMALL, self.DIM)
            renderer.draw_text("Quick-start examples:", x + 8, self.y + 72, self.F_SMALL, self.DIM)
            var ei = 0
            while ei < len(self.examples):
                renderer.draw_text("  ↳ " + self.examples[ei][0],
                                   x + 8, self.y + 88 + ei * 16,
                                   self.F_SMALL, Color(self.ACCENT.r, self.ACCENT.g, self.ACCENT.b, 120))
                ei = ei + 1

    def _draw_test(self, renderer):
        var x  = self.x + self.FORM_W + self.REG_W + self.PAD
        var y  = self.y + 6
        var tw = self.TEST_W - self.PAD * 2

        renderer.draw_text("LIVE TEST", x, y, self.F_BOLD, self.ACCENT)
        renderer.draw_text("Code (with rewrites applied):", x, self.y + 22, self.F_SMALL, self.DIM)

        self.test_input.y = self.y + 34
        self.test_input.draw(renderer)

        # Run button
        renderer.fill_rect(Rect(x, self.y + 68, 80, 24), Color(99, 102, 241, 80))
        renderer.draw_rect(Rect(x, self.y + 68, 80, 24), Color(99, 102, 241, 120), 1)
        renderer.draw_text("▶ Run", x + 18, self.y + 75, self.F_BOLD, Color(200, 202, 255, 220))

        renderer.draw_text("Output:", x, self.y + 102, self.F_SMALL, self.DIM)
        var out_y = self.y + 118
        var i = 0
        while i < len(self.test_output):
            if out_y > self.y + self.h - 10: break
            var line = self.test_output[i]
            var clr  = self.TEXT
            if string_startswith(line, ">"):
                clr = Color(self.ACCENT.r, self.ACCENT.g, self.ACCENT.b, 200)
            renderer.draw_text(line, x, out_y, self.F_BODY, clr)
            out_y = out_y + 15
            i = i + 1

        if len(self.test_output) == 0:
            renderer.draw_text("Results appear here after ▶ Run", x + 4, self.y + 122,
                               self.F_SMALL, self.DIM)
            renderer.draw_text("Example: unless x > 5:", x + 4, self.y + 142,
                               self.F_SMALL, Color(self.DIM.r, self.DIM.g, self.DIM.b, 100))
            renderer.draw_text("Example: [1,2,3] has 2", x + 4, self.y + 158,
                               self.F_SMALL, Color(self.DIM.r, self.DIM.g, self.DIM.b, 100))


# ─── NythonIDE v3.0 ───────────────────────────────────────────────────────────
class NythonIDE:
    def __init__(self):
        self.win = Window(1600, 960, "NythonIDE v3.0")

        # Icon set + the font that renders it (see lib/icons.ny for licensing).
        # Real compiler bridge. Run / Tokenize / AST / Disassemble used to be
        # simulated by scanning buffer text; they now invoke the actual binary.
        self.toolchain = Toolchain()
        self.repl_history = []

        # Pointer feedback + draggable pane splitters.
        # Seeded from the window so the cursor map and splitter rects are valid
        # before the first resize event ever arrives.
        # High-DPI. Every metric below was a raw pixel count, so on a Retina or
        # 4K panel the whole interface rendered at half size with blurry text.
        # Chrome metrics are multiplied by the display's content scale; a scale
        # of 1.0 leaves the previous numbers exactly as they were.
        self.dpi = gui_display_scale()
        if self.dpi <= 0.0:
            self.dpi = 1.0

        # Layout constants — base (unscaled) values. These must be set
        # before the DPI-scaling block below, which reads them back through
        # self.scaled(); reading them first left every one of these none
        # (an unset attribute), and self.scaled(none) propagated none into
        # every layout metric derived from it, eventually reaching
        # float(none) when the editor/panel split was computed.
        self.MIN_W      = 640     # below this the panes stop shrinking
        self.MIN_H      = 400
        self.CHAT_W     = 360
        self.ACTIVITY_W = 52
        self.SIDEBAR_W  = 260
        self.EDITOR_H_RATIO = 0.60
        self.TOOLBAR_H  = 38
        self.STATUS_H   = 26
        self.MINIMAP_W  = 110
        self.PANEL_H    = 0  # computed
        self.SPLIT_HIT  = 5      # px either side of a splitter that grabs it

        self.TOOLBAR_H  = self.scaled(self.TOOLBAR_H)
        self.STATUS_H   = self.scaled(self.STATUS_H)
        self.ACTIVITY_W = self.scaled(self.ACTIVITY_W)
        self.SIDEBAR_W  = self.scaled(self.SIDEBAR_W)
        self.MINIMAP_W  = self.scaled(self.MINIMAP_W)
        self.MIN_W      = self.scaled(self.MIN_W)
        self.MIN_H      = self.scaled(self.MIN_H)
        self.SPLIT_HIT  = self.scaled(self.SPLIT_HIT)

        self.win_w        = self.win.width
        self.win_h        = self.win.height
        self.cursors      = CursorManager()
        self.drag_split   = ""     # "" | "sidebar" | "panel"
        self.drag_origin  = 0
        self.drag_start_v = 0
        self.editor_ratio = 0.62   # editor/panel split, adjustable by dragging
        self.use_vm    = false

        self.icons = Icons()
        self.icon_font    = Font(self.icons.font_path, 16, false, false)
        self.icon_font_sm = Font(self.icons.font_path, 13, false, false)

        # ── Files / buffers ─────────────────────────────────────────────────
        self.buffers = []
        self.buf_count = 0
        self.active_buf = 0
        self._init_sample_files()

        # ── Compiler pipeline state ─────────────────────────────────────────
        self.last_mode = 0        # 0=Run 1=Debug 2=Tokenize 3=AST 4=Disasm 5=REPL 6=Profile
        self.run_output = []      # lines of last run
        self.token_data = []      # parsed token list
        self.ast_xml = ""
        self.is_running = false
        self.run_elapsed_ms = 0

        # ── Notification / toast state ───────────────────────────────────────
        self.toast_mgr = ToastManager()
        self.notif_bell = NotificationBell(0, 0, 28, 28)
        self.notif_bell.add("IDE ready — Nython v3.0", "info")
        self.notif_bell.add("All 1053 GUI tests passing", "ok")
        self.confetti = Confetti(0, 0, 1600, 960)
        self.show_confetti = false

        # ── Spotlight ────────────────────────────────────────────────────────
        self.spotlight = Spotlight(320, 160, 960, 480)
        self._register_commands()

        # ── Keybinds ─────────────────────────────────────────────────────────
        self.keybind_panel = KeybindPanel(200, 80, 1200, 800)
        self._register_keybinds()
        self.show_keybinds = false

        # ── Widgets ──────────────────────────────────────────────────────────
        self._build_layout()

        # ── Debug state ──────────────────────────────────────────────────────
        self.debug_panel.add_watch("self.count", "0")
        self.debug_panel.add_watch("result", "none")
        self.debug_panel.push_frame("<module>", "main.ny", 1)

        # ── Profiler demo data ───────────────────────────────────────────────
        self._load_demo_profiler()

        # ── REPL ─────────────────────────────────────────────────────────────
        self.repl_panel.on_execute(self._repl_execute)
        self.repl_panel.write("Nython 3.0 REPL — type expressions and press Enter", "info")
        self.repl_panel.write("Try: var x = 42  |  print x * 2  |  class Foo:", "info")

        # ── Git panel ────────────────────────────────────────────────────────
        self.git_panel.add_change("src/main.ny", "modified")
        self.git_panel.add_change("src/utils.ny", "modified")
        self.git_panel.add_change("lib/gui.ny", "added")
        self.git_panel.add_change("README.md", "modified")

    def _init_sample_files(self):
        var main_src = "import \"lib/gui.ny\"\nimport \"lib/nytorch.ny\"\n\n# NyxAI demo — Vision Transformer style\nclass ViTBlock:\n    def __init__(self, dim, heads):\n        self.attn = MultiheadAttention(dim, heads)\n        self.norm = LayerNorm(dim)\n        self.ff   = Sequential(Linear(dim, dim * 4), GELU(), Linear(dim * 4, dim))\n        self.drop = Dropout(0.1)\n\n    def forward(self, x):\n        var h = self.norm.forward(x)\n        h = self.attn.forward(h, h, h)\n        x = x + self.drop.forward(h)\n        x = x + self.drop.forward(self.ff.forward(self.norm.forward(x)))\n        return x\n\n# Build a simple 4-layer ViT classifier\nvar model = Sequential(\n    ViTBlock(256, 8),\n    ViTBlock(256, 8),\n    ViTBlock(256, 8),\n    Linear(256, 10)\n)\n\nvar win = Window(800, 600, \"ViT Demo\")\nvar card = GlassCard(60, 60, 680, 480)\nvar counter = AnimatedCounter(120, 200, 240, 80, 0.0, 99.2, \"%\")\nvar grad_btn = GradientButton(300, 380, 200, 44, \"Run Inference\")\n\nprint \"Model ready — \" + str(len(model.parameters())) + \" parameters\"\n"
        var utils_src = "# Utility functions for NythonIDE\n\ndef clamp(val, lo, hi):\n    if val < lo: return lo\n    if val > hi: return hi\n    return val\n\ndef lerp(a, b, t):\n    return a + (b - a) * t\n\ndef format_num(n):\n    if n >= 1000000:\n        return str(int(n / 1000000)) + \"M\"\n    if n >= 1000:\n        return str(int(n / 1000)) + \"k\"\n    return str(n)\n\ndef zip_lists(a, b):\n    var out = []\n    var i = 0\n    while i < len(a) and i < len(b):\n        out = out + [[a[i], b[i]]]\n        i = i + 1\n    return out\n\ndef flatten(lst):\n    var out = []\n    var i = 0\n    while i < len(lst):\n        var j = 0\n        while j < len(lst[i]):\n            out = out + [lst[i][j]]\n            j = j + 1\n        i = i + 1\n    return out\n"
        var app_src = "# Application framework\n\nclass App:\n    def __init__(self, title):\n        self.title = title\n        self.modules = []\n        self.running = true\n        print \"App: \" + title + \" started\"\n\n    def register(self, mod):\n        self.modules = self.modules + [mod]\n        return self\n\n    def run(self):\n        while self.running:\n            var i = 0\n            while i < len(self.modules):\n                self.modules[i].tick()\n                i = i + 1\n\nclass Module:\n    def __init__(self, name):\n        self.name = name\n        self.enabled = true\n\n    def tick(self):\n        pass\n\nvar app = App(\"NythonApp\")\nprint \"Framework loaded\"\n"
        var okra_src = "# OkraNet — Maturity Classification\nimport \"lib/nytorch.ny\"\n\nclass OkraViT:\n    def __init__(self):\n        self.patch_embed = Linear(48 * 48 * 3, 256)\n        self.pos_embed   = Tensor.zeros(1, 196, 256)\n        self.blocks = []\n        var i = 0\n        while i < 6:\n            self.blocks = self.blocks + [TransformerBlock(256, 8)]\n            i = i + 1\n        self.head = Linear(256, 5)  # 5 maturity stages\n\n    def forward(self, x):\n        var h = self.patch_embed.forward(x)\n        h = h + self.pos_embed\n        var i = 0\n        while i < len(self.blocks):\n            h = self.blocks[i].forward(h)\n            i = i + 1\n        return self.head.forward(h)\n\n# Training config\nvar model = OkraViT()\nvar optim = Adam(model.parameters(), 0.0001)\nvar loss_fn = OrdinalCrossEntropy(5)\n\nprint \"OkraViT ready — 6 transformer blocks\"\nprint \"Maturity stages: Immature / PreMaturing / Mature / Overripe / Dried\"\n"
        self._add_buffer("main.ny",   main_src,  "/project/src/main.ny")
        self._add_buffer("utils.ny",  utils_src, "/project/src/utils.ny")
        self._add_buffer("app.ny",    app_src,   "/project/src/app.ny")
        self._add_buffer("okra.ny",   okra_src,  "/project/src/okra.ny")

    def _add_buffer(self, name, content, path):
        var buf = EditorBuffer(name, content)
        buf.language = "nython"
        self.buffers = self.buffers + [buf]
        self.buf_count = self.buf_count + 1

    def _build_layout(self):
        # Was hardcoded 1600x960, so the IDE rendered at that size no matter how
        # large or small the window actually was. Read the real size, and clamp
        # so a narrow window cannot produce negative widget widths.
        var W = self.win.width
        var H = self.win.height
        if W < self.MIN_W:
            W = self.MIN_W
        if H < self.MIN_H:
            H = self.MIN_H

        var toolbar_y = 0
        var content_y = self.TOOLBAR_H
        var content_h = H - self.TOOLBAR_H - self.STATUS_H
        var sidebar_x = self.ACTIVITY_W
        var editor_x  = self.ACTIVITY_W + self.SIDEBAR_W
        var editor_w  = W - editor_x - self.MINIMAP_W
        var editor_h  = int(float(content_h) * 0.62)
        self.PANEL_H  = content_h - editor_h

        # ── Run config toolbar ───────────────────────────────────────────────
        self.run_bar = RunConfigBar(0, toolbar_y, W, self.TOOLBAR_H)
        self.run_bar.on_mode(self._on_mode_change)
        self.run_bar.on_run(self._on_run)

        # ── Activity bar ─────────────────────────────────────────────────────
        self.activity = ActivityBar(0, content_y, self.ACTIVITY_W, content_h)
        # Codicon glyphs rather than emoji. Emoji are rendered by whatever emoji
        # font the OS ships, so they were multi-coloured, differently shaped on
        # every platform, and impossible to theme. Codicons are monochrome and
        # inherit the current text colour, which is what VS Code relies on.
        self.activity.add_item(self.icons.get("files"),          "Explorer", false)
        self.activity.add_item(self.icons.get("search"),         "Search", false)
        self.activity.add_item(self.icons.get("source-control"), "Source Control", false)
        self.activity.add_item(self.icons.get("debug-alt"),      "Run & Debug", false)
        self.activity.add_item(self.icons.get("sparkle"),        "NyxAI", false)
        self.activity.items[2].badge = 4
        self.activity.on_select(self._on_activity)

        # ── Sidebar (file tree) ───────────────────────────────────────────────
        self.file_tree = FileTree(sidebar_x, content_y, self.SIDEBAR_W, content_h)
        self.file_tree.add_node("/project", "📁 project", 0, true, "folder")
        self.file_tree.add_node("/project/src", "📁 src", 1, true, "folder")
        self.file_tree.add_node("/project/src/main.ny", "main.ny", 2, false, "file")
        self.file_tree.add_node("/project/src/utils.ny", "utils.ny", 2, false, "file")
        self.file_tree.add_node("/project/src/app.ny", "app.ny", 2, false, "file")
        self.file_tree.add_node("/project/src/okra.ny", "okra.ny", 2, false, "file")
        self.file_tree.add_node("/project/lib", "📁 lib", 1, false, "folder")
        self.file_tree.add_node("/project/lib/gui.ny", "gui.ny", 2, false, "file")
        self.file_tree.add_node("/project/lib/nytorch.ny", "nytorch.ny", 2, false, "file")
        self.file_tree.add_node("/project/examples", "📁 examples", 1, false, "folder")
        self.file_tree.on_select(self._on_file_select)

        # ── Tab bar ───────────────────────────────────────────────────────────
        self.tab_bar = TabBar(editor_x, content_y, editor_w + self.MINIMAP_W, 34)
        self.tab_bar.add_tab("main.ny")
        self.tab_bar.add_tab("utils.ny")
        self.tab_bar.add_tab("app.ny")
        self.tab_bar.add_tab("okra.ny")
        self.tab_bar.on_select(self._on_tab_select)
        self.tab_bar.on_close(self._on_tab_close)

        # ── Editor ────────────────────────────────────────────────────────────
        var ed_y = content_y + 34
        var ed_h = editor_h - 34
        self.editor = RichEditor(editor_x, ed_y, editor_w, ed_h)
        self.editor.set_buffer(self.buffers[0])
        self.editor.on_change(self._on_edit_change)
        self.editor.on_gutter_click(self._on_gutter_click)

        # ── Minimap ───────────────────────────────────────────────────────────
        self.minimap = MiniMap(editor_x + editor_w, ed_y, self.MINIMAP_W, ed_h)
        self.minimap.set_lines(self.buffers[0].lines)

        # ── Bottom panel system ───────────────────────────────────────────────
        var panel_y = content_y + editor_h
        var panel_w = W - self.ACTIVITY_W
        var pane_x  = self.ACTIVITY_W

        self.panel_tabs_list = ["OUTPUT", "TERMINAL", "PROBLEMS", "DEBUG", "TOKENS", "AST", "PROFILER", "REPL", "LANGDEF"]
        self.active_panel = 0

        # Panel tab strip
        self.panel_tab_strip_y = panel_y
        self.panel_content_y = panel_y + 30
        self.panel_content_h = self.PANEL_H - 30
        self.panel_x = pane_x
        self.panel_w = panel_w

        # ── Output console ────────────────────────────────────────────────────
        self.output = OutputConsole(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.output.write("NythonIDE v3.0 ready", "info")
        self.output.write("Workspace: /project  |  4 files loaded", "info")

        # ── Terminal ──────────────────────────────────────────────────────────
        self.terminal = TerminalPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.terminal.on_command(self._on_terminal_cmd)
        self.terminal.hide()

        # ── Diagnostics ───────────────────────────────────────────────────────
        self.diagnostics = DiagnosticPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.diagnostics.hide()

        # ── Debug panel ───────────────────────────────────────────────────────
        self.debug_panel = DebugPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.debug_panel.on_step(self._on_debug_step)
        self.debug_panel.on_continue(self._on_debug_continue)
        self.debug_panel.on_stop(self._on_debug_stop)
        self.debug_panel.hide()

        # ── Token viewer ──────────────────────────────────────────────────────
        self.token_viewer = TokenViewer(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.token_viewer.hide()

        # ── AST viewer ────────────────────────────────────────────────────────
        self.ast_viewer = ASTViewer(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.ast_viewer.hide()

        # ── Profiler ──────────────────────────────────────────────────────────
        self.profiler = ProfilerPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.profiler.hide()

        # ── REPL ──────────────────────────────────────────────────────────────
        self.repl_panel = REPLPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.repl_panel.hide()

        # ── Language Workshop (LANGDEF panel) ─────────────────────────────
        self.lang_workshop = LangWorkshopPanel(pane_x, self.panel_content_y, panel_w, self.panel_content_h)
        self.lang_workshop.hide()

        # ── AI chat ───────────────────────────────────────────────────────────
        self.chat = ChatPanel(W - 360, content_y, 360, content_h - self.PANEL_H)
        self.chat.on_send(self._on_chat_send)
        self.chat.hide()

        # ── Search ────────────────────────────────────────────────────────────
        self.search = SearchPanel(sidebar_x, content_y, self.SIDEBAR_W, content_h)
        self.search.on_search(self._on_search)
        self.search.hide()

        # ── Git ───────────────────────────────────────────────────────────────
        self.git_panel = GitPanel(sidebar_x, content_y, self.SIDEBAR_W, content_h)
        self.git_panel.on_commit(self._on_git_commit)
        self.git_panel.hide()

        # ── Autocomplete ──────────────────────────────────────────────────────
        self.autocomplete = AutoComplete(0, 0, 320, 200)
        self.autocomplete.hide()
        self._ac_last_word = ""
        self._ac_visible = false

        # ── Status bar ────────────────────────────────────────────────────────
        self.status_y = H - self.STATUS_H
        self.status_branch = "main"
        self.status_lang = "Nython"
        self.status_mode = "READY"
        self.status_ai = "NyxAI ✓"

        # ── Keybind registration ──────────────────────────────────────────────
        self.active_sidebar = "explorer"

    def _load_demo_profiler(self):
        self.profiler.set_total(180.0)
        self.profiler.add_entry("OkraViT.forward", "method", 1000, 95.0, 40.0)
        self.profiler.add_entry("TransformerBlock.forward", "method", 6000, 78.0, 55.0)
        self.profiler.add_entry("MultiheadAttention.forward", "method", 6000, 45.0, 45.0)
        self.profiler.add_entry("LayerNorm.forward", "method", 12000, 22.0, 22.0)
        self.profiler.add_entry("Linear.forward", "method", 24000, 18.0, 18.0)
        self.profiler.add_entry("Dropout.forward", "method", 12000, 8.0, 8.0)
        self.profiler.add_entry("<module>", "module", 1, 180.0, 6.0)

    def _register_commands(self):
        self.spotlight.add_item("▶  Run File", "run-file")
        self.spotlight.add_item("⬤  Debug File", "debug-file")
        self.spotlight.add_item("⟨⟩  Show Tokens", "tokenize")
        self.spotlight.add_item("🌲  Show AST", "show-ast")
        self.spotlight.add_item("≋  Disassemble", "disasm")
        self.spotlight.add_item("»  Open REPL", "open-repl")
        self.spotlight.add_item("⏱  Profile Run", "profile")
        self.spotlight.add_item("📁  Explorer", "sidebar-explorer")
        self.spotlight.add_item("🔍  Find in Files", "sidebar-search")
        self.spotlight.add_item("⎇  Source Control", "sidebar-git")
        self.spotlight.add_item("✦  NyxAI Chat", "sidebar-ai")
        self.spotlight.add_item("🔧  Format File", "format")
        self.spotlight.add_item("?  Keyboard Shortcuts", "keybinds")
        self.spotlight.add_item("🔤  Language Workshop", "lang-workshop")
        self.spotlight.add_item("🎊  Celebrate!", "confetti")
        self.spotlight.add_item("➕  New File", "new-file")
        self.spotlight.add_item("🗑  Close Tab", "close-tab")
        self.spotlight.add_item("⬆  Previous Tab", "prev-tab")
        self.spotlight.add_item("⬇  Next Tab", "next-tab")
        self.spotlight.add_item("🔆  Toggle Minimap", "toggle-minimap")
        self.spotlight.add_item("💡  Analyze Code", "analyze")
        self.spotlight.on_select(self._on_spotlight_cmd)

    def _register_keybinds(self):
        self.keybind_panel.add_row("⌘P", "Open Spotlight / Command Palette")
        self.keybind_panel.add_row("⌘↵", "Run current file")
        self.keybind_panel.add_row("F5", "Debug current file")
        self.keybind_panel.add_row("F6", "Tokenize current file")
        self.keybind_panel.add_row("F7", "Show AST")
        self.keybind_panel.add_row("F8", "Disassemble")
        self.keybind_panel.add_row("F9", "Open REPL")
        self.keybind_panel.add_row("F10", "Profile run")
        self.keybind_panel.add_row("⌘⇧F", "Find in files")
        self.keybind_panel.add_row("⌘⇧G", "Source control")
        self.keybind_panel.add_row("⌘⇧A", "NyxAI chat")
        self.keybind_panel.add_row("⌘⇧D", "Toggle debug panel")
        self.keybind_panel.add_row("⌘1–4", "Switch editor tab")
        self.keybind_panel.add_row("?", "Show this keybinds panel")
        self.keybind_panel.add_row("F11", "Language Workshop")
        self.keybind_panel.add_row("Esc", "Close overlay / panel")
        self.keybind_panel.add_row("Tab", "Indent (4 spaces)")
        self.keybind_panel.add_row("Home", "Smart Home (indent/start)")
        self.keybind_panel.add_row("End", "End of line")
        self.keybind_panel.add_row("↑↓", "Navigate lines / REPL history")
        self.keybind_panel.add_row("⌘K", "Open Spotlight (alias)")

    def _on_mode_change(self, idx, name):
        self.last_mode = idx
        self.status_mode = string_upper(name)
        self._switch_panel_for_mode(idx)

    def _switch_panel_for_mode(self, mode):
        if mode == 1:
            self._show_panel(3)
        elif mode == 2:
            self._show_panel(4)
        elif mode == 3:
            self._show_panel(5)
        elif mode == 5:
            self._show_panel(7)
        elif mode == 6:
            self._show_panel(6)

    def _show_panel(self, idx):
        self.active_panel = idx
        self.output.hide()
        self.terminal.hide()
        self.diagnostics.hide()
        self.debug_panel.hide()
        self.token_viewer.hide()
        self.ast_viewer.hide()
        self.profiler.hide()
        self.repl_panel.hide()
        self.lang_workshop.hide()
        if idx == 0: self.output.show()
        elif idx == 1: self.terminal.show()
        elif idx == 2: self.diagnostics.show()
        elif idx == 3: self.debug_panel.show()
        elif idx == 4: self.token_viewer.show()
        elif idx == 5: self.ast_viewer.show()
        elif idx == 6: self.profiler.show()
        elif idx == 7: self.repl_panel.show()
        elif idx == 8: self.lang_workshop.show()

    def _on_run(self, mode_idx, mode_name):
        if self.buf_count == 0: return
        var buf = self.buffers[self.active_buf]
        self.status_mode = "RUNNING…"
        self.is_running = true
        if mode_idx == 0:
            self._run_file(buf)
        elif mode_idx == 1:
            self._debug_file(buf)
        elif mode_idx == 2:
            self._tokenize_file(buf)
        elif mode_idx == 3:
            self._ast_file(buf)
        elif mode_idx == 4:
            self._disasm_file(buf)
        elif mode_idx == 5:
            self._show_panel(7)
            self.repl_panel.show()
            self.status_mode = "REPL"
        elif mode_idx == 6:
            self._profile_file(buf)
        self.is_running = false

    def _run_file(self, buf):
        self._show_panel(0)
        self.output.clear()
        var engine = "interpreter"
        if self.use_vm:
            engine = "bytecode VM"
        var cmd = "nython "
        if self.use_vm:
            cmd = "nython --vm "
        self.output.write("$ " + cmd + buf.name, "cmd")
        self.output.write("engine: " + engine, "info")

        var res = self.toolchain.run(buf.get_all_text(), buf.name, self.use_vm)

        var i = 0
        while i < res.line_count:
            var ln = res.lines[i]
            var kind = "stdout"
            var low = string_lower(ln)
            if string_find(low, "error") >= 0 or string_find(low, "exception") >= 0:
                kind = "err"
            self.output.write(ln, kind)
            i = i + 1

        self.run_elapsed_ms = res.ms
        self.output.write("", "stdout")
        if res.ok:
            self.output.write("Process finished with exit code 0  (" + str(res.ms) + " ms)", "ok")
            self.status_mode = "DONE"
            self.toast_mgr.show("Ran " + buf.name, "success", 2200)
            self.notif_bell.add("Ran " + buf.name + " — exit 0", "ok")
            self._trigger_confetti_brief()
        else:
            self.output.write("Process finished with exit code " + str(res.exit_code)
                              + "  (" + str(res.ms) + " ms)", "err")
            self.status_mode = "FAILED"
            self.toast_mgr.show("Run failed: " + buf.name, "error", 3200)
            self.notif_bell.add("Run failed — exit " + str(res.exit_code), "err")
        self._refresh_diagnostics(buf)

    # Compile-only pass; populates the PROBLEMS panel from real compiler output.
    def _refresh_diagnostics(self, buf):
        var ds = self.toolchain.diagnose(buf.get_all_text(), buf.name)
        self.diagnostics.clear()
        var i = 0
        while i < len(ds):
            if ds[i].severity == "warning":
                self.diagnostics.add_warning(buf.name, ds[i].line, 0, ds[i].message)
            else:
                self.diagnostics.add_error(buf.name, ds[i].line, 0, ds[i].message)
            i = i + 1
        self.problem_count = len(ds)
        return len(ds)

    def _debug_file(self, buf):
        self._show_panel(3)
        self.debug_panel.show()
        self.debug_panel.running = true
        self.debug_panel.paused = true
        self.debug_panel.current_file = buf.name
        self.debug_panel.current_line = 1
        self.debug_panel.clear_stack()
        self.debug_panel.push_frame("<module>", buf.name, 1)
        var i = 0
        while i < buf.line_count:
            var ln = string_strip(buf.get_line(i))
            if string_startswith(ln, "def ") or string_startswith(ln, "class "):
                var name = ln[4:]
                var end = string_find(name, "(")
                if end < 0: end = string_find(name, ":")
                var name2 = name
                if end >= 0:
                    name2 = name[0:end]
                name = name2
                self.debug_panel.push_frame(name, buf.name, i + 1)
            i = i + 1
        self.status_mode = "DEBUG — PAUSED"
        self.toast_mgr.show("⬤ Debug session started", "info", 2500)

    def _tokenize_file(self, buf):
        # Was a re-implementation of the lexer in Nython (SyntaxHighlighter over
        # buffer lines), so it showed approximate tokens that could disagree with
        # the real one. Now uses `nython -t`, whose XML the viewer already parses.
        self._show_panel(4)
        var res = self.toolchain.tokenize(buf.get_all_text(), buf.name)
        if not res.ok:
            self.output.write("tokenize failed (exit " + str(res.exit_code) + ")", "err")
            self._show_panel(0)
            return 0
        var xml = ""
        var i = 0
        while i < res.line_count:
            xml = xml + res.lines[i] + "\n"
            i = i + 1
        self.token_viewer.parse_xml(xml)
        self.status_mode = "TOKENS"
        self.run_elapsed_ms = res.ms
        self.toast_mgr.show("Tokenized " + buf.name, "info", 2000)
        return self.token_viewer.token_count

    def _ast_tag_for_line(self, ln):
        if string_startswith(ln, "class "):
            var cn = ln[6:]
            var ce = string_find(cn, ":")
            var cn2 = cn
            if ce >= 0:
                cn2 = cn[0:ce]
            return "<Class name=\"" + string_strip(cn2) + "\">" + "\n      </Class>"
        if string_startswith(ln, "def "):
            var fn = ln[4:]
            var fe = string_find(fn, "(")
            var fn2 = fn
            if fe >= 0:
                fn2 = fn[0:fe]
            return "<Function name=\"" + string_strip(fn2) + "\">" + "\n      </Function>"
        if string_startswith(ln, "var "):
            var vn = ln[4:]
            var ve = string_find(vn, " ")
            var vn2 = vn
            if ve >= 0:
                vn2 = vn[0:ve]
            return "<VarDecl name=\"" + string_strip(vn2) + "\"/>"
        if string_startswith(ln, "import "):
            return "<Import path=\"" + ln[7:] + "\"/>"
        return ""


    def _ast_file(self, buf):
        # Was hand-built XML from line-prefix guesses; now the parser's own tree.
        self._show_panel(5)
        var res = self.toolchain.ast(buf.get_all_text(), buf.name)
        if not res.ok:
            self.output.write("parse failed (exit " + str(res.exit_code) + ")", "err")
            var k = 0
            while k < res.line_count:
                self.output.write(res.lines[k], "err")
                k = k + 1
            self._show_panel(0)
            self._refresh_diagnostics(buf)
            return 0
        var xml = ""
        var i = 0
        while i < res.line_count:
            xml = xml + res.lines[i] + "\n"
            i = i + 1
        self.ast_xml = xml
        self.ast_viewer.parse_xml(xml)
        self.status_mode = "AST"
        self.run_elapsed_ms = res.ms
        self.toast_mgr.show("Parsed " + buf.name, "info", 2000)
        return self.ast_viewer.node_count

    def _disasm_file(self, buf):
        # Was one invented "EXEC" line per source line. Now the VM's real
        # bytecode listing, constants pool and all.
        self._show_panel(0)
        self.output.clear()
        self.output.write("$ nython --disasm " + buf.name, "cmd")
        var res = self.toolchain.disasm(buf.get_all_text(), buf.name)
        var i = 0
        while i < res.line_count:
            var kind = "stdout"
            if string_find(string_lower(res.lines[i]), "error") >= 0:
                kind = "err"
            self.output.write(res.lines[i], kind)
            i = i + 1
        self.run_elapsed_ms = res.ms
        if res.ok:
            self.output.write("", "stdout")
            self.output.write(str(res.line_count) + " lines  (" + str(res.ms) + " ms)", "ok")
        self.status_mode = "DISASM"
        return res.line_count

    def _profile_file(self, buf):
        # Was fabricated: it scanned for "def " lines and invented a duration for
        # each. These numbers are measured by the interpreter itself under
        # --profile, so the hot spot shown is the real hot spot.
        self._show_panel(6)
        self.profiler.clear()
        var res = self.toolchain.profile(buf.get_all_text(), buf.name)

        if not res.ok:
            self._show_panel(0)
            self.output.write("profile run failed (exit " + str(res.exit_code) + ")", "err")
            var e = 0
            var prog = self.toolchain.split_program_output(res)
            while e < len(prog):
                self.output.write(prog[e], "err")
                e = e + 1
            self._refresh_diagnostics(buf)
            return 0

        var total = 0.0
        var i = 0
        while i < res.profile_count:
            total = total + res.profile_rows[i][3]
            i = i + 1

        i = 0
        while i < res.profile_count:
            var row = res.profile_rows[i]
            var kind = "function"
            if string_find(row[0], ".") >= 0:
                kind = "method"
            self.profiler.add_entry(row[0], kind, row[1], row[2], row[3])
            i = i + 1

        self.run_elapsed_ms = res.ms
        self.status_mode = "PROFILE"
        if res.profile_count == 0:
            self.toast_mgr.show("No function calls to profile", "info", 2200)
        else:
            self.toast_mgr.show("Profiled " + str(res.profile_count) + " functions ("
                                + str(int(total)) + " ms)", "success", 2600)
        return res.profile_count

    def _trigger_confetti_brief(self):
        self.confetti.burst(800, 400, 80)
        self.show_confetti = true

    def _on_edit_change(self, buf):
        var idx = self.active_buf
        if idx < len(self.tab_bar.tabs):
            self.tab_bar.tabs[idx].modified = true
        self.minimap.set_lines(buf.lines)

    def _on_gutter_click(self, line_num):
        var buf = self.buffers[self.active_buf]
        var file = buf.name
        self.debug_panel.add_breakpoint(file, line_num)
        self.activity.items[3].badge = self.debug_panel.bp_count
        self.toast_mgr.show("⬤ Breakpoint at line " + str(line_num), "info", 2000)

    def _on_tab_select(self, idx):
        if idx >= 0 and idx < self.buf_count:
            self.active_buf = idx
            self.editor.set_buffer(self.buffers[idx])
            self.minimap.set_lines(self.buffers[idx].lines)

    def _on_tab_close(self, idx):
        if self.buf_count <= 1: return
        var kept = []
        var i = 0
        while i < self.buf_count:
            if i != idx:
                kept = kept + [self.buffers[i]]
            i = i + 1
        self.buffers = kept
        self.buf_count = self.buf_count - 1
        if self.active_buf >= self.buf_count:
            self.active_buf = self.buf_count - 1
        self.editor.set_buffer(self.buffers[self.active_buf])

    def _on_file_select(self, path):
        var name = path
        var slash = string_find(path, "/")
        while slash >= 0:
            name = path[slash + 1:]
            var next = string_find(name, "/")
            if next < 0: slash = -1
            else:
                var path = name
                slash = string_find(path, "/")
        var i = 0
        while i < self.buf_count:
            if self.buffers[i].name == name:
                self.active_buf = i
                self.tab_bar.active = i
                self.editor.set_buffer(self.buffers[i])
                self.minimap.set_lines(self.buffers[i].lines)
                return
            i = i + 1
        self.toast_mgr.show("📄 " + name, "info", 1500)

    def _on_activity(self, idx, label):
        if idx == 0:
            self.active_sidebar = "explorer"
            self.file_tree.show()
            self.search.hide()
            self.git_panel.hide()
            self.chat.hide()
        elif idx == 1:
            self.active_sidebar = "search"
            self.file_tree.hide()
            self.search.show()
            self.git_panel.hide()
            self.chat.hide()
        elif idx == 2:
            self.active_sidebar = "git"
            self.file_tree.hide()
            self.search.hide()
            self.git_panel.show()
            self.chat.hide()
        elif idx == 4:
            self.active_sidebar = "ai"
            self.file_tree.hide()
            self.search.hide()
            self.git_panel.hide()
            self.chat.show()

    def _on_terminal_cmd(self, cmd):
        var parts = string_split(string_strip(cmd), " ")
        if len(parts) == 0: return
        var prog = parts[0]
        if prog == "run" and len(parts) > 1:
            self._run_file(self.buffers[self.active_buf])
            self._show_panel(1)
            self.terminal.show()
        elif prog == "tokenize" and len(parts) > 1:
            self.run_bar.active_mode = 2
            self._tokenize_file(self.buffers[self.active_buf])
        elif prog == "ast" and len(parts) > 1:
            self.run_bar.active_mode = 3
            self._ast_file(self.buffers[self.active_buf])
        elif prog == "disasm" and len(parts) > 1:
            self.run_bar.active_mode = 4
            self._disasm_file(self.buffers[self.active_buf])
        elif prog == "profile" and len(parts) > 1:
            self.run_bar.active_mode = 6
            self._profile_file(self.buffers[self.active_buf])
        elif prog == "repl":
            self._show_panel(7)
            self.repl_panel.show()
        elif prog == "clear":
            self.terminal.lines = []
            self.terminal.line_count = 0
        elif prog == "help":
            self.terminal.write("run <file>       — run current buffer", "output")
            self.terminal.write("tokenize <file>  — show token stream", "output")
            self.terminal.write("ast <file>       — show AST", "output")
            self.terminal.write("disasm <file>    — disassemble", "output")
            self.terminal.write("profile <file>   — profile execution", "output")
            self.terminal.write("repl             — open interactive REPL", "output")
            self.terminal.write("clear            — clear terminal", "output")
        elif prog == "ls":
            var i = 0
            while i < self.buf_count:
                self.terminal.write("  " + self.buffers[i].name, "output")
                i = i + 1
        else:
            self.terminal.write("Unknown command: " + prog + "  (type help)", "error")

    def _on_debug_step(self, kind):
        self.debug_panel.current_line = self.debug_panel.current_line + 1
        self.toast_mgr.show("⬇ Step " + kind, "info", 800)

    def _on_debug_continue(self):
        self.debug_panel.paused = false
        self.debug_panel.running = false
        self.status_mode = "DONE"
        self.toast_mgr.show("▶ Continued — execution resumed", "ok", 1500)

    def _on_debug_stop(self):
        self.debug_panel.paused = false
        self.debug_panel.running = false
        self.debug_panel.clear_stack()
        self.status_mode = "STOPPED"
        self.toast_mgr.show("■ Debug session ended", "warn", 1500)

    def _repl_execute(self, expr):
        # Was pattern-matching: "2 + 2" printed "<expression>" and `print x`
        # echoed the source text. This evaluates for real by replaying the
        # session's declarations and printing the new expression, so values,
        # errors and side effects are the language's own.
        var stripped = string_strip(expr)
        if stripped == "":
            return 0

        if stripped == ":clear" or stripped == ":reset":
            self.repl_history = []
            self.repl_panel.write("session reset", "ok")
            return 0

        var is_decl = false
        for kw in ["var ", "def ", "class ", "import ", "func "]:
            if string_startswith(stripped, kw):
                is_decl = true

        var prelude = ""
        var i = 0
        while i < len(self.repl_history):
            prelude = prelude + self.repl_history[i] + "\n"
            i = i + 1

        var program = prelude
        if is_decl:
            program = program + stripped + "\n"
        else:
            program = program + "print(" + stripped + ")\n"

        var res = self.toolchain.run(program, "repl.ny", self.use_vm)

        if not res.ok:
            var j = 0
            while j < res.line_count:
                self.repl_panel.write(res.lines[j], "err")
                j = j + 1
            return 0

        # A declaration only joins the session once it compiles cleanly, so a
        # broken line cannot poison every later evaluation.
        if is_decl:
            self.repl_history = self.repl_history + [stripped]
            self.repl_panel.write("defined", "ok")
            return 0

        var k = 0
        while k < res.line_count:
            self.repl_panel.write(res.lines[k], "result")
            k = k + 1
        return res.line_count

    def _on_chat_send(self, text):
        var lower = string_lower(text)
        if string_find(lower, "token") >= 0:
            self.chat.add_message("NyxAI: Switching to token view and tokenizing active file…", false)
            self.run_bar.active_mode = 2
            self._tokenize_file(self.buffers[self.active_buf])
        elif string_find(lower, "ast") >= 0:
            self.chat.add_message("NyxAI: Generating AST for " + self.buffers[self.active_buf].name + "…", false)
            self.run_bar.active_mode = 3
            self._ast_file(self.buffers[self.active_buf])
        elif string_find(lower, "debug") >= 0 or string_find(lower, "breakpoint") >= 0:
            self.chat.add_message("NyxAI: Starting debug session. Breakpoints are visible in the Debug panel.", false)
            self._debug_file(self.buffers[self.active_buf])
        elif string_find(lower, "profile") >= 0 or string_find(lower, "slow") >= 0 or string_find(lower, "perf") >= 0:
            self.chat.add_message("NyxAI: Running profiler. Check the PROFILER tab for hotspots.", false)
            self._profile_file(self.buffers[self.active_buf])
        elif string_find(lower, "run") >= 0 or string_find(lower, "execute") >= 0:
            self.chat.add_message("NyxAI: Running " + self.buffers[self.active_buf].name + "…", false)
            self._run_file(self.buffers[self.active_buf])
        elif string_find(lower, "repl") >= 0:
            self.chat.add_message("NyxAI: Opening REPL panel. Type expressions and press Enter.", false)
            self._show_panel(7)
            self.repl_panel.show()
        elif string_find(lower, "disasm") >= 0 or string_find(lower, "bytecode") >= 0:
            self.chat.add_message("NyxAI: Disassembling " + self.buffers[self.active_buf].name + "…", false)
            self._disasm_file(self.buffers[self.active_buf])
        elif string_find(lower, "help") >= 0:
            self.chat.add_message("NyxAI: I can help you run, debug, tokenize, inspect AST, disassemble, profile, or use the REPL. Just ask!", false)
        else:
            self.chat.add_message("NyxAI: I see you're working on " + self.buffers[self.active_buf].name + ". Try asking me to run, debug, tokenize, show AST, disassemble, or profile your code.", false)

    def _on_search(self, query):
        if len(query) < 2: return
        self.search.clear_results()
        var i = 0
        while i < self.buf_count:
            var buf = self.buffers[i]
            var j = 0
            while j < buf.line_count:
                var ln = buf.get_line(j)
                if string_find(ln, query) >= 0:
                    self.search.add_result(buf.name, j + 1, string_strip(ln))
                j = j + 1
            i = i + 1

    def _on_git_commit(self, msg):
        if len(string_strip(msg)) == 0:
            self.toast_mgr.show("⚠ Commit message required", "warn", 2000)
            return
        self.git_panel.changes = []
        self.git_panel.change_count = 0
        self.activity.items[2].badge = 0
        self.toast_mgr.show("⎇ Committed: " + msg, "success", 2500)
        self.notif_bell.add("Committed: " + msg, "ok")
        self._trigger_confetti_brief()

    def _on_spotlight_cmd(self, label, action):
        self.spotlight.visible = false
        if action == "run-file":
            self.run_bar.active_mode = 0
            self._on_run(0, "Run")
        elif action == "debug-file":
            self.run_bar.active_mode = 1
            self._on_run(1, "Debug")
        elif action == "tokenize":
            self.run_bar.active_mode = 2
            self._on_run(2, "Tokenize")
        elif action == "show-ast":
            self.run_bar.active_mode = 3
            self._on_run(3, "AST")
        elif action == "disasm":
            self.run_bar.active_mode = 4
            self._on_run(4, "Disasm")
        elif action == "open-repl":
            self.run_bar.active_mode = 5
            self._show_panel(7)
            self.repl_panel.show()
        elif action == "profile":
            self.run_bar.active_mode = 6
            self._on_run(6, "Profile")
        elif action == "sidebar-explorer":
            self._on_activity(0, "Explorer")
        elif action == "sidebar-search":
            self._on_activity(1, "Search")
        elif action == "sidebar-git":
            self._on_activity(2, "Source Control")
        elif action == "sidebar-ai":
            self._on_activity(4, "NyxAI")
        elif action == "format":
            self.toast_mgr.show("🔧 Formatted " + self.buffers[self.active_buf].name, "ok", 2000)
        elif action == "keybinds":
            self.show_keybinds = true
            self.keybind_panel.visible = true
        elif action == "lang-workshop":
            self._show_panel(8)
        elif action == "confetti":
            self._trigger_confetti_brief()
        elif action == "new-file":
            self._add_buffer("untitled.ny", "# New file\n\n", "/project/untitled.ny")
            self.tab_bar.add_tab("untitled.ny")
            self.active_buf = self.buf_count - 1
            self.editor.set_buffer(self.buffers[self.active_buf])
        elif action == "close-tab":
            self._on_tab_close(self.active_buf)
        elif action == "prev-tab":
            if self.active_buf > 0:
                self.active_buf = self.active_buf - 1
                self.tab_bar.active = self.active_buf
                self.editor.set_buffer(self.buffers[self.active_buf])
        elif action == "next-tab":
            if self.active_buf < self.buf_count - 1:
                self.active_buf = self.active_buf + 1
                self.tab_bar.active = self.active_buf
                self.editor.set_buffer(self.buffers[self.active_buf])
        elif action == "toggle-minimap":
            if self.minimap.visible:
                self.minimap.hide()
            else:
                self.minimap.show()
        elif action == "analyze":
            self._analyze_code()

    def _analyze_code(self):
        self._show_panel(2)
        self.diagnostics.show()
        self.diagnostics.items = []
        self.diagnostics.item_count = 0
        var buf = self.buffers[self.active_buf]
        var i = 0
        while i < buf.line_count:
            var ln = buf.get_line(i)
            var stripped = string_strip(ln)
            if string_find(ln, "print") >= 0 and string_find(ln, "print ") < 0 and string_find(ln, "#") < 0:
                self.diagnostics.add_item(buf.name, i + 1, "warn", "print without space — use 'print expr'")
            if string_find(stripped, "  ") >= 0 and string_startswith(stripped, "def "):
                self.diagnostics.add_item(buf.name, i + 1, "info", "Double space found in def signature")
            if len(stripped) > 120:
                self.diagnostics.add_item(buf.name, i + 1, "info", "Line exceeds 120 characters (" + str(len(stripped)) + ")")
            if string_find(stripped, "TODO") >= 0:
                self.diagnostics.add_item(buf.name, i + 1, "info", "TODO: " + stripped)
            i = i + 1
        if self.diagnostics.item_count == 0:
            self.diagnostics.add_item(buf.name, 0, "ok", "No issues found — code looks clean!")
        self.activity.items[3].badge = self.diagnostics.item_count
        self.toast_mgr.show("💡 Analysis: " + str(self.diagnostics.item_count) + " issue(s)", "info", 2500)

    def _draw_panel_tab_strip(self, renderer):
        var W = 1600
        renderer.fill_rect(Rect(self.panel_x, self.panel_tab_strip_y, self.panel_w, 30), Color(14, 16, 28, 255))
        renderer.draw_line(self.panel_x, self.panel_tab_strip_y, self.panel_x + self.panel_w, self.panel_tab_strip_y, Color(255,255,255,8), 1)
        var accent = Color(99, 102, 241, 255)
        var font_tab = Font("sans-serif", 11, false, false)
        var font_bold = Font("sans-serif", 11, true, false)
        var tw = 98
        var i = 0
        while i < len(self.panel_tabs_list):
            var tx = self.panel_x + i * tw
            var ty = self.panel_tab_strip_y
            if i == self.active_panel:
                renderer.fill_rect(Rect(tx, ty + 28, tw, 2), accent)
                renderer.draw_text(self.panel_tabs_list[i], tx + 8, ty + 8, font_bold, Color(accent.r, accent.g, accent.b, 230))
            else:
                renderer.draw_text(self.panel_tabs_list[i], tx + 8, ty + 8, font_tab, Color(100, 102, 140, 160))
            if i > 0:
                renderer.draw_line(tx, ty + 4, tx, ty + 26, Color(255,255,255,8), 1)
            i = i + 1

    def _draw_status_bar(self, renderer):
        var W = 1600
        renderer.fill_rect(Rect(0, self.status_y, W, self.STATUS_H), Color(10, 12, 22, 255))
        renderer.draw_line(0, self.status_y, W, self.status_y, Color(255,255,255,10), 1)
        renderer.fill_rect(Rect(0, self.status_y, 110, self.STATUS_H), Color(99, 102, 241, 40))
        var font_s = Font("sans-serif", 11, false, false)
        var font_b = Font("sans-serif", 11, true, false)
        var y = self.status_y + 6
        renderer.draw_text("⎇ " + self.status_branch, 10, y, font_b, Color(180, 182, 240, 230))
        renderer.draw_text(self.status_lang, 120, y, font_s, Color(130, 132, 180, 190))
        renderer.draw_text("Mode: " + self.status_mode, 200, y, font_s, Color(120, 122, 160, 160))
        if self.buf_count > 0:
            var buf = self.buffers[self.active_buf]
            renderer.draw_text("Ln " + str(buf.cursor_row + 1) + " Col " + str(buf.cursor_col + 1), W - 280, y, font_s, Color(100, 102, 140, 160))
            var stats = buf.get_stats()
            renderer.draw_text(str(stats["lines"]) + "L  " + str(stats["words"]) + "W  " + str(stats["chars"]) + "ch", W - 190, y, font_s, Color(80, 82, 120, 130))
        renderer.draw_text(self.status_ai, W - 80, y, font_b, Color(99, 102, 241, 220))

    # Rebuild the hover map and push the right pointer shape. Called on every
    # mouse move so the cursor tracks what is actually under it.
    def _update_cursor(self, mx, my):
        var content_y = self.TOOLBAR_H
        var content_h = self.win_h - self.TOOLBAR_H - self.STATUS_H
        self.cursors.begin()

        # Clickable chrome -> hand, the way every editor signals "this is a
        # control" rather than a decoration.
        self.cursors.add(Rect(0, 0, self.win_w, self.TOOLBAR_H), "hand")
        self.cursors.add(Rect(0, content_y, self.ACTIVITY_W, content_h), "hand")
        self.cursors.add(Rect(self.ACTIVITY_W, content_y, self.SIDEBAR_W, content_h), "hand")
        self.cursors.add(Rect(self.editor.rect.x, content_y, self.editor.rect.w + self.MINIMAP_W, 34), "hand")
        self.cursors.add(Rect(self.panel_x, self.panel_tab_strip_y, self.panel_w, 30), "hand")
        self.cursors.add(Rect(0, self.win_h - self.STATUS_H, self.win_w, self.STATUS_H), "hand")

        # Text surfaces -> I-beam.
        self.cursors.add(self.editor.rect, "ibeam")
        self.cursors.add(Rect(self.panel_x, self.panel_content_y, self.panel_w, self.panel_content_h), "ibeam")

        # Minimap is a navigation strip, not text.
        self.cursors.add(self.minimap.rect, "hand")

        # Splitters win over everything they overlap.
        self.cursors.add_p(self._sidebar_split_rect(), "sizewe", 20)
        self.cursors.add_p(self._panel_split_rect(), "sizens", 20)

        self.cursors.apply(mx, my)

    # Round a design-pixel metric to whole device pixels.
    def scaled(self, v):
        return int(float(v) * self.dpi + 0.5)

    def _sidebar_split_rect(self):
        var x = self.ACTIVITY_W + self.SIDEBAR_W - self.SPLIT_HIT
        return Rect(x, self.TOOLBAR_H, self.SPLIT_HIT * 2,
                    self.win_h - self.TOOLBAR_H - self.STATUS_H)

    def _panel_split_rect(self):
        var y = self.panel_tab_strip_y - self.SPLIT_HIT
        return Rect(self.ACTIVITY_W, y, self.win_w - self.ACTIVITY_W, self.SPLIT_HIT * 2)

    def handle_event(self, event):
        # ── pane splitter drag ───────────────────────────────────────────────
        if event.type == "mousedown":
            if self._sidebar_split_rect().contains(event.x, event.y):
                self.drag_split = "sidebar"
                self.drag_origin = event.x
                self.drag_start_v = self.SIDEBAR_W
                self.cursors.lock("sizewe")
                event.consume()
                return
            if self._panel_split_rect().contains(event.x, event.y):
                self.drag_split = "panel"
                self.drag_origin = event.y
                self.drag_start_v = int(self.editor_ratio * 1000.0)
                self.cursors.lock("sizens")
                event.consume()
                return

        if self.drag_split != "":
            if event.type == "mousemove":
                if self.drag_split == "sidebar":
                    var w = self.drag_start_v + (event.x - self.drag_origin)
                    if w < 140:
                        w = 140
                    if w > self.win_w - self.ACTIVITY_W - 320:
                        w = self.win_w - self.ACTIVITY_W - 320
                    self.SIDEBAR_W = w
                else:
                    var content_h = self.win_h - self.TOOLBAR_H - self.STATUS_H
                    var delta = event.y - self.drag_origin
                    var ratio = (float(self.drag_start_v) / 1000.0) + (float(delta) / float(content_h))
                    if ratio < 0.20:
                        ratio = 0.20
                    if ratio > 0.85:
                        ratio = 0.85
                    self.editor_ratio = ratio
                self._relayout(self.win_w, self.win_h)
                event.consume()
                return
            if event.type == "mouseup":
                self.drag_split = ""
                self.cursors.unlock()
                event.consume()
                return

        if event.type == "mousemove":
            self._update_cursor(event.x, event.y)

        if self.show_confetti:
            self.confetti.handle_event(event)
        if self.spotlight.visible:
            self.spotlight.handle_event(event)
            if event.consumed: return
        if self.show_keybinds:
            if event.type == "keydown" and event.key == "escape":
                self.show_keybinds = false
                self.keybind_panel.visible = false
                event.consume()
                return
            self.keybind_panel.handle_event(event)
            if event.consumed: return
        if event.type == "keydown":
            if event.key == "p" and event.ctrl:
                self.spotlight.visible = true
                event.consume()
                return
            if event.key == "k" and event.ctrl:
                self.spotlight.visible = true
                event.consume()
                return
            if event.key == "?" or event.key == "slash" and event.shift:
                self.show_keybinds = not self.show_keybinds
                self.keybind_panel.visible = self.show_keybinds
                event.consume()
                return
            if event.key == "escape":
                self.spotlight.visible = false
                self.show_keybinds = false
                self.keybind_panel.visible = false
                self._ac_hide()
                event.consume()
                return
            if event.key == "enter" and event.ctrl:
                self._on_run(self.run_bar.active_mode, self.run_bar.modes[self.run_bar.active_mode])
                event.consume()
                return
            if event.key == "f5":
                self.run_bar.active_mode = 1
                self._on_run(1, "Debug")
                event.consume()
                return
            if event.key == "f6":
                self.run_bar.active_mode = 2
                self._on_run(2, "Tokenize")
                event.consume()
                return
            if event.key == "f7":
                self.run_bar.active_mode = 3
                self._on_run(3, "AST")
                event.consume()
                return
            if event.key == "f8":
                self.run_bar.active_mode = 4
                self._on_run(4, "Disasm")
                event.consume()
                return
            if event.key == "f9":
                self.run_bar.active_mode = 5
                self._show_panel(7)
                self.repl_panel.show()
                event.consume()
                return
            if event.key == "f10":
                self.run_bar.active_mode = 6
                self._on_run(6, "Profile")
                event.consume()
                return
            if event.key == "f11":
                self._show_panel(8)
                event.consume()
                return
        if event.type == "mousedown":
            var panel_strip_h = 30
            var py = self.panel_tab_strip_y
            var px = self.panel_x
            var pw = self.panel_w
            if event.y >= py and event.y < py + panel_strip_h and event.x >= px and event.x < px + pw:
                var tw = 98
                var tidx = int((event.x - px) / tw)
                if tidx >= 0 and tidx < len(self.panel_tabs_list):
                    self._show_panel(tidx)
                    event.consume()
                    return
        self.run_bar.handle_event(event)
        if event.consumed: return
        self.activity.handle_event(event)
        if event.consumed: return
        if self.active_sidebar == "explorer":
            self.file_tree.handle_event(event)
        elif self.active_sidebar == "search":
            self.search.handle_event(event)
        elif self.active_sidebar == "git":
            self.git_panel.handle_event(event)
        elif self.active_sidebar == "ai":
            self.chat.handle_event(event)
        if event.consumed: return
        self.tab_bar.handle_event(event)
        if event.consumed: return
        self.editor.handle_event(event)
        self.minimap.handle_event(event)
        self.output.handle_event(event)
        self.terminal.handle_event(event)
        self.diagnostics.handle_event(event)
        self.debug_panel.handle_event(event)
        self.token_viewer.handle_event(event)
        self.ast_viewer.handle_event(event)
        self.profiler.handle_event(event)
        self.repl_panel.handle_event(event)
        self.lang_workshop.handle_event(event)
        self.notif_bell.handle_event(event)
        self.autocomplete.handle_event(event)
        self.toast_mgr.handle_event(event)

    def _ac_hide(self):
        self._ac_visible = false
        self.autocomplete.hide()

    def draw(self, renderer):
        var W = 1600
        var H = 960
        renderer.fill_rect(Rect(0, 0, W, H), Color(16, 18, 32, 255))
        self.run_bar.draw(renderer)
        self.activity.draw(renderer)
        if self.active_sidebar == "explorer":
            self.file_tree.draw(renderer)
        elif self.active_sidebar == "search":
            self.search.draw(renderer)
        elif self.active_sidebar == "git":
            self.git_panel.draw(renderer)
        elif self.active_sidebar == "ai":
            self.chat.draw(renderer)
        self.tab_bar.draw(renderer)
        self.editor.draw(renderer)
        self.minimap.draw(renderer)
        self._draw_panel_tab_strip(renderer)
        self.output.draw(renderer)
        self.terminal.draw(renderer)
        self.diagnostics.draw(renderer)
        self.debug_panel.draw(renderer)
        self.token_viewer.draw(renderer)
        self.ast_viewer.draw(renderer)
        self.profiler.draw(renderer)
        self.repl_panel.draw(renderer)
        self.lang_workshop.draw(renderer)
        self._draw_status_bar(renderer)
        self.chat.draw(renderer)
        self.notif_bell.draw(renderer)
        self.toast_mgr.draw(renderer)
        self.autocomplete.draw(renderer)
        if self.spotlight.visible:
            renderer.fill_rect(Rect(0, 0, W, H), Color(0, 0, 0, 120))
            self.spotlight.draw(renderer)
        if self.show_keybinds:
            renderer.fill_rect(Rect(0, 0, W, H), Color(0, 0, 0, 140))
            self.keybind_panel.draw(renderer)
        if self.show_confetti:
            self.confetti.draw(renderer)
            self.show_confetti = self.confetti.active

    def _main_loop(self, renderer, event):
        self.handle_event(event)
        self.draw(renderer)

    # ── Responsive relayout ──────────────────────────────────────────────────
    # Nothing repositioned itself when the window changed size: every widget kept
    # the coordinates it was constructed with, so resizing left the UI pinned to
    # the original 1600x960 geometry. This recomputes the same geometry
    # _build_layout uses and pushes it into the existing widgets, preserving
    # buffers, tabs and terminal history (rebuilding them would discard state).
    def _relayout(self, win_w, win_h):
        var W = win_w
        var H = win_h
        if W < self.MIN_W:
            W = self.MIN_W
        if H < self.MIN_H:
            H = self.MIN_H

        # Solved by the Flex engine rather than hand-computed arithmetic. The
        # vertical stack is toolbar / content / status; the content row is
        # activity | sidebar | editor(grows) | minimap. Same numbers as the old
        # arithmetic produced — test_17 pins editor.w == 1178 at 1600x960 — but
        # the constraints are now declared instead of derived by hand, so a new
        # pane is an add() rather than an audit of every offset below.
        var vstack = Flex("column")
        vstack.add("toolbar", self.TOOLBAR_H, 0)
        vstack.add("content", 0, 1)
        vstack.add("status", self.STATUS_H, 0)
        vstack.solve(0, 0, W, H)

        var content_y = vstack.get("content").y
        var content_h = vstack.get("content").h

        var hrow = Flex("row")
        hrow.add("activity", self.ACTIVITY_W, 0)
        hrow.add("sidebar", self.SIDEBAR_W, 0)
        hrow.add_min("editor", 0, 1, 120)
        hrow.add("minimap", self.MINIMAP_W, 0)
        hrow.solve(0, content_y, W, content_h)

        var sidebar_x = hrow.get("sidebar").x
        var editor_x  = hrow.get("editor").x
        var editor_w  = hrow.get("editor").w

        var editor_h  = int(float(content_h) * self.editor_ratio)
        self.PANEL_H  = content_h - editor_h

        var ed_y = content_y + 34
        var ed_h = editor_h - 34
        var panel_y = content_y + editor_h
        var panel_w = W - self.ACTIVITY_W
        var pane_x  = self.ACTIVITY_W

        self.panel_tab_strip_y = panel_y
        self.panel_content_y   = panel_y + 30
        self.panel_content_h   = self.PANEL_H - 30
        self.panel_x = pane_x
        self.panel_w = panel_w

        self.run_bar.set_pos(0, 0)
        self.run_bar.set_size(W, self.TOOLBAR_H)

        self.activity.set_pos(0, content_y)
        self.activity.set_size(self.ACTIVITY_W, content_h)

        self.file_tree.set_pos(sidebar_x, content_y)
        self.file_tree.set_size(self.SIDEBAR_W, content_h)
        self.search.set_pos(sidebar_x, content_y)
        self.search.set_size(self.SIDEBAR_W, content_h)
        self.git_panel.set_pos(sidebar_x, content_y)
        self.git_panel.set_size(self.SIDEBAR_W, content_h)

        self.tab_bar.set_pos(editor_x, content_y)
        self.tab_bar.set_size(editor_w + self.MINIMAP_W, 34)

        self.editor.set_pos(editor_x, ed_y)
        self.editor.set_size(editor_w, ed_h)
        self.minimap.set_pos(editor_x + editor_w, ed_y)
        self.minimap.set_size(self.MINIMAP_W, ed_h)

        var panels = [self.output, self.terminal, self.diagnostics, self.debug_panel,
                      self.token_viewer, self.ast_viewer, self.profiler,
                      self.repl_panel, self.lang_workshop]
        for pnl in panels:
            pnl.set_pos(pane_x, self.panel_content_y)
            pnl.set_size(panel_w, self.panel_content_h)

        self.chat.set_pos(W - self.CHAT_W, content_y)
        self.chat.set_size(self.CHAT_W, content_h - self.PANEL_H)

        # Overlays are centred rather than pinned to their construction offsets.
        var sp_w = W - 640
        if sp_w < 320:
            sp_w = 320
        var sp_h = H - 480
        if sp_h < 240:
            sp_h = 240
        self.spotlight.set_pos(int((W - sp_w) / 2), int((H - sp_h) / 3))
        self.spotlight.set_size(sp_w, sp_h)

        var kb_w = W - 400
        if kb_w < 360:
            kb_w = 360
        var kb_h = H - 160
        if kb_h < 240:
            kb_h = 240
        self.keybind_panel.set_pos(int((W - kb_w) / 2), int((H - kb_h) / 2))
        self.keybind_panel.set_size(kb_w, kb_h)

        self.confetti.set_pos(0, 0)
        self.confetti.set_size(W, H)

        self.win_w = W
        self.win_h = H

    def run(self):
        self.win.on_resize(self._relayout)
        self.win.run(self._main_loop)


# ── Launch ───────────────────────────────────────────────────────────────────
var ide = NythonIDE()
ide.run()

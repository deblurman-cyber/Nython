# ide_editor.ny — EditorBuffer, SyntaxHighlighter, RichEditor, OutputConsole
# Imported by nython_ide.ny

import "lib/gui.ny"

# ═══════════════════════════════════════════════════════════════════════════════
# NythonIDE v3.0  -  Full-featured IDE with compiler pipeline inspection
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
        self._parse_content(content)

    def _parse_content(self, text):
        # Single split instead of the previous character walk.
        #
        # The old loop did `self.lines = self.lines + [line]` (copying the whole
        # list every iteration) and `rem = rem[nl+1:]` (copying the rest of the
        # file every iteration). Both are O(n^2), and since the interpreter does
        # not reclaim the intermediates, the cost was paid in resident memory:
        # a 680-line file needed 99 MB and a 3,087-line file 1.5 GB, while a
        # 13,000-line file was killed by the OOM reaper before it opened.
        if text == none:
            text = ""
        self.lines = string_split(text, "\n")
        var n = len(self.lines)
        # A trailing newline yields one empty element; that is the end of the
        # last line, not an extra line.
        # Drop it by shortening the count rather than rebuilding the list: a
        # copy loop here would be O(n^2) again, which is the very thing this
        # rewrite exists to remove.
        if n > 1 and self.lines[n - 1] == "":
            n = n - 1
        if n == 0:
            self.lines = [""]
            n = 1
        self.line_count = n

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
        var row = self.cursor_row
        var col = self.cursor_col
        var line = self.get_line(row)
        var new_line = line[0:col] + ch + line[col:]
        self.lines[row] = new_line
        # Advance by the length of what was inserted, not by one. A text-input
        # event can carry several characters (paste, IME, a fast key sequence),
        # and advancing by one left the caret inside the text just typed, so the
        # next character landed in the middle of it.
        self.cursor_col = col + len(ch)
        self.modified = true

    def delete_char_back(self):
        var row = self.cursor_row
        var col = self.cursor_col
        if col > 0:
            var line = self.get_line(row)
            self.lines[row] = line[0:col - 1] + line[col:]
            self.cursor_col = col - 1
            self.modified = true
        elif row > 0:
            var prev = self.get_line(row - 1)
            var cur = self.get_line(row)
            self.lines[row - 1] = prev + cur
            var new_lines = []
            var i = 0
            while i < self.line_count:
                if i != row:
                    new_lines.append(self.lines[i])
                i = i + 1
            self.lines = new_lines
            self.line_count = self.line_count - 1
            self.cursor_row = row - 1
            self.cursor_col = len(prev)
            self.modified = true

    def insert_newline(self):
        var row = self.cursor_row
        var col = self.cursor_col
        var line = self.get_line(row)
        var before = line[0:col]
        var after = line[col:]
        var indent = 0
        var li = 0
        while li < len(before):
            if before[li:li + 1] == " ":
                indent = indent + 1
            else:
                li = len(before)
            li = li + 1
        var ends_colon = len(string_strip(before)) > 0 and before[len(before) - 1:] == ":"
        if ends_colon:
            indent = indent + 4
        var pad = ""
        var pi = 0
        while pi < indent:
            pad = pad + " "
            pi = pi + 1
        self.lines[row] = before
        var new_lines = []
        var i = 0
        while i < self.line_count:
            new_lines.append(self.lines[i])
            if i == row:
                new_lines.append(pad + after)
            i = i + 1
        self.lines = new_lines
        self.line_count = self.line_count + 1
        self.cursor_row = row + 1
        self.cursor_col = indent
        self.modified = true

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


# ─── SyntaxHighlighter  -  full Nython tokeniser ────────────────────────────────
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
        # Colours. Two palettes: the dark set is tuned for a near-black editor
        # background, the light set for a white one. Reusing the dark colours on
        # a light background leaves keywords and strings washed out to the point
        # of being unreadable, so set_dark() swaps the whole palette.
        self.dark = true
        # User-extensible tokens. `custom` maps an exact word to a colour and is
        # consulted before every built-in category, so a user rule always wins.
        # `custom_names` keeps insertion order for listing them back.
        self.custom = {}
        self.custom_names = []
        self.set_dark(true)

    # ── extension API ────────────────────────────────────────────────────────
    # add_keyword / add_builtin / add_type put a word into an existing category
    # so it picks up that category's colour in both themes automatically.
    def add_keyword(self, word):
        if not self._has(self.keywords, word):
            self.keywords.append(word)
        return true

    def add_builtin(self, word):
        if not self._has(self.builtins, word):
            self.builtins.append(word)
        return true

    def add_type(self, word):
        if not self._has(self.type_names, word):
            self.type_names.append(word)
        return true

    # add_token gives a word its own colour, independent of the categories.
    # Passing none for the colour removes the rule.
    def add_token(self, word, color):
        if color == none:
            if self.custom.has_key(word):
                self.custom.remove(word)
                var keep = []
                var i = 0
                while i < len(self.custom_names):
                    if self.custom_names[i] != word:
                        keep.append(self.custom_names[i])
                    i = i + 1
                self.custom_names = keep
            return true
        if not self.custom.has_key(word):
            self.custom_names.append(word)
        self.custom[word] = color
        return true

    def add_tokens(self, words, color):
        var i = 0
        while i < len(words):
            self.add_token(words[i], color)
            i = i + 1
        return len(words)

    def clear_tokens(self):
        self.custom = {}
        self.custom_names = []
        return true

    def token_list(self):
        return self.custom_names

    def _has(self, arr, word):
        var i = 0
        while i < len(arr):
            if arr[i] == word:
                return true
            i = i + 1
        return false

    # Load rules from a plain-text file: "colour  word word word" per line,
    # where colour is keyword | builtin | type | r,g,b. Lines starting with #
    # are comments. Returns the number of rules applied, or -1 if unreadable.
    def load_rules(self, path):
        # read_file returns "" for a missing path as well as for an empty file,
        # so existence has to be checked separately to distinguish "could not
        # read" from "read, nothing in it".
        if not os_exists(path):
            return 0 - 1
        var text = read_file(path)
        if text == none:
            return 0 - 1
        var applied = 0
        var lines = string_split(text, "\n")
        var i = 0
        while i < len(lines):
            var ln = string_strip(lines[i])
            if len(ln) > 0 and string_find(ln, "#") != 0:
                var sp = string_find(ln, " ")
                if sp > 0:
                    var head = string_strip(string_slice(ln, 0, sp))
                    var rest = string_strip(string_slice(ln, sp + 1, len(ln)))
                    var words = string_split(rest, " ")
                    var col = none
                    if string_find(head, ",") > 0:
                        var parts = string_split(head, ",")
                        if len(parts) >= 3:
                            col = Color(int(parts[0]), int(parts[1]), int(parts[2]), 255)
                    var w = 0
                    while w < len(words):
                        var word = string_strip(words[w])
                        if word != "":
                            if head == "keyword":
                                self.add_keyword(word)
                            elif head == "builtin":
                                self.add_builtin(word)
                            elif head == "type":
                                self.add_type(word)
                            elif col != none:
                                self.add_token(word, col)
                            applied = applied + 1
                        w = w + 1
            i = i + 1
        return applied

    def set_dark(self, on):
        self.dark = on
        if on:
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
        else:
            self.c_keyword  = Color(126, 42, 190, 255)
            self.c_builtin  = Color(20, 105, 175, 255)
            self.c_string   = Color(150, 62, 30, 255)
            self.c_comment  = Color(38, 128, 60, 235)
            self.c_number   = Color(96, 118, 24, 255)
            self.c_class_n  = Color(20, 130, 118, 255)
            self.c_type     = Color(152, 92, 10, 255)
            self.c_operator = Color(124, 88, 12, 240)
            self.c_self     = Color(126, 42, 190, 235)
            self.c_default  = Color(40, 44, 60, 240)
            self.c_decorator= Color(140, 92, 10, 245)
            self.c_lineno   = Color(150, 155, 175, 200)
            self.c_active_ln= Color(60, 66, 120, 230)

    def tokenise_line(self, line):
        var segments = []
        if len(line) == 0:
            return segments
        var stripped = string_strip(line)
        if string_startswith(stripped, "#"):
            segments.append({"text": line, "color": self.c_comment})
            return segments
        if string_startswith(stripped, "@"):
            segments.append({"text": line, "color": self.c_decorator})
            return segments
        var i = 0
        var j = 0
        var ch = ""
        var word = ""
        var wc = Color(0,0,0,0)
        while i < len(line):
            ch = line[i:i + 1]
            if ch == "#":
                segments.append({"text": line[i:], "color": self.c_comment})
                i = len(line)
            elif ch == "\"":
                j = i + 1
                while j < len(line) and line[j:j + 1] != "\"":
                    j = j + 1
                if j < len(line):
                    j = j + 1
                segments.append({"text": line[i:j], "color": self.c_string})
                i = j
            elif (ch >= "0" and ch <= "9"):
                j = i
                while j < len(line) and line[j:j+1] >= "0" and line[j:j+1] <= "9":
                    j = j + 1
                segments.append({"text": line[i:j], "color": self.c_number})
                i = j
            elif self._is_id_char(ch) and (ch < "0" or ch > "9"):
                j = i
                while j < len(line) and self._is_id_char(line[j:j+1]):
                    j = j + 1
                word = line[i:j]
                wc = self._word_color(word)
                segments.append({"text": word, "color": wc})
                i = j
            elif self._is_op_char(ch):
                segments.append({"text": ch, "color": self.c_operator})
                i = i + 1
            else:
                segments.append({"text": ch, "color": self.c_default})
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
        if self.custom.has_key(word):
            return self.custom[word]
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


# ─── RichEditor  -  GPU-style syntax-highlighted editor ─────────────────────────
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


# ─── OutputConsole  -  pretty output panel ──────────────────────────────────────
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
        self.entries.append({"text": text, "kind": kind})
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


# ─── NythonIDE v3.0 ───────────────────────────────────────────────────────────

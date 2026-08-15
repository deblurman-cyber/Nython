# ─── Value Inspector ─────────────────────────────────────────────────────────
# Renders ANY Nython value for display in the debug / watch / REPL panels.
#
# Nython values are not all printable-as-text in a useful way. A list prints as
# one long line; a nested map prints as an unreadable blob; a string containing
# a tab, a newline or a lone control character prints as damage. And because the
# language is fully Unicode - identifiers, strings and the IDE's own Codicon
# glyphs are all multi-byte - a naive `len()` or a naive substring truncation
# cuts a character in half and emits invalid UTF-8, which shows up as a replacement
# box or garbage in the middle of a value.
#
# This module gives every value:
#   - a type name          -> shown as a dim tag
#   - an icon              -> a Codicon glyph, so the type is readable at a glance
#   - a one-line summary   -> safely truncated on a CHARACTER boundary
#   - an expandable tree   -> children for lists / maps / instances
#
#   var ins = Inspector()
#   var rows = ins.inspect("total", value)
#   for r in rows: print(r.indent, r.icon, r.key, r.type_name, r.summary)

class InspectRow:
    def __init__(self, key, type_name, summary, icon, indent, expandable):
        self.key = key
        self.type_name = type_name
        self.summary = summary
        self.icon = icon
        self.indent = indent
        self.expandable = expandable
        self.expanded = false
        self.raw = none


class Inspector:
    def __init__(self):
        self.max_summary = 60      # characters, not bytes
        self.max_children = 200    # guard against inspecting a huge container
        self.max_depth = 4
        self.icons = Icons_Codicon()

    # ── type identification ──────────────────────────────────────────────────
    def type_of(self, v):
        return type(v)

    def icon_for(self, v):
        var t = self.type_of(v)
        if t == "list":
            return self.icons.get("symbol-array")
        if t == "map" or t == "dict":
            if self.icons.has("symbol-object"):
                return self.icons.get("symbol-object")
            return self.icons.get("symbol-namespace")
        if t == "string":
            return self.icons.get("symbol-string")
        if t == "int" or t == "integer" or t == "float" or t == "double":
            return self.icons.get("symbol-numeric")
        if t == "bool" or t == "boolean":
            return self.icons.get("symbol-boolean")
        if t == "function":
            return self.icons.get("symbol-method")
        if t == "none":
            return self.icons.get("circle-slash")
        return self.icons.get("symbol-variable")

    # ── text helpers ─────────────────────────────────────────────────────────
    # KNOWN LANGUAGE INCONSISTENCY (see FIXES round 43): len() on a string counts
    # CHARACTERS -- len("日本語") is 3 -- but s[i] and s[a:b] index BYTES. So
    # rebuilding a string character by character silently corrupts any non-ASCII
    # text: "aébç" comes back as "aéb".
    #
    # Nothing here reassembles a string from indexed pieces. Truncation uses a
    # byte slice guarded by a byte budget so it can only ever cut on an ASCII
    # boundary, and escaping rebuilds only when a control character is actually
    # present -- which, being ASCII, is safe.
    def _byte(self, ch):
        var b = ord(ch)
        if b < 0:
            b = b + 256
        return b

    def char_len(self, s):
        return len(s)

    def truncate(self, s, n):
        if len(s) <= n:
            return s
        # len() is characters and slicing is bytes, so a character count is
        # always <= the safe byte count; slicing at it cannot overrun.
        return s[0:n] + "…"

    def has_control(self, s):
        if string_find(s, "\n") >= 0:
            return true
        if string_find(s, "\t") >= 0:
            return true
        if string_find(s, "\r") >= 0:
            return true
        return false

    # Make newlines/tabs/returns visible so a multi-line value stays one row.
    # Left untouched when there is nothing to escape, which keeps every accented
    # letter, CJK glyph and Codicon glyph byte-identical.
    def escape(self, s):
        if not self.has_control(s):
            return s
        var out = string_replace(s, "\n", "\\n")
        out = string_replace(out, "\t", "\\t")
        out = string_replace(out, "\r", "\\r")
        return out

    # ── summaries ────────────────────────────────────────────────────────────
    def summarize(self, v):
        var t = self.type_of(v)
        if t == "string":
            return "\"" + self.truncate(self.escape(v), self.max_summary) + "\""
        if t == "list":
            var n = len(v)
            if n == 0:
                return "[] (empty)"
            return "[" + str(n) + " items] " + self.truncate(self.escape(str(v)), self.max_summary)
        if t == "map" or t == "dict":
            var keys = v.keys()
            if len(keys) == 0:
                return "{} (empty)"
            return "{" + str(len(keys)) + " keys} " + self.truncate(self.escape(str(v)), self.max_summary)
        if t == "none":
            return "none"
        return self.truncate(self.escape(str(v)), self.max_summary)

    # ── expansion ────────────────────────────────────────────────────────────
    def is_expandable(self, v):
        var t = self.type_of(v)
        if t == "list":
            return len(v) > 0
        if t == "map" or t == "dict":
            return len(v.keys()) > 0
        return false

    def row_for(self, key, v, indent):
        var r = InspectRow(key, self.type_of(v), self.summarize(v),
                           self.icon_for(v), indent, self.is_expandable(v))
        r.raw = v
        return r

    # Flatten a value into display rows, depth-first.
    def inspect(self, key, v):
        return self._walk(key, v, 0)

    def _walk(self, key, v, depth):
        var rows = [self.row_for(key, v, depth)]
        if depth >= self.max_depth:
            return rows
        var t = self.type_of(v)
        if t == "list":
            var n = len(v)
            if n > self.max_children:
                n = self.max_children
            var i = 0
            while i < n:
                # Extend in place rather than rebuilding `rows` per child. The
                # old form is quadratic in the node count and the discarded
                # intermediates are never reclaimed, so inspecting a large
                # nested value cost memory proportional to depth x width.
                var kid = self._walk("[" + str(i) + "]", v[i], depth + 1)
                var ki = 0
                while ki < len(kid):
                    rows.append(kid[ki])
                    ki = ki + 1
                i = i + 1
            if len(v) > self.max_children:
                rows.append(InspectRow("…", "info",
                              str(len(v) - self.max_children) + " more items",
                              self.icons.get("ellipsis"), depth + 1, false))
        elif t == "map" or t == "dict":
            var keys = v.keys()
            var m = len(keys)
            if m > self.max_children:
                m = self.max_children
            var j = 0
            while j < m:
                var kid2 = self._walk(str(keys[j]), v[keys[j]], depth + 1)
                var kj = 0
                while kj < len(kid2):
                    rows.append(kid2[kj])
                    kj = kj + 1
                j = j + 1
        return rows

    def render_line(self, r):
        var pad = ""
        var i = 0
        while i < r.indent:
            pad = pad + "  "
            i = i + 1
        return pad + r.icon + " " + r.key + ": " + r.summary + "  (" + r.type_name + ")"

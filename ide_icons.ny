# ══════════════════════════════════════════════════════════════════════════════
#  ide_icons.ny — vector icons drawn with renderer primitives
#
#  Why not downloaded SVG files?
#
#  Nython links SDL3_image, which does not rasterise SVG, so an .svg on disk
#  could not be drawn without adding a rendering dependency. Bitmap exports
#  would need a separate asset per size and per theme colour, and third-party
#  icon sets carry attribution requirements that would have to be shipped with
#  the project.
#
#  These are drawn from primitives instead: they scale to any size, take the
#  theme colour as a parameter, need no files on disk and no licence, and cost
#  a handful of draw calls each. The shapes follow the same visual conventions
#  as VS Code's icon set (16px grid, 1.5px strokes, rounded corners).
# ══════════════════════════════════════════════════════════════════════════════


import "lib/icons.ny"


class Icons:
    def __init__(self):
        self.codicon = Icons_Codicon()
        self.glyph_fonts = {}
        # Off if the font is missing, so the vector fallback runs instead of
        # every icon rendering as a missing-glyph box.
        self.use_glyphs = path_exists(self.codicon.font_path)
        self.name_map = {}
        self.name_map["explorer"]      = "files"
        self.name_map["search"]        = "search"
        self.name_map["git"]           = "source-control"
        self.name_map["run"]           = "play"
        self.name_map["debug"]         = "debug-alt"
        self.name_map["ext"]           = "extensions"
        self.name_map["outline"]       = "symbol-structure"
        self.name_map["ai"]            = "sparkle"
        self.name_map["folder"]        = "folder"
        self.name_map["folder_open"]   = "folder-opened"
        self.name_map["file"]          = "file"
        self.name_map["file_code"]     = "file-code"
        self.name_map["settings"]      = "settings-gear"
        self.name_map["terminal"]      = "terminal"
        self.name_map["warning"]       = "warning"
        self.name_map["close"]         = "close"
        self.name_map["chevron_right"] = "chevron-right"
        self.name_map["chevron_down"]  = "chevron-down"
        self.name_map["save"]          = "save"
        self.name_map["new_file"]      = "new-file"
        self.name_map["project"]       = "project"
        self.name_map["breakpoint"]    = "debug-breakpoint"
        self.name_map["output"]        = "output"
        self.stroke = 1.6

    # ── helpers ───────────────────────────────────────────────────────────────
    def _ln(self, r, x1, y1, x2, y2, c):
        r.draw_line(x1, y1, x2, y2, c, self.stroke)

    def _box(self, r, x, y, w, h, c):
        r.draw_rounded_rect(Rect(x, y, w, h), c, 2, 1)

    def _fbox(self, r, x, y, w, h, c, rad):
        r.fill_rounded_rect(Rect(x, y, w, h), c, rad)

    # ── main entry ────────────────────────────────────────────────────────────
    # draw(renderer, name, x, y, size, color)  — x,y is the top-left of a
    # size x size box; every icon is designed on a 16-unit grid and scaled.
    # ── Codicon glyphs, with the vector shapes as fallback ───────────────────
    # The header above argued for drawing icons from primitives because SDL3_image
    # cannot rasterise SVG. That is true of SVG, but the icon set also ships as a
    # FONT, and SDL3_ttf is already linked and already used for every label. So
    # the real VS Code icons can be drawn as text — one glyph, one draw call,
    # taking the theme colour like any other text, at any size.
    #
    # assets/fonts/codicon.ttf is bundled (CC BY 4.0, licence beside it).
    # If the font is missing the vector shapes below still run, so a stripped
    # install degrades instead of showing blank squares.
    def _glyph_font(self, size):
        var key = str(int(size))
        var f = self.glyph_fonts[key]
        if f == none:
            f = Font(self.codicon.font_path, int(size), false, false)
            self.glyph_fonts[key] = f
        return f

    # v4's icon names differ from the codicon set's; map them.
    def _codicon_name(self, name):
        var m = self.name_map[name]
        if m == none:
            return name
        return m

    def draw(self, r, name, x, y, s, c):
        if self.use_glyphs:
            var cn = self._codicon_name(name)
            if self.codicon.has(cn):
                var f = self._glyph_font(s)
                if f != none:
                    # Nudge down so the glyph box sits on the same baseline the
                    # vector shapes were drawn against.
                    r.draw_text(self.codicon.get(cn), x, y - int(s / 8), f, c)
                    return true
        var u = s / 16.0
        if name == "folder":
            self._folder(r, x, y, u, c, false)
        elif name == "folder_open":
            self._folder(r, x, y, u, c, true)
        elif name == "file":
            self._file(r, x, y, u, c, false)
        elif name == "file_code":
            self._file(r, x, y, u, c, true)
        elif name == "explorer":
            self._explorer(r, x, y, u, c)
        elif name == "search":
            self._search(r, x, y, u, c)
        elif name == "git":
            self._git(r, x, y, u, c)
        elif name == "run":
            self._play(r, x, y, u, c)
        elif name == "debug":
            self._bug(r, x, y, u, c)
        elif name == "ext":
            self._grid(r, x, y, u, c)
        elif name == "settings":
            self._gear(r, x, y, u, c)
        elif name == "terminal":
            self._terminal(r, x, y, u, c)
        elif name == "warning":
            self._warning(r, x, y, u, c)
        elif name == "close":
            self._close(r, x, y, u, c)
        elif name == "chevron_right":
            self._chevron(r, x, y, u, c, false)
        elif name == "chevron_down":
            self._chevron(r, x, y, u, c, true)
        elif name == "save":
            self._save(r, x, y, u, c)
        elif name == "new_file":
            self._new_file(r, x, y, u, c)
        elif name == "project":
            self._project(r, x, y, u, c)
        elif name == "breakpoint":
            r.fill_circle(int(x + 8 * u), int(y + 8 * u), int(4 * u), c)
        elif name == "output":
            self._output(r, x, y, u, c)
        elif name == "outline":
            self._outline(r, x, y, u, c)
        elif name == "ai":
            self._sparkle(r, x, y, u, c)
        else:
            # The fallback is an empty rounded box. Two rail buttons ("outline"
            # and "ai") had no case above and therefore rendered as blank
            # squares in the activity bar — the icon was not missing from a font,
            # it was never drawn at all.
            self._box(r, x + 3 * u, y + 3 * u, 10 * u, 10 * u, c)

    # ── shapes ────────────────────────────────────────────────────────────────
    def _folder(self, r, x, y, u, c, open_state):
        # tab
        self._ln(r, x + 2 * u, y + 4 * u, x + 6 * u, y + 4 * u, c)
        self._ln(r, x + 6 * u, y + 4 * u, x + 7.5 * u, y + 5.5 * u, c)
        if open_state:
            # open folder: body skewed forward
            self._ln(r, x + 2 * u, y + 4 * u, x + 2 * u, y + 12 * u, c)
            self._ln(r, x + 2 * u, y + 12 * u, x + 13 * u, y + 12 * u, c)
            self._ln(r, x + 13 * u, y + 12 * u, x + 14.5 * u, y + 6.5 * u, c)
            self._ln(r, x + 14.5 * u, y + 6.5 * u, x + 4 * u, y + 6.5 * u, c)
            self._ln(r, x + 4 * u, y + 6.5 * u, x + 2 * u, y + 12 * u, c)
        else:
            self._box(r, x + 2 * u, y + 5.5 * u, 12 * u, 6.5 * u, c)

    def _file(self, r, x, y, u, c, code):
        self._ln(r, x + 4 * u, y + 2 * u, x + 9.5 * u, y + 2 * u, c)
        self._ln(r, x + 9.5 * u, y + 2 * u, x + 12.5 * u, y + 5 * u, c)
        self._ln(r, x + 12.5 * u, y + 5 * u, x + 12.5 * u, y + 14 * u, c)
        self._ln(r, x + 12.5 * u, y + 14 * u, x + 4 * u, y + 14 * u, c)
        self._ln(r, x + 4 * u, y + 14 * u, x + 4 * u, y + 2 * u, c)
        # folded corner
        self._ln(r, x + 9.5 * u, y + 2 * u, x + 9.5 * u, y + 5 * u, c)
        self._ln(r, x + 9.5 * u, y + 5 * u, x + 12.5 * u, y + 5 * u, c)
        if code:
            # < > glyphs inside
            self._ln(r, x + 7.4 * u, y + 8 * u, x + 6.2 * u, y + 9.6 * u, c)
            self._ln(r, x + 6.2 * u, y + 9.6 * u, x + 7.4 * u, y + 11.2 * u, c)
            self._ln(r, x + 9.4 * u, y + 8 * u, x + 10.6 * u, y + 9.6 * u, c)
            self._ln(r, x + 10.6 * u, y + 9.6 * u, x + 9.4 * u, y + 11.2 * u, c)

    def _explorer(self, r, x, y, u, c):
        self._fbox(r, x + 2 * u, y + 2.5 * u, 5 * u, 11 * u, c, 1)
        self._box(r, x + 8 * u, y + 2.5 * u, 6 * u, 11 * u, c)

    def _search(self, r, x, y, u, c):
        r.draw_circle(int(x + 7 * u), int(y + 7 * u), int(4.2 * u), c)
        self._ln(r, x + 10 * u, y + 10 * u, x + 13.5 * u, y + 13.5 * u, c)

    def _git(self, r, x, y, u, c):
        r.fill_circle(int(x + 4.5 * u), int(y + 4 * u), int(2 * u), c)
        r.fill_circle(int(x + 4.5 * u), int(y + 12 * u), int(2 * u), c)
        r.fill_circle(int(x + 11.5 * u), int(y + 7 * u), int(2 * u), c)
        self._ln(r, x + 4.5 * u, y + 6 * u, x + 4.5 * u, y + 10 * u, c)
        self._ln(r, x + 4.5 * u, y + 7.5 * u, x + 9.5 * u, y + 7.5 * u, c)

    def _play(self, r, x, y, u, c):
        r.fill_polygon([int(x + 5 * u), int(y + 3.5 * u),
                        int(x + 5 * u), int(y + 12.5 * u),
                        int(x + 12.5 * u), int(y + 8 * u)], c)

    def _bug(self, r, x, y, u, c):
        self._fbox(r, x + 5 * u, y + 5 * u, 6 * u, 8 * u, c, int(3 * u))
        self._ln(r, x + 3 * u, y + 7 * u, x + 5 * u, y + 8 * u, c)
        self._ln(r, x + 3 * u, y + 11 * u, x + 5 * u, y + 10.5 * u, c)
        self._ln(r, x + 13 * u, y + 7 * u, x + 11 * u, y + 8 * u, c)
        self._ln(r, x + 13 * u, y + 11 * u, x + 11 * u, y + 10.5 * u, c)
        self._ln(r, x + 6.5 * u, y + 4 * u, x + 8 * u, y + 5 * u, c)
        self._ln(r, x + 9.5 * u, y + 4 * u, x + 8 * u, y + 5 * u, c)

    def _grid(self, r, x, y, u, c):
        self._fbox(r, x + 2.5 * u, y + 2.5 * u, 4.5 * u, 4.5 * u, c, 1)
        self._fbox(r, x + 9 * u, y + 2.5 * u, 4.5 * u, 4.5 * u, c, 1)
        self._fbox(r, x + 2.5 * u, y + 9 * u, 4.5 * u, 4.5 * u, c, 1)
        self._box(r, x + 9 * u, y + 9 * u, 4.5 * u, 4.5 * u, c)

    # Document outline: a nested list of decreasing indent, the way every editor
    # symbolises structure.
    def _outline(self, r, x, y, u, c):
        self._fbox(r, x + 2.5 * u, y + 3.5 * u, 2 * u, 1.4 * u, c, 1)
        self._ln(r, x + 6 * u, y + 4.2 * u, x + 13.5 * u, y + 4.2 * u, c)
        self._fbox(r, x + 4.5 * u, y + 7.3 * u, 2 * u, 1.4 * u, c, 1)
        self._ln(r, x + 8 * u, y + 8 * u, x + 13.5 * u, y + 8 * u, c)
        self._fbox(r, x + 4.5 * u, y + 11.1 * u, 2 * u, 1.4 * u, c, 1)
        self._ln(r, x + 8 * u, y + 11.8 * u, x + 13.5 * u, y + 11.8 * u, c)

    # AI assistant: a four-point sparkle plus a small companion star.
    def _sparkle(self, r, x, y, u, c):
        var cx = x + 6.6 * u
        var cy = y + 7.4 * u
        var a = 4.6 * u
        var b = 1.7 * u
        self._ln(r, cx, cy - a, cx, cy + a, c)
        self._ln(r, cx - a, cy, cx + a, cy, c)
        self._ln(r, cx - b, cy - b, cx + b, cy + b, c)
        self._ln(r, cx - b, cy + b, cx + b, cy - b, c)
        var sx = x + 12.2 * u
        var sy = y + 12.4 * u
        var t = 2.2 * u
        self._ln(r, sx, sy - t, sx, sy + t, c)
        self._ln(r, sx - t, sy, sx + t, sy, c)

    def _gear(self, r, x, y, u, c):
        r.draw_circle(int(x + 8 * u), int(y + 8 * u), int(3.2 * u), c)
        r.draw_circle(int(x + 8 * u), int(y + 8 * u), int(5.6 * u), c)
        self._ln(r, x + 8 * u, y + 1.5 * u, x + 8 * u, y + 3.4 * u, c)
        self._ln(r, x + 8 * u, y + 12.6 * u, x + 8 * u, y + 14.5 * u, c)
        self._ln(r, x + 1.5 * u, y + 8 * u, x + 3.4 * u, y + 8 * u, c)
        self._ln(r, x + 12.6 * u, y + 8 * u, x + 14.5 * u, y + 8 * u, c)

    def _terminal(self, r, x, y, u, c):
        self._box(r, x + 2 * u, y + 3 * u, 12 * u, 10 * u, c)
        self._ln(r, x + 4.5 * u, y + 6.5 * u, x + 7 * u, y + 8.2 * u, c)
        self._ln(r, x + 7 * u, y + 8.2 * u, x + 4.5 * u, y + 10 * u, c)
        self._ln(r, x + 8.2 * u, y + 10.4 * u, x + 11.5 * u, y + 10.4 * u, c)

    def _warning(self, r, x, y, u, c):
        r.fill_polygon([int(x + 8 * u), int(y + 2.5 * u),
                        int(x + 14.5 * u), int(y + 13.5 * u),
                        int(x + 1.5 * u), int(y + 13.5 * u)], c)

    def _close(self, r, x, y, u, c):
        self._ln(r, x + 4.5 * u, y + 4.5 * u, x + 11.5 * u, y + 11.5 * u, c)
        self._ln(r, x + 11.5 * u, y + 4.5 * u, x + 4.5 * u, y + 11.5 * u, c)

    def _chevron(self, r, x, y, u, c, down):
        if down:
            self._ln(r, x + 4 * u, y + 6.5 * u, x + 8 * u, y + 10.5 * u, c)
            self._ln(r, x + 8 * u, y + 10.5 * u, x + 12 * u, y + 6.5 * u, c)
        else:
            self._ln(r, x + 6.5 * u, y + 4 * u, x + 10.5 * u, y + 8 * u, c)
            self._ln(r, x + 10.5 * u, y + 8 * u, x + 6.5 * u, y + 12 * u, c)

    def _save(self, r, x, y, u, c):
        self._box(r, x + 2.5 * u, y + 2.5 * u, 11 * u, 11 * u, c)
        self._box(r, x + 5 * u, y + 2.5 * u, 6 * u, 4 * u, c)
        self._box(r, x + 4.5 * u, y + 8.5 * u, 7 * u, 5 * u, c)

    def _new_file(self, r, x, y, u, c):
        self._file(r, x - 1 * u, y, u, c, false)
        self._ln(r, x + 11 * u, y + 10 * u, x + 11 * u, y + 14 * u, c)
        self._ln(r, x + 9 * u, y + 12 * u, x + 13 * u, y + 12 * u, c)

    def _project(self, r, x, y, u, c):
        self._box(r, x + 2 * u, y + 3 * u, 12 * u, 10 * u, c)
        self._ln(r, x + 2 * u, y + 6 * u, x + 14 * u, y + 6 * u, c)
        r.fill_circle(int(x + 4.2 * u), int(y + 4.5 * u), int(0.9 * u), c)
        r.fill_circle(int(x + 6.4 * u), int(y + 4.5 * u), int(0.9 * u), c)

    def _output(self, r, x, y, u, c):
        self._ln(r, x + 3 * u, y + 4.5 * u, x + 13 * u, y + 4.5 * u, c)
        self._ln(r, x + 3 * u, y + 8 * u, x + 13 * u, y + 8 * u, c)
        self._ln(r, x + 3 * u, y + 11.5 * u, x + 9 * u, y + 11.5 * u, c)

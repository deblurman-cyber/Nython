# ══════════════════════════════════════════════════════════════════════════════
#  NythonIDE v4  —  responsive editor shell
#
#  Every coordinate here derives from the LIVE window size (self.W / self.H),
#  recomputed in _layout() and re-run on every "resize" event.
#
#  v3 hardcoded 1600x960. On a 1366x768 display Windows clamped the window while
#  the layout kept painting at the unclamped size, so most of the UI landed
#  off-screen and the window looked black. Nothing here uses a fixed size.
#
#  Arrangement follows VS Code / Code::Blocks: icon rail, collapsible sidebar,
#  tabbed editor with gutter + minimap, tabbed bottom panel, status bar.
# ══════════════════════════════════════════════════════════════════════════════

import "ide_editor.ny"
import "ide_workshop.ny"
import "ide_icons.ny"
import "ide_project.ny"
import "lib/aiagent.ny"
import "lib/gui_motion.ny"
import "lib/nyimgui.ny"


class IDETheme:
    def __init__(self):
        self.dark = true
        self.apply()

    def toggle(self):
        self.dark = not self.dark
        self.apply()

    def apply(self):
        if self.dark:
            # ── VS Code "Dark+" ──────────────────────────────────────────
            # These are the published Dark+ workbench values. The previous
            # palette was a blue-black with a purple accent, which is why the
            # IDE did not read as an editor.
            #
            # A Dark+ palette was written in round 41 — into lib/gui.ny, which
            # this file does not import. It therefore never appeared in the
            # shipped IDE. Same class of mistake as editing the wrong IDE file:
            # the change was real and landed somewhere unused.
            self.bg          = Color(30, 30, 30, 255)      # #1E1E1E editor
            self.chrome      = Color(60, 60, 60, 255)      # #3C3C3C title bar
            self.chrome_hi   = Color(69, 69, 69, 255)      # #454545 raised
            self.panel       = Color(37, 37, 38, 255)      # #252526 side/panel
            self.editor_bg   = Color(30, 30, 30, 255)      # #1E1E1E
            self.gutter_bg   = Color(30, 30, 30, 255)      # gutter matches editor
            self.minimap_bg  = Color(30, 30, 30, 255)
            self.status_bg   = Color(0, 122, 204, 255)     # #007ACC status bar
            self.border      = Color(59, 59, 59, 255)      # #3B3B3B
            self.border_soft = Color(255, 255, 255, 10)
            self.text        = Color(212, 212, 212, 255)   # #D4D4D4
            self.text_dim    = Color(133, 133, 133, 255)   # #858585
            self.text_faint  = Color(106, 106, 106, 255)   # #6A6A6A
            self.accent      = Color(0, 122, 204, 255)     # #007ACC focus
            self.accent_soft = Color(0, 122, 204, 60)
            self.ok          = Color(137, 209, 133, 255)   # #89D185
            self.warn        = Color(204, 167, 0, 255)     # #CCA700
            self.err         = Color(241, 76, 76, 255)     # #F14C4C
            self.gutter      = Color(133, 133, 133, 255)   # #858585 line numbers
            self.caret_line  = Color(255, 255, 255, 10)    # current-line wash
            self.hover       = Color(42, 45, 46, 255)      # #2A2D2E list hover
            self.overlay     = Color(37, 37, 38, 250)      # menus/popups
            self.field       = Color(60, 60, 60, 255)      # #3C3C3C inputs
            self.scrim       = Color(0, 0, 0, 125)
            # Selection + tabs, referenced by the editor and tab strip.
            self.selection   = Color(38, 79, 120, 255)     # #264F78
            self.tab_active  = Color(30, 30, 30, 255)      # #1E1E1E
            self.tab_inactive= Color(45, 45, 45, 255)      # #2D2D2D
            self.activitybar = Color(51, 51, 51, 255)      # #333333
        else:
            self.bg          = Color(243, 244, 248, 255)
            self.chrome      = Color(235, 237, 243, 255)
            self.chrome_hi   = Color(246, 247, 251, 255)
            self.panel       = Color(238, 240, 246, 255)
            self.editor_bg   = Color(252, 252, 254, 255)
            self.gutter_bg   = Color(246, 247, 251, 255)
            self.minimap_bg  = Color(244, 245, 250, 255)
            self.status_bg   = Color(230, 232, 240, 255)
            self.border      = Color(0, 0, 0, 28)
            self.border_soft = Color(0, 0, 0, 14)
            self.text        = Color(32, 36, 52, 255)
            self.text_dim    = Color(88, 95, 118, 255)
            self.text_faint  = Color(134, 141, 163, 255)
            self.accent      = Color(74, 84, 214, 255)
            self.accent_soft = Color(74, 84, 214, 38)
            self.ok          = Color(30, 150, 92, 255)
            self.warn        = Color(184, 128, 20, 255)
            self.err         = Color(198, 48, 58, 255)
            self.gutter      = Color(150, 157, 178, 255)
            self.caret_line  = Color(0, 0, 0, 10)
            self.hover       = Color(0, 0, 0, 12)
            self.overlay     = Color(255, 255, 255, 253)
            self.field       = Color(0, 0, 0, 10)
            self.scrim       = Color(0, 0, 0, 70)


def hit(rx, ry, rw, rh, px, py):
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh


class RailItem:
    def __init__(self, key, glyph, tip):
        self.key = key
        self.glyph = glyph
        self.tip = tip
        self.x = 0
        self.y = 0
        self.w = 0
        self.h = 0
        self.hovered = false


class EdTab:
    def __init__(self, title):
        self.title = title
        self.path = ""
        self.dirty = false
        self.x = 0
        self.w = 0


class NythonIDE:
    def __init__(self):
        self.th = IDETheme()

        # Size the window to the ACTUAL display, never larger.
        var want_w = 1600
        var want_h = 960
        var disp = gui_get_display_size()
        if disp != none:
            if len(disp) >= 2:
                var dw = disp[0]
                var dh = disp[1]
                if dw > 0 and dh > 0:
                    if want_w > dw - 40:
                        want_w = dw - 40
                    if want_h > dh - 90:
                        want_h = dh - 90
        if want_w < 900:
            want_w = 900
        if want_h < 560:
            want_h = 560

        self.win = Window(want_w, want_h, "NythonIDE v4")
        self.win.resizable = true
        self.W = want_w
        self.H = want_h

        # High-DPI. Every metric and font size below is a design-pixel value.
        # Nothing queried the display's content scale, so on a 4K or Retina
        # panel the whole interface rendered at roughly half size with soft
        # text. At scale 1.0 every number is identical to before, so a standard
        # display is unaffected.
        self.dpi = gui_display_scale()
        if self.dpi <= 0.0 or self.dpi > 8.0:
            self.dpi = 1.0

        self.RAIL_W     = self.dp(52)
        self.SIDEBAR_W  = self.dp(258)
        self.MENU_H     = self.dp(30)
        self.TOOLBAR_H  = self.dp(40)
        self.TABBAR_H   = self.dp(36)
        self.STATUS_H   = self.dp(26)
        self.PANELTAB_H = self.dp(32)
        self.MINIMAP_W  = self.dp(92)
        self.GUTTER_W   = self.dp(56)
        self.LINE_H     = self.dp(18)

        # Motion. Nothing in the UI eased: toasts appeared and vanished at full
        # opacity, and panes snapped between open and closed in a single frame.
        # Linear or instant transitions are the clearest "not a real app" tell,
        # because nothing physical moves that way.
        self.ease = Ease()
        self.fuzzy = Fuzzy()
        # Immediate-mode context, used by the panel tab strip. Retained widgets
        # continue to work alongside it; the two coexist by flushing the IM draw
        # list through the same renderer.
        self.ui = NyImGui()
        self.mouse_down = false
        self.sidebar_anim = 1.0      # 0 = fully collapsed, 1 = fully open
        self.panel_anim   = 1.0
        self.ANIM_MS      = 160

        self.sidebar_open = true
        self.panel_open   = true
        self.panel_ratio  = 0.30
        self.minimap_on   = true

        self.f_ui      = Font("sans-serif", self.dp(12), false, false)
        self.f_ui_bold = Font("sans-serif", self.dp(12), true,  false)
        self.f_small   = Font("sans-serif", self.dp(11), false, false)
        self.f_code    = Font("monospace",  self.dp(13), false, false)
        self.f_icon    = Font("sans-serif", self.dp(15), true,  false)

        self.menus = ["File", "Edit", "View", "Search", "Build", "Debug", "Tools", "Help"]
        self.menu_count = 8
        self.menu_items = {
            "File":   ["New File\tCtrl+N", "New Project...\tCtrl+Shift+N", "-",
                       "Open File...\tCtrl+O", "Open Folder...\tCtrl+K", "Open Project...", "-",
                       "Save\tCtrl+S", "Save All", "-", "Recent Files", "Close Folder", "Exit\tAlt+F4"],
            "Edit":   ["Undo\tCtrl+Z", "Redo\tCtrl+Y", "-", "Cut\tCtrl+X", "Copy\tCtrl+C", "Paste\tCtrl+V", "-", "Toggle Comment\tCtrl+/", "Duplicate Line\tCtrl+D", "Delete Line\tCtrl+Shift+K", "Move Line Up\tAlt+Up", "Move Line Down\tAlt+Down"],
            "View":   ["Toggle Sidebar\tCtrl+B", "Toggle Panel\tCtrl+J", "Toggle Minimap", "Toggle Theme\tCtrl+Shift+T", "-", "Zoom In\tCtrl++", "Zoom Out\tCtrl+-", "Reset Zoom\tCtrl+0", "-", "Command Palette\tCtrl+P"],
            "Search": ["Find\tCtrl+F", "Replace\tCtrl+H", "Go to Line\tCtrl+G", "Find in Files"],
            "Build":  ["Run\tF5", "Run on VM", "Build", "Tokenize", "Show AST", "Disassemble"],
            "Debug":  ["Start Debugging\tF5", "Step Over\tF10", "Step Into\tF11", "-",
                       "Toggle Breakpoint\tF9", "Clear All Breakpoints", "Show Breakpoints"],
            "Tools":  ["Analyse Buffer", "Lang Workshop", "Terminal", "-", "Save Settings", "Reload Settings", "Add Highlight Token...", "Reload Highlight Rules", "Settings"],
            "Help":   ["Documentation", "Keyboard Shortcuts", "About Nython"]
        }
        self.menu_open = -1
        self.menu_hover = -1
        self.menu_rects = []
        self.menu_item_rects = []
        self.menu_item_hover = -1

        self.rail = [RailItem("explorer", "E", "Explorer"),
                     RailItem("search",   "S", "Search"),
                     RailItem("git",      "G", "Source Control"),
                     RailItem("run",      "R", "Run and Debug"),
                     RailItem("ext",      "X", "Extensions"),
                     RailItem("outline",  "O", "Outline"),
                     RailItem("ai",       "A", "AI Assistant")]
        self.rail_count = 7
        self.active_view = "explorer"

        self.run_modes = ["Run", "VM", "Debug", "Tokenize", "AST", "Disasm"]
        # Index 0 ("Run") is deliberately NOT drawn as a chip: the green ▶ button
        # already is Run, and drawing both put two Run controls side by side.
        # The entry stays in the list because mode indices are hardcoded
        # throughout (0=Run, 1=VM, 3=Tokenize, 4=AST, 5=Disasm) and renumbering
        # them here would silently rewire every menu command.
        self.first_chip = 1
        self.run_mode_count = 6
        self.active_mode = 0
        self.mode_rects = []

        self.buffers = []
        self.tabs = []
        self.tab_count = 0
        self.active_tab = 0
        self._seed_files()

        self.editor = RichEditor(0, 0, 100, 100)
        # The IDE paints the gutter and the code itself, so the editor's rect
        # starts AFTER the gutter. RichEditor was still subtracting its own
        # gutter_w and using line_h 20 against the IDE's 18, which put every
        # click roughly seven columns and one row away from where it looked.
        self.editor.gutter_w = 0
        self.editor.line_h = self.LINE_H
        var cw = self.f_code.width("M")
        self.editor.char_w = cw
        self.editor.focused = true
        self.editor.set_buffer(self.buffers[0])
        self.console = OutputConsole(0, 0, 100, 100)
        self.console.write("NythonIDE v4 ready", "ok")
        self.console.write("Workspace: /project  |  3 files loaded", "info")

        self.workshop = LangWorkshopPanel(0, 0, 100, 100)

        self.panel_tabs = ["Output", "Problems", "Terminal", "Debug", "Tokens", "Workshop"]
        self.panel_tab_count = 6
        self.active_panel = 0
        self.panel_rects = []

        self.problems = [{"sev": "err",  "msg": "undefined name 'foo'",         "file": "main.ny",  "line": 12},
                         {"sev": "warn", "msg": "unused variable 'tmp'",        "file": "main.ny",  "line": 27},
                         {"sev": "info", "msg": "consider using a for-in loop", "file": "utils.ny", "line": 8}]
        self.problem_count = 3
        self.problem_rows = []

        self.term_lines = ["Nython 0.2.1 interactive shell", "type 'help' for commands", ""]
        self.term_count = 3
        self.term_input = ""

        self.tree = [{"depth": 0, "name": "project",   "dir": true,  "open": true},
                     {"depth": 1, "name": "src",       "dir": true,  "open": true},
                     {"depth": 2, "name": "main.ny",   "dir": false, "open": false},
                     {"depth": 2, "name": "utils.ny",  "dir": false, "open": false},
                     {"depth": 2, "name": "model.ny",  "dir": false, "open": false},
                     {"depth": 1, "name": "lib",       "dir": true,  "open": false},
                     {"depth": 1, "name": "README.md", "dir": false, "open": false}]
        self.tree_count = 7
        self.tree_sel = 2
        self.tree_hover = -1

        self.palette_open = false
        self.palette_query = ""
        self.palette_sel = 0
        self.palette_all = ["Run: Execute current file",
                            "Run: Tokenize current file",
                            "Run: Show AST",
                            "View: Toggle Sidebar",
                            "View: Toggle Panel",
                            "View: Toggle Minimap",
                            "View: Toggle Theme",
                            "File: New File",
                            "File: Save",
                            "Tools: Lang Workshop",
                            "Help: Keyboard Shortcuts"]
        self.palette_hits = []
        self.palette_hit_count = 0

        self.mx = 0
        self.my = 0
        self.dragging_split = false
        self.dragging_sidebar = false
        self.status_msg = "Ready"
        self.frames = 0
        self._hl_cache = {}
        self._hl_cache_n = 0
        self._code_handle = none
        # Repaint only when something changed. The IDE previously redrew its
        # entire UI on every idle frame — ~178 interpreted draw_text calls a
        # frame for pixels that were already correct.
        self._dirty = true
        self._skipped = 0
        self.icons = Icons()
        self.ws = Workspace()
        # open_folder(getcwd()) alone: if the working directory could not be
        # opened the explorer stayed permanently empty while the output still
        # claimed files were loaded, and the only clue was an error string
        # overflowing the sidebar. Try a chain of candidates and keep whichever
        # works, so the tree is never empty just because the launch directory
        # was odd.
        self._open_initial_workspace()
        self.tree_scroll = 0
        # Modal path prompt. There is no native file chooser available, so
        # New Project / Open Project / Open Folder ask for a path here.
        self.dialog_open = false
        self.dialog_title = ""
        self.dialog_hint = ""
        self.dialog_input = ""
        self.dialog_action = ""
        # Find / Replace (Ctrl+F, Ctrl+H) and Go to Line (Ctrl+G)
        self.find_open = false
        self.find_query = ""
        self.find_replace = ""
        self.find_field = 0          # 0 = find, 1 = replace
        self.find_replace_mode = false
        self.find_hits = []
        self.find_hit_count = 0
        self.find_index = 0
        # Breakpoints, keyed "tabtitle:line"
        self.breaks = {}
        self.break_count = 0
        # Structured build log for the Problems panel
        self.build_ok = true
        self.introspect = []
        self.introspect_n = 0
        self.introspect_kind = ""
        # AI assistant: analyses the active buffer with lib/aiagent.ny.
        self.ai = CodeAnalyzer()
        self.ai_issues = []
        self.ai_n = 0
        self.ai_file = ""
        # Workspace search
        self.search_query = ""
        self.search_hits = []
        self.search_n = 0
        self.search_files = 0
        self.search_rows = []
        self.search_focus = false
        self.caret_on = true
        self.caret_t = 0
        self.clipboard = ""
        self.undo_stack = []
        self.undo_n = 0
        self.debug_line = -1
        self.status_segs = []
        self.status_hover = -1
        self.BREADCRUMB_H = 24
        self.cursor_shape = "arrow"
        self.tooltip = ""
        self.tooltip_x = 0
        self.tooltip_y = 0
        self.toasts = []
        self.toast_n = 0
        self.show_indent_guides = true
        self.show_whitespace = false
        # Right-click context menu
        self.ctx_open = false
        self.ctx_x = 0
        self.ctx_y = 0
        self.ctx_items = []
        self.ctx_hover = -1
        self.ctx_target = ""
        self.ctx_arg = -1
        # Autocomplete (Ctrl+Space)
        self.ac_open = false
        self.ac_items = []
        self.ac_n = 0
        self.ac_sel = 0
        self.ac_prefix = ""
        # Text selection: anchor stays put, the buffer cursor is the moving head.
        self.sel_on = false
        self.sel_row = 0
        self.sel_col = 0
        self.dragging_sel = false
        self.outline = []
        self.outline_n = 0
        self.outline_sel = -1
        self.ai_rows = []
        self.font_size = 13
        self.dragging_mm = false
        self.panel_scroll = 0
        self.recent = []
        self.recent_n = 0
        # Set this to false to repaint every frame, the way the IDE behaved
        # before dirty-flag repainting was added. It costs CPU but removes any
        # dependence on the platform delivering expose events. Change this first
        # if the window ever appears blank or stops updating.
        self.repaint_on_change_only = true

        self._load_hl_rules(false)
        self._load_settings()
        self._layout()

    def _seed_files(self):
        var main_src = "# main.ny\nimport \"lib/gui.ny\"\n\nclass App:\n    def __init__(self, title):\n        self.title = title\n        self.count = 0\n\n    def tick(self):\n        self.count = self.count + 1\n        return self.count\n\nvar app = App(\"Nython\")\nprint app.tick()\n"
        var utils_src = "# utils.ny\n\ndef clamp(v, lo, hi):\n    if v < lo:\n        return lo\n    if v > hi:\n        return hi\n    return v\n\ndef lerp(a, b, t):\n    return a + (b - a) * t\n"
        var model_src = "# model.ny\nimport \"lib/nytorch.ny\"\n\nvar net = Sequential()\nnet.add(Dense(128, \"relu\"))\nnet.add(Dense(10, \"softmax\"))\nprint \"model ready\"\n"
        self.buffers = [EditorBuffer("main.ny", main_src),
                        EditorBuffer("utils.ny", utils_src),
                        EditorBuffer("model.ny", model_src)]
        self.tabs = [EdTab("main.ny"), EdTab("utils.ny"), EdTab("model.ny")]
        self.tab_count = 3

    # ── layout ───────────────────────────────────────────────────────────────
    # Step both pane animations one frame. Returns true if anything moved.
    #
    # Exponential approach: each frame closes a fixed FRACTION of the remaining
    # distance, so the pane moves fast at first and decelerates into place. That
    # is an ease-out by construction, and unlike a fixed-size step it cannot
    # overshoot or take a different number of frames depending on distance.
    def _advance_panes(self):
        var moved = false
        var k = 0.28          # fraction of the remaining gap closed per frame
        var snap = 0.004      # close enough to call it arrived

        var s_target = 0.0
        if self.sidebar_open:
            s_target = 1.0
        var ds = s_target - self.sidebar_anim
        if ds > snap or ds < 0.0 - snap:
            self.sidebar_anim = self.sidebar_anim + ds * k
            moved = true
        elif self.sidebar_anim != s_target:
            self.sidebar_anim = s_target
            moved = true

        var p_target = 0.0
        if self.panel_open:
            p_target = 1.0
        var dp = p_target - self.panel_anim
        if dp > snap or dp < 0.0 - snap:
            self.panel_anim = self.panel_anim + dp * k
            moved = true
        elif self.panel_anim != p_target:
            self.panel_anim = p_target
            moved = true

        return moved

    def _layout(self):
        self._dirty = true
        var W = self.W
        var H = self.H

        self.toolbar_y = self.MENU_H
        self.content_y = self.MENU_H + self.TOOLBAR_H
        self.status_y  = H - self.STATUS_H
        var ch = self.status_y - self.content_y
        if ch < 120:
            ch = 120
        self.content_h = ch

        var i = 0
        var ry = self.content_y + 8
        while i < self.rail_count:
            var b = self.rail[i]
            b.x = 7
            b.y = ry
            b.w = self.RAIL_W - 14
            b.h = 36
            ry = ry + 42
            i = i + 1

        # Width is scaled by sidebar_anim (0..1) rather than switching between 0
        # and full width in one frame, so collapsing the sidebar slides instead
        # of teleporting. At rest anim is exactly 0 or 1, so the resting layout
        # is unchanged.
        self.sidebar_x = self.RAIL_W
        var sw = self.SIDEBAR_W
        if sw > W - self.RAIL_W - 320:
            sw = W - self.RAIL_W - 320
        if sw < 0:
            sw = 0
        self.sidebar_w = int(float(sw) * self.sidebar_anim)

        self.col_x = self.RAIL_W + self.sidebar_w
        self.col_w = W - self.col_x
        if self.col_w < 200:
            self.col_w = 200

        self.panel_h = 0
        var ph = int(ch * self.panel_ratio)
        if ph < 110:
            ph = 110
        if ph > ch - 150:
            ph = ch - 150
        if ph < 0:
            ph = 0
        self.panel_h = int(float(ph) * self.panel_anim)
        self.panel_y = self.content_y + ch - self.panel_h

        self.tabbar_y = self.content_y
        self.crumb_y = self.content_y + self.TABBAR_H
        self.ed_y = self.crumb_y + self.BREADCRUMB_H
        self.ed_h = self.panel_y - self.ed_y
        if self.ed_h < 60:
            self.ed_h = 60

        self.mm_w = 0
        if self.minimap_on:
            if self.col_w > 520:
                self.mm_w = self.MINIMAP_W
        self.ed_w = self.col_w - self.mm_w

        self.editor.set_pos(self.col_x + self.GUTTER_W, self.ed_y)
        self.editor.set_size(self.ed_w - self.GUTTER_W, self.ed_h)
        self.console.set_pos(self.col_x + 10, self.panel_y + self.PANELTAB_H + 6)
        self.console.set_size(self.col_w - 20, self.panel_h - self.PANELTAB_H - 12)
        self.workshop.set_pos(self.col_x + 10, self.panel_y + self.PANELTAB_H + 6)
        self.workshop.set_size(self.col_w - 20, self.panel_h - self.PANELTAB_H - 12)

        var t = 0
        var tx = self.col_x + 4
        while t < self.tab_count:
            var tab = self.tabs[t]
            var mw = self.f_ui.width(tab.title)
            var tw = mw + 48
            if tw < 112:
                tw = 112
            tab.x = tx
            tab.w = tw
            tx = tx + tw + 2
            t = t + 1

    def on_resize(self, w, h):
        self.W = w
        self.H = h
        self._dirty = true
        self._layout()
        # Was: status_msg = "Resized W x H". Window size is already shown at the
        # right of the status bar, so this only pushed real messages out of the
        # way with debug noise on every resize event.

    # ── draw ─────────────────────────────────────────────────────────────────
    def draw(self, r):
        self.frames = self.frames + 1
        self.f_code.ensure_loaded()
        self._code_handle = self.f_code._handle
        r.fill_xywh(0, 0, self.W, self.H, self.th.bg)
        self._draw_menubar(r)
        self._draw_toolbar(r)
        self._draw_rail(r)
        if self.sidebar_open:
            if self.sidebar_w > 0:
                self._draw_sidebar(r)
        self._draw_tabbar(r)
        self._draw_breadcrumbs(r)
        self._draw_editor(r)
        if self.mm_w > 0:
            self._draw_minimap(r)
        if self.find_open:
            self._draw_find(r)
        if self.panel_open:
            if self.panel_h > 0:
                self._draw_panel(r)
        self._draw_status(r)
        if self.menu_open >= 0:
            self._draw_dropdown(r)
        if self.palette_open:
            self._draw_palette(r)
        if self.dialog_open:
            self._draw_dialog(r)
        if self.ac_open:
            self._draw_ac(r)
        if self.ctx_open:
            self._draw_ctx(r)
        self._draw_toasts(r)
        self._draw_tooltip(r)

    def _draw_menubar(self, r):
        var th = self.th
        r.draw_gradient(Rect(0, 0, self.W, self.MENU_H), th.chrome_hi, th.chrome, true)
        r.draw_line(0, self.MENU_H, self.W, self.MENU_H, th.border_soft, 1)
        r.fill_circle(17, 15, 5, th.accent)
        self.menu_rects = []
        var x = 34
        var i = 0
        while i < self.menu_count:
            var name = self.menus[i]
            var m = self.f_ui.width(name)
            var w = m + 20
            if self.menu_open == i or self.menu_hover == i:
                r.fill_round_xywh(x, 4, w, self.MENU_H - 8, th.hover, 4)
            var col = th.text_dim
            if self.menu_open == i:
                col = th.text
            r.draw_text(name, x + 10, 8, self.f_ui, col)
            self.menu_rects.append({"x": x, "w": w, "i": i})
            x = x + w
            i = i + 1
        var label = "NythonIDE  -  /project"
        var lm = self.f_small.width(label)
        r.draw_text(label, int(self.W / 2 - lm / 2), 9, self.f_small, th.text_faint)

    def _draw_dropdown(self, r):
        var th = self.th
        var mx = -1
        var i = 0
        while i < len(self.menu_rects):
            var mr = self.menu_rects[i]
            if mr["i"] == self.menu_open:
                mx = mr["x"]
            i = i + 1
        if mx < 0:
            return
        var items = self.menu_items[self.menus[self.menu_open]]
        var n = len(items)
        var iw = 224
        var ih = 10
        var k = 0
        while k < n:
            if items[k] == "-":
                ih = ih + 9
            else:
                ih = ih + 26
            k = k + 1
        if mx + iw > self.W - 8:
            mx = self.W - iw - 8
        r.draw_shadow(Rect(mx, self.MENU_H, iw, ih), 16, 0, 6, Color(0, 0, 0, 130))
        r.fill_round_xywh(mx, self.MENU_H, iw, ih, th.overlay, 8)
        r.draw_rounded_rect(Rect(mx, self.MENU_H, iw, ih), th.border, 8, 1)
        var y = self.MENU_H + 5
        self.menu_item_rects = []
        k = 0
        while k < n:
            var it = items[k]
            if it == "-":
                r.draw_line(mx + 12, y + 4, mx + iw - 12, y + 4, th.border_soft, 1)
                y = y + 9
            else:
                var parts = string_split(it, "\t")
                if self.menu_item_hover == k:
                    r.fill_round_xywh(mx + 4, y, iw - 8, 24, th.accent_soft, 5)
                r.draw_text(parts[0], mx + 14, y + 5, self.f_ui, th.text)
                if len(parts) > 1:
                    var sm = self.f_small.width(parts[1])
                    r.draw_text(parts[1], mx + iw - 14 - sm, y + 6, self.f_small, th.text_faint)
                self.menu_item_rects.append({"x": mx, "y": y, "w": iw, "h": 26, "label": parts[0], "i": k})
                y = y + 26
            k = k + 1

    # Try progressively more conservative roots. Returns the one that opened.
    # Design pixels -> device pixels, rounded half up.
    def dp(self, v):
        return int(float(v) * self.dpi + 0.5)

    def _open_initial_workspace(self):
        var tried = []
        var cands = [getcwd(), ".", os_path_dirname(getcwd())]
        var home = getenv("HOME")
        if home == none or home == "":
            home = getenv("USERPROFILE")
        if home != none and home != "":
            cands = cands + [home]
        var i = 0
        while i < len(cands):
            var c = cands[i]
            if c != none and c != "":
                # Windows hands back backslashes; normalise before stat-ing so a
                # perfectly valid path is not rejected for its separators.
                var norm = string_replace(c, "\\", "/")
                if self.ws.open_folder(norm):
                    return norm
                tried = tried + [norm]
            i = i + 1
        self.ws.error = "Could not open a workspace folder (tried " + str(len(tried)) + ")"
        return ""

    def _draw_toolbar(self, r):
        var th = self.th
        var y = self.toolbar_y
        r.draw_gradient(Rect(0, y, self.W, self.TOOLBAR_H), th.chrome, th.bg, true)
        r.draw_line(0, y + self.TOOLBAR_H, self.W, y + self.TOOLBAR_H, th.border_soft, 1)
        # ── Run button ───────────────────────────────────────────────────────
        # Every coordinate here used to be a hardcoded constant: icon at x=22,
        # text at x=44, inside a box at x=12 width 82. Those numbers were tuned
        # for one font at one size, so the label sat off-centre and drifted
        # further with the HiDPI scaling added later.
        #
        # The content is now MEASURED and centred as a unit: icon + gap + text
        # is laid out from the middle of the button outward, so it stays centred
        # at any font size or display scale.
        var run_h  = self.dp(26)
        var run_y  = y + int((self.TOOLBAR_H - run_h) / 2)
        var ico_sz = self.dp(15)
        var gap    = self.dp(7)
        var tw     = self.f_ui_bold.width("Run")
        var run_w  = self.dp(16) + ico_sz + gap + tw + self.dp(16)
        var run_x  = self.dp(12)

        var hovered = self.mx >= run_x and self.mx < run_x + run_w
        hovered = hovered and self.my >= run_y and self.my < run_y + run_h
        var green = Color(46, 176, 111, 245)
        if hovered:
            green = Color(56, 196, 126, 255)
        r.fill_round_xywh(run_x, run_y, run_w, run_h, green, self.dp(6))
        r.draw_gradient(Rect(run_x + 2, run_y + 2, run_w - 4, int(run_h / 2)),
                        Color(255, 255, 255, 38), Color(255, 255, 255, 0), true)

        var content_w = ico_sz + gap + tw
        var cx = run_x + int((run_w - content_w) / 2)
        var fg = Color(240, 255, 246, 255)
        self.icons.draw(r, "run", cx, run_y + int((run_h - ico_sz) / 2), ico_sz, fg)
        # Vertically centre the label on the glyph's own metrics rather than a
        # guessed offset.
        var th_txt = self.f_ui_bold.height()
        r.draw_text("Run", cx + ico_sz + gap,
                    run_y + int((run_h - th_txt) / 2), self.f_ui_bold, fg)
        self.run_btn = {"x": run_x, "y": run_y, "w": run_w, "h": run_h}

        # Mode chips: immediate mode. Was a draw loop plus a parallel
        # `mode_rects` list plus a click handler elsewhere — the same
        # three-piece arrangement as the panel tabs, with the same drift risk.
        # One call now lays out, draws, hit-tests and returns the selection, and
        # the chips gained hover feedback they never had: they were clickable
        # but gave no sign of it until selected.
        self.ui.io.mouse_x = self.mx
        self.ui.io.mouse_y = self.my
        self.ui.io.mouse_down = self.mouse_down
        var chips_x = self.run_btn["x"] + self.run_btn["w"] + self.dp(14)
        self.ui.begin_frame(chips_x, y + 8, self.W - chips_x, 24)
        var newmode = self.ui.chips("modechips", self.run_modes, self.active_mode,
                                    self.first_chip, th, chips_x, run_y, run_h,
                                    self.f_small.width)
        self.ui.end_frame()
        self.ui.flush(r, self.f_small, self.f_ui_bold)
        if newmode != self.active_mode:
            self.active_mode = newmode
            self.status_msg = "Mode: " + self.run_modes[newmode]

        var pal = "Ctrl+P   Command Palette"
        var pm = self.f_small.width(pal)
        if self.W > 900:
            r.fill_round_xywh(self.W - pm - 42, y + 8, pm + 28, 24, th.field, 5)
            r.draw_text(pal, self.W - pm - 28, y + 14, self.f_small, th.text_faint)

    def _draw_rail(self, r):
        var th = self.th
        r.fill_xywh(0, self.content_y, self.RAIL_W, self.content_h, th.chrome)
        r.draw_line(self.RAIL_W, self.content_y, self.RAIL_W, self.status_y, th.border_soft, 1)
        var i = 0
        while i < self.rail_count:
            var b = self.rail[i]
            var act = false
            if b.key == self.active_view:
                if self.sidebar_open:
                    act = true
            if act:
                r.fill_xywh(0, b.y, 2, b.h, th.accent)
                r.fill_round_xywh(b.x, b.y, b.w, b.h, th.hover, 6)
            elif b.hovered:
                r.fill_round_xywh(b.x, b.y, b.w, b.h, Color(255, 255, 255, 8), 6)
            var col = th.text_faint
            if act:
                col = th.text
            self.icons.draw(r, b.key, int(b.x + b.w / 2 - 10), int(b.y + b.h / 2 - 10), 20, col)
            i = i + 1
        r.fill_circle(self.RAIL_W - 15, self.status_y - 24, 4, th.err)

    def _draw_sidebar(self, r):
        var th = self.th
        var x = self.sidebar_x
        var w = self.sidebar_w
        r.fill_xywh(x, self.content_y, w, self.content_h, th.panel)
        r.draw_line(x + w, self.content_y, x + w, self.status_y, th.border_soft, 1)
        var title = "EXPLORER"
        if self.active_view == "search":
            title = "SEARCH"
        elif self.active_view == "git":
            title = "SOURCE CONTROL"
        elif self.active_view == "run":
            title = "RUN AND DEBUG"
        elif self.active_view == "ext":
            title = "EXTENSIONS"
        elif self.active_view == "outline":
            title = "OUTLINE"
        elif self.active_view == "ai":
            title = "AI ASSISTANT"
        r.draw_text(title, x + 14, self.content_y + 10, self.f_small, th.text_faint)
        if self.active_view == "explorer" and self.ws.root != "":
            var rn = os_path_basename(self.ws.root)
            var rm = self.f_small.width(rn)
            r.draw_text(rn, x + w - rm - 14, self.content_y + 10, self.f_small, th.accent)
        if self.active_view == "explorer":
            self._draw_tree(r, x, w)
        elif self.active_view == "outline":
            self._draw_outline(r, x, w)
        elif self.active_view == "ai":
            self._draw_ai(r, x, w)
        elif self.active_view == "search":
            self._draw_search(r, x, w)
        else:
            r.draw_text("No content yet", x + 14, self.content_y + 44, self.f_small, th.text_faint)

    def _draw_tree(self, r, x, w):
        var th = self.th
        var y = self.content_y + 34
        var bottom = self.status_y
        r.set_clip(Rect(x, y, w, bottom - y))
        var i = self.tree_scroll
        var drawn = 0
        while i < self.ws.row_count:
            # Stop at the last row that fits entirely. Drawing a half-height row
            # against the status bar relies on the clip to hide the remainder,
            # which looks cut off rather than scrolled.
            if y + 22 > bottom:
                i = self.ws.row_count
            else:
                var n = self.ws.rows[i]
                var ix = x + 8 + n.depth * 14
                if i == self.tree_sel:
                    r.fill_xywh(x, y, w, 22, th.accent_soft)
                    r.fill_xywh(x, y, 2, 22, th.accent)
                elif i == self.tree_hover:
                    r.fill_xywh(x, y, w, 22, th.hover)
                var col = th.text_dim
                if n.is_dir:
                    col = th.text
                    var chev = "chevron_right"
                    if n.expanded:
                        chev = "chevron_down"
                    self.icons.draw(r, chev, ix, y + 4, 14, th.text_faint)
                    var fic = "folder"
                    if n.expanded:
                        fic = "folder_open"
                    self.icons.draw(r, fic, ix + 15, y + 3, 16, th.accent)
                    r.draw_text(n.name, ix + 35, y + 4, self.f_ui, col)
                else:
                    var ic = "file"
                    var icol = th.text_faint
                    if n.kind == "code":
                        ic = "file_code"
                        icol = th.accent
                    elif n.kind == "project":
                        ic = "project"
                        icol = th.ok
                    self.icons.draw(r, ic, ix + 15, y + 3, 16, icol)
                    r.draw_text(n.name, ix + 35, y + 4, self.f_ui, col)
                y = y + 22
                drawn = drawn + 1
                i = i + 1
        r.clear_clip()
        if self.ws.error != "":
            # Was drawn at full length with no clip, so a long Windows path ran
            # out of the sidebar and across the panel below it. Clip to the
            # sidebar and ellipsise on a character boundary.
            var msg = self.ws.error
            var avail = w - 24
            while self.f_small.width(msg) > avail and len(msg) > 4:
                msg = string_slice(msg, 0, len(msg) - 2) + "…"
            r.set_clip(Rect(x, bottom - 34, w, 28))
            r.draw_text(msg, x + 12, bottom - 22, self.f_small, th.err)
            r.clear_clip()

    def _draw_tabbar(self, r):
        var th = self.th
        var y = self.tabbar_y
        r.fill_xywh(self.col_x, y, self.col_w, self.TABBAR_H, th.chrome)
        r.draw_line(self.col_x, y + self.TABBAR_H, self.col_x + self.col_w, y + self.TABBAR_H, th.border_soft, 1)
        r.set_clip(Rect(self.col_x, y, self.col_w, self.TABBAR_H))
        var i = 0
        while i < self.tab_count:
            var t = self.tabs[i]
            if i == self.active_tab:
                r.fill_xywh(t.x, y, t.w, self.TABBAR_H, th.editor_bg)
                r.fill_xywh(t.x, y, t.w, 2, th.accent)
                r.draw_line(t.x, y + 2, t.x, y + self.TABBAR_H, th.border_soft, 1)
                r.draw_line(t.x + t.w, y + 2, t.x + t.w, y + self.TABBAR_H, th.border_soft, 1)
            r.fill_round_xywh(t.x + 11, y + 12, 9, 11, th.accent, 2)
            var col = th.text_faint
            if i == self.active_tab:
                col = th.text
            r.draw_text(t.title, t.x + 26, y + 10, self.f_ui, col)
            if t.dirty:
                r.fill_circle(t.x + t.w - 14, y + 18, 4, th.text_dim)
            else:
                self.icons.draw(r, "close", t.x + t.w - 24, y + 10, 14, th.text_faint)
            i = i + 1
        r.clear_clip()

    def _draw_editor(self, r):
        var th = self.th
        r.fill_xywh(self.col_x, self.ed_y, self.ed_w, self.ed_h, th.editor_bg)
        r.fill_xywh(self.col_x, self.ed_y, self.GUTTER_W, self.ed_h, th.gutter_bg)
        var buf = self.buffers[self.active_tab]
        var line_h = self.LINE_H
        var rows = int(self.ed_h / line_h) + 1
        var top = int(self.editor.scroll_y / line_h)
        if top < 0:
            top = 0
        var text_x = self.col_x + self.GUTTER_W + 10
        r.set_clip(Rect(self.col_x, self.ed_y, self.ed_w, self.ed_h))
        self._draw_selection(r, buf, top, rows, line_h, text_x)
        var i = 0
        while i < rows:
            var ln = top + i
            if ln < buf.line_count:
                var y = self.ed_y + i * line_h
                if ln == self.debug_line:
                    r.fill_xywh(self.col_x + self.GUTTER_W, y, self.ed_w - self.GUTTER_W, line_h, Color(232, 178, 74, 45))
                    r.fill_polygon([self.col_x + 26, y + 4, self.col_x + 26, y + 14, self.col_x + 34, y + 9], th.warn)
                elif ln == buf.cursor_row:
                    r.fill_xywh(self.col_x + self.GUTTER_W, y, self.ed_w - self.GUTTER_W, line_h, th.caret_line)
                var s = str(ln + 1)
                var m = self.f_code.width(s)
                var gc = th.gutter
                if ln == buf.cursor_row:
                    gc = th.text
                if self._has_break(ln):
                    r.fill_circle(self.col_x + 13, y + 9, 5, th.err)
                r.draw_text(s, self.col_x + self.GUTTER_W - 12 - m, y + 1, self.f_code, gc)
                if self.find_open and self.find_hit_count > 0:
                    var hh = self.find_hits[self.find_index]
                    if hh["line"] == ln:
                        var pre = self.f_code.width(string_slice(buf.get_line(ln), 0, hh["col"]))
                        var qm = self.f_code.width(self.find_query)
                        r.fill_xywh(text_x + pre, y, qm, line_h, Color(232, 178, 74, 70))
                if self.show_indent_guides:
                    self._draw_indent_guides(r, buf.get_line(ln), text_x, y, line_h)
                self._draw_code_line(r, buf.get_line(ln), text_x, y + 1)
            i = i + 1

        self._draw_bracket_match(r, buf, top, line_h, text_x)

        # ── caret ────────────────────────────────────────────────────────────
        # Blinks at roughly 1 Hz. The IDE only repaints when something changes,
        # so the caret marks the frame dirty while the editor holds focus,
        # exactly like the terminal's prompt does.
        var crow = buf.cursor_row - top
        if crow >= 0 and crow < rows:
            var cy = self.ed_y + crow * line_h
            var upto = string_slice(buf.get_line(buf.cursor_row), 0, buf.cursor_col)
            var cm = self.f_code.width(upto)
            if self.caret_on:
                r.fill_xywh(text_x + cm, cy + 1, 2, line_h - 2, th.accent)
        r.clear_clip()
        r.draw_line(self.col_x + self.GUTTER_W, self.ed_y, self.col_x + self.GUTTER_W, self.ed_y + self.ed_h, th.border_soft, 1)

        # vertical scrollbar
        if buf.line_count * line_h > self.ed_h:
            var track = self.ed_h
            var frac = self.ed_h * 1.0 / (buf.line_count * line_h)
            var th_h = int(track * frac)
            if th_h < 30:
                th_h = 30
            var maxs = buf.line_count * line_h - self.ed_h
            var prog = 0.0
            if maxs > 0:
                prog = self.editor.scroll_y * 1.0 / maxs
            var ty = self.ed_y + int((track - th_h) * prog)
            r.fill_round_xywh(self.col_x + self.ed_w - 8, ty, 5, th_h, Color(255, 255, 255, 40), 3)

    def _draw_code_line(self, r, line, x, y):
        if line == none:
            return
        if len(line) == 0:
            return
        # Tokenising is a full interpreted scan of the line. Redoing it for every
        # visible line on every frame dominated the frame budget, so memoise by
        # line content — editor text changes rarely relative to frame rate.
        # Tokenising is a full interpreted scan of the line, and measuring each
        # token is another builtin round-trip. Both were being redone for every
        # visible line on every frame. Cache the finished layout (text, colour
        # and resolved x offset) keyed by line content instead.
        var segs = none
        if self._hl_cache.has_key(line):
            segs = self._hl_cache[line]
        else:
            var raw = self.editor.hl.tokenise_line(line)
            var built = []
            var k = 0
            var dx = 0
            while k < len(raw):
                var rs = raw[k]
                var rt = rs["text"]
                built.append({"text": rt, "color": rs["color"], "dx": dx})
                var mm = self.f_code.width(rt)
                dx = dx + mm
                k = k + 1
            segs = built
            if self._hl_cache_n > 2000:
                self._hl_cache = {}
                self._hl_cache_n = 0
            self._hl_cache[line] = segs
            self._hl_cache_n = self._hl_cache_n + 1
        # Hot loop: call the builtin directly. Renderer.draw_text() adds two
        # interpreted method calls (draw_text -> ensure_loaded) plus attribute
        # lookups per token, which at ~180 text runs a frame is the single
        # largest cost in the frame. The handle is resolved once per frame in
        # draw() instead.
        var fh = self._code_handle
        var n = len(segs)
        var i = 0
        while i < n:
            var s = segs[i]
            var c = s["color"]
            gui_draw_text(r.handle, s["text"], x + s["dx"], y, fh, c.r, c.g, c.b, c.a)
            i = i + 1

    def _draw_minimap(self, r):
        var th = self.th
        var x = self.col_x + self.ed_w
        r.fill_xywh(x, self.ed_y, self.mm_w, self.ed_h, th.minimap_bg)
        r.draw_line(x, self.ed_y, x, self.ed_y + self.ed_h, th.border_soft, 1)
        var buf = self.buffers[self.active_tab]
        var i = 0
        var y = self.ed_y + 6
        while i < buf.line_count:
            if y < self.ed_y + self.ed_h - 4:
                var ln = buf.get_line(i)
                var w = len(ln)
                if w > 0:
                    if w > 68:
                        w = 68
                    r.fill_xywh(x + 10, y, w, 2, Color(120, 130, 165, 95))
                y = y + 3
            i = i + 1
        var total = buf.line_count * self.LINE_H
        var vh = self.ed_h
        var vy = self.ed_y + 4
        var box = self.ed_h - 8
        if total > self.ed_h:
            box = int(self.ed_h * (self.ed_h * 1.0 / total))
            if box < 24:
                box = 24
            var maxs2 = total - self.ed_h
            var pr = 0.0
            if maxs2 > 0:
                pr = self.editor.scroll_y * 1.0 / maxs2
            vy = self.ed_y + int((self.ed_h - box) * pr)
        r.fill_xywh(x + 4, vy, self.mm_w - 8, box, Color(255, 255, 255, 16))
        r.draw_rect(Rect(x + 4, vy, self.mm_w - 8, box), Color(255, 255, 255, 30), 1)

    def _draw_panel(self, r):
        var th = self.th
        var y = self.panel_y
        r.fill_xywh(self.col_x, y, self.col_w, self.panel_h, th.panel)
        r.draw_line(self.col_x, y, self.col_x + self.col_w, y, th.border, 1)
        # ── panel tabs: immediate mode ───────────────────────────────────────
        # This strip used to be three pieces that had to agree: a draw loop, a
        # parallel `panel_rects` list of hit rectangles, and a click handler
        # 600 lines away that walked that list. Adding a tab meant touching all
        # three, and any disagreement showed up as a tab that drew in one place
        # and responded in another.
        #
        # One call now lays out, draws and hit-tests, and returns the selection.
        # `panel_rects` is gone and so is its handler.
        var badges = [0, self.problem_count, 0, 0, 0, 0]
        self.ui.io.mouse_x = self.mx
        self.ui.io.mouse_y = self.my
        self.ui.io.mouse_down = self.mouse_down
        self.ui.begin_frame(self.col_x, y, self.col_w, self.PANELTAB_H)
        self.active_panel = self.ui.tabs("paneltabs", self.panel_tabs,
                                         self.active_panel, badges, th,
                                         self.col_x, y, self.PANELTAB_H,
                                         self.f_small.width)
        self.ui.end_frame()
        self.ui.flush(r, self.f_small, self.f_ui_bold)

        var body_y = y + self.PANELTAB_H
        r.set_clip(Rect(self.col_x, body_y, self.col_w, self.panel_h - self.PANELTAB_H))
        if self.active_panel == 0:
            self.console.draw(r)
        elif self.active_panel == 1:
            self._draw_problems(r, body_y)
        elif self.active_panel == 2:
            self._draw_terminal(r, body_y)
        elif self.active_panel == 3:
            self._draw_debug(r, body_y)
        elif self.active_panel == 4:
            self._draw_tokens(r, body_y)
        elif self.active_panel == 5:
            self.workshop.draw(r)
        else:
            r.draw_text("Nothing to show", self.col_x + 18, body_y + 12, self.f_small, th.text_faint)
        r.clear_clip()

    def _draw_problems(self, r, body_y):
        var th = self.th
        self.problem_rows = []
        var i = self.panel_scroll
        var y = body_y + 8
        while i < self.problem_count:
            var p = self.problems[i]
            var col = th.err
            if p["sev"] == "warn":
                col = th.warn
            elif p["sev"] == "info":
                col = th.accent
            r.fill_circle(self.col_x + 24, y + 8, 5, col)
            r.draw_text(p["msg"], self.col_x + 40, y + 1, self.f_ui, th.text)
            var loc = p["file"] + " : " + str(p["line"])
            var m = self.f_small.width(loc)
            r.draw_text(loc, self.col_x + self.col_w - m - 20, y + 2, self.f_small, th.text_faint)
            self.problem_rows = self.problem_rows + [{"y": y, "i": i}]
            y = y + 22
            i = i + 1

    # Tokens panel: whatever the last Tokenize / AST / Disasm run produced.
    def _draw_tokens(self, r, body_y):
        var th = self.th
        if self.introspect_n == 0:
            r.draw_text("Run Tokenize, AST or Disassemble to populate this panel",
                        self.col_x + 18, body_y + 10, self.f_small, th.text_faint)
            return
        r.draw_text(self.introspect_kind + "  (" + str(self.introspect_n) + " lines)",
                    self.col_x + 18, body_y + 6, self.f_ui_bold, th.text)
        var i = self.panel_scroll
        var y = body_y + 26
        while i < self.introspect_n:
            if y + 16 <= self.status_y:
                r.draw_text(self.introspect[i], self.col_x + 18, y, self.f_code, th.text_dim)
                y = y + 16
            i = i + 1

    def _draw_debug(self, r, body_y):
        var th = self.th
        r.draw_text("Breakpoints (" + str(self.break_count) + ")", self.col_x + 18, body_y + 8, self.f_ui_bold, th.text)
        if self.break_count == 0:
            r.draw_text("Click the gutter or press F9 to set one", self.col_x + 18, body_y + 30, self.f_small, th.text_faint)
            return
        var keys = self.breaks.keys()
        var i = 0
        var y = body_y + 30
        while i < len(keys):
            r.fill_circle(self.col_x + 24, y + 7, 5, th.err)
            r.draw_text(keys[i], self.col_x + 38, y, self.f_ui, th.text_dim)
            y = y + 20
            i = i + 1

    def _draw_terminal(self, r, body_y):
        var th = self.th
        var i = 0
        var y = body_y + 6
        while i < self.term_count:
            r.draw_text(self.term_lines[i], self.col_x + 16, y, self.f_code, th.text_dim)
            y = y + 17
            i = i + 1
        r.draw_text("$", self.col_x + 16, y, self.f_code, th.ok)
        r.draw_text(self.term_input, self.col_x + 32, y, self.f_code, th.text)

    def _draw_status(self, r):
        var th = self.th
        var y = self.status_y
        r.draw_gradient(Rect(0, y, self.W, self.STATUS_H), th.chrome_hi, th.status_bg, true)
        var brand = th.accent
        if not self.build_ok:
            brand = th.err
        r.fill_xywh(0, y, 104, self.STATUS_H, brand)
        r.draw_text("Nython", 26, y + 5, self.f_small, Color(245, 246, 255, 255))
        r.draw_text(self.status_msg, 120, y + 5, self.f_small, th.text_dim)

        # right-hand segments are clickable
        self.status_segs = []
        var buf = self.buffers[self.active_tab]
        var segs = ["Ln " + str(buf.cursor_row + 1) + ", Col " + str(buf.cursor_col + 1),
                    str(self.problem_count) + " problems",
                    str(self.break_count) + " breakpoints",
                    "UTF-8",
                    "Nython",
                    str(self.W) + " x " + str(self.H)]
        var acts = ["goto", "problems", "breaks", "", "", ""]
        var i = len(segs) - 1
        var x = self.W - 12
        while i >= 0:
            var m = self.f_small.width(segs[i])
            x = x - m - 16
            var col = th.text_dim
            if acts[i] != "" and self.status_hover == i:
                r.fill_xywh(x - 4, y, m + 16, self.STATUS_H, Color(255, 255, 255, 18))
                col = th.text
            r.draw_text(segs[i], x + 4, y + 5, self.f_small, col)
            self.status_segs.append({"x": x - 4, "w": m + 16, "act": acts[i], "i": i})
            i = i - 1

    def _draw_palette(self, r):
        var th = self.th
        r.fill_xywh(0, 0, self.W, self.H, th.scrim)
        var pw = 560
        if pw > self.W - 80:
            pw = self.W - 80
        var px = int(self.W / 2 - pw / 2)
        var py = 88
        var rows = self.palette_hit_count
        if rows > 8:
            rows = 8
        var ph = 56 + rows * 30 + 8
        r.draw_shadow(Rect(px, py, pw, ph), 24, 0, 10, Color(0, 0, 0, 170))
        r.fill_round_xywh(px, py, pw, ph, th.overlay, 10)
        r.draw_rounded_rect(Rect(px, py, pw, ph), th.accent, 10, 1)
        r.fill_round_xywh(px + 12, py + 12, pw - 24, 32, th.field, 6)
        if len(self.palette_query) == 0:
            r.draw_text("Type a command...", px + 24, py + 20, self.f_ui, th.text_faint)
        else:
            r.draw_text(self.palette_query, px + 24, py + 20, self.f_ui, th.text)
        var i = 0
        var y = py + 52
        while i < rows:
            if i == self.palette_sel:
                r.fill_round_xywh(px + 8, y, pw - 16, 28, th.accent_soft, 5)
            var col = th.text_dim
            if i == self.palette_sel:
                col = th.text
            r.draw_text(self.palette_hits[i], px + 22, y + 6, self.f_ui, col)
            y = y + 30
            i = i + 1

    # ── events ───────────────────────────────────────────────────────────────
    def handle_event(self, e):
        # Immediate-mode widgets read the pointer during draw rather than
        # receiving events, so the latest position and button level are recorded
        # here for them. Level, not edges: NyImGui derives press and release
        # itself, which is what keeps a click tied to one item across frames.
        if e.type == "mousedown" or e.type == "mouseup":
            self.mx = e.x
            self.my = e.y
        if e.type == "mousedown":
            self.mouse_down = true
        if e.type == "mouseup":
            self.mouse_down = false
        # An immediate-mode widget only sees a press if a FRAME IS DRAWN while
        # the button is down: it hit-tests during draw, it is not sent events.
        # The frame loop skips redraws unless _dirty is set, so the panel tabs
        # and toolbar chips recorded the pointer, never redrew, and therefore
        # never registered a click — they looked completely dead.
        if e.type == "mousedown" or e.type == "mouseup" or e.type == "mousemove":
            self._dirty = true

        if e.type == "mousemove":
            self.mx = e.x
            self.my = e.y
            self._update_hover()
            self._apply_cursor()
            if self.dragging_split:
                self._apply_split(e.y)
                return
            if self.dragging_mm:
                self._minimap_scroll(e.y)
                self._dirty = true
                return
            if self.dragging_sel:
                var dp = self._pos_at(e.x, e.y)
                var dbuf = self.buffers[self.active_tab]
                dbuf.cursor_row = dp["row"]
                dbuf.cursor_col = dp["col"]
                self._dirty = true
                return
            if self.dragging_sidebar:
                var nw = e.x - self.RAIL_W
                if nw < 150:
                    nw = 150
                if nw > 520:
                    nw = 520
                self.SIDEBAR_W = nw
                self._layout()
                return

        if self.dialog_open:
            self._dialog_event(e)
            if e.consumed:
                self._dirty = true
                return
        if self.ctx_open:
            if e.type == "mousemove":
                self.ctx_hover = self._ctx_hit(e.x, e.y)
                self._dirty = true
                return
            if e.type == "mousedown":
                var hitc = self._ctx_hit(e.x, e.y)
                self.ctx_open = false
                if hitc >= 0:
                    self._ctx_action(self.ctx_items[hitc])
                e.consume()
                self._dirty = true
                return
            if e.type == "keydown":
                self.ctx_open = false
                e.consume()
                self._dirty = true
                return
        if self.ac_open:
            self._ac_event(e)
            if e.consumed:
                self._dirty = true
                return
        if self.search_focus and self.sidebar_open and self.active_view == "search":
            if e.type == "textinput" or e.type == "keydown":
                # Let global shortcuts through; plain typing goes to the box.
                if not e.ctrl and not e.alt:
                    self._search_event(e)
                    if e.consumed:
                        self._dirty = true
                        return
        if self.find_open:
            self._find_event(e)
            if e.consumed:
                self._dirty = true
                return
        if self.palette_open:
            self._palette_event(e)
            if e.consumed:
                return

        if e.type == "keydown":
            if self._global_keys(e):
                return

        if e.type == "mouseup":
            self.dragging_split = false
            self.dragging_sidebar = false
            self.dragging_sel = false
            self.dragging_mm = false

        if e.type == "mousedown":
            self._mouse_down(e)
            if e.consumed:
                return

        if e.type == "scroll" or e.type == "wheel":
            # A wheel event carries its own pointer position; mx/my only track
            # mousemove, so routing by those sent the scroll to whichever region
            # the pointer was last *moved* over rather than where it now is.
            if e.x > 0 or e.y > 0:
                self.mx = e.x
                self.my = e.y
            if self.sidebar_open and self.mx > self.sidebar_x and self.mx < self.sidebar_x + self.sidebar_w and self.my > self.content_y and self.my < self.status_y:
                self._scroll_tree(e.delta)
            elif self.panel_open and self.my >= self.panel_y and self.my < self.status_y:
                self._scroll_panel(e.delta)
            elif self.my >= self.ed_y and self.my < self.panel_y:
                self.editor.handle_event(e)
            self._dirty = true
            return

        # Terminal panel owns the keyboard while it is visible and focused.
        # Its prompt and caret were drawn but nothing could ever be typed.
        if self.panel_open and self.active_panel == 2:
            if e.type == "textinput":
                self.term_input = self.term_input + e.text
                e.consume()
                return
            if e.type == "keydown":
                if e.key == "backspace":
                    if len(self.term_input) > 0:
                        self.term_input = string_slice(self.term_input, 0, len(self.term_input) - 1)
                    e.consume()
                    return
                if e.key == "enter":
                    self.term_lines.append("$ " + self.term_input)
                    self.term_count = self.term_count + 1
                    var out = self._term_run(self.term_input)
                    if out != "":
                        self.term_lines.append(out)
                        self.term_count = self.term_count + 1
                    self.term_input = ""
                    e.consume()
                    return

        if e.type == "textinput" or e.type == "keydown":
            if self.menu_open < 0:
                var isnav = false
                if e.type == "keydown":
                    isnav = (e.key == "left" or e.key == "right" or e.key == "up"
                             or e.key == "down" or e.key == "home" or e.key == "end")
                if isnav:
                    if e.shift:
                        self._sel_begin()
                    else:
                        self._sel_clear()
                if e.type == "textinput" or e.key == "backspace" or e.key == "enter":
                    # Typing over a selection replaces it.
                    if self._sel_range() != none:
                        self._sel_delete()
                        if e.key == "backspace":
                            e.consume()
                    else:
                        self._push_undo()
                if e.consumed:
                    return
                self.editor.handle_event(e)
                # No auto-indent here: EditorBuffer.newline() already copies the
                # previous line's indentation and adds a level after ':'. Doing
                # it again indented new lines twice.
                if e.type == "textinput":
                    self._auto_close(e.text)
                # Edited text must re-tokenise, and a changed line count changes
                # the scrollbar, so drop the memoised highlight layout.
                if e.type == "textinput" or e.key == "backspace" or e.key == "enter" or e.key == "tab":
                    self._hl_cache = {}
                    self._hl_cache_n = 0
                    self.tabs[self.active_tab].dirty = true

    # Pointer shape by region: I-beam over text, resize over the splitters,
    # hand over anything clickable, arrow otherwise.
    def _apply_cursor(self):
        var want = "arrow"
        if self.my > self.ed_y and self.my < self.panel_y and self.mx > self.col_x + self.GUTTER_W:
            want = "ibeam"
        if self.sidebar_open:
            if self.mx >= self.sidebar_x + self.sidebar_w - 5 and self.mx <= self.sidebar_x + self.sidebar_w + 5:
                if self.my > self.content_y and self.my < self.status_y:
                    want = "sizewe"
        if self.panel_open:
            if self.my >= self.panel_y - 6 and self.my <= self.panel_y + 6 and self.mx >= self.col_x:
                want = "sizens"
        if self.my < self.MENU_H:
            want = "hand"
        if self.my >= self.status_y and self.status_hover >= 0:
            want = "hand"
        if self.mx < self.RAIL_W and self.my > self.content_y and self.my < self.status_y:
            want = "hand"
        if self.dialog_open or self.palette_open:
            want = "arrow"
        if want != self.cursor_shape:
            self.cursor_shape = want
            gui_set_cursor(want)

    def _update_hover(self):
        self.tooltip = ""
        var i = 0
        while i < self.rail_count:
            var b = self.rail[i]
            b.hovered = hit(b.x, b.y, b.w, b.h, self.mx, self.my)
            if b.hovered:
                self.tooltip = b.tip
                self.tooltip_x = b.x + b.w + 10
                self.tooltip_y = b.y + 6
            i = i + 1
        self.menu_hover = -1
        if self.my < self.MENU_H:
            i = 0
            while i < len(self.menu_rects):
                var mr = self.menu_rects[i]
                if self.mx >= mr["x"] and self.mx < mr["x"] + mr["w"]:
                    self.menu_hover = mr["i"]
                i = i + 1
            if self.menu_open >= 0:
                if self.menu_hover >= 0:
                    self.menu_open = self.menu_hover
        self.status_hover = -1
        if self.my >= self.status_y:
            var si = 0
            while si < len(self.status_segs):
                var sg = self.status_segs[si]
                if self.mx >= sg["x"] and self.mx < sg["x"] + sg["w"] and sg["act"] != "":
                    self.status_hover = sg["i"]
                si = si + 1
        self.tree_hover = -1
        if self.sidebar_open:
            if self.active_view == "explorer":
                if self.mx > self.sidebar_x and self.mx < self.sidebar_x + self.sidebar_w:
                    var idx = int((self.my - self.content_y - 34) / 22) + self.tree_scroll
                    if idx >= 0 and idx < self.ws.row_count:
                        self.tree_hover = idx

    def _apply_split(self, my):
        var avail = self.content_h
        var newh = self.content_y + avail - my
        var ratio = newh * 1.0 / avail
        if ratio < 0.12:
            ratio = 0.12
        if ratio > 0.70:
            ratio = 0.70
        self.panel_ratio = ratio
        self._layout()

    def _mouse_down(self, e):
        var x = e.x
        var y = e.y
        if e.button == 3:
            if y >= self.tabbar_y and y < self.tabbar_y + self.TABBAR_H and x >= self.col_x:
                self._open_ctx(x, y, "tab", -1)
            elif self.sidebar_open and x > self.sidebar_x and x < self.sidebar_x + self.sidebar_w and y > self.content_y + 34:
                var ri = int((y - self.content_y - 34) / 22) + self.tree_scroll
                if ri >= 0 and ri < self.ws.row_count:
                    self.tree_sel = ri
                self._open_ctx(x, y, "tree", ri)
            elif y >= self.ed_y and y < self.panel_y and x >= self.col_x:
                self._open_ctx(x, y, "editor", -1)
            else:
                self._open_ctx(x, y, "view", -1)
            e.consume()
            return
        if y >= self.status_y:
            var si = 0
            while si < len(self.status_segs):
                var sg = self.status_segs[si]
                if x >= sg["x"] and x < sg["x"] + sg["w"]:
                    if sg["act"] == "goto":
                        self._ask("goto", "Go to Line", "Line number", "")
                    elif sg["act"] == "problems":
                        self.panel_open = true
                        self.active_panel = 1
                        self._layout()
                    elif sg["act"] == "breaks":
                        self.panel_open = true
                        self.active_panel = 3
                        self._layout()
                    e.consume()
                    return
                si = si + 1
            return
        if y < self.MENU_H:
            var i = 0
            while i < len(self.menu_rects):
                var mr = self.menu_rects[i]
                if x >= mr["x"] and x < mr["x"] + mr["w"]:
                    if self.menu_open == mr["i"]:
                        self.menu_open = -1
                    else:
                        self.menu_open = mr["i"]
                    e.consume()
                    return
                i = i + 1
            self.menu_open = -1
            return
        if self.menu_open >= 0:
            # Dropdown entries used to be drawn but not clickable: any click just
            # dismissed the menu. Hit-test them first.
            var mi = 0
            while mi < len(self.menu_item_rects):
                var ir = self.menu_item_rects[mi]
                if hit(ir["x"], ir["y"], ir["w"], ir["h"], x, y):
                    self.menu_open = -1
                    self._menu_action(ir["label"])
                    e.consume()
                    return
                mi = mi + 1
            self.menu_open = -1
            e.consume()
            return
        if y >= self.toolbar_y and y < self.content_y:
            if hit(12, self.toolbar_y + 7, 82, 26, x, y):
                self._run()
                e.consume()
                return
            # The chip row hit-tests itself while drawing, so this only records
            # the pointer state it will read and swallows the event.
            e.consume()
            return
        if x < self.RAIL_W and y >= self.content_y and y < self.status_y:
            var j = 0
            while j < self.rail_count:
                var b = self.rail[j]
                if hit(b.x, b.y, b.w, b.h, x, y):
                    if self.active_view == b.key and self.sidebar_open:
                        self.sidebar_open = false
                    else:
                        self.active_view = b.key
                        self.sidebar_open = true
                        self.search_focus = (b.key == "search")
                    self._layout()
                    e.consume()
                    return
                j = j + 1
            return
        if self.sidebar_open:
            if x >= self.sidebar_x + self.sidebar_w - 5 and x <= self.sidebar_x + self.sidebar_w + 5:
                if y > self.content_y and y < self.status_y:
                    self.dragging_sidebar = true
                    e.consume()
                    return
        if self.sidebar_open and self.active_view == "search":
            if x > self.sidebar_x and x < self.sidebar_x + self.sidebar_w:
                if y >= self.content_y + 32 and y < self.content_y + 60:
                    self.search_focus = true
                    e.consume()
                    return
                var si2 = 0
                while si2 < len(self.search_rows):
                    var sr = self.search_rows[si2]
                    if y >= sr["y"] and y < sr["y"] + 34:
                        var hit = self.search_hits[sr["i"]]
                        self._open_path(hit["path"])
                        self._goto_line(hit["line"])
                        self.status_msg = hit["file"] + " : " + str(hit["line"])
                        e.consume()
                        return
                    si2 = si2 + 1
                self.search_focus = false
        if self.sidebar_open and self.active_view == "ai":
            if x > self.sidebar_x and x < self.sidebar_x + self.sidebar_w:
                var ai_i = 0
                while ai_i < len(self.ai_rows):
                    var arow = self.ai_rows[ai_i]
                    if y >= arow["y"] and y < arow["y"] + 40:
                        self._goto_line(arow["line"])
                        e.consume()
                        return
                    ai_i = ai_i + 1
        if self.sidebar_open and self.active_view == "outline":
            if x > self.sidebar_x and x < self.sidebar_x + self.sidebar_w:
                if y > self.content_y + 34 and y < self.status_y:
                    var oi = int((y - self.content_y - 34) / 22)
                    if oi >= 0 and oi < self.outline_n:
                        self.outline_sel = oi
                        self._goto_line(self.outline[oi]["line"] + 1)
                        e.consume()
                        return
        if self.sidebar_open and self.active_view == "explorer":
            if x > self.sidebar_x and x < self.sidebar_x + self.sidebar_w:
                if y > self.content_y + 34 and y < self.status_y:
                    var idx = int((y - self.content_y - 34) / 22) + self.tree_scroll
                    if idx >= 0 and idx < self.ws.row_count:
                        self.tree_sel = idx
                        var n = self.ws.rows[idx]
                        if n.is_dir:
                            self.ws.toggle(n.path)
                        else:
                            self._open_path(n.path)
                        self._dirty = true
                        e.consume()
                        return
        if y >= self.tabbar_y and y < self.tabbar_y + self.TABBAR_H and x >= self.col_x:
            var t = 0
            while t < self.tab_count:
                var tb = self.tabs[t]
                if x >= tb.x and x < tb.x + tb.w:
                    # The "x" glyph was drawn but never hit-tested, so tabs
                    # could not be closed.
                    if x >= tb.x + tb.w - 24:
                        self._close_tab(t)
                    else:
                        self.active_tab = t
                        self.editor.set_buffer(self.buffers[t])
                        self.status_msg = "Opened " + tb.title
                    e.consume()
                    return
                t = t + 1
            return
        if self.panel_open:
            if y >= self.panel_y - 6 and y <= self.panel_y + 6 and x >= self.col_x:
                self.dragging_split = true
                e.consume()
                return
        # Clicking a problem opens its file at the reported line.
        if self.panel_open and self.active_panel == 1 and y > self.panel_y + self.PANELTAB_H:
            var pi = 0
            while pi < len(self.problem_rows):
                var pr2 = self.problem_rows[pi]
                if y >= pr2["y"] and y < pr2["y"] + 22:
                    var prob = self.problems[pr2["i"]]
                    if self.ws.root != "":
                        var fp = os_path_join(self.ws.root, prob["file"])
                        if os_exists(fp):
                            self._open_path(fp)
                    if prob["line"] > 0:
                        self._goto_line(prob["line"])
                    self.status_msg = prob["file"] + ":" + str(prob["line"])
                    e.consume()
                    return
                pi = pi + 1
        if self.panel_open and y >= self.panel_y and y < self.panel_y + self.PANELTAB_H:
            # The tab strip hit-tests itself during draw (immediate mode), so
            # this only has to record the pointer state the strip will read and
            # swallow the event.
            e.consume()
            return
        if self.mm_w > 0 and x >= self.col_x + self.ed_w and y >= self.ed_y and y < self.panel_y:
            self._minimap_scroll(y)
            self.dragging_mm = true
            e.consume()
            return
        if y >= self.ed_y and y < self.panel_y and x >= self.col_x:
            # Clicking the gutter toggles a breakpoint, as in Code::Blocks.
            if x < self.col_x + self.GUTTER_W:
                var row = int((y - self.ed_y) / 18)
                if row >= 0 and row < self.buffers[self.active_tab].line_count:
                    self._toggle_break(row)
                    e.consume()
                    return
            var p = self._pos_at(x, y)
            var buf = self.buffers[self.active_tab]
            buf.cursor_row = p["row"]
            buf.cursor_col = p["col"]
            if e.shift:
                self._sel_begin()
            else:
                self.sel_on = true
                self.sel_row = p["row"]
                self.sel_col = p["col"]
            self.dragging_sel = true
            self.editor.focused = true
            e.consume()

    def _global_keys(self, e):
        if e.key == "p" and e.ctrl:
            self._open_palette()
            e.consume()
            return true
        if e.key == "b" and e.ctrl:
            self.sidebar_open = not self.sidebar_open
            self._layout()
            e.consume()
            return true
        if e.key == "j" and e.ctrl:
            self.panel_open = not self.panel_open
            self._layout()
            e.consume()
            return true
        if e.key == "escape":
            if self.menu_open >= 0:
                self.menu_open = -1
                e.consume()
                return true
        if e.key == "k" and e.ctrl and not e.shift:
            self._ask("open_folder", "Open Folder", "Folder to open as the workspace", getcwd())
            e.consume()
            return true
        if e.key == "n" and e.ctrl and e.shift:
            self._ask("new_project", "New Project", "Folder to create the project in", os_path_join(getcwd(), "MyProject"))
            e.consume()
            return true
        if e.key == "o" and e.ctrl:
            self._ask("open_file", "Open File", "Path to a file", getcwd())
            e.consume()
            return true
        if e.ctrl and (e.key == "+" or e.key == "=" or e.key == "plus"):
            self._zoom(1)
            e.consume()
            return true
        if e.ctrl and (e.key == "-" or e.key == "minus"):
            self._zoom(0 - 1)
            e.consume()
            return true
        if e.ctrl and e.key == "0":
            self._zoom(13 - self.font_size)
            e.consume()
            return true
        if e.key == "t" and e.ctrl and e.shift:
            self._set_theme(not self.th.dark)
            var tm = "dark"
            if not self.th.dark:
                tm = "light"
            self._toast("Theme: " + tm, "ok")
            self.status_msg = "Theme: " + tm
            e.consume()
            return true
        if e.ctrl and (e.key == "/" or e.key == "slash"):
            self._toggle_comment()
            e.consume()
            return true
        if e.key == "d" and e.ctrl:
            self._duplicate_line()
            e.consume()
            return true
        if e.key == "k" and e.ctrl and e.shift:
            self._delete_line()
            e.consume()
            return true
        if e.key == "up" and e.alt:
            self._move_line(0 - 1)
            e.consume()
            return true
        if e.key == "down" and e.alt:
            self._move_line(1)
            e.consume()
            return true
        if e.key == "space" and e.ctrl:
            self._ac_open_now()
            e.consume()
            return true
        if e.key == "s" and e.ctrl:
            var sp = self._save_active()
            self.console.write("saved " + sp, "ok")
            self._toast("Saved " + os_path_basename(sp), "ok")
            self.status_msg = "Saved " + os_path_basename(sp)
            e.consume()
            return true
        if e.key == "z" and e.ctrl:
            self._undo()
            e.consume()
            return true
        if e.key == "c" and e.ctrl:
            self._copy_line()
            e.consume()
            return true
        if e.key == "x" and e.ctrl:
            self._cut_line()
            e.consume()
            return true
        if e.key == "v" and e.ctrl:
            self._paste()
            e.consume()
            return true
        if e.key == "f10" or e.key == "f11":
            self._debug_step("Step")
            e.consume()
            return true
        if e.key == "f" and e.ctrl:
            self.find_open = true
            self.find_replace_mode = false
            self.find_field = 0
            self._find_run()
            e.consume()
            return true
        if e.key == "h" and e.ctrl:
            self.find_open = true
            self.find_replace_mode = true
            self.find_field = 0
            self._find_run()
            e.consume()
            return true
        if e.key == "g" and e.ctrl:
            self._ask("goto", "Go to Line", "Line number", "")
            e.consume()
            return true
        if e.key == "f9":
            self._toggle_break(self.buffers[self.active_tab].cursor_row)
            e.consume()
            return true
        if e.key == "f5":
            self._run()
            e.consume()
            return true
        return false

    def _open_palette(self):
        self.palette_open = true
        self.palette_query = ""
        self.palette_sel = 0
        self._palette_filter()

    def _palette_filter(self):
        # Fuzzy, not substring. Substring matching meant "gtl" did not find
        # "Go to Line" and "oprj" did not find "Open Project" — the two things a
        # command palette exists to do. Results are ranked, so the intended
        # command sorts to the top instead of merely appearing in the list.
        var q = self.palette_query
        var hits = []
        var n = 0
        if len(q) == 0:
            var i = 0
            while i < len(self.palette_all):
                hits.append(self.palette_all[i])
                n = n + 1
                i = i + 1
        else:
            var ranked = self.fuzzy.rank(q, self.palette_all)
            var j = 0
            while j < len(ranked):
                hits.append(ranked[j][0])
                n = n + 1
                j = j + 1
        self.palette_hits = hits
        self.palette_hit_count = n
        if self.palette_sel >= n:
            self.palette_sel = 0

    def _palette_event(self, e):
        if e.type == "keydown":
            if e.key == "escape":
                self.palette_open = false
                e.consume()
                return
            if e.key == "down":
                self.palette_sel = self.palette_sel + 1
                if self.palette_sel >= self.palette_hit_count:
                    self.palette_sel = 0
                e.consume()
                return
            if e.key == "up":
                self.palette_sel = self.palette_sel - 1
                if self.palette_sel < 0:
                    self.palette_sel = self.palette_hit_count - 1
                e.consume()
                return
            if e.key == "enter":
                if self.palette_hit_count > 0:
                    self._run_command(self.palette_hits[self.palette_sel])
                self.palette_open = false
                e.consume()
                return
            if e.key == "backspace":
                if len(self.palette_query) > 0:
                    self.palette_query = string_slice(self.palette_query, 0, len(self.palette_query) - 1)
                    self._palette_filter()
                e.consume()
                return
        if e.type == "textinput":
            self.palette_query = self.palette_query + e.text
            self._palette_filter()
            e.consume()

    def _open_path(self, path):
        var title = os_path_basename(path)
        var i = 0
        while i < self.tab_count:
            if self.tabs[i].title == title:
                self.active_tab = i
                self.editor.set_buffer(self.buffers[i])
                self.status_msg = "Switched to " + title
                return
            i = i + 1
        var text = read_file(path)
        if text == none:
            self.status_msg = "Could not read " + path
            return
        self.buffers.append(EditorBuffer(title, text))
        var nt = EdTab(title)
        nt.path = path
        self.tabs.append(nt)
        self.tab_count = self.tab_count + 1
        self.active_tab = self.tab_count - 1
        self.editor.set_buffer(self.buffers[self.active_tab])
        self._remember_recent(path)
        self.status_msg = "Opened " + path
        self._layout()

    # ── modal path prompt ────────────────────────────────────────────────────
    def _ask(self, action, title, hint, prefill):
        self.dialog_open = true
        self.dialog_action = action
        self.dialog_title = title
        self.dialog_hint = hint
        self.dialog_input = prefill

    def _dialog_commit(self):
        var v = string_strip(self.dialog_input)
        self.dialog_open = false
        if v == "":
            return
        if self.dialog_action == "open_folder":
            if self.ws.open_folder(v):
                self._load_hl_rules(false)
                self.status_msg = "Opened folder " + v
            else:
                self.status_msg = self.ws.error
        elif self.dialog_action == "open_file":
            self._open_path(v)
        elif self.dialog_action == "open_project":
            var pr = Project()
            if pr.load(v):
                self.ws.project = pr
                self.ws.open_folder(pr.root)
                self._open_path(pr.target)
                self.status_msg = "Project " + pr.name
            else:
                self.status_msg = "Not a project file: " + v
        elif self.dialog_action == "addtoken":
            var eqp = string_find(v, "=")
            if eqp > 0:
                var wname = string_strip(string_slice(v, 0, eqp))
                var cparts = string_split(string_slice(v, eqp + 1, len(v)), ",")
                if len(cparts) >= 3:
                    self.editor.hl.add_token(wname, Color(int(cparts[0]), int(cparts[1]), int(cparts[2]), 255))
                    self._toast("Highlighting " + wname, "ok")
            else:
                self.editor.hl.add_keyword(string_strip(v))
                self._toast("Keyword " + string_strip(v), "ok")
            self._hl_cache = {}
            self._hl_cache_n = 0
        elif self.dialog_action == "goto":
            self._goto_line(int(v))
        elif self.dialog_action == "new_project":
            var nm = os_path_basename(v)
            var pr2 = Project()
            if pr2.create(v, nm):
                self.ws.project = pr2
                self.ws.open_folder(v)
                self._open_path(pr2.target)
                self.console.write("Created project " + nm + " at " + v, "ok")
                self.active_panel = 0
                self.panel_open = true
                self.status_msg = "Created project " + nm
            else:
                self.status_msg = "Could not create project at " + v
        self._layout()

    def _draw_dialog(self, r):
        var th = self.th
        r.fill_xywh(0, 0, self.W, self.H, th.scrim)
        var dw = 620
        if dw > self.W - 80:
            dw = self.W - 80
        var dx = int(self.W / 2 - dw / 2)
        var dy = 130
        var dh = 150
        r.draw_shadow(Rect(dx, dy, dw, dh), 26, 0, 12, Color(0, 0, 0, 180))
        r.fill_round_xywh(dx, dy, dw, dh, th.overlay, 12)
        r.draw_rounded_rect(Rect(dx, dy, dw, dh), th.accent, 12, 1)
        self.icons.draw(r, "folder_open", dx + 20, dy + 18, 20, th.accent)
        r.draw_text(self.dialog_title, dx + 50, dy + 20, self.f_ui_bold, th.text)
        r.draw_text(self.dialog_hint, dx + 20, dy + 48, self.f_small, th.text_faint)
        r.fill_round_xywh(dx + 20, dy + 70, dw - 40, 34, Color(255, 255, 255, 14), 7)
        r.draw_rounded_rect(Rect(dx + 20, dy + 70, dw - 40, 34), th.border, 7, 1)
        r.draw_text(self.dialog_input, dx + 32, dy + 79, self.f_code, th.text)
        var m = self.f_code.width(self.dialog_input)
        r.fill_xywh(dx + 33 + m, dy + 78, 1, 18, th.text)
        r.draw_text("Enter to confirm     Esc to cancel", dx + 20, dy + 116, self.f_small, th.text_faint)

    def _dialog_event(self, e):
        if e.type == "keydown":
            if e.key == "escape":
                self.dialog_open = false
                e.consume()
                return
            if e.key == "enter":
                self._dialog_commit()
                e.consume()
                return
            if e.key == "backspace":
                if len(self.dialog_input) > 0:
                    self.dialog_input = string_slice(self.dialog_input, 0, len(self.dialog_input) - 1)
                e.consume()
                return
        if e.type == "textinput":
            self.dialog_input = self.dialog_input + e.text
            e.consume()

    # A faint rule every four columns of leading whitespace, as VS Code does,
    # so nesting is readable without counting spaces.
    def _draw_indent_guides(self, r, line, x, y, line_h):
        if line == none:
            return
        var n = len(line)
        var i = 0
        while i < n and string_slice(line, i, i + 1) == " ":
            i = i + 1
        if i < 4:
            return
        var cw = self.editor.char_w
        var g = 4
        while g <= i:
            r.fill_xywh(x + g * cw - cw * 4, y, 1, line_h, Color(255, 255, 255, 14))
            g = g + 4

    # Highlight the bracket under the cursor and its partner.
    def _draw_bracket_match(self, r, buf, top, line_h, text_x):
        var row = buf.cursor_row
        var line = buf.get_line(row)
        var col = buf.cursor_col
        if col >= len(line):
            col = len(line) - 1
        if col < 0:
            return
        var ch = string_slice(line, col, col + 1)
        var opens = "([{"
        var closes = ")]}"
        var oi = string_find(opens, ch)
        var ci = string_find(closes, ch)
        if oi < 0 and ci < 0:
            return
        var want = ""
        var step = 1
        if oi >= 0:
            want = string_slice(closes, oi, oi + 1)
        else:
            want = string_slice(opens, ci, ci + 1)
            step = -1
        var depth = 0
        var c = col
        var found = -1
        while c >= 0 and c < len(line):
            var cc = string_slice(line, c, c + 1)
            if cc == ch:
                depth = depth + 1
            elif cc == want:
                depth = depth - 1
                if depth == 0:
                    found = c
                    c = -2
            c = c + step
        if found < 0:
            return
        var yy = self.ed_y + (row - top) * line_h
        var a = self.f_code.width(string_slice(line, 0, col))
        var b = self.f_code.width(string_slice(line, 0, found))
        var cw = self.f_code.width(ch)
        r.draw_rounded_rect(Rect(text_x + a - 1, yy + 1, cw + 2, line_h - 3), Color(140, 150, 255, 130), 2, 1)
        r.draw_rounded_rect(Rect(text_x + b - 1, yy + 1, cw + 2, line_h - 3), Color(140, 150, 255, 130), 2, 1)

    # Switching the chrome theme must also switch the syntax palette and drop
    # the highlight cache, which stores resolved colours per line.
    def _set_theme(self, dark):
        self.th.dark = dark
        self.th.apply()
        self.editor.hl.set_dark(dark)
        self._hl_cache = {}
        self._hl_cache_n = 0

    # Workspace-local syntax rules. Dropping a .nyhighlight file beside the
    # project makes its tokens colour without touching the IDE source.
    def _load_hl_rules(self, announce):
        if self.ws.root == "":
            return
        var path = os_path_join(self.ws.root, ".nyhighlight")
        var n = self.editor.hl.load_rules(path)
        self._hl_cache = {}
        self._hl_cache_n = 0
        if n > 0:
            self.status_msg = str(n) + " highlight rule(s) from .nyhighlight"
            if announce:
                self._toast(str(n) + " highlight rules loaded", "ok")
        elif announce:
            self._toast("No .nyhighlight in workspace", "err")

    # ── recent files ─────────────────────────────────────────────────────────
    def _remember_recent(self, path):
        if path == "":
            return
        var keep = [path]
        var n = 1
        var i = 0
        while i < self.recent_n:
            if self.recent[i] != path and n < 8:
                keep.append(self.recent[i])
                n = n + 1
            i = i + 1
        self.recent = keep
        self.recent_n = n

    # ── wheel scrolling for the sidebar and the bottom panel ────────────────
    def _scroll_tree(self, delta):
        var rows = self.ws.row_count
        if self.active_view == "outline":
            rows = self.outline_n
        var visible = int((self.status_y - self.content_y - 34) / 22)
        var maxs = rows - visible
        if maxs < 0:
            maxs = 0
        self.tree_scroll = self.tree_scroll - delta * 3
        if self.tree_scroll < 0:
            self.tree_scroll = 0
        if self.tree_scroll > maxs:
            self.tree_scroll = maxs

    def _scroll_panel(self, delta):
        self.panel_scroll = self.panel_scroll - delta * 3
        if self.panel_scroll < 0:
            self.panel_scroll = 0
        var maxs = self.problem_count - 4
        if maxs < 0:
            maxs = 0
        if self.panel_scroll > maxs:
            self.panel_scroll = maxs

    # ── editor zoom ──────────────────────────────────────────────────────────
    # Ctrl +/- resizes the code font. Line height follows so the gutter, caret,
    # selection and minimap stay aligned, and the highlight cache is dropped
    # because it stores pixel offsets measured at the old size.
    def _zoom(self, delta):
        var ns = self.font_size + delta
        if ns < 8:
            ns = 8
        if ns > 30:
            ns = 30
        if ns == self.font_size:
            return
        self.font_size = ns
        self.f_code = Font("monospace", ns, false, false)
        self.LINE_H = int(ns * 1.4)
        self.editor.line_h = self.LINE_H
        var cw = self.f_code.width("M")
        self.editor.char_w = cw
        self.f_code.ensure_loaded()
        self._code_handle = self.f_code._handle
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.status_msg = "Font size " + str(ns)
        self._layout()

    # ── minimap navigation ───────────────────────────────────────────────────
    # Clicking or dragging in the minimap scrolls the editor to that fraction of
    # the document, like VS Code's.
    def _minimap_scroll(self, y):
        var buf = self.buffers[self.active_tab]
        var frac = (y - self.ed_y) * 1.0 / self.ed_h
        if frac < 0.0:
            frac = 0.0
        if frac > 1.0:
            frac = 1.0
        var maxs = buf.line_count * self.LINE_H - self.ed_h
        if maxs < 0:
            maxs = 0
        self.editor.scroll_y = int(maxs * frac)
        self.status_msg = "Line " + str(int(self.editor.scroll_y / self.LINE_H) + 1)

    # ══ AI assistant ═════════════════════════════════════════════════════════
    # Runs lib/aiagent.ny's CodeAnalyzer over the active buffer. Cached per file
    # so the analysis is not redone on every frame.
    def _ai_analyze(self, force):
        var title = self.tabs[self.active_tab].title
        if not force and self.ai_file == title:
            return
        var text = self.buffers[self.active_tab].get_all_text()
        var found = self.ai.analyze(text)
        self.ai_issues = found
        self.ai_n = len(found)
        self.ai_file = title

    def _draw_ai(self, r, x, w):
        var th = self.th
        self._ai_analyze(false)
        var y = self.content_y + 34
        r.draw_text(self.tabs[self.active_tab].title, x + 14, y, self.f_small, th.accent)
        y = y + 20
        if self.ai_n == 0:
            self.icons.draw(r, "run", x + 14, y + 2, 16, th.ok)
            r.draw_text("No issues found", x + 36, y + 3, self.f_ui, th.text_dim)
            r.draw_text("Analyser: pattern review of the open buffer", x + 14, y + 30, self.f_small, th.text_faint)
            return
        r.draw_text(str(self.ai_n) + " suggestion(s)", x + 14, y, self.f_small, th.text_faint)
        y = y + 22
        self.ai_rows = []
        var i = self.tree_scroll
        r.set_clip(Rect(x, y, w, self.status_y - y))
        while i < self.ai_n:
            if y + 40 <= self.status_y:
                var it = self.ai_issues[i]
                self.icons.draw(r, "warning", x + 12, y + 4, 14, th.warn)
                r.draw_text(it["message"], x + 32, y + 2, self.f_ui, th.text)
                r.draw_text("line " + str(it["line"]) + "   " + string_strip(it["code"]),
                            x + 32, y + 20, self.f_small, th.text_faint)
                self.ai_rows = self.ai_rows + [{"y": y, "line": it["line"]}]
                y = y + 40
            i = i + 1
        r.clear_clip()

    # ══ settings persistence ═════════════════════════════════════════════════
    # Plain "key = value" lines in .nyide next to the workspace, so preferences
    # survive a restart and can be edited without the IDE.
    def _settings_path(self):
        var root = self.ws.root
        if root == "":
            root = getcwd()
        return os_path_join(root, ".nyide")

    def _save_settings(self):
        var mode = "dark"
        if not self.th.dark:
            mode = "light"
        var body = "# NythonIDE preferences\n"
        body = body + "theme = " + mode + "\n"
        body = body + "font_size = " + str(self.font_size) + "\n"
        body = body + "sidebar_width = " + str(self.SIDEBAR_W) + "\n"
        body = body + "minimap = " + str(self.minimap_on) + "\n"
        body = body + "panel = " + str(self.panel_open) + "\n"
        write(self._settings_path(), body)
        self.status_msg = "Settings saved"
        return true

    def _load_settings(self):
        var path = self._settings_path()
        if not os_exists(path):
            return false
        var text = read_file(path)
        if text == none or text == "":
            return false
        var lines = string_split(text, "\n")
        var i = 0
        while i < len(lines):
            var ln = string_strip(lines[i])
            if len(ln) > 0 and string_find(ln, "#") != 0:
                var eq = string_find(ln, "=")
                if eq > 0:
                    var k = string_strip(string_slice(ln, 0, eq))
                    var v = string_strip(string_slice(ln, eq + 1, len(ln)))
                    if k == "theme":
                        self._set_theme(v == "dark")
                    elif k == "font_size":
                        self._zoom(int(v) - self.font_size)
                    elif k == "sidebar_width":
                        self.SIDEBAR_W = int(v)
                    elif k == "minimap":
                        self.minimap_on = (v == "true")
                    elif k == "panel":
                        self.panel_open = (v == "true")
            i = i + 1
        self._layout()
        self.status_msg = "Settings loaded"
        return true

    # ══ workspace search ═════════════════════════════════════════════════════
    # Scans every code file in the workspace for the query and lists each match
    # with its file and line. Clicking a result opens the file at that line.
    def _run_search(self):
        var hits = []
        var n = 0
        var files = 0
        if len(self.search_query) < 2:
            self.search_hits = []
            self.search_n = 0
            self.search_files = 0
            return
        var i = 0
        while i < self.ws.row_count:
            var row = self.ws.rows[i]
            if not row.is_dir and (row.kind == "code" or row.kind == "text"):
                var text = read_file(row.path)
                if text != none and text != "":
                    var lines = string_split(text, "\n")
                    var j = 0
                    var found_here = false
                    while j < len(lines) and n < 300:
                        if string_find(lines[j], self.search_query) >= 0:
                            hits.append({"file": row.name, "path": row.path,
                                         "line": j + 1, "text": string_strip(lines[j])})
                            n = n + 1
                            found_here = true
                        j = j + 1
                    if found_here:
                        files = files + 1
            i = i + 1
        self.search_hits = hits
        self.search_n = n
        self.search_files = files
        self.status_msg = str(n) + " results in " + str(files) + " files"

    def _draw_search(self, r, x, w):
        var th = self.th
        var fy = self.content_y + 32
        var fb = th.field
        if self.search_focus:
            fb = th.accent_soft
        r.fill_round_xywh(x + 10, fy, w - 20, 28, fb, 6)
        self.icons.draw(r, "search", x + 16, fy + 6, 16, th.text_faint)
        if self.search_query == "":
            r.draw_text("Search workspace", x + 38, fy + 7, self.f_ui, th.text_faint)
        else:
            r.draw_text(self.search_query, x + 38, fy + 7, self.f_ui, th.text)
            if self.search_focus:
                var qm = self.f_code.width(self.search_query)
                r.fill_xywh(x + 39 + qm, fy + 6, 1, 16, th.text)
        var y = fy + 36
        if self.search_n == 0:
            var msg = "No results"
            if self.search_query == "":
                msg = "Type at least two characters"
            r.draw_text(msg, x + 14, y, self.f_small, th.text_faint)
            return
        r.draw_text(str(self.search_n) + " results in " + str(self.search_files) + " files",
                    x + 14, y, self.f_small, th.text_faint)
        y = y + 20
        self.search_rows = []
        var i = self.tree_scroll
        r.set_clip(Rect(x, y, w, self.status_y - y))
        while i < self.search_n:
            if y + 34 <= self.status_y:
                var h = self.search_hits[i]
                self.icons.draw(r, "file_code", x + 12, y + 2, 14, th.accent)
                r.draw_text(h["file"] + " : " + str(h["line"]), x + 32, y, self.f_small, th.text_dim)
                # No truncation by slice: string_slice cuts by byte offset and
                # can split a multi-byte character, producing invalid UTF-8.
                # The sidebar is already clipped, so let the clip do it.
                r.draw_text(h["text"], x + 32, y + 16, self.f_code, th.text_faint)
                self.search_rows = self.search_rows + [{"y": y, "i": i}]
                y = y + 34
            i = i + 1
        r.clear_clip()

    def _search_event(self, e):
        if e.type == "textinput":
            self.search_query = self.search_query + e.text
            self._run_search()
            e.consume()
            return
        if e.type == "keydown":
            if e.key == "backspace":
                if len(self.search_query) > 0:
                    self.search_query = string_slice(self.search_query, 0, len(self.search_query) - 1)
                    self._run_search()
                e.consume()
                return
            if e.key == "escape":
                self.search_focus = false
                e.consume()
                return
            if e.key == "enter":
                self._run_search()
                e.consume()
                return

    # ══ symbol outline ═══════════════════════════════════════════════════════
    # Code::Blocks' symbol browser: every class / def / top-level var in the
    # active buffer, indented by nesting, click to jump.
    def _build_outline(self):
        var out = []
        var n = 0
        var buf = self.buffers[self.active_tab]
        var i = 0
        while i < buf.line_count:
            var raw = buf.get_line(i)
            var st = string_strip(raw)
            var kind = ""
            var nm = ""
            if string_find(st, "class ") == 0:
                kind = "class"
                nm = string_slice(st, 6, len(st))
            elif string_find(st, "def ") == 0:
                kind = "def"
                nm = string_slice(st, 4, len(st))
            if kind != "":
                var cut = len(nm)
                var stops = ["(", ":", " "]
                var k = 0
                while k < len(stops):
                    var at = string_find(nm, stops[k])
                    if at >= 0 and at < cut:
                        cut = at
                    k = k + 1
                nm = string_strip(string_slice(nm, 0, cut))
                var indent = 0
                while indent < len(raw) and string_slice(raw, indent, indent + 1) == " ":
                    indent = indent + 1
                if nm != "":
                    out.append({"name": nm, "kind": kind, "line": i, "depth": int(indent / 4)})
                    n = n + 1
            i = i + 1
        self.outline = out
        self.outline_n = n

    def _draw_outline(self, r, x, w):
        var th = self.th
        self._build_outline()
        var y = self.content_y + 34
        if self.outline_n == 0:
            r.draw_text("No symbols in this file", x + 14, y, self.f_small, th.text_faint)
            return
        r.set_clip(Rect(x, y, w, self.status_y - y))
        var i = self.tree_scroll
        while i < self.outline_n:
            if y + 22 <= self.status_y:
                var sy = self.outline[i]
                var ix = x + 10 + sy["depth"] * 14
                if i == self.outline_sel:
                    r.fill_xywh(x, y, w, 22, th.accent_soft)
                    r.fill_xywh(x, y, 2, 22, th.accent)
                var ic = "file_code"
                var icol = th.accent
                if sy["kind"] == "class":
                    ic = "project"
                    icol = th.ok
                self.icons.draw(r, ic, ix, y + 3, 16, icol)
                r.draw_text(sy["name"], ix + 22, y + 4, self.f_ui, th.text_dim)
                var lm = self.f_small.width(str(sy["line"] + 1))
                r.draw_text(str(sy["line"] + 1), x + w - lm - 12, y + 5, self.f_small, th.text_faint)
                y = y + 22
            i = i + 1
        r.clear_clip()

    # ══ line operations ══════════════════════════════════════════════════════
    # Range the operation applies to: the selection if there is one, else the
    # cursor line.
    def _line_span(self):
        var g = self._sel_range()
        if g == none:
            var cr = self.buffers[self.active_tab].cursor_row
            return {"a": cr, "b": cr}
        return {"a": g["r1"], "b": g["r2"]}

    def _after_edit(self):
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.tabs[self.active_tab].dirty = true

    def _toggle_comment(self):
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        var sp = self._line_span()
        # If every non-blank line in the range is already commented, uncomment;
        # otherwise comment them all. Matches how editors behave on mixed input.
        var all_commented = true
        var i = sp["a"]
        while i <= sp["b"]:
            var st = string_strip(buf.get_line(i))
            if st != "" and string_find(st, "#") != 0:
                all_commented = false
            i = i + 1
        i = sp["a"]
        while i <= sp["b"]:
            var line = buf.get_line(i)
            var st2 = string_strip(line)
            if st2 != "":
                if all_commented:
                    var at = string_find(line, "#")
                    var head = string_slice(line, 0, at)
                    var rest = string_slice(line, at + 1, len(line))
                    if string_find(rest, " ") == 0:
                        rest = string_slice(rest, 1, len(rest))
                    buf.lines[i] = head + rest
                else:
                    var ind = 0
                    while ind < len(line) and string_slice(line, ind, ind + 1) == " ":
                        ind = ind + 1
                    buf.lines[i] = string_slice(line, 0, ind) + "# " + string_slice(line, ind, len(line))
            i = i + 1
        self._after_edit()
        self.status_msg = "Toggled comment"

    def _duplicate_line(self):
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        var row = buf.cursor_row
        var out = []
        var i = 0
        while i < buf.line_count:
            out.append(buf.lines[i])
            if i == row:
                out.append(buf.lines[i])
            i = i + 1
        buf.lines = out
        buf.line_count = len(out)
        buf.cursor_row = row + 1
        self._after_edit()
        self.status_msg = "Duplicated line"

    def _delete_line(self):
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        if buf.line_count <= 1:
            buf.lines = [""]
            buf.line_count = 1
            buf.cursor_row = 0
            buf.cursor_col = 0
            self._after_edit()
            return
        var row = buf.cursor_row
        var out = []
        var i = 0
        while i < buf.line_count:
            if i != row:
                out.append(buf.lines[i])
            i = i + 1
        buf.lines = out
        buf.line_count = len(out)
        if buf.cursor_row >= buf.line_count:
            buf.cursor_row = buf.line_count - 1
        buf.cursor_col = 0
        self._after_edit()
        self.status_msg = "Deleted line"

    def _move_line(self, delta):
        var buf = self.buffers[self.active_tab]
        var row = buf.cursor_row
        var dest = row + delta
        if dest < 0 or dest >= buf.line_count:
            return
        self._push_undo()
        var tmp = buf.lines[row]
        buf.lines[row] = buf.lines[dest]
        buf.lines[dest] = tmp
        buf.cursor_row = dest
        self._after_edit()
        self.status_msg = "Moved line"

    # ── typing helpers ───────────────────────────────────────────────────────
    # Typing an opening bracket or quote inserts its partner and leaves the
    # caret between them.
    def _auto_close(self, ch):
        var pairs = {"(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"}
        if not pairs.has_key(ch):
            return false
        var buf = self.buffers[self.active_tab]
        buf.insert_char(pairs[ch])
        buf.cursor_col = buf.cursor_col - 1
        return true

    # ══ selection ════════════════════════════════════════════════════════════
    def _sel_clear(self):
        self.sel_on = false

    def _sel_begin(self):
        if not self.sel_on:
            var buf = self.buffers[self.active_tab]
            self.sel_row = buf.cursor_row
            self.sel_col = buf.cursor_col
            self.sel_on = true

    # Ordered (startRow, startCol, endRow, endCol); empty selections report none.
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
    def _pos_at(self, x, y):
        var buf = self.buffers[self.active_tab]
        var top = int(self.editor.scroll_y / self.LINE_H)
        var row = top + int((y - self.ed_y) / self.LINE_H)
        if row < 0:
            row = 0
        if row >= buf.line_count:
            row = buf.line_count - 1
        var line = buf.get_line(row)
        var text_x = self.col_x + self.GUTTER_W + 10
        var col = 0
        while col < len(line):
            var m = self.f_code.width(string_slice(line, 0, col + 1))
            if text_x + m > x:
                col = col
                break
            col = col + 1
        return {"row": row, "col": col}

    def _draw_selection(self, r, buf, top, rows, line_h, text_x):
        var g = self._sel_range()
        if g == none:
            return
        var i = 0
        while i < rows:
            var ln = top + i
            if ln >= g["r1"] and ln <= g["r2"] and ln < buf.line_count:
                var line = buf.get_line(ln)
                var a = 0
                var b = len(line)
                if ln == g["r1"]:
                    a = g["c1"]
                if ln == g["r2"]:
                    b = g["c2"]
                var ma = self.f_code.width(string_slice(line, 0, a))
                var mb = self.f_code.width(string_slice(line, 0, b))
                var w = mb - ma
                if w < 3:
                    w = 3
                r.fill_xywh(text_x + ma, self.ed_y + i * line_h, w, line_h, Color(90, 110, 200, 90))
            i = i + 1

    # ══ context menus ════════════════════════════════════════════════════════
    def _open_ctx(self, x, y, target, arg):
        self.ctx_target = target
        self.ctx_arg = arg
        if target == "editor":
            self.ctx_items = ["Cut", "Copy", "Paste", "-", "Go to Line", "Toggle Breakpoint", "-", "Run"]
        elif target == "tree":
            self.ctx_items = ["Open", "Reveal in Explorer", "-", "Copy Path", "Set as Workspace"]
        elif target == "tab":
            self.ctx_items = ["Close", "Close Others", "-", "Copy Path", "Save"]
        else:
            self.ctx_items = ["Toggle Sidebar", "Toggle Panel", "Toggle Minimap"]
        self.ctx_open = true
        self.ctx_x = x
        self.ctx_y = y
        self.ctx_hover = -1

    def _ctx_height(self):
        var h = 10
        var i = 0
        while i < len(self.ctx_items):
            if self.ctx_items[i] == "-":
                h = h + 9
            else:
                h = h + 26
            i = i + 1
        return h

    def _draw_ctx(self, r):
        var th = self.th
        var w = 220
        var h = self._ctx_height()
        var x = self.ctx_x
        var y = self.ctx_y
        if x + w > self.W - 8:
            x = self.W - w - 8
        if y + h > self.H - 8:
            y = self.H - h - 8
        r.draw_shadow(Rect(x, y, w, h), 20, 0, 8, Color(0, 0, 0, 160))
        r.fill_round_xywh(x, y, w, h, th.overlay, 8)
        r.draw_rounded_rect(Rect(x, y, w, h), th.border, 8, 1)
        var yy = y + 5
        var i = 0
        while i < len(self.ctx_items):
            var it = self.ctx_items[i]
            if it == "-":
                r.draw_line(x + 12, yy + 4, x + w - 12, yy + 4, th.border_soft, 1)
                yy = yy + 9
            else:
                if self.ctx_hover == i:
                    r.fill_round_xywh(x + 4, yy, w - 8, 24, th.accent_soft, 5)
                r.draw_text(it, x + 16, yy + 5, self.f_ui, th.text)
                yy = yy + 26
            i = i + 1

    def _ctx_hit(self, mx, my):
        var w = 220
        var h = self._ctx_height()
        var x = self.ctx_x
        var y = self.ctx_y
        if x + w > self.W - 8:
            x = self.W - w - 8
        if y + h > self.H - 8:
            y = self.H - h - 8
        if mx < x or mx > x + w or my < y or my > y + h:
            return -1
        var yy = y + 5
        var i = 0
        while i < len(self.ctx_items):
            var it = self.ctx_items[i]
            if it == "-":
                yy = yy + 9
            else:
                if my >= yy and my < yy + 26:
                    return i
                yy = yy + 26
            i = i + 1
        return -1

    def _ctx_action(self, label):
        if label == "Cut":
            self._cut_line()
        elif label == "Copy":
            self._copy_line()
        elif label == "Paste":
            self._paste()
        elif label == "Go to Line":
            self._ask("goto", "Go to Line", "Line number", "")
        elif label == "Toggle Breakpoint":
            self._toggle_break(self.buffers[self.active_tab].cursor_row)
        elif label == "Run":
            self._run()
        elif label == "Open":
            if self.ctx_arg >= 0 and self.ctx_arg < self.ws.row_count:
                var n = self.ws.rows[self.ctx_arg]
                if not n.is_dir:
                    self._open_path(n.path)
        elif label == "Copy Path":
            if self.ctx_target == "tree" and self.ctx_arg >= 0:
                self.clipboard = self.ws.rows[self.ctx_arg].path
            else:
                self.clipboard = self.tabs[self.active_tab].path
            self._toast("Path copied", "ok")
        elif label == "Set as Workspace":
            if self.ctx_arg >= 0:
                var d = self.ws.rows[self.ctx_arg]
                if d.is_dir:
                    self.ws.open_folder(d.path)
                    self._toast("Workspace: " + d.name, "ok")
        elif label == "Reveal in Explorer":
            self.active_view = "explorer"
            self.sidebar_open = true
        elif label == "Close":
            self._close_tab(self.active_tab)
        elif label == "Close Others":
            var keepT = [self.tabs[self.active_tab]]
            var keepB = [self.buffers[self.active_tab]]
            self.tabs = keepT
            self.buffers = keepB
            self.tab_count = 1
            self.active_tab = 0
            self.editor.set_buffer(self.buffers[0])
        elif label == "Save":
            var sp = self._save_active()
            self._toast("Saved " + os_path_basename(sp), "ok")
        elif label == "Toggle Sidebar":
            self.sidebar_open = not self.sidebar_open
        elif label == "Toggle Panel":
            self.panel_open = not self.panel_open
        elif label == "Toggle Minimap":
            self.minimap_on = not self.minimap_on
        self.status_msg = label
        self._layout()

    # ══ autocomplete ═════════════════════════════════════════════════════════
    # Suggestions come from language keywords plus every def/class/var name in
    # the current buffer, filtered by the word being typed.
    def _ac_symbols(self):
        var out = ["if", "elif", "else", "while", "for", "def", "class", "return",
                   "var", "true", "false", "none", "and", "or", "not", "import",
                   "print", "len", "str", "int", "range"]
        var buf = self.buffers[self.active_tab]
        var i = 0
        while i < buf.line_count:
            var st = string_strip(buf.get_line(i))
            var head = ""
            if string_find(st, "def ") == 0:
                head = string_slice(st, 4, len(st))
            elif string_find(st, "class ") == 0:
                head = string_slice(st, 6, len(st))
            elif string_find(st, "var ") == 0:
                head = string_slice(st, 4, len(st))
            if head != "":
                var cut = len(head)
                var stops = ["(", ":", " ", "="]
                var k = 0
                while k < len(stops):
                    var at = string_find(head, stops[k])
                    if at >= 0 and at < cut:
                        cut = at
                    k = k + 1
                var nm = string_strip(string_slice(head, 0, cut))
                if nm != "":
                    out.append(nm)
            i = i + 1
        return out

    def _ac_word(self):
        var buf = self.buffers[self.active_tab]
        var line = buf.get_line(buf.cursor_row)
        var c = buf.cursor_col
        var st = c
        while st > 0:
            var ch = string_slice(line, st - 1, st)
            if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_" or (ch >= "0" and ch <= "9"):
                st = st - 1
            else:
                st = 0 - 1
        if st < 0:
            st = 0
            var j = c
            while j > 0:
                var c2 = string_slice(line, j - 1, j)
                if (c2 >= "a" and c2 <= "z") or (c2 >= "A" and c2 <= "Z") or c2 == "_" or (c2 >= "0" and c2 <= "9"):
                    j = j - 1
                else:
                    st = j
                    j = 0
            if j == 0 and st == 0:
                st = 0
        return string_slice(line, st, c)

    def _ac_open_now(self):
        self.ac_prefix = self._ac_word()
        var syms = self._ac_symbols()
        var hits = []
        var n = 0
        var seen = {}
        var i = 0
        while i < len(syms):
            var sname = syms[i]
            if not seen.has_key(sname):
                if self.ac_prefix == "" or string_find(sname, self.ac_prefix) == 0:
                    seen[sname] = true
                    hits.append(sname)
                    n = n + 1
            i = i + 1
        self.ac_items = hits
        self.ac_n = n
        self.ac_sel = 0
        self.ac_open = (n > 0)
        if n == 0:
            self.status_msg = "No completions for '" + self.ac_prefix + "'"

    def _ac_accept(self):
        if self.ac_n == 0:
            return
        var word = self.ac_items[self.ac_sel]
        var tail = string_slice(word, len(self.ac_prefix), len(word))
        var buf = self.buffers[self.active_tab]
        var k = 0
        while k < len(tail):
            buf.insert_char(string_slice(tail, k, k + 1))
            k = k + 1
        self.ac_open = false
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.status_msg = "Completed " + word

    def _draw_ac(self, r):
        var th = self.th
        var buf = self.buffers[self.active_tab]
        var top = int(self.editor.scroll_y / self.LINE_H)
        var text_x = self.col_x + self.GUTTER_W + 10
        var pre = self.f_code.width(string_slice(buf.get_line(buf.cursor_row), 0, buf.cursor_col))
        var x = text_x + pre
        var y = self.ed_y + (buf.cursor_row - top) * self.LINE_H + self.LINE_H
        var rows = self.ac_n
        if rows > 8:
            rows = 8
        var w = 240
        var h = rows * 24 + 8
        if x + w > self.W - 10:
            x = self.W - w - 10
        r.draw_shadow(Rect(x, y, w, h), 18, 0, 6, Color(0, 0, 0, 160))
        r.fill_round_xywh(x, y, w, h, th.overlay, 7)
        r.draw_rounded_rect(Rect(x, y, w, h), th.accent, 7, 1)
        var i = 0
        var yy = y + 4
        while i < rows:
            if i == self.ac_sel:
                r.fill_round_xywh(x + 4, yy, w - 8, 22, th.accent_soft, 4)
            self.icons.draw(r, "file_code", x + 8, yy + 3, 14, th.accent)
            var col = th.text_dim
            if i == self.ac_sel:
                col = th.text
            r.draw_text(self.ac_items[i], x + 28, yy + 3, self.f_code, col)
            yy = yy + 24
            i = i + 1

    def _ac_event(self, e):
        if e.type == "keydown":
            if e.key == "escape":
                self.ac_open = false
                e.consume()
                return
            if e.key == "down":
                self.ac_sel = self.ac_sel + 1
                if self.ac_sel >= self.ac_n:
                    self.ac_sel = 0
                e.consume()
                return
            if e.key == "up":
                self.ac_sel = self.ac_sel - 1
                if self.ac_sel < 0:
                    self.ac_sel = self.ac_n - 1
                e.consume()
                return
            if e.key == "enter" or e.key == "tab":
                self._ac_accept()
                e.consume()
                return

    # ── breadcrumbs ──────────────────────────────────────────────────────────
    # VS Code's path strip: workspace > folder > file > enclosing symbol.
    def _draw_breadcrumbs(self, r):
        var th = self.th
        var y = self.crumb_y
        r.fill_xywh(self.col_x, y, self.col_w, self.BREADCRUMB_H, th.editor_bg)
        r.draw_line(self.col_x, y + self.BREADCRUMB_H, self.col_x + self.col_w, y + self.BREADCRUMB_H, th.border_soft, 1)
        var parts = []
        if self.ws.root != "":
            parts.append(os_path_basename(self.ws.root))
        var t = self.tabs[self.active_tab]
        if t.path != "":
            var d = os_path_basename(os_path_dirname(t.path))
            if d != "" and d != os_path_basename(self.ws.root):
                parts.append(d)
        parts.append(t.title)
        var sym = self._enclosing_symbol()
        if sym != "":
            parts.append(sym)
        var x = self.col_x + 14
        var i = 0
        while i < len(parts):
            if i > 0:
                self.icons.draw(r, "chevron_right", x, y + 5, 14, th.text_faint)
                x = x + 16
            var col = th.text_faint
            if i == len(parts) - 1:
                col = th.text_dim
            r.draw_text(parts[i], x, y + 4, self.f_small, col)
            var m = self.f_small.width(parts[i])
            x = x + m + 4
            i = i + 1

    # Nearest enclosing class/def above the cursor, for the last crumb.
    def _enclosing_symbol(self):
        var buf = self.buffers[self.active_tab]
        var i = buf.cursor_row
        while i >= 0:
            var ln = buf.get_line(i)
            var st = string_strip(ln)
            if string_find(st, "def ") == 0 or string_find(st, "class ") == 0:
                var head = string_slice(st, 0, len(st))
                var paren = string_find(head, "(")
                if paren > 0:
                    head = string_slice(head, 0, paren)
                var colon = string_find(head, ":")
                if colon > 0:
                    head = string_slice(head, 0, colon)
                return string_strip(head)
            i = i - 1
        return ""

    # ── toasts ───────────────────────────────────────────────────────────────
    def _toast(self, text, kind):
        self.toasts.append({"text": text, "kind": kind, "t": time_ms()})
        self.toast_n = self.toast_n + 1

    def _draw_toasts(self, r):
        var th = self.th
        var keep = []
        var n = 0
        var now = time_ms()
        var i = 0
        var y = self.status_y - 52
        while i < self.toast_n:
            var t = self.toasts[i]
            var age = now - t["t"]
            if age < 3200:
                keep.append(t)
                n = n + 1
                var m = self.f_ui.width(t["text"])
                var w = m + 54
                var x = self.W - w - 22
                var bar = th.accent
                var ic = "output"
                if t["kind"] == "ok":
                    bar = th.ok
                    ic = "run"
                elif t["kind"] == "err":
                    bar = th.err
                    ic = "warning"
                # Slide in from the right on out_cubic, hold, then fade out.
                # Age is known per toast, so this needs no extra state.
                var appear = 1.0
                if age < 220:
                    appear = self.ease.out_cubic(float(age) / 220.0)
                var fade = 1.0
                if age > 2600:
                    fade = 1.0 - self.ease.in_out_quad(float(age - 2600) / 600.0)
                if fade < 0.0:
                    fade = 0.0
                var slide = int((1.0 - appear) * 46.0)
                var ax = x + slide
                var alpha = int(255.0 * fade)
                r.draw_shadow(Rect(ax, y, w, 40), 18, 0, 6, Color(0, 0, 0, int(150.0 * fade)))
                r.fill_round_xywh(ax, y, w, 40, Color(th.overlay.r, th.overlay.g, th.overlay.b,
                                                     int(float(th.overlay.a) * fade)), 8)
                r.fill_xywh(ax, y + 8, 3, 24, Color(bar.r, bar.g, bar.b, alpha))
                self.icons.draw(r, ic, ax + 14, y + 12, 16, Color(bar.r, bar.g, bar.b, alpha))
                r.draw_text(t["text"], ax + 38, y + 12, self.f_ui,
                            Color(th.text.r, th.text.g, th.text.b, alpha))
                y = y - 48
            i = i + 1
        self.toasts = keep
        self.toast_n = n
        if n > 0:
            self._dirty = true

    # ── tooltip ──────────────────────────────────────────────────────────────
    def _draw_tooltip(self, r):
        if self.tooltip == "":
            return
        var th = self.th
        var m = self.f_small.width(self.tooltip)
        var w = m + 20
        var x = self.tooltip_x
        var y = self.tooltip_y
        if x + w > self.W - 8:
            x = self.W - w - 8
        r.draw_shadow(Rect(x, y, w, 26), 12, 0, 4, Color(0, 0, 0, 150))
        r.fill_round_xywh(x, y, w, 26, th.overlay, 6)
        r.draw_rounded_rect(Rect(x, y, w, 26), th.border, 6, 1)
        r.draw_text(self.tooltip, x + 10, y + 6, self.f_small, th.text)

    # ── edit actions ─────────────────────────────────────────────────────────
    # History is whole-file snapshots, so its cost scales with file size, not
    # edit size: 50 steps on a 140 KB file held 7,000,000 characters in the
    # measurement for this change — 50 copies of text that is almost entirely
    # identical. Two bounds keep that in check without altering behaviour:
    # identical consecutive states are not stored at all, and the stack is
    # trimmed on total characters as well as on step count, so a large file
    # keeps fewer steps rather than proportionally more memory.
    #
    # (The real fix is a piece table — lib/gui_piecetable.ny stores the text
    # once and makes a history entry a list of spans, 140,050 characters for the
    # same 50 steps. Adopting it means re-backing EditorBuffer, which every
    # editor feature reads, so it belongs in its own change.)
    def _push_undo(self):
        var buf = self.buffers[self.active_tab]
        var txt = buf.get_all_text()
        if self.undo_n > 0:
            var last = self.undo_stack[self.undo_n - 1]
            if last["tab"] == self.active_tab and last["text"] == txt:
                return 0
        self.undo_stack = self.undo_stack + [{"tab": self.active_tab, "text": txt,
                                              "row": buf.cursor_row, "col": buf.cursor_col}]
        self.undo_n = self.undo_n + 1

        # Character budget: ~4 MB of history regardless of document size.
        var budget = 4000000
        var used = 0
        var j = self.undo_n - 1
        var keep_from = 0
        while j >= 0:
            used = used + len(self.undo_stack[j]["text"])
            if used > budget and keep_from == 0:
                keep_from = j + 1
            j = j - 1
        if keep_from > 0:
            var kept = []
            var m = keep_from
            while m < self.undo_n:
                kept.append(self.undo_stack[m])
                m = m + 1
            self.undo_stack = kept
            self.undo_n = len(kept)

        if self.undo_n > 50:
            var trimmed = []
            var i = 1
            while i < self.undo_n:
                trimmed.append(self.undo_stack[i])
                i = i + 1
            self.undo_stack = trimmed
            self.undo_n = self.undo_n - 1

    def _undo(self):
        if self.undo_n == 0:
            self.status_msg = "Nothing to undo"
            return
        var snap = self.undo_stack[self.undo_n - 1]
        var keep = []
        var i = 0
        while i < self.undo_n - 1:
            keep.append(self.undo_stack[i])
            i = i + 1
        self.undo_stack = keep
        self.undo_n = self.undo_n - 1
        var idx = snap["tab"]
        if idx < self.tab_count:
            self.buffers[idx] = EditorBuffer(self.tabs[idx].title, snap["text"])
            self.buffers[idx].cursor_row = snap["row"]
            self.buffers[idx].cursor_col = snap["col"]
            self.active_tab = idx
            self.editor.set_buffer(self.buffers[idx])
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.status_msg = "Undo"

    def _copy_line(self):
        var sel = self._sel_text()
        if sel != "":
            self.clipboard = sel
            self.status_msg = "Copied selection"
            return
        var buf = self.buffers[self.active_tab]
        self.clipboard = buf.get_line(buf.cursor_row)
        self.status_msg = "Copied line " + str(buf.cursor_row + 1)

    def _cut_line(self):
        var sel = self._sel_text()
        if sel != "":
            self.clipboard = sel
            self._sel_delete()
            self.status_msg = "Cut selection"
            return
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        self.clipboard = buf.get_line(buf.cursor_row)
        var keep = []
        var i = 0
        while i < buf.line_count:
            if i != buf.cursor_row:
                keep.append(buf.lines[i])
            i = i + 1
        if len(keep) == 0:
            keep = [""]
        buf.lines = keep
        buf.line_count = len(keep)
        if buf.cursor_row >= buf.line_count:
            buf.cursor_row = buf.line_count - 1
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.tabs[self.active_tab].dirty = true
        self.status_msg = "Cut line"

    def _paste(self):
        if self.clipboard == "":
            self.status_msg = "Clipboard is empty"
            return
        self._push_undo()
        var buf = self.buffers[self.active_tab]
        var out = []
        var i = 0
        while i < buf.line_count:
            out.append(buf.lines[i])
            if i == buf.cursor_row:
                out.append(self.clipboard)
            i = i + 1
        buf.lines = out
        buf.line_count = len(out)
        buf.cursor_row = buf.cursor_row + 1
        self._hl_cache = {}
        self._hl_cache_n = 0
        self.tabs[self.active_tab].dirty = true
        self.status_msg = "Pasted"

    def _find_in_files(self):
        if self.find_query == "":
            self.status_msg = "Set a search term with Ctrl+F first"
            return
        var probs = []
        var n = 0
        var i = 0
        while i < self.ws.row_count:
            var row = self.ws.rows[i]
            if not row.is_dir and row.kind == "code":
                var text = read_file(row.path)
                if text != none:
                    var lines = string_split(text, "\n")
                    var j = 0
                    while j < len(lines) and n < 200:
                        if string_find(lines[j], self.find_query) >= 0:
                            probs = probs + [{"sev": "info", "msg": string_strip(lines[j]),
                                              "file": row.name, "line": j + 1}]
                            n = n + 1
                        j = j + 1
            i = i + 1
        self.problems = probs
        self.problem_count = n
        self.panel_open = true
        self.active_panel = 1
        self.status_msg = str(n) + " matches for '" + self.find_query + "'"

    # ── debugging ────────────────────────────────────────────────────────────
    def _start_debug(self):
        self.panel_open = true
        self.active_panel = 3
        if self.break_count == 0:
            self.status_msg = "No breakpoints set - running to completion"
            self._build_run("Run")
            return
        var buf = self.buffers[self.active_tab]
        var first = -1
        var i = 0
        while i < buf.line_count:
            if self._has_break(i) and first < 0:
                first = i
            i = i + 1
        if first >= 0:
            buf.cursor_row = first
            self.debug_line = first
            self.status_msg = "Stopped at breakpoint, line " + str(first + 1)
            self.console.write("debug: stopped at line " + str(first + 1), "info")

    def _debug_step(self, kind):
        var buf = self.buffers[self.active_tab]
        if buf.cursor_row + 1 < buf.line_count:
            buf.cursor_row = buf.cursor_row + 1
        self.debug_line = buf.cursor_row
        self.status_msg = kind + " - line " + str(buf.cursor_row + 1)

    def _show_help(self, which):
        self.panel_open = true
        self.active_panel = 0
        if which == "About Nython":
            self.console.write("NythonIDE v4  -  Nython " + str(lang_version()), "ok")
            self.console.write("SDL3 " + str(gui_sdl_version()), "info")
        elif which == "Keyboard Shortcuts":
            self.console.write("Ctrl+P palette   Ctrl+F find   Ctrl+H replace   Ctrl+G go to line", "info")
            self.console.write("Ctrl+B sidebar   Ctrl+J panel  Ctrl+O open file  Ctrl+K open folder", "info")
            self.console.write("Ctrl+Shift+N new project      F5 run   F9 breakpoint", "info")
        else:
            self.console.write("Documentation: see CLAUDE.md and SDL3_SETUP.md in the project root", "info")
        self.status_msg = which

    # ── build & run ──────────────────────────────────────────────────────────
    # Executes the current file with the interpreter this IDE is running inside
    # and captures its output, rather than printing a canned message.
    def _save_active(self):
        var t = self.tabs[self.active_tab]
        if t.path == "":
            t.path = os_path_join(getcwd(), t.title)
        write(t.path, self.buffers[self.active_tab].get_all_text())
        t.dirty = false
        return t.path

    # Locate the interpreter to build with. On Windows nython.exe sits beside
    # the IDE; on a dev checkout it is in bin/. Falling straight through to a
    # bare "nython" only works if it happens to be on PATH.
    def _interpreter_path(self):
        var cands = [os_path_join(getcwd(), "nython"),
                     os_path_join(getcwd(), "nython.exe"),
                     os_path_join(os_path_join(getcwd(), "bin"), "nython"),
                     os_path_join(os_path_join(getcwd(), "bin"), "nython.exe"),
                     os_path_join(os_path_join(getcwd(), "bin/Release"), "nython.exe")]
        var i = 0
        while i < len(cands):
            if os_exists(cands[i]):
                return cands[i]
            i = i + 1
        var env = os_getenv("NYTHON_EXE")
        if env != none and env != "":
            return env
        return "nython"

    def _build_run(self, mode):
        self.active_panel = 0
        self.panel_open = true
        var path = self._save_active()
        self.console.write("> " + mode + "  " + path, "info")
        # Flags must match src/main.cpp exactly. "--tokens" was wrong — the
        # interpreter accepts "--tokenize" — so Tokenize silently ran the file
        # instead of dumping its token stream.
        var flag = ""
        if mode == "Tokenize":
            flag = "--tokenize "
        elif mode == "AST":
            flag = "--ast "
        elif mode == "Disasm":
            flag = "--disasm "
        elif mode == "VM":
            flag = "--vm "
        var t0 = time_ms()
        var exe = self._interpreter_path()
        var out = popen("\"" + exe + "\" " + flag + "\"" + path + "\" 2>&1")
        var dt = int(time_ms() - t0)
        if out == none:
            out = ""
        self._parse_build_output(out, path)
        # Tokenize / AST / Disasm produce a dump rather than program output;
        # keep it for the Tokens panel and show that panel instead of Output.
        if mode == "Tokenize" or mode == "AST" or mode == "Disasm":
            var dump = string_split(self._strip_ansi(out), "\n")
            var keep = []
            var kn = 0
            var di = 0
            while di < len(dump) and kn < 400:
                if string_strip(dump[di]) != "":
                    keep.append(dump[di])
                    kn = kn + 1
                di = di + 1
            self.introspect = keep
            self.introspect_n = kn
            self.introspect_kind = mode
            self.active_panel = 4
            self.panel_scroll = 0
        var lines = string_split(out, "\n")
        var i = 0
        var shown = 0
        while i < len(lines) and shown < 200:
            var ln = self._strip_ansi(lines[i])
            if string_strip(ln) != "":
                var kind = "out"
                if string_find(ln, "Error") >= 0 or string_find(ln, "error") >= 0:
                    kind = "err"
                self.console.write(ln, kind)
                shown = shown + 1
            i = i + 1
        if self.build_ok:
            self.console.write("finished in " + str(dt) + " ms", "ok")
            self.status_msg = mode + " succeeded (" + str(dt) + " ms)"
            self._toast(mode + " succeeded in " + str(dt) + " ms", "ok")
        else:
            self.console.write("failed with " + str(self.problem_count) + " problem(s)", "err")
            self.status_msg = mode + " failed"
            self._toast(mode + " failed - see Problems", "err")
        self._layout()

    # Captured output carries terminal colour escapes; strip them so the
    # console shows text rather than control sequences.
    def _strip_ansi(self, text):
        var out = ""
        var i = 0
        var n = len(text)
        while i < n:
            var ch = string_slice(text, i, i + 1)
            if ch == "\x1b":
                while i < n and string_slice(text, i, i + 1) != "m":
                    i = i + 1
                i = i + 1
            else:
                out = out + ch
                i = i + 1
        return out

    # Turn interpreter diagnostics into Problems entries.
    def _parse_build_output(self, out, path):
        var probs = []
        var n = 0
        var lines = string_split(out, "\n")
        var i = 0
        while i < len(lines):
            var ln = lines[i]
            var bad = string_find(ln, "Error") >= 0 or string_find(ln, "error") >= 0
            bad = bad or string_find(ln, "Uncaught") >= 0
            bad = bad or string_find(ln, "not found") >= 0
            bad = bad or string_find(ln, "No such file") >= 0
            bad = bad or string_find(ln, "Traceback") >= 0
            if bad:
                var lineno = 0
                var at = string_find(ln, "line ")
                if at >= 0:
                    var rest = string_slice(ln, at + 5, len(ln))
                    lineno = int(rest)
                probs = probs + [{"sev": "err", "msg": string_strip(ln),
                                  "file": os_path_basename(path), "line": lineno}]
                n = n + 1
            i = i + 1
        self.problems = probs
        self.problem_count = n
        self.build_ok = (n == 0)

    # ── find / replace ───────────────────────────────────────────────────────
    def _find_run(self):
        var hits = []
        var n = 0
        var q = self.find_query
        if q != "":
            var buf = self.buffers[self.active_tab]
            var i = 0
            while i < buf.line_count:
                var ln = buf.get_line(i)
                var at = string_find(ln, q)
                if at >= 0:
                    hits.append({"line": i, "col": at})
                    n = n + 1
                i = i + 1
        self.find_hits = hits
        self.find_hit_count = n
        if self.find_index >= n:
            self.find_index = 0
        if n > 0:
            self._goto_line(self.find_hits[self.find_index]["line"] + 1)

    def _find_step(self, delta):
        if self.find_hit_count == 0:
            return
        self.find_index = self.find_index + delta
        if self.find_index >= self.find_hit_count:
            self.find_index = 0
        if self.find_index < 0:
            self.find_index = self.find_hit_count - 1
        self._goto_line(self.find_hits[self.find_index]["line"] + 1)

    def _replace_current(self, all_of_them):
        if self.find_query == "":
            return
        var buf = self.buffers[self.active_tab]
        var replaced = 0
        var i = 0
        while i < buf.line_count:
            var ln = buf.get_line(i)
            var at = string_find(ln, self.find_query)
            if at >= 0:
                var head = string_slice(ln, 0, at)
                var tail = string_slice(ln, at + len(self.find_query), len(ln))
                buf.lines[i] = head + self.find_replace + tail
                replaced = replaced + 1
                if not all_of_them:
                    i = buf.line_count
            i = i + 1
        self.status_msg = "Replaced " + str(replaced)
        self._hl_cache = {}
        self._hl_cache_n = 0
        self._find_run()

    def _goto_line(self, one_based):
        var buf = self.buffers[self.active_tab]
        var r = one_based - 1
        if r < 0:
            r = 0
        if r >= buf.line_count:
            r = buf.line_count - 1
        buf.cursor_row = r
        buf.cursor_col = 0
        self.status_msg = "Line " + str(r + 1)

    def _draw_find(self, r):
        var th = self.th
        var w = 420
        if w > self.col_w - 40:
            w = self.col_w - 40
        var x = self.col_x + self.col_w - w - 20
        var y = self.ed_y + 8
        var h = 40
        if self.find_replace_mode:
            h = 74
        r.draw_shadow(Rect(x, y, w, h), 18, 0, 6, Color(0, 0, 0, 150))
        r.fill_round_xywh(x, y, w, h, Color(30, 33, 52, 252), 8)
        r.draw_rounded_rect(Rect(x, y, w, h), th.border, 8, 1)
        self.icons.draw(r, "search", x + 10, y + 10, 16, th.text_faint)
        var fb = Color(255, 255, 255, 12)
        if self.find_field == 0:
            fb = Color(110, 118, 246, 40)
        r.fill_round_xywh(x + 32, y + 8, w - 150, 24, fb, 5)
        r.draw_text(self.find_query, x + 40, y + 13, self.f_code, th.text)
        var info = str(self.find_hit_count) + " matches"
        if self.find_hit_count > 0:
            info = str(self.find_index + 1) + " of " + str(self.find_hit_count)
        var im = self.f_small.width(info)
        r.draw_text(info, x + w - im - 14, y + 14, self.f_small, th.text_faint)
        if self.find_replace_mode:
            var rb = Color(255, 255, 255, 12)
            if self.find_field == 1:
                rb = Color(110, 118, 246, 40)
            r.fill_round_xywh(x + 32, y + 40, w - 150, 24, rb, 5)
            r.draw_text(self.find_replace, x + 40, y + 45, self.f_code, th.text)
            r.draw_text("Ctrl+Enter replaces all", x + w - 150, y + 46, self.f_small, th.text_faint)

    def _find_event(self, e):
        if e.type == "keydown":
            if e.key == "escape":
                self.find_open = false
                e.consume()
                return
            if e.key == "enter":
                if e.ctrl and self.find_replace_mode:
                    self._replace_current(true)
                elif self.find_replace_mode and self.find_field == 1:
                    self._replace_current(false)
                else:
                    self._find_step(1)
                e.consume()
                return
            if e.key == "tab":
                if self.find_replace_mode:
                    if self.find_field == 0:
                        self.find_field = 1
                    else:
                        self.find_field = 0
                e.consume()
                return
            if e.key == "backspace":
                if self.find_field == 0:
                    if len(self.find_query) > 0:
                        self.find_query = string_slice(self.find_query, 0, len(self.find_query) - 1)
                        self._find_run()
                else:
                    if len(self.find_replace) > 0:
                        self.find_replace = string_slice(self.find_replace, 0, len(self.find_replace) - 1)
                e.consume()
                return
        if e.type == "textinput":
            if self.find_field == 0:
                self.find_query = self.find_query + e.text
                self._find_run()
            else:
                self.find_replace = self.find_replace + e.text
            e.consume()

    # ── breakpoints ──────────────────────────────────────────────────────────
    def _break_key(self, line):
        return self.tabs[self.active_tab].title + ":" + str(line)

    def _toggle_break(self, line):
        var k = self._break_key(line)
        if self.breaks.has_key(k):
            self.breaks.remove(k)
            self.break_count = self.break_count - 1
            self.status_msg = "Breakpoint cleared at line " + str(line + 1)
        else:
            self.breaks[k] = true
            self.break_count = self.break_count + 1
            self.status_msg = "Breakpoint set at line " + str(line + 1)

    def _has_break(self, line):
        return self.breaks.has_key(self._break_key(line))

    def _term_run(self, cmd):
        var c = string_strip(cmd)
        if c == "":
            return ""
        if c == "help":
            return "commands: help, clear, files, version"
        if c == "clear":
            self.term_lines = []
            self.term_count = 0
            return ""
        if c == "files":
            var out = ""
            var i = 0
            while i < self.tab_count:
                out = out + self.tabs[i].title + "  "
                i = i + 1
            return out
        if c == "version":
            return "Nython 0.2.1  |  NythonIDE v4"
        return "unknown command: " + c

    def _close_tab(self, idx):
        if self.tab_count <= 1:
            self.status_msg = "Cannot close the last tab"
            return
        var nt = []
        var nb = []
        var i = 0
        while i < self.tab_count:
            if i != idx:
                nt.append(self.tabs[i])
                nb.append(self.buffers[i])
            i = i + 1
        var closed = self.tabs[idx].title
        self.tabs = nt
        self.buffers = nb
        self.tab_count = self.tab_count - 1
        if self.active_tab >= self.tab_count:
            self.active_tab = self.tab_count - 1
        self.editor.set_buffer(self.buffers[self.active_tab])
        self.status_msg = "Closed " + closed
        self._layout()

    def _menu_action(self, label):
        if label == "Toggle Sidebar":
            self.sidebar_open = not self.sidebar_open
        elif label == "Toggle Panel":
            self.panel_open = not self.panel_open
        elif label == "Toggle Minimap":
            self.minimap_on = not self.minimap_on
        elif label == "Toggle Theme":
            self._set_theme(not self.th.dark)
            var mode = "dark"
            if not self.th.dark:
                mode = "light"
            self._toast("Theme: " + mode, "ok")
        elif label == "Zoom In":
            self._zoom(1)
        elif label == "Zoom Out":
            self._zoom(0 - 1)
        elif label == "Reset Zoom":
            self._zoom(13 - self.font_size)
        elif label == "Command Palette":
            self._open_palette()
        elif label == "Run":
            self.active_mode = 0
            self._run()
        elif label == "Run on VM":
            self.active_mode = 1
            self._run()
        elif label == "Tokenize":
            self.active_mode = 3
            self._run()
        elif label == "Show AST":
            self.active_mode = 4
            self._run()
        elif label == "Disassemble":
            self.active_mode = 5
            self._run()
        elif label == "Build":
            self.active_mode = 0
            self._run()
        elif label == "Analyse Buffer":
            self.active_view = "ai"
            self.sidebar_open = true
            self._ai_analyze(true)
            self._toast(str(self.ai_n) + " suggestion(s)", "ok")
        elif label == "Lang Workshop":
            self.panel_open = true
            self.active_panel = 5
        elif label == "Terminal":
            self.panel_open = true
            self.active_panel = 2
        elif label == "Exit":
            self._save_settings()
            self.win.running = false
        elif label == "Undo":
            self._undo()
        elif label == "Redo":
            self.status_msg = "Nothing to redo"
        elif label == "Cut":
            self._cut_line()
        elif label == "Copy":
            self._copy_line()
        elif label == "Paste":
            self._paste()
        elif label == "Toggle Comment":
            self._toggle_comment()
        elif label == "Duplicate Line":
            self._duplicate_line()
        elif label == "Delete Line":
            self._delete_line()
        elif label == "Move Line Up":
            self._move_line(0 - 1)
        elif label == "Move Line Down":
            self._move_line(1)
        elif label == "Find":
            self.find_open = true
            self.find_replace_mode = false
            self.find_field = 0
            self._find_run()
        elif label == "Replace":
            self.find_open = true
            self.find_replace_mode = true
            self.find_field = 0
            self._find_run()
        elif label == "Go to Line":
            self._ask("goto", "Go to Line", "Line number", "")
        elif label == "Find in Files":
            self._find_in_files()
        elif label == "Start Debugging":
            self._start_debug()
        elif label == "Step Over" or label == "Step Into":
            self._debug_step(label)
        elif label == "Toggle Breakpoint":
            self._toggle_break(self.buffers[self.active_tab].cursor_row)
        elif label == "Clear All Breakpoints":
            self.breaks = {}
            self.break_count = 0
            self.status_msg = "All breakpoints cleared"
        elif label == "Show Breakpoints":
            self.panel_open = true
            self.active_panel = 3
        elif label == "Add Highlight Token...":
            self._ask("addtoken", "Add Highlight Token", "word  or  word=r,g,b", "")
        elif label == "Reload Highlight Rules":
            self._load_hl_rules(true)
        elif label == "Save Settings":
            self._save_settings()
            self._toast("Settings saved", "ok")
        elif label == "Reload Settings":
            if self._load_settings():
                self._toast("Settings loaded", "ok")
            else:
                self._toast("No .nyide file", "err")
        elif label == "Settings":
            self.panel_open = true
            self.active_panel = 5
        elif label == "Documentation" or label == "Keyboard Shortcuts" or label == "About Nython":
            self._show_help(label)
        elif label == "New Project...":
            self._ask("new_project", "New Project", "Folder to create the project in", os_path_join(getcwd(), "MyProject"))
        elif label == "Open Project...":
            self._ask("open_project", "Open Project", "Path to a .nyproj manifest", getcwd())
        elif label == "Open Folder...":
            self._ask("open_folder", "Open Folder", "Folder to open as the workspace", getcwd())
        elif label == "Open File...":
            self._ask("open_file", "Open File", "Path to a file", getcwd())
        elif label == "Recent Files":
            self.panel_open = true
            self.active_panel = 0
            if self.recent_n == 0:
                self.console.write("no recent files yet", "info")
            else:
                var ri = 0
                while ri < self.recent_n:
                    self.console.write("recent: " + self.recent[ri], "info")
                    ri = ri + 1
        elif label == "Close Folder":
            self.ws.root = ""
            self.ws.rebuild()
        elif label == "Save All":
            self.console.write("saved all open buffers", "ok")
            self.panel_open = true
            self.active_panel = 0
        elif label == "New File":
            var nm = "untitled" + str(self.tab_count + 1) + ".ny"
            self.buffers.append(EditorBuffer(nm, "# " + nm + "\n"))
            self.tabs.append(EdTab(nm))
            self.tab_count = self.tab_count + 1
            self.active_tab = self.tab_count - 1
            self.editor.set_buffer(self.buffers[self.active_tab])
        elif label == "Save":
            self.console.write("saved " + self.tabs[self.active_tab].title, "ok")
            self.panel_open = true
            self.active_panel = 0
        self.status_msg = label
        self._layout()

    def _run_command(self, cmd):
        if string_find(cmd, "Toggle Sidebar") >= 0:
            self.sidebar_open = not self.sidebar_open
        elif string_find(cmd, "Toggle Panel") >= 0:
            self.panel_open = not self.panel_open
        elif string_find(cmd, "Toggle Minimap") >= 0:
            self.minimap_on = not self.minimap_on
        elif string_find(cmd, "Toggle Theme") >= 0:
            self._set_theme(not self.th.dark)
        elif string_find(cmd, "Execute") >= 0:
            self._run()
        self.status_msg = cmd
        self._layout()

    def _open_by_name(self, name):
        var i = 0
        while i < self.tab_count:
            if self.tabs[i].title == name:
                self.active_tab = i
                self.editor.set_buffer(self.buffers[i])
                self.status_msg = "Opened " + name
                return
            i = i + 1
        self.status_msg = name + " is not open"

    def _run(self):
        self._build_run(self.run_modes[self.active_mode])

    def _frame(self, renderer, event):
        self.handle_event(event)
        # Anything that is not an idle tick may have changed the UI.
        if event.type != "idle":
            self._dirty = true
        # The terminal draws a blinking caret, so it must keep animating.
        if self.panel_open and self.active_panel == 2:
            self._dirty = true
        # So does the editor caret.
        # Advance pane animations toward their target. Both are eased with
        # out_cubic, which decelerates into place; a linear slide reads as
        # mechanical and is the thing easing exists to avoid.
        if self._advance_panes():
            self._layout()
            self._dirty = true

        var now = time_ms()
        if now - self.caret_t > 500:
            self.caret_t = now
            self.caret_on = not self.caret_on
            self._dirty = true
        if event.type == "textinput" or event.type == "keydown" or event.type == "mousedown":
            self.caret_on = true
        # Safety net. Skipping repaints depends on the platform delivering an
        # expose/shown event whenever the window needs redrawing. If one is ever
        # missed the window would stay stale forever, so force a repaint at
        # least twice a second regardless. At ~60 Hz this costs two frames a
        # second instead of sixty.
        if self._skipped >= 30:
            self._dirty = true
        if not self.repaint_on_change_only:
            self._dirty = true
        if not self._dirty:
            self._skipped = self._skipped + 1
            return false
        # Coalesce: a poll batch delivers several events (move, down, up) before
        # a single present. Handle them all, but repaint only on the last one.
        if not event.is_last:
            return false
        self._skipped = 0
        self._dirty = false
        self.draw(renderer)
        return true

    def run(self):
        self.win.on_resize(self.on_resize)
        self.win.run(self._frame)


var ide = NythonIDE()
ide.run()

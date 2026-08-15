# ═══════════════════════════════════════════════════════════════════════════════
import nytorch

# gui.ny  -  Nython GUI Library  (SDL3 + OpenGL backend)
# Windows, Widgets, Layouts, Themes, Events, Rendering, Images, Video, Icons
# Usage: import "lib/gui.ny"
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Color ───────────────────────────────────────────────────────────────────

class Color:
    def __init__(self, r, g, b, a):
        self.r = r
        self.g = g
        self.b = b
        self.a = a

    def to_hex(self):
        var hex_chars = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
        var rhi = int(self.r / 16)
        var rlo = int(self.r % 16)
        var ghi = int(self.g / 16)
        var glo = int(self.g % 16)
        var bhi = int(self.b / 16)
        var blo = int(self.b % 16)
        return "#" + hex_chars[rhi] + hex_chars[rlo] + hex_chars[ghi] + hex_chars[glo] + hex_chars[bhi] + hex_chars[blo]

    def lerp(self, other, t):
        return Color(
            int(self.r + (other.r - self.r) * t),
            int(self.g + (other.g - self.g) * t),
            int(self.b + (other.b - self.b) * t),
            int(self.a + (other.a - self.a) * t)
        )

    def with_alpha(self, a):
        return Color(self.r, self.g, self.b, a)

    def darken(self, factor):
        return Color(int(self.r * factor), int(self.g * factor), int(self.b * factor), self.a)

    def lighten(self, factor):
        var r = int(self.r + (255 - self.r) * factor)
        var g = int(self.g + (255 - self.g) * factor)
        var b = int(self.b + (255 - self.b) * factor)
        return Color(r, g, b, self.a)

# ─── Palette ─────────────────────────────────────────────────────────────────

class Palette:
    def __init__(self):
        self.BLACK      = Color(0,   0,   0,   255)
        self.WHITE      = Color(255, 255, 255, 255)
        self.RED        = Color(220, 50,  50,  255)
        self.GREEN      = Color(50,  200, 80,  255)
        self.BLUE       = Color(50,  120, 220, 255)
        self.YELLOW     = Color(240, 210, 50,  255)
        self.ORANGE     = Color(240, 130, 40,  255)
        self.PURPLE     = Color(140, 60,  200, 255)
        self.CYAN       = Color(50,  200, 220, 255)
        self.PINK       = Color(240, 100, 160, 255)
        self.GRAY       = Color(128, 128, 128, 255)
        self.LIGHT_GRAY = Color(200, 200, 200, 255)
        self.DARK_GRAY  = Color(60,  60,  60,  255)
        self.TRANSPARENT= Color(0,   0,   0,   0)
        # ── VS Code "Dark+" workbench colours ────────────────────────────────
        # Previously an iOS system palette, which is why the IDE did not read as
        # an editor. These are the published Dark+ token values.
        self.ACCENT     = Color(0,   122, 204, 255)  # #007ACC  focus / activity badge
        self.SURFACE    = Color(30,  30,  30,  255)  # #1E1E1E  editor background
        self.SURFACE2   = Color(37,  37,  38,  255)  # #252526  sidebar / panel
        self.ON_SURFACE = Color(212, 212, 212, 255)  # #D4D4D4  default foreground
        self.SUCCESS    = Color(137, 209, 133, 255)  # #89D185  git added / pass
        self.WARNING    = Color(204, 167, 0,   255)  # #CCA700  warning squiggle
        self.DANGER     = Color(241, 76,  76,  255)  # #F14C4C  error squiggle
        self.INFO       = Color(117, 190, 255, 255)  # #75BEFF  info squiggle

        # Chrome surfaces
        self.TITLEBAR   = Color(60,  60,  60,  255)  # #3C3C3C  title bar
        self.ACTIVITYBAR= Color(51,  51,  51,  255)  # #333333  activity bar
        self.STATUSBAR  = Color(0,   122, 204, 255)  # #007ACC  status bar
        self.TAB_ACTIVE = Color(30,  30,  30,  255)  # #1E1E1E  active tab
        self.TAB_INACTIVE = Color(45, 45, 45, 255)   # #2D2D2D  inactive tab
        self.BORDER_DIM = Color(59,  59,  59,  255)  # #3B3B3B  panel borders
        self.SELECTION  = Color(38,  79,  120, 255)  # #264F78  editor selection
        self.LINE_HL    = Color(42,  45,  46,  255)  # #2A2D2E  hovered list row
        self.SCROLLBAR  = Color(121, 121, 121, 66)   # #79797942 scrollbar slider

        # Dark+ syntax token colours
        self.SYN_KEYWORD  = Color(197, 134, 192, 255) # #C586C0 control keywords
        self.SYN_DECL     = Color(86,  156, 214, 255) # #569CD6 var / class / types
        self.SYN_STRING   = Color(206, 145, 120, 255) # #CE9178
        self.SYN_NUMBER   = Color(181, 206, 168, 255) # #B5CEA8
        self.SYN_COMMENT  = Color(106, 153, 85,  255) # #6A9955
        self.SYN_FUNCTION = Color(220, 220, 170, 255) # #DCDCAA
        self.SYN_TYPE     = Color(78,  201, 176, 255) # #4EC9B0
        self.SYN_VARIABLE = Color(156, 220, 254, 255) # #9CDCFE
        self.SYN_OPERATOR = Color(212, 212, 212, 255) # #D4D4D4
        self.SYN_CONSTANT = Color(100, 102, 149, 255) # #646695

# ─── Rect ────────────────────────────────────────────────────────────────────

class Rect:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h

    def contains(self, px, py):
        return px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h

    def intersects(self, other):
        return self.x < other.x + other.w and self.x + self.w > other.x and self.y < other.y + other.h and self.y + self.h > other.y

    def expand(self, d):
        return Rect(self.x - d, self.y - d, self.w + d * 2, self.h + d * 2)

    def shrink(self, d):
        return Rect(self.x + d, self.y + d, self.w - d * 2, self.h - d * 2)

    def moved(self, dx, dy):
        return Rect(self.x + dx, self.y + dy, self.w, self.h)

    def center_x(self):
        return int(self.x + self.w / 2)

    def center_y(self):
        return int(self.y + self.h / 2)

    def right(self):
        return self.x + self.w

    def bottom(self):
        return self.y + self.h

# ─── Font ────────────────────────────────────────────────────────────────────

class Font:
    def __init__(self, family, size, bold, italic):
        self.family = family
        self.size = size
        self.bold = bold
        self.italic = italic
        self._handle = none
        self.load()  # auto-load; returns false silently if SDL not ready yet

    def load(self):
        self._handle = gui_load_font(self.family, self.size, self.bold, self.italic)
        return self._handle != none

    def ensure_loaded(self):
        # Lazy retry: if constructed before SDL/TTF was ready, reload now
        if self._handle == none:
            self.load()

    # Width only, without allocating the [w, h] list that measure() returns.
    def width(self, text):
        self.ensure_loaded()
        if self._handle == none:
            return 0
        return gui_measure_text_w(self._handle, text)

    def measure(self, text):
        self.ensure_loaded()
        if self._handle == none:
            return [len(text) * self.size / 2, self.size]
        var result = gui_measure_text(self._handle, text)
        if result == none:
            return [len(text) * self.size / 2, self.size]
        return result

# ─── Theme ───────────────────────────────────────────────────────────────────

class Theme:
    def __init__(self):
        self.pal = Palette()
        self.bg             = self.pal.SURFACE
        self.surface        = self.pal.SURFACE2
        self.text           = self.pal.ON_SURFACE
        self.text_secondary = Color(133, 133, 133, 255)   # #858585 VS Code dimmed
        self.accent         = self.pal.ACCENT
        self.accent_hover   = self.pal.ACCENT.lighten(0.2)
        self.accent_press   = self.pal.ACCENT.darken(0.85)
        self.border         = self.pal.BORDER_DIM          # #3B3B3B
        self.titlebar       = self.pal.TITLEBAR
        self.activitybar    = self.pal.ACTIVITYBAR
        self.statusbar      = self.pal.STATUSBAR
        self.tab_active     = self.pal.TAB_ACTIVE
        self.tab_inactive   = self.pal.TAB_INACTIVE
        self.selection      = self.pal.SELECTION
        self.line_highlight = self.pal.LINE_HL
        self.scrollbar      = self.pal.SCROLLBAR
        self.shadow         = Color(0, 0, 0, 100)
        self.success        = self.pal.SUCCESS
        self.warning        = self.pal.WARNING
        self.danger         = self.pal.DANGER
        self.info           = self.pal.INFO
        self.font_size      = 14
        self.font_family    = "sans-serif"
        self.radius         = 4    # VS Code chrome is near-square, not pill-shaped
        self.spacing        = 8
        self.padding        = 12

    def dark(self):
        return self

    def light(self):
        var t = Theme()
        t.bg             = Color(245, 245, 250, 255)
        t.surface        = Color(255, 255, 255, 255)
        t.text           = Color(20, 20, 30, 255)
        t.text_secondary = Color(100, 100, 110, 255)
        t.border         = Color(200, 200, 210, 255)
        return t

# ─── CursorManager ───────────────────────────────────────────────────────────
# gui_set_cursor() has always existed with twelve named system cursors, but
# nothing ever called it: the pointer stayed an arrow everywhere, including over
# editor text and over pane splitters that can be dragged. That is one of the
# strongest signals that a UI is not a real application - a text area that does
# not show an I-beam reads as a picture of a text area.
#
# Regions are registered per frame in priority order (last match wins for equal
# priority), and the cursor is only pushed to SDL when it actually changes, so
# a mouse-motion storm does not turn into a syscall storm.
#
#   cursors.begin()
#   cursors.add(editor_rect, "ibeam")
#   cursors.add(splitter_rect, "sizewe", 10)
#   cursors.apply(mouse_x, mouse_y)

class CursorRegion:
    def __init__(self, rect, shape, priority):
        self.rect = rect
        self.shape = shape
        self.priority = priority


class CursorManager:
    def __init__(self):
        self.regions = []
        self.region_count = 0
        self.current = "arrow"
        self.default_shape = "arrow"
        self.enabled = true
        self.changes = 0          # counts real cursor switches, for tests
        self.locked = ""          # non-empty pins the cursor (e.g. during a drag)

    def begin(self):
        self.regions = []
        self.region_count = 0

    def add(self, rect, shape):
        return self.add_p(rect, shape, 0)

    def add_p(self, rect, shape, priority):
        self.regions = self.regions + [CursorRegion(rect, shape, priority)]
        self.region_count = self.region_count + 1
        return self.region_count

    # Pin a shape regardless of hit-testing. A pane drag must keep its resize
    # cursor even when the pointer runs off the splitter mid-drag.
    def lock(self, shape):
        self.locked = shape

    def unlock(self):
        self.locked = ""

    def shape_at(self, x, y):
        if len(self.locked) > 0:
            return self.locked
        var best = self.default_shape
        var best_pri = -1
        var i = 0
        while i < self.region_count:
            var r = self.regions[i]
            if r.rect.contains(x, y):
                if r.priority >= best_pri:
                    best_pri = r.priority
                    best = r.shape
            i = i + 1
        return best

    def apply(self, x, y):
        if not self.enabled:
            return self.current
        var want = self.shape_at(x, y)
        if want != self.current:
            self.current = want
            self.changes = self.changes + 1
            gui_set_cursor(want)
        return self.current

    def reset(self):
        self.locked = ""
        if self.current != self.default_shape:
            self.current = self.default_shape
            self.changes = self.changes + 1
            gui_set_cursor(self.default_shape)


# ─── Splitter ────────────────────────────────────────────────────────────────
# A draggable divider between two panes. The IDE grew its own ad-hoc splitter
# handling inline; this is the reusable widget the audit found missing, so any
# container can have resizable panes without repeating the drag bookkeeping.

class Splitter:
    def __init__(self, orientation, position, thickness):
        self.orientation = orientation    # "vertical" (drag left/right) | "horizontal"
        self.position = position          # px along the axis being split
        self.thickness = thickness
        self.hit_slop = 4                 # grab margin either side of the visible line
        self.min_before = 80
        self.min_after = 80
        self.dragging = false
        self.drag_origin = 0
        self.drag_start = 0
        self.rect = Rect(0, 0, 0, 0)
        self.extent = 0                   # total size of the axis being split
        self.visible = true
        self.on_move = none

    def cursor_shape(self):
        if self.orientation == "vertical":
            return "sizewe"
        return "sizens"

    # Where the grab band is, given the container rect.
    def layout(self, x, y, w, h):
        if self.orientation == "vertical":
            self.extent = w
            self.rect = Rect(x + self.position - self.hit_slop, y,
                             self.thickness + self.hit_slop * 2, h)
        else:
            self.extent = h
            self.rect = Rect(x, y + self.position - self.hit_slop,
                             w, self.thickness + self.hit_slop * 2)
        return self.rect

    def contains(self, px, py):
        return self.rect.contains(px, py)

    def _clamp(self, v):
        if v < self.min_before:
            v = self.min_before
        var limit = self.extent - self.min_after
        if limit < self.min_before:
            limit = self.min_before
        if v > limit:
            v = limit
        return v

    def begin_drag(self, px, py):
        self.dragging = true
        if self.orientation == "vertical":
            self.drag_origin = px
        else:
            self.drag_origin = py
        self.drag_start = self.position
        return true

    def drag_to(self, px, py):
        if not self.dragging:
            return self.position
        var cur = px
        if self.orientation != "vertical":
            cur = py
        self.position = self._clamp(self.drag_start + (cur - self.drag_origin))
        if self.on_move != none:
            self.on_move(self.position)
        return self.position

    def end_drag(self):
        self.dragging = false
        return self.position

    def set_position(self, v):
        self.position = self._clamp(v)
        return self.position

    def handle_event(self, event):
        if not self.visible:
            return false
        if event.type == "mousedown" and self.contains(event.x, event.y):
            self.begin_drag(event.x, event.y)
            event.consume()
            return true
        if event.type == "mousemove" and self.dragging:
            self.drag_to(event.x, event.y)
            event.consume()
            return true
        if event.type == "mouseup" and self.dragging:
            self.end_drag()
            event.consume()
            return true
        return false


# ─── ScrollArea ──────────────────────────────────────────────────────────────
# Scrolling was reimplemented per widget with its own clamping. This centralises
# it: content extent in, viewport out, plus scrollbar geometry computed the way
# every real editor does it (thumb size proportional to the visible fraction).

class ScrollArea:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.content_w = 0
        self.content_h = 0
        self.scroll_x = 0
        self.scroll_y = 0
        self.line_height = 18
        self.bar_thickness = 10
        self.wheel_lines = 3

    def set_content(self, w, h):
        self.content_w = w
        self.content_h = h
        self.clamp()
        return self

    def max_scroll_y(self):
        var m = self.content_h - self.rect.h
        if m < 0:
            return 0
        return m

    def max_scroll_x(self):
        var m = self.content_w - self.rect.w
        if m < 0:
            return 0
        return m

    def clamp(self):
        if self.scroll_y > self.max_scroll_y():
            self.scroll_y = self.max_scroll_y()
        if self.scroll_y < 0:
            self.scroll_y = 0
        if self.scroll_x > self.max_scroll_x():
            self.scroll_x = self.max_scroll_x()
        if self.scroll_x < 0:
            self.scroll_x = 0
        return self.scroll_y

    def scroll_by(self, dx, dy):
        self.scroll_x = self.scroll_x + dx
        self.scroll_y = self.scroll_y + dy
        return self.clamp()

    def scroll_wheel(self, delta):
        return self.scroll_by(0, -delta * self.wheel_lines * self.line_height)

    def scroll_to(self, y):
        self.scroll_y = y
        return self.clamp()

    def page_down(self):
        return self.scroll_by(0, self.rect.h)

    def page_up(self):
        return self.scroll_by(0, -self.rect.h)

    def needs_vbar(self):
        return self.content_h > self.rect.h

    def needs_hbar(self):
        return self.content_w > self.rect.w

    # Thumb length is the visible fraction of the content, floored so it stays
    # grabbable in a very long document.
    def vbar_thumb(self):
        if not self.needs_vbar():
            return [0, 0]
        var frac = float(self.rect.h) / float(self.content_h)
        var len_px = int(float(self.rect.h) * frac)
        if len_px < 24:
            len_px = 24
        var travel = self.rect.h - len_px
        var pos = 0
        if self.max_scroll_y() > 0:
            pos = int(float(travel) * (float(self.scroll_y) / float(self.max_scroll_y())))
        return [pos, len_px]

    # Only the rows actually on screen need rendering; a 10k-line file draws ~40.
    def visible_range(self, row_height):
        if row_height <= 0:
            return [0, 0]
        var first = int(self.scroll_y / row_height)
        var count = int(self.rect.h / row_height) + 2
        return [first, count]


# ─── FocusManager ────────────────────────────────────────────────────────────
# Keyboard focus was tracked ad hoc per widget with no way to move between
# widgets, so Tab did nothing. This owns the ring and the traversal.

class FocusManager:
    def __init__(self):
        self.order = []
        self.count = 0
        self.index = -1

    def register(self, key):
        self.order = self.order + [key]
        self.count = self.count + 1
        if self.index < 0:
            self.index = 0
        return self.count

    def current(self):
        if self.index < 0 or self.index >= self.count:
            return ""
        return self.order[self.index]

    def focus(self, key):
        var i = 0
        while i < self.count:
            if self.order[i] == key:
                self.index = i
                return true
            i = i + 1
        return false

    def has_focus(self, key):
        return self.current() == key

    # Tab wraps forward, Shift+Tab wraps backward - both must wrap, or focus
    # gets stuck at an end of the ring.
    def next(self):
        if self.count == 0:
            return ""
        self.index = self.index + 1
        if self.index >= self.count:
            self.index = 0
        return self.current()

    def prev(self):
        if self.count == 0:
            return ""
        self.index = self.index - 1
        if self.index < 0:
            self.index = self.count - 1
        return self.current()

    def clear(self):
        self.index = -1
        return true


# ─── Event ───────────────────────────────────────────────────────────────────

class Event:
    def __init__(self, type_name):
        self.type = type_name
        self.x = 0
        self.y = 0
        self.button = 0
        self.key = ""
        self.keycode = 0
        self.mods = 0
        self.text = ""
        self.delta = 0
        self.consumed = false
        # True when this is the final event of the current poll batch. A
        # callback that repaints should repaint on this event only: the whole
        # batch is processed before a single present, so repainting on every
        # event does N full repaints for one visible frame.
        self.is_last = true
        self.ctrl = false
        self.shift = false
        self.alt = false

    def consume(self):
        self.consumed = true

    def is_mouse(self):
        return self.type == "mousedown" or self.type == "mouseup" or self.type == "mousemove"

    def is_keyboard(self):
        return self.type == "keydown" or self.type == "keyup" or self.type == "textinput"

    def is_click(self):
        return self.type == "click"

    def is_key(self, key_name):
        return self.is_keyboard() and self.key == key_name

# ─── Base Widget ─────────────────────────────────────────────────────────────

class Widget:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.visible = true
        self.enabled = true
        self.focused = false
        self.hovered = false
        self.pressed = false
        self.theme = Theme()
        self.parent = none
        self.children = []
        self.child_count = 0
        self.z_order = 0
        self._event_handlers = {}
        self._eh_counts = {}
        self.id = ""
        self.tooltip = ""
        self.opacity = 1.0

    def add_child(self, widget):
        widget.parent = self
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def remove_child(self, widget):
        var new_children = []
        var new_count = 0
        var i = 0
        while i < self.child_count:
            if self.children[i].id != widget.id:
                new_children.append(self.children[i])
                new_count = new_count + 1
            i = i + 1
        self.children = new_children
        self.child_count = new_count

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none and event.consumed == false:
                h(event)
            i = i + 1

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var is_inside = self.rect.contains(event.x, event.y)
        if event.type == "mousemove":
            var was_hovered = self.hovered
            self.hovered = is_inside
            if is_inside and was_hovered == false:
                var ev = Event("mouseenter")
                ev.x = event.x
                ev.y = event.y
                self.emit(ev)
            elif is_inside == false and was_hovered:
                ev = Event("mouseleave")
                self.emit(ev)
        if event.type == "mousedown" and is_inside:
            self.pressed = true
            self.focused = true
            self.emit(event)
        if event.type == "mouseup" and self.pressed:
            self.pressed = false
            if is_inside:
                var click_ev = Event("click")
                click_ev.x = event.x
                click_ev.y = event.y
                click_ev.button = event.button
                self.emit(click_ev)
            self.emit(event)
        if event.type == "keydown" and self.focused:
            self.emit(event)
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1

    def draw(self, renderer):
        if self.visible == false:
            return
        self._draw(renderer)
        var i = 0
        while i < self.child_count:
            self.children[i].draw(renderer)
            i = i + 1

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.theme.surface)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

    def set_theme(self, theme):
        self.theme = theme
        var i = 0
        while i < self.child_count:
            self.children[i].set_theme(theme)
            i = i + 1
        return self

# ─── Renderer (SDL2 / OpenGL abstraction) ────────────────────────────────────

class Renderer:
    def __init__(self, window_handle):
        self.handle = window_handle
        self.gl = none

    def clear(self, color):
        gui_clear(self.handle, color.r, color.g, color.b, color.a)

    def present(self):
        gui_present(self.handle)

    # Raw-coordinate variants. fill_rect(Rect(...)) allocates a Rect per call,
    # and the IDE issues a few hundred of those per frame.
    def fill_xywh(self, x, y, w, h, color):
        gui_fill_rect(self.handle, x, y, w, h, color.r, color.g, color.b, color.a)

    def fill_round_xywh(self, x, y, w, h, color, radius):
        gui_fill_rounded_rect(self.handle, x, y, w, h, color.r, color.g, color.b, color.a, radius)

    def fill_rect(self, rect, color):
        gui_fill_rect(self.handle, rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a)

    def draw_rect(self, rect, color, border_w):
        gui_draw_rect(self.handle, rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a, border_w)

    def fill_rounded_rect(self, rect, color, radius):
        gui_fill_rounded_rect(self.handle, rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a, radius)

    def draw_rounded_rect(self, rect, color, radius, border_w):
        gui_draw_rounded_rect(self.handle, rect.x, rect.y, rect.w, rect.h, color.r, color.g, color.b, color.a, radius, border_w)

    def draw_text(self, text, x, y, font, color):
        font.ensure_loaded()
        if font._handle == none:
            return
        gui_draw_text(self.handle, text, x, y, font._handle, color.r, color.g, color.b, color.a)

    def draw_image(self, image_handle, x, y, w, h):
        gui_draw_image(self.handle, image_handle, x, y, w, h)

    def draw_circle(self, cx, cy, radius, color):
        gui_draw_circle(self.handle, cx, cy, radius, color.r, color.g, color.b, color.a)

    def fill_circle(self, cx, cy, radius, color):
        gui_fill_circle(self.handle, cx, cy, radius, color.r, color.g, color.b, color.a)

    def draw_line(self, x1, y1, x2, y2, color, thickness):
        gui_draw_line(self.handle, x1, y1, x2, y2, color.r, color.g, color.b, color.a, thickness)

    def draw_shadow(self, rect, blur, offset_x, offset_y, color):
        gui_draw_shadow(self.handle, rect.x, rect.y, rect.w, rect.h, blur, offset_x, offset_y, color.r, color.g, color.b, color.a)

    def draw_gradient(self, rect, color1, color2, vertical):
        gui_draw_gradient(self.handle, rect.x, rect.y, rect.w, rect.h, color1.r, color1.g, color1.b, color2.r, color2.g, color2.b, vertical)

    def set_clip(self, rect):
        gui_set_clip(self.handle, rect.x, rect.y, rect.w, rect.h)

    def clear_clip(self):
        gui_clear_clip(self.handle)

    def set_viewport(self, rect):
        gui_set_viewport(self.handle, rect.x, rect.y, rect.w, rect.h)

    def clear_viewport(self):
        gui_clear_viewport(self.handle)

    def draw_polygon(self, points, n, color):
        gui_draw_polygon(self.handle, points, n, color.r, color.g, color.b, color.a)

    def fill_polygon(self, points, n, color):
        gui_fill_polygon(self.handle, points, n, color.r, color.g, color.b, color.a)

# ─── Window ───────────────────────────────────────────────────────────────────

class Window:
    def __init__(self, width, height, title):
        self.title = title
        self.x = -1
        self.y = -1
        self.width = width
        self.height = height
        self._handle = none
        self.renderer = none
        self.root = none
        self.running = false
        self.fps = 60
        self.theme = Theme()
        self._on_close = none
        self._on_resize = none
        self.resizable = true
        self.borderless = false
        self.always_on_top = false

    def create(self):
        var flags = 0
        if self.resizable:
            flags = flags + 1
        if self.borderless:
            flags = flags + 2
        if self.always_on_top:
            flags = flags + 4
        self._handle = gui_create_window(self.title, self.x, self.y, self.width, self.height, flags)
        if self._handle == none:
            return false
        self.renderer = Renderer(self._handle)
        self.root = Widget(0, 0, self.width, self.height)
        self.root.theme = self.theme
        return true
    def add(self, widget):
        if self.root != none:
            self.root.add_child(widget)
        return self

    def set_icon(self, image_path):
        var img = gui_load_image(image_path)
        if img != none:
            gui_set_window_icon(self._handle, img)

    def set_title(self, title):
        self.title = title
        gui_set_window_title(self._handle, title)

    def maximize(self):
        gui_maximize_window(self._handle)

    def minimize(self):
        gui_minimize_window(self._handle)

    def restore(self):
        gui_restore_window(self._handle)

    def center(self):
        gui_center_window(self._handle)

    def on_close(self, fn):
        self._on_close = fn

    def on_resize(self, fn):
        self._on_resize = fn

    def _process_event(self, raw_event):
        # Normalise event type: C++ backend emits "wheel", widgets expect "scroll"
        var etype = raw_event["type"]
        if etype == "wheel":
            etype = "scroll"
        var ev = Event(etype)
        ev.x = raw_event["x"]
        ev.y = raw_event["y"]
        ev.button = raw_event["button"]
        ev.key = raw_event["key"]
        ev.keycode = raw_event["keycode"]
        ev.text = raw_event["text"]
        ev.delta = raw_event["delta"]
        ev.ctrl = raw_event["ctrl"]
        ev.shift = raw_event["shift"]
        ev.alt = raw_event["alt"]
        if ev.type == "quit":
            self.running = false
            if self._on_close != none:
                self._on_close()
            return
        if ev.type == "resize":
            self.width = raw_event["w"]
            self.height = raw_event["h"]
            # The IDE drives its own layout and never installs a root widget,
            # so root is none here. Assigning through it aborted resize handling
            # before _on_resize could ever fire.
            if self.root != none:
                self.root.rect.w = self.width
                self.root.rect.h = self.height
            if self._on_resize != none:
                self._on_resize(self.width, self.height)
            return
        if self.root != none:
            self.root.handle_event(ev)

    def run(self, callback):
        if self._handle == none:
            var ok = self.create()
            if not ok:
                var err = gui_get_error()
                var ver = gui_sdl_version()
                if ver == none:
                    # gui_sdl_version() can only return none when the gui_* builtins
                    # were never dispatched at all — the SDL backend was never even
                    # reached. This is an interpreter/runtime wiring fault, NOT a
                    # graphics problem. Do not send the user off to update drivers.
                    print "[Nython] GUI builtins are not available in this runtime."
                    print "[Nython] gui_sdl_version() returned none, which means the"
                    print "[Nython] gui_* builtins were never dispatched — SDL was"
                    print "[Nython] never called, so this is NOT a GPU/driver issue."
                    print "[Nython] This build's entry point must execute scripts via"
                    print "[Nython] NythonExecutor (which owns dispatch_gui), not via"
                    print "[Nython] the bytecode VM, which registers no gui_* natives."
                elif err != "" and err != none:
                    print "[Nython] Cannot open window: " + str(err)
                    print "[Nython] SDL3 runtime " + str(ver) + " is loaded and was called."
                else:
                    print "[Nython] Window creation failed (SDL3 " + str(ver) + " is loaded)."
                    print "[Nython] SDL_CreateWindow returned NULL but set no error text."
                    print "[Nython] Possible causes:"
                    print "[Nython]   1. GPU drivers outdated — update them and reboot"
                    print "[Nython]   2. Running inside Remote Desktop or VM without GPU"
                    print "[Nython]   3. SDL3.dll is 32-bit but nython.exe is 64-bit"
                    print "[Nython]   4. Missing Windows system DLL (run: dxdiag)"
                return
        self.running = true
        var frame_ms = int(1000 / self.fps)
        while self.running:
            var t_start = time_ms()
            var painted = false
            var events = gui_poll_events(self._handle)
            var i = 0
            while i < len(events):
                var raw = events[i]
                self._process_event(raw)
                if callback != none:
                    var rtype = raw["type"]
                    if rtype == "wheel":
                        rtype = "scroll"
                    var ev = Event(rtype)
                    ev.x = raw["x"]
                    ev.y = raw["y"]
                    ev.button = raw["button"]
                    ev.key = raw["key"]
                    ev.keycode = raw["keycode"]
                    ev.text = raw["text"]
                    ev.delta = raw["delta"]
                    ev.ctrl = raw["ctrl"]
                    ev.shift = raw["shift"]
                    ev.alt = raw["alt"]
                    ev.is_last = (i == len(events) - 1)
                    var rp = callback(self.renderer, ev)
                    if rp != false:
                        painted = true
                i = i + 1
            if callback != none:
                if len(events) == 0:
                    var idle_ev = Event("idle")
                    var rp2 = callback(self.renderer, idle_ev)
                    if rp2 != false:
                        painted = true
            else:
                self.renderer.clear(self.theme.bg)
                if self.root != none:
                    self.root.draw(self.renderer)
                painted = true
            # Only present a frame that was actually drawn.
            #
            # After SDL_RenderPresent the backbuffer contents are undefined, so
            # a callback that skips drawing must also skip the present or the
            # window shows garbage. A callback may therefore return false to
            # mean "nothing changed, do not present". Returning anything else
            # (including none, which every existing callback returns) presents
            # as before, so this is backward compatible.
            if painted:
                self.renderer.present()
            # Frame pacing: sleep only the time left in this frame's budget.
            # Sleeping a flat frame_ms after the work was done made the real
            # period (work + frame_ms) instead of max(work, frame_ms), which
            # capped the IDE well below its target frame rate.
            var elapsed = int(time_ms() - t_start)
            var remain = frame_ms - elapsed
            if remain > 0:
                thread_sleep(remain)
        self.destroy()

    def destroy(self):
        if self._handle != none:
            gui_destroy_window(self._handle)
            self._handle = none

# ─── Button ───────────────────────────────────────────────────────────────────

class Button:
    def __init__(self, x, y, w, h, label):
        self.rect = Rect(x, y, w, h)
        self.label = label
        self.visible = true
        self.enabled = true
        self.hovered = false
        self.pressed = false
        self.focused = false
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.icon = none
        self.icon_size = 20
        self.border_radius = 8
        self.variant = "primary"
        self._eh_counts = {}
        self._event_handlers = {}
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self._loading = false
        self._animation = 0.0

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def _get_bg_color(self):
        if self.enabled == false:
            return self.theme.border
        if self.variant == "primary":
            if self.pressed:
                return self.theme.accent.darken(0.85)
            if self.hovered:
                return self.theme.accent.lighten(0.2)
            return self.theme.accent
        if self.variant == "secondary":
            if self.pressed:
                return self.theme.surface.darken(0.8)
            if self.hovered:
                return self.theme.surface.lighten(0.15)
            return self.theme.surface
        if self.variant == "danger":
            if self.pressed:
                return self.theme.danger.darken(0.8)
            if self.hovered:
                return self.theme.danger.lighten(0.2)
            return self.theme.danger
        if self.variant == "ghost":
            if self.pressed or self.hovered:
                return Color(255, 255, 255, 30)
            return Color(0, 0, 0, 0)
        return self.theme.accent

    def _draw(self, renderer):
        var bg = self._get_bg_color()
        if self.variant != "ghost":
            renderer.draw_shadow(self.rect, 4, 0, 2, Color(0,0,0,80))
        renderer.fill_rounded_rect(self.rect, bg, self.border_radius)
        if self.focused:
            var focus_rect = self.rect.expand(2)
            renderer.draw_rounded_rect(focus_rect, self.theme.accent, self.border_radius + 2, 2)
        var text_color = self.theme.text
        if self.variant == "primary":
            text_color = Color(255, 255, 255, 255)
        if self.enabled == false:
            text_color = text_color.with_alpha(120)
        if self._loading:
            renderer.draw_text("...", self.rect.center_x() - 10, self.rect.center_y() - 7, self.font, text_color)
        else:
            var txt = self.label
            var size = self.font.measure(txt)
            var tx = self.rect.center_x() - size[0] / 2
            var ty = self.rect.center_y() - size[1] / 2
            renderer.draw_text(txt, tx, ty, self.font, text_color)

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var inside = self.rect.contains(event.x, event.y)
        if event.type == "mousemove":
            self.hovered = inside
        if event.type == "mousedown" and inside:
            self.pressed = true
            self.focused = true
        if event.type == "mouseup" and self.pressed:
            self.pressed = false
            if inside:
                var click_ev = Event("click")
                click_ev.x = event.x
                click_ev.y = event.y
                self.emit(click_ev)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_loading(self, loading):
        self._loading = loading
        return self

    def set_variant(self, v):
        self.variant = v
        return self

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── Label ───────────────────────────────────────────────────────────────────

class Label:
    def __init__(self, x, y, w, h, text):
        self.rect = Rect(x, y, w, h)
        self.text = text
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.color = none
        self.align = "left"
        self.wrap = false
        self.visible = true
        self.children = []
        self.child_count = 0
        self.parent = none
        self.id = ""

    def _draw(self, renderer):
        var c = self.color
        if c == none:
            c = self.theme.text
        var x = self.rect.x
        if self.align == "center":
            var size = self.font.measure(self.text)
            x = self.rect.center_x() - size[0] / 2
        elif self.align == "right":
            size = self.font.measure(self.text)
            x = self.rect.right() - size[0]
        renderer.draw_text(self.text, x, self.rect.y, self.font, c)

    def handle_event(self, event):
        pass

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_text(self, text):
        self.text = text
        return self

    def set_color(self, color):
        self.color = color
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── TextInput ────────────────────────────────────────────────────────────────

class TextInput:
    def __init__(self, x, y, w, h, placeholder=""):
        self.rect = Rect(x, y, w, h)
        self.placeholder = placeholder
        self.value = ""
        self.focused = false
        self.hovered = false
        self.cursor = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.password = false
        self.max_length = 256
        self.visible = true
        self.enabled = true
        self.children = []
        self.child_count = 0
        self.parent = none
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def _draw(self, renderer):
        var bg = self.theme.surface
        var border_color = self.theme.border
        if self.focused:
            border_color = self.theme.accent
        if self.hovered and self.focused == false:
            border_color = self.theme.text_secondary
        renderer.fill_rounded_rect(self.rect, bg, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, border_color, self.theme.radius, 1)
        var display = self.value
        if self.password:
            display = self._stars(len(self.value))
        var text_color = self.theme.text
        if len(display) == 0:
            display = self.placeholder
            text_color = self.theme.text_secondary
        renderer.draw_text(display, self.rect.x + 10, self.rect.center_y() - 7, self.font, text_color)
        if self.focused:
            var cursor_x = self.rect.x + 10 + self.cursor * 8
            renderer.draw_line(cursor_x, self.rect.y + 6, cursor_x, self.rect.bottom() - 6, self.theme.accent, 1)

    def _stars(self, n):
        var s = ""
        var i = 0
        while i < n:
            s = s + "*"
            i = i + 1
        return s

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var inside = self.rect.contains(event.x, event.y)
        if event.type == "mousedown":
            self.focused = inside
        if event.type == "mousemove":
            self.hovered = inside
        # "textinput" = printable characters from SDL3 (was wrongly "keychar")
        if self.focused and event.type == "textinput":
            if len(self.value) < self.max_length:
                self.value = self.value + event.text
                self.cursor = self.cursor + 1
                var ev = Event("input")
                ev.text = self.value
                self.emit(ev)
        if self.focused and event.type == "keydown":
            # Keys are normalised to lowercase by gui.cpp event builder
            if event.key == "backspace" and len(self.value) > 0:
                self.value = self.value[0:len(self.value) - 1]
                if self.cursor > 0:
                    self.cursor = self.cursor - 1
                var ev = Event("input")
                ev.text = self.value
                self.emit(ev)
            if event.key == "enter":
                var ev = Event("submit")
                ev.text = self.value
                self.emit(ev)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def clear(self):
        self.value = ""
        self.cursor = 0
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Checkbox ────────────────────────────────────────────────────────────────

class Checkbox:
    def __init__(self, x, y, label):
        self.rect = Rect(x, y, 20, 20)
        self.label = label
        self.checked = false
        self.hovered = false
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def _draw(self, renderer):
        var bg = self.theme.surface
        var border = self.theme.border
        if self.checked:
            bg = self.theme.accent
            border = self.theme.accent
        if self.hovered:
            border = self.theme.accent
        renderer.fill_rounded_rect(self.rect, bg, 4)
        renderer.draw_rounded_rect(self.rect, border, 4, 1)
        if self.checked:
            var cx = self.rect.x + 4
            var cy = self.rect.y + 10
            renderer.draw_line(cx, cy, cx + 5, cy + 5, Color(255,255,255,255), 2)
            renderer.draw_line(cx + 5, cy + 5, cx + 12, cy - 4, Color(255,255,255,255), 2)
        var label_x = self.rect.right() + 8
        var label_y = self.rect.y + 3
        renderer.draw_text(self.label, label_x, label_y, self.font, self.theme.text)

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var label_w = len(self.label) * 8
        var full_rect = Rect(self.rect.x, self.rect.y, self.rect.w + 12 + label_w, self.rect.h)
        var inside = full_rect.contains(event.x, event.y)
        if event.type == "mousemove":
            self.hovered = inside
        if event.type == "mousedown" and inside:
            self.checked = self.checked == false
            var ev = Event("change")
            ev.text = str(self.checked)
            self.emit(ev)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Slider ──────────────────────────────────────────────────────────────────

class Slider:
    def __init__(self, x, y, w, min_val, max_val, value):
        self.rect = Rect(x, y, w, 24)
        self.min_val = min_val
        self.max_val = max_val
        self.value = value
        self.hovered = false
        self.dragging = false
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.show_value = true
        self.step = 1.0
        self.visible = true
        self.enabled = true
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def _value_to_x(self):
        var t = (self.value - self.min_val) / (self.max_val - self.min_val)
        return self.rect.x + int(t * self.rect.w)

    def _x_to_value(self, x):
        var t = float(x - self.rect.x) / float(self.rect.w)
        if t < 0.0: t = 0.0
        if t > 1.0: t = 1.0
        var raw = self.min_val + t * (self.max_val - self.min_val)
        return int(raw / self.step) * self.step

    def _draw(self, renderer):
        var track_rect = Rect(self.rect.x, self.rect.center_y() - 3, self.rect.w, 6)
        renderer.fill_rounded_rect(track_rect, self.theme.border, 3)
        var fill_w = self._value_to_x() - self.rect.x
        var fill_rect = Rect(self.rect.x, self.rect.center_y() - 3, fill_w, 6)
        renderer.fill_rounded_rect(fill_rect, self.theme.accent, 3)
        var thumb_x = self._value_to_x()
        var thumb_color = self.theme.accent
        if self.hovered or self.dragging:
            thumb_color = self.theme.accent_hover
        renderer.fill_circle(thumb_x, self.rect.center_y(), 10, thumb_color)
        renderer.draw_circle(thumb_x, self.rect.center_y(), 10, Color(255,255,255,60))
        if self.show_value:
            var txt = str(self.value)
            renderer.draw_text(txt, thumb_x - 10, self.rect.y - 18, self.font, self.theme.text)

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var inside = self.rect.contains(event.x, event.y)
        if event.type == "mousemove":
            self.hovered = inside
            if self.dragging:
                self.value = self._x_to_value(event.x)
                var ev = Event("change")
                ev.delta = self.value
                self.emit(ev)
        if event.type == "mousedown" and inside:
            self.dragging = true
            self.value = self._x_to_value(event.x)
            ev = Event("change")
            ev.delta = self.value
            self.emit(ev)
        if event.type == "mouseup":
            self.dragging = false

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ProgressBar ─────────────────────────────────────────────────────────────

class ProgressBar:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.value = 0.0
        self.min_val = 0.0
        self.max_val = 100.0
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.show_percent = true
        self.animated = true
        self.color = none
        self.visible = true
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none

    def set_value(self, v):
        if v < self.min_val: v = self.min_val
        if v > self.max_val: v = self.max_val
        self.value = v

    def percent(self):
        return (self.value - self.min_val) / (self.max_val - self.min_val) * 100.0

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.theme.surface, self.rect.h / 2)
        var t = (self.value - self.min_val) / (self.max_val - self.min_val)
        var fill_w = int(self.rect.w * t)
        if fill_w > 0:
            var fill_rect = Rect(self.rect.x, self.rect.y, fill_w, self.rect.h)
            var c = self.color
            if c == none:
                c = self.theme.accent
            renderer.fill_rounded_rect(fill_rect, c, self.rect.h / 2)
        if self.show_percent:
            var txt = str(int(t * 100)) + "%"
            var tw = len(txt) * 7
            renderer.draw_text(txt, self.rect.center_x() - tw / 2, self.rect.center_y() - 7, self.font, self.theme.text)

    def handle_event(self, event):
        pass

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Image ───────────────────────────────────────────────────────────────────

class Image:
    def __init__(self, x, y, w, h, path):
        self.rect = Rect(x, y, w, h)
        self.path = path
        self._handle = none
        self.loaded = false
        self.visible = true
        self.opacity = 1.0
        self.fit = "cover"
        self.theme = Theme()
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self.rounded = false
        self.radius = 8
        self._font_placeholder = Font("sans-serif", 12, false, false)

    def load(self):
        self._handle = gui_load_image(self.path)
        self.loaded = self._handle != none
        return self.loaded

    def _draw(self, renderer):
        if self.loaded == false:
            renderer.fill_rounded_rect(self.rect, self.theme.surface, 4)
            renderer.draw_text("[img]", self.rect.x + 4, self.rect.center_y() - 7, self._font_placeholder, self.theme.text_secondary)
            return
        renderer.draw_image(self._handle, self.rect.x, self.rect.y, self.rect.w, self.rect.h)

    def handle_event(self, event):
        pass

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Panel (container) ────────────────────────────────────────────────────────

class Panel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.theme = Theme()
        self.visible = true
        self.shadow = true
        self.radius = 12
        self.border = false
        self.children = []
        self.child_count = 0
        self.parent = none
        self.id = ""

    def add(self, widget):
        widget.parent = self
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def _draw(self, renderer):
        if self.shadow:
            renderer.draw_shadow(self.rect, 8, 0, 4, Color(0,0,0,80))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, self.radius)
        if self.border:
            renderer.draw_rounded_rect(self.rect, self.theme.border, self.radius, 1)

    def handle_event(self, event):
        if self.visible == false:
            return
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1

    def draw(self, renderer):
        if self.visible == false:
            return
        self._draw(renderer)
        var i = 0
        while i < self.child_count:
            self.children[i].draw(renderer)
            i = i + 1

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Layouts ─────────────────────────────────────────────────────────────────

class VBox:
    def __init__(self, x, y, w, spacing):
        self.x = x
        self.y = y
        self.w = w
        self.spacing = spacing
        self.widgets = []
        self.count = 0
        self._cursor_y = y

    def add(self, widget):
        widget.set_pos(self.x, self._cursor_y)
        widget.set_size(self.w, widget.rect.h)
        self.widgets.append(widget)
        self.count = self.count + 1
        self._cursor_y = self._cursor_y + widget.rect.h + self.spacing
        return self

    def total_height(self):
        return self._cursor_y - self.y

    def handle_event(self, event):
        var i = 0
        while i < self.count:
            self.widgets[i].handle_event(event)
            i = i + 1

    def draw(self, renderer):
        var i = 0
        while i < self.count:
            self.widgets[i].draw(renderer)
            i = i + 1

class HBox:
    def __init__(self, x, y, h, spacing):
        self.x = x
        self.y = y
        self.h = h
        self.spacing = spacing
        self.widgets = []
        self.count = 0
        self._cursor_x = x

    def add(self, widget):
        widget.set_pos(self._cursor_x, self.y)
        widget.set_size(widget.rect.w, self.h)
        self.widgets.append(widget)
        self.count = self.count + 1
        self._cursor_x = self._cursor_x + widget.rect.w + self.spacing
        return self

    def total_width(self):
        return self._cursor_x - self.x

    def handle_event(self, event):
        var i = 0
        while i < self.count:
            self.widgets[i].handle_event(event)
            i = i + 1

    def draw(self, renderer):
        var i = 0
        while i < self.count:
            self.widgets[i].draw(renderer)
            i = i + 1

class GridLayout:
    def __init__(self, x, y, cols, col_w, col_h, gap):
        self.x = x
        self.y = y
        self.cols = cols
        self.col_w = col_w
        self.col_h = col_h
        self.gap = gap
        self.widgets = []
        self.count = 0

    def add(self, widget):
        var col = self.count % self.cols
        var row = int(self.count / self.cols)
        var wx = self.x + col * (self.col_w + self.gap)
        var wy = self.y + row * (self.col_h + self.gap)
        widget.set_pos(wx, wy)
        widget.set_size(self.col_w, self.col_h)
        self.widgets.append(widget)
        self.count = self.count + 1
        return self

    def clear(self):
        self.widgets = []
        self.count = 0
        return self

    def set_pos(self, x, y):
        var dx = x - self.x
        var dy = y - self.y
        self.x = x
        self.y = y
        var i = 0
        while i < self.count:
            var wx = self.widgets[i].rect.x + dx
            var wy = self.widgets[i].rect.y + dy
            self.widgets[i].set_pos(wx, wy)
            i = i + 1
        return self

    def total_height(self):
        var rows = int((self.count + self.cols - 1) / self.cols)
        return rows * (self.col_h + self.gap) - self.gap

    def total_width(self):
        return self.cols * (self.col_w + self.gap) - self.gap

    def handle_event(self, event):
        var i = 0
        while i < self.count:
            self.widgets[i].handle_event(event)
            i = i + 1

    def draw(self, renderer):
        var i = 0
        while i < self.count:
            self.widgets[i].draw(renderer)
            i = i + 1

# ─── Modal / Dialog ───────────────────────────────────────────────────────────

class Modal:
    def __init__(self, w, h, title):
        self.w = w
        self.h = h
        self.title = title
        self.visible = false
        self.theme = Theme()
        self._on_close = none
        self.content = none
        self._close_btn = none
        self._font_title = Font("sans-serif", 16, true, false)
        self._font_close = Font("sans-serif", 14, true, false)

    def show(self, window_w, window_h):
        var x = int((window_w - self.w) / 2)
        var y = int((window_h - self.h) / 2)
        self.rect = Rect(x, y, self.w, self.h)
        self.visible = true
        return self

    def hide(self):
        self.visible = false

    def on_close(self, fn):
        self._on_close = fn

    def _draw(self, renderer):
        var overlay = Color(0, 0, 0, 150)
        renderer.fill_rect(Rect(0, 0, 9999, 9999), overlay)
        renderer.draw_shadow(self.rect, 20, 0, 8, Color(0,0,0,150))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 16)
        var title_rect = Rect(self.rect.x, self.rect.y, self.rect.w, 50)
        renderer.fill_rounded_rect(title_rect, self.theme.bg, 16)
        renderer.draw_text(self.title, self.rect.x + 20, self.rect.y + 14, self._font_title, self.theme.text)
        var close_x = self.rect.right() - 36
        var close_y = self.rect.y + 10
        var close_rect = Rect(close_x, close_y, 28, 28)
        renderer.fill_circle(close_x + 14, close_y + 14, 14, Color(255,80,80,200))
        renderer.draw_text("x", close_x + 8, close_y + 6, self._font_close, Color(255,255,255,255))

    def handle_event(self, event):
        if self.visible == false:
            return
        var close_rect = Rect(self.rect.right() - 36, self.rect.y + 10, 28, 28)
        if event.type == "mousedown" and close_rect.contains(event.x, event.y):
            self.hide()
            if self._on_close != none:
                self._on_close()

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)
            if self.content != none:
                self.content.draw(renderer)

# ─── Toast Notification ───────────────────────────────────────────────────────

class Toast:
    def __init__(self, message, type_name, duration_ms):
        self.message = message
        self.type = type_name
        self.duration_ms = duration_ms
        self.created_at = time_ms()
        self.visible = true
        self.x = 0
        self.y = 0
        self.w = 320
        self.h = 56
        self.theme = Theme()
        self._font = Font("sans-serif", 13, false, false)

    def is_expired(self):
        return time_ms() - self.created_at > self.duration_ms

    def _get_color(self):
        if self.type == "success": return self.theme.success
        if self.type == "error": return self.theme.danger
        if self.type == "warning": return self.theme.warning
        return self.theme.info

    def _draw(self, renderer):
        var rect = Rect(self.x, self.y, self.w, self.h)
        renderer.draw_shadow(rect, 8, 0, 4, Color(0,0,0,100))
        renderer.fill_rounded_rect(rect, self.theme.surface, 10)
        var indicator = Rect(self.x, self.y, 4, self.h)
        renderer.fill_rounded_rect(indicator, self._get_color(), 2)
        renderer.draw_text(self.message, self.x + 16, self.y + 18, self._font, self.theme.text)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

class ToastManager:
    def __init__(self, window_w):
        self.window_w = window_w
        self.toasts = []
        self.count = 0
        self.margin = 16
        self.spacing = 8

    def show(self, message, type_name, duration_ms):
        var t = Toast(message, type_name, duration_ms)
        t.x = self.window_w - t.w - self.margin
        t.y = self.margin + self.count * (t.h + self.spacing)
        self.toasts.append(t)
        self.count = self.count + 1

    def success(self, msg):
        self.show(msg, "success", 3000)

    def error(self, msg):
        self.show(msg, "error", 5000)

    def warning(self, msg):
        self.show(msg, "warning", 4000)

    def info(self, msg):
        self.show(msg, "info", 3000)

    def update(self):
        var new_toasts = []
        var new_count = 0
        var i = 0
        while i < self.count:
            var t = self.toasts[i]
            if t.is_expired() == false:
                t.y = self.margin + new_count * (t.h + self.spacing)
                new_toasts.append(t)
                new_count = new_count + 1
            i = i + 1
        self.toasts = new_toasts
        self.count = new_count

    def handle_event(self, event):
        pass

    def draw(self, renderer):
        self.update()
        var i = 0
        while i < self.count:
            self.toasts[i].draw(renderer)
            i = i + 1

# ─── VideoPlayer ─────────────────────────────────────────────────────────────

class VideoPlayer:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.path = ""
        self._handle = none
        self.playing = false
        self.paused = false
        self.volume = 1.0
        self.loop = false
        self.theme = Theme()
        self.visible = true
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self._font_placeholder = Font("sans-serif", 14, false, false)

    def load(self, path):
        self.path = path
        self._handle = gui_load_video(path)
        return self._handle != none

    def play(self):
        if self._handle != none:
            gui_video_play(self._handle)
            self.playing = true
            self.paused = false

    def pause(self):
        if self._handle != none:
            gui_video_pause(self._handle)
            self.paused = true

    def stop(self):
        if self._handle != none:
            gui_video_stop(self._handle)
            self.playing = false
            self.paused = false

    def seek(self, seconds):
        if self._handle != none:
            gui_video_seek(self._handle, seconds)

    def set_volume(self, vol):
        self.volume = vol
        if self._handle != none:
            gui_video_volume(self._handle, vol)

    def duration(self):
        if self._handle == none:
            return 0.0
        return gui_video_duration(self._handle)

    def current_time(self):
        if self._handle == none:
            return 0.0
        return gui_video_time(self._handle)

    def _draw(self, renderer):
        if self._handle == none:
            renderer.fill_rect(self.rect, Color(0,0,0,255))
            renderer.draw_text("No video", self.rect.center_x() - 36, self.rect.center_y() - 7, self._font_placeholder, Color(128,128,128,255))
            return
        gui_video_render(self._handle, self.rect.x, self.rect.y, self.rect.w, self.rect.h)
        if self.playing == false:
            var cx = self.rect.center_x()
            var cy = self.rect.center_y()
            renderer.fill_circle(cx, cy, 32, Color(0,0,0,140))
            var pts = []
            pts[0] = [cx - 10, cy - 18]
            pts[1] = [cx + 18, cy]
            pts[2] = [cx - 10, cy + 18]
            renderer.fill_polygon(pts, 3, Color(255,255,255,220))

    def handle_event(self, event):
        if self.visible == false:
            return
        var inside = self.rect.contains(event.x, event.y)
        if event.type == "mousedown" and inside:
            if self.playing:
                self.pause()
            else:
                self.play()

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Dropdown ─────────────────────────────────────────────────────────────────

class Dropdown:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.items = []
        self.item_count = 0
        self.selected = -1
        self.open = false
        self.hovered_item = -1
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.placeholder = "Select..."
        self.visible = true
        self.enabled = true
        self.id = ""
        self.children = []
        self.child_count = 0
        self.parent = none
        self._eh_counts = {}
        self._event_handlers = {}

    def add_item(self, label, value):
        self.items.append({"label": label, "value": value})
        self.item_count = self.item_count + 1
        return self

    def select(self, index):
        if index >= 0 and index < self.item_count:
            self.selected = index
        return self

    def select_by_value(self, value):
        var i = 0
        while i < self.item_count:
            if self.items[i]["value"] == value:
                self.selected = i
                return self
            i = i + 1
        return self

    def get_value(self):
        if self.selected < 0 or self.selected >= self.item_count:
            return none
        return self.items[self.selected]["value"]

    def get_label(self):
        if self.selected < 0 or self.selected >= self.item_count:
            return self.placeholder
        return self.items[self.selected]["label"]

    def clear_items(self):
        self.items = []
        self.item_count = 0
        self.selected = -1
        return self

    def set_placeholder(self, text):
        self.placeholder = text
        return self

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousemove":
            self.hovered_item = -1
            if self.open:
                var item_h = self.rect.h
                var i = 0
                while i < self.item_count:
                    var iy = self.rect.bottom() + i * item_h
                    if event.y >= iy and event.y < iy + item_h:
                        self.hovered_item = i
                    i = i + 1
        elif event.type == "mousedown":
            if self.rect.contains(event.x, event.y):
                self.open = not self.open
                event.consume()
            elif self.open:
                var item_h = self.rect.h
                var i = 0
                while i < self.item_count:
                    var iy = self.rect.bottom() + i * item_h
                    if event.y >= iy and event.y < iy + item_h and event.x >= self.rect.x and event.x < self.rect.right():
                        self.selected = i
                        self.open = false
                        var ev = Event("change")
                        ev.target = self
                        self.emit(ev)
                        event.consume()
                        i = self.item_count
                    else:
                        i = i + 1
                if not event.consumed:
                    self.open = false

    def _draw(self, renderer):
        var bg = self.theme.surface
        if self.hovered_item == -1 and not self.open:
            bg = self.theme.bg
        renderer.fill_rounded_rect(self.rect, bg, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, self.theme.border, self.theme.radius, 1)
        var label = self.get_label()
        var tx = self.rect.x + 12
        var ty = self.rect.y + int((self.rect.h - 14) / 2)
        renderer.draw_text(label, tx, ty, self.font, self.theme.text)
        var ax = self.rect.right() - 20
        var ay = self.rect.center_y()
        renderer.draw_text("?", ax, ay - 7, self.font, self.theme.text_secondary)
        if self.open:
            var i = 0
            while i < self.item_count:
                var ir = Rect(self.rect.x, self.rect.bottom() + i * self.rect.h, self.rect.w, self.rect.h)
                var ibg = self.theme.surface
                if i == self.hovered_item:
                    ibg = self.theme.accent
                renderer.fill_rounded_rect(ir, ibg, 4)
                renderer.draw_rounded_rect(ir, self.theme.border, 4, 1)
                var ilabel = self.items[i]["label"]
                var itx = ir.x + 12
                var ity = ir.y + int((ir.h - 14) / 2)
                var itc = self.theme.text
                if i == self.hovered_item:
                    itc = Color(255, 255, 255, 255)
                renderer.draw_text(ilabel, itx, ity, self.font, itc)
                i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def get_value(self):
        if self.selected < 0 or self.selected >= self.item_count:
            return none
        return self.items[self.selected]["value"]

    def get_label(self):
        if self.selected < 0 or self.selected >= self.item_count:
            return self.placeholder
        return self.items[self.selected]["label"]

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.theme.surface, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, self.theme.border, self.theme.radius, 1)
        var label = self.get_label()
        renderer.draw_text(label, self.rect.x + 10, self.rect.center_y() - 7, self.font, self.theme.text)
        var arrow_x = self.rect.right() - 24
        var arrow_y = self.rect.center_y()
        var pts = []
        if self.open:
            pts[0] = [arrow_x, arrow_y + 4]
            pts[1] = [arrow_x + 8, arrow_y - 4]
            pts[2] = [arrow_x + 16, arrow_y + 4]
        else:
            pts[0] = [arrow_x, arrow_y - 4]
            pts[1] = [arrow_x + 8, arrow_y + 4]
            pts[2] = [arrow_x + 16, arrow_y - 4]
        renderer.fill_polygon(pts, 3, self.theme.text_secondary)
        if self.open:
            var item_h = self.rect.h
            var list_rect = Rect(self.rect.x, self.rect.bottom(), self.rect.w, item_h * self.item_count + 8)
            renderer.draw_shadow(list_rect, 12, 0, 4, Color(0,0,0,100))
            renderer.fill_rounded_rect(list_rect, self.theme.surface, self.theme.radius)
            renderer.draw_rounded_rect(list_rect, self.theme.border, self.theme.radius, 1)
            var i = 0
            while i < self.item_count:
                var item_y = self.rect.bottom() + 4 + i * item_h
                var item_rect = Rect(self.rect.x + 4, item_y, self.rect.w - 8, item_h - 2)
                if i == self.hovered_item:
                    renderer.fill_rounded_rect(item_rect, self.theme.accent.with_alpha(60), 6)
                if i == self.selected:
                    renderer.draw_text("[OK]", self.rect.x + 8, item_y + 6, self.font, self.theme.accent)
                renderer.draw_text(self.items[i]["label"], self.rect.x + 28, item_y + 6, self.font, self.theme.text)
                i = i + 1

    def handle_event(self, event):
        if self.visible == false or self.enabled == false:
            return
        var inside = self.rect.contains(event.x, event.y)
        if event.type == "mousedown":
            if inside:
                self.open = self.open == false
            elif self.open:
                self.open = false
        if event.type == "mousemove" and self.open:
            var item_h = self.rect.h
            var i = 0
            while i < self.item_count:
                var item_y = self.rect.bottom() + 4 + i * item_h
                var item_rect = Rect(self.rect.x + 4, item_y, self.rect.w - 8, item_h - 2)
                if item_rect.contains(event.x, event.y):
                    self.hovered_item = i
                i = i + 1
        if event.type == "mousedown" and self.open:
            item_h = self.rect.h
            i = 0
            while i < self.item_count:
                item_y = self.rect.bottom() + 4 + i * item_h
                item_rect = Rect(self.rect.x + 4, item_y, self.rect.w - 8, item_h - 2)
                if item_rect.contains(event.x, event.y):
                    self.selected = i
                    self.open = false
                    var ev = Event("change")
                    ev.text = self.items[i]["label"]
                    ev.delta = i
                    self.emit(ev)
                i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Switch (Toggle) ──────────────────────────────────────────────────────────

class Switch:
    def __init__(self, x, y, label):
        self.rect = Rect(x, y, 48, 26)
        self.label = label
        self.checked = false
        self.hovered = false
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def toggle(self):
        self.checked = not self.checked
        return self

    def set_checked(self, val):
        self.checked = val
        return self

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousemove":
            self.hovered = self.rect.contains(event.x, event.y)
        elif event.type == "mousedown":
            if self.rect.contains(event.x, event.y):
                self.checked = not self.checked
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
                event.consume()

    def _draw(self, renderer):
        var track_color = self.theme.border
        if self.checked:
            track_color = self.theme.accent
        renderer.fill_rounded_rect(self.rect, track_color, 13)
        var knob_x = self.rect.x + 3
        if self.checked:
            knob_x = self.rect.right() - 23
        var knob = Rect(knob_x, self.rect.y + 3, 20, 20)
        renderer.fill_circle(knob.center_x(), knob.center_y(), 10, Color(255, 255, 255, 255))
        if self.label != "":
            var tx = self.rect.right() + 8
            var ty = self.rect.y + int((self.rect.h - 14) / 2)
            renderer.draw_text(self.label, tx, ty, self.font, self.theme.text)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── RadioButton / RadioGroup ─────────────────────────────────────────────────

class RadioButton:
    def __init__(self, x, y, label, group_name, value):
        self.rect = Rect(x, y, 20, 20)
        self.label = label
        self.group_name = group_name
        self.value = value
        self.selected = false
        self.hovered = false
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def set_selected(self, val):
        self.selected = val
        return self

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousemove":
            self.hovered = self.rect.contains(event.x, event.y)
        elif event.type == "mousedown":
            if self.rect.contains(event.x, event.y):
                self.selected = true
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
                event.consume()

    def _draw(self, renderer):
        var border = self.theme.border
        if self.selected:
            border = self.theme.accent
        renderer.draw_circle(self.rect.center_x(), self.rect.center_y(), 9, border)
        if self.selected:
            renderer.fill_circle(self.rect.center_x(), self.rect.center_y(), 5, self.theme.accent)
        if self.label != "":
            var tx = self.rect.right() + 8
            var ty = self.rect.y + int((self.rect.h - 14) / 2)
            renderer.draw_text(self.label, tx, ty, self.font, self.theme.text)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self


class RadioGroup:
    def __init__(self, group_name):
        self.group_name = group_name
        self.buttons = []
        self.count = 0
        self.selected_value = none
        self._on_change = none

    def add(self, radio_btn):
        radio_btn.group_name = self.group_name
        self.buttons.append(radio_btn)
        self.count = self.count + 1
        return self

    def select(self, value):
        self.selected_value = value
        var i = 0
        while i < self.count:
            self.buttons[i].selected = (self.buttons[i].value == value)
            i = i + 1
        return self

    def get_value(self):
        return self.selected_value

    def on_change(self, fn):
        self._on_change = fn
        return self

    def handle_event(self, event):
        var i = 0
        while i < self.count:
            var prev = self.buttons[i].selected
            self.buttons[i].handle_event(event)
            if self.buttons[i].selected and not prev:
                var j = 0
                while j < self.count:
                    if j != i:
                        self.buttons[j].selected = false
                    j = j + 1
                self.selected_value = self.buttons[i].value
                if self._on_change != none:
                    self._on_change(self.selected_value)
            i = i + 1

    def draw(self, renderer):
        var i = 0
        while i < self.count:
            self.buttons[i].draw(renderer)
            i = i + 1

# ─── NumberInput ──────────────────────────────────────────────────────────────

class NumberInput:
    def __init__(self, x, y, w, h, min_val, max_val, step):
        self.rect = Rect(x, y, w, h)
        self.min_val = min_val
        self.max_val = max_val
        self.step = step
        self.value = min_val
        self.hovered = false
        self.focused = false
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def set_value(self, val):
        if val < self.min_val:
            val = self.min_val
        if val > self.max_val:
            val = self.max_val
        self.value = val
        return self

    def increment(self):
        self.set_value(self.value + self.step)
        return self

    def decrement(self):
        self.set_value(self.value - self.step)
        return self

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        var btn_w = self.rect.h
        var up_rect = Rect(self.rect.right() - btn_w, self.rect.y, btn_w, int(self.rect.h / 2))
        var dn_rect = Rect(self.rect.right() - btn_w, self.rect.y + int(self.rect.h / 2), btn_w, int(self.rect.h / 2))
        if event.type == "mousemove":
            self.hovered = self.rect.contains(event.x, event.y)
        elif event.type == "mousedown":
            if up_rect.contains(event.x, event.y):
                self.increment()
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
                event.consume()
            elif dn_rect.contains(event.x, event.y):
                self.decrement()
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
                event.consume()
        elif event.type == "scroll":
            if self.rect.contains(event.x, event.y):
                if event.delta > 0:
                    self.increment()
                else:
                    self.decrement()
                var ev = Event("change")
                ev.target = self
                self.emit(ev)

    def _draw(self, renderer):
        var bg = self.theme.surface
        var border = self.theme.border
        if self.focused:
            border = self.theme.accent
        renderer.fill_rounded_rect(self.rect, bg, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, border, self.theme.radius, 1)
        var tx = self.rect.x + 10
        var ty = self.rect.y + int((self.rect.h - 14) / 2)
        renderer.draw_text(str(self.value), tx, ty, self.font, self.theme.text)
        var btn_w = self.rect.h
        var up_r = Rect(self.rect.right() - btn_w, self.rect.y, btn_w, int(self.rect.h / 2))
        var dn_r = Rect(self.rect.right() - btn_w, self.rect.y + int(self.rect.h / 2), btn_w, int(self.rect.h / 2))
        renderer.draw_rect(up_r, self.theme.border, 1)
        renderer.draw_rect(dn_r, self.theme.border, 1)
        renderer.draw_text("?", up_r.center_x() - 5, up_r.center_y() - 7, self.font, self.theme.text_secondary)
        renderer.draw_text("?", dn_r.center_x() - 5, dn_r.center_y() - 7, self.font, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── TextArea ─────────────────────────────────────────────────────────────────

class TextArea:
    def __init__(self, x, y, w, h, placeholder):
        self.rect = Rect(x, y, w, h)
        self.placeholder = placeholder
        self.value = ""
        self.focused = false
        self.hovered = false
        self.scroll_y = 0
        self.max_length = 10000
        self.line_height = 20
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.visible = true
        self.enabled = true
        self.readonly = false
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def set_value(self, text):
        self.value = text
        return self

    def append(self, text):
        if len(self.value) + len(text) <= self.max_length:
            self.value = self.value + text
        return self

    def clear(self):
        self.value = ""
        self.scroll_y = 0
        return self

    def line_count(self):
        return len(self.value.split("\n"))

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousedown":
            self.focused = self.rect.contains(event.x, event.y)
        elif event.type == "keydown" and self.focused and not self.readonly:
            if event.key == "backspace":
                if len(self.value) > 0:
                    self.value = self.value[0:len(self.value)-1]
                    var ev = Event("input")
                    ev.target = self
                    self.emit(ev)
            elif event.key == "enter":
                if len(self.value) < self.max_length:
                    self.value = self.value + "\n"
                    var ev = Event("input")
                    ev.target = self
                    self.emit(ev)
        elif event.type == "textinput" and self.focused and not self.readonly:
            if len(self.value) < self.max_length:
                self.value = self.value + event.text
                var ev = Event("input")
                ev.target = self
                self.emit(ev)
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_height
            if self.scroll_y < 0:
                self.scroll_y = 0

    def _draw(self, renderer):
        var bg = self.theme.surface
        var border = self.theme.border
        if self.focused:
            border = self.theme.accent
        renderer.fill_rounded_rect(self.rect, bg, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, border, self.theme.radius, 1)
        renderer.set_clip(Rect(self.rect.x + 2, self.rect.y + 2, self.rect.w - 4, self.rect.h - 4))
        if self.value == "":
            renderer.draw_text(self.placeholder, self.rect.x + 10, self.rect.y + 10, self.font, self.theme.text_secondary)
        else:
            var lines = self.value.split("\n")
            var i = 0
            while i < len(lines):
                var ty = self.rect.y + 10 + i * self.line_height - self.scroll_y
                if ty >= self.rect.y and ty < self.rect.bottom():
                    renderer.draw_text(lines[i], self.rect.x + 10, ty, self.font, self.theme.text)
                i = i + 1
        renderer.clear_clip()

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── Badge ────────────────────────────────────────────────────────────────────

class Badge:
    def __init__(self, text, variant):
        self.text = text
        self.variant = variant
        self.x = 0
        self.y = 0
        self.visible = true
        self.theme = Theme()
        self.font = Font("sans-serif", 11, true, false)

    def _get_color(self):
        if self.variant == "success":
            return self.theme.success
        if self.variant == "warning":
            return self.theme.warning
        if self.variant == "danger":
            return self.theme.danger
        if self.variant == "info":
            return self.theme.info
        return self.theme.accent

    def set_text(self, text):
        self.text = text
        return self

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def _draw(self, renderer):
        var color = self._get_color()
        var pad_x = 8
        var pad_y = 3
        var w = len(self.text) * 7 + pad_x * 2
        var h = 20
        var r = Rect(self.x, self.y, w, h)
        renderer.fill_rounded_rect(r, color, 10)
        renderer.draw_text(self.text, self.x + pad_x, self.y + pad_y, self.font, Color(255, 255, 255, 255))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Divider ──────────────────────────────────────────────────────────────────

class Divider:
    def __init__(self, x, y, length, vertical):
        self.x = x
        self.y = y
        self.length = length
        self.vertical = vertical
        self.thickness = 1
        self.visible = true
        self.theme = Theme()
        self.label = ""
        self.font = Font("sans-serif", 12, false, false)

    def set_label(self, text):
        self.label = text
        return self

    def set_thickness(self, t):
        self.thickness = t
        return self

    def _draw(self, renderer):
        var color = self.theme.border
        if self.vertical:
            var r = Rect(self.x, self.y, self.thickness, self.length)
            renderer.fill_rect(r, color)
        else:
            if self.label != "":
                var lw = len(self.label) * 8 + 16
                var lx = self.x + int((self.length - lw) / 2)
                var seg1 = int((self.length - lw) / 2) - 8
                renderer.fill_rect(Rect(self.x, self.y, seg1, self.thickness), color)
                renderer.fill_rect(Rect(lx + lw + 4, self.y, self.length - lx - lw, self.thickness), color)
                renderer.draw_text(self.label, lx + 8, self.y - 8, self.font, self.theme.text_secondary)
            else:
                renderer.fill_rect(Rect(self.x, self.y, self.length, self.thickness), color)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Card ────────────────────────────────────────────────────────────────────

class Card:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.title = ""
        self.subtitle = ""
        self.children = []
        self.child_count = 0
        self.theme = Theme()
        self.font_title = Font("sans-serif", 16, true, false)
        self.font_sub = Font("sans-serif", 13, false, false)
        self.padding = 16
        self.shadow = true
        self.visible = true
        self.id = ""

    def set_title(self, title):
        self.title = title
        return self

    def set_subtitle(self, sub):
        self.subtitle = sub
        return self

    def add(self, widget):
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def handle_event(self, event):
        if self.visible == false:
            return
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1
            renderer.draw_shadow(shadow_r, 8, 0, 2, Color(0, 0, 0, 60))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, self.theme.border, self.theme.radius, 1)
        var cy = self.rect.y + self.padding
        if self.title != "":
            renderer.draw_text(self.title, self.rect.x + self.padding, cy, self.font_title, self.theme.text)
            cy = cy + 24
        if self.subtitle != "":
            renderer.draw_text(self.subtitle, self.rect.x + self.padding, cy, self.font_sub, self.theme.text_secondary)
            cy = cy + 20
        var i = 0
        while i < self.child_count:
            self.children[i].draw(renderer)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Tooltip ─────────────────────────────────────────────────────────────────

class Tooltip:
    def __init__(self, text):
        self.text = text
        self.x = 0
        self.y = 0
        self.visible = false
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.delay_ms = 500
        self._timer = 0
        self._target_rect = none

    def attach(self, widget_rect):
        self._target_rect = widget_rect
        return self

    def set_text(self, text):
        self.text = text
        return self

    def show_at(self, x, y):
        self.x = x
        self.y = y - 36
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def handle_event(self, event):
        if self._target_rect == none:
            return
        if event.type == "mousemove":
            if self._target_rect.contains(event.x, event.y):
                self.show_at(event.x, event.y)
            else:
                self.hide()

    def _draw(self, renderer):
        var pad = 8
        var w = len(self.text) * 7 + pad * 2
        var h = 28
        var r = Rect(self.x - int(w / 2), self.y, w, h)
        renderer.fill_rounded_rect(r, Color(30, 30, 40, 230), 6)
        renderer.draw_text(self.text, r.x + pad, r.y + 7, self.font, Color(255, 255, 255, 255))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── Tabs / TabPanel ──────────────────────────────────────────────────────────

class Tab:
    def __init__(self, label, content_widget):
        self.label = label
        self.content = content_widget
        self.badge = none


class Tabs:
    def __init__(self, x, y, w, tab_h):
        self.rect = Rect(x, y, w, tab_h)
        self.tabs = []
        self.count = 0
        self.active = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self._on_change = none
        self.id = ""

    def add(self, label, content):
        self.tabs.append(Tab(label, content))
        self.count = self.count + 1
        return self

    def select(self, index):
        if index >= 0 and index < self.count:
            self.active = index
            if self._on_change != none:
                self._on_change(index)
        return self

    def on_change(self, fn):
        self._on_change = fn
        return self

    def get_active(self):
        if self.count == 0:
            return none
        return self.tabs[self.active]

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var tab_w = int(self.rect.w / self.count)
            var i = 0
            while i < self.count:
                var tr = Rect(self.rect.x + i * tab_w, self.rect.y, tab_w, self.rect.h)
                if tr.contains(event.x, event.y):
                    self.select(i)
                    event.consume()
                    i = self.count
                else:
                    i = i + 1
        if self.count > 0:
            self.tabs[self.active].content.handle_event(event)

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.theme.bg)
        var tab_w = int(self.rect.w / self.count)
        var i = 0
        while i < self.count:
            var tr = Rect(self.rect.x + i * tab_w, self.rect.y, tab_w, self.rect.h)
            var is_active = (i == self.active)
            var bg = self.theme.surface if is_active else self.theme.bg
            renderer.fill_rect(tr, bg)
            var tc = self.theme.text if is_active else self.theme.text_secondary
            var tx = tr.center_x() - int(len(self.tabs[i].label) * 4)
            var ty = tr.center_y() - 7
            renderer.draw_text(self.tabs[i].label, tx, ty, self.font, tc)
            if is_active:
                var indicator = Rect(tr.x + 4, tr.bottom() - 3, tr.w - 8, 3)
                renderer.fill_rect(indicator, self.theme.accent)
            i = i + 1
        if self.count > 0:
            self.tabs[self.active].content.draw(renderer)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ScrollPanel ──────────────────────────────────────────────────────────────

class ScrollPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.scroll_x = 0
        self.scroll_y = 0
        self.content_w = w
        self.content_h = h
        self.children = []
        self.child_count = 0
        self.theme = Theme()
        self.show_scrollbar_x = true
        self.show_scrollbar_y = true
        self.visible = true
        self.id = ""
        self._scrollbar_w = 8

    def add(self, widget):
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def set_content_size(self, w, h):
        self.content_w = w
        self.content_h = h
        return self

    def scroll_to(self, x, y):
        self.scroll_x = x
        self.scroll_y = y
        self._clamp_scroll()
        return self

    def _clamp_scroll(self):
        if self.scroll_x < 0:
            self.scroll_x = 0
        if self.scroll_y < 0:
            self.scroll_y = 0
        var max_x = self.content_w - self.rect.w
        var max_y = self.content_h - self.rect.h
        if max_x < 0:
            max_x = 0
        if max_y < 0:
            max_y = 0
        if self.scroll_x > max_x:
            self.scroll_x = max_x
        if self.scroll_y > max_y:
            self.scroll_y = max_y

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * 30
            self._clamp_scroll()
            event.consume()
        # Forward to children with scroll-adjusted coordinates
        var orig_x = event.x
        var orig_y = event.y
        event.x = event.x + self.scroll_x
        event.y = event.y + self.scroll_y
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1
        event.x = orig_x
        event.y = orig_y

    def _draw(self, renderer):
        # Set viewport to the scroll panel's rect  -  this both clips AND shifts
        # the coordinate origin, so children at position (0,0) draw at (rect.x, rect.y)
        # and the scroll_y offset shifts them up correctly.
        # We save and restore by using set_viewport with scroll offset.
        var vp = Rect(self.rect.x, self.rect.y, self.rect.w, self.rect.h)
        renderer.set_clip(vp)
        # Temporarily shift each child by -scroll_y so they appear at the right position
        var i = 0
        while i < self.child_count:
            var child = self.children[i]
            var orig_y = child.rect.y
            var orig_x = child.rect.x
            child.rect.y = orig_y - self.scroll_y
            child.rect.x = orig_x - self.scroll_x
            child.draw(renderer)
            child.rect.y = orig_y
            child.rect.x = orig_x
            i = i + 1
        renderer.clear_clip()
        # Draw scrollbar
        if self.show_scrollbar_y and self.content_h > self.rect.h:
            var track = Rect(self.rect.right() - self._scrollbar_w, self.rect.y, self._scrollbar_w, self.rect.h)
            renderer.fill_rect(track, Color(40, 40, 50, 180))
            var thumb_h = int(self.rect.h * self.rect.h / self.content_h)
            if thumb_h < 20:
                thumb_h = 20
            var thumb_y = self.rect.y + int(self.scroll_y * (self.rect.h - thumb_h) / (self.content_h - self.rect.h))
            var thumb = Rect(track.x + 1, thumb_y, self._scrollbar_w - 2, thumb_h)
            renderer.fill_rounded_rect(thumb, Color(120, 120, 140, 200), 4)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Spinner (Loading Indicator) ──────────────────────────────────────────────

class Spinner:
    def __init__(self, x, y, size, variant):
        self.x = x
        self.y = y
        self.size = size
        self.variant = variant
        self.angle = 0.0
        self.speed = 6.0
        self.visible = true
        self.theme = Theme()
        self.label = ""
        self.font = Font("sans-serif", 13, false, false)

    def _get_color(self):
        if self.variant == "primary":
            return self.theme.accent
        if self.variant == "success":
            return self.theme.success
        if self.variant == "danger":
            return self.theme.danger
        if self.variant == "white":
            return Color(255, 255, 255, 255)
        return self.theme.accent

    def update(self):
        self.angle = (self.angle + self.speed) % 360.0

    def set_label(self, text):
        self.label = text
        return self

    def _draw(self, renderer):
        var cx = self.x + int(self.size / 2)
        var cy = self.y + int(self.size / 2)
        var r = int(self.size / 2) - 2
        var color = self._get_color()
        renderer.draw_circle(cx, cy, r, Color(color.r, color.g, color.b, 40))
        renderer.draw_arc(cx, cy, r, int(self.angle), int(self.angle) + 90, color, 3)
        if self.label != "":
            var tx = self.x + self.size + 10
            var ty = cy - 7
            renderer.draw_text(self.label, tx, ty, self.font, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ContextMenu ──────────────────────────────────────────────────────────────

class ContextMenuItem:
    def __init__(self, label, action, shortcut):
        self.label = label
        self.action = action
        self.shortcut = shortcut
        self.separator = false
        self.enabled = true
        self.icon = ""


class ContextMenu:
    def __init__(self):
        self.items = []
        self.count = 0
        self.x = 0
        self.y = 0
        self.visible = false
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_shortcut = Font("sans-serif", 11, false, false)
        self.item_h = 32
        self.min_w = 180
        self.hovered = -1

    def add_item(self, label, action):
        var item = ContextMenuItem(label, action, "")
        self.items.append(item)
        self.count = self.count + 1
        return self

    def add_item_with_shortcut(self, label, action, shortcut):
        var item = ContextMenuItem(label, action, shortcut)
        self.items.append(item)
        self.count = self.count + 1
        return self

    def add_separator(self):
        var item = ContextMenuItem("", none, "")
        item.separator = true
        self.items.append(item)
        self.count = self.count + 1
        return self

    def show_at(self, x, y):
        self.x = x
        self.y = y
        self.visible = true
        self.hovered = -1
        return self

    def hide(self):
        self.visible = false
        return self

    def _item_rect(self, index):
        var y_off = 0
        var i = 0
        while i < index:
            if self.items[i].separator:
                y_off = y_off + 10
            else:
                y_off = y_off + self.item_h
            i = i + 1
        var w = self.min_w
        return Rect(self.x, self.y + y_off, w, self.item_h)

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            self.hovered = -1
            var i = 0
            while i < self.count:
                if not self.items[i].separator:
                    var r = self._item_rect(i)
                    if r.contains(event.x, event.y):
                        self.hovered = i
                i = i + 1
        elif event.type == "mousedown":
            var clicked = false
            var i = 0
            while i < self.count:
                if not self.items[i].separator and self.items[i].enabled:
                    var r = self._item_rect(i)
                    if r.contains(event.x, event.y):
                        if self.items[i].action != none:
                            self.items[i].action()
                        self.hide()
                        event.consume()
                        clicked = true
                        i = self.count
                i = i + 1
            if not clicked:
                self.hide()
        elif event.type == "keydown":
            if event.key == "escape":
                self.hide()

    def _draw(self, renderer):
        var total_h = 0
        var i = 0
        while i < self.count:
            if self.items[i].separator:
                total_h = total_h + 10
            else:
                total_h = total_h + self.item_h
            i = i + 1
        var bg_rect = Rect(self.x, self.y, self.min_w, total_h)
        renderer.draw_shadow(bg_rect, 12, 2, 4, Color(0, 0, 0, 80))
        renderer.fill_rounded_rect(bg_rect, self.theme.surface, self.theme.radius)
        renderer.draw_rounded_rect(bg_rect, self.theme.border, self.theme.radius, 1)
        var y_off = 0
        i = 0
        while i < self.count:
            var item = self.items[i]
            if item.separator:
                var sep_y = self.y + y_off + 5
                renderer.fill_rect(Rect(self.x + 8, sep_y, self.min_w - 16, 1), self.theme.border)
                y_off = y_off + 10
            else:
                var ir = Rect(self.x, self.y + y_off, self.min_w, self.item_h)
                if i == self.hovered and item.enabled:
                    renderer.fill_rounded_rect(ir, self.theme.accent, 4)
                var tc = self.theme.text
                if i == self.hovered and item.enabled:
                    tc = Color(255, 255, 255, 255)
                if not item.enabled:
                    tc = self.theme.text_secondary
                renderer.draw_text(item.label, ir.x + 12, ir.y + int((ir.h - 14) / 2), self.font, tc)
                if item.shortcut != "":
                    var sw = len(item.shortcut) * 7
                    renderer.draw_text(item.shortcut, ir.right() - sw - 12, ir.y + int((ir.h - 12) / 2), self.font_shortcut, self.theme.text_secondary)
                y_off = y_off + self.item_h
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── Form ────────────────────────────────────────────────────────────────────

class FormField:
    def __init__(self, name, label, widget):
        self.name = name
        self.label = label
        self.widget = widget
        self.required = false
        self.error = ""
        self.validator = none


class Form:
    def __init__(self, x, y, w):
        self.x = x
        self.y = y
        self.w = w
        self.fields = []
        self.field_count = 0
        self.field_gap = 16
        self.label_h = 20
        self.theme = Theme()
        self.font_label = Font("sans-serif", 13, false, false)
        self.font_error = Font("sans-serif", 12, false, false)
        self.visible = true
        self._on_submit = none

    def add_field(self, name, label, widget):
        var f = FormField(name, label, widget)
        self.fields.append(f)
        self.field_count = self.field_count + 1
        var widget_h = widget.rect.h
        var y_off = self.field_count * (widget_h + self.label_h + self.field_gap)
        widget.set_pos(self.x, self.y + y_off)
        widget.set_size(self.w, widget_h)
        return self

    def set_required(self, name):
        var i = 0
        while i < self.field_count:
            if self.fields[i].name == name:
                self.fields[i].required = true
            i = i + 1
        return self

    def set_validator(self, name, validator_fn):
        var i = 0
        while i < self.field_count:
            if self.fields[i].name == name:
                self.fields[i].validator = validator_fn
            i = i + 1
        return self

    def get_value(self, name):
        var i = 0
        while i < self.field_count:
            if self.fields[i].name == name:
                return self.fields[i].widget.value
            i = i + 1
        return none

    def get_values(self):
        var data = {}
        var i = 0
        while i < self.field_count:
            var f = self.fields[i]
            data[f.name] = f.widget.value
            i = i + 1
        return data

    def validate(self):
        var valid = true
        var i = 0
        while i < self.field_count:
            var f = self.fields[i]
            f.error = ""
            if f.required and len(str(f.widget.value)) == 0:
                f.error = f.label + " is required"
                valid = false
            elif f.validator != none:
                var err = f.validator(f.widget.value)
                if err != none and err != "":
                    f.error = err
                    valid = false
            i = i + 1
        return valid

    def on_submit(self, fn):
        self._on_submit = fn
        return self

    def submit(self):
        if self.validate():
            if self._on_submit != none:
                self._on_submit(self.get_values())
            return true
        return false

    def reset(self):
        var i = 0
        while i < self.field_count:
            self.fields[i].widget.value = ""
            self.fields[i].error = ""
            i = i + 1
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        var i = 0
        while i < self.field_count:
            self.fields[i].widget.handle_event(event)
            i = i + 1

    def _draw(self, renderer):
        var i = 0
        while i < self.field_count:
            var f = self.fields[i]
            var lx = f.widget.rect.x
            var ly = f.widget.rect.y - self.label_h
            renderer.draw_text(f.label, lx, ly + 4, self.font_label, self.theme.text)
            if f.required:
                renderer.draw_text(" *", lx + len(f.label) * 8, ly + 4, self.font_label, self.theme.danger)
            f.widget.draw(renderer)
            if f.error != "":
                renderer.draw_text(f.error, lx, f.widget.rect.bottom() + 4, self.font_error, self.theme.danger)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── DataTable ────────────────────────────────────────────────────────────────

class DataTable:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.columns = []
        self.col_count = 0
        self.rows = []
        self.row_count = 0
        self.row_h = 36
        self.header_h = 40
        self.scroll_y = 0
        self.selected_row = -1
        self.hovered_row = -1
        self.theme = Theme()
        self.font_header = Font("sans-serif", 13, true, false)
        self.font_cell = Font("sans-serif", 13, false, false)
        self.visible = true
        self.id = ""
        self._on_select = none
        self._sort_col = -1
        self._sort_asc = true

    def add_column(self, key, label, width):
        self.columns.append({"key": key, "label": label, "width": width})
        self.col_count = self.col_count + 1
        return self

    def add_row(self, row_data):
        self.rows.append(row_data)
        self.row_count = self.row_count + 1
        return self

    def clear_rows(self):
        self.rows = []
        self.row_count = 0
        self.selected_row = -1
        return self

    def set_data(self, rows):
        self.rows = rows
        self.row_count = len(rows)
        self.selected_row = -1
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def get_selected(self):
        if self.selected_row < 0 or self.selected_row >= self.row_count:
            return none
        return self.rows[self.selected_row]

    def _row_y(self, index):
        return self.rect.y + self.header_h + index * self.row_h - self.scroll_y

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.row_h
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_scroll = self.row_count * self.row_h - (self.rect.h - self.header_h)
            if max_scroll < 0:
                max_scroll = 0
            if self.scroll_y > max_scroll:
                self.scroll_y = max_scroll
            event.consume()
        elif event.type == "mousemove":
            self.hovered_row = -1
            var i = 0
            while i < self.row_count:
                var ry = self._row_y(i)
                if event.y >= ry and event.y < ry + self.row_h and self.rect.contains(event.x, event.y):
                    self.hovered_row = i
                i = i + 1
        elif event.type == "mousedown":
            var i = 0
            while i < self.row_count:
                var ry = self._row_y(i)
                if event.y >= ry and event.y < ry + self.row_h and self.rect.contains(event.x, event.y):
                    self.selected_row = i
                    if self._on_select != none:
                        self._on_select(self.rows[i])
                    event.consume()
                    i = self.row_count
                else:
                    i = i + 1

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.theme.surface)
        renderer.draw_rect(self.rect, self.theme.border, 1)
        var header_rect = Rect(self.rect.x, self.rect.y, self.rect.w, self.header_h)
        renderer.fill_rect(header_rect, self.theme.bg)
        var cx = self.rect.x
        var i = 0
        while i < self.col_count:
            var col = self.columns[i]
            renderer.draw_text(col["label"], cx + 10, self.rect.y + int((self.header_h - 14) / 2), self.font_header, self.theme.text)
            cx = cx + col["width"]
            if i < self.col_count - 1:
                renderer.fill_rect(Rect(cx - 1, self.rect.y, 1, self.header_h), self.theme.border)
            i = i + 1
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + self.header_h - 1, self.rect.w, 1), self.theme.border)
        renderer.set_clip(Rect(self.rect.x, self.rect.y + self.header_h, self.rect.w, self.rect.h - self.header_h))
        i = 0
        while i < self.row_count:
            var ry = self._row_y(i)
            if ry + self.row_h > self.rect.y + self.header_h and ry < self.rect.bottom():
                var row_r = Rect(self.rect.x, ry, self.rect.w, self.row_h)
                if i == self.selected_row:
                    renderer.fill_rect(row_r, Color(self.theme.accent.r, self.theme.accent.g, self.theme.accent.b, 60))
                elif i == self.hovered_row:
                    renderer.fill_rect(row_r, Color(255, 255, 255, 10))
                elif i % 2 == 1:
                    renderer.fill_rect(row_r, Color(0, 0, 0, 15))
                var row_data = self.rows[i]
                var rx = self.rect.x
                var j = 0
                while j < self.col_count:
                    var col = self.columns[j]
                    var cell_val = row_data[col["key"]]
                    if cell_val == none:
                        cell_val = ""
                    renderer.draw_text(str(cell_val), rx + 10, ry + int((self.row_h - 14) / 2), self.font_cell, self.theme.text)
                    rx = rx + col["width"]
                    j = j + 1
                renderer.fill_rect(Rect(self.rect.x, ry + self.row_h - 1, self.rect.w, 1), self.theme.border)
            i = i + 1
        renderer.clear_clip()

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Accordion ────────────────────────────────────────────────────────────────

class AccordionItem:
    def __init__(self, title, content):
        self.title = title
        self.content = content
        self.expanded = false
        self.title_h = 44


class Accordion:
    def __init__(self, x, y, w):
        self.x = x
        self.y = y
        self.w = w
        self.items = []
        self.count = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 14, false, false)
        self.visible = true
        self.allow_multiple = false
        self.id = ""

    def add(self, title, content):
        self.items.append(AccordionItem(title, content))
        self.count = self.count + 1
        return self

    def expand(self, index):
        if not self.allow_multiple:
            var i = 0
            while i < self.count:
                self.items[i].expanded = false
                i = i + 1
        if index >= 0 and index < self.count:
            self.items[index].expanded = true
        return self

    def collapse(self, index):
        if index >= 0 and index < self.count:
            self.items[index].expanded = false
        return self

    def collapse_all(self):
        var i = 0
        while i < self.count:
            self.items[i].expanded = false
            i = i + 1
        return self

    def _item_y(self, index):
        var y = self.y
        var i = 0
        while i < index:
            y = y + self.items[i].title_h
            if self.items[i].expanded:
                y = y + self.items[i].content.rect.h
            i = i + 1
        return y

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var i = 0
            while i < self.count:
                var iy = self._item_y(i)
                var title_r = Rect(self.x, iy, self.w, self.items[i].title_h)
                if title_r.contains(event.x, event.y):
                    if self.items[i].expanded:
                        self.items[i].expanded = false
                    else:
                        self.expand(i)
                    event.consume()
                    i = self.count
                else:
                    if self.items[i].expanded:
                        self.items[i].content.handle_event(event)
                    i = i + 1

    def _draw(self, renderer):
        var i = 0
        while i < self.count:
            var iy = self._item_y(i)
            var title_r = Rect(self.x, iy, self.w, self.items[i].title_h)
            renderer.fill_rect(title_r, self.theme.surface)
            renderer.draw_rect(title_r, self.theme.border, 1)
            renderer.draw_text(self.items[i].title, self.x + 16, iy + int((self.items[i].title_h - 14) / 2), self.font, self.theme.text)
            var arrow = "?" if self.items[i].expanded else ">"
            renderer.draw_text(arrow, self.x + self.w - 30, iy + int((self.items[i].title_h - 14) / 2), self.font, self.theme.text_secondary)
            if self.items[i].expanded:
                var content_y = iy + self.items[i].title_h
                self.items[i].content.set_pos(self.x, content_y)
                self.items[i].content.draw(renderer)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── RangeSlider ──────────────────────────────────────────────────────────────

class RangeSlider:
    def __init__(self, x, y, w, min_val, max_val, low, high):
        self.rect = Rect(x, y, w, 24)
        self.min_val = min_val
        self.max_val = max_val
        self.low = low
        self.high = high
        self.dragging_low = false
        self.dragging_high = false
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.show_values = true
        self.step = 1.0
        self.visible = true
        self.enabled = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            var count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def _val_to_x(self, val):
        var range_v = self.max_val - self.min_val
        if range_v == 0.0:
            return self.rect.x
        var ratio = (val - self.min_val) / range_v
        return self.rect.x + int(ratio * self.rect.w)

    def _x_to_val(self, x):
        var ratio = float(x - self.rect.x) / float(self.rect.w)
        if ratio < 0.0:
            var ratio = 0.0
        if ratio > 1.0:
            ratio = 1.0
        var val = self.min_val + ratio * (self.max_val - self.min_val)
        return float(int(val / self.step + 0.5)) * self.step

    def set_low(self, val):
        if val < self.min_val:
            var val = self.min_val
        if val > self.high:
            val = self.high
        self.low = val
        return self

    def set_high(self, val):
        if val > self.max_val:
            var val = self.max_val
        if val < self.low:
            val = self.low
        self.high = val
        return self

    def set_range(self, low, high):
        self.set_low(low)
        self.set_high(high)
        return self

    def span(self):
        return self.high - self.low

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        var cy = self.rect.center_y()
        var lx = self._val_to_x(self.low)
        var hx = self._val_to_x(self.high)
        if event.type == "mousedown":
            var dl = (event.x - lx)
            var dh = (event.x - hx)
            if dl < 0:
                dl = -dl
            if dh < 0:
                dh = -dh
            if dl < dh and dl < 12:
                self.dragging_low = true
                event.consume()
            elif dh < 12:
                self.dragging_high = true
                event.consume()
        elif event.type == "mousemove":
            if self.dragging_low:
                var nv = self._x_to_val(event.x)
                self.set_low(nv)
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
            elif self.dragging_high:
                var nv = self._x_to_val(event.x)
                self.set_high(nv)
                var ev = Event("change")
                ev.target = self
                self.emit(ev)
        elif event.type == "mouseup":
            self.dragging_low = false
            self.dragging_high = false

    def _draw(self, renderer):
        var cy = self.rect.center_y()
        var track = Rect(self.rect.x, cy - 2, self.rect.w, 4)
        renderer.fill_rounded_rect(track, self.theme.border, 2)
        var lx = self._val_to_x(self.low)
        var hx = self._val_to_x(self.high)
        var sel = Rect(lx, cy - 2, hx - lx, 4)
        renderer.fill_rounded_rect(sel, self.theme.accent, 2)
        renderer.fill_circle(lx, cy, 8, self.theme.accent)
        renderer.fill_circle(hx, cy, 8, self.theme.accent)
        renderer.draw_circle(lx, cy, 8, Color(255, 255, 255, 80))
        renderer.draw_circle(hx, cy, 8, Color(255, 255, 255, 80))
        if self.show_values:
            renderer.draw_text(str(self.low), lx - 10, self.rect.y - 18, self.font, self.theme.text_secondary)
            renderer.draw_text(str(self.high), hx - 10, self.rect.y - 18, self.font, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── TreeNode / TreeView ──────────────────────────────────────────────────────

class TreeNode:
    def __init__(self, label, value):
        self.label = label
        self.value = value
        self.children = []
        self.child_count = 0
        self.expanded = false
        self.selected = false
        self.icon = ""
        self.depth = 0
        self.parent = none

    def add_child(self, node):
        node.parent = self
        node.depth = self.depth + 1
        self.children.append(node)
        self.child_count = self.child_count + 1
        return self

    def has_children(self):
        return self.child_count > 0

    def expand(self):
        self.expanded = true
        return self

    def collapse(self):
        self.expanded = false
        return self

    def toggle(self):
        self.expanded = not self.expanded
        return self

    def find(self, value):
        if self.value == value:
            return self
        var i = 0
        while i < self.child_count:
            var result = self.children[i].find(value)
            if result != none:
                return result
            i = i + 1
        return none


class TreeView:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.roots = []
        self.root_count = 0
        self.selected = none
        self.item_h = 28
        self.indent = 20
        self.scroll_y = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._on_select = none
        self._on_expand = none

    def add_root(self, node):
        node.depth = 0
        self.roots.append(node)
        self.root_count = self.root_count + 1
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_expand(self, fn):
        self._on_expand = fn
        return self

    def find(self, value):
        var i = 0
        while i < self.root_count:
            var result = self.roots[i].find(value)
            if result != none:
                return result
            i = i + 1
        return none

    def select(self, value):
        if self.selected != none:
            self.selected.selected = false
        var node = self.find(value)
        if node != none:
            node.selected = true
            self.selected = node
        return self

    def _flat_visible(self, node, out):
        out.append(node)
        if node.expanded:
            var i = 0
            while i < node.child_count:
                out = self._flat_visible(node.children[i], out)
                i = i + 1
        return out

    def _all_visible(self):
        var result = []
        var i = 0
        while i < self.root_count:
            result = self._flat_visible(self.roots[i], result)
            i = i + 1
        return result

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h
            if self.scroll_y < 0:
                self.scroll_y = 0
            event.consume()
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var visible = self._all_visible()
            var i = 0
            while i < len(visible):
                var node = visible[i]
                var iy = self.rect.y + i * self.item_h - self.scroll_y
                var ir = Rect(self.rect.x, iy, self.rect.w, self.item_h)
                if ir.contains(event.x, event.y):
                    var indent_x = self.rect.x + node.depth * self.indent
                    if node.has_children() and event.x < indent_x + 20:
                        node.toggle()
                        if self._on_expand != none:
                            self._on_expand(node)
                    else:
                        if self.selected != none:
                            self.selected.selected = false
                        node.selected = true
                        self.selected = node
                        if self._on_select != none:
                            self._on_select(node)
                    event.consume()
                    i = len(visible)    # break out of while loop
                else:
                    i = i + 1

    def _draw(self, renderer):
        renderer.set_clip(self.rect)
        var visible = self._all_visible()
        var i = 0
        while i < len(visible):
            var node = visible[i]
            var iy = self.rect.y + i * self.item_h - self.scroll_y
            if iy + self.item_h > self.rect.y and iy < self.rect.bottom():
                var ir = Rect(self.rect.x, iy, self.rect.w, self.item_h)
                if node.selected:
                    renderer.fill_rect(ir, Color(self.theme.accent.r, self.theme.accent.g, self.theme.accent.b, 50))
                var indent_x = self.rect.x + node.depth * self.indent
                if node.has_children():
                    var arrow = "?" if node.expanded else ">"
                    renderer.draw_text(arrow, indent_x, iy + int((self.item_h - 14) / 2), self.font, self.theme.text_secondary)
                var tx = indent_x + 18
                renderer.draw_text(node.label, tx, iy + int((self.item_h - 14) / 2), self.font, self.theme.text)
            i = i + 1
        renderer.clear_clip()
        renderer.draw_rect(self.rect, self.theme.border, 1)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── TagInput ─────────────────────────────────────────────────────────────────

class TagInput:
    def __init__(self, x, y, w, h, placeholder):
        self.rect = Rect(x, y, w, h)
        self.placeholder = placeholder
        self.tags = []
        self.tag_count = 0
        self.input_value = ""
        self.focused = false
        self.hovered = false
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_small = Font("sans-serif", 12, false, false)
        self.max_tags = 20
        self.visible = true
        self.enabled = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            var count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def add_tag(self, tag):
        if tag == "" or self.tag_count >= self.max_tags:
            return false
        var i = 0
        while i < self.tag_count:
            if self.tags[i] == tag:
                return false
            i = i + 1
        self.tags.append(tag)
        self.tag_count = self.tag_count + 1
        var ev = Event("add")
        ev.target = self
        self.emit(ev)
        return true

    def remove_tag(self, tag):
        var kept = []
        var i = 0
        while i < self.tag_count:
            if self.tags[i] != tag:
                kept.append(self.tags[i])
            i = i + 1
        self.tags = kept
        self.tag_count = len(kept)
        var ev = Event("remove")
        ev.target = self
        self.emit(ev)
        return self

    def remove_last(self):
        if self.tag_count == 0:
            return self
        var last = self.tags[self.tag_count - 1]
        return self.remove_tag(last)

    def has_tag(self, tag):
        var i = 0
        while i < self.tag_count:
            if self.tags[i] == tag:
                return true
            i = i + 1
        return false

    def clear(self):
        self.tags = []
        self.tag_count = 0
        self.input_value = ""
        return self

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousedown":
            self.focused = self.rect.contains(event.x, event.y)
        elif event.type == "keydown" and self.focused:
            if event.key == "enter" or event.key == "comma":
                var tag = string_strip(self.input_value)
                if len(tag) > 0:
                    self.add_tag(tag)
                    self.input_value = ""
            elif event.key == "backspace":
                if len(self.input_value) > 0:
                    self.input_value = self.input_value[0:len(self.input_value)-1]
                else:
                    self.remove_last()
        elif event.type == "textinput" and self.focused:
            if event.text != ",":
                self.input_value = self.input_value + event.text

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.theme.surface, self.theme.radius)
        renderer.draw_rounded_rect(self.rect, self.theme.accent if self.focused else self.theme.border, self.theme.radius, 1)
        var tx = self.rect.x + 8
        var ty = self.rect.y + int((self.rect.h - 20) / 2)
        var i = 0
        while i < self.tag_count:
            var tw = len(self.tags[i]) * 7 + 16
            var tag_r = Rect(tx, ty, tw, 20)
            renderer.fill_rounded_rect(tag_r, self.theme.accent, 10)
            renderer.draw_text(self.tags[i], tx + 6, ty + 3, self.font_small, Color(255, 255, 255, 255))
            tx = tx + tw + 4
            i = i + 1
        if len(self.input_value) > 0:
            renderer.draw_text(self.input_value, tx, ty + 3, self.font, self.theme.text)
        elif self.tag_count == 0 and not self.focused:
            renderer.draw_text(self.placeholder, tx, ty + 3, self.font, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── Rating ───────────────────────────────────────────────────────────────────

class Rating:
    def __init__(self, x, y, max_stars, value):
        self.x = x
        self.y = y
        self.max_stars = max_stars
        self.value = value
        self.hovered = 0
        self.star_size = 24
        self.gap = 4
        self.half_stars = false
        self.readonly = false
        self.theme = Theme()
        self.font = Font("sans-serif", 22, false, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._on_change = none

    def set_value(self, val):
        if val < 0.0:
            var val = 0.0
        if val > float(self.max_stars):
            val = float(self.max_stars)
        self.value = val
        return self

    def on_change(self, fn):
        self._on_change = fn
        return self

    def _star_x(self, index):
        return self.x + index * (self.star_size + self.gap)

    def width(self):
        return self.max_stars * (self.star_size + self.gap)

    def handle_event(self, event):
        if not self.visible or not self.enabled or self.readonly:
            return
        if event.type == "mousemove":
            var hit = -1
            var i = 0
            while i < self.max_stars:
                var sx = self._star_x(i)
                var sr = Rect(sx, self.y, self.star_size, self.star_size)
                if sr.contains(event.x, event.y):
                    var hit = i + 1
                i = i + 1
            self.hovered = hit
        elif event.type == "mouseleave":
            self.hovered = 0
        elif event.type == "mousedown":
            var i = 0
            while i < self.max_stars:
                var sx = self._star_x(i)
                var sr = Rect(sx, self.y, self.star_size, self.star_size)
                if sr.contains(event.x, event.y):
                    self.value = float(i + 1)
                    if self._on_change != none:
                        self._on_change(self.value)
                    event.consume()
                    i = self.max_stars
                else:
                    i = i + 1

    def _draw(self, renderer):
        var display_val = float(self.hovered) if self.hovered > 0 else self.value
        var i = 0
        while i < self.max_stars:
            var sx = self._star_x(i)
            var filled = float(i + 1) <= display_val
            var star_color = self.theme.warning if filled else self.theme.border
            renderer.draw_text("*", sx, self.y, self.font, star_color)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Breadcrumb ───────────────────────────────────────────────────────────────

class Breadcrumb:
    def __init__(self, x, y, h):
        self.x = x
        self.y = y
        self.h = h
        self.items = []
        self.item_count = 0
        self.separator = "?"
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_active = Font("sans-serif", 13, true, false)
        self.visible = true
        self.id = ""
        self._on_click = none

    def add(self, label, value):
        self.items.append({"label": label, "value": value})
        self.item_count = self.item_count + 1
        return self

    def set_separator(self, sep):
        self.separator = sep
        return self

    def clear(self):
        self.items = []
        self.item_count = 0
        return self

    def on_click(self, fn):
        self._on_click = fn
        return self

    def current(self):
        if self.item_count == 0:
            return none
        return self.items[self.item_count - 1]

    def handle_event(self, event):
        if not self.visible or self._on_click == none:
            return
        if event.type == "mousedown":
            var tx = self.x
            var i = 0
            while i < self.item_count:
                var item = self.items[i]
                var lw = len(item["label"]) * 8 + 8
                var ir = Rect(tx, self.y, lw, self.h)
                if ir.contains(event.x, event.y) and i < self.item_count - 1:
                    self._on_click(item["value"])
                    event.consume()
                    i = self.item_count
                else:
                    tx = tx + lw + len(self.separator) * 8 + 8
                    i = i + 1

    def _draw(self, renderer):
        var tx = self.x
        var i = 0
        while i < self.item_count:
            var item = self.items[i]
            var is_last = (i == self.item_count - 1)
            var font = self.font_active if is_last else self.font
            var color = self.theme.text if is_last else self.theme.accent
            renderer.draw_text(item["label"], tx, self.y + int((self.h - 14) / 2), font, color)
            tx = tx + len(item["label"]) * 8 + 8
            if not is_last:
                renderer.draw_text(self.separator, tx, self.y + int((self.h - 14) / 2), self.font, self.theme.text_secondary)
                tx = tx + len(self.separator) * 8 + 8
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Avatar ───────────────────────────────────────────────────────────────────

class Avatar:
    def __init__(self, x, y, size):
        self.x = x
        self.y = y
        self.size = size
        self.name = ""
        self.image_path = ""
        self._image_handle = none
        self.color = none
        self.status = "none"
        self.theme = Theme()
        self.font = Font("sans-serif", int(size / 2.5), true, false)
        self.visible = true
        self.shape = "circle"
        self.id = ""

    def set_name(self, name):
        self.name = name
        return self

    def set_image(self, path):
        self.image_path = path
        self._image_handle = gui_load_image(path)
        return self

    def set_status(self, status):
        self.status = status
        return self

    def set_color(self, color):
        self.color = color
        return self

    def initials(self):
        if self.name == "":
            return "?"
        var parts = self.name.split(" ")
        if len(parts) == 1:
            return string_upper(self.name[0:1])
        return string_upper(parts[0][0:1]) + string_upper(parts[1][0:1])

    def _status_color(self):
        if self.status == "online":
            return self.theme.success
        if self.status == "busy":
            return self.theme.danger
        if self.status == "away":
            return self.theme.warning
        return none

    def _draw(self, renderer):
        var cx = self.x + int(self.size / 2)
        var cy = self.y + int(self.size / 2)
        var r = int(self.size / 2)
        var bg = self.color
        if bg == none:
            var bg = self.theme.accent
        if self._image_handle != none:
            renderer.fill_circle(cx, cy, r, bg)
            renderer.draw_image(self._image_handle, self.x, self.y, self.size, self.size)
        else:
            renderer.fill_circle(cx, cy, r, bg)
            var init = self.initials()
            var fw = len(init) * 7
            renderer.draw_text(init, cx - int(fw / 2), cy - int(self.size / 8), self.font, Color(255, 255, 255, 255))
        var sc = self._status_color()
        if sc != none:
            var sr = int(self.size / 5)
            renderer.fill_circle(cx + r - sr, cy + r - sr, sr, sc)
            renderer.draw_circle(cx + r - sr, cy + r - sr, sr, Color(0, 0, 0, 60))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ProgressRing ─────────────────────────────────────────────────────────────

class ProgressRing:
    def __init__(self, x, y, size, value, max_value):
        self.x = x
        self.y = y
        self.size = size
        self.value = value
        self.max_value = max_value
        self.thickness = 8
        self.show_label = true
        self.label = ""
        self.theme = Theme()
        self.font = Font("sans-serif", int(size / 5), true, false)
        self.font_sub = Font("sans-serif", int(size / 8), false, false)
        self.color = none
        self.track_color = none
        self.visible = true
        self.id = ""

    def set_value(self, val):
        if val < 0.0:
            var val = 0.0
        if val > float(self.max_value):
            val = float(self.max_value)
        self.value = val
        return self

    def percent(self):
        if self.max_value == 0:
            return 0.0
        return float(self.value) / float(self.max_value) * 100.0

    def set_label(self, text):
        self.label = text
        return self

    def _draw(self, renderer):
        var cx = self.x + int(self.size / 2)
        var cy = self.y + int(self.size / 2)
        var r = int(self.size / 2) - self.thickness
        var track = self.track_color
        if track == none:
            var track = Color(self.theme.border.r, self.theme.border.g, self.theme.border.b, 80)
        renderer.draw_circle(cx, cy, r, track)
        var fill_color = self.color
        if fill_color == none:
            var fill_color = self.theme.accent
        var pct = self.percent()
        var sweep = int(pct * 360.0 / 100.0)
        renderer.draw_arc(cx, cy, r, -90, -90 + sweep, fill_color, self.thickness)
        if self.show_label:
            var pct_str = str(int(pct)) + "%"
            var pw = len(pct_str) * 8
            renderer.draw_text(pct_str, cx - int(pw / 2), cy - 10, self.font, self.theme.text)
            if self.label != "":
                var lw = len(self.label) * 6
                renderer.draw_text(self.label, cx - int(lw / 2), cy + 6, self.font_sub, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Pagination ───────────────────────────────────────────────────────────────

class Pagination:
    def __init__(self, x, y, total_pages):
        self.x = x
        self.y = y
        self.total_pages = total_pages
        self.current_page = 1
        self.btn_w = 36
        self.btn_h = 36
        self.gap = 4
        self.max_visible = 7
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.visible = true
        self.id = ""
        self._on_change = none

    def on_change(self, fn):
        self._on_change = fn
        return self

    def go_to(self, page):
        if page < 1:
            var page = 1
        if page > self.total_pages:
            page = self.total_pages
        var changed = (page != self.current_page)
        self.current_page = page
        if changed and self._on_change != none:
            self._on_change(page)
        return self

    def next(self):
        return self.go_to(self.current_page + 1)

    def prev(self):
        return self.go_to(self.current_page - 1)

    def first(self):
        return self.go_to(1)

    def last(self):
        return self.go_to(self.total_pages)

    def has_next(self):
        return self.current_page < self.total_pages

    def has_prev(self):
        return self.current_page > 1

    def set_total(self, total):
        self.total_pages = total
        if self.current_page > total:
            self.current_page = total
        return self

    def _btn_rect(self, index):
        return Rect(self.x + index * (self.btn_w + self.gap), self.y, self.btn_w, self.btn_h)

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var buttons = self._get_buttons()
            var i = 0
            while i < len(buttons):
                var br = self._btn_rect(i)
                if br.contains(event.x, event.y):
                    var btn = buttons[i]
                    if btn["page"] > 0:
                        self.go_to(btn["page"])
                        event.consume()
                    i = len(buttons)
                else:
                    i = i + 1

    def _get_buttons(self):
        var btns = []
        btns.append({"label": "?", "page": self.current_page - 1 if self.has_prev() else 0})
        if self.total_pages <= self.max_visible:
            var i = 1
            while i <= self.total_pages:
                btns.append({"label": str(i), "page": i})
                i = i + 1
        else:
            btns.append({"label": "1", "page": 1})
            if self.current_page > 3:
                btns.append({"label": "...", "page": 0})
            var start = self.current_page - 1
            var end = self.current_page + 1
            if start < 2:
                var start = 2
            if end > self.total_pages - 1:
                var end = self.total_pages - 1
            var p = start
            while p <= end:
                btns.append({"label": str(p), "page": p})
                p = p + 1
            if self.current_page < self.total_pages - 2:
                btns.append({"label": "...", "page": 0})
            btns.append({"label": str(self.total_pages), "page": self.total_pages})
        btns.append({"label": "?", "page": self.current_page + 1 if self.has_next() else 0})
        return btns

    def _draw(self, renderer):
        var buttons = self._get_buttons()
        var i = 0
        while i < len(buttons):
            var btn = buttons[i]
            var br = self._btn_rect(i)
            var is_current = (btn["page"] == self.current_page)
            var is_disabled = (btn["page"] == 0)
            var bg = self.theme.accent if is_current else self.theme.surface
            renderer.fill_rounded_rect(br, bg, 6)
            renderer.draw_rounded_rect(br, self.theme.border, 6, 1)
            var tc = Color(255, 255, 255, 255) if is_current else (self.theme.text_secondary if is_disabled else self.theme.text)
            var lw = len(btn["label"]) * 7
            renderer.draw_text(btn["label"], br.center_x() - int(lw / 2), br.center_y() - 7, self.font, tc)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Stepper ──────────────────────────────────────────────────────────────────

class StepperStep:
    def __init__(self, label, description):
        self.label = label
        self.description = description
        self.completed = false
        self.error = false
        self.optional = false


class Stepper:
    def __init__(self, x, y, w, h, orientation):
        self.rect = Rect(x, y, w, h)
        self.orientation = orientation
        self.steps = []
        self.step_count = 0
        self.current = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_sub = Font("sans-serif", 11, false, false)
        self.visible = true
        self.id = ""
        self._on_change = none

    def add_step(self, label, description):
        self.steps.append(StepperStep(label, description))
        self.step_count = self.step_count + 1
        return self

    def on_change(self, fn):
        self._on_change = fn
        return self

    def go_to(self, index):
        if index >= 0 and index < self.step_count:
            self.current = index
            if self._on_change != none:
                self._on_change(index)
        return self

    def next_step(self):
        if self.current < self.step_count - 1:
            self.steps[self.current].completed = true
            self.go_to(self.current + 1)
        return self

    def prev_step(self):
        return self.go_to(self.current - 1)

    def complete_step(self, index):
        if index >= 0 and index < self.step_count:
            self.steps[index].completed = true
        return self

    def set_error(self, index):
        if index >= 0 and index < self.step_count:
            self.steps[index].error = true
        return self

    def is_complete(self):
        var i = 0
        while i < self.step_count:
            if not self.steps[i].completed:
                return false
            i = i + 1
        return true

    def reset(self):
        self.current = 0
        var i = 0
        while i < self.step_count:
            self.steps[i].completed = false
            self.steps[i].error = false
            i = i + 1
        return self

    def _draw(self, renderer):
        var step_w = int(self.rect.w / self.step_count)
        var i = 0
        while i < self.step_count:
            var step = self.steps[i]
            var is_current = (i == self.current)
            var sx = self.rect.x + i * step_w + int(step_w / 2)
            var sy = self.rect.y + 20
            var circle_color = self.theme.accent if is_current else (self.theme.success if step.completed else (self.theme.danger if step.error else self.theme.border))
            renderer.fill_circle(sx, sy, 14, circle_color)
            var num = str(i + 1) if not step.completed else "[OK]"
            renderer.draw_text(num, sx - 4, sy - 7, self.font, Color(255, 255, 255, 255))
            renderer.draw_text(step.label, sx - int(len(step.label) * 4), sy + 20, self.font, self.theme.text if is_current else self.theme.text_secondary)
            if i < self.step_count - 1:
                var line_x = sx + 14
                var line_end = self.rect.x + (i + 1) * step_w + int(step_w / 2) - 14
                var line_color = self.theme.accent if step.completed else self.theme.border
                renderer.fill_rect(Rect(line_x, sy - 1, line_end - line_x, 2), line_color)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Drawer ───────────────────────────────────────────────────────────────────

class Drawer:
    def __init__(self, side, w, window_w, window_h):
        self.side = side
        self.w = w
        self.window_w = window_w
        self.window_h = window_h
        self.open = false
        self.overlay = true
        self.title = ""
        self.children = []
        self.child_count = 0
        self.theme = Theme()
        self.font_title = Font("sans-serif", 16, true, false)
        self.visible = true
        self.id = ""
        self._on_close = none
        self._anim = 0.0
        self._anim_speed = 0.15

    def set_title(self, title):
        self.title = title
        return self

    def add(self, widget):
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def on_close(self, fn):
        self._on_close = fn
        return self

    def show(self):
        self.open = true
        self.visible = true
        return self

    def hide(self):
        self.open = false
        if self._on_close != none:
            self._on_close()
        return self

    def toggle(self):
        if self.open:
            self.hide()
        else:
            self.show()
        return self

    def _rect(self):
        if self.side == "left":
            return Rect(0, 0, self.w, self.window_h)
        if self.side == "right":
            return Rect(self.window_w - self.w, 0, self.w, self.window_h)
        if self.side == "bottom":
            return Rect(0, self.window_h - self.w, self.window_w, self.w)
        return Rect(0, 0, self.window_w, self.w)

    def handle_event(self, event):
        if not self.open:
            return
        if event.type == "mousedown" and self.overlay:
            var dr = self._rect()
            if not dr.contains(event.x, event.y):
                self.hide()
                event.consume()
        if event.type == "keydown" and event.key == "escape":
            self.hide()
            event.consume()
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1

    def _draw(self, renderer):
        if not self.open:
            return
        var dr = self._rect()
        if self.overlay:
            renderer.fill_rect(Rect(0, 0, self.window_w, self.window_h), Color(0, 0, 0, 120))
        renderer.draw_shadow(dr, 16, 0, 0, Color(0, 0, 0, 80))
        renderer.fill_rect(dr, self.theme.surface)
        if self.title != "":
            var title_r = Rect(dr.x, dr.y, dr.w, 56)
            renderer.fill_rect(title_r, self.theme.bg)
            renderer.draw_text(self.title, dr.x + 20, dr.y + 18, self.font_title, self.theme.text)
            renderer.draw_text("?", dr.right() - 36, dr.y + 18, self.font_title, self.theme.text_secondary)
        var i = 0
        while i < self.child_count:
            self.children[i].draw(renderer)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── MenuBar / MenuItem ───────────────────────────────────────────────────────

class MenuItem:
    def __init__(self, label, action):
        self.label = label
        self.action = action
        self.shortcut = ""
        self.enabled = true
        self.separator = false
        self.submenu = none
        self.icon = ""

    def set_shortcut(self, key):
        self.shortcut = key
        return self

    def disable(self):
        self.enabled = false
        return self

    def enable(self):
        self.enabled = true
        return self


class Menu:
    def __init__(self, label):
        self.label = label
        self.items = []
        self.item_count = 0
        self.open = false
        self.hovered = -1

    def add(self, label, action):
        self.items.append(MenuItem(label, action))
        self.item_count = self.item_count + 1
        return self

    def add_separator(self):
        var item = MenuItem("", none)
        item.separator = true
        self.items.append(item)
        self.item_count = self.item_count + 1
        return self

    def add_item(self, item):
        self.items.append(item)
        self.item_count = self.item_count + 1
        return self


class MenuBar:
    def __init__(self, w):
        self.w = w
        self.h = 30
        self.y = 0
        self.menus = []
        self.menu_count = 0
        self.active_menu = -1
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.item_h = 28
        self.item_min_w = 160
        self.visible = true
        self.id = ""

    def add_menu(self, menu):
        self.menus.append(menu)
        self.menu_count = self.menu_count + 1
        return self

    def close_all(self):
        var i = 0
        while i < self.menu_count:
            self.menus[i].open = false
            i = i + 1
        self.active_menu = -1

    def _menu_x(self, index):
        var x = 0
        var i = 0
        while i < index:
            x = x + len(self.menus[i].label) * 8 + 24
            i = i + 1
        return x

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var bar_r = Rect(0, self.y, self.w, self.h)
            if bar_r.contains(event.x, event.y):
                var i = 0
                while i < self.menu_count:
                    var mx = self._menu_x(i)
                    var mr = Rect(mx, self.y, len(self.menus[i].label) * 8 + 24, self.h)
                    if mr.contains(event.x, event.y):
                        if self.menus[i].open:
                            self.close_all()
                        else:
                            self.close_all()
                            self.menus[i].open = true
                            self.active_menu = i
                        event.consume()
                        i = self.menu_count
                    else:
                        i = i + 1
            elif self.active_menu >= 0:
                var m = self.menus[self.active_menu]
                var mx = self._menu_x(self.active_menu)
                var total_h = 0
                var j = 0
                while j < m.item_count:
                    if m.items[j].separator:
                        total_h = total_h + 10
                    else:
                        total_h = total_h + self.item_h
                    j = j + 1
                var drop_r = Rect(mx, self.y + self.h, self.item_min_w, total_h)
                if drop_r.contains(event.x, event.y):
                    var item_y = self.y + self.h
                    var k = 0
                    while k < m.item_count:
                        if not m.items[k].separator:
                            var ir = Rect(mx, item_y, self.item_min_w, self.item_h)
                            if ir.contains(event.x, event.y) and m.items[k].enabled:
                                if m.items[k].action != none:
                                    m.items[k].action()
                                self.close_all()
                                event.consume()
                                var k = m.item_count
                            else:
                                item_y = item_y + self.item_h
                                k = k + 1
                        else:
                            item_y = item_y + 10
                            k = k + 1
                else:
                    self.close_all()
        elif event.type == "keydown" and event.key == "escape":
            self.close_all()

    def _draw(self, renderer):
        renderer.fill_rect(Rect(0, self.y, self.w, self.h), self.theme.bg)
        renderer.fill_rect(Rect(0, self.y + self.h - 1, self.w, 1), self.theme.border)
        var i = 0
        while i < self.menu_count:
            var m = self.menus[i]
            var mx = self._menu_x(i)
            var mr = Rect(mx, self.y, len(m.label) * 8 + 24, self.h)
            if m.open:
                renderer.fill_rect(mr, self.theme.surface)
            renderer.draw_text(m.label, mx + 12, self.y + int((self.h - 14) / 2), self.font, self.theme.text)
            if m.open:
                var item_y = self.y + self.h
                var total_h = 0
                var j = 0
                while j < m.item_count:
                    if m.items[j].separator:
                        total_h = total_h + 10
                    else:
                        total_h = total_h + self.item_h
                    j = j + 1
                var drop_r = Rect(mx, item_y, self.item_min_w, total_h)
                renderer.draw_shadow(drop_r, 10, 2, 4, Color(0, 0, 0, 60))
                renderer.fill_rounded_rect(drop_r, self.theme.surface, 4)
                renderer.draw_rounded_rect(drop_r, self.theme.border, 4, 1)
                var k = 0
                while k < m.item_count:
                    var item = m.items[k]
                    if item.separator:
                        renderer.fill_rect(Rect(mx + 8, item_y + 5, self.item_min_w - 16, 1), self.theme.border)
                        item_y = item_y + 10
                    else:
                        var ir = Rect(mx, item_y, self.item_min_w, self.item_h)
                        if k == m.hovered:
                            renderer.fill_rect(ir, Color(self.theme.accent.r, self.theme.accent.g, self.theme.accent.b, 40))
                        var tc = self.theme.text if item.enabled else self.theme.text_secondary
                        renderer.draw_text(item.label, mx + 12, item_y + int((self.item_h - 14) / 2), self.font, tc)
                        if item.shortcut != "":
                            var sw = len(item.shortcut) * 7
                            renderer.draw_text(item.shortcut, mx + self.item_min_w - sw - 12, item_y + int((self.item_h - 14) / 2), self.font, self.theme.text_secondary)
                        item_y = item_y + self.item_h
                    k = k + 1
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── StatusBar ────────────────────────────────────────────────────────────────

class StatusBar:
    def __init__(self, window_w, window_h):
        self.window_w = window_w
        self.window_h = window_h
        self.h = 24
        self.left_items = []
        self.left_count = 0
        self.right_items = []
        self.right_count = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.visible = true
        self.id = ""

    def add_left(self, text, icon):
        self.left_items.append({"text": text, "icon": icon})
        self.left_count = self.left_count + 1
        return self

    def add_right(self, text, icon):
        self.right_items.append({"text": text, "icon": icon})
        self.right_count = self.right_count + 1
        return self

    def set_left(self, index, text):
        if index >= 0 and index < self.left_count:
            self.left_items[index]["text"] = text
        return self

    def set_right(self, index, text):
        if index >= 0 and index < self.right_count:
            self.right_items[index]["text"] = text
        return self

    def clear_left(self):
        self.left_items = []
        self.left_count = 0
        return self

    def clear_right(self):
        self.right_items = []
        self.right_count = 0
        return self

    def _draw(self, renderer):
        var bar_y = self.window_h - self.h
        renderer.fill_rect(Rect(0, bar_y, self.window_w, self.h), self.theme.bg)
        renderer.fill_rect(Rect(0, bar_y, self.window_w, 1), self.theme.border)
        var lx = 8
        var i = 0
        while i < self.left_count:
            var item = self.left_items[i]
            var full = item["text"]
            if item["icon"] != "" and item["icon"] != none:
                full = item["icon"] + " " + full
            renderer.draw_text(full, lx, bar_y + int((self.h - 12) / 2), self.font, self.theme.text_secondary)
            lx = lx + len(full) * 7 + 16
            if i < self.left_count - 1:
                renderer.fill_rect(Rect(lx - 8, bar_y + 4, 1, self.h - 8), self.theme.border)
            i = i + 1
        var rx = self.window_w - 8
        i = self.right_count - 1
        while i >= 0:
            var item = self.right_items[i]
            var full = item["text"]
            if item["icon"] != "" and item["icon"] != none:
                full = item["icon"] + " " + full
            rx = rx - len(full) * 7
            renderer.draw_text(full, rx, bar_y + int((self.h - 12) / 2), self.font, self.theme.text_secondary)
            rx = rx - 16
            if i > 0:
                renderer.fill_rect(Rect(rx + 8, bar_y + 4, 1, self.h - 8), self.theme.border)
            i = i - 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── Notification ────────────────────────────────────────────────────────────

class Notification:
    def __init__(self, title, body, type_name, duration_ms):
        self.title = title
        self.body = body
        self.type = type_name
        self.duration_ms = duration_ms
        self.created_at = time_ms()
        self.read = false
        self.dismissed = false
        self.id = "ntf_" + str(int(time_ms()))
        self.action_label = ""
        self._action = none

    def is_expired(self):
        if self.duration_ms <= 0:
            return false
        return (time_ms() - self.created_at) > float(self.duration_ms)

    def dismiss(self):
        self.dismissed = true
        return self

    def mark_read(self):
        self.read = true
        return self

    def set_action(self, label, fn):
        self.action_label = label
        self._action = fn
        return self


class NotificationCenter:
    def __init__(self, window_w, window_h):
        self.window_w = window_w
        self.window_h = window_h
        self.notifications = []
        self.count = 0
        self.unread = 0
        self.max_visible = 5
        self.notif_w = 320
        self.notif_h = 80
        self.gap = 8
        self.position = "top-right"
        self.theme = Theme()
        self.font_title = Font("sans-serif", 13, true, false)
        self.font_body = Font("sans-serif", 12, false, false)
        self.visible = true

    def _get_color(self, type_name):
        if type_name == "success":
            return self.theme.success
        if type_name == "error":
            return self.theme.danger
        if type_name == "warning":
            return self.theme.warning
        return self.theme.info

    def add(self, title, body, type_name, duration_ms):
        var n = Notification(title, body, type_name, duration_ms)
        self.notifications.append(n)
        self.count = self.count + 1
        self.unread = self.unread + 1
        return n

    def success(self, title, body):
        return self.add(title, body, "success", 4000)

    def error(self, title, body):
        return self.add(title, body, "error", 0)

    def warning(self, title, body):
        return self.add(title, body, "warning", 5000)

    def info(self, title, body):
        return self.add(title, body, "info", 4000)

    def dismiss(self, notif_id):
        var i = 0
        while i < self.count:
            if self.notifications[i].id == notif_id:
                self.notifications[i].dismissed = true
            i = i + 1

    def dismiss_all(self):
        var i = 0
        while i < self.count:
            self.notifications[i].dismissed = true
            i = i + 1
        self.unread = 0

    def update(self):
        var kept = []
        var i = 0
        while i < self.count:
            if not self.notifications[i].dismissed and not self.notifications[i].is_expired():
                kept.append(self.notifications[i])
            i = i + 1
        self.notifications = kept
        self.count = len(kept)

    def _draw(self, renderer):
        self.update()
        var visible_count = self.count
        if visible_count > self.max_visible:
            var visible_count = self.max_visible
        var i = 0
        while i < visible_count:
            var n = self.notifications[i]
            var nx = self.window_w - self.notif_w - 16
            var ny = 16 + i * (self.notif_h + self.gap)
            var nr = Rect(nx, ny, self.notif_w, self.notif_h)
            renderer.draw_shadow(nr, 8, 0, 2, Color(0, 0, 0, 60))
            renderer.fill_rounded_rect(nr, self.theme.surface, 8)
            var accent = self._get_color(n.type)
            renderer.fill_rect(Rect(nx, ny + 4, 4, self.notif_h - 8), accent)
            renderer.draw_rounded_rect(nr, self.theme.border, 8, 1)
            renderer.draw_text(n.title, nx + 16, ny + 14, self.font_title, self.theme.text)
            renderer.draw_text(n.body, nx + 16, ny + 34, self.font_body, self.theme.text_secondary)
            renderer.draw_text("?", nx + self.notif_w - 24, ny + 10, self.font_body, self.theme.text_secondary)
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ListView ─────────────────────────────────────────────────────────────────

class ListView:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.items = []
        self.item_count = 0
        self.item_h = 40
        self.selected = -1
        self.hovered = -1
        self.scroll_y = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_sub = Font("sans-serif", 11, false, false)
        self.visible = true
        self.enabled = true
        self.multi_select = false
        self.selected_indices = []
        self.id = ""
        self._on_select = none
        self._on_double_click = none
        self._render_item = none
        self._last_click_time = 0.0
        self._last_click_index = -1

    def add_item(self, label, subtitle, value):
        self.items.append({"label": label, "subtitle": subtitle, "value": value, "icon": none})
        self.item_count = self.item_count + 1
        return self

    def add_item_with_icon(self, label, subtitle, value, icon):
        self.items.append({"label": label, "subtitle": subtitle, "value": value, "icon": icon})
        self.item_count = self.item_count + 1
        return self

    def set_item_height(self, h):
        self.item_h = h
        return self

    def set_render_item(self, fn):
        self._render_item = fn
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_double_click(self, fn):
        self._on_double_click = fn
        return self

    def clear(self):
        self.items = []
        self.item_count = 0
        self.selected = -1
        self.selected_indices = []
        return self

    def get_selected(self):
        if self.selected < 0 or self.selected >= self.item_count:
            return none
        return self.items[self.selected]

    def select(self, index):
        if index >= 0 and index < self.item_count:
            self.selected = index
            if self._on_select != none:
                self._on_select(self.items[index])
        return self

    def _item_y(self, index):
        return self.rect.y + index * self.item_h - self.scroll_y

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_s = self.item_count * self.item_h - self.rect.h
            if max_s < 0:
                var max_s = 0
            if self.scroll_y > max_s:
                self.scroll_y = max_s
            event.consume()
        elif event.type == "mousemove":
            self.hovered = -1
            var i = 0
            while i < self.item_count:
                var iy = self._item_y(i)
                if event.y >= iy and event.y < iy + self.item_h and self.rect.contains(event.x, event.y):
                    self.hovered = i
                i = i + 1
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var i = 0
            while i < self.item_count:
                var iy = self._item_y(i)
                if event.y >= iy and event.y < iy + self.item_h:
                    var now = time_ms()
                    var is_double = (i == self._last_click_index and (now - self._last_click_time) < 500.0)
                    self._last_click_time = now
                    self._last_click_index = i
                    self.select(i)
                    if is_double and self._on_double_click != none:
                        self._on_double_click(self.items[i])
                    event.consume()
                    i = self.item_count
                else:
                    i = i + 1

    def _draw(self, renderer):
        renderer.set_clip(self.rect)
        var i = 0
        while i < self.item_count:
            var iy = self._item_y(i)
            if iy + self.item_h > self.rect.y and iy < self.rect.bottom():
                var ir = Rect(self.rect.x, iy, self.rect.w, self.item_h)
                if i == self.selected:
                    renderer.fill_rect(ir, Color(self.theme.accent.r, self.theme.accent.g, self.theme.accent.b, 60))
                elif i == self.hovered:
                    renderer.fill_rect(ir, Color(255, 255, 255, 8))
                elif i % 2 == 1:
                    renderer.fill_rect(ir, Color(0, 0, 0, 10))
                var item = self.items[i]
                var tx = self.rect.x + 12
                var tc = self.theme.text
                renderer.draw_text(item["label"], tx, iy + 8, self.font, tc)
                if item["subtitle"] != "" and item["subtitle"] != none:
                    renderer.draw_text(item["subtitle"], tx, iy + 24, self.font_sub, self.theme.text_secondary)
                renderer.fill_rect(Rect(self.rect.x, iy + self.item_h - 1, self.rect.w, 1), Color(self.theme.border.r, self.theme.border.g, self.theme.border.b, 60))
            i = i + 1
        renderer.clear_clip()
        renderer.draw_rect(self.rect, self.theme.border, 1)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self


# ═══════════════════════════════════════════════════════════════════════════════
# BEAUTIFUL WIDGETS  -  v7 EXPANSION
# ═══════════════════════════════════════════════════════════════════════════════

# ─── GlassCard ────────────────────────────────────────────────────────────────
# Glassmorphism card: frosted-glass surface with blur hint, luminous border,
# inner-glow highlight, and a soft multi-layer drop shadow.

class GlassCard:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.title = ""
        self.subtitle = ""
        self.accent = Color(120, 80, 255, 255)
        self.tint = Color(255, 255, 255, 18)
        self.border_color = Color(255, 255, 255, 45)
        self.shadow_color = Color(0, 0, 0, 90)
        self.radius = 20
        self.blur_passes = 3
        self.children = []
        self.child_count = 0
        self.visible = true
        self.hovered = false
        self.theme = Theme()
        self.font_title = Font("sans-serif", 16, true, false)
        self.font_sub = Font("sans-serif", 12, false, false)
        self.glow = true
        self.id = ""

    def set_title(self, t):
        self.title = t
        return self

    def set_subtitle(self, s):
        self.subtitle = s
        return self

    def set_accent(self, color):
        self.accent = color
        return self

    def add(self, widget):
        self.children.append(widget)
        self.child_count = self.child_count + 1
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            self.hovered = self.rect.contains(event.x, event.y)
        var i = 0
        while i < self.child_count:
            self.children[i].handle_event(event)
            i = i + 1

    def _draw(self, renderer):
        # Multi-layer shadow for depth
        renderer.draw_shadow(self.rect, 32, 0, 12, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 60))
        renderer.draw_shadow(self.rect, 12, 0, 4, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 40))
        renderer.draw_shadow(self.rect, 4, 0, 1, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 30))
        # Frosted glass body (semi-transparent, slightly warm)
        renderer.fill_rounded_rect(self.rect, self.tint, self.radius)
        # Vertical gradient overlay to simulate glass depth
        var top_rect = Rect(self.rect.x, self.rect.y, self.rect.w, int(self.rect.h / 2))
        renderer.fill_rounded_rect(top_rect, Color(255, 255, 255, 10), self.radius)
        # Accent glow bar at top
        if self.glow:
            var glow_rect = Rect(self.rect.x + 20, self.rect.y - 1, int(self.rect.w * 2 / 3), 3)
            renderer.fill_rounded_rect(glow_rect, Color(self.accent.r, self.accent.g, self.accent.b, 180), 2)
        # Luminous border
        renderer.draw_rounded_rect(self.rect, self.border_color, self.radius, 1)
        # Inner highlight (top edge of glass)
        var inner = Rect(self.rect.x + 2, self.rect.y + 2, self.rect.w - 4, 1)
        renderer.fill_rect(inner, Color(255, 255, 255, 30))
        # Title and subtitle
        var ty = self.rect.y + 18
        if self.title != "":
            renderer.draw_text(self.title, self.rect.x + 20, ty, self.font_title, Color(255, 255, 255, 240))
            ty = ty + 22
        if self.subtitle != "":
            renderer.draw_text(self.subtitle, self.rect.x + 20, ty, self.font_sub, Color(200, 200, 220, 180))
        # Children
        var i = 0
        while i < self.child_count:
            self.children[i].draw(renderer)
            i = i + 1
        # Hover shimmer
        if self.hovered:
            renderer.fill_rounded_rect(self.rect, Color(255, 255, 255, 8), self.radius)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── FloatingActionButton ─────────────────────────────────────────────────────
# FAB with layered glow rings, ripple animation, and icon label.

class FloatingActionButton:
    def __init__(self, x, y, icon, size):
        self.cx = x
        self.cy = y
        self.icon = icon
        self.size = size
        self.r = int(size / 2)
        self.color = Color(99, 102, 241, 255)
        self.icon_color = Color(255, 255, 255, 255)
        self.shadow_color = Color(99, 102, 241, 100)
        self.pressed = false
        self.hovered = false
        self.ripple_r = 0.0
        self.ripple_alpha = 0
        self.ripple_active = false
        self.theme = Theme()
        self.font = Font("sans-serif", int(size * 0.4), false, false)
        self.visible = true
        self.enabled = true
        self.label = ""
        self.extended = false
        self.label_w = 0
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            var count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def set_color(self, color):
        self.color = color
        self.shadow_color = Color(color.r, color.g, color.b, 100)
        return self

    def set_label(self, text):
        self.label = text
        self.extended = (text != "")
        self.label_w = len(text) * 9
        return self

    def update(self):
        if self.ripple_active:
            self.ripple_r = self.ripple_r + float(self.r) * 0.12
            self.ripple_alpha = self.ripple_alpha - 14
            if self.ripple_r > float(self.r) * 1.8 or self.ripple_alpha <= 0:
                self.ripple_active = false
                self.ripple_r = 0.0
                self.ripple_alpha = 0

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        var inside = false
        if self.extended:
            var total_w = self.r * 2 + self.label_w + 16
            var fab_r = Rect(self.cx - self.r, self.cy - self.r, total_w, self.r * 2)
            var inside = fab_r.contains(event.x, event.y)
        else:
            var dx = event.x - self.cx
            var dy = event.y - self.cy
            if dx < 0:
                dx = -dx
            if dy < 0:
                dy = -dy
            inside = (dx * dx + dy * dy) <= (self.r * self.r)
        if event.type == "mousemove":
            self.hovered = inside
        elif event.type == "mousedown" and inside:
            self.pressed = true
            self.ripple_active = true
            self.ripple_r = 0.0
            self.ripple_alpha = 180
            event.consume()
        elif event.type == "mouseup" and self.pressed:
            self.pressed = false
            if inside:
                var ev = Event("click")
                ev.target = self
                self.emit(ev)
            event.consume()

    def _draw(self, renderer):
        # Glow rings (outermost to innermost)
        renderer.fill_circle(self.cx, self.cy, self.r + 14, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 20))
        renderer.fill_circle(self.cx, self.cy, self.r + 8, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 35))
        renderer.fill_circle(self.cx, self.cy, self.r + 3, Color(self.shadow_color.r, self.shadow_color.g, self.shadow_color.b, 55))
        if self.extended and self.label != "":
            # Extended FAB pill shape
            var total_w = self.r * 2 + self.label_w + 16
            var fab_r = Rect(self.cx - self.r, self.cy - self.r, total_w, self.r * 2)
            renderer.fill_rounded_rect(fab_r, self.color, self.r)
            renderer.draw_text(self.icon, self.cx - 8, self.cy - int(self.size * 0.22), self.font, self.icon_color)
            renderer.draw_text(self.label, self.cx + self.r + 4, self.cy - int(self.size * 0.22), self.font, self.icon_color)
        else:
            # Round FAB
            var bg = self.color
            if self.pressed:
                var bg = Color(int(self.color.r * 0.85), int(self.color.g * 0.85), int(self.color.b * 0.85), 255)
            elif self.hovered:
                bg = Color(min(self.color.r + 20, 255), min(self.color.g + 20, 255), min(self.color.b + 20, 255), 255)
            renderer.fill_circle(self.cx, self.cy, self.r, bg)
            # Highlight arc (top-left quadrant)
            renderer.fill_circle(self.cx - int(self.r * 0.2), self.cy - int(self.r * 0.25), int(self.r * 0.55), Color(255, 255, 255, 25))
            # Icon
            var iw = len(self.icon) * int(self.size * 0.24)
            renderer.draw_text(self.icon, self.cx - int(iw / 2), self.cy - int(self.size * 0.22), self.font, self.icon_color)
        # Ripple
        if self.ripple_active and self.ripple_r > 0.0:
            renderer.fill_circle(self.cx, self.cy, int(self.ripple_r), Color(255, 255, 255, self.ripple_alpha))

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.cx = x
        self.cy = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── ColorPicker ──────────────────────────────────────────────────────────────
# HSV gradient square + hue rainbow strip + hex preview swatch.

class ColorPicker:
    def __init__(self, x, y, size):
        self.x = x
        self.y = y
        self.size = size
        self.hue = 0.0
        self.saturation = 1.0
        self.value = 1.0
        self.alpha = 1.0
        self.dragging_sv = false
        self.dragging_hue = false
        self.dragging_alpha = false
        self.hue_strip_h = 18
        self.alpha_strip_h = 18
        self.gap = 8
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.font_mono = Font("monospace", 12, false, false)
        self.show_hex = true
        self.show_alpha = true
        self.visible = true
        self.enabled = true
        self.id = ""
        self._on_change = none

    def on_change(self, fn):
        self._on_change = fn
        return self

    def _hsv_to_rgb(self, h, s, v):
        var h6 = h * 6.0
        var i = int(h6)
        var f = h6 - float(i)
        var p = v * (1.0 - s)
        var q = v * (1.0 - f * s)
        var t = v * (1.0 - (1.0 - f) * s)
        var r = 0.0
        var g = 0.0
        var b = 0.0
        if i == 0:
            var r = v
            var g = t
            var b = p
        elif i == 1:
            r = q
            g = v
            b = p
        elif i == 2:
            r = p
            g = v
            b = t
        elif i == 3:
            r = p
            g = q
            b = v
        elif i == 4:
            r = t
            g = p
            b = v
        else:
            r = v
            g = p
            b = q
        return Color(int(r * 255), int(g * 255), int(b * 255), 255)

    def get_color(self):
        var c = self._hsv_to_rgb(self.hue, self.saturation, self.value)
        return Color(c.r, c.g, c.b, int(self.alpha * 255))

    def get_hex(self):
        var c = self.get_color()
        return c.to_hex()

    def set_hue(self, h):
        self.hue = h
        if self._on_change != none:
            self._on_change(self.get_color())
        return self

    def set_saturation(self, s):
        self.saturation = s
        return self

    def set_value_field(self, v):
        self.value = v
        return self

    def sv_rect(self):
        return Rect(self.x, self.y, self.size, self.size)

    def hue_rect(self):
        return Rect(self.x, self.y + self.size + self.gap, self.size, self.hue_strip_h)

    def alpha_rect(self):
        return Rect(self.x, self.y + self.size + self.gap * 2 + self.hue_strip_h, self.size, self.alpha_strip_h)

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        var sv = self.sv_rect()
        var hr = self.hue_rect()
        var ar = self.alpha_rect()
        if event.type == "mousedown":
            if sv.contains(event.x, event.y):
                self.dragging_sv = true
            elif hr.contains(event.x, event.y):
                self.dragging_hue = true
            elif self.show_alpha and ar.contains(event.x, event.y):
                self.dragging_alpha = true
        elif event.type == "mouseup":
            self.dragging_sv = false
            self.dragging_hue = false
            self.dragging_alpha = false
        elif event.type == "mousemove":
            if self.dragging_sv:
                var s = float(event.x - sv.x) / float(sv.w)
                var v = 1.0 - float(event.y - sv.y) / float(sv.h)
                if s < 0.0:
                    var s = 0.0
                if s > 1.0:
                    s = 1.0
                if v < 0.0:
                    var v = 0.0
                if v > 1.0:
                    v = 1.0
                self.saturation = s
                self.value = v
                if self._on_change != none:
                    self._on_change(self.get_color())
            elif self.dragging_hue:
                var h = float(event.x - hr.x) / float(hr.w)
                if h < 0.0:
                    var h = 0.0
                if h > 1.0:
                    h = 1.0
                self.hue = h
                if self._on_change != none:
                    self._on_change(self.get_color())
            elif self.dragging_alpha:
                var a = float(event.x - ar.x) / float(ar.w)
                if a < 0.0:
                    var a = 0.0
                if a > 1.0:
                    a = 1.0
                self.alpha = a
                if self._on_change != none:
                    self._on_change(self.get_color())

    def _draw(self, renderer):
        var sv = self.sv_rect()
        var hr = self.hue_rect()
        # SV gradient square (drawn as 16x16 grid approximation)
        var hue_color = self._hsv_to_rgb(self.hue, 1.0, 1.0)
        var cols = 16
        var rows = 16
        var cw = int(sv.w / cols)
        var ch = int(sv.h / rows)
        var row = 0
        while row < rows:
            var col = 0
            while col < cols:
                var s = float(col) / float(cols - 1)
                var v = 1.0 - float(row) / float(rows - 1)
                var cell_c = self._hsv_to_rgb(self.hue, s, v)
                renderer.fill_rect(Rect(sv.x + col * cw, sv.y + row * ch, cw + 1, ch + 1), cell_c)
                col = col + 1
            row = row + 1
        renderer.draw_rounded_rect(sv, Color(0, 0, 0, 80), 4, 1)
        # SV cursor crosshair
        var cx = sv.x + int(self.saturation * float(sv.w))
        var cy = sv.y + int((1.0 - self.value) * float(sv.h))
        renderer.draw_circle(cx, cy, 8, Color(255, 255, 255, 200))
        renderer.draw_circle(cx, cy, 6, Color(0, 0, 0, 120))
        renderer.fill_circle(cx, cy, 4, self.get_color())
        # Hue rainbow strip (8 segments)
        var seg_w = int(hr.w / 8)
        var hues = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
        var hi = 0
        while hi < 8:
            var seg_c = self._hsv_to_rgb(hues[hi], 1.0, 1.0)
            renderer.fill_rect(Rect(hr.x + hi * seg_w, hr.y, seg_w + 1, hr.h), seg_c)
            hi = hi + 1
        renderer.draw_rounded_rect(hr, Color(0, 0, 0, 80), 4, 1)
        # Hue cursor
        var hx = hr.x + int(self.hue * float(hr.w))
        renderer.fill_rect(Rect(hx - 2, hr.y - 2, 4, hr.h + 4), Color(255, 255, 255, 230))
        renderer.draw_rect(Rect(hx - 2, hr.y - 2, 4, hr.h + 4), Color(0, 0, 0, 100), 1)
        # Alpha strip
        if self.show_alpha:
            var ar = self.alpha_rect()
            # Checkerboard background for alpha
            var csize = 8
            var checker_cols = int(ar.w / csize)
            var ci = 0
            while ci < checker_cols:
                var checker_c = Color(180, 180, 180, 255) if (ci % 2 == 0) else Color(120, 120, 120, 255)
                renderer.fill_rect(Rect(ar.x + ci * csize, ar.y, csize, ar.h), checker_c)
                ci = ci + 1
            var base_c = self.get_color()
            renderer.fill_rounded_rect(ar, Color(base_c.r, base_c.g, base_c.b, int(self.alpha * 180)), 4)
            renderer.draw_rounded_rect(ar, Color(0, 0, 0, 80), 4, 1)
            var ax = ar.x + int(self.alpha * float(ar.w))
            renderer.fill_rect(Rect(ax - 2, ar.y - 2, 4, ar.h + 4), Color(255, 255, 255, 230))
            renderer.draw_rect(Rect(ax - 2, ar.y - 2, 4, ar.h + 4), Color(0, 0, 0, 100), 1)
        # Color preview swatch + hex
        if self.show_hex:
            var swatch_y = self.y + self.size + self.gap * 3 + self.hue_strip_h + self.alpha_strip_h
            var swatch_r = Rect(self.x, swatch_y, 36, 24)
            renderer.fill_rounded_rect(swatch_r, self.get_color(), 6)
            renderer.draw_rounded_rect(swatch_r, Color(255, 255, 255, 60), 6, 1)
            renderer.draw_text(self.get_hex(), self.x + 44, swatch_y + 4, self.font_mono, self.theme.text)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── LineChart ────────────────────────────────────────────────────────────────
# Smooth anti-aliased line chart with gradient fill, dots, grid, axis labels,
# multiple series support, and hover crosshair.

class ChartSeries:
    def __init__(self, name, data, color):
        self.name = name
        self.data = data
        self.color = color
        self.line_w = 2
        self.show_dots = true
        self.dot_r = 4
        self.fill = true
        self.fill_alpha = 40
        self.dashed = false


class LineChart:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.series = []
        self.series_count = 0
        self.title = ""
        self.x_labels = []
        self.x_label_count = 0
        self.padding_left = 50
        self.padding_right = 20
        self.padding_top = 40
        self.padding_bottom = 40
        self.grid_lines = 5
        self.show_grid = true
        self.show_legend = true
        self.show_tooltip = true
        self.hover_x = -1
        self.animate = true
        self.anim_progress = 0.0
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 14, true, false)
        self.font_legend = Font("sans-serif", 11, false, false)
        self.bg_color = none
        self.visible = true
        self.id = ""

    def add_series(self, series):
        self.series.append(series)
        self.series_count = self.series_count + 1
        return self

    def set_x_labels(self, labels):
        self.x_labels = labels
        self.x_label_count = len(labels)
        return self

    def set_title(self, t):
        self.title = t
        return self

    def _min_val(self):
        var mn = 999999.0
        var i = 0
        while i < self.series_count:
            var j = 0
            while j < len(self.series[i].data):
                if self.series[i].data[j] < mn:
                    var mn = self.series[i].data[j]
                j = j + 1
            i = i + 1
        return mn

    def _max_val(self):
        var mx = -999999.0
        var i = 0
        while i < self.series_count:
            var j = 0
            while j < len(self.series[i].data):
                if self.series[i].data[j] > mx:
                    var mx = self.series[i].data[j]
                j = j + 1
            i = i + 1
        return mx

    def _plot_area(self):
        return Rect(
            self.rect.x + self.padding_left,
            self.rect.y + self.padding_top,
            self.rect.w - self.padding_left - self.padding_right,
            self.rect.h - self.padding_top - self.padding_bottom
        )

    def _data_to_px(self, di, val, n_points, min_v, max_v, pa):
        var range_v = max_v - min_v
        if range_v == 0.0:
            var range_v = 1.0
        var px = pa.x + int(float(di) / float(n_points - 1) * float(pa.w))
        var py = pa.bottom() - int((val - min_v) / range_v * float(pa.h))
        return [px, py]

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.04
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            if self.rect.contains(event.x, event.y):
                self.hover_x = event.x
            else:
                self.hover_x = -1

    def _draw(self, renderer):
        var pa = self._plot_area()
        var min_v = self._min_val()
        var max_v = self._max_val()
        var val_range = max_v - min_v
        if val_range == 0.0:
            var val_range = 1.0
        # Background
        if self.bg_color != none:
            renderer.fill_rounded_rect(self.rect, self.bg_color, 12)
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 50))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 12)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 15), 12, 1)
        # Title
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, self.rect.x + int((self.rect.w - tw) / 2), self.rect.y + 12, self.font_title, self.theme.text)
        # Grid lines
        if self.show_grid:
            var gi = 0
            while gi <= self.grid_lines:
                var gy = pa.bottom() - int(float(gi) / float(self.grid_lines) * float(pa.h))
                renderer.fill_rect(Rect(pa.x, gy, pa.w, 1), Color(255, 255, 255, 12))
                var label_v = min_v + float(gi) / float(self.grid_lines) * val_range
                var lbl = str(int(label_v))
                renderer.draw_text(lbl, self.rect.x + 4, gy - 6, self.font, self.theme.text_secondary)
                gi = gi + 1
        # X axis labels
        if self.x_label_count > 0 and self.series_count > 0:
            var n = len(self.series[0].data)
            var xi = 0
            while xi < self.x_label_count and xi < n:
                var pos = self._data_to_px(xi, 0.0, n, min_v, max_v, pa)
                renderer.draw_text(self.x_labels[xi], pos[0] - int(len(self.x_labels[xi]) * 3), pa.bottom() + 8, self.font, self.theme.text_secondary)
                xi = xi + 1
        # Axis lines
        renderer.fill_rect(Rect(pa.x, pa.y, 1, pa.h), Color(255, 255, 255, 30))
        renderer.fill_rect(Rect(pa.x, pa.bottom(), pa.w, 1), Color(255, 255, 255, 30))
        # Series
        var si = 0
        while si < self.series_count:
            var ser = self.series[si]
            var n = len(ser.data)
            if n < 2:
                si = si + 1
            else:
                var draw_n = int(float(n) * self.anim_progress)
                if draw_n < 2:
                    var draw_n = 2
                if draw_n > n:
                    draw_n = n
                # Gradient fill under line (approximated as horizontal strips)
                if ser.fill and draw_n > 1:
                    var fi = 0
                    while fi < draw_n - 1:
                        var p0 = self._data_to_px(fi, ser.data[fi], n, min_v, max_v, pa)
                        var p1 = self._data_to_px(fi + 1, ser.data[fi + 1], n, min_v, max_v, pa)
                        var strip_x = p0[0]
                        var strip_w = p1[0] - p0[0] + 1
                        var strip_top = min(p0[1], p1[1])
                        var strip_h = pa.bottom() - strip_top
                        renderer.fill_rect(Rect(strip_x, strip_top, strip_w, strip_h), Color(ser.color.r, ser.color.g, ser.color.b, ser.fill_alpha))
                        fi = fi + 1
                # Line segments
                var li = 0
                while li < draw_n - 1:
                    var p0 = self._data_to_px(li, ser.data[li], n, min_v, max_v, pa)
                    var p1 = self._data_to_px(li + 1, ser.data[li + 1], n, min_v, max_v, pa)
                    renderer.draw_line(p0[0], p0[1], p1[0], p1[1], ser.color, ser.line_w)
                    # Thicker glow line
                    renderer.draw_line(p0[0], p0[1], p1[0], p1[1], Color(ser.color.r, ser.color.g, ser.color.b, 60), ser.line_w + 3)
                    li = li + 1
                # Dots
                if ser.show_dots:
                    var di = 0
                    while di < draw_n:
                        var p = self._data_to_px(di, ser.data[di], n, min_v, max_v, pa)
                        renderer.fill_circle(p[0], p[1], ser.dot_r + 2, Color(ser.color.r, ser.color.g, ser.color.b, 80))
                        renderer.fill_circle(p[0], p[1], ser.dot_r, ser.color)
                        renderer.fill_circle(p[0], p[1], ser.dot_r - 2, Color(255, 255, 255, 180))
                        di = di + 1
                si = si + 1
        # Legend
        if self.show_legend and self.series_count > 0:
            var lx = pa.x
            var ly = self.rect.y + self.rect.h - 22
            var li = 0
            while li < self.series_count:
                renderer.fill_circle(lx + 6, ly + 6, 5, self.series[li].color)
                renderer.draw_text(self.series[li].name, lx + 16, ly, self.font_legend, self.theme.text_secondary)
                lx = lx + len(self.series[li].name) * 7 + 32
                li = li + 1
        # Hover crosshair
        if self.hover_x >= pa.x and self.hover_x <= pa.right():
            renderer.fill_rect(Rect(self.hover_x, pa.y, 1, pa.h), Color(255, 255, 255, 40))

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── BarChart ─────────────────────────────────────────────────────────────────
# Animated bar chart with gradient bars, rounded tops, value labels,
# category labels, and multi-group support.

class BarChart:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.bars = []
        self.bar_count = 0
        self.title = ""
        self.max_value = 0.0
        self.auto_max = true
        self.bar_w = 40
        self.bar_gap = 12
        self.group_gap = 24
        self.padding_left = 50
        self.padding_right = 20
        self.padding_top = 40
        self.padding_bottom = 50
        self.grid_lines = 4
        self.show_values = true
        self.show_grid = true
        self.anim_progress = 0.0
        self.animate = true
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 14, true, false)
        self.font_val = Font("sans-serif", 10, true, false)
        self.visible = true
        self.id = ""

    def add_bar(self, label, value, color):
        self.bars.append({"label": label, "value": value, "color": color})
        self.bar_count = self.bar_count + 1
        if self.auto_max and value > self.max_value:
            self.max_value = value
        return self

    def set_title(self, t):
        self.title = t
        return self

    def set_max(self, v):
        self.max_value = v
        self.auto_max = false
        return self

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.05
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def _draw(self, renderer):
        var pa_x = self.rect.x + self.padding_left
        var pa_y = self.rect.y + self.padding_top
        var pa_w = self.rect.w - self.padding_left - self.padding_right
        var pa_h = self.rect.h - self.padding_top - self.padding_bottom
        var pa_bottom = pa_y + pa_h
        var mx = self.max_value
        if mx == 0.0:
            var mx = 1.0
        # Background
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 50))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 12)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 15), 12, 1)
        # Title
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, self.rect.x + int((self.rect.w - tw) / 2), self.rect.y + 12, self.font_title, self.theme.text)
        # Grid
        if self.show_grid:
            var gi = 0
            while gi <= self.grid_lines:
                var gy = pa_bottom - int(float(gi) / float(self.grid_lines) * float(pa_h))
                renderer.fill_rect(Rect(pa_x, gy, pa_w, 1), Color(255, 255, 255, 12))
                var lv = int(float(gi) / float(self.grid_lines) * mx)
                renderer.draw_text(str(lv), self.rect.x + 4, gy - 6, self.font, self.theme.text_secondary)
                gi = gi + 1
        # Axes
        renderer.fill_rect(Rect(pa_x, pa_y, 1, pa_h + 1), Color(255, 255, 255, 30))
        renderer.fill_rect(Rect(pa_x, pa_bottom), pa_w, 1, Color(255, 255, 255, 30))
        # Bars
        var total_bar_w = self.bar_count * (self.bar_w + self.bar_gap) - self.bar_gap
        var start_x = pa_x + int((pa_w - total_bar_w) / 2)
        if start_x < pa_x:
            var start_x = pa_x
        var bi = 0
        while bi < self.bar_count:
            var bar = self.bars[bi]
            var bx = start_x + bi * (self.bar_w + self.bar_gap)
            var animated_h = int(float(bar["value"]) / mx * float(pa_h) * self.anim_progress)
            var by = pa_bottom - animated_h
            var c = bar["color"]
            # Shadow under bar
            renderer.fill_rect(Rect(bx + 3, by + 4, self.bar_w, animated_h), Color(c.r, c.g, c.b, 40))
            # Gradient bar body (drawn as two halves: brighter top, normal bottom)
            var bright = Color(min(c.r + 50, 255), min(c.g + 50, 255), min(c.b + 50, 255), 255)
            if animated_h > 0:
                renderer.fill_rounded_rect(Rect(bx, by, self.bar_w, animated_h), c, 6)
                # Highlight on top third of bar
                renderer.fill_rounded_rect(Rect(bx, by, self.bar_w, int(animated_h / 3) + 1), bright, 6)
                # Shine stripe
                renderer.fill_rounded_rect(Rect(bx + 4, by + 4, int(self.bar_w / 4), int(animated_h / 2)), Color(255, 255, 255, 45), 3)
            # Value label on top
            if self.show_values and animated_h > 16:
                var val_str = str(int(bar["value"]))
                var vw = len(val_str) * 6
                renderer.draw_text(val_str, bx + int((self.bar_w - vw) / 2), by - 16, self.font_val, self.theme.text)
            # Category label below axis
            var lw = len(bar["label"]) * 6
            renderer.draw_text(bar["label"], bx + int((self.bar_w - lw) / 2), pa_bottom + 8, self.font, self.theme.text_secondary)
            bi = bi + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Gauge ────────────────────────────────────────────────────────────────────
# Speedometer-style arc gauge with colored zones, animated needle,
# tick marks, value label, and min/max labels.

class Gauge:
    def __init__(self, x, y, size, min_val, max_val, value):
        self.x = x
        self.y = y
        self.size = size
        self.min_val = min_val
        self.max_val = max_val
        self.value = value
        self.display_value = 0.0
        self.animate = true
        self.anim_speed = 0.06
        self.start_angle = 210
        self.sweep_angle = 240
        self.thickness = int(size / 8)
        self.zones = []
        self.zone_count = 0
        self.label = ""
        self.unit = ""
        self.show_ticks = true
        self.tick_count = 10
        self.needle_color = Color(255, 80, 60, 255)
        self.bg_color = Color(30, 32, 44, 255)
        self.track_color = Color(60, 62, 80, 255)
        self.value_color = Color(240, 240, 255, 255)
        self.theme = Theme()
        self.font_val = Font("sans-serif", int(size / 5), true, false)
        self.font_unit = Font("sans-serif", int(size / 10), false, false)
        self.font_tick = Font("sans-serif", int(size / 14), false, false)
        self.visible = true
        self.id = ""

    def set_value(self, val):
        if val < self.min_val:
            var val = self.min_val
        if val > self.max_val:
            val = self.max_val
        self.value = val
        if not self.animate:
            self.display_value = val
        return self

    def add_zone(self, from_pct, to_pct, color):
        self.zones.append({"from": from_pct, "to": to_pct, "color": color})
        self.zone_count = self.zone_count + 1
        return self

    def set_label(self, text):
        self.label = text
        return self

    def set_unit(self, unit):
        self.unit = unit
        return self

    def _val_to_angle(self, val):
        var range_v = float(self.max_val - self.min_val)
        if range_v == 0.0:
            var range_v = 1.0
        var pct = (val - float(self.min_val)) / range_v
        return self.start_angle + int(pct * float(self.sweep_angle))

    def update(self):
        if self.animate:
            var diff = self.value - self.display_value
            if diff > 0.5 or diff < -0.5:
                self.display_value = self.display_value + diff * self.anim_speed * 20.0
            else:
                self.display_value = self.value

    def _draw(self, renderer):
        var cx = self.x + int(self.size / 2)
        var cy = self.y + int(self.size / 2)
        var r = int(self.size / 2) - 4
        # Outer glow
        renderer.fill_circle(cx, cy, r + 10, Color(0, 0, 0, 40))
        renderer.fill_circle(cx, cy, r + 4, Color(0, 0, 0, 60))
        # Background disk
        renderer.fill_circle(cx, cy, r, self.bg_color)
        # Track arc
        renderer.draw_arc(cx, cy, r - int(self.thickness / 2), self.start_angle, self.start_angle + self.sweep_angle, self.track_color, self.thickness)
        # Zones
        var zi = 0
        while zi < self.zone_count:
            var z = self.zones[zi]
            var za = self.start_angle + int(z["from"] * float(self.sweep_angle))
            var zb = self.start_angle + int(z["to"] * float(self.sweep_angle))
            renderer.draw_arc(cx, cy, r - int(self.thickness / 2), za, zb, z["color"], self.thickness)
            zi = zi + 1
        # Progress arc up to current value
        var prog_angle = self._val_to_angle(self.display_value)
        var range_v = float(self.max_val - self.min_val)
        if range_v == 0.0:
            var range_v = 1.0
        var pct = (self.display_value - float(self.min_val)) / range_v
        var prog_color = Color(99, 102, 241, 255)
        if self.zone_count > 0:
            var zi2 = 0
            while zi2 < self.zone_count:
                var z = self.zones[zi2]
                if pct >= z["from"] and pct <= z["to"]:
                    var prog_color = z["color"]
                zi2 = zi2 + 1
        renderer.draw_arc(cx, cy, r - int(self.thickness / 2), self.start_angle, prog_angle, prog_color, self.thickness)
        # Tick marks
        if self.show_ticks:
            var ti = 0
            while ti <= self.tick_count:
                var t_pct = float(ti) / float(self.tick_count)
                var t_angle = self.start_angle + int(t_pct * float(self.sweep_angle))
                var t_len = int(self.size / 14) if (ti % 2 == 0) else int(self.size / 22)
                var t_inner = r - self.thickness - 4 - t_len
                var t_outer = r - self.thickness - 4
                # Use approximate sin/cos (hard coded for 8 angles won't work, use renderer.draw_line with angle)
                renderer.draw_spoke(cx, cy, t_inner, t_outer, t_angle, Color(180, 180, 200, 120))
                ti = ti + 1
        # Inner circle (hub)
        renderer.fill_circle(cx, cy, int(r * 0.22), Color(50, 52, 70, 255))
        renderer.draw_circle(cx, cy, int(r * 0.22), Color(255, 255, 255, 20))
        # Needle
        renderer.draw_needle(cx, cy, int(r * 0.72), prog_angle, self.needle_color, 3)
        renderer.fill_circle(cx, cy, int(r * 0.1), self.needle_color)
        renderer.fill_circle(cx, cy, int(r * 0.06), Color(255, 255, 255, 200))
        # Value text
        var val_str = str(int(self.display_value))
        var vw = len(val_str) * int(self.size / 10)
        renderer.draw_text(val_str, cx - int(vw / 2), cy + int(r * 0.18), self.font_val, self.value_color)
        if self.unit != "":
            var uw = len(self.unit) * int(self.size / 20)
            renderer.draw_text(self.unit, cx - int(uw / 2), cy + int(r * 0.38), self.font_unit, self.theme.text_secondary)
        if self.label != "":
            var lw = len(self.label) * int(self.size / 20)
            renderer.draw_text(self.label, cx - int(lw / 2), cy + int(r * 0.55), self.font_unit, self.theme.text_secondary)
        # Min/max labels
        renderer.draw_text(str(self.min_val), self.x + 8, self.y + self.size - 20, self.font_tick, self.theme.text_secondary)
        var max_s = str(self.max_val)
        renderer.draw_text(max_s, self.x + self.size - len(max_s) * 7, self.y + self.size - 20, self.font_tick, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── CalendarWidget ───────────────────────────────────────────────────────────
# Full month calendar with event dots, range selection, navigation,
# today highlight, and weekend accents.

class CalendarWidget:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.year = 2025
        self.month = 1
        self.selected_day = 0
        self.range_start = 0
        self.range_end = 0
        self.events = {}
        self.today_year = 2025
        self.today_month = 1
        self.today_day = 1
        self.cell_w = int(w / 7)
        self.cell_h = int((h - 80) / 6)
        self.header_h = 48
        self.weekday_h = 28
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_bold = Font("sans-serif", 13, true, false)
        self.font_header = Font("sans-serif", 15, true, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.accent = Color(99, 102, 241, 255)
        self.weekend_color = Color(255, 100, 100, 200)
        self.today_color = Color(99, 102, 241, 255)
        self.event_color = Color(52, 199, 89, 255)
        self.visible = true
        self.id = ""
        self._on_select = none
        self._on_navigate = none

    def set_date(self, year, month):
        self.year = year
        self.month = month
        return self

    def set_today(self, year, month, day):
        self.today_year = year
        self.today_month = month
        self.today_day = day
        return self

    def add_event(self, day, label):
        var key = str(self.year) + "-" + str(self.month) + "-" + str(day)
        self.events[key] = label
        return self

    def has_event(self, day):
        var key = str(self.year) + "-" + str(self.month) + "-" + str(day)
        return self.events[key] != none

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_navigate(self, fn):
        self._on_navigate = fn
        return self

    def _days_in_month(self, year, month):
        var days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        if month == 2:
            var leap = false
            if year % 400 == 0:
                var leap = true
            elif year % 100 == 0:
                leap = false
            elif year % 4 == 0:
                leap = true
            if leap:
                return 29
        return days[month]

    def _first_weekday(self, year, month):
        var y = year
        var m = month
        if m < 3:
            m = m + 12
            y = y - 1
        var k = y % 100
        var j = int(y / 100)
        var h = (1 + int(13 * (m + 1) / 5) + k + int(k / 4) + int(j / 4) - 2 * j) % 7
        var d = (h + 5) % 7
        return d

    def prev_month(self):
        self.month = self.month - 1
        if self.month < 1:
            self.month = 12
            self.year = self.year - 1
        if self._on_navigate != none:
            self._on_navigate(self.year, self.month)
        return self

    def next_month(self):
        self.month = self.month + 1
        if self.month > 12:
            self.month = 1
            self.year = self.year + 1
        if self._on_navigate != none:
            self._on_navigate(self.year, self.month)
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var nav_prev = Rect(self.rect.x + 10, self.rect.y + 10, 30, 30)
            var nav_next = Rect(self.rect.right() - 40, self.rect.y + 10, 30, 30)
            if nav_prev.contains(event.x, event.y):
                self.prev_month()
                event.consume()
            elif nav_next.contains(event.x, event.y):
                self.next_month()
                event.consume()
            else:
                var grid_y = self.rect.y + self.header_h + self.weekday_h
                if event.y >= grid_y:
                    var col = int((event.x - self.rect.x) / self.cell_w)
                    var row = int((event.y - grid_y) / self.cell_h)
                    if col >= 0 and col < 7:
                        var first_wd = self._first_weekday(self.year, self.month)
                        var day = row * 7 + col - first_wd + 1
                        var max_day = self._days_in_month(self.year, self.month)
                        if day >= 1 and day <= max_day:
                            self.selected_day = day
                            if self._on_select != none:
                                self._on_select(self.year, self.month, day)
                            event.consume()

    def _draw(self, renderer):
        var month_names = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        var day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        # Background
        renderer.draw_shadow(self.rect, 20, 0, 6, Color(0, 0, 0, 60))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 16)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 15), 16, 1)
        # Header gradient
        var hdr = Rect(self.rect.x, self.rect.y, self.rect.w, self.header_h)
        renderer.fill_rounded_rect(hdr, Color(self.accent.r, self.accent.g, self.accent.b, 30), 16)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + 8, self.rect.w, self.header_h - 8), Color(self.accent.r, self.accent.g, self.accent.b, 20))
        # Navigation
        renderer.fill_rounded_rect(Rect(self.rect.x + 10, self.rect.y + 10, 30, 30), Color(255, 255, 255, 15), 8)
        renderer.draw_text("?", self.rect.x + 18, self.rect.y + 14, self.font_header, self.theme.text)
        renderer.fill_rounded_rect(Rect(self.rect.right() - 40, self.rect.y + 10, 30, 30), Color(255, 255, 255, 15), 8)
        renderer.draw_text("?", self.rect.right() - 30, self.rect.y + 14, self.font_header, self.theme.text)
        # Month/year title
        var title = month_names[self.month] + " " + str(self.year)
        var tw = len(title) * 9
        renderer.draw_text(title, self.rect.x + int((self.rect.w - tw) / 2), self.rect.y + 14, self.font_header, self.theme.text)
        # Day-of-week headers
        var wd_y = self.rect.y + self.header_h
        var di = 0
        while di < 7:
            var dname = day_names[di]
            var dx = self.rect.x + di * self.cell_w + int((self.cell_w - len(dname) * 7) / 2)
            var is_weekend = (di == 5 or di == 6)
            var dc = self.weekend_color if is_weekend else self.theme.text_secondary
            renderer.draw_text(dname, dx, wd_y + 6, self.font, dc)
            di = di + 1
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + self.header_h + self.weekday_h - 1, self.rect.w, 1), Color(255, 255, 255, 15))
        # Calendar grid
        var grid_y = self.rect.y + self.header_h + self.weekday_h
        var first_wd = self._first_weekday(self.year, self.month)
        var max_day = self._days_in_month(self.year, self.month)
        var day = 1
        var ri = 0
        while ri < 6:
            var ci = 0
            while ci < 7:
                var idx = ri * 7 + ci
                var d = idx - first_wd + 1
                if d >= 1 and d <= max_day:
                    var cx = self.rect.x + ci * self.cell_w
                    var cy = grid_y + ri * self.cell_h
                    var cell_r = Rect(cx, cy, self.cell_w, self.cell_h)
                    var is_today = (d == self.today_day and self.month == self.today_month and self.year == self.today_year)
                    var is_selected = (d == self.selected_day)
                    var is_weekend = (ci == 5 or ci == 6)
                    if is_selected:
                        renderer.fill_rounded_rect(Rect(cx + 4, cy + 2, self.cell_w - 8, self.cell_h - 4), self.accent, 10)
                    elif is_today:
                        renderer.fill_rounded_rect(Rect(cx + 4, cy + 2, self.cell_w - 8, self.cell_h - 4), Color(self.accent.r, self.accent.g, self.accent.b, 35), 10)
                    var day_str = str(d)
                    var dw = len(day_str) * 7
                    var tx = cx + int((self.cell_w - dw) / 2)
                    var ty = cy + int((self.cell_h - 14) / 2)
                    var tc = Color(255, 255, 255, 255) if is_selected else (self.today_color if is_today else (self.weekend_color if is_weekend else self.theme.text))
                    var df = self.font_bold if (is_today or is_selected) else self.font
                    renderer.draw_text(day_str, tx, ty, df, tc)
                    if self.has_event(d):
                        renderer.fill_circle(cx + int(self.cell_w / 2), cy + self.cell_h - 6, 3, self.event_color)
                ci = ci + 1
            ri = ri + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── SkeletonLoader ───────────────────────────────────────────────────────────
# Shimmer loading placeholder with configurable shape presets:
# text lines, avatar, card, image, table row.

class SkeletonBlock:
    def __init__(self, x, y, w, h, radius):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.radius = radius


class SkeletonLoader:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.blocks = []
        self.block_count = 0
        self.shimmer_x = 0.0
        self.shimmer_speed = 2.5
        self.base_color = Color(50, 52, 70, 255)
        self.shimmer_color = Color(80, 85, 110, 180)
        self.shimmer_w = 80
        self.visible = true
        self.id = ""

    def add_block(self, rel_x, rel_y, w, h, radius):
        self.blocks.append(SkeletonBlock(self.rect.x + rel_x, self.rect.y + rel_y, w, h, radius))
        self.block_count = self.block_count + 1
        return self

    def preset_card(self):
        self.add_block(0, 0, self.rect.w, 180, 12)
        self.add_block(0, 196, int(self.rect.w * 0.6), 16, 8)
        self.add_block(0, 220, int(self.rect.w * 0.4), 12, 6)
        self.add_block(0, 248, self.rect.w, 10, 5)
        self.add_block(0, 266, int(self.rect.w * 0.8), 10, 5)
        return self

    def preset_list_item(self):
        self.add_block(0, 0, 44, 44, 22)
        self.add_block(56, 4, int(self.rect.w * 0.5), 14, 7)
        self.add_block(56, 26, int(self.rect.w * 0.3), 10, 5)
        return self

    def preset_profile(self):
        var cx = int(self.rect.w / 2) - 36
        self.add_block(cx, 0, 72, 72, 36)
        self.add_block(int(self.rect.w * 0.2), 88, int(self.rect.w * 0.6), 16, 8)
        self.add_block(int(self.rect.w * 0.3), 114, int(self.rect.w * 0.4), 12, 6)
        self.add_block(0, 142, self.rect.w, 10, 5)
        self.add_block(0, 160, int(self.rect.w * 0.85), 10, 5)
        self.add_block(0, 178, int(self.rect.w * 0.7), 10, 5)
        return self

    def preset_text(self, lines):
        var i = 0
        while i < lines:
            var line_w = self.rect.w if (i < lines - 1) else int(self.rect.w * 0.6)
            self.add_block(0, i * 22, line_w, 12, 6)
            i = i + 1
        return self

    def update(self):
        self.shimmer_x = self.shimmer_x + self.shimmer_speed
        if self.shimmer_x > float(self.rect.w) + float(self.shimmer_w):
            self.shimmer_x = -float(self.shimmer_w)

    def _draw(self, renderer):
        var i = 0
        while i < self.block_count:
            var b = self.blocks[i]
            renderer.fill_rounded_rect(Rect(b.x, b.y, b.w, b.h), self.base_color, b.radius)
            var sx = b.x + int(self.shimmer_x) - int(float(self.shimmer_w) / 2)
            var clip_r = Rect(b.x, b.y, b.w, b.h)
            renderer.set_clip(clip_r)
            renderer.fill_rounded_rect(Rect(sx, b.y, self.shimmer_w, b.h), self.shimmer_color, b.radius)
            renderer.clear_clip()
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Timeline ─────────────────────────────────────────────────────────────────
# Vertical event timeline with icons, connectors, timestamps,
# accent pills, and collapsible detail text.

class TimelineEvent:
    def __init__(self, title, description, timestamp, color, icon):
        self.title = title
        self.description = description
        self.timestamp = timestamp
        self.color = color
        self.icon = icon
        self.expanded = true
        self.tag = ""


class Timeline:
    def __init__(self, x, y, w):
        self.x = x
        self.y = y
        self.w = w
        self.events = []
        self.event_count = 0
        self.line_x_offset = 24
        self.dot_r = 10
        self.item_gap = 16
        self.min_item_h = 72
        self.theme = Theme()
        self.font_title = Font("sans-serif", 13, true, false)
        self.font_desc = Font("sans-serif", 12, false, false)
        self.font_time = Font("sans-serif", 11, false, false)
        self.font_icon = Font("sans-serif", 14, false, false)
        self.line_color = Color(70, 72, 95, 255)
        self.connector_glow = true
        self.visible = true
        self.id = ""
        self._on_click = none

    def add_event(self, title, description, timestamp, color, icon):
        self.events.append(TimelineEvent(title, description, timestamp, color, icon))
        self.event_count = self.event_count + 1
        return self

    def add_tagged_event(self, title, description, timestamp, color, icon, tag):
        var ev = TimelineEvent(title, description, timestamp, color, icon)
        ev.tag = tag
        self.events.append(ev)
        self.event_count = self.event_count + 1
        return self

    def on_click(self, fn):
        self._on_click = fn
        return self

    def total_height(self):
        return self.event_count * (self.min_item_h + self.item_gap)

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown" and self._on_click != none:
            var iy = self.y
            var i = 0
            while i < self.event_count:
                var item_h = self.min_item_h
                var ir = Rect(self.x, iy, self.w, item_h)
                if ir.contains(event.x, event.y):
                    self._on_click(i, self.events[i])
                    event.consume()
                    i = self.event_count
                else:
                    iy = iy + item_h + self.item_gap
                    i = i + 1

    def _draw(self, renderer):
        var lx = self.x + self.line_x_offset
        var total_h = self.total_height()
        # Vertical connector line with gradient feel
        renderer.fill_rect(Rect(lx - 1, self.y + self.dot_r, 2, total_h - self.dot_r * 2), self.line_color)
        var iy = self.y
        var i = 0
        while i < self.event_count:
            var ev = self.events[i]
            var is_last = (i == self.event_count - 1)
            var dot_y = iy + int(self.min_item_h / 2)
            # Glow ring behind dot
            if self.connector_glow:
                renderer.fill_circle(lx, dot_y, self.dot_r + 6, Color(ev.color.r, ev.color.g, ev.color.b, 30))
                renderer.fill_circle(lx, dot_y, self.dot_r + 3, Color(ev.color.r, ev.color.g, ev.color.b, 60))
            # Dot with inner highlight
            renderer.fill_circle(lx, dot_y, self.dot_r, ev.color)
            renderer.fill_circle(lx - 2, dot_y - 2, int(self.dot_r * 0.45), Color(255, 255, 255, 80))
            if ev.icon != "":
                renderer.draw_text(ev.icon, lx - 6, dot_y - 8, self.font_icon, Color(255, 255, 255, 230))
            # Content area
            var cx = lx + self.dot_r + 16
            var cw = self.w - self.line_x_offset - self.dot_r - 20
            # Timestamp pill
            if ev.timestamp != "":
                renderer.draw_text(ev.timestamp, cx, iy + 4, self.font_time, self.theme.text_secondary)
            # Title
            renderer.draw_text(ev.title, cx, iy + 20, self.font_title, self.theme.text)
            # Tag badge
            if ev.tag != "":
                var tag_x = cx + len(ev.title) * 8 + 10
                var tag_r = Rect(tag_x, iy + 18, len(ev.tag) * 7 + 10, 18)
                renderer.fill_rounded_rect(tag_r, Color(ev.color.r, ev.color.g, ev.color.b, 50), 9)
                renderer.draw_rounded_rect(tag_r, Color(ev.color.r, ev.color.g, ev.color.b, 120), 9, 1)
                renderer.draw_text(ev.tag, tag_x + 5, iy + 21, self.font_time, ev.color)
            # Description
            if ev.description != "" and ev.expanded:
                renderer.draw_text(ev.description, cx, iy + 40, self.font_desc, Color(self.theme.text_secondary.r, self.theme.text_secondary.g, self.theme.text_secondary.b, 200))
            # Subtle horizontal rule under item (except last)
            if not is_last:
                renderer.fill_rect(Rect(cx, iy + self.min_item_h + int(self.item_gap / 2) - 1, cw, 1), Color(255, 255, 255, 8))
            iy = iy + self.min_item_h + self.item_gap
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── PieChart ─────────────────────────────────────────────────────────────────
# Animated donut / pie chart with explode effect on hover,
# percentage labels, rich legend, and center value display.

class PieSegment:
    def __init__(self, label, value, color):
        self.label = label
        self.value = value
        self.color = color
        self.explode = 0.0
        self.hovered = false


class PieChart:
    def __init__(self, x, y, size):
        self.x = x
        self.y = y
        self.size = size
        self.segments = []
        self.seg_count = 0
        self.donut = true
        self.donut_ratio = 0.55
        self.title = ""
        self.center_label = ""
        self.center_value = ""
        self.anim_progress = 0.0
        self.animate = true
        self.hover_idx = -1
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 14, true, false)
        self.font_center = Font("sans-serif", 22, true, false)
        self.font_sub = Font("sans-serif", 11, false, false)
        self.show_legend = true
        self.show_pct_labels = true
        self.gap_angle = 2
        self.visible = true
        self.id = ""
        self._on_hover = none

    def add_segment(self, label, value, color):
        self.segments.append(PieSegment(label, value, color))
        self.seg_count = self.seg_count + 1
        return self

    def set_title(self, t):
        self.title = t
        return self

    def set_center(self, label, value):
        self.center_label = label
        self.center_value = value
        return self

    def on_hover(self, fn):
        self._on_hover = fn
        return self

    def _total(self):
        var tot = 0.0
        var i = 0
        while i < self.seg_count:
            tot = tot + self.segments[i].value
            i = i + 1
        return tot

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.035
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            var cx = self.x + int(self.size / 2)
            var cy = self.y + int(self.size / 2)
            var dx = event.x - cx
            var dy = event.y - cy
            var dist = int(dx * dx + dy * dy)
            var r = int(self.size / 2)
            if dist <= r * r:
                self.hover_idx = 0
            else:
                self.hover_idx = -1

    def _draw(self, renderer):
        var cx = self.x + int(self.size / 2)
        var cy = self.y + int(self.size / 2)
        var r = int(self.size / 2) - 8
        # Background
        renderer.draw_shadow(Rect(self.x, self.y, self.size, self.size), 20, 0, 6, Color(0, 0, 0, 50))
        renderer.fill_rounded_rect(Rect(self.x, self.y, self.size, self.size), self.theme.surface, 16)
        # Title
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, cx - int(tw / 2), self.y + 12, self.font_title, self.theme.text)
        var tot = self._total()
        if tot == 0.0:
            var tot = 1.0
        # Outer glow ring
        renderer.fill_circle(cx, cy, r + 6, Color(0, 0, 0, 30))
        # Draw segments
        var angle = -90.0
        var draw_sweep = 360.0 * self.anim_progress
        var i = 0
        while i < self.seg_count:
            var seg = self.segments[i]
            var sweep = (seg.value / tot) * 360.0
            var end_a = angle + min(sweep - float(self.gap_angle), draw_sweep - (angle + 90.0))
            if end_a > angle + 0.5:
                # Shadow arc for depth
                var arc_thickness = 0
                if self.donut:
                    arc_thickness = int(r * self.donut_ratio)
                renderer.draw_arc(cx + 2, cy + 2, r - 2, int(angle), int(end_a), Color(0, 0, 0, 50), r - arc_thickness)
                # Main arc
                renderer.draw_arc(cx, cy, r - 2, int(angle), int(end_a), seg.color, r - arc_thickness)
                # Highlight arc (inner, brighter)
                var br = Color(min(seg.color.r + 40, 255), min(seg.color.g + 40, 255), min(seg.color.b + 40, 255), 80)
                renderer.draw_arc(cx, cy, r - 2, int(angle), int(angle + (end_a - angle) * 0.35), br, 4)
            angle = angle + sweep
            if angle > -90.0 + draw_sweep:
                i = self.seg_count
            else:
                i = i + 1
        # Donut hole
        if self.donut:
            var hole_r = int(r * self.donut_ratio)
            renderer.fill_circle(cx, cy, hole_r, self.theme.surface)
            renderer.draw_circle(cx, cy, hole_r, Color(0, 0, 0, 40))
            renderer.draw_circle(cx, cy, hole_r - 2, Color(255, 255, 255, 10))
            # Center value display
            if self.center_value != "":
                var vw = len(self.center_value) * int(self.size / 15)
                renderer.draw_text(self.center_value, cx - int(vw / 2), cy - 16, self.font_center, self.theme.text)
            if self.center_label != "":
                var lw = len(self.center_label) * 6
                renderer.draw_text(self.center_label, cx - int(lw / 2), cy + 8, self.font_sub, self.theme.text_secondary)
        # Legend
        if self.show_legend:
            var leg_y = self.y + self.size + 8
            var leg_x = self.x
            var i2 = 0
            while i2 < self.seg_count:
                var seg = self.segments[i2]
                var pct = int(seg.value / tot * 100.0)
                renderer.fill_rounded_rect(Rect(leg_x, leg_y + 3, 10, 10), seg.color, 5)
                renderer.draw_text(seg.label + " " + str(pct) + "%", leg_x + 14, leg_y, self.font, self.theme.text_secondary)
                leg_x = leg_x + len(seg.label) * 7 + 60
                if leg_x > self.x + self.size - 80:
                    leg_x = self.x
                    leg_y = leg_y + 20
                i2 = i2 + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── KanbanCard / KanbanColumn / KanbanBoard ──────────────────────────────────
# Drag-aware Kanban board with column swim-lanes, card priority badges,
# progress bars on cards, member avatars, and drop shadow lift effect.

class KanbanCard:
    def __init__(self, id, title, description):
        self.id = id
        self.title = title
        self.description = description
        self.priority = "normal"
        self.tags = []
        self.tag_count = 0
        self.progress = 0
        self.assignee = ""
        self.due = ""
        self.color = none
        self.dragging = false

    def set_priority(self, p):
        self.priority = p
        return self

    def set_progress(self, pct):
        self.progress = pct
        return self

    def set_assignee(self, name):
        self.assignee = name
        return self

    def set_due(self, due):
        self.due = due
        return self

    def add_tag(self, tag):
        self.tags.append(tag)
        self.tag_count = self.tag_count + 1
        return self


class KanbanColumn:
    def __init__(self, id, title, color):
        self.id = id
        self.title = title
        self.color = color
        self.cards = []
        self.card_count = 0
        self.card_h = 110
        self.card_w = 220
        self.card_gap = 10
        self.header_h = 44

    def add_card(self, card):
        self.cards.append(card)
        self.card_count = self.card_count + 1
        return self

    def remove_card(self, card_id):
        var kept = []
        var i = 0
        while i < self.card_count:
            if self.cards[i].id != card_id:
                kept.append(self.cards[i])
            i = i + 1
        self.cards = kept
        self.card_count = len(kept)
        return self

    def total_h(self):
        return self.header_h + self.card_count * (self.card_h + self.card_gap) + self.card_gap

    def draw_column(self, renderer, cx, cy, theme, font, font_title, font_small):
        var col_h = self.total_h()
        var col_r = Rect(cx, cy, self.card_w + 20, col_h)
        # Column background
        renderer.fill_rounded_rect(col_r, Color(self.color.r, self.color.g, self.color.b, 18), 14)
        renderer.draw_rounded_rect(col_r, Color(self.color.r, self.color.g, self.color.b, 50), 14, 1)
        # Column header
        var hdr = Rect(cx, cy, self.card_w + 20, self.header_h)
        renderer.fill_rounded_rect(hdr, Color(self.color.r, self.color.g, self.color.b, 40), 14)
        renderer.fill_rect(Rect(cx, cy + 8, self.card_w + 20, self.header_h - 8), Color(self.color.r, self.color.g, self.color.b, 25))
        # Color accent strip at top of column
        renderer.fill_rounded_rect(Rect(cx + 12, cy + 8, 36, 4), self.color, 2)
        renderer.draw_text(self.title, cx + 14, cy + 14, font_title, Color(255, 255, 255, 230))
        # Card count badge
        var cnt_str = str(self.card_count)
        var badge_r = Rect(cx + self.card_w - 4, cy + 12, len(cnt_str) * 7 + 10, 20)
        renderer.fill_rounded_rect(badge_r, Color(self.color.r, self.color.g, self.color.b, 80), 10)
        renderer.draw_text(cnt_str, cx + self.card_w - 2, cy + 14, font_small, Color(255, 255, 255, 200))
        # Cards
        var card_y = cy + self.header_h + self.card_gap
        var i = 0
        while i < self.card_count:
            var card = self.cards[i]
            var cr = Rect(cx + 10, card_y, self.card_w, self.card_h)
            # Card shadow + lift
            renderer.draw_shadow(cr, 12, 0, 4, Color(0, 0, 0, 60))
            # Card bg
            var card_bg = Color(45, 47, 65, 255) if card.color == none else card.color
            renderer.fill_rounded_rect(cr, card_bg, 10)
            renderer.draw_rounded_rect(cr, Color(255, 255, 255, 12), 10, 1)
            # Priority stripe on left edge
            var pri_color = Color(255, 80, 60, 255)
            if card.priority == "normal":
                var pri_color = Color(99, 102, 241, 200)
            elif card.priority == "low":
                pri_color = Color(52, 199, 89, 200)
            elif card.priority == "critical":
                pri_color = Color(255, 45, 85, 255)
            renderer.fill_rounded_rect(Rect(cx + 10, card_y, 3, self.card_h), pri_color, 2)
            # Title
            renderer.draw_text(card.title, cx + 20, card_y + 10, font_title, Color(235, 235, 250, 255))
            # Description (truncated)
            var desc = card.description
            if len(desc) > 28:
                desc = desc[0:28] + "..."
            renderer.draw_text(desc, cx + 20, card_y + 30, font, Color(160, 162, 190, 200))
            # Tags
            var tx = cx + 20
            var ti = 0
            while ti < card.tag_count:
                var tag_r2 = Rect(tx, card_y + 50, len(card.tags[ti]) * 6 + 10, 16)
                renderer.fill_rounded_rect(tag_r2, Color(self.color.r, self.color.g, self.color.b, 60), 8)
                renderer.draw_text(card.tags[ti], tx + 5, card_y + 52, font_small, self.color)
                tx = tx + len(card.tags[ti]) * 6 + 16
                ti = ti + 1
            # Progress bar (if set)
            if card.progress > 0:
                var pb_r = Rect(cx + 20, card_y + 74, self.card_w - 30, 4)
                renderer.fill_rounded_rect(pb_r, Color(60, 62, 80, 255), 2)
                var fill_w = int(float(card.progress) / 100.0 * float(self.card_w - 30))
                renderer.fill_rounded_rect(Rect(cx + 20, card_y + 74, fill_w, 4), self.color, 2)
            # Assignee
            if card.assignee != "":
                var initials = card.assignee[0:1]
                renderer.fill_circle(cx + self.card_w - 8, card_y + self.card_h - 14, 11, self.color)
                renderer.draw_text(string_upper(initials), cx + self.card_w - 13, card_y + self.card_h - 21, font_small, Color(255, 255, 255, 230))
            # Due date
            if card.due != "":
                renderer.draw_text("? " + card.due, cx + 20, card_y + self.card_h - 20, font_small, Color(160, 162, 180, 180))
            card_y = card_y + self.card_h + self.card_gap
            i = i + 1


class KanbanBoard:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.columns = []
        self.col_count = 0
        self.col_gap = 16
        self.title = ""
        self.scroll_x = 0
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 13, true, false)
        self.font_board_title = Font("sans-serif", 18, true, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.bg_color = Color(22, 24, 38, 255)
        self.visible = true
        self.id = ""

    def set_title(self, t):
        self.title = t
        return self

    def add_column(self, column):
        self.columns.append(column)
        self.col_count = self.col_count + 1
        return self

    def get_column(self, col_id):
        var i = 0
        while i < self.col_count:
            if self.columns[i].id == col_id:
                return self.columns[i]
            i = i + 1
        return none

    def move_card(self, card_id, from_col_id, to_col_id):
        var from_col = self.get_column(from_col_id)
        var to_col = self.get_column(to_col_id)
        if from_col == none or to_col == none:
            return false
        var found = none
        var i = 0
        while i < from_col.card_count:
            if from_col.cards[i].id == card_id:
                var found = from_col.cards[i]
            i = i + 1
        if found == none:
            return false
        from_col.remove_card(card_id)
        to_col.add_card(found)
        return true

    def total_cards(self):
        var total = 0
        var i = 0
        while i < self.col_count:
            total = total + self.columns[i].card_count
            i = i + 1
        return total

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_x = self.scroll_x + event.delta * 20
            if self.scroll_x < 0:
                self.scroll_x = 0

    def _draw(self, renderer):
        # Board background
        renderer.fill_rounded_rect(self.rect, self.bg_color, 16)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 10), 16, 1)
        renderer.set_clip(self.rect)
        # Board title bar
        if self.title != "":
            var tb_r = Rect(self.rect.x, self.rect.y, self.rect.w, 50)
            renderer.fill_rounded_rect(tb_r, Color(0, 0, 0, 30), 16)
            renderer.draw_text(self.title, self.rect.x + 20, self.rect.y + 14, self.font_board_title, self.theme.text)
            var total_str = str(self.total_cards()) + " cards"
            renderer.draw_text(total_str, self.rect.right() - len(total_str) * 7 - 20, self.rect.y + 16, self.font, self.theme.text_secondary)
        # Columns
        var col_y = self.rect.y + 60
        if self.title == "":
            var col_y = self.rect.y + 10
        var col_x = self.rect.x + 16 - self.scroll_x
        var i = 0
        while i < self.col_count:
            self.columns[i].draw_column(renderer, col_x, col_y, self.theme, self.font, self.font_title, self.font_small)
            col_x = col_x + self.columns[i].card_w + 20 + self.col_gap
            i = i + 1
        renderer.clear_clip()

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self


# ═══════════════════════════════════════════════════════════════════════════════
# WAVE 3  -  EXCEPTIONAL WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

# ─── HeatMap ──────────────────────────────────────────────────────────────────
# GitHub-style contribution / data heatmap with palette interpolation,
# row/column labels, value tooltip, and animated cell reveal.

class HeatMap:
    def __init__(self, x, y, cols, rows, cell_size, cell_gap):
        self.x = x
        self.y = y
        self.cols = cols
        self.rows = rows
        self.cell_size = cell_size
        self.cell_gap = cell_gap
        self.data = []
        self.min_val = 0.0
        self.max_val = 1.0
        self.col_labels = []
        self.row_labels = []
        self.col_label_count = 0
        self.row_label_count = 0
        self.label_pad = 40
        self.colors_low = Color(30, 32, 44, 255)
        self.colors_high = Color(99, 102, 241, 255)
        self.null_color = Color(38, 40, 55, 255)
        self.border_color = Color(255, 255, 255, 8)
        self.theme = Theme()
        self.font = Font("sans-serif", 10, false, false)
        self.title = ""
        self.radius = 3
        self.show_values = false
        self.anim_reveal = true
        self.anim_col = 0
        self.visible = true
        self.id = ""
        self._on_hover = none
        self._init_data()

    def _init_data(self):
        var total = self.cols * self.rows
        var i = 0
        while i < total:
            self.data.append(0.0)
            i = i + 1

    def set_data(self, flat_data):
        self.data = flat_data
        var i = 0
        var mn = 999999.0
        var mx = -999999.0
        while i < len(flat_data):
            if flat_data[i] < mn:
                var mn = flat_data[i]
            if flat_data[i] > mx:
                var mx = flat_data[i]
            i = i + 1
        self.min_val = mn
        self.max_val = mx
        return self

    def set_cell(self, col, row, val):
        var idx = row * self.cols + col
        if idx >= 0 and idx < len(self.data):
            self.data[idx] = val
            if val > self.max_val:
                self.max_val = val
            if val < self.min_val:
                self.min_val = val
        return self

    def set_col_labels(self, labels):
        self.col_labels = labels
        self.col_label_count = len(labels)
        return self

    def set_row_labels(self, labels):
        self.row_labels = labels
        self.row_label_count = len(labels)
        return self

    def set_palette(self, low, high):
        self.colors_low = low
        self.colors_high = high
        return self

    def set_title(self, t):
        self.title = t
        return self

    def on_hover(self, fn):
        self._on_hover = fn
        return self

    def _cell_color(self, val):
        var range_v = self.max_val - self.min_val
        if range_v <= 0.0:
            return self.colors_low
        var t = (val - self.min_val) / range_v
        if t < 0.0:
            var t = 0.0
        if t > 1.0:
            t = 1.0
        var r = int(float(self.colors_low.r) + t * float(self.colors_high.r - self.colors_low.r))
        var g = int(float(self.colors_low.g) + t * float(self.colors_high.g - self.colors_low.g))
        var b = int(float(self.colors_low.b) + t * float(self.colors_high.b - self.colors_low.b))
        return Color(r, g, b, 255)

    def total_w(self):
        return self.label_pad + self.cols * (self.cell_size + self.cell_gap)

    def total_h(self):
        return self.label_pad + self.rows * (self.cell_size + self.cell_gap) + 20

    def update(self):
        if self.anim_reveal and self.anim_col < self.cols:
            self.anim_col = self.anim_col + 1

    def _draw(self, renderer):
        var ox = self.x + self.label_pad
        var oy = self.y + self.label_pad + 20
        if self.title != "":
            renderer.draw_text(self.title, self.x, self.y, self.font, self.theme.text)
        var draw_cols = self.anim_col if self.anim_reveal else self.cols
        var col = 0
        while col < draw_cols:
            var row = 0
            while row < self.rows:
                var idx = row * self.cols + col
                var val = 0.0
                if idx < len(self.data):
                    var val = self.data[idx]
                var cx = ox + col * (self.cell_size + self.cell_gap)
                var cy = oy + row * (self.cell_size + self.cell_gap)
                var cell_r = Rect(cx, cy, self.cell_size, self.cell_size)
                var cc = self._cell_color(val)
                # Cell shadow
                renderer.fill_rounded_rect(Rect(cx + 1, cy + 1, self.cell_size, self.cell_size), Color(0, 0, 0, 40), self.radius)
                renderer.fill_rounded_rect(cell_r, cc, self.radius)
                # Subtle highlight on bright cells
                var brightness = int(float(cc.r + cc.g + cc.b) / 3)
                if brightness > 100:
                    renderer.fill_rounded_rect(Rect(cx, cy, self.cell_size, int(self.cell_size / 2)), Color(255, 255, 255, 20), self.radius)
                renderer.draw_rounded_rect(cell_r, self.border_color, self.radius, 1)
                row = row + 1
            if self.col_label_count > col and col < self.col_label_count:
                var lbl = self.col_labels[col]
                var lx = ox + col * (self.cell_size + self.cell_gap) + int(self.cell_size / 2) - int(len(lbl) * 3)
                renderer.draw_text(lbl, lx, oy - 18, self.font, self.theme.text_secondary)
            col = col + 1
        var row2 = 0
        while row2 < self.rows:
            if self.row_label_count > row2:
                var lbl = self.row_labels[row2]
                var ly = oy + row2 * (self.cell_size + self.cell_gap) + int(self.cell_size / 2) - 6
                renderer.draw_text(lbl, self.x, ly, self.font, self.theme.text_secondary)
            row2 = row2 + 1
        # Legend gradient strip
        var leg_y = oy + self.rows * (self.cell_size + self.cell_gap) + 8
        var leg_w = self.cols * (self.cell_size + self.cell_gap)
        var segs = 12
        var sw = int(leg_w / segs)
        var li = 0
        while li < segs:
            var t = float(li) / float(segs - 1)
            var r = int(float(self.colors_low.r) + t * float(self.colors_high.r - self.colors_low.r))
            var g = int(float(self.colors_low.g) + t * float(self.colors_high.g - self.colors_low.g))
            var b = int(float(self.colors_low.b) + t * float(self.colors_high.b - self.colors_low.b))
            renderer.fill_rounded_rect(Rect(ox + li * sw, leg_y, sw + 1, 8), Color(r, g, b, 255), 2)
            li = li + 1
        renderer.draw_text(str(int(self.min_val)), ox, leg_y + 12, self.font, self.theme.text_secondary)
        renderer.draw_text(str(int(self.max_val)), ox + leg_w - 16, leg_y + 12, self.font, self.theme.text_secondary)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── AudioWaveform ────────────────────────────────────────────────────────────
# Real-time style waveform visualiser with mirrored bars, glow gradient,
# playhead needle, progress fill, and animated idle bounce.

class AudioWaveform:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.samples = []
        self.sample_count = 0
        self.playhead = 0.0
        self.playing = false
        self.color_low = Color(99, 102, 241, 200)
        self.color_high = Color(220, 100, 255, 255)
        self.progress_color = Color(99, 102, 241, 255)
        self.playhead_color = Color(255, 255, 255, 220)
        self.bg_color = Color(22, 24, 38, 255)
        self.bar_gap = 2
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.title = ""
        self.duration_str = ""
        self.current_str = ""
        self.anim_t = 0.0
        self.idle_bounce = true
        self.visible = true
        self.enabled = true
        self.id = ""
        self._on_seek = none

    def set_samples(self, samples):
        self.samples = samples
        self.sample_count = len(samples)
        return self

    def set_playhead(self, t):
        if t < 0.0:
            var t = 0.0
        if t > 1.0:
            t = 1.0
        self.playhead = t
        return self

    def set_time_display(self, current, duration):
        self.current_str = current
        self.duration_str = duration
        return self

    def set_title(self, t):
        self.title = t
        return self

    def on_seek(self, fn):
        self._on_seek = fn
        return self

    def play(self):
        self.playing = true
        return self

    def pause(self):
        self.playing = false
        return self

    def update(self):
        self.anim_t = self.anim_t + 0.05
        if self.anim_t > 1000.0:
            self.anim_t = 0.0

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var t = float(event.x - self.rect.x) / float(self.rect.w)
            self.playhead = t
            if self._on_seek != none:
                self._on_seek(t)
            event.consume()

    def _sample_at(self, idx):
        if self.sample_count == 0:
            var noise = float((idx * 7 + 13) % 17) / 17.0
            var wave = float((idx * 3 + 5) % 11) / 11.0
            return 0.2 + noise * 0.3 + wave * 0.3
        var si = int(float(idx) / float(self.rect.w) * float(self.sample_count))
        if si >= self.sample_count:
            var si = self.sample_count - 1
        return self.samples[si]

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.bg_color, 12)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 12), 12, 1)
        var cy = self.rect.y + int(self.rect.h / 2)
        var bar_w = 3
        var step = bar_w + self.bar_gap
        var n_bars = int(self.rect.w / step)
        var playhead_px = self.rect.x + int(self.playhead * float(self.rect.w))
        var bi = 0
        while bi < n_bars:
            var bx = self.rect.x + bi * step
            var sample = self._sample_at(bi)
            if self.idle_bounce and self.playing:
                var bounce = float((bi * 3 + int(self.anim_t * 5)) % 7) / 7.0 * 0.15
                sample = sample + bounce
                if sample > 1.0:
                    sample = 1.0
            var bh = int(sample * float(self.rect.h / 2 - 6))
            if bh < 2:
                var bh = 2
            var is_played = (bx < playhead_px)
            var bar_color = Color(0,0,0,0)
            if is_played:
                var t = float(bi) / float(n_bars)
                var r = int(float(self.color_low.r) + t * float(self.color_high.r - self.color_low.r))
                var g = int(float(self.color_low.g) + t * float(self.color_high.g - self.color_low.g))
                var b_ch = int(float(self.color_low.b) + t * float(self.color_high.b - self.color_low.b))
                var bar_color = Color(r, g, b_ch, 255)
            else:
                bar_color = Color(70, 72, 95, 200)
            # Upper bar
            renderer.fill_rounded_rect(Rect(bx, cy - bh, bar_w, bh), bar_color, 1)
            # Mirror lower bar (slightly dimmer)
            renderer.fill_rounded_rect(Rect(bx, cy, bar_w, int(bh * 0.6)), Color(bar_color.r, bar_color.g, bar_color.b, int(bar_color.a * 0.5)), 1)
            # Glow on played bars
            if is_played and bh > 8:
                renderer.fill_rounded_rect(Rect(bx, cy - bh, bar_w, bh), Color(bar_color.r, bar_color.g, bar_color.b, 60), 1)
            bi = bi + 1
        # Playhead needle
        renderer.fill_rect(Rect(playhead_px, self.rect.y + 4, 2, self.rect.h - 8), self.playhead_color)
        renderer.fill_circle(playhead_px + 1, self.rect.y + 6, 5, self.playhead_color)
        renderer.fill_circle(playhead_px + 1, self.rect.bottom() - 6, 5, self.playhead_color)
        # Title + time display
        if self.title != "":
            renderer.draw_text(self.title, self.rect.x + 12, self.rect.y + 8, self.font, Color(220, 220, 240, 200))
        if self.current_str != "" and self.duration_str != "":
            var time_str = self.current_str + " / " + self.duration_str
            var tw = len(time_str) * 7
            renderer.draw_text(time_str, self.rect.right() - tw - 12, self.rect.y + 8, self.font, Color(160, 162, 190, 180))

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Spotlight ────────────────────────────────────────────────────────────────
# Cmd-K-style command palette overlay: instant fuzzy search through
# registered actions, keyboard nav, icon+category badges, recents.

class SpotlightItem:
    def __init__(self, id, label, category, icon, shortcut):
        self.id = id
        self.label = label
        self.category = category
        self.icon = icon
        self.shortcut = shortcut
        self.recent = false

    def matches(self, query):
        if query == "":
            return true
        var q = string_lower(query)
        var l = string_lower(self.label)
        var c = string_lower(self.category)
        if string_contains(l, q):
            return true
        if string_contains(c, q):
            return true
        return false


class Spotlight:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.query = ""
        self.items = []
        self.item_count = 0
        self.results = []
        self.result_count = 0
        self.selected = 0
        self.recents = []
        self.recent_count = 0
        self.max_recents = 5
        self.item_h = 44
        self.input_h = 52
        self.visible = false
        self.theme = Theme()
        self.cmd_count = 0
        self.font = Font("sans-serif", 14, false, false)
        self.font_bold = Font("sans-serif", 14, true, false)
        self.font_small = Font("sans-serif", 11, false, false)
        self.font_icon = Font("sans-serif", 18, false, false)
        self.bg = Color(28, 30, 46, 240)
        self.id = ""
        self._on_select = none
        self._on_close = none

    def register(self, id, label, category, icon, shortcut):
        self.items.append(SpotlightItem(id, label, category, icon, shortcut))
        self.item_count = self.item_count + 1
        self.cmd_count = self.item_count
        self._refresh()
        return self

    def add_item(self, label, id):
        return self.register(id, label, "", "", "")

    def add_command(self, name, desc, fn):
        return self.register(name, desc, "", "", "")

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_close(self, fn):
        self._on_close = fn
        return self

    def open(self):
        self.visible = true
        self.query = ""
        self.selected = 0
        self._refresh()
        return self

    def close(self):
        self.visible = false
        if self._on_close != none:
            self._on_close()
        return self

    def toggle(self):
        if self.visible:
            self.close()
        else:
            self.open()
        return self

    def _refresh(self):
        self.results = []
        self.result_count = 0
        var i = 0
        while i < self.item_count:
            if self.items[i].matches(self.query):
                self.results.append(self.items[i])
                self.result_count = self.result_count + 1
            i = i + 1
        if self.selected >= self.result_count:
            self.selected = 0

    def _execute(self):
        if self.selected >= 0 and self.selected < self.result_count:
            var item = self.results[self.selected]
            if self._on_select != none:
                self._on_select(item)
            # Add to recents
            var new_rec = [item]
            var ri = 0
            while ri < self.recent_count:
                if self.recents[ri].id != item.id:
                    new_rec.append(self.recents[ri])
                ri = ri + 1
            self.recents = new_rec
            if len(new_rec) > self.max_recents:
                self.recent_count = self.max_recents
            else:
                self.recent_count = len(new_rec)
            self.close()

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "keydown":
            if event.key == "escape":
                self.close()
                event.consume()
            elif event.key == "enter":
                self._execute()
                event.consume()
            elif event.key == "up":
                if self.selected > 0:
                    self.selected = self.selected - 1
                event.consume()
            elif event.key == "down":
                if self.selected < self.result_count - 1:
                    self.selected = self.selected + 1
                event.consume()
            elif event.key == "backspace":
                if len(self.query) > 0:
                    self.query = self.query[0:len(self.query) - 1]
                    self._refresh()
                event.consume()
        elif event.type == "textinput" and self.visible:
            self.query = self.query + event.text
            self._refresh()
            event.consume()
        elif event.type == "mousedown":
            var overlay = Rect(0, 0, self.window_w, self.window_h)
            var panel = Rect(self.x, self.y, self.w, self.h)
            if not panel.contains(event.x, event.y):
                self.close()
                event.consume()
            else:
                var list_y = self.y + self.input_h
                if event.y >= list_y:
                    var clicked_row = int((event.y - list_y) / self.item_h)
                    if clicked_row >= 0 and clicked_row < self.result_count:
                        self.selected = clicked_row
                        self._execute()
                    event.consume()

    def _draw(self, renderer):
        # Backdrop
        renderer.fill_rect(Rect(0, 0, self.window_w, self.window_h), Color(0, 0, 0, 140))
        # Panel
        var panel = Rect(self.x, self.y, self.w, self.h)
        renderer.draw_shadow(panel, 40, 0, 16, Color(0, 0, 0, 120))
        renderer.fill_rounded_rect(panel, self.bg, 16)
        renderer.draw_rounded_rect(panel, Color(255, 255, 255, 20), 16, 1)
        # Accent top border glow
        renderer.fill_rounded_rect(Rect(self.x + 40, self.y - 1, self.w - 80, 2), Color(99, 102, 241, 200), 1)
        # Search input area
        var inp_r = Rect(self.x, self.y, self.w, self.input_h)
        renderer.fill_rounded_rect(inp_r, Color(255, 255, 255, 6), 16)
        renderer.fill_rect(Rect(self.x, self.y + self.input_h - 1, self.w, 1), Color(255, 255, 255, 12))
        # Search icon
        renderer.draw_text("?", self.x + 16, self.y + 14, self.font_icon, Color(140, 142, 180, 200))
        # Query text with cursor
        var disp_q = self.query + "|"
        renderer.draw_text(disp_q, self.x + 44, self.y + 16, self.font, Color(230, 232, 255, 255))
        if self.query == "":
            renderer.draw_text("Search commands, files, actions...", self.x + 44, self.y + 16, self.font, Color(100, 102, 140, 180))
        # Results
        var max_visible = int((self.h - self.input_h) / self.item_h)
        var show_start = 0
        if self.selected >= max_visible:
            var show_start = self.selected - max_visible + 1
        var ri = 0
        while ri < self.result_count and ri < max_visible:
            var idx = ri + show_start
            if idx >= self.result_count:
                var ri = max_visible
            else:
                var item = self.results[idx]
                var iy = self.y + self.input_h + ri * self.item_h
                var ir = Rect(self.x, iy, self.w, self.item_h)
                if idx == self.selected:
                    renderer.fill_rounded_rect(Rect(self.x + 4, iy + 2, self.w - 8, self.item_h - 4), Color(99, 102, 241, 50), 10)
                    renderer.draw_rounded_rect(Rect(self.x + 4, iy + 2, self.w - 8, self.item_h - 4), Color(99, 102, 241, 80), 10, 1)
                # Icon badge
                renderer.fill_rounded_rect(Rect(self.x + 12, iy + 10, 28, 24), Color(99, 102, 241, 30), 8)
                renderer.draw_text(item.icon, self.x + 16, iy + 11, self.font_icon, Color(180, 182, 240, 230))
                # Label
                renderer.draw_text(item.label, self.x + 52, iy + 8, self.font_bold, Color(220, 222, 255, 240))
                # Category badge
                var cat_w = len(item.category) * 7 + 12
                renderer.fill_rounded_rect(Rect(self.x + 52, iy + 26, cat_w, 14), Color(255, 255, 255, 10), 7)
                renderer.draw_text(item.category, self.x + 58, iy + 27, self.font_small, Color(140, 142, 180, 180))
                # Shortcut
                if item.shortcut != "":
                    var sw = len(item.shortcut) * 7 + 10
                    renderer.fill_rounded_rect(Rect(self.x + self.w - sw - 12, iy + 13, sw, 18), Color(255, 255, 255, 8), 6)
                    renderer.draw_text(item.shortcut, self.x + self.w - sw - 7, iy + 14, self.font_small, Color(160, 162, 200, 160))
                ri = ri + 1
        # Empty state
        if self.result_count == 0:
            renderer.draw_text("No results for  \"" + self.query + "\"", self.x + int(self.w / 2) - 80, self.y + self.input_h + 50, self.font, Color(100, 102, 140, 180))
        # Footer hint
        var footer_y = self.y + self.h - 26
        renderer.fill_rect(Rect(self.x, footer_y, self.w, 1), Color(255, 255, 255, 10))
        renderer.draw_text("^v navigate", self.x + 12, footer_y + 8, self.font_small, Color(100, 102, 140, 160))
        renderer.draw_text("Enter execute", self.x + 100, footer_y + 8, self.font_small, Color(100, 102, 140, 160))
        renderer.draw_text("esc dismiss", self.x + 175, footer_y + 8, self.font_small, Color(100, 102, 140, 160))
        var total_str = str(self.result_count) + " results"
        renderer.draw_text(total_str, self.x + self.w - len(total_str) * 7 - 12, footer_y + 8, self.font_small, Color(100, 102, 140, 140))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

# ─── NotificationBell ─────────────────────────────────────────────────────────
# Animated bell icon with wiggle, unread badge, and drop-down panel
# showing recent notifications with type-colored left borders.

class NotificationBell:
    def __init__(self, cx, cy, size):
        self.cx = cx
        self.cy = cy
        self.size = size
        self.unread = 0
        self.items = []
        self.item_count = 0
        self.panel_open = false
        self.wiggle_t = 0.0
        self.wiggle_active = false
        self.panel_w = 300
        self.panel_h = 0
        self.item_h = 60
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.font_icon = Font("sans-serif", int(size * 0.55), false, false)
        self.icon_color = Color(200, 202, 230, 220)
        self.bg_color = Color(28, 30, 46, 250)
        self.visible = true
        self.id = ""
        self._on_open = none

    def add_notification(self, title, body, type_name):
        self.items.append({"title": title, "body": body, "type": type_name, "read": false})
        self.item_count = self.item_count + 1
        self.unread = self.unread + 1
        self.wiggle_active = true
        self.wiggle_t = 0.0
        self.panel_h = min(self.item_count * self.item_h + 48, 340)
        return self

    def mark_all_read(self):
        var i = 0
        while i < self.item_count:
            self.items[i]["read"] = true
            i = i + 1
        self.unread = 0
        return self

    def on_open(self, fn):
        self._on_open = fn
        return self

    def _type_color(self, t):
        if t == "success":
            return Color(52, 199, 89, 255)
        if t == "error":
            return Color(255, 59, 48, 255)
        if t == "warning":
            return Color(255, 149, 0, 255)
        return Color(99, 102, 241, 255)

    def update(self):
        if self.wiggle_active:
            self.wiggle_t = self.wiggle_t + 0.25
            if self.wiggle_t > 6.28:
                self.wiggle_active = false
                self.wiggle_t = 0.0

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var r = int(self.size / 2)
            var dx = event.x - self.cx
            var dy = event.y - self.cy
            if dx * dx + dy * dy <= r * r:
                self.panel_open = not self.panel_open
                if self.panel_open:
                    self.mark_all_read()
                    if self._on_open != none:
                        self._on_open()
                event.consume()
            elif self.panel_open:
                var panel_x = self.cx - self.panel_w + self.size
                var panel_y = self.cy + self.size + 4
                var pr = Rect(panel_x, panel_y, self.panel_w, self.panel_h)
                if not pr.contains(event.x, event.y):
                    self.panel_open = false

    def _draw(self, renderer):
        # Bell with wiggle animation
        var wiggle_offset = 0
        if self.wiggle_active:
            var wsin = self.wiggle_t * 4.0
            var period = int(wsin) % 6
            if period < 3:
                var wiggle_offset = 3
            else:
                wiggle_offset = -3
        var bell_r = int(self.size / 2)
        # Glow behind bell when panel open or unread > 0
        if self.panel_open or self.unread > 0:
            renderer.fill_circle(self.cx + wiggle_offset, self.cy, bell_r + 8, Color(99, 102, 241, 25))
            renderer.fill_circle(self.cx + wiggle_offset, self.cy, bell_r + 4, Color(99, 102, 241, 45))
        renderer.fill_circle(self.cx + wiggle_offset, self.cy, bell_r, Color(40, 42, 60, 230))
        renderer.draw_circle(self.cx + wiggle_offset, self.cy, bell_r, Color(255, 255, 255, 15))
        renderer.draw_text("?", self.cx + wiggle_offset - int(self.size * 0.27), self.cy - int(self.size * 0.32), self.font_icon, self.icon_color)
        # Unread badge
        if self.unread > 0:
            var badge_str = str(self.unread)
            if self.unread > 9:
                var badge_str = "9+"
            var badge_r = Rect(self.cx + bell_r - 6, self.cy - bell_r - 2, len(badge_str) * 7 + 8, 18)
            renderer.fill_rounded_rect(badge_r, Color(255, 59, 48, 255), 9)
            renderer.draw_rounded_rect(badge_r, Color(0, 0, 0, 80), 9, 1)
            renderer.draw_text(badge_str, badge_r.x + 4, badge_r.y + 2, self.font_small, Color(255, 255, 255, 255))
        # Dropdown panel
        if self.panel_open:
            var panel_x = self.cx - self.panel_w + self.size
            var panel_y = self.cy + bell_r + 10
            var pr = Rect(panel_x, panel_y, self.panel_w, self.panel_h)
            renderer.draw_shadow(pr, 24, 0, 8, Color(0, 0, 0, 100))
            renderer.fill_rounded_rect(pr, self.bg_color, 12)
            renderer.draw_rounded_rect(pr, Color(255, 255, 255, 18), 12, 1)
            # Header
            var hdr_r = Rect(panel_x, panel_y, self.panel_w, 40)
            renderer.fill_rounded_rect(hdr_r, Color(255, 255, 255, 6), 12)
            renderer.draw_text("Notifications", panel_x + 14, panel_y + 12, self.font_bold, Color(220, 222, 255, 230))
            renderer.draw_text("Mark all read", panel_x + self.panel_w - 90, panel_y + 12, self.font_small, Color(99, 102, 241, 200))
            renderer.fill_rect(Rect(panel_x, panel_y + 40, self.panel_w, 1), Color(255, 255, 255, 10))
            var max_show = int((self.panel_h - 48) / self.item_h)
            var iy = panel_y + 42
            var i = 0
            while i < self.item_count and i < max_show:
                var item = self.items[self.item_count - 1 - i]
                var ir = Rect(panel_x, iy, self.panel_w, self.item_h)
                if not item["read"]:
                    renderer.fill_rect(ir, Color(99, 102, 241, 12))
                var tc = self._type_color(item["type"])
                renderer.fill_rect(Rect(panel_x + 2, iy + 8, 3, self.item_h - 16), tc)
                renderer.draw_text(item["title"], panel_x + 14, iy + 10, self.font_bold, Color(220, 222, 255, 230))
                var body_short = item["body"]
                if len(body_short) > 35:
                    body_short = body_short[0:35] + "..."
                renderer.draw_text(body_short, panel_x + 14, iy + 30, self.font_small, Color(140, 142, 180, 180))
                renderer.fill_rect(Rect(panel_x + 8, iy + self.item_h - 1, self.panel_w - 16, 1), Color(255, 255, 255, 8))
                iy = iy + self.item_h
                i = i + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, cx, cy):
        self.cx = cx
        self.cy = cy
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── GradientButton ───────────────────────────────────────────────────────────
# Multi-stop gradient fill button with shimmer sweep, ripple click,
# glowing border, icon support, and pressed depth effect.

class GradientButton:
    def __init__(self, x, y, w, h, label):
        self.rect = Rect(x, y, w, h)
        self.label = label
        self.icon = ""
        self.color_a = Color(99, 102, 241, 255)
        self.color_b = Color(168, 85, 247, 255)
        self.text_color = Color(255, 255, 255, 255)
        self.radius = 12
        self.pressed = false
        self.hovered = false
        self.shimmer_x = -1.0
        self.shimmer_speed = 0.025
        self.ripple_x = 0
        self.ripple_y = 0
        self.ripple_r = 0.0
        self.ripple_alpha = 0
        self.ripple_active = false
        self.disabled = false
        self.font = Font("sans-serif", 14, true, false)
        self.font_icon = Font("sans-serif", 16, false, false)
        self.visible = true
        self.id = ""
        self._eh_counts = {}
        self._event_handlers = {}

    def on(self, event, handler):
        var count = self._eh_counts[event]
        if count == none:
            var count = 0
        self._event_handlers[event + "_" + str(count)] = handler
        self._eh_counts[event] = count + 1
        return self

    def emit(self, event):
        var count = self._eh_counts[event.type]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self._event_handlers[event.type + "_" + str(i)]
            if h != none:
                h(event)
            i = i + 1

    def set_gradient(self, a, b):
        self.color_a = a
        self.color_b = b
        return self

    def set_icon(self, icon):
        self.icon = icon
        return self

    def set_radius(self, r):
        self.radius = r
        return self

    def enable(self):
        self.disabled = false
        return self

    def disable(self):
        self.disabled = true
        return self

    def update(self):
        if self.shimmer_x < 0.0 and not self.hovered:
            pass
        elif self.hovered:
            self.shimmer_x = self.shimmer_x + self.shimmer_speed
            if self.shimmer_x > 1.5:
                self.shimmer_x = -0.3
        if self.ripple_active:
            self.ripple_r = self.ripple_r + float(self.rect.w) * 0.06
            self.ripple_alpha = self.ripple_alpha - 12
            if self.ripple_alpha <= 0 or self.ripple_r > float(self.rect.w):
                self.ripple_active = false
                self.ripple_r = 0.0
                self.ripple_alpha = 0

    def handle_event(self, event):
        if not self.visible or self.disabled:
            return
        if event.type == "mousemove":
            self.hovered = self.rect.contains(event.x, event.y)
            if self.hovered and self.shimmer_x < 0.0:
                self.shimmer_x = -0.3
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            self.pressed = true
            self.ripple_active = true
            self.ripple_x = event.x
            self.ripple_y = event.y
            self.ripple_r = 0.0
            self.ripple_alpha = 160
            event.consume()
        elif event.type == "mouseup" and self.pressed:
            self.pressed = false
            if self.rect.contains(event.x, event.y):
                var ev = Event("click")
                ev.target = self
                self.emit(ev)
            event.consume()
        elif event.type == "mouseleave":
            self.hovered = false
            self.shimmer_x = -1.0

    def _draw(self, renderer):
        var depth = 2 if self.pressed else 0
        var dr = Rect(self.rect.x + depth, self.rect.y + depth, self.rect.w, self.rect.h)
        # Multi-layer shadow (glow)
        if not self.disabled:
            renderer.draw_shadow(dr, 20, 0, 6, Color(self.color_a.r, self.color_a.g, self.color_a.b, 60))
            renderer.draw_shadow(dr, 8, 0, 2, Color(self.color_a.r, self.color_a.g, self.color_a.b, 40))
        # Gradient fill (3 horizontal strips simulating a gradient)
        var n_strips = 8
        var sw = int(dr.w / n_strips)
        var i = 0
        while i < n_strips:
            var t = float(i) / float(n_strips - 1)
            var r = int(float(self.color_a.r) + t * float(self.color_b.r - self.color_a.r))
            var g = int(float(self.color_a.g) + t * float(self.color_b.g - self.color_a.g))
            var b_ch = int(float(self.color_a.b) + t * float(self.color_b.b - self.color_a.b))
            var strip_r = Rect(dr.x + i * sw, dr.y, sw + 1, dr.h)
            renderer.fill_rounded_rect(strip_r, Color(r, g, b_ch, 255), self.radius)
            i = i + 1
        # Top highlight (glass effect)
        renderer.fill_rounded_rect(Rect(dr.x, dr.y, dr.w, int(dr.h / 2)), Color(255, 255, 255, 22), self.radius)
        # Shimmer sweep
        if self.shimmer_x >= 0.0:
            var sx = dr.x + int(self.shimmer_x * float(dr.w)) - 30
            renderer.set_clip(dr)
            renderer.fill_rounded_rect(Rect(sx, dr.y, 60, dr.h), Color(255, 255, 255, 35), self.radius)
            renderer.clear_clip()
        # Glowing border
        renderer.draw_rounded_rect(dr, Color(255, 255, 255, 50), self.radius, 1)
        # Ripple effect
        if self.ripple_active:
            renderer.set_clip(dr)
            renderer.fill_circle(self.ripple_x, self.ripple_y, int(self.ripple_r), Color(255, 255, 255, self.ripple_alpha))
            renderer.clear_clip()
        # Disabled overlay
        if self.disabled:
            renderer.fill_rounded_rect(dr, Color(0, 0, 0, 100), self.radius)
        # Icon + Label
        var content_w = len(self.label) * 8
        if self.icon != "":
            content_w = content_w + 24
        var tx = dr.x + int((dr.w - content_w) / 2)
        if self.icon != "":
            renderer.draw_text(self.icon, tx, dr.y + int((dr.h - 18) / 2), self.font_icon, self.text_color)
            tx = tx + 24
        renderer.draw_text(self.label, tx, dr.y + int((dr.h - 14) / 2), self.font, self.text_color)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── AnimatedCounter ──────────────────────────────────────────────────────────
# Smooth number roll-up animation with prefix/suffix, locale-style
# comma formatting, color-coded delta indicator, and sparkline history.

class AnimatedCounter:
    def __init__(self, x, y, w, h, label):
        self.rect = Rect(x, y, w, h)
        self.label = label
        self.target = 0.0
        self.current = 0.0
        self.display = 0.0
        self.speed = 0.08
        self.prefix = ""
        self.suffix = ""
        self.decimals = 0
        self.delta = 0.0
        self.show_delta = true
        self.history = []
        self.history_max = 20
        self.history_count = 0
        self.sparkline_color = Color(99, 102, 241, 200)
        self.up_color = Color(52, 199, 89, 255)
        self.down_color = Color(255, 59, 48, 255)
        self.value_color = Color(235, 237, 255, 255)
        self.bg_color = Color(30, 32, 48, 255)
        self.border_color = Color(255, 255, 255, 12)
        self.theme = Theme()
        self.font_label = Font("sans-serif", 12, false, false)
        self.font_value = Font("sans-serif", 32, true, false)
        self.font_delta = Font("sans-serif", 12, false, false)
        self.visible = true
        self.id = ""

    def set_value(self, val):
        self.delta = val - self.target
        self.target = val
        self.history.append(val)
        self.history_count = self.history_count + 1
        if self.history_count > self.history_max:
            self.history = self.history[1:self.history_count]
            self.history_count = self.history_max
        return self

    def set_prefix(self, p):
        self.prefix = p
        return self

    def set_suffix(self, s):
        self.suffix = s
        return self

    def set_decimals(self, d):
        self.decimals = d
        return self

    def _format(self, val):
        var base = str(int(val))
        var result = ""
        var n = len(base)
        var i = 0
        while i < n:
            result = result + base[i:i+1]
            var remaining = n - i - 1
            if remaining > 0 and remaining % 3 == 0:
                result = result + ","
            i = i + 1
        return self.prefix + result + self.suffix

    def update(self):
        var diff = self.target - self.display
        if diff > 0.5 or diff < -0.5:
            self.display = self.display + diff * self.speed * 10.0
        else:
            self.display = self.target

    def _draw(self, renderer):
        # Card background
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 60))
        renderer.fill_rounded_rect(self.rect, self.bg_color, 14)
        renderer.draw_rounded_rect(self.rect, self.border_color, 14, 1)
        # Inner top highlight
        renderer.fill_rounded_rect(Rect(self.rect.x + 1, self.rect.y + 1, self.rect.w - 2, 2), Color(255, 255, 255, 15), 14)
        # Label
        renderer.draw_text(self.label, self.rect.x + 16, self.rect.y + 14, self.font_label, self.theme.text_secondary)
        # Main value
        var val_str = self._format(self.display)
        var vw = len(val_str) * 18
        renderer.draw_text(val_str, self.rect.x + 16, self.rect.y + 36, self.font_value, self.value_color)
        # Delta indicator
        if self.show_delta and self.delta != 0.0:
            var is_up = (self.delta > 0.0)
            var arrow = "?" if is_up else "?"
            var dc = self.up_color if is_up else self.down_color
            var dabs = self.delta
            if dabs < 0.0:
                dabs = -dabs
            var d_str = arrow + " " + self._format(dabs)
            var badge_w = len(d_str) * 7 + 12
            renderer.fill_rounded_rect(Rect(self.rect.x + 16, self.rect.y + self.rect.h - 30, badge_w, 20), Color(dc.r, dc.g, dc.b, 30), 10)
            renderer.draw_rounded_rect(Rect(self.rect.x + 16, self.rect.y + self.rect.h - 30, badge_w, 20), Color(dc.r, dc.g, dc.b, 80), 10, 1)
            renderer.draw_text(d_str, self.rect.x + 22, self.rect.y + self.rect.h - 27, self.font_delta, dc)
        # Sparkline
        if self.history_count > 1:
            var spark_x = self.rect.right() - 90
            var spark_y = self.rect.y + 20
            var spark_w = 80
            var spark_h = self.rect.h - 40
            var mn = self.history[0]
            var mx = self.history[0]
            var hi = 0
            while hi < self.history_count:
                if self.history[hi] < mn:
                    var mn = self.history[hi]
                if self.history[hi] > mx:
                    var mx = self.history[hi]
                hi = hi + 1
            var spark_range = mx - mn
            if spark_range <= 0.0:
                var spark_range = 1.0
            var pi = 0
            while pi < self.history_count - 1:
                var t0 = float(pi) / float(self.history_count - 1)
                var t1 = float(pi + 1) / float(self.history_count - 1)
                var y0 = spark_y + spark_h - int((self.history[pi] - mn) / spark_range * float(spark_h))
                var y1 = spark_y + spark_h - int((self.history[pi + 1] - mn) / spark_range * float(spark_h))
                var x0 = spark_x + int(t0 * float(spark_w))
                var x1 = spark_x + int(t1 * float(spark_w))
                renderer.draw_line(x0, y0, x1, y1, self.sparkline_color, 2)
                renderer.draw_line(x0, y0, x1, y1, Color(self.sparkline_color.r, self.sparkline_color.g, self.sparkline_color.b, 60), 5)
                pi = pi + 1
            var last_t = float(self.history_count - 1) / float(self.history_count - 1)
            var last_x = spark_x + spark_w
            var last_y = spark_y + spark_h - int((self.history[self.history_count - 1] - mn) / spark_range * float(spark_h))
            renderer.fill_circle(last_x, last_y, 4, self.sparkline_color)
            renderer.fill_circle(last_x, last_y, 2, Color(255, 255, 255, 200))

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── SplitPane ────────────────────────────────────────────────────────────────
# Resizable split pane with animated divider handle, hover glow,
# min/max size constraints, and horizontal/vertical layout.

class SplitPane:
    def __init__(self, x, y, w, h, orientation):
        self.rect = Rect(x, y, w, h)
        self.orientation = orientation
        self.split = 0.5
        self.min_split = 0.15
        self.max_split = 0.85
        self.divider_size = 6
        self.pane_a = none
        self.pane_b = none
        self.dragging = false
        self.hovered = false
        self.handle_alpha = 60
        self.accent = Color(99, 102, 241, 255)
        self.divider_color = Color(60, 62, 85, 255)
        self.theme = Theme()
        self.visible = true
        self.id = ""
        self._on_resize = none

    def set_panes(self, a, b):
        self.pane_a = a
        self.pane_b = b
        self._layout()
        return self

    def set_split(self, ratio):
        if ratio < self.min_split:
            var ratio = self.min_split
        if ratio > self.max_split:
            ratio = self.max_split
        self.split = ratio
        self._layout()
        return self

    def on_resize(self, fn):
        self._on_resize = fn
        return self

    def _layout(self):
        if self.orientation == "horizontal":
            var split_px = int(self.split * float(self.rect.w))
            if self.pane_a != none:
                self.pane_a.set_pos(self.rect.x, self.rect.y)
                self.pane_a.set_size(split_px - int(self.divider_size / 2), self.rect.h)
            if self.pane_b != none:
                var bx = self.rect.x + split_px + int(self.divider_size / 2)
                self.pane_b.set_pos(bx, self.rect.y)
                self.pane_b.set_size(self.rect.w - split_px - int(self.divider_size / 2), self.rect.h)
        else:
            var split_px = int(self.split * float(self.rect.h))
            if self.pane_a != none:
                self.pane_a.set_pos(self.rect.x, self.rect.y)
                self.pane_a.set_size(self.rect.w, split_px - int(self.divider_size / 2))
            if self.pane_b != none:
                var by = self.rect.y + split_px + int(self.divider_size / 2)
                self.pane_b.set_pos(self.rect.x, by)
                self.pane_b.set_size(self.rect.w, self.rect.h - split_px - int(self.divider_size / 2))

    def _divider_rect(self):
        if self.orientation == "horizontal":
            var sp = self.rect.x + int(self.split * float(self.rect.w))
            return Rect(sp - int(self.divider_size / 2), self.rect.y, self.divider_size, self.rect.h)
        var sp = self.rect.y + int(self.split * float(self.rect.h))
        return Rect(self.rect.x, sp - int(self.divider_size / 2), self.rect.w, self.divider_size)

    def handle_event(self, event):
        if not self.visible:
            return
        var dr = self._divider_rect()
        if event.type == "mousemove":
            self.hovered = dr.contains(event.x, event.y)
            if self.hovered:
                self.handle_alpha = 200
            elif not self.dragging:
                self.handle_alpha = 60
            if self.dragging:
                if self.orientation == "horizontal":
                    var ratio = float(event.x - self.rect.x) / float(self.rect.w)
                    self.set_split(ratio)
                else:
                    var ratio = float(event.y - self.rect.y) / float(self.rect.h)
                    self.set_split(ratio)
                if self._on_resize != none:
                    self._on_resize(self.split)
        elif event.type == "mousedown" and dr.contains(event.x, event.y):
            self.dragging = true
            event.consume()
        elif event.type == "mouseup":
            self.dragging = false
        if self.pane_a != none:
            self.pane_a.handle_event(event)
        if self.pane_b != none:
            self.pane_b.handle_event(event)

    def _draw(self, renderer):
        if self.pane_a != none:
            self.pane_a.draw(renderer)
        if self.pane_b != none:
            self.pane_b.draw(renderer)
        var dr = self._divider_rect()
        renderer.fill_rect(dr, self.divider_color)
        # Divider handle dots
        var cx = dr.center_x()
        var cy = dr.center_y()
        renderer.fill_rounded_rect(Rect(cx - 1, cy, 2, 20), Color(self.accent.r, self.accent.g, self.accent.b, self.handle_alpha), 1)
        renderer.fill_circle(cx, cy - 12, 2, Color(self.accent.r, self.accent.g, self.accent.b, self.handle_alpha))
        renderer.fill_circle(cx, cy, 2, Color(self.accent.r, self.accent.g, self.accent.b, self.handle_alpha))
        renderer.fill_circle(cx, cy + 12, 2, Color(self.accent.r, self.accent.g, self.accent.b, self.handle_alpha))
        if self.hovered or self.dragging:
            renderer.fill_rect(dr, Color(self.accent.r, self.accent.g, self.accent.b, 15))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        self._layout()
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        self._layout()
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self


# ═══════════════════════════════════════════════════════════════════════════════
# WAVE 4  -  PREMIUM EXCEPTIONAL WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

# ─── RadarChart ───────────────────────────────────────────────────────────────
# Multi-axis polygon radar with glow fills, animated draw-in, axis labels,
# value dots, tick rings, and multi-series support.

class RadarSeries:
    def __init__(self, name, values, color):
        self.name = name
        self.values = values
        self.color = color
        self.fill_alpha = 45
        self.line_w = 2
        self.show_dots = true


class RadarChart:
    def __init__(self, cx, cy, radius):
        self.cx = cx
        self.cy = cy
        self.radius = radius
        self.axes = []
        self.axis_count = 0
        self.series = []
        self.series_count = 0
        self.rings = 5
        self.title = ""
        self.anim_progress = 0.0
        self.animate = true
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 14, true, false)
        self.font_axis = Font("sans-serif", 11, false, false)
        self.ring_color = Color(255, 255, 255, 12)
        self.axis_color = Color(255, 255, 255, 20)
        self.bg_color = Color(28, 30, 46, 255)
        self.show_legend = true
        self.visible = true
        self.id = ""

    def add_axis(self, label):
        self.axes.append(label)
        self.axis_count = self.axis_count + 1
        return self

    def add_series(self, series):
        self.series.append(series)
        self.series_count = self.series_count + 1
        return self

    def set_title(self, t):
        self.title = t
        return self

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.04
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def _axis_point(self, axis_idx, dist):
        if self.axis_count == 0:
            return [self.cx, self.cy]
        var angle = float(axis_idx) / float(self.axis_count) * 360.0 - 90.0
        var rad_approx = angle * 3.14159 / 180.0
        var steps = int(angle / 30.0)
        var sin_table = [0.0, 0.5, 0.866, 1.0, 0.866, 0.5, 0.0, -0.5, -0.866, -1.0, -0.866, -0.5]
        var cos_table = [1.0, 0.866, 0.5, 0.0, -0.5, -0.866, -1.0, -0.866, -0.5, 0.0, 0.5, 0.866]
        var seg = int((angle + 360.0) % 360.0 / 30.0) % 12
        var px = self.cx + int(float(dist) * cos_table[seg])
        var py = self.cy + int(float(dist) * sin_table[seg])
        return [px, py]

    def _draw(self, renderer):
        var size = self.radius * 2 + 80
        var bg_r = Rect(self.cx - self.radius - 40, self.cy - self.radius - 40, size, size)
        renderer.draw_shadow(bg_r, 20, 0, 6, Color(0, 0, 0, 60))
        renderer.fill_rounded_rect(bg_r, self.bg_color, 16)
        renderer.draw_rounded_rect(bg_r, Color(255, 255, 255, 12), 16, 1)
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, self.cx - int(tw / 2), self.cy - self.radius - 30, self.font_title, self.theme.text)
        # Concentric rings
        var ri = 1
        while ri <= self.rings:
            var ring_r = int(float(ri) / float(self.rings) * float(self.radius))
            renderer.draw_circle(self.cx, self.cy, ring_r, self.ring_color)
            ri = ri + 1
        # Axis spokes
        var ai = 0
        while ai < self.axis_count:
            var tip = self._axis_point(ai, self.radius)
            renderer.draw_line(self.cx, self.cy, tip[0], tip[1], self.axis_color, 1)
            # Axis label (with padding past the ring)
            var lp = self._axis_point(ai, self.radius + 18)
            var lbl = self.axes[ai]
            var lw = len(lbl) * 6
            renderer.draw_text(lbl, lp[0] - int(lw / 2), lp[1] - 6, self.font_axis, self.theme.text_secondary)
            ai = ai + 1
        # Series polygons
        var si = 0
        while si < self.series_count:
            var ser = self.series[si]
            var n = len(ser.values)
            if n == 0 or self.axis_count == 0:
                si = si + 1
            else:
                var pts = []
                var vi = 0
                while vi < self.axis_count:
                    var val = 0.0
                    if vi < n:
                        var val = ser.values[vi]
                    if val > 1.0:
                        val = 1.0
                    if val < 0.0:
                        val = 0.0
                    val = val * self.anim_progress
                    var dist = int(val * float(self.radius))
                    var pt = self._axis_point(vi, dist)
                    pts.append(pt)
                    vi = vi + 1
                # Draw fill polygon
                renderer.fill_polygon(pts, Color(ser.color.r, ser.color.g, ser.color.b, ser.fill_alpha))
                # Glow outer ring of polygon
                renderer.draw_polygon(pts, Color(ser.color.r, ser.color.g, ser.color.b, 100), ser.line_w + 3)
                # Crisp outline
                renderer.draw_polygon(pts, ser.color, ser.line_w)
                # Value dots with glow
                if ser.show_dots:
                    var di = 0
                    while di < len(pts):
                        renderer.fill_circle(pts[di][0], pts[di][1], 5, Color(ser.color.r, ser.color.g, ser.color.b, 80))
                        renderer.fill_circle(pts[di][0], pts[di][1], 3, ser.color)
                        renderer.fill_circle(pts[di][0], pts[di][1], 1, Color(255, 255, 255, 200))
                        di = di + 1
                si = si + 1
        # Legend
        if self.show_legend and self.series_count > 0:
            var lx = self.cx - self.radius - 30
            var ly = self.cy + self.radius + 20
            var li = 0
            while li < self.series_count:
                renderer.fill_rounded_rect(Rect(lx, ly + 2, 10, 10), self.series[li].color, 5)
                renderer.draw_text(self.series[li].name, lx + 14, ly, self.font, self.theme.text_secondary)
                lx = lx + len(self.series[li].name) * 7 + 28
                li = li + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, cx, cy):
        self.cx = cx
        self.cy = cy
        return self

    def set_radius(self, r):
        self.radius = r
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── SideNav ──────────────────────────────────────────────────────────────────
# Collapsible sidebar with icon+label items, active highlight bar,
# unread badges, section headings, bottom profile slot, and hover glow.

class SideNavItem:
    def __init__(self, id, label, icon):
        self.id = id
        self.label = label
        self.icon = icon
        self.badge = 0
        self.badge_color = Color(255, 59, 48, 255)
        self.section = ""
        self.active = false
        self.divider_before = false

    def set_badge(self, count):
        self.badge = count
        return self

    def set_divider(self):
        self.divider_before = true
        return self


class SideNav:
    def __init__(self, x, y, h):
        self.x = x
        self.y = y
        self.h = h
        self.w_expanded = 220
        self.w_collapsed = 56
        self.w = 220
        self.collapsed = false
        self.items = []
        self.item_count = 0
        self.active_id = ""
        self.hovered_id = ""
        self.item_h = 44
        self.top_h = 56
        self.bottom_h = 60
        self.profile_name = ""
        self.profile_initial = "?"
        self.profile_color = Color(99, 102, 241, 255)
        self.bg_color = Color(18, 20, 32, 255)
        self.accent = Color(99, 102, 241, 255)
        self.surface = Color(30, 32, 48, 255)
        self.border_color = Color(255, 255, 255, 10)
        self.logo = "*"
        self.app_name = "App"
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_bold = Font("sans-serif", 13, true, false)
        self.font_icon = Font("sans-serif", 17, false, false)
        self.font_section = Font("sans-serif", 10, true, false)
        self.font_logo = Font("sans-serif", 20, true, false)
        self.visible = true
        self.id = ""
        self._on_select = none

    def add_item(self, id, label, icon):
        var item = SideNavItem(id, label, icon)
        self.items.append(item)
        self.item_count = self.item_count + 1
        return self

    def add_section(self, id, label, icon, section_name):
        var item = SideNavItem(id, label, icon)
        item.section = section_name
        item.divider_before = true
        self.items.append(item)
        self.item_count = self.item_count + 1
        return self

    def set_badge(self, id, count):
        var i = 0
        while i < self.item_count:
            if self.items[i].id == id:
                self.items[i].badge = count
            i = i + 1
        return self

    def set_active(self, id):
        self.active_id = id
        var i = 0
        while i < self.item_count:
            self.items[i].active = (self.items[i].id == id)
            i = i + 1
        return self

    def set_profile(self, name):
        self.profile_name = name
        if len(name) > 0:
            self.profile_initial = name[0:1]
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def toggle(self):
        self.collapsed = not self.collapsed
        if self.collapsed:
            self.w = self.w_collapsed
        else:
            self.w = self.w_expanded
        return self

    def expand(self):
        self.collapsed = false
        self.w = self.w_expanded
        return self

    def collapse(self):
        self.collapsed = true
        self.w = self.w_collapsed
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        var nav_r = Rect(self.x, self.y, self.w, self.h)
        if event.type == "mousemove":
            self.hovered_id = ""
            var iy = self.y + self.top_h
            var i = 0
            while i < self.item_count:
                var ir = Rect(self.x, iy, self.w, self.item_h)
                if ir.contains(event.x, event.y):
                    self.hovered_id = self.items[i].id
                iy = iy + self.item_h
                i = i + 1
        elif event.type == "mousedown" and nav_r.contains(event.x, event.y):
            var iy = self.y + self.top_h
            var i = 0
            while i < self.item_count:
                var ir = Rect(self.x, iy, self.w, self.item_h)
                if ir.contains(event.x, event.y):
                    self.set_active(self.items[i].id)
                    if self._on_select != none:
                        self._on_select(self.items[i])
                    event.consume()
                    i = self.item_count
                else:
                    iy = iy + self.item_h
                    i = i + 1
            # Toggle button
            var toggle_r = Rect(self.x + self.w - 28, self.y + 14, 24, 24)
            if toggle_r.contains(event.x, event.y):
                self.toggle()
                event.consume()

    def _draw(self, renderer):
        var nav_r = Rect(self.x, self.y, self.w, self.h)
        renderer.fill_rect(nav_r, self.bg_color)
        renderer.draw_line(self.x + self.w - 1, self.y, self.x + self.w - 1, self.y + self.h, self.border_color, 1)
        # Logo/header
        var hdr = Rect(self.x, self.y, self.w, self.top_h)
        renderer.fill_rect(hdr, Color(0, 0, 0, 30))
        renderer.draw_line(self.x, self.y + self.top_h - 1, self.x + self.w, self.y + self.top_h - 1, self.border_color, 1)
        # Logo icon with glow
        renderer.fill_rounded_rect(Rect(self.x + 12, self.y + 12, 30, 30), Color(self.accent.r, self.accent.g, self.accent.b, 30), 8)
        renderer.draw_text(self.logo, self.x + 17, self.y + 14, self.font_logo, self.accent)
        if not self.collapsed:
            renderer.draw_text(self.app_name, self.x + 50, self.y + 18, self.font_bold, self.theme.text)
            # Collapse toggle chevron
            renderer.draw_text("?", self.x + self.w - 22, self.y + 16, self.font_bold, Color(120, 122, 160, 180))
        else:
            renderer.draw_text("?", self.x + 20, self.y + 16, self.font_bold, Color(120, 122, 160, 180))
        # Nav items
        var iy = self.y + self.top_h
        var i = 0
        while i < self.item_count:
            var item = self.items[i]
            var is_active = (item.id == self.active_id)
            var is_hovered = (item.id == self.hovered_id)
            var ir = Rect(self.x, iy, self.w, self.item_h)
            # Section heading
            if item.divider_before and not self.collapsed and item.section != "":
                renderer.draw_line(self.x + 12, iy - 4, self.x + self.w - 12, iy - 4, Color(255, 255, 255, 8), 1)
                renderer.draw_text(item.section, self.x + 16, iy + 2, self.font_section, Color(100, 102, 140, 180))
                iy = iy + 18
                var ir = Rect(self.x, iy, self.w, self.item_h)
            # Active/hover background
            if is_active:
                renderer.fill_rect(Rect(self.x, iy, self.w, self.item_h), Color(self.accent.r, self.accent.g, self.accent.b, 20))
                renderer.fill_rect(Rect(self.x, iy + 6, 3, self.item_h - 12), self.accent)
            elif is_hovered:
                renderer.fill_rect(Rect(self.x, iy, self.w, self.item_h), Color(255, 255, 255, 6))
            # Icon
            var icon_x = self.x + 16
            var icon_color = self.accent if is_active else Color(160, 162, 200, 200)
            if is_active:
                renderer.fill_rounded_rect(Rect(icon_x - 4, iy + 10, 28, 24), Color(self.accent.r, self.accent.g, self.accent.b, 25), 8)
            renderer.draw_text(item.icon, icon_x, iy + 12, self.font_icon, icon_color)
            # Label
            if not self.collapsed:
                var text_color = Color(235, 237, 255, 255) if is_active else Color(160, 162, 200, 200)
                var lf = self.font_bold if is_active else self.font
                renderer.draw_text(item.label, self.x + 50, iy + 14, lf, text_color)
                # Badge
                if item.badge > 0:
                    var badge_str = str(item.badge)
                    var bw = len(badge_str) * 7 + 10
                    var br = Rect(self.x + self.w - bw - 12, iy + 13, bw, 18)
                    renderer.fill_rounded_rect(br, item.badge_color, 9)
                    renderer.draw_text(badge_str, br.x + 5, br.y + 2, self.font_section, Color(255, 255, 255, 255))
            else:
                if item.badge > 0:
                    renderer.fill_circle(self.x + self.w - 10, iy + 8, 5, item.badge_color)
            iy = iy + self.item_h
            i = i + 1
        # Bottom profile strip
        var bottom_r = Rect(self.x, self.y + self.h - self.bottom_h, self.w, self.bottom_h)
        renderer.fill_rect(bottom_r, Color(0, 0, 0, 25))
        renderer.draw_line(self.x, self.y + self.h - self.bottom_h, self.x + self.w, self.y + self.h - self.bottom_h, self.border_color, 1)
        renderer.fill_circle(self.x + 28, self.y + self.h - 30, 16, self.profile_color)
        renderer.draw_text(string_upper(self.profile_initial), self.x + 22, self.y + self.h - 38, self.font_bold, Color(255, 255, 255, 230))
        if not self.collapsed and self.profile_name != "":
            renderer.draw_text(self.profile_name, self.x + 50, self.y + self.h - 40, self.font_bold, self.theme.text)
            renderer.draw_text("View profile", self.x + 50, self.y + self.h - 22, self.font, Color(99, 102, 241, 180))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── OTPInput ─────────────────────────────────────────────────────────────────
# Beautiful one-time password / verification code input with individual
# digit boxes, focused glow, shake on error, fill animation, auto-advance.

class OTPInput:
    def __init__(self, x, y, digits, box_w, box_h):
        self.x = x
        self.y = y
        self.digits = digits
        self.box_w = box_w
        self.box_h = box_h
        self.box_gap = 10
        self.values = []
        self.focused_idx = 0
        self.focused = false
        self.error = false
        self.success = false
        self.shake_t = 0.0
        self.shake_active = false
        self.accent = Color(99, 102, 241, 255)
        self.error_color = Color(255, 59, 48, 255)
        self.success_color = Color(52, 199, 89, 255)
        self.bg_color = Color(30, 32, 48, 255)
        self.border_color = Color(60, 62, 85, 255)
        self.theme = Theme()
        self.font = Font("sans-serif", int(box_h * 0.45), true, false)
        self.visible = true
        self.enabled = true
        self.id = ""
        self._on_complete = none
        self._on_change = none
        self._init_values()

    def _init_values(self):
        var i = 0
        while i < self.digits:
            self.values.append("")
            i = i + 1

    def get_value(self):
        var result = ""
        var i = 0
        while i < self.digits:
            result = result + self.values[i]
            i = i + 1
        return result

    def is_complete(self):
        var i = 0
        while i < self.digits:
            if self.values[i] == "":
                return false
            i = i + 1
        return true

    def clear(self):
        self.values = []
        self.focused_idx = 0
        self.error = false
        self.success = false
        self._init_values()
        return self

    def set_error(self):
        self.error = true
        self.success = false
        self.shake_active = true
        self.shake_t = 0.0
        return self

    def set_success(self):
        self.success = true
        self.error = false
        return self

    def on_complete(self, fn):
        self._on_complete = fn
        return self

    def on_change(self, fn):
        self._on_change = fn
        return self

    def _set_digit(self, idx, ch):
        if idx >= 0 and idx < self.digits:
            self.values[idx] = ch
            if self._on_change != none:
                self._on_change(self.get_value())
            if self.is_complete() and self._on_complete != none:
                self._on_complete(self.get_value())

    def update(self):
        if self.shake_active:
            self.shake_t = self.shake_t + 0.3
            if self.shake_t > 6.28:
                self.shake_active = false
                self.shake_t = 0.0

    def handle_event(self, event):
        if not self.visible or not self.enabled:
            return
        if event.type == "mousedown":
            var total_w = self.digits * (self.box_w + self.box_gap) - self.box_gap
            var field_r = Rect(self.x, self.y, total_w, self.box_h)
            if field_r.contains(event.x, event.y):
                self.focused = true
                var clicked = int((event.x - self.x) / float(self.box_w + self.box_gap))
                if clicked >= 0 and clicked < self.digits:
                    self.focused_idx = clicked
            else:
                self.focused = false
        elif event.type == "keydown" and self.focused:
            if event.key == "backspace":
                if self.values[self.focused_idx] != "":
                    self._set_digit(self.focused_idx, "")
                elif self.focused_idx > 0:
                    self.focused_idx = self.focused_idx - 1
                    self._set_digit(self.focused_idx, "")
        elif event.type == "textinput" and self.focused:
            var ch = event.text
            if len(ch) == 1:
                self._set_digit(self.focused_idx, ch)
                if self.focused_idx < self.digits - 1:
                    self.focused_idx = self.focused_idx + 1

    def _draw(self, renderer):
        var shake_offset = 0
        if self.shake_active:
            var period = int(self.shake_t * 3) % 4
            if period == 0 or period == 2:
                var shake_offset = 5
            else:
                shake_offset = -5
        var i = 0
        while i < self.digits:
            var bx = self.x + i * (self.box_w + self.box_gap) + shake_offset
            var br = Rect(bx, self.y, self.box_w, self.box_h)
            var is_focused = (self.focused and i == self.focused_idx)
            var is_filled = (self.values[i] != "")
            # Shadow under box
            renderer.draw_shadow(br, 8, 0, 3, Color(0, 0, 0, 50))
            # Box background
            renderer.fill_rounded_rect(br, self.bg_color, 10)
            # Border with state color
            var border_c = self.border_color
            if self.error:
                var border_c = self.error_color
            elif self.success:
                border_c = self.success_color
            elif is_focused:
                border_c = self.accent
            var border_w = 2 if is_focused else 1
            renderer.draw_rounded_rect(br, border_c, 10, border_w)
            # Focus glow
            if is_focused:
                renderer.draw_shadow(br, 14, 0, 4, Color(self.accent.r, self.accent.g, self.accent.b, 60))
            elif self.success and is_filled:
                renderer.draw_shadow(br, 10, 0, 3, Color(self.success_color.r, self.success_color.g, self.success_color.b, 40))
            # Inner highlight
            renderer.fill_rounded_rect(Rect(bx + 2, self.y + 2, self.box_w - 4, 2), Color(255, 255, 255, 15), 8)
            # Digit character
            if is_filled:
                var char_c = Color(235, 237, 255, 255)
                if self.error:
                    var char_c = self.error_color
                elif self.success:
                    char_c = self.success_color
                var cw = len(self.values[i]) * int(self.box_h * 0.24)
                renderer.draw_text(self.values[i], bx + int((self.box_w - cw) / 2), self.y + int(self.box_h * 0.27), self.font, char_c)
            elif is_focused:
                # Blinking cursor (always draw)
                renderer.fill_rect(Rect(bx + int(self.box_w / 2) - 1, self.y + int(self.box_h * 0.25), 2, int(self.box_h * 0.5)), Color(self.accent.r, self.accent.g, self.accent.b, 180))
            i = i + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.x = x
        self.y = y
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

# ─── CodeBlock ────────────────────────────────────────────────────────────────
# Syntax-highlighted code display with line numbers, language badge,
# copy button, scrollable content, and theme-aware token colors.

class CodeBlock:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.code = ""
        self.lines = []
        self.line_count = 0
        self.language = ""
        self.scroll_y = 0
        self.line_h = 20
        self.pad_left = 52
        self.pad_top = 12
        self.copied = false
        self.copy_timer = 0
        self.bg_color = Color(20, 22, 34, 255)
        self.border_color = Color(255, 255, 255, 10)
        self.gutter_color = Color(30, 32, 48, 255)
        self.line_num_color = Color(80, 82, 110, 255)
        self.keyword_color = Color(140, 120, 255, 255)
        self.string_color = Color(160, 220, 100, 255)
        self.comment_color = Color(100, 120, 100, 180)
        self.number_color = Color(255, 180, 80, 255)
        self.func_color = Color(100, 200, 255, 255)
        self.default_color = Color(200, 202, 230, 255)
        self.theme = Theme()
        self.font = Font("monospace", 13, false, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_badge = Font("sans-serif", 10, true, false)
        self.visible = true
        self.id = ""
        self._keywords = ["def", "class", "var", "return", "if", "else", "elif", "while", "for", "in", "import", "not", "and", "or", "true", "false", "none", "int", "float", "str", "len", "print", "self"]

    def set_code(self, code):
        self.code = code
        self.lines = []
        self.line_count = 0
        var remaining = code
        while len(remaining) > 0:
            var nl = string_find(remaining, "\n")
            if nl < 0:
                self.lines.append(remaining)
                self.line_count = self.line_count + 1
                var remaining = ""
            else:
                self.lines.append(remaining[0:nl])
                self.line_count = self.line_count + 1
                remaining = remaining[nl + 1:]
        return self

    def set_language(self, lang):
        self.language = lang
        return self

    def _is_keyword(self, word):
        var i = 0
        while i < len(self._keywords):
            if self._keywords[i] == word:
                return true
            i = i + 1
        return false

    def _token_color(self, token, line):
        if string_startswith(token, "#"):
            return self.comment_color
        if string_startswith(token, "\"") or string_startswith(token, "'"):
            return self.string_color
        if self._is_keyword(token):
            return self.keyword_color
        var is_num = true
        var ci = 0
        while ci < len(token):
            var ch = token[ci:ci+1]
            if ch != "0" and ch != "1" and ch != "2" and ch != "3" and ch != "4" and ch != "5" and ch != "6" and ch != "7" and ch != "8" and ch != "9" and ch != ".":
                var is_num = false
            ci = ci + 1
        if is_num and len(token) > 0:
            return self.number_color
        return self.default_color

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 2
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_scroll = self.line_count * self.line_h - (self.rect.h - self.pad_top * 2 - 40)
            if max_scroll < 0:
                var max_scroll = 0
            if self.scroll_y > max_scroll:
                self.scroll_y = max_scroll
        if self.copy_timer > 0:
            self.copy_timer = self.copy_timer - 1
            if self.copy_timer == 0:
                self.copied = false

    def _draw(self, renderer):
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 70))
        renderer.fill_rounded_rect(self.rect, self.bg_color, 12)
        renderer.draw_rounded_rect(self.rect, self.border_color, 12, 1)
        # Header bar
        var hdr = Rect(self.rect.x, self.rect.y, self.rect.w, 36)
        renderer.fill_rounded_rect(hdr, Color(30, 32, 48, 255), 12)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + 12, self.rect.w, 24), Color(30, 32, 48, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 36, self.rect.right(), self.rect.y + 36, self.border_color, 1)
        # Traffic light dots
        renderer.fill_circle(self.rect.x + 16, self.rect.y + 18, 5, Color(255, 95, 86, 255))
        renderer.fill_circle(self.rect.x + 30, self.rect.y + 18, 5, Color(255, 189, 46, 255))
        renderer.fill_circle(self.rect.x + 44, self.rect.y + 18, 5, Color(39, 201, 63, 255))
        # Language badge
        if self.language != "":
            var lw = len(self.language) * 7 + 12
            renderer.fill_rounded_rect(Rect(self.rect.x + 60, self.rect.y + 9, lw, 18), Color(99, 102, 241, 50), 9)
            renderer.draw_text(self.language, self.rect.x + 66, self.rect.y + 11, self.font_badge, Color(180, 182, 240, 230))
        # Copy button
        var copy_str = "[OK] Copied" if self.copied else "? Copy"
        var cw = len(copy_str) * 7 + 12
        var copy_r = Rect(self.rect.right() - cw - 8, self.rect.y + 8, cw, 20)
        renderer.fill_rounded_rect(copy_r, Color(255, 255, 255, 10), 6)
        renderer.draw_text(copy_str, copy_r.x + 6, copy_r.y + 3, self.font_ui, Color(140, 142, 180, 200))
        # Gutter
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + 36, self.pad_left, self.rect.h - 36), self.gutter_color)
        renderer.draw_line(self.rect.x + self.pad_left, self.rect.y + 36, self.rect.x + self.pad_left, self.rect.bottom(), Color(255, 255, 255, 6), 1)
        # Lines
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 36, self.rect.w, self.rect.h - 36))
        var first_line = int(self.scroll_y / self.line_h)
        var max_visible = int((self.rect.h - 36) / self.line_h) + 2
        var li = first_line
        while li < self.line_count and li < first_line + max_visible:
            var line = self.lines[li]
            var ly = self.rect.y + 36 + self.pad_top + li * self.line_h - self.scroll_y
            # Line number
            var lnum_str = str(li + 1)
            var lnum_x = self.rect.x + self.pad_left - len(lnum_str) * 7 - 8
            renderer.draw_text(lnum_str, lnum_x, ly, self.font, self.line_num_color)
            # Code text (simple rendering - whole line with heuristic coloring)
            var line_color = self.default_color
            var stripped = line
            if string_contains(line, "#"):
                var line_color = self.comment_color
            elif string_startswith(stripped, "def ") or string_startswith(stripped, "    def "):
                line_color = self.func_color
            elif string_startswith(stripped, "class "):
                line_color = self.keyword_color
            elif string_startswith(stripped, "var ") or string_startswith(stripped, "    var ") or string_startswith(stripped, "        var "):
                line_color = self.default_color
            elif string_contains(line, "\"") or string_contains(line, "'"):
                line_color = self.string_color
            renderer.draw_text(line, self.rect.x + self.pad_left + 10, ly, self.font, line_color)
            li = li + 1
        renderer.clear_clip()
        # Scrollbar
        if self.line_count * self.line_h > self.rect.h - 36:
            var content_h = self.line_count * self.line_h
            var view_h = self.rect.h - 36
            var thumb_h = int(float(view_h) / float(content_h) * float(view_h))
            if thumb_h < 24:
                var thumb_h = 24
            var thumb_y = self.rect.y + 36 + int(float(self.scroll_y) / float(content_h) * float(view_h))
            renderer.fill_rounded_rect(Rect(self.rect.right() - 6, thumb_y, 4, thumb_h), Color(99, 102, 241, 100), 2)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Confetti ─────────────────────────────────────────────────────────────────
# Celebration particle burst: physics-driven confetti with gravity,
# rotation, fading, and configurable color palette.

class ConfettiParticle:
    def __init__(self, x, y, vx, vy, color, size, rot, rot_speed):
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.color = color
        self.size = size
        self.rot = rot
        self.rot_speed = rot_speed
        self.alpha = 255
        self.alive = true


class Confetti:
    def __init__(self, window_w, window_h):
        self.window_w = window_w
        self.window_h = window_h
        self.particles = []
        self.particle_count = 0
        self.active = false
        self.gravity = 0.35
        self.drag = 0.99
        self.colors = [
            Color(99, 102, 241, 255),
            Color(168, 85, 247, 255),
            Color(52, 199, 89, 255),
            Color(255, 149, 0, 255),
            Color(255, 59, 48, 255),
            Color(0, 199, 190, 255),
            Color(255, 214, 0, 255)
        ]
        self.color_count = 7
        self.visible = true
        self.id = ""

    def burst(self, cx, cy, count):
        self.active = true
        var i = 0
        while i < count:
            var angle_step = float(i) * 137.5
            var speed = 4.0 + float(i % 5) * 1.5
            var angle_rad = angle_step * 3.14159 / 180.0
            var vx_approx = speed * float((i * 7) % 20 - 10) / 10.0
            var vy_approx = -(speed * 0.6 + float(i % 4) * 0.8)
            var c_idx = i % self.color_count
            var p = ConfettiParticle(
                float(cx) + float((i * 13) % 60 - 30),
                float(cy),
                vx_approx,
                vy_approx,
                self.colors[c_idx],
                4 + (i % 4) * 2,
                float(i * 23 % 360),
                float((i % 7) - 3) * 0.15
            )
            self.particles.append(p)
            self.particle_count = self.particle_count + 1
            i = i + 1

    def rain(self, count):
        self.active = true
        var i = 0
        while i < count:
            var c_idx = i % self.color_count
            var p = ConfettiParticle(
                float(i * (self.window_w / count)),
                float(-10 - i * 3 % 50),
                float((i % 6) - 3) * 0.5,
                float(2 + i % 4),
                self.colors[c_idx],
                4 + (i % 4) * 2,
                float(i * 17 % 360),
                float((i % 5) - 2) * 0.12
            )
            self.particles.append(p)
            self.particle_count = self.particle_count + 1
            i = i + 1

    def clear(self):
        self.particles = []
        self.particle_count = 0
        self.active = false
        return self

    def is_done(self):
        var i = 0
        while i < self.particle_count:
            if self.particles[i].alive:
                return false
            i = i + 1
        return true

    def update(self):
        if not self.active:
            return
        var still_alive = false
        var i = 0
        while i < self.particle_count:
            var p = self.particles[i]
            if p.alive:
                p.x = p.x + p.vx
                p.y = p.y + p.vy
                p.vy = p.vy + self.gravity
                p.vx = p.vx * self.drag
                p.rot = p.rot + p.rot_speed * 10.0
                p.alpha = p.alpha - 2
                if p.alpha <= 0 or p.y > float(self.window_h + 20):
                    p.alive = false
                else:
                    var still_alive = true
            i = i + 1
        if not still_alive:
            self.active = false

    def _draw(self, renderer):
        var i = 0
        while i < self.particle_count:
            var p = self.particles[i]
            if p.alive:
                var px = int(p.x)
                var py = int(p.y)
                var c = Color(p.color.r, p.color.g, p.color.b, p.alpha)
                # Draw as small rect or circle based on size
                if p.size <= 6:
                    renderer.fill_rect(Rect(px - int(p.size / 2), py - int(p.size / 2), p.size, p.size), c)
                else:
                    renderer.fill_rounded_rect(Rect(px - int(p.size / 2), py - int(p.size / 2), p.size, p.size), c, 2)
            i = i + 1

    def draw(self, renderer):
        if self.visible and self.active:
            self.update()
            self._draw(renderer)

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── TreeMap ──────────────────────────────────────────────────────────────────
# Animated squarified treemap with gradient fills, hover highlight,
# value labels, breadcrumb path, and drill-down support.

class TreeMapNode:
    def __init__(self, label, value, color):
        self.label = label
        self.value = value
        self.color = color
        self.children = []
        self.child_count = 0
        self.rect = Rect(0, 0, 0, 0)
        self.parent = none
        self.depth = 0

    def add_child(self, node):
        node.parent = self
        node.depth = self.depth + 1
        self.children.append(node)
        self.child_count = self.child_count + 1
        return self

    def total_value(self):
        if self.child_count == 0:
            return self.value
        var tot = 0.0
        var i = 0
        while i < self.child_count:
            tot = tot + self.children[i].total_value()
            i = i + 1
        return tot


class TreeMap:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.root = none
        self.hovered = none
        self.anim_progress = 0.0
        self.animate = true
        self.gap = 3
        self.min_label_w = 60
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_label = Font("sans-serif", 12, true, false)
        self.font_val = Font("sans-serif", 10, false, false)
        self.title = ""
        self.font_title = Font("sans-serif", 14, true, false)
        self.visible = true
        self.id = ""
        self._on_click = none

    def set_root(self, node):
        self.root = node
        return self

    def set_title(self, t):
        self.title = t
        return self

    def on_click(self, fn):
        self._on_click = fn
        return self

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.04
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def _layout_nodes(self, nodes, n_count, area):
        if n_count == 0:
            return
        var tot = 0.0
        var i = 0
        while i < n_count:
            tot = tot + nodes[i].total_value()
            i = i + 1
        if tot <= 0.0:
            return
        var x = area.x
        var y = area.y
        var w = area.w
        var h = area.h
        var ai = 0
        while ai < n_count:
            var node = nodes[ai]
            var ratio = node.total_value() / tot
            if w >= h:
                var nw = int(ratio * float(w))
                if ai == n_count - 1:
                    var nw = area.right() - x
                node.rect = Rect(x, y, nw, h)
                x = x + nw
            else:
                var nh = int(ratio * float(h))
                if ai == n_count - 1:
                    var nh = area.bottom() - y
                node.rect = Rect(x, y, w, nh)
                y = y + nh
            if node.child_count > 0:
                var inner = Rect(node.rect.x + self.gap, node.rect.y + self.gap, node.rect.w - self.gap * 2, node.rect.h - self.gap * 2)
                self._layout_nodes(node.children, node.child_count, inner)
            ai = ai + 1

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            self.hovered = none
            if self.root != none:
                self._find_hovered(self.root, event.x, event.y)
        elif event.type == "mousedown" and self.hovered != none:
            if self._on_click != none:
                self._on_click(self.hovered)

    def _find_hovered(self, node, mx, my):
        if node.rect.contains(mx, my):
            self.hovered = node
            var i = 0
            while i < node.child_count:
                self._find_hovered(node.children[i], mx, my)
                i = i + 1

    def _draw_node(self, renderer, node, depth):
        if node.rect.w < 4 or node.rect.h < 4:
            return
        var animated_h = int(float(node.rect.h) * self.anim_progress)
        var dr = Rect(node.rect.x, node.rect.bottom() - animated_h, node.rect.w, animated_h)
        # Shadow for top-level
        if depth == 0:
            renderer.draw_shadow(node.rect, 10, 0, 3, Color(0, 0, 0, 60))
        # Fill with gradient simulation (bright top, normal base)
        renderer.fill_rounded_rect(dr, node.color, 6 if depth == 0 else 4)
        var bright = Color(min(node.color.r + 35, 255), min(node.color.g + 35, 255), min(node.color.b + 35, 255), 80)
        var top_h = int(dr.h / 3)
        if top_h > 0:
            renderer.fill_rounded_rect(Rect(dr.x, dr.y, dr.w, top_h), bright, 4)
        # Hover glow
        if self.hovered != none and node.id == self.hovered.id:
            renderer.fill_rounded_rect(dr, Color(255, 255, 255, 30), 4)
            renderer.draw_rounded_rect(dr, Color(255, 255, 255, 120), 4, 2)
        else:
            renderer.draw_rounded_rect(dr, Color(0, 0, 0, 40), 4, 1)
        # Label
        if dr.w >= self.min_label_w and dr.h >= 30:
            var lw = len(node.label) * 7
            if lw < dr.w - 8:
                renderer.draw_text(node.label, dr.x + 8, dr.y + 8, self.font_label, Color(255, 255, 255, 220))
            if dr.h >= 48:
                var val_str = str(int(node.total_value()))
                renderer.draw_text(val_str, dr.x + 8, dr.y + 24, self.font_val, Color(255, 255, 255, 140))
        # Children
        var i = 0
        while i < node.child_count:
            self._draw_node(renderer, node.children[i], depth + 1)
            i = i + 1

    def _draw(self, renderer):
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 60))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 12)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 12), 12, 1)
        var content_r = self.rect
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, self.rect.x + 16, self.rect.y + 14, self.font_title, self.theme.text)
            var content_r = Rect(self.rect.x + 8, self.rect.y + 42, self.rect.w - 16, self.rect.h - 50)
        else:
            content_r = Rect(self.rect.x + 8, self.rect.y + 8, self.rect.w - 16, self.rect.h - 16)
        if self.root != none:
            self._layout_nodes([self.root], 1, content_r)
            self._draw_node(renderer, self.root, 0)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── Marquee ──────────────────────────────────────────────────────────────────
# Infinite scrolling ticker with configurable speed, direction,
# pause-on-hover, separator icons, and multi-item support.

class MarqueeItem:
    def __init__(self, text, icon, color):
        self.text = text
        self.icon = icon
        self.color = color


class Marquee:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.items = []
        self.item_count = 0
        self.offset = 0.0
        self.speed = 1.2
        self.direction = "left"
        self.separator = "-"
        self.paused = false
        self.pause_on_hover = true
        self.hovered = false
        self.total_w = 0
        self.char_w = 8
        self.pad_between = 48
        self.bg_color = Color(20, 22, 34, 255)
        self.border_color = Color(99, 102, 241, 60)
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_icon = Font("sans-serif", 14, false, false)
        self.visible = true
        self.id = ""

    def add_item(self, text, icon, color):
        self.items.append(MarqueeItem(text, icon, color))
        self.item_count = self.item_count + 1
        self._calc_total_w()
        return self

    def _calc_total_w(self):
        self.total_w = 0
        var i = 0
        while i < self.item_count:
            var item_w = len(self.items[i].text) * self.char_w
            if self.items[i].icon != "":
                item_w = item_w + 22
            self.total_w = self.total_w + item_w + self.pad_between
            i = i + 1

    def set_speed(self, s):
        self.speed = s
        return self

    def pause(self):
        self.paused = true
        return self

    def resume(self):
        self.paused = false
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove" and self.pause_on_hover:
            self.hovered = self.rect.contains(event.x, event.y)
            self.paused = self.hovered

    def update(self):
        if self.paused or self.item_count == 0 or self.total_w == 0:
            return
        if self.direction == "left":
            self.offset = self.offset + self.speed
            if self.offset >= float(self.total_w):
                self.offset = 0.0
        else:
            self.offset = self.offset - self.speed
            if self.offset < 0.0:
                self.offset = float(self.total_w)

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.bg_color, 8)
        renderer.draw_rounded_rect(self.rect, self.border_color, 8, 1)
        # Fade masks on edges
        renderer.fill_rect(Rect(self.rect.x, self.rect.y, 40, self.rect.h), Color(self.bg_color.r, self.bg_color.g, self.bg_color.b, 200))
        renderer.fill_rect(Rect(self.rect.right() - 40, self.rect.y, 40, self.rect.h), Color(self.bg_color.r, self.bg_color.g, self.bg_color.b, 200))
        renderer.set_clip(Rect(self.rect.x + 20, self.rect.y, self.rect.w - 40, self.rect.h))
        var x_start = self.rect.x + 20 - int(self.offset)
        # Draw enough copies to fill
        var copies_needed = int(float(self.rect.w) / float(self.total_w)) + 2
        var copy_i = 0
        while copy_i <= copies_needed:
            var cx = x_start + copy_i * self.total_w
            var i = 0
            while i < self.item_count:
                var item = self.items[i]
                var item_x = cx
                var cy = self.rect.y + int((self.rect.h - 14) / 2)
                # Separator dot
                if i > 0 or copy_i > 0:
                    renderer.draw_text(self.separator, item_x - 24, cy, self.font, Color(100, 102, 140, 180))
                # Icon
                if item.icon != "":
                    renderer.draw_text(item.icon, item_x, cy - 1, self.font_icon, item.color)
                    item_x = item_x + 22
                # Text
                renderer.draw_text(item.text, item_x, cy, self.font, item.color)
                cx = cx + len(item.text) * self.char_w + (22 if item.icon != "" else 0) + self.pad_between
                i = i + 1
            copy_i = copy_i + 1
        renderer.clear_clip()

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── BubbleChart ──────────────────────────────────────────────────────────────
# Scatter plot with variable-radius bubbles, glow halos, axis lines,
# grid, animated pop-in per-bubble, labels, and category coloring.

class Bubble:
    def __init__(self, x_val, y_val, size, label, color):
        self.x_val = x_val
        self.y_val = y_val
        self.size = size
        self.label = label
        self.color = color
        self.anim_r = 0.0


class BubbleChart:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.bubbles = []
        self.bubble_count = 0
        self.x_min = 0.0
        self.x_max = 100.0
        self.y_min = 0.0
        self.y_max = 100.0
        self.auto_range = true
        self.padding = 50
        self.title = ""
        self.x_label = ""
        self.y_label = ""
        self.grid_lines = 5
        self.show_grid = true
        self.show_labels = true
        self.anim_progress = 0.0
        self.animate = true
        self.theme = Theme()
        self.font = Font("sans-serif", 11, false, false)
        self.font_title = Font("sans-serif", 14, true, false)
        self.font_label = Font("sans-serif", 10, false, false)
        self.bg_color = none
        self.visible = true
        self.id = ""

    def add_bubble(self, x_val, y_val, size, label, color):
        var b = Bubble(x_val, y_val, size, label, color)
        self.bubbles.append(b)
        self.bubble_count = self.bubble_count + 1
        if self.auto_range:
            if x_val < self.x_min:
                self.x_min = x_val
            if x_val > self.x_max:
                self.x_max = x_val
            if y_val < self.y_min:
                self.y_min = y_val
            if y_val > self.y_max:
                self.y_max = y_val
        return self

    def set_title(self, t):
        self.title = t
        return self

    def set_axis_labels(self, x_lbl, y_lbl):
        self.x_label = x_lbl
        self.y_label = y_lbl
        return self

    def _to_px(self, x_val, y_val):
        var pa_x = self.rect.x + self.padding
        var pa_y = self.rect.y + self.padding
        var pa_w = self.rect.w - self.padding * 2
        var pa_h = self.rect.h - self.padding * 2
        var x_range = self.x_max - self.x_min
        var y_range = self.y_max - self.y_min
        if x_range <= 0.0:
            var x_range = 1.0
        if y_range <= 0.0:
            var y_range = 1.0
        var px = pa_x + int((x_val - self.x_min) / x_range * float(pa_w))
        var py = pa_y + pa_h - int((y_val - self.y_min) / y_range * float(pa_h))
        return [px, py]

    def update(self):
        if self.animate and self.anim_progress < 1.0:
            self.anim_progress = self.anim_progress + 0.03
            if self.anim_progress > 1.0:
                self.anim_progress = 1.0

    def _draw(self, renderer):
        var pa_x = self.rect.x + self.padding
        var pa_y = self.rect.y + self.padding
        var pa_w = self.rect.w - self.padding * 2
        var pa_h = self.rect.h - self.padding * 2
        renderer.draw_shadow(self.rect, 16, 0, 4, Color(0, 0, 0, 50))
        renderer.fill_rounded_rect(self.rect, self.theme.surface, 12)
        renderer.draw_rounded_rect(self.rect, Color(255, 255, 255, 12), 12, 1)
        if self.title != "":
            var tw = len(self.title) * 8
            renderer.draw_text(self.title, self.rect.x + int((self.rect.w - tw) / 2), self.rect.y + 14, self.font_title, self.theme.text)
        # Grid
        if self.show_grid:
            var gi = 0
            while gi <= self.grid_lines:
                var gx = pa_x + int(float(gi) / float(self.grid_lines) * float(pa_w))
                var gy = pa_y + int(float(gi) / float(self.grid_lines) * float(pa_h))
                renderer.fill_rect(Rect(gx, pa_y, 1, pa_h), Color(255, 255, 255, 8))
                renderer.fill_rect(Rect(pa_x, gy, pa_w, 1), Color(255, 255, 255, 8))
                var x_range = self.x_max - self.x_min
                var y_range = self.y_max - self.y_min
                var x_lv = self.x_min + float(gi) / float(self.grid_lines) * x_range
                var y_lv = self.y_max - float(gi) / float(self.grid_lines) * y_range
                renderer.draw_text(str(int(x_lv)), gx - 8, pa_y + pa_h + 6, self.font, self.theme.text_secondary)
                renderer.draw_text(str(int(y_lv)), pa_x - 30, gy - 6, self.font, self.theme.text_secondary)
                gi = gi + 1
        # Axes
        renderer.fill_rect(Rect(pa_x, pa_y, 1, pa_h), Color(255, 255, 255, 30))
        renderer.fill_rect(Rect(pa_x, pa_y + pa_h), pa_w, 1, Color(255, 255, 255, 30))
        if self.x_label != "":
            var xw = len(self.x_label) * 7
            renderer.draw_text(self.x_label, pa_x + int((pa_w - xw) / 2), pa_y + pa_h + 22, self.font, self.theme.text_secondary)
        # Bubbles (draw in 3 passes: glow, shadow, main)
        var bi = 0
        while bi < self.bubble_count:
            var b = self.bubbles[bi]
            var pt = self._to_px(b.x_val, b.y_val)
            var anim_size = int(float(b.size) * self.anim_progress)
            if anim_size < 1:
                var anim_size = 1
            # Outer glow halo
            renderer.fill_circle(pt[0], pt[1], anim_size + 8, Color(b.color.r, b.color.g, b.color.b, 18))
            renderer.fill_circle(pt[0], pt[1], anim_size + 4, Color(b.color.r, b.color.g, b.color.b, 35))
            bi = bi + 1
        bi = 0
        while bi < self.bubble_count:
            var b = self.bubbles[bi]
            var pt = self._to_px(b.x_val, b.y_val)
            var anim_size = int(float(b.size) * self.anim_progress)
            if anim_size < 1:
                anim_size = 1
            # Shadow
            renderer.fill_circle(pt[0] + 3, pt[1] + 3, anim_size, Color(0, 0, 0, 40))
            # Main bubble
            renderer.fill_circle(pt[0], pt[1], anim_size, Color(b.color.r, b.color.g, b.color.b, 190))
            # Specular highlight
            var hi_x = pt[0] - int(float(anim_size) * 0.3)
            var hi_y = pt[1] - int(float(anim_size) * 0.35)
            renderer.fill_circle(hi_x, hi_y, int(float(anim_size) * 0.35), Color(255, 255, 255, 60))
            # Outline
            renderer.draw_circle(pt[0], pt[1], anim_size, Color(255, 255, 255, 30))
            bi = bi + 1
        # Labels on top
        if self.show_labels:
            bi = 0
            while bi < self.bubble_count:
                var b = self.bubbles[bi]
                var pt = self._to_px(b.x_val, b.y_val)
                var anim_size = int(float(b.size) * self.anim_progress)
                if b.label != "" and anim_size > 10:
                    var lw = len(b.label) * 6
                    renderer.draw_text(b.label, pt[0] - int(lw / 2), pt[1] - int(float(anim_size) * 0.45), self.font_label, Color(255, 255, 255, 200))
                bi = bi + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── CommandBar ───────────────────────────────────────────────────────────────
# App-level top command bar: left logo/breadcrumb zone, centre search,
# right action buttons, gradient accent line, notification slot.

class CommandBar:
    def __init__(self, window_w, h):
        self.window_w = window_w
        self.h = h
        self.left_items = []
        self.left_count = 0
        self.right_items = []
        self.right_count = 0
        self.search_text = ""
        self.search_placeholder = "Search..."
        self.search_focused = false
        self.search_w = 280
        self.show_search = true
        self.accent = Color(99, 102, 241, 255)
        self.bg_color = Color(18, 20, 32, 255)
        self.border_color = Color(255, 255, 255, 8)
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_small = Font("sans-serif", 11, false, false)
        self.font_icon = Font("sans-serif", 16, false, false)
        self.visible = true
        self.id = ""
        self._on_search = none

    def add_left(self, icon, label, on_click):
        self.left_items.append({"icon": icon, "label": label, "action": on_click})
        self.left_count = self.left_count + 1
        return self

    def add_right(self, icon, label, on_click, badge):
        self.right_items.append({"icon": icon, "label": label, "action": on_click, "badge": badge})
        self.right_count = self.right_count + 1
        return self

    def on_search(self, fn):
        self._on_search = fn
        return self

    def set_search_placeholder(self, p):
        self.search_placeholder = p
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown":
            var bar_r = Rect(0, 0, self.window_w, self.h)
            if not bar_r.contains(event.x, event.y):
                self.search_focused = false
                return
            var search_x = int((self.window_w - self.search_w) / 2)
            var search_r = Rect(search_x, 8, self.search_w, self.h - 16)
            if self.show_search and search_r.contains(event.x, event.y):
                self.search_focused = true
                event.consume()
            else:
                self.search_focused = false
            # Left items
            var lx = 16
            var li = 0
            while li < self.left_count:
                var item = self.left_items[li]
                var iw = len(item["label"]) * 7 + 28
                var ir = Rect(lx, 8, iw, self.h - 16)
                if ir.contains(event.x, event.y) and item["action"] != none:
                    var ev = Event("click")
                    item["action"](ev)
                    event.consume()
                lx = lx + iw + 4
                li = li + 1
            # Right items
            var rx = self.window_w - 16
            var ri = self.right_count - 1
            while ri >= 0:
                var item = self.right_items[ri]
                var iw = len(item["label"]) * 7 + 32
                rx = rx - iw
                var ir = Rect(rx, 8, iw, self.h - 16)
                if ir.contains(event.x, event.y) and item["action"] != none:
                    var ev = Event("click")
                    item["action"](ev)
                    event.consume()
                rx = rx - 4
                ri = ri - 1
        elif event.type == "textinput" and self.search_focused:
            self.search_text = self.search_text + event.text
            if self._on_search != none:
                self._on_search(self.search_text)
        elif event.type == "keydown" and self.search_focused:
            if event.key == "backspace" and len(self.search_text) > 0:
                self.search_text = self.search_text[0:len(self.search_text) - 1]
                if self._on_search != none:
                    self._on_search(self.search_text)

    def _draw(self, renderer):
        renderer.fill_rect(Rect(0, 0, self.window_w, self.h), self.bg_color)
        renderer.draw_line(0, self.h - 1, self.window_w, self.h - 1, self.border_color, 1)
        # Gradient accent line at bottom
        var seg_count = 8
        var seg_w = int(self.window_w / seg_count)
        var si = 0
        while si < seg_count:
            var t = float(si) / float(seg_count - 1)
            var r = int(float(self.accent.r) * (1.0 - t) + 168.0 * t)
            var g = int(float(self.accent.g) * (1.0 - t) + 85.0 * t)
            var b = int(float(self.accent.b) * (1.0 - t) + 247.0 * t)
            renderer.fill_rect(Rect(si * seg_w, self.h - 2, seg_w + 1, 2), Color(r, g, b, 180))
            si = si + 1
        # Left items
        var lx = 16
        var li = 0
        while li < self.left_count:
            var item = self.left_items[li]
            var iw = len(item["label"]) * 7 + 28
            if item["icon"] != "":
                renderer.draw_text(item["icon"], lx + 4, int(self.h / 2) - 9, self.font_icon, Color(160, 162, 200, 200))
            renderer.draw_text(item["label"], lx + 24, int(self.h / 2) - 7, self.font, Color(200, 202, 230, 200))
            if li < self.left_count - 1:
                renderer.draw_text("?", lx + iw, int(self.h / 2) - 8, self.font, Color(80, 82, 110, 160))
            lx = lx + iw + 4
            li = li + 1
        # Centre search
        if self.show_search:
            var search_x = int((self.window_w - self.search_w) / 2)
            var sr = Rect(search_x, 8, self.search_w, self.h - 16)
            renderer.fill_rounded_rect(sr, Color(30, 32, 48, 255), 8)
            if self.search_focused:
                renderer.draw_rounded_rect(sr, Color(self.accent.r, self.accent.g, self.accent.b, 120), 8, 1)
                renderer.draw_shadow(sr, 12, 0, 3, Color(self.accent.r, self.accent.g, self.accent.b, 40))
            else:
                renderer.draw_rounded_rect(sr, Color(255, 255, 255, 10), 8, 1)
            renderer.draw_text("?", search_x + 10, int(self.h / 2) - 10, self.font_icon, Color(100, 102, 140, 160))
            var disp = self.search_text if (self.search_text != "" or self.search_focused) else self.search_placeholder
            var text_c = Color(220, 222, 255, 220) if self.search_text != "" else Color(100, 102, 140, 140)
            renderer.draw_text(disp, search_x + 32, int(self.h / 2) - 7, self.font, text_c)
            if self.search_text == "" and not self.search_focused:
                var hint = "CtrlK"
                var hw = len(hint) * 7 + 8
                var hr = Rect(search_x + self.search_w - hw - 8, int(self.h / 2) - 9, hw, 18)
                renderer.fill_rounded_rect(hr, Color(255, 255, 255, 8), 5)
                renderer.draw_text(hint, hr.x + 4, hr.y + 2, self.font_small, Color(120, 122, 160, 140))
        # Right items
        var rx = self.window_w - 16
        var ri = self.right_count - 1
        while ri >= 0:
            var item = self.right_items[ri]
            var iw = len(item["label"]) * 7 + 32
            rx = rx - iw
            renderer.fill_rounded_rect(Rect(rx, 8, iw, self.h - 16), Color(255, 255, 255, 6), 8)
            if item["icon"] != "":
                renderer.draw_text(item["icon"], rx + 6, int(self.h / 2) - 9, self.font_icon, Color(160, 162, 200, 200))
            renderer.draw_text(item["label"], rx + 24, int(self.h / 2) - 7, self.font, Color(200, 202, 230, 200))
            if item["badge"] > 0:
                var bs = str(item["badge"])
                renderer.fill_circle(rx + iw - 4, 10, 6, Color(255, 59, 48, 255))
                renderer.draw_text(bs, rx + iw - 7, 4, self.font_small, Color(255, 255, 255, 255))
            rx = rx - 4
            ri = ri - 1

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self


# ═══════════════════════════════════════════════════════════════════════════════
# WAVE 5  -  IDE-ESSENTIAL WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

# ─── AutoComplete ─────────────────────────────────────────────────────────────
# Floating suggestion dropdown with fuzzy filter, keyboard nav,
# category icons, type annotations, and animated slide-in.

class AutoCompleteItem:
    def __init__(self, label, detail, kind, icon):
        self.label = label
        self.detail = detail
        self.kind = kind
        self.icon = icon
        self.score = 0


class AutoComplete:
    def __init__(self, x_or_w, y=0, w=0, h=0):
        if w == 0:
            self.x = 0
            self.y = 0
            self.w = x_or_w
            self.h = 300
        else:
            self.x = x_or_w
            self.y = y
            self.w = w
            self.h = h
        self.items = []
        self.item_count = 0
        self.filtered = []
        self.filtered_count = 0
        self.selected = 0
        self.query = ""
        self.visible = false
        self.item_h = 30
        self.max_visible = 8
        self.bg_color = Color(24, 26, 42, 252)
        self.border_color = Color(99, 102, 241, 80)
        self.accent = Color(99, 102, 241, 255)
        self.theme = Theme()
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_detail = Font("sans-serif", 11, false, false)
        self.font_icon = Font("sans-serif", 13, false, false)
        self.anim_y = 0.0
        self.id = ""
        self._on_accept = none
        self._on_dismiss = none

    def register(self, label, detail, kind, icon):
        self.items.append(AutoCompleteItem(label, detail, kind, icon))
        self.item_count = self.item_count + 1
        return self

    def on_accept(self, fn):
        self._on_accept = fn
        return self

    def on_dismiss(self, fn):
        self._on_dismiss = fn
        return self

    def show_at(self, x, y, query):
        self.x = x
        self.y = y
        self.query = query
        self.visible = true
        self.selected = 0
        self.anim_y = float(self.item_h * 2)
        self._filter()
        return self

    def hide(self):
        self.visible = false
        if self._on_dismiss != none:
            self._on_dismiss()
        return self

    def _filter(self):
        self.filtered = []
        self.filtered_count = 0
        var q = string_lower(self.query)
        var i = 0
        while i < self.item_count:
            var item = self.items[i]
            var lbl = string_lower(item.label)
            if q == "" or string_contains(lbl, q) or string_startswith(lbl, q):
                item.score = 100 if string_startswith(lbl, q) else 50
                self.filtered.append(item)
                self.filtered_count = self.filtered_count + 1
            i = i + 1
        if self.selected >= self.filtered_count:
            self.selected = 0

    def update_query(self, q):
        self.query = q
        self._filter()
        return self

    def accept(self):
        if self.filtered_count > 0 and self.selected < self.filtered_count:
            var item = self.filtered[self.selected]
            if self._on_accept != none:
                self._on_accept(item)
            self.hide()

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "keydown":
            if event.key == "down":
                if self.selected < self.filtered_count - 1:
                    self.selected = self.selected + 1
                event.consume()
            elif event.key == "up":
                if self.selected > 0:
                    self.selected = self.selected - 1
                event.consume()
            elif event.key == "enter" or event.key == "tab":
                self.accept()
                event.consume()
            elif event.key == "escape":
                self.hide()
                event.consume()

    def update(self):
        if self.visible and self.anim_y > 0.0:
            self.anim_y = self.anim_y - float(self.item_h) * 0.3
            if self.anim_y < 0.0:
                self.anim_y = 0.0

    def _kind_color(self, kind):
        if kind == "function":
            return Color(99, 102, 241, 255)
        if kind == "variable":
            return Color(52, 199, 89, 255)
        if kind == "class":
            return Color(220, 100, 255, 255)
        if kind == "keyword":
            return Color(255, 149, 0, 255)
        if kind == "snippet":
            return Color(0, 199, 190, 255)
        return Color(160, 162, 200, 255)

    def _draw(self, renderer):
        if self.filtered_count == 0:
            return
        var vis = min(self.filtered_count, self.max_visible)
        var panel_h = vis * self.item_h + 8
        var ay = self.y + int(self.anim_y)
        var panel_r = Rect(self.x, ay, self.w, panel_h)
        renderer.draw_shadow(panel_r, 24, 0, 8, Color(0, 0, 0, 120))
        renderer.fill_rounded_rect(panel_r, self.bg_color, 10)
        renderer.draw_rounded_rect(panel_r, self.border_color, 10, 1)
        renderer.fill_rounded_rect(Rect(self.x + 40, ay - 1, 60, 2), Color(99, 102, 241, 180), 1)
        var scroll_start = 0
        if self.selected >= self.max_visible:
            var scroll_start = self.selected - self.max_visible + 1
        var i = 0
        while i < vis:
            var idx = i + scroll_start
            if idx >= self.filtered_count:
                var i = vis
            else:
                var item = self.filtered[idx]
                var iy = ay + 4 + i * self.item_h
                var ir = Rect(self.x, iy, self.w, self.item_h)
                if idx == self.selected:
                    renderer.fill_rounded_rect(Rect(self.x + 2, iy + 1, self.w - 4, self.item_h - 2), Color(99, 102, 241, 35), 7)
                    renderer.fill_rect(Rect(self.x + 2, iy + 4, 3, self.item_h - 8), self.accent)
                var kc = self._kind_color(item.kind)
                renderer.fill_rounded_rect(Rect(self.x + 8, iy + 7, 16, 16), Color(kc.r, kc.g, kc.b, 25), 4)
                renderer.draw_text(item.icon, self.x + 10, iy + 8, self.font_icon, kc)
                renderer.draw_text(item.label, self.x + 30, iy + 8, self.font_bold, Color(220, 222, 255, 240))
                if item.detail != "":
                    var lw = len(item.label) * 8
                    renderer.draw_text(item.detail, self.x + 34 + lw, iy + 9, self.font_detail, Color(120, 122, 160, 160))
                i = i + 1

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

# ─── MiniMap ──────────────────────────────────────────────────────────────────
# Code overview minimap: scaled-down code render with viewport rect,
# click-to-scroll, syntax colour bands, and smooth track highlight.

class MiniMap:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.lines = []
        self.line_count = 0
        self.scroll_pct = 0.0
        self.viewport_pct = 0.2
        self.dragging = false
        self.scale = 2
        self.bg_color = Color(16, 18, 28, 255)
        self.viewport_color = Color(255, 255, 255, 18)
        self.viewport_border = Color(99, 102, 241, 60)
        self.theme = Theme()
        self.visible = true
        self.id = ""
        self._on_scroll = none
        self._color_bands = [
            Color(99, 102, 241, 120),
            Color(52, 199, 89, 100),
            Color(255, 149, 0, 100),
            Color(220, 100, 255, 100),
            Color(200, 202, 230, 60)
        ]

    def set_lines(self, lines):
        self.lines = lines
        self.line_count = len(lines)
        return self

    def set_scroll(self, pct, viewport_pct):
        self.scroll_pct = pct
        self.viewport_pct = viewport_pct
        return self

    def on_scroll(self, fn):
        self._on_scroll = fn
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown" and self.rect.contains(event.x, event.y):
            self.dragging = true
            var pct = float(event.y - self.rect.y) / float(self.rect.h)
            self.scroll_pct = pct
            if self._on_scroll != none:
                self._on_scroll(pct)
            event.consume()
        elif event.type == "mouseup":
            self.dragging = false
        elif event.type == "mousemove" and self.dragging:
            var pct = float(event.y - self.rect.y) / float(self.rect.h)
            if pct < 0.0:
                var pct = 0.0
            if pct > 1.0:
                pct = 1.0
            self.scroll_pct = pct
            if self._on_scroll != none:
                self._on_scroll(pct)

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.bg_color)
        renderer.draw_line(self.rect.x, self.rect.y, self.rect.x, self.rect.bottom(), Color(255, 255, 255, 8), 1)
        var lh = self.scale
        var max_lines = int(self.rect.h / lh) + 1
        var start_line = int(self.scroll_pct * float(self.line_count))
        var i = 0
        while i < max_lines and i + start_line < self.line_count:
            var line = self.lines[i + start_line]
            var ly = self.rect.y + i * lh
            var indent = 0
            while indent < len(line) and line[indent:indent+1] == " ":
                indent = indent + 1
            var content_len = len(line) - indent
            if content_len < 0:
                var content_len = 0
            var bar_w = int(float(content_len) * float(self.rect.w - 6) / 80.0)
            if bar_w > self.rect.w - 6:
                var bar_w = self.rect.w - 6
            if bar_w > 0 and lh > 0:
                var band_idx = (i + start_line) % 5
                var lc = self._color_bands[band_idx]
                var lx = self.rect.x + 4 + int(float(indent) * float(self.rect.w - 8) / 80.0)
                renderer.fill_rect(Rect(lx, ly, bar_w, max(lh - 1, 1)), lc)
            i = i + 1
        var vp_h = int(self.viewport_pct * float(self.rect.h))
        var vp_y = self.rect.y + int(self.scroll_pct * float(self.rect.h - vp_h))
        renderer.fill_rect(Rect(self.rect.x, vp_y, self.rect.w, vp_h), self.viewport_color)
        renderer.draw_line(self.rect.x, vp_y, self.rect.right(), vp_y, self.viewport_border, 1)
        renderer.draw_line(self.rect.x, vp_y + vp_h, self.rect.right(), vp_y + vp_h, self.viewport_border, 1)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── ChatBubble / ChatPanel ────────────────────────────────────────────────────
# AI chat interface: message bubbles with sender avatar, timestamp,
# typing indicator, code block detection, and smooth scroll.

class ChatMessage:
    def __init__(self, text, sender, timestamp):
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.is_code = false
        self.language = ""
        self.height = 0


class ChatPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.messages = []
        self.msg_count = 0
        self.input_text = ""
        self.input_h = 52
        self.input_focused = false
        self.scroll_y = 0
        self.total_content_h = 0
        self.typing = false
        self.typing_dots = 0
        self.typing_t = 0.0
        self.bot_name = "Nython AI"
        self.bot_avatar_color = Color(99, 102, 241, 255)
        self.user_avatar_color = Color(52, 199, 89, 255)
        self.bg_color = Color(18, 20, 32, 255)
        self.user_bubble = Color(99, 102, 241, 255)
        self.bot_bubble = Color(30, 32, 52, 255)
        self.input_bg = Color(28, 30, 48, 255)
        self.border_color = Color(255, 255, 255, 8)
        self.code_bg = Color(14, 16, 26, 255)
        self.accent = Color(99, 102, 241, 255)
        self.theme = Theme()
        self.font = Font("sans-serif", 13, false, false)
        self.font_bold = Font("sans-serif", 13, true, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.font_mono = Font("monospace", 12, false, false)
        self.font_icon = Font("sans-serif", 16, false, false)
        self.char_w = 7
        self.line_h = 19
        self.bubble_pad = 10
        self.visible = true
        self.id = ""
        self._on_send = none
        self._on_input = none

    def add_message(self, text, sender):
        var msg = ChatMessage(text, sender, "")
        if string_startswith(text, "```") or string_contains(text, "\n    "):
            msg.is_code = true
        var lines = 1
        var i = 0
        while i < len(text):
            if text[i:i+1] == "\n":
                lines = lines + 1
            i = i + 1
        var bubble_w = int(self.rect.w * 0.72) - self.bubble_pad * 2
        var chars_per_line = int(float(bubble_w) / float(self.char_w))
        if chars_per_line < 1:
            chars_per_line = 1
        var wrapped = int(float(len(text)) / float(chars_per_line)) + lines
        msg.height = wrapped * self.line_h + self.bubble_pad * 2 + 28
        self.messages.append(msg)
        self.msg_count = self.msg_count + 1
        self.total_content_h = self.total_content_h + msg.height + 12
        self.scroll_y = max(0, self.total_content_h - (self.rect.h - self.input_h - 20))
        self.typing = false
        return self

    def set_typing(self, active):
        self.typing = active
        return self

    def on_send(self, fn):
        self._on_send = fn
        return self

    def on_input(self, fn):
        self._on_input = fn
        return self

    def clear_input(self):
        self.input_text = ""
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        var inp_r = Rect(self.rect.x, self.rect.bottom() - self.input_h, self.rect.w, self.input_h)
        if event.type == "mousedown":
            if inp_r.contains(event.x, event.y):
                self.input_focused = true
            else:
                self.input_focused = false
            event.consume()
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 3
            var max_scroll = self.total_content_h - (self.rect.h - self.input_h - 20)
            if max_scroll < 0:
                max_scroll = 0
            if self.scroll_y < 0:
                self.scroll_y = 0
            if self.scroll_y > max_scroll:
                self.scroll_y = max_scroll
        elif event.type == "keydown" and self.input_focused:
            if event.key == "enter" and self.input_text != "":
                var text = self.input_text
                self.input_text = ""
                if self._on_send != none:
                    self._on_send(text)
            elif event.key == "backspace" and len(self.input_text) > 0:
                self.input_text = self.input_text[0:len(self.input_text) - 1]
                if self._on_input != none:
                    self._on_input(self.input_text)
        elif event.type == "textinput" and self.input_focused:
            self.input_text = self.input_text + event.text
            if self._on_input != none:
                self._on_input(self.input_text)

    def update(self):
        if self.typing:
            self.typing_t = self.typing_t + 0.08
            if self.typing_t > 3.0:
                self.typing_t = 0.0
            self.typing_dots = int(self.typing_t) % 4

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.bg_color, 0)
        var chat_area = Rect(self.rect.x, self.rect.y, self.rect.w, self.rect.h - self.input_h)
        renderer.set_clip(chat_area)
        var cy = self.rect.y + 12 - self.scroll_y
        var i = 0
        while i < self.msg_count:
            var msg = self.messages[i]
            var is_user = (msg.sender == "user")
            var bubble_max_w = int(self.rect.w * 0.72)
            var bw = min(bubble_max_w, len(msg.text) * self.char_w + self.bubble_pad * 2 + 40)
            var bx = 0
            if is_user:
                bx = self.rect.right() - bw - 12
            else:
                bx = self.rect.x + 44
            var bubble_c = self.user_bubble if is_user else self.bot_bubble
            var bubble_r = Rect(bx, cy, bw, msg.height - 4)
            renderer.draw_shadow(bubble_r, 8, 0, 3, Color(0, 0, 0, 50))
            renderer.fill_rounded_rect(bubble_r, bubble_c, 14)
            if is_user:
                renderer.fill_rounded_rect(Rect(bx, cy, bw, 1), Color(255, 255, 255, 30), 14)
            else:
                renderer.draw_rounded_rect(bubble_r, Color(255, 255, 255, 8), 14, 1)
            var avatar_color = self.user_avatar_color if is_user else self.bot_avatar_color
            var avatar_x = bx + bw + 6 if is_user else self.rect.x + 16
            renderer.fill_circle(avatar_x, cy + 18, 14, avatar_color)
            if is_user:
                renderer.draw_text("U", avatar_x - 4, cy + 11, self.font_bold, Color(255, 255, 255, 230))
            else:
                renderer.draw_text("*", avatar_x - 6, cy + 10, self.font_icon, Color(255, 255, 255, 230))
            var text_c = Color(255, 255, 255, 240) if is_user else Color(210, 212, 240, 230)
            if msg.is_code:
                renderer.fill_rounded_rect(Rect(bx + 6, cy + 6, bw - 12, msg.height - 16), self.code_bg, 8)
                renderer.draw_text(msg.text[0:min(len(msg.text), 60)], bx + 12, cy + 14, self.font_mono, Color(180, 220, 120, 230))
            else:
                var chars_per = int(float(bw - self.bubble_pad * 2) / float(self.char_w))
                if chars_per < 1:
                    chars_per = 1
                var tx = bx + self.bubble_pad
                var ty = cy + self.bubble_pad + 4
                var pos = 0
                var text = msg.text
                while pos < len(text):
                    var chunk_end = min(pos + chars_per, len(text))
                    var nl = string_find(text[pos:chunk_end], "\n")
                    if nl >= 0:
                        chunk_end = pos + nl
                    renderer.draw_text(text[pos:chunk_end], tx, ty, self.font, text_c)
                    ty = ty + self.line_h
                    if nl >= 0:
                        pos = pos + nl + 1
                    else:
                        pos = chunk_end
            cy = cy + msg.height + 12
            i = i + 1
        if self.typing:
            var dots = ""
            var di = 0
            while di < self.typing_dots:
                dots = dots + "o"
                di = di + 1
            var typing_r = Rect(self.rect.x + 44, cy, 80, 32)
            renderer.fill_rounded_rect(typing_r, self.bot_bubble, 14)
            renderer.draw_rounded_rect(typing_r, Color(255, 255, 255, 8), 14, 1)
            renderer.draw_text(dots, typing_r.x + 12, typing_r.y + 9, self.font, Color(140, 142, 180, 200))
            renderer.fill_circle(self.rect.x + 16, cy + 16, 14, self.bot_avatar_color)
            renderer.draw_text("*", self.rect.x + 10, cy + 9, self.font_icon, Color(255, 255, 255, 230))
        renderer.clear_clip()
        renderer.draw_line(self.rect.x, self.rect.bottom() - self.input_h, self.rect.right(), self.rect.bottom() - self.input_h, self.border_color, 1)
        var inp_r = Rect(self.rect.x + 10, self.rect.bottom() - self.input_h + 8, self.rect.w - 52, self.input_h - 16)
        renderer.fill_rounded_rect(inp_r, self.input_bg, 10)
        if self.input_focused:
            renderer.draw_rounded_rect(inp_r, Color(self.accent.r, self.accent.g, self.accent.b, 120), 10, 1)
            renderer.draw_shadow(inp_r, 10, 0, 3, Color(self.accent.r, self.accent.g, self.accent.b, 30))
        else:
            renderer.draw_rounded_rect(inp_r, Color(255, 255, 255, 12), 10, 1)
        var placeholder_c = Color(80, 82, 110, 160)
        if self.input_text != "":
            renderer.draw_text(self.input_text, inp_r.x + 10, inp_r.y + 9, self.font, Color(220, 222, 255, 230))
        else:
            renderer.draw_text("Ask Nython AI...", inp_r.x + 10, inp_r.y + 9, self.font, placeholder_c)
        var send_r = Rect(self.rect.right() - 40, self.rect.bottom() - self.input_h + 10, 30, 30)
        var send_c = Color(self.accent.r, self.accent.g, self.accent.b, 180 if self.input_text != "" else 60)
        renderer.fill_rounded_rect(send_r, send_c, 8)
        renderer.draw_text("?", send_r.x + 7, send_r.y + 7, self.font_icon, Color(255, 255, 255, 220))
        renderer.draw_line(self.rect.x, self.rect.y, self.rect.x, self.rect.bottom(), Color(255, 255, 255, 6), 1)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── FileTree ─────────────────────────────────────────────────────────────────
# Hierarchical file explorer with icons, expand/collapse animation,
# context menu hook, rename inline, and git-status colour coding.

class FileNode:
    def __init__(self, name, path, is_dir):
        self.name = name
        self.path = path
        self.is_dir = is_dir
        self.children = []
        self.child_count = 0
        self.expanded = false
        self.selected = false
        self.modified = false
        self.git_status = ""
        self.depth = 0
        self.icon = "[file]"
        if is_dir:
            self.icon = "[dir]"

    def add_child(self, node):
        node.depth = self.depth + 1
        self.children.append(node)
        self.child_count = self.child_count + 1
        return self

    def set_icon(self, icon):
        self.icon = icon
        return self

    def set_git_status(self, status):
        self.git_status = status
        return self


class FileTree:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.roots = []
        self.root_count = 0
        self.selected_path = ""
        self.hovered_path = ""
        self.scroll_y = 0
        self.item_h = 28
        self.indent_w = 18
        self.bg_color = Color(18, 20, 32, 255)
        self.border_color = Color(255, 255, 255, 6)
        self.accent = Color(99, 102, 241, 255)
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.font_icon = Font("sans-serif", 13, false, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.visible = true
        self.id = ""
        self._on_select = none
        self._on_expand = none
        self.node_count = 0
        self._nodes_by_path = {}

    def add_node(self, path, label, depth, expanded, ntype):
        var node = FileNode(label, path, ntype == "folder")
        node.depth = depth
        node.expanded = expanded
        self._nodes_by_path[path] = node
        self.node_count = self.node_count + 1
        if depth == 0:
            self.add_root(node)
        else:
            # Find parent by checking paths
            var parts = string_split(path, "/")
            var parent_path = ""
            var i = 0
            while i < len(parts) - 1:
                if i > 0:
                    parent_path = parent_path + "/"
                parent_path = parent_path + parts[i]
                i = i + 1
            var parent = self._nodes_by_path[parent_path]
            if parent != none:
                parent.add_child(node)
        return self

    def add_root(self, node):
        self.roots.append(node)
        self.root_count = self.root_count + 1
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_expand(self, fn):
        self._on_expand = fn
        return self

    def select(self, path):
        self.selected_path = path
        return self

    def _flat(self, node, out):
        out.append(node)
        if node.is_dir and node.expanded:
            var i = 0
            while i < node.child_count:
                out = self._flat(node.children[i], out)
                i = i + 1
        return out

    def _all_visible(self):
        var out = []
        var i = 0
        while i < self.root_count:
            out = self._flat(self.roots[i], out)
            i = i + 1
        return out

    def handle_event(self, event):
        if not self.visible:
            return
        var items = self._all_visible()
        var n = len(items)
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h * 2
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_scroll = n * self.item_h - self.rect.h + 40
            if max_scroll < 0:
                var max_scroll = 0
            if self.scroll_y > max_scroll:
                self.scroll_y = max_scroll
        elif event.type == "mousemove":
            self.hovered_path = ""
            if self.rect.contains(event.x, event.y):
                var iy = self.rect.y + 36 - self.scroll_y
                var i = 0
                while i < n:
                    if event.y >= iy and event.y < iy + self.item_h:
                        self.hovered_path = items[i].path
                    iy = iy + self.item_h
                    i = i + 1
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var iy = self.rect.y + 36 - self.scroll_y
            var i = 0
            while i < n:
                if event.y >= iy and event.y < iy + self.item_h:
                    var node = items[i]
                    if node.is_dir:
                        node.expanded = not node.expanded
                        node.icon = "?" if node.expanded else "[dir]"
                        if self._on_expand != none:
                            self._on_expand(node)
                    else:
                        self.selected_path = node.path
                        node.selected = true
                        if self._on_select != none:
                            self._on_select(node)
                    event.consume()
                    i = n
                else:
                    iy = iy + self.item_h
                    i = i + 1

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.bg_color)
        var hdr_r = Rect(self.rect.x, self.rect.y, self.rect.w, 36)
        renderer.fill_rect(hdr_r, Color(0, 0, 0, 30))
        renderer.draw_text("EXPLORER", self.rect.x + 12, self.rect.y + 11, self.font_small, Color(100, 102, 140, 180))
        renderer.draw_line(self.rect.x, self.rect.y + 35, self.rect.right(), self.rect.y + 35, self.border_color, 1)
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 36, self.rect.w, self.rect.h - 36))
        var items = self._all_visible()
        var n = len(items)
        var iy = self.rect.y + 36 - self.scroll_y
        var i = 0
        while i < n:
            var node = items[i]
            var ir = Rect(self.rect.x, iy, self.rect.w, self.item_h)
            var is_selected = (node.path == self.selected_path)
            var is_hovered = (node.path == self.hovered_path)
            if is_selected:
                renderer.fill_rect(ir, Color(self.accent.r, self.accent.g, self.accent.b, 25))
                renderer.fill_rect(Rect(self.rect.x, iy, 2, self.item_h), self.accent)
            elif is_hovered:
                renderer.fill_rect(ir, Color(255, 255, 255, 6))
            var ix = self.rect.x + 8 + node.depth * self.indent_w
            if node.is_dir:
                var arrow = "?" if node.expanded else "?"
                renderer.draw_text(arrow, ix, iy + 8, self.font_small, Color(120, 122, 160, 180))
                ix = ix + 12
            else:
                ix = ix + 14
            renderer.draw_text(node.icon, ix, iy + 7, self.font_icon, Color(160, 162, 200, 200))
            var name_c = Color(220, 222, 255, 230) if (is_selected or node.is_dir) else Color(180, 182, 210, 200)
            var nf = self.font_bold if node.is_dir else self.font
            renderer.draw_text(node.name, ix + 20, iy + 8, nf, name_c)
            if node.modified:
                renderer.fill_circle(self.rect.right() - 10, iy + 14, 3, Color(255, 149, 0, 200))
            if node.git_status != "":
                var gs_c = Color(52, 199, 89, 200)
                if node.git_status == "M":
                    var gs_c = Color(255, 149, 0, 200)
                elif node.git_status == "?":
                    gs_c = Color(99, 102, 241, 200)
                elif node.git_status == "D":
                    gs_c = Color(255, 59, 48, 200)
                renderer.draw_text(node.git_status, self.rect.right() - 16, iy + 8, self.font_small, gs_c)
            iy = iy + self.item_h
            i = i + 1
        renderer.clear_clip()
        renderer.draw_line(self.rect.right() - 1, self.rect.y, self.rect.right() - 1, self.rect.bottom(), self.border_color, 1)

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── EditorTab / TabBar ───────────────────────────────────────────────────────
# Multi-file tab strip with close buttons, modified indicators,
# icon by file type, drag reorder hint, and overflow scrolling.

class EditorTab:
    def __init__(self, id, filename, path):
        self.id = id
        self.filename = filename
        self.path = path
        self.modified = false
        self.active = false
        self.icon = "[file]"
        self._ext_icon()

    def _ext_icon(self):
        if string_endswith(self.filename, ".ny"):
            self.icon = "◈"
        elif string_endswith(self.filename, ".json"):
            self.icon = "{}"
        elif string_endswith(self.filename, ".md"):
            self.icon = "Md"
        elif string_endswith(self.filename, ".txt"):
            self.icon = "Tx"


class TabBar:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.tabs = []
        self.tab_count = 0
        self.active_id = ""
        self.scroll_x = 0
        self.tab_min_w = 120
        self.tab_max_w = 200
        self.bg_color = Color(18, 20, 32, 255)
        self.active_bg = Color(26, 28, 46, 255)
        self.inactive_bg = Color(18, 20, 32, 255)
        self.border_color = Color(255, 255, 255, 8)
        self.accent = Color(99, 102, 241, 255)
        self.theme = Theme()
        self.font = Font("sans-serif", 12, false, false)
        self.font_icon = Font("monospace", 11, false, false)
        self.visible = true
        self.id = ""
        self._on_select = none
        self._on_close = none
        self._on_new = none

    def add_tab(self, name, filename="", path=""):
        if filename == "":
            filename = name
        if path == "":
            path = name
        var tab = EditorTab(name, filename, path)
        self.tabs.append(tab)
        self.tab_count = self.tab_count + 1
        self.set_active(name)
        return self

    def close_tab(self, id):
        var kept = []
        var i = 0
        while i < self.tab_count:
            if self.tabs[i].id != id:
                kept.append(self.tabs[i])
            i = i + 1
        self.tabs = kept
        self.tab_count = len(kept)
        if self.active_id == id and self.tab_count > 0:
            self.active_id = self.tabs[self.tab_count - 1].id
        return self

    def set_active(self, id):
        self.active_id = id
        var i = 0
        while i < self.tab_count:
            self.tabs[i].active = (self.tabs[i].id == id)
            i = i + 1
        return self

    def set_modified(self, id, modified):
        var i = 0
        while i < self.tab_count:
            if self.tabs[i].id == id:
                self.tabs[i].modified = modified
            i = i + 1
        return self

    def get_active(self):
        var i = 0
        while i < self.tab_count:
            if self.tabs[i].id == self.active_id:
                return self.tabs[i]
            i = i + 1
        return none

    def on_select(self, fn):
        self._on_select = fn
        return self

    def on_close(self, fn):
        self._on_close = fn
        return self

    def on_new(self, fn):
        self._on_new = fn
        return self

    def _tab_w(self):
        if self.tab_count == 0:
            return self.tab_min_w
        var avail = self.rect.w - 44
        var w = int(avail / self.tab_count)
        if w < self.tab_min_w:
            w = self.tab_min_w
        if w > self.tab_max_w:
            w = self.tab_max_w
        return w

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var tw = self._tab_w()
            var new_btn = Rect(self.rect.x + self.tab_count * tw - self.scroll_x + 8, self.rect.y + 8, 24, self.rect.h - 16)
            if new_btn.contains(event.x, event.y):
                if self._on_new != none:
                    self._on_new()
                event.consume()
                return
            var tx = self.rect.x - self.scroll_x
            var i = 0
            while i < self.tab_count:
                var tab_r = Rect(tx, self.rect.y, tw, self.rect.h)
                var close_r = Rect(tx + tw - 22, self.rect.y + int((self.rect.h - 16) / 2), 16, 16)
                if close_r.contains(event.x, event.y):
                    if self._on_close != none:
                        self._on_close(self.tabs[i].id)
                    event.consume()
                    i = self.tab_count
                elif tab_r.contains(event.x, event.y):
                    self.set_active(self.tabs[i].id)
                    if self._on_select != none:
                        self._on_select(self.tabs[i])
                    event.consume()
                    i = self.tab_count
                else:
                    tx = tx + tw
                    i = i + 1

    def _draw(self, renderer):
        renderer.fill_rect(self.rect, self.bg_color)
        renderer.draw_line(self.rect.x, self.rect.bottom() - 1, self.rect.right(), self.rect.bottom() - 1, self.border_color, 1)
        var tw = self._tab_w()
        renderer.set_clip(Rect(self.rect.x, self.rect.y, self.rect.w - 44, self.rect.h))
        var tx = self.rect.x - self.scroll_x
        var i = 0
        while i < self.tab_count:
            var tab = self.tabs[i]
            var tab_r = Rect(tx, self.rect.y, tw, self.rect.h)
            if tab.active:
                renderer.fill_rect(tab_r, self.active_bg)
                renderer.fill_rect(Rect(tx, self.rect.bottom() - 2, tw, 2), self.accent)
                renderer.draw_shadow(Rect(tx, self.rect.y, tw, 2), 8, 0, 2, Color(self.accent.r, self.accent.g, self.accent.b, 40))
            renderer.draw_line(tx + tw - 1, self.rect.y + 6, tx + tw - 1, self.rect.bottom() - 6, Color(255, 255, 255, 8), 1)
            var name_c = Color(220, 222, 255, 230) if tab.active else Color(120, 122, 160, 160)
            renderer.draw_text(tab.icon, tx + 8, self.rect.y + int((self.rect.h - 13) / 2), self.font_icon, Color(self.accent.r, self.accent.g, self.accent.b, 180 if tab.active else 100))
            var fname = tab.filename
            if len(fname) > 16:
                fname = fname[0:14] + "..."
            renderer.draw_text(fname, tx + 24, self.rect.y + int((self.rect.h - 13) / 2), self.font, name_c)
            if tab.modified:
                renderer.fill_circle(tx + tw - 14, self.rect.y + int(self.rect.h / 2), 4, Color(255, 149, 0, 200))
            else:
                renderer.fill_rounded_rect(Rect(tx + tw - 22, self.rect.y + int((self.rect.h - 16) / 2), 16, 16), Color(255, 255, 255, 0), 8)
                renderer.draw_text("x", tx + tw - 18, self.rect.y + int((self.rect.h - 13) / 2), self.font, Color(80, 82, 110, 140))
            tx = tx + tw
            i = i + 1
        renderer.clear_clip()
        var new_btn = Rect(self.rect.x + self.tab_count * tw - self.scroll_x + 8, self.rect.y + 8, 24, self.rect.h - 16)
        renderer.fill_rounded_rect(new_btn, Color(255, 255, 255, 8), 6)
        renderer.draw_text("+", new_btn.x + 6, new_btn.y + 4, self.font, Color(160, 162, 200, 200))

    def draw(self, renderer):
        if self.visible:
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

# ─── TerminalPanel ────────────────────────────────────────────────────────────
# Integrated terminal/output panel: ANSI-aware coloured output,
# command input with history, prompt styling, clear, and resize.

class TerminalLine:
    def __init__(self, text, kind):
        self.text = text
        self.kind = kind


class TerminalPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.lines = []
        self.line_count = 0
        self.input_text = ""
        self.input_focused = false
        self.history = []
        self.history_idx = -1
        self.history_count = 0
        self.scroll_y = 0
        self.line_h = 18
        self.input_h = 30
        self.prompt = "nython> "
        self.bg_color = Color(12, 14, 22, 255)
        self.border_color = Color(255, 255, 255, 8)
        self.prompt_color = Color(99, 102, 241, 255)
        self.output_color = Color(200, 210, 200, 230)
        self.error_color = Color(255, 100, 80, 230)
        self.success_color = Color(80, 220, 120, 230)
        self.warning_color = Color(255, 180, 60, 230)
        self.input_color = Color(200, 222, 255, 230)
        self.cursor_color = Color(99, 102, 241, 220)
        self.header_color = Color(80, 82, 110, 180)
        self.theme = Theme()
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.visible = true
        self.id = ""
        self._on_run = none
        self._blink_t = 0.0
        self._blink_visible = true

    def write(self, text, kind):
        var remaining = text
        while len(remaining) > 0:
            var nl = string_find(remaining, "\n")
            if nl < 0:
                self.lines.append(TerminalLine(remaining, kind))
                self.line_count = self.line_count + 1
                var remaining = ""
            else:
                self.lines.append(TerminalLine(remaining[0:nl], kind))
                self.line_count = self.line_count + 1
                remaining = remaining[nl + 1:]
        self._scroll_to_bottom()
        return self

    def write_out(self, text):
        return self.write(text, "output")

    def write_err(self, text):
        return self.write(text, "error")

    def write_ok(self, text):
        return self.write(text, "success")

    def write_warn(self, text):
        return self.write(text, "warning")

    def write_info(self, text):
        return self.write(text, "info")

    def clear(self):
        self.lines = []
        self.line_count = 0
        self.scroll_y = 0
        return self

    def on_run(self, fn):
        self._on_run = fn
        return self

    def _scroll_to_bottom(self):
        var content_h = self.line_count * self.line_h
        var view_h = self.rect.h - self.input_h - 36
        if content_h > view_h:
            self.scroll_y = content_h - view_h

    def handle_event(self, event):
        if not self.visible:
            return
        var inp_r = Rect(self.rect.x, self.rect.bottom() - self.input_h, self.rect.w, self.input_h)
        if event.type == "mousedown":
            self.input_focused = inp_r.contains(event.x, event.y)
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 3
            if self.scroll_y < 0:
                self.scroll_y = 0
        elif event.type == "keydown" and self.input_focused:
            if event.key == "enter":
                var cmd = self.input_text
                self.input_text = ""
                self.history = [cmd] + self.history
                self.history_count = self.history_count + 1
                self.history_idx = -1
                self.write(self.prompt + cmd, "prompt")
                if self._on_run != none:
                    self._on_run(cmd)
            elif event.key == "backspace" and len(self.input_text) > 0:
                self.input_text = self.input_text[0:len(self.input_text) - 1]
            elif event.key == "up":
                if self.history_idx < self.history_count - 1:
                    self.history_idx = self.history_idx + 1
                    self.input_text = self.history[self.history_idx]
            elif event.key == "down":
                if self.history_idx > 0:
                    self.history_idx = self.history_idx - 1
                    self.input_text = self.history[self.history_idx]
                elif self.history_idx == 0:
                    self.history_idx = -1
                    self.input_text = ""
        elif event.type == "textinput" and self.input_focused:
            self.input_text = self.input_text + event.text

    def update(self):
        self._blink_t = self._blink_t + 0.04
        if self._blink_t > 1.0:
            self._blink_t = 0.0
            self._blink_visible = not self._blink_visible

    def _line_color(self, kind):
        if kind == "error":
            return self.error_color
        if kind == "success":
            return self.success_color
        if kind == "warning":
            return self.warning_color
        if kind == "prompt":
            return self.prompt_color
        if kind == "info":
            return Color(100, 180, 255, 200)
        return self.output_color

    def _draw(self, renderer):
        renderer.fill_rounded_rect(self.rect, self.bg_color, 8)
        renderer.draw_rounded_rect(self.rect, self.border_color, 8, 1)
        var hdr_r = Rect(self.rect.x, self.rect.y, self.rect.w, 32)
        renderer.fill_rounded_rect(hdr_r, Color(20, 22, 36, 255), 8)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + 12, self.rect.w, 20), Color(20, 22, 36, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 32, self.rect.right(), self.rect.y + 32, self.border_color, 1)
        renderer.fill_circle(self.rect.x + 14, self.rect.y + 16, 5, Color(255, 95, 86, 255))
        renderer.fill_circle(self.rect.x + 28, self.rect.y + 16, 5, Color(255, 189, 46, 255))
        renderer.fill_circle(self.rect.x + 42, self.rect.y + 16, 5, Color(39, 201, 63, 255))
        renderer.draw_text("TERMINAL", self.rect.x + 58, self.rect.y + 10, self.font_ui, self.header_color)
        var clear_r = Rect(self.rect.right() - 54, self.rect.y + 8, 46, 18)
        renderer.fill_rounded_rect(clear_r, Color(255, 255, 255, 8), 6)
        renderer.draw_text("clear", clear_r.x + 8, clear_r.y + 3, self.font_ui, Color(120, 122, 160, 160))
        var content_area = Rect(self.rect.x, self.rect.y + 32, self.rect.w, self.rect.h - self.input_h - 32)
        renderer.set_clip(content_area)
        var first_line = int(self.scroll_y / self.line_h)
        var max_visible = int(content_area.h / self.line_h) + 2
        var i = max(0, first_line)
        while i < self.line_count and i < first_line + max_visible:
            var line = self.lines[i]
            var ly = self.rect.y + 32 + i * self.line_h - self.scroll_y + 4
            var lc = self._line_color(line.kind)
            if line.kind == "prompt":
                renderer.draw_text(line.text, self.rect.x + 8, ly, self.font_bold, lc)
            else:
                var prefix = ""
                if line.kind == "error":
                    var prefix = "? "
                elif line.kind == "success":
                    prefix = "[OK] "
                elif line.kind == "warning":
                    prefix = "! "
                elif line.kind == "info":
                    prefix = "? "
                renderer.draw_text(prefix + line.text, self.rect.x + 8, ly, self.font, lc)
            i = i + 1
        renderer.clear_clip()
        renderer.draw_line(self.rect.x, self.rect.bottom() - self.input_h, self.rect.right(), self.rect.bottom() - self.input_h, self.border_color, 1)
        var inp_y = self.rect.bottom() - self.input_h + 6
        renderer.draw_text(self.prompt, self.rect.x + 8, inp_y, self.font_bold, self.prompt_color)
        var px = self.rect.x + 8 + len(self.prompt) * 7
        renderer.draw_text(self.input_text, px, inp_y, self.font, self.input_color)
        if self.input_focused and self._blink_visible:
            var cursor_x = px + len(self.input_text) * 7
            renderer.fill_rect(Rect(cursor_x, inp_y, 2, 14), self.cursor_color)

    def draw(self, renderer):
        if self.visible:
            self.update()
            self._draw(renderer)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
        return self

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self


# ═══════════════════════════════════════════════════════════════════════════════
# WAVE 6  -  Advanced IDE & Dashboard Widgets
# ═══════════════════════════════════════════════════════════════════════════════

# ─── GlowBadge ────────────────────────────────────────────────────────────────
class GlowBadge:
    def __init__(self, x, y, label, color):
        self.x = x
        self.y = y
        self.label = label
        self.color = color
        self.visible = true
        self.pulse = false
        self.t = 0.0
        self.font = Font("sans-serif", 11, true, false)
        self.id = ""

    def set_pulse(self, p):
        self.pulse = p
        return self

    def update(self):
        if self.pulse:
            self.t = self.t + 0.05

    def draw(self, renderer):
        if not self.visible:
            return
        self.update()
        var pad = 10
        var w = len(self.label) * 7 + pad * 2
        var h = 22
        var alpha = 255
        if self.pulse:
            var glow = int(40.0 + 20.0 * sin(self.t))
            renderer.draw_shadow(Rect(self.x, self.y, w, h), glow, 0, 4, Color(self.color.r, self.color.g, self.color.b, 80))
        renderer.fill_rounded_rect(Rect(self.x, self.y, w, h), Color(self.color.r, self.color.g, self.color.b, 30), 11)
        renderer.draw_rounded_rect(Rect(self.x, self.y, w, h), Color(self.color.r, self.color.g, self.color.b, 120), 11, 1)
        renderer.draw_text(self.label, self.x + pad, self.y + 5, self.font, Color(self.color.r, self.color.g, self.color.b, 240))

    def set_pos(self, x, y):
        self.x = x
        self.y = y

    def show(self):
        self.visible = true

    def hide(self):
        self.visible = false

# ─── ProgressTrack ────────────────────────────────────────────────────────────
class ProgressTrack:
    def __init__(self, x, y, w, label):
        self.x = x
        self.y = y
        self.w = w
        self.label = label
        self.value = 0.0
        self.target = 0.0
        self.color = Color(99, 102, 241, 255)
        self.visible = true
        self.font = Font("sans-serif", 12, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.id = ""

    def set_value(self, v):
        self.value = v
        self.target = v
        return self

    def set_color(self, c):
        self.color = c
        return self

    def update(self):
        if self.value < self.target:
            self.value = self.value + (self.target - self.value) * 0.1
            if self.target - self.value < 0.005:
                self.value = self.target

    def draw(self, renderer):
        if not self.visible:
            return
        self.update()
        renderer.draw_text(self.label, self.x, self.y, self.font, Color(160, 162, 200, 200))
        var pct_str = str(int(self.value * 100.0)) + "%"
        renderer.draw_text(pct_str, self.x + self.w - 36, self.y, self.font_bold, Color(self.color.r, self.color.g, self.color.b, 220))
        var track_r = Rect(self.x, self.y + 18, self.w, 6)
        renderer.fill_rounded_rect(track_r, Color(255, 255, 255, 12), 3)
        var fill_w = int(float(self.w) * self.value)
        if fill_w > 0:
            renderer.fill_rounded_rect(Rect(self.x, self.y + 18, fill_w, 6), self.color, 3)
            renderer.fill_rounded_rect(Rect(self.x, self.y + 18, fill_w, 3), Color(255, 255, 255, 30), 3)

    def set_pos(self, x, y):
        self.x = x
        self.y = y

    def show(self):
        self.visible = true

    def hide(self):
        self.visible = false

# ─── KeybindRow ───────────────────────────────────────────────────────────────
class KeybindRow:
    def __init__(self, action, keys, description):
        self.action = action
        self.keys = keys
        self.description = description


class KeybindPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.rows = []
        self.row_count = 0
        self.scroll_y = 0
        self.filter_text = ""
        self.visible = false
        self.bg = Color(16, 18, 32, 252)
        self.border = Color(99, 102, 241, 60)
        self.font = Font("sans-serif", 13, false, false)
        self.font_bold = Font("sans-serif", 13, true, false)
        self.font_key = Font("monospace", 12, true, false)
        self.font_header = Font("sans-serif", 11, false, false)
        self.id = ""

    def add(self, action, keys, description):
        self.rows.append(KeybindRow(action, keys, description))
        self.row_count = self.row_count + 1
        return self

    def show(self):
        self.visible = true
        return self

    def hide(self):
        self.visible = false
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "keydown" and event.key == "escape":
            self.hide()
            event.consume()
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * 24
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_s = self.row_count * 38 - self.rect.h + 80
            if max_s < 0:
                var max_s = 0
            if self.scroll_y > max_s:
                self.scroll_y = max_s

    def draw(self, renderer):
        if not self.visible:
            return
        renderer.draw_shadow(self.rect, 40, 0, 16, Color(0, 0, 0, 180))
        renderer.fill_rounded_rect(self.rect, self.bg, 16)
        renderer.draw_rounded_rect(self.rect, self.border, 16, 1)
        var hdr_r = Rect(self.rect.x, self.rect.y, self.rect.w, 52)
        renderer.fill_rounded_rect(hdr_r, Color(0, 0, 0, 40), 16)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y + 36, self.rect.w, 16), Color(0, 0, 0, 40))
        renderer.draw_text("?  Keyboard Shortcuts", self.rect.x + 20, self.rect.y + 16, self.font_bold, Color(220, 222, 255, 240))
        renderer.draw_text("Esc to close", self.rect.right() - 90, self.rect.y + 18, self.font_header, Color(100, 102, 140, 160))
        renderer.draw_line(self.rect.x, self.rect.y + 52, self.rect.right(), self.rect.y + 52, Color(255,255,255,8), 1)
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 52, self.rect.w, self.rect.h - 52))
        var row_h = 38
        var i = 0
        while i < self.row_count:
            var row = self.rows[i]
            var ry = self.rect.y + 52 + i * row_h - self.scroll_y + 6
            if i % 2 == 0:
                renderer.fill_rect(Rect(self.rect.x, ry - 4, self.rect.w, row_h), Color(255,255,255,3))
            renderer.draw_text(row.description, self.rect.x + 20, ry + 4, self.font, Color(180, 182, 220, 200))
            var kx = self.rect.right() - 20
            var ki = len(row.keys) - 1
            while ki >= 0:
                var k = row.keys[ki]
                var kw = len(k) * 9 + 14
                kx = kx - kw - 4
                renderer.fill_rounded_rect(Rect(kx, ry, kw, 22), Color(255, 255, 255, 10), 5)
                renderer.draw_rounded_rect(Rect(kx, ry, kw, 22), Color(255, 255, 255, 20), 5, 1)
                renderer.draw_text(k, kx + 7, ry + 4, self.font_key, Color(200, 202, 240, 220))
                ki = ki - 1
            i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h

# ─── ActivityBar ──────────────────────────────────────────────────────────────
class ActivityItem:
    def __init__(self, id, icon, tooltip):
        self.id = id
        self.icon = icon
        self.tooltip = tooltip
        self.active = false
        self.badge = 0


class ActivityBar:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.items = []
        self.item_count = 0
        self.active_id = ""
        self.bg = Color(14, 16, 28, 255)
        self.accent = Color(99, 102, 241, 255)
        self.hover_id = ""
        self.font_icon = Font("sans-serif", 20, false, false)
        self.font_badge = Font("sans-serif", 9, true, false)
        self.font_logo = Font("sans-serif", 20, true, false)
        self.visible = true
        self.id = ""
        self._on_select = none

    def add_item(self, icon, label, active):
        var item = ActivityItem(icon, icon, label)
        if active:
            item.active = true
            self.active_id = icon
        self.items.append(item)
        self.item_count = self.item_count + 1
        return self

    def set_badge(self, id, n):
        var i = 0
        while i < self.item_count:
            if self.items[i].id == id:
                self.items[i].badge = n
            i = i + 1
        return self

    def on_select(self, fn):
        self._on_select = fn
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "mousemove":
            self.hover_id = ""
            var i = 0
            while i < self.item_count:
                var iy = self.y + 60 + i * 52
                if event.x >= self.x and event.x <= self.x + self.w and event.y >= iy and event.y <= iy + 44:
                    self.hover_id = self.items[i].id
                i = i + 1
        elif event.type == "mousedown" and event.x >= self.x and event.x <= self.x + self.w:
            var i = 0
            while i < self.item_count:
                var iy = self.y + 60 + i * 52
                if event.y >= iy and event.y <= iy + 44:
                    self.active_id = self.items[i].id
                    var j = 0
                    while j < self.item_count:
                        self.items[j].active = (self.items[j].id == self.active_id)
                        j = j + 1
                    if self._on_select != none:
                        self._on_select(self.items[i])
                    event.consume()
                i = i + 1

    def draw(self, renderer):
        if not self.visible:
            return
        renderer.fill_rect(Rect(self.x, self.y, self.w, self.h), self.bg)
        renderer.draw_line(self.x + self.w - 1, self.y, self.x + self.w - 1, self.y + self.h, Color(255,255,255,6), 1)
        renderer.fill_rounded_rect(Rect(self.x + 8, self.y + 8, 32, 36), Color(99,102,241,30), 8)
        renderer.draw_text("*", self.x + 12, self.y + 14, self.font_logo, self.accent)
        var i = 0
        while i < self.item_count:
            var item = self.items[i]
            var iy = self.y + 60 + i * 52
            if item.active:
                renderer.fill_rect(Rect(self.x, iy + 2, 3, 40), self.accent)
                renderer.fill_rounded_rect(Rect(self.x + 4, iy, self.w - 8, 44), Color(self.accent.r, self.accent.g, self.accent.b, 20), 8)
            elif item.id == self.hover_id:
                renderer.fill_rounded_rect(Rect(self.x + 4, iy, self.w - 8, 44), Color(255,255,255,8), 8)
            var ic = self.accent if item.active else Color(120, 122, 160, 180)
            renderer.draw_text(item.icon, self.x + 12, iy + 12, self.font_icon, ic)
            if item.badge > 0:
                var bx = self.x + self.w - 14
                var by = iy + 4
                renderer.fill_circle(bx, by, 9, Color(255, 59, 48, 255))
                renderer.draw_text(str(item.badge), bx - 4, by - 6, self.font_badge, Color(255,255,255,255))
            i = i + 1
        var settings_y = self.h - 52
        renderer.draw_text("?", self.x + 13, settings_y + 12, self.font_icon, Color(100, 102, 140, 160))

    def set_pos(self, x, y):
        self.x = x
        self.y = y

    def set_size(self, w, h):
        self.w = w
        self.h = h

    def show(self):
        self.visible = true

    def hide(self):
        self.visible = false

# ─── DiagnosticPanel ──────────────────────────────────────────────────────────
class DiagnosticItem:
    def __init__(self, file, line, col, kind, message):
        self.file = file
        self.line = line
        self.col = col
        self.kind = kind
        self.message = message


class DiagnosticPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.items = []
        self.item_count = 0
        self.error_count = 0
        self.warn_count = 0
        self.scroll_y = 0
        self.selected = -1
        self.visible = true
        self.bg = Color(14, 16, 26, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.item_h = 36
        self.id = ""
        self._on_click = none

    def add_error(self, file, line, col, message):
        self.items.append(DiagnosticItem(file, line, col, "error", message))
        self.item_count = self.item_count + 1
        self.error_count = self.error_count + 1
        return self

    def add_warning(self, file, line, col, message):
        self.items.append(DiagnosticItem(file, line, col, "warning", message))
        self.item_count = self.item_count + 1
        self.warn_count = self.warn_count + 1
        return self

    def clear(self):
        self.items = []
        self.item_count = 0
        self.error_count = 0
        self.warn_count = 0
        return self

    def on_click(self, fn):
        self._on_click = fn
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h
            if self.scroll_y < 0:
                self.scroll_y = 0
            var max_s = self.item_count * self.item_h - self.rect.h + 40
            if max_s < 0:
                var max_s = 0
            if self.scroll_y > max_s:
                self.scroll_y = max_s
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var iy = self.rect.y + 36 - self.scroll_y
            var i = 0
            while i < self.item_count:
                if event.y >= iy and event.y < iy + self.item_h:
                    self.selected = i
                    if self._on_click != none:
                        self._on_click(self.items[i])
                    event.consume()
                iy = iy + self.item_h
                i = i + 1

    def draw(self, renderer):
        if not self.visible:
            return
        renderer.fill_rect(self.rect, self.bg)
        var hdr_r = Rect(self.rect.x, self.rect.y, self.rect.w, 34)
        renderer.fill_rect(hdr_r, Color(20, 22, 36, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 34, self.rect.right(), self.rect.y + 34, self.border, 1)
        renderer.draw_text("PROBLEMS", self.rect.x + 12, self.rect.y + 10, self.font_ui, Color(100,102,140,180))
        var ex = self.rect.x + 90
        renderer.fill_rounded_rect(Rect(ex, self.rect.y + 8, 28, 18), Color(255, 59, 48, 30), 5)
        renderer.draw_text(str(self.error_count), ex + 8, self.rect.y + 10, self.font_ui, Color(255, 59, 48, 220))
        renderer.fill_rounded_rect(Rect(ex + 36, self.rect.y + 8, 28, 18), Color(255, 149, 0, 30), 5)
        renderer.draw_text(str(self.warn_count), ex + 44, self.rect.y + 10, self.font_ui, Color(255, 149, 0, 220))
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 34, self.rect.w, self.rect.h - 34))
        var iy = self.rect.y + 34 - self.scroll_y
        var i = 0
        while i < self.item_count:
            var item = self.items[i]
            var ir = Rect(self.rect.x, iy, self.rect.w, self.item_h)
            if i == self.selected:
                renderer.fill_rect(ir, Color(self.accent.r, self.accent.g, self.accent.b, 20))
            elif i % 2 == 0:
                renderer.fill_rect(ir, Color(255,255,255,3))
            var dot_c = Color(255, 59, 48, 255) if item.kind == "error" else Color(255, 149, 0, 255)
            var dot_icon = "?" if item.kind == "error" else "!"
            renderer.draw_text(dot_icon, self.rect.x + 10, iy + 10, self.font_ui, dot_c)
            renderer.draw_text(item.message, self.rect.x + 28, iy + 10, self.font, Color(200, 202, 240, 210))
            var loc_str = item.file + ":" + str(item.line) + ":" + str(item.col)
            renderer.draw_text(loc_str, self.rect.right() - len(loc_str) * 7 - 10, iy + 10, self.font_ui, Color(100,102,140,160))
            renderer.draw_line(self.rect.x, iy + self.item_h - 1, self.rect.right(), iy + self.item_h - 1, Color(255,255,255,4), 1)
            iy = iy + self.item_h
            i = i + 1
        if self.item_count == 0:
            renderer.draw_text("[OK]  No problems detected", self.rect.x + int(self.rect.w / 2) - 80, self.rect.y + int(self.rect.h / 2) - 8, self.font_bold, Color(52, 199, 89, 160))
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h

    def show(self):
        self.visible = true

    def hide(self):
        self.visible = false

# ─── SearchPanel ──────────────────────────────────────────────────────────────
class SearchResult:
    def __init__(self, file, line, col, text, match):
        self.file = file
        self.line = line
        self.col = col
        self.text = text
        self.match = match


class SearchPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.query = ""
        self.replace_text = ""
        self.results = []
        self.result_count = 0
        self.focused = false
        self.scroll_y = 0
        self.visible = false
        self.show_replace = false
        self.bg = Color(17, 19, 33, 255)
        self.input_bg = Color(24, 26, 44, 255)
        self.accent = Color(99, 102, 241, 255)
        self.border = Color(255,255,255,8)
        self.font = Font("sans-serif", 13, false, false)
        self.font_bold = Font("sans-serif", 13, true, false)
        self.font_mono = Font("monospace", 12, false, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.id = ""
        self._on_search = none
        self._on_jump = none

    def on_search(self, fn):
        self._on_search = fn
        return self

    def on_jump(self, fn):
        self._on_jump = fn
        return self

    def add_result(self, file, line, col, text, match):
        self.results.append(SearchResult(file, line, col, text, match))
        self.result_count = self.result_count + 1
        return self

    def clear_results(self):
        self.results = []
        self.result_count = 0
        return self

    def show(self):
        self.visible = true
        self.focused = true
        return self

    def hide(self):
        self.visible = false
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        var input_r = Rect(self.rect.x + 8, self.rect.y + 44, self.rect.w - 16, 32)
        if event.type == "keydown" and self.focused:
            if event.key == "escape":
                self.hide()
                event.consume()
            elif event.key == "enter":
                if self._on_search != none:
                    self._on_search(self.query)
                event.consume()
            elif event.key == "backspace" and len(self.query) > 0:
                self.query = self.query[0:len(self.query) - 1]
        elif event.type == "textinput" and self.focused:
            self.query = self.query + event.text
        elif event.type == "mousedown":
            self.focused = input_r.contains(event.x, event.y)
            if self.rect.contains(event.x, event.y) and not self.focused:
                var iy = self.rect.y + 110 - self.scroll_y
                var i = 0
                while i < self.result_count:
                    if event.y >= iy and event.y < iy + 40:
                        if self._on_jump != none:
                            self._on_jump(self.results[i])
                        event.consume()
                    iy = iy + 40
                    i = i + 1
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * 40
            if self.scroll_y < 0:
                self.scroll_y = 0

    def draw(self, renderer):
        if not self.visible:
            return
        renderer.fill_rounded_rect(self.rect, self.bg, 0)
        renderer.draw_line(self.rect.right() - 1, self.rect.y, self.rect.right() - 1, self.rect.bottom(), self.border, 1)
        renderer.draw_text("SEARCH", self.rect.x + 12, self.rect.y + 12, self.font_ui, Color(100,102,140,180))
        var esc_r = Rect(self.rect.right() - 30, self.rect.y + 8, 22, 18)
        renderer.fill_rounded_rect(esc_r, Color(255,255,255,8), 4)
        renderer.draw_text("?", esc_r.x + 5, esc_r.y + 2, self.font_ui, Color(120,122,160,160))
        var inp_r = Rect(self.rect.x + 8, self.rect.y + 36, self.rect.w - 16, 32)
        renderer.fill_rounded_rect(inp_r, self.input_bg, 8)
        if self.focused:
            renderer.draw_rounded_rect(inp_r, Color(self.accent.r, self.accent.g, self.accent.b, 120), 8, 1)
        else:
            renderer.draw_rounded_rect(inp_r, self.border, 8, 1)
        renderer.draw_text("?", inp_r.x + 8, inp_r.y + 9, self.font, Color(100,102,140,180))
        if self.query != "":
            renderer.draw_text(self.query, inp_r.x + 28, inp_r.y + 9, self.font_mono, Color(220, 222, 255, 230))
            if self.focused:
                var cx = inp_r.x + 28 + len(self.query) * 7
                renderer.fill_rect(Rect(cx, inp_r.y + 7, 2, 18), self.accent)
        else:
            renderer.draw_text("Find in files...", inp_r.x + 28, inp_r.y + 9, self.font, Color(80,82,120,140))
        if self.result_count > 0:
            renderer.draw_text(str(self.result_count) + " results", self.rect.x + 12, self.rect.y + 76, self.font_ui, Color(100,102,140,160))
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 96, self.rect.w, self.rect.h - 96))
        var iy = self.rect.y + 96 - self.scroll_y
        var i = 0
        while i < self.result_count:
            var res = self.results[i]
            var ir = Rect(self.rect.x, iy, self.rect.w, 40)
            renderer.fill_rect(ir, Color(255,255,255, 3 if i % 2 == 0 else 0))
            renderer.draw_text(res.file + ":" + str(res.line), self.rect.x + 10, iy + 4, self.font_ui, Color(99, 102, 141, 200))
            renderer.draw_text(string_strip(res.text), self.rect.x + 10, iy + 20, self.font_mono, Color(180,182,220,190))
            renderer.draw_line(self.rect.x, iy + 39, self.rect.right(), iy + 39, Color(255,255,255,4), 1)
            iy = iy + 40
            i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h

# ─── GitPanel ─────────────────────────────────────────────────────────────────
class GitChange:
    def __init__(self, path, status):
        self.path = path
        self.status = status
        self.staged = false


class GitPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.changes = []
        self.change_count = 0
        self.commit_msg = ""
        self.branch = "main"
        self.commit_input_focused = false
        self.visible = true
        self.bg = Color(17, 19, 33, 255)
        self.accent = Color(99, 102, 241, 255)
        self.border = Color(255,255,255,8)
        self.font = Font("sans-serif", 12, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_mono = Font("monospace", 12, false, false)
        self.id = ""
        self._on_commit = none
        self._on_stage = none

    def add_change(self, path, status):
        self.changes.append(GitChange(path, status))
        self.change_count = self.change_count + 1
        return self

    def on_commit(self, fn):
        self._on_commit = fn
        return self

    def on_stage(self, fn):
        self._on_stage = fn
        return self

    def handle_event(self, event):
        if not self.visible:
            return
        var inp_r = Rect(self.rect.x + 8, self.rect.bottom() - 80, self.rect.w - 16, 30)
        if event.type == "mousedown":
            self.commit_input_focused = inp_r.contains(event.x, event.y)
            if self.rect.contains(event.x, event.y):
                var iy = self.rect.y + 52
                var i = 0
                while i < self.change_count:
                    var ir = Rect(self.rect.x, iy, self.rect.w, 32)
                    if ir.contains(event.x, event.y):
                        self.changes[i].staged = not self.changes[i].staged
                        if self._on_stage != none:
                            self._on_stage(self.changes[i])
                        event.consume()
                    iy = iy + 32
                    i = i + 1
        elif event.type == "keydown" and self.commit_input_focused:
            if event.key == "enter" and self.commit_msg != "":
                if self._on_commit != none:
                    self._on_commit(self.commit_msg)
                self.commit_msg = ""
            elif event.key == "backspace" and len(self.commit_msg) > 0:
                self.commit_msg = self.commit_msg[0:len(self.commit_msg) - 1]
        elif event.type == "textinput" and self.commit_input_focused:
            self.commit_msg = self.commit_msg + event.text

    def draw(self, renderer):
        if not self.visible:
            return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_line(self.rect.right() - 1, self.rect.y, self.rect.right() - 1, self.rect.bottom(), self.border, 1)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y, self.rect.w, 48), Color(0,0,0,30))
        renderer.draw_text("SOURCE CONTROL", self.rect.x + 12, self.rect.y + 10, self.font_ui, Color(100,102,140,180))
        renderer.fill_rounded_rect(Rect(self.rect.x + 12, self.rect.y + 26, 80, 16), Color(99,102,241,20), 5)
        renderer.draw_text("[branch] " + self.branch, self.rect.x + 16, self.rect.y + 27, self.font_ui, Color(99, 102, 141, 200))
        renderer.draw_line(self.rect.x, self.rect.y + 48, self.rect.right(), self.rect.y + 48, self.border, 1)
        var staged_c = 0
        var i = 0
        while i < self.change_count:
            if self.changes[i].staged:
                staged_c = staged_c + 1
            i = i + 1
        renderer.draw_text("Changes (" + str(self.change_count) + ")", self.rect.x + 10, self.rect.y + 54, self.font_ui, Color(120,122,160,160))
        var iy = self.rect.y + 72
        i = 0
        while i < self.change_count:
            var ch = self.changes[i]
            var ir = Rect(self.rect.x, iy, self.rect.w, 30)
            if ch.staged:
                renderer.fill_rect(ir, Color(self.accent.r, self.accent.g, self.accent.b, 12))
            var cb = Rect(self.rect.x + 8, iy + 7, 16, 16)
            renderer.fill_rounded_rect(cb, Color(255,255,255, 15 if ch.staged else 6), 4)
            renderer.draw_rounded_rect(cb, Color(255,255,255,20), 4, 1)
            if ch.staged:
                renderer.draw_text("[OK]", cb.x + 3, cb.y + 2, self.font_ui, Color(52, 199, 89, 220))
            var sc = Color(255, 149, 0, 220)
            if ch.status == "A":
                var sc = Color(52, 199, 89, 220)
            elif ch.status == "D":
                sc = Color(255, 59, 48, 220)
            var fname = ch.path
            if len(fname) > 20:
                fname = "..." + fname[len(fname) - 19:]
            renderer.draw_text(fname, self.rect.x + 30, iy + 9, self.font_mono, Color(180,182,220,200))
            renderer.draw_text(ch.status, self.rect.right() - 18, iy + 9, self.font_bold, sc)
            iy = iy + 30
            i = i + 1
        renderer.draw_line(self.rect.x, self.rect.bottom() - 90, self.rect.right(), self.rect.bottom() - 90, self.border, 1)
        var inp_r = Rect(self.rect.x + 8, self.rect.bottom() - 84, self.rect.w - 16, 30)
        renderer.fill_rounded_rect(inp_r, Color(24,26,44,255), 8)
        if self.commit_input_focused:
            renderer.draw_rounded_rect(inp_r, Color(self.accent.r, self.accent.g, self.accent.b, 100), 8, 1)
        else:
            renderer.draw_rounded_rect(inp_r, self.border, 8, 1)
        var commit_display = self.commit_msg if self.commit_msg != "" else "Commit message..."
        var commit_c = Color(180,182,220,210) if self.commit_msg != "" else Color(80,82,120,120)
        renderer.draw_text(commit_display, inp_r.x + 8, inp_r.y + 8, self.font, commit_c)
        var commit_btn = Rect(self.rect.x + 8, self.rect.bottom() - 46, self.rect.w - 16, 30)
        var btn_active = self.commit_msg != "" and staged_c > 0
        var btn_bg = Color(self.accent.r, self.accent.g, self.accent.b, 200 if btn_active else 40)
        renderer.fill_rounded_rect(commit_btn, btn_bg, 8)
        renderer.draw_text("[OK]  Commit (" + str(staged_c) + " staged)", commit_btn.x + int((commit_btn.w - 130) / 2), commit_btn.y + 8, self.font_bold, Color(255,255,255, 220 if btn_active else 80))

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y

    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h

    def show(self):
        self.visible = true

    def hide(self):
        self.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# WAVE 7  -  Compiler / Debug / Analysis Widgets
# ═══════════════════════════════════════════════════════════════════════════════

# ─── RunConfigBar  -  compilation/run mode toolbar ──────────────────────────────
class RunConfigBar:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.modes = ["Run", "Debug", "Tokenize", "AST", "Disasm", "REPL", "Profile"]
        self.mode_icons = [">", "O", "<>", "[tree]", "~", ">>", "[time]"]
        self.active_mode = 0
        self.hover_mode = -1
        self.bg = Color(14, 16, 30, 255)
        self.accent = Color(99, 102, 241, 255)
        self.green = Color(52, 199, 89, 255)
        self.orange = Color(255, 149, 0, 255)
        self.red = Color(255, 59, 48, 255)
        self.font = Font("sans-serif", 11, true, false)
        self.font_icon = Font("sans-serif", 13, false, false)
        self.font_small = Font("sans-serif", 10, false, false)
        self.visible = true
        self.id = ""
        self._on_mode = none
        self._on_run = none

    def on_mode(self, fn):
        self._on_mode = fn
        return self

    def on_run(self, fn):
        self._on_run = fn
        return self

    def _mode_color(self, idx):
        if idx == 0: return self.green
        if idx == 1: return self.red
        if idx == 6: return self.orange
        return self.accent

    def handle_event(self, event):
        if not self.visible: return
        if event.type == "mousemove":
            self.hover_mode = -1
            if self.rect.contains(event.x, event.y):
                var bw = 86
                var i = 0
                while i < len(self.modes):
                    var bx = self.rect.x + 8 + i * (bw + 6)
                    if event.x >= bx and event.x <= bx + bw:
                        self.hover_mode = i
                    i = i + 1
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var bw = 86
            var i = 0
            while i < len(self.modes):
                var bx = self.rect.x + 8 + i * (bw + 6)
                if event.x >= bx and event.x <= bx + bw:
                    self.active_mode = i
                    if self._on_mode != none: self._on_mode(i, self.modes[i])
                    event.consume()
                i = i + 1
            var run_bx = self.rect.right() - 110
            if event.x >= run_bx and event.x <= run_bx + 100:
                if self._on_run != none: self._on_run(self.active_mode, self.modes[self.active_mode])
                event.consume()

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_line(self.rect.x, self.rect.y, self.rect.right(), self.rect.y, Color(255,255,255,8), 1)
        renderer.draw_line(self.rect.x, self.rect.bottom()-1, self.rect.right(), self.rect.bottom()-1, Color(255,255,255,6), 1)
        var bw = 86
        var i = 0
        while i < len(self.modes):
            var bx = self.rect.x + 8 + i * (bw + 6)
            var by = self.rect.y + 5
            var bh = self.rect.h - 10
            var is_active = (i == self.active_mode)
            var is_hover = (i == self.hover_mode)
            var mc = self._mode_color(i)
            if is_active:
                renderer.fill_rounded_rect(Rect(bx, by, bw, bh), Color(mc.r, mc.g, mc.b, 28), 7)
                renderer.draw_rounded_rect(Rect(bx, by, bw, bh), Color(mc.r, mc.g, mc.b, 100), 7, 1)
                renderer.fill_rect(Rect(bx + 8, by + bh - 2, bw - 16, 2), mc)
            elif is_hover:
                renderer.fill_rounded_rect(Rect(bx, by, bw, bh), Color(255,255,255,8), 7)
            renderer.draw_text(self.mode_icons[i], bx + 8, by + 6, self.font_icon, Color(mc.r, mc.g, mc.b, 210 if is_active else 130))
            renderer.draw_text(self.modes[i], bx + 24, by + 8, self.font, Color(220,222,255, 230 if is_active else 140))
            i = i + 1
        var run_bx = self.rect.right() - 110
        var run_c = self._mode_color(self.active_mode)
        renderer.fill_rounded_rect(Rect(run_bx, self.rect.y + 5, 100, self.rect.h - 10), Color(run_c.r, run_c.g, run_c.b, 35), 8)
        renderer.draw_rounded_rect(Rect(run_bx, self.rect.y + 5, 100, self.rect.h - 10), Color(run_c.r, run_c.g, run_c.b, 100), 8, 1)
        renderer.draw_text(">  " + self.modes[self.active_mode], run_bx + 10, self.rect.y + 11, self.font, Color(run_c.r, run_c.g, run_c.b, 230))

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false

# ─── TokenViewer  -  renders the XML token stream beautifully ──────────────────
class TokenEntry:
    def __init__(self, value, tok_type, tok_kind, tok_class, line, col):
        self.value = value
        self.tok_type = tok_type
        self.tok_kind = tok_kind
        self.tok_class = tok_class
        self.line = line
        self.col = col


class TokenViewer:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.tokens = []
        self.token_count = 0
        self.scroll_y = 0
        self.selected = -1
        self.filter_class = ""
        self.visible = false
        self.bg = Color(13, 15, 27, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_tag = Font("sans-serif", 10, true, false)
        self.item_h = 28
        self.id = ""
        self._on_click = none

    def _class_color(self, cls):
        if cls == "Keyword": return Color(196, 148, 255, 255)
        if cls == "Identifier": return Color(86, 196, 255, 255)
        if cls == "Literal": return Color(130, 215, 100, 255)
        if cls == "Delimiter": return Color(120, 122, 160, 180)
        if cls == "Assignment": return Color(255, 149, 0, 220)
        if cls == "Operator": return Color(248, 186, 80, 220)
        if cls == "Eof": return Color(80, 82, 100, 140)
        return Color(180, 182, 220, 200)

    def parse_xml(self, xml_text):
        self.tokens = []
        self.token_count = 0
        var lines = []
        var rem = xml_text
        while len(rem) > 0:
            var nl = string_find(rem, "\n")
            if nl < 0:
                lines.append(rem)
                var rem = ""
            else:
                lines.append(rem[0:nl])
                rem = rem[nl+1:]
        var cur_val = ""
        var cur_type = ""
        var cur_kind = ""
        var cur_class = ""
        var cur_line = 0
        var cur_col = 0
        var i = 0
        while i < len(lines):
            var ln = string_strip(lines[i])
            if string_startswith(ln, "<Token "):
                var cur_val = ""
                var cur_type = ""
                var cur_kind = ""
                var cur_class = ""
                var cur_line = 0
                var cur_col = 0
                var vi = string_find(ln, "value=\"")
                if vi >= 0:
                    var vs = vi + 7
                    var ve = string_find(ln[vs:], "\"")
                    if ve >= 0: cur_val = ln[vs:vs+ve]
                var li = string_find(ln, "line=\"")
                if li >= 0:
                    var ls = li + 6
                    var le = string_find(ln[ls:], "\"")
                    if le >= 0: cur_line = int(ln[ls:ls+le])
                var ci = string_find(ln, "column=\"")
                if ci >= 0:
                    var cs = ci + 8
                    var ce = string_find(ln[cs:], "\"")
                    if ce >= 0: cur_col = int(ln[cs:cs+ce])
            elif string_startswith(ln, "<TokenType "):
                var vi = string_find(ln, "value=\"")
                if vi >= 0:
                    var vs = vi + 7
                    var ve = string_find(ln[vs:], "\"")
                    if ve >= 0: cur_type = ln[vs:vs+ve]
            elif string_startswith(ln, "<TokenKind "):
                var vi = string_find(ln, "value=\"")
                if vi >= 0:
                    var vs = vi + 7
                    var ve = string_find(ln[vs:], "\"")
                    if ve >= 0: cur_kind = ln[vs:vs+ve]
            elif string_startswith(ln, "<TokenClass "):
                var vi = string_find(ln, "value=\"")
                if vi >= 0:
                    var vs = vi + 7
                    var ve = string_find(ln[vs:], "\"")
                    if ve >= 0: cur_class = ln[vs:vs+ve]
            elif string_startswith(ln, "</Token>"):
                if cur_val != "newline" and cur_val != "End" and cur_val != "":
                    self.tokens.append(TokenEntry(cur_val, cur_type, cur_kind, cur_class, cur_line, cur_col))
                    self.token_count = self.token_count + 1
            i = i + 1

    def set_raw(self, lines_list):
        self.tokens = []
        self.token_count = 0
        var i = 0
        while i < len(lines_list):
            var tk = TokenEntry(lines_list[i]["v"], lines_list[i]["t"], lines_list[i]["k"], lines_list[i]["c"], lines_list[i]["ln"], lines_list[i]["col"])
            self.tokens.append(tk)
            self.token_count = self.token_count + 1
            i = i + 1

    def on_click(self, fn):
        self._on_click = fn
        return self

    def handle_event(self, event):
        if not self.visible: return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h * 3
            if self.scroll_y < 0: self.scroll_y = 0
            var mx = self.token_count * self.item_h - self.rect.h + 48
            if mx < 0: mx = 0
            if self.scroll_y > mx: self.scroll_y = mx
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var iy = self.rect.y + 44 - self.scroll_y
            var i = 0
            while i < self.token_count:
                if event.y >= iy and event.y < iy + self.item_h:
                    self.selected = i
                    if self._on_click != none: self._on_click(self.tokens[i])
                    event.consume()
                iy = iy + self.item_h
                i = i + 1

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_rounded_rect(self.rect, self.border, 0, 1)
        var hdr = Rect(self.rect.x, self.rect.y, self.rect.w, 44)
        renderer.fill_rect(hdr, Color(20, 22, 38, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 44, self.rect.right(), self.rect.y + 44, self.border, 1)
        renderer.draw_text("<>  TOKEN STREAM", self.rect.x + 14, self.rect.y + 12, self.font_bold, Color(99, 102, 241, 220))
        renderer.draw_text(str(self.token_count) + " tokens", self.rect.right() - 72, self.rect.y + 14, self.font_ui, Color(100,102,140,160))
        var col_v  = self.rect.x + 14
        var col_t  = self.rect.x + 148
        var col_k  = self.rect.x + 296
        var col_c  = self.rect.x + 416
        var col_ln = self.rect.right() - 60
        renderer.draw_text("VALUE", col_v, self.rect.y + 28, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("TYPE", col_t, self.rect.y + 28, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("KIND", col_k, self.rect.y + 28, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("CLASS", col_c, self.rect.y + 28, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("LN:COL", col_ln, self.rect.y + 28, self.font_tag, Color(80,82,110,160))
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 44, self.rect.w, self.rect.h - 44))
        var first = int(self.scroll_y / self.item_h)
        var vis_count = int(self.rect.h / self.item_h) + 2
        var i = max(0, first)
        while i < self.token_count and i < first + vis_count:
            var tk = self.tokens[i]
            var iy = self.rect.y + 44 + i * self.item_h - self.scroll_y
            var cc = self._class_color(tk.tok_class)
            if i == self.selected:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(self.accent.r, self.accent.g, self.accent.b, 22))
                renderer.fill_rect(Rect(self.rect.x, iy, 3, self.item_h), self.accent)
            elif i % 2 == 0:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(255,255,255,3))
            var val_disp = tk.value
            if len(val_disp) > 14: val_disp = val_disp[0:12] + "..."
            renderer.draw_text(val_disp, col_v, iy + 8, self.font_bold, cc)
            renderer.draw_text(tk.tok_type, col_t, iy + 8, self.font, Color(180,182,220,190))
            renderer.draw_text(tk.tok_kind, col_k, iy + 8, self.font, Color(140,142,180,170))
            var cls_pill_w = len(tk.tok_class) * 7 + 12
            renderer.fill_rounded_rect(Rect(col_c, iy + 4, cls_pill_w, 20), Color(cc.r, cc.g, cc.b, 20), 5)
            renderer.draw_text(tk.tok_class, col_c + 6, iy + 8, self.font_tag, Color(cc.r, cc.g, cc.b, 200))
            renderer.draw_text(str(tk.line) + ":" + str(tk.col), col_ln, iy + 8, self.font_ui, Color(80,82,110,150))
            renderer.draw_line(self.rect.x, iy + self.item_h - 1, self.rect.right(), iy + self.item_h - 1, Color(255,255,255,4), 1)
            i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false

# ─── ASTViewer  -  renders XML AST as an interactive tree ──────────────────────
class ASTNode2:
    def __init__(self, tag, attrs, depth):
        self.tag = tag
        self.attrs = attrs
        self.depth = depth
        self.expanded = true
        self.has_children = false


class ASTViewer:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.nodes = []
        self.node_count = 0
        self.scroll_y = 0
        self.selected = -1
        self.visible = false
        self.bg = Color(13, 15, 27, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_tag = Font("sans-serif", 10, true, false)
        self.item_h = 26
        self.indent_w = 18
        self.id = ""

    def _tag_color(self, tag):
        if tag == "Script" or tag == "Statements": return Color(99, 102, 241, 255)
        if tag == "Function": return Color(86, 196, 255, 255)
        if tag == "Class": return Color(252, 176, 98, 255)
        if tag == "VarDecl": return Color(130, 215, 100, 255)
        if tag == "If" or tag == "While" or tag == "For": return Color(255, 149, 0, 255)
        if tag == "Return": return Color(196, 148, 255, 255)
        if tag == "Node": return Color(140, 142, 180, 180)
        if tag == "Source" or tag == "Package": return Color(80, 82, 100, 160)
        return Color(180, 182, 220, 200)

    def parse_xml(self, xml_text):
        self.nodes = []
        self.node_count = 0
        var xml_lines = []
        var rem = xml_text
        while len(rem) > 0:
            var nl = string_find(rem, "\n")
            if nl < 0:
                xml_lines.append(rem)
                rem = ""
            else:
                xml_lines.append(rem[0:nl])
                rem = rem[nl + 1:]
        var depth = 0
        var i = 0
        while i < len(xml_lines):
            var ln = string_strip(xml_lines[i])
            if len(ln) == 0 or string_startswith(ln, "<?") or string_startswith(ln, "<!--"):
                i = i + 1
            elif string_startswith(ln, "</"):
                depth = depth - 1
                if depth < 0:
                    depth = 0
                i = i + 1
            elif string_startswith(ln, "<"):
                var tag_end = string_find(ln[1:], " ")
                var tag_end2 = string_find(ln[1:], ">")
                var te = tag_end
                if te < 0 or (tag_end2 >= 0 and tag_end2 < te):
                    te = tag_end2
                var tag = ""
                if te >= 0:
                    tag = ln[1:te + 1]
                else:
                    tag = ln[1:]
                var attrs = ln
                var self_closing = string_endswith(string_strip(ln), "/>")
                var new_node = ASTNode2(tag, attrs, depth)
                if not self_closing:
                    new_node.has_children = true
                    depth = depth + 1
                self.nodes.append(new_node)
                self.node_count = self.node_count + 1
                i = i + 1
            else:
                i = i + 1

    def handle_event(self, event):
        if not self.visible: return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h * 3
            if self.scroll_y < 0: self.scroll_y = 0
            var mx = self.node_count * self.item_h - self.rect.h + 44
            if mx < 0: mx = 0
            if self.scroll_y > mx: self.scroll_y = mx
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var iy = self.rect.y + 44 - self.scroll_y
            var i = 0
            while i < self.node_count:
                if event.y >= iy and event.y < iy + self.item_h:
                    self.selected = i
                    if self.nodes[i].has_children:
                        self.nodes[i].expanded = not self.nodes[i].expanded
                    event.consume()
                iy = iy + self.item_h
                i = i + 1

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_rounded_rect(self.rect, self.border, 0, 1)
        var hdr = Rect(self.rect.x, self.rect.y, self.rect.w, 44)
        renderer.fill_rect(hdr, Color(20, 22, 38, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 44, self.rect.right(), self.rect.y + 44, self.border, 1)
        renderer.draw_text("[tree]  AST VIEWER", self.rect.x + 14, self.rect.y + 13, self.font_bold, Color(252, 176, 98, 220))
        renderer.draw_text(str(self.node_count) + " nodes", self.rect.right() - 68, self.rect.y + 14, self.font_ui, Color(100,102,140,160))
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 44, self.rect.w, self.rect.h - 44))
        var first = int(self.scroll_y / self.item_h)
        var vis = int(self.rect.h / self.item_h) + 2
        var i = max(0, first)
        while i < self.node_count and i < first + vis:
            var node = self.nodes[i]
            var iy = self.rect.y + 44 + i * self.item_h - self.scroll_y
            var tc = self._tag_color(node.tag)
            if i == self.selected:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(self.accent.r, self.accent.g, self.accent.b, 22))
            elif i % 2 == 0:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(255,255,255,3))
            var ix = self.rect.x + 10 + node.depth * self.indent_w
            if node.depth > 0:
                renderer.fill_rect(Rect(ix - self.indent_w + 8, iy, 1, self.item_h), Color(255,255,255,8))
                renderer.fill_rect(Rect(ix - self.indent_w + 8, iy + int(self.item_h/2), self.indent_w - 8, 1), Color(255,255,255,8))
            if node.has_children:
                var arrow = "?" if node.expanded else "?"
                renderer.draw_text(arrow, ix, iy + 7, self.font_ui, Color(tc.r, tc.g, tc.b, 180))
                ix = ix + 14
            var tag_label = "<" + node.tag + ">"
            renderer.draw_text(tag_label, ix, iy + 6, self.font_bold, tc)
            var attr_start = string_find(node.attrs, " ")
            if attr_start >= 0:
                var attrs_str = node.attrs[attr_start:]
                var clean_attrs = ""
                var ai = 0
                while ai < len(attrs_str):
                    if attrs_str[ai:ai+1] == ">" or attrs_str[ai:ai+1] == "/":
                        var ai = len(attrs_str)
                    else:
                        clean_attrs = clean_attrs + attrs_str[ai:ai+1]
                        ai = ai + 1
                var disp = string_strip(clean_attrs)
                if len(disp) > 40: disp = disp[0:38] + "..."
                var lw = len(tag_label) * 8 + 8
                renderer.draw_text(disp, ix + lw, iy + 7, self.font_ui, Color(130, 132, 170, 170))
            renderer.draw_line(self.rect.x, iy + self.item_h - 1, self.rect.right(), iy + self.item_h - 1, Color(255,255,255,4), 1)
            i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false

# ─── DebugPanel  -  breakpoints, call stack, variable watch ────────────────────
class BreakpointEntry:
    def __init__(self, file, line, enabled):
        self.file = file
        self.line = line
        self.enabled = enabled
        self.hit_count = 0
        self.condition = ""


class WatchEntry:
    def __init__(self, expr, value):
        self.expr = expr
        self.value = value
        self.changed = false


class DebugPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.breakpoints = []
        self.bp_count = 0
        self.watches = []
        self.watch_count = 0
        self.call_stack = []
        self.stack_depth = 0
        self.current_line = -1
        self.current_file = ""
        self.running = false
        self.paused = false
        self.active_tab = 0
        self.tabs = ["Breakpoints", "Watch", "Call Stack"]
        self.scroll_y = 0
        self.bg = Color(14, 16, 28, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.green = Color(52, 199, 89, 255)
        self.red = Color(255, 59, 48, 255)
        self.orange = Color(255, 149, 0, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_bold = Font("sans-serif", 12, true, false)
        self.font_icon = Font("sans-serif", 14, false, false)
        self.visible = false
        self.id = ""
        self._on_step = none
        self._on_continue = none
        self._on_stop = none

    def add_breakpoint(self, file, line):
        var bp = BreakpointEntry(file, line, true)
        self.breakpoints.append(bp)
        self.bp_count = self.bp_count + 1
        return self

    def remove_breakpoint(self, file, line):
        var kept = []
        var i = 0
        while i < self.bp_count:
            if not (self.breakpoints[i].file == file and self.breakpoints[i].line == line):
                kept.append(self.breakpoints[i])
            i = i + 1
        self.breakpoints = kept
        self.bp_count = len(kept)
        return self

    def add_watch(self, expr, value):
        var w = WatchEntry(expr, value)
        self.watches.append(w)
        self.watch_count = self.watch_count + 1
        return self

    def update_watch(self, expr, new_val):
        var i = 0
        while i < self.watch_count:
            if self.watches[i].expr == expr:
                self.watches[i].changed = (self.watches[i].value != new_val)
                self.watches[i].value = new_val
            i = i + 1
        return self

    def push_frame(self, name, file, line):
        self.call_stack.append({"name": name, "file": file, "line": line})
        self.stack_depth = self.stack_depth + 1
        return self

    def clear_stack(self):
        self.call_stack = []
        self.stack_depth = 0
        return self

    def on_step(self, fn): self._on_step = fn
    def on_continue(self, fn): self._on_continue = fn
    def on_stop(self, fn): self._on_stop = fn

    def handle_event(self, event):
        if not self.visible: return
        var tab_h = 32
        var btn_y = self.rect.y + 2
        if event.type == "mousedown" and self.rect.contains(event.x, event.y):
            var tw = int(self.rect.w / 3)
            var ti = int((event.x - self.rect.x) / tw)
            if event.y >= self.rect.y and event.y < self.rect.y + tab_h:
                if ti >= 0 and ti < 3:
                    self.active_tab = ti
                    self.scroll_y = 0
                    event.consume()
            var step_x = self.rect.right() - 200
            if event.y >= btn_y and event.y <= btn_y + 28 and event.x >= step_x:
                var dx = event.x - step_x
                if dx < 44:
                    if self._on_step != none: self._on_step("into")
                    event.consume()
                elif dx < 88:
                    if self._on_step != none: self._on_step("over")
                    event.consume()
                elif dx < 132:
                    if self._on_continue != none: self._on_continue()
                    event.consume()
                elif dx < 176:
                    if self._on_stop != none: self._on_stop()
                    event.consume()
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * 26
            if self.scroll_y < 0: self.scroll_y = 0

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_line(self.rect.x, self.rect.y, self.rect.right(), self.rect.y, self.border, 1)
        var tab_h = 32
        var tw = int(self.rect.w / 3)
        renderer.fill_rect(Rect(self.rect.x, self.rect.y, self.rect.w, tab_h), Color(18, 20, 34, 255))
        var ti = 0
        while ti < 3:
            var tx = self.rect.x + ti * tw
            if ti == self.active_tab:
                renderer.fill_rect(Rect(tx, self.rect.y + tab_h - 2, tw, 2), self.accent)
                renderer.draw_text(self.tabs[ti], tx + 8, self.rect.y + 9, self.font_bold, Color(ACC.r, ACC.g, ACC.b, 220) if false else Color(self.accent.r, self.accent.g, self.accent.b, 220))
            else:
                renderer.draw_text(self.tabs[ti], tx + 8, self.rect.y + 9, self.font_ui, Color(100,102,140,160))
            renderer.draw_line(tx + tw - 1, self.rect.y + 6, tx + tw - 1, self.rect.y + tab_h - 6, self.border, 1)
            ti = ti + 1
        var dbg_icons = ["v", "?", ">", "?"]
        var dbg_tips  = ["Step Into", "Step Over", "Continue", "Stop"]
        var dbg_cols  = [self.accent, self.accent, self.green, self.red]
        var btn_x = self.rect.right() - 204
        var bi = 0
        while bi < 4:
            var bx = btn_x + bi * 46
            var is_active = (self.running or (bi < 3))
            var bc = dbg_cols[bi]
            renderer.fill_rounded_rect(Rect(bx, self.rect.y + 4, 40, 24), Color(bc.r, bc.g, bc.b, 22 if is_active else 8), 7)
            renderer.draw_rounded_rect(Rect(bx, self.rect.y + 4, 40, 24), Color(bc.r, bc.g, bc.b, 60 if is_active else 20), 7, 1)
            renderer.draw_text(dbg_icons[bi], bx + 12, self.rect.y + 7, self.font_icon, Color(bc.r, bc.g, bc.b, 200 if is_active else 60))
            bi = bi + 1
        if self.paused and self.current_line >= 0:
            renderer.fill_rounded_rect(Rect(self.rect.x + 4, self.rect.y + tab_h + 4, self.rect.w - 8, 22), Color(255, 149, 0, 20), 6)
            renderer.draw_text("O Paused at " + self.current_file + " line " + str(self.current_line), self.rect.x + 10, self.rect.y + tab_h + 8, self.font_ui, Color(255, 149, 0, 220))
        var content_y = self.rect.y + tab_h + (30 if self.paused else 0)
        renderer.set_clip(Rect(self.rect.x, content_y, self.rect.w, self.rect.h - tab_h - (30 if self.paused else 0)))
        var item_h = 28
        if self.active_tab == 0:
            if self.bp_count == 0:
                renderer.draw_text("No breakpoints set", self.rect.x + int(self.rect.w/2) - 70, content_y + 30, self.font_ui, Color(80,82,120,140))
                renderer.draw_text("Click the gutter (line numbers) to set a breakpoint", self.rect.x + int(self.rect.w/2) - 140, content_y + 52, self.font_ui, Color(60,62,100,120))
            else:
                var i = 0
                while i < self.bp_count:
                    var bp = self.breakpoints[i]
                    var iy = content_y + i * item_h - self.scroll_y + 4
                    if i % 2 == 0: renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, item_h), Color(255,255,255,3))
                    var dot_c = self.red if bp.enabled else Color(100,102,140,140)
                    renderer.fill_circle(self.rect.x + 16, iy + 14, 6, dot_c)
                    renderer.draw_text(bp.file + ":" + str(bp.line), self.rect.x + 28, iy + 8, self.font, Color(180,182,220,210))
                    if bp.hit_count > 0:
                        renderer.draw_text("x " + str(bp.hit_count), self.rect.right() - 44, iy + 8, self.font_ui, Color(255,149,0,180))
                    i = i + 1
        elif self.active_tab == 1:
            if self.watch_count == 0:
                renderer.draw_text("No watch expressions", self.rect.x + int(self.rect.w/2) - 70, content_y + 30, self.font_ui, Color(80,82,120,140))
            else:
                var i = 0
                while i < self.watch_count:
                    var we = self.watches[i]
                    var iy = content_y + i * item_h - self.scroll_y + 4
                    if i % 2 == 0: renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, item_h), Color(255,255,255,3))
                    renderer.draw_text(we.expr, self.rect.x + 12, iy + 8, self.font_bold, Color(86,196,255,210))
                    var val_c = Color(255,149,0,230) if we.changed else Color(130,215,100,200)
                    renderer.draw_text("= " + we.value, self.rect.x + 180, iy + 8, self.font, val_c)
                    i = i + 1
        elif self.active_tab == 2:
            if self.stack_depth == 0:
                renderer.draw_text("No active call stack", self.rect.x + int(self.rect.w/2) - 70, content_y + 30, self.font_ui, Color(80,82,120,140))
            else:
                var i = 0
                while i < self.stack_depth:
                    var frame = self.call_stack[i]
                    var iy = content_y + i * item_h - self.scroll_y + 4
                    if i == 0: renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, item_h), Color(self.accent.r, self.accent.g, self.accent.b, 15))
                    renderer.draw_text("#" + str(i), self.rect.x + 10, iy + 8, self.font_ui, Color(80,82,120,160))
                    renderer.draw_text(frame["name"], self.rect.x + 32, iy + 8, self.font_bold, Color(86,196,255,220))
                    renderer.draw_text(frame["file"] + ":" + str(frame["line"]), self.rect.x + 160, iy + 8, self.font, Color(130,132,170,160))
                    i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false

# ─── ProfilerPanel  -  execution time per line / function ──────────────────────
class ProfileEntry:
    def __init__(self, name, kind, calls, total_ms, self_ms):
        self.name = name
        self.kind = kind
        self.calls = calls
        self.total_ms = total_ms
        self.self_ms = self_ms
        self.pct = 0.0


class ProfilerPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.entries = []
        self.entry_count = 0
        self.total_ms = 0.0
        self.scroll_y = 0
        self.selected = -1
        self.sort_col = "total"
        self.visible = false
        self.bg = Color(13, 15, 27, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.green = Color(52, 199, 89, 255)
        self.orange = Color(255, 149, 0, 255)
        self.red = Color(255, 59, 48, 255)
        self.font = Font("monospace", 12, false, false)
        self.font_bold = Font("monospace", 12, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.font_tag = Font("sans-serif", 10, true, false)
        self.item_h = 32
        self.id = ""

    def add_entry(self, name, kind, calls, total_ms, self_ms):
        var e = ProfileEntry(name, kind, calls, total_ms, self_ms)
        if self.total_ms > 0.0:
            e.pct = total_ms / self.total_ms
        self.entries.append(e)
        self.entry_count = self.entry_count + 1
        return self

    def set_total(self, ms):
        self.total_ms = ms
        var i = 0
        while i < self.entry_count:
            if ms > 0.0:
                self.entries[i].pct = self.entries[i].total_ms / ms
            i = i + 1
        return self

    def clear(self):
        self.entries = []
        self.entry_count = 0
        self.total_ms = 0.0
        return self

    def handle_event(self, event):
        if not self.visible: return
        if event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.item_h * 3
            if self.scroll_y < 0: self.scroll_y = 0
            var mx = self.entry_count * self.item_h - self.rect.h + 60
            if mx < 0: mx = 0
            if self.scroll_y > mx: self.scroll_y = mx
        elif event.type == "mousedown" and self.rect.contains(event.x, event.y):
            if event.y < self.rect.y + 54:
                if event.x > self.rect.right() - 140: self.sort_col = "self"
                elif event.x > self.rect.right() - 240: self.sort_col = "calls"
                else: self.sort_col = "total"
            else:
                var iy = self.rect.y + 54 - self.scroll_y
                var i = 0
                while i < self.entry_count:
                    if event.y >= iy and event.y < iy + self.item_h:
                        self.selected = i
                        event.consume()
                    iy = iy + self.item_h
                    i = i + 1

    def draw(self, renderer):
        if not self.visible: return
        renderer.fill_rect(self.rect, self.bg)
        renderer.draw_rounded_rect(self.rect, self.border, 0, 1)
        var hdr_r = Rect(self.rect.x, self.rect.y, self.rect.w, 54)
        renderer.fill_rect(hdr_r, Color(20, 22, 38, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 54, self.rect.right(), self.rect.y + 54, self.border, 1)
        renderer.draw_text("[time]  PROFILER", self.rect.x + 14, self.rect.y + 10, self.font_bold, Color(255, 149, 0, 220))
        renderer.draw_text("Total: " + str(int(self.total_ms)) + "ms · " + str(self.entry_count) + " entries", self.rect.x + 14, self.rect.y + 32, self.font_ui, Color(100,102,140,160))
        var col_name = self.rect.x + 14
        var col_calls = self.rect.right() - 240
        var col_total = self.rect.right() - 160
        var col_self  = self.rect.right() - 76
        renderer.draw_text("FUNCTION", col_name, self.rect.y + 38, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("CALLS", col_calls, self.rect.y + 38, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("TOTAL", col_total, self.rect.y + 38, self.font_tag, Color(80,82,110,160))
        renderer.draw_text("SELF", col_self, self.rect.y + 38, self.font_tag, Color(80,82,110,160))
        renderer.set_clip(Rect(self.rect.x, self.rect.y + 54, self.rect.w, self.rect.h - 54))
        var first = int(self.scroll_y / self.item_h)
        var vis = int(self.rect.h / self.item_h) + 2
        var i = max(0, first)
        while i < self.entry_count and i < first + vis:
            var e = self.entries[i]
            var iy = self.rect.y + 54 + i * self.item_h - self.scroll_y
            if i == self.selected:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(self.accent.r, self.accent.g, self.accent.b, 22))
            elif i % 2 == 0:
                renderer.fill_rect(Rect(self.rect.x, iy, self.rect.w, self.item_h), Color(255,255,255,3))
            var bar_w = int(e.pct * float(self.rect.w - 40))
            if bar_w > 0:
                var bar_c = self.green
                if e.pct > 0.5: bar_c = self.orange
                if e.pct > 0.8: bar_c = self.red
                renderer.fill_rect(Rect(self.rect.x, iy, bar_w, self.item_h), Color(bar_c.r, bar_c.g, bar_c.b, 12))
            renderer.draw_text(e.name, col_name, iy + 9, self.font_bold, Color(220,222,255,220))
            renderer.draw_text(str(e.calls), col_calls, iy + 9, self.font, Color(140,142,180,200))
            var total_str = str(int(e.total_ms)) + "ms"
            var tc = self.red if e.pct > 0.5 else (self.orange if e.pct > 0.2 else self.green)
            renderer.draw_text(total_str, col_total, iy + 9, self.font_bold, tc)
            renderer.draw_text(str(int(e.self_ms)) + "ms", col_self, iy + 9, self.font, Color(140,142,180,180))
            var pct_str = str(int(e.pct * 100.0)) + "%"
            renderer.draw_text(pct_str, self.rect.right() - 8 - len(pct_str) * 7, iy + 9, self.font_ui, Color(tc.r, tc.g, tc.b, 180))
            renderer.draw_line(self.rect.x, iy + self.item_h - 1, self.rect.right(), iy + self.item_h - 1, Color(255,255,255,4), 1)
            i = i + 1
        renderer.clear_clip()

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false

# ─── REPLPanel  -  live interactive REPL ────────────────────────────────────────
class REPLPanel:
    def __init__(self, x, y, w, h):
        self.rect = Rect(x, y, w, h)
        self.history = []
        self.hist_count = 0
        self.hist_idx = -1
        self.input_text = ""
        self.focused = false
        self.scroll_y = 0
        self.total_h = 0
        self.bg = Color(12, 14, 24, 255)
        self.border = Color(255,255,255,8)
        self.accent = Color(99, 102, 241, 255)
        self.prompt_c = Color(99, 102, 241, 255)
        self.out_c = Color(200, 210, 200, 230)
        self.err_c = Color(255, 100, 80, 230)
        self.ok_c = Color(80, 220, 120, 230)
        self.input_c = Color(200, 222, 255, 230)
        self.font = Font("monospace", 13, false, false)
        self.font_bold = Font("monospace", 13, true, false)
        self.font_ui = Font("sans-serif", 11, false, false)
        self.line_h = 20
        self.blink_t = 0.0
        self.blink_v = true
        self.visible = false
        self.id = ""
        self._on_execute = none

    def on_execute(self, fn):
        self._on_execute = fn
        return self

    def write(self, text, kind):
        self.history.append({"text": text, "kind": kind})
        self.hist_count = self.hist_count + 1
        self.total_h = self.total_h + self.line_h
        var max_scroll = self.total_h - self.rect.h + 50
        if max_scroll > 0: self.scroll_y = max_scroll
        return self

    def clear(self):
        self.history = []
        self.hist_count = 0
        self.total_h = 0
        self.scroll_y = 0
        return self

    def handle_event(self, event):
        if not self.visible: return
        var inp_r = Rect(self.rect.x, self.rect.bottom() - 36, self.rect.w, 36)
        if event.type == "mousedown":
            self.focused = self.rect.contains(event.x, event.y)
        elif event.type == "scroll" and self.rect.contains(event.x, event.y):
            self.scroll_y = self.scroll_y - event.delta * self.line_h * 3
            if self.scroll_y < 0: self.scroll_y = 0
        elif event.type == "keydown" and self.focused:
            if event.key == "enter" and self.input_text != "":
                var expr = self.input_text
                self.write(">>> " + expr, "prompt")
                self.input_text = ""
                self.hist_idx = -1
                if self._on_execute != none: self._on_execute(expr)
            elif event.key == "backspace" and len(self.input_text) > 0:
                self.input_text = self.input_text[0:len(self.input_text) - 1]
            elif event.key == "up":
                var cmd_history = []
                var i = 0
                while i < self.hist_count:
                    if self.history[i]["kind"] == "prompt":
                        var txt = self.history[i]["text"]
                        if len(txt) > 4: cmd_history = cmd_history + [txt[4:]]
                    i = i + 1
                if len(cmd_history) > 0:
                    self.hist_idx = self.hist_idx + 1
                    if self.hist_idx >= len(cmd_history): self.hist_idx = len(cmd_history) - 1
                    self.input_text = cmd_history[len(cmd_history) - 1 - self.hist_idx]
            elif event.key == "down":
                if self.hist_idx > 0:
                    self.hist_idx = self.hist_idx - 1
                    var cmd_history2 = []
                    var i = 0
                    while i < self.hist_count:
                        if self.history[i]["kind"] == "prompt":
                            var txt = self.history[i]["text"]
                            if len(txt) > 4: cmd_history2 = cmd_history2 + [txt[4:]]
                        i = i + 1
                    if len(cmd_history2) > 0:
                        self.input_text = cmd_history2[len(cmd_history2) - 1 - self.hist_idx]
                else:
                    self.hist_idx = -1
                    self.input_text = ""
        elif event.type == "textinput" and self.focused:
            self.input_text = self.input_text + event.text

    def update(self):
        self.blink_t = self.blink_t + 0.04
        if self.blink_t > 1.0:
            self.blink_t = 0.0
            self.blink_v = not self.blink_v

    def _line_color(self, kind):
        if kind == "prompt": return self.prompt_c
        if kind == "error": return self.err_c
        if kind == "ok": return self.ok_c
        if kind == "info": return Color(100, 180, 255, 200)
        if kind == "result": return Color(248, 186, 80, 230)
        return self.out_c

    def draw(self, renderer):
        if not self.visible: return
        self.update()
        renderer.fill_rounded_rect(self.rect, self.bg, 0)
        renderer.draw_rounded_rect(self.rect, self.border, 0, 1)
        var hdr = Rect(self.rect.x, self.rect.y, self.rect.w, 36)
        renderer.fill_rect(hdr, Color(18, 20, 34, 255))
        renderer.draw_line(self.rect.x, self.rect.y + 36, self.rect.right(), self.rect.y + 36, self.border, 1)
        renderer.fill_circle(self.rect.x + 14, self.rect.y + 18, 5, Color(255,95,86,255))
        renderer.fill_circle(self.rect.x + 28, self.rect.y + 18, 5, Color(255,189,46,255))
        renderer.fill_circle(self.rect.x + 42, self.rect.y + 18, 5, Color(39,201,63,255))
        renderer.draw_text(">>  REPL  -  Interactive Nython", self.rect.x + 56, self.rect.y + 11, self.font_bold, Color(99,102,241,220))
        renderer.draw_text("Enter to run · ^v for history", self.rect.right() - 180, self.rect.y + 12, self.font_ui, Color(60,62,100,140))
        var content_r = Rect(self.rect.x, self.rect.y + 36, self.rect.w, self.rect.h - 72)
        renderer.set_clip(content_r)
        var first_line = max(0, int(self.scroll_y / self.line_h))
        var vis_lines = int(content_r.h / self.line_h) + 2
        var i = max(0, first_line)
        while i < self.hist_count and i < first_line + vis_lines:
            var entry = self.history[i]
            var ly = self.rect.y + 36 + i * self.line_h - self.scroll_y + 4
            var lc = self._line_color(entry["kind"])
            if entry["kind"] == "prompt":
                renderer.draw_text(entry["text"], self.rect.x + 10, ly, self.font_bold, lc)
            else:
                renderer.draw_text(entry["text"], self.rect.x + 10, ly, self.font, lc)
            i = i + 1
        renderer.clear_clip()
        renderer.draw_line(self.rect.x, self.rect.bottom() - 36, self.rect.right(), self.rect.bottom() - 36, self.border, 1)
        var prompt_x = self.rect.x + 10
        var inp_y = self.rect.bottom() - 28
        renderer.draw_text(">>>", prompt_x, inp_y, self.font_bold, self.prompt_c)
        var txt_x = prompt_x + 30
        if self.input_text != "":
            renderer.draw_text(self.input_text, txt_x, inp_y, self.font, self.input_c)
        else:
            renderer.draw_text("type expression...", txt_x, inp_y, self.font, Color(50,52,80,120))
        if self.focused and self.blink_v:
            var cx = txt_x + len(self.input_text) * 8
            renderer.fill_rect(Rect(cx, inp_y - 1, 2, 16), self.accent)

    def set_pos(self, x, y):
        self.rect.x = x
        self.rect.y = y
    def set_size(self, w, h):
        self.rect.w = w
        self.rect.h = h
    def show(self): self.visible = true
    def hide(self): self.visible = false


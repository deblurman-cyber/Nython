# ─── NyImGui: an immediate-mode core ─────────────────────────────────────────
# Modelled on Dear ImGui's architecture, in Nython, over SDL3.
#
# The existing widget set is RETAINED mode: every button is an object that owns
# its rect, its hover flag and its callback, and the caller keeps it alive
# between frames. That is why adding a pane meant auditing every offset, why
# widgets had to be told their position, and why the IDE carried hundreds of
# fields that exist only to remember what a widget looked like last frame.
#
# Immediate mode inverts this. A widget is a CALL:
#
#     if ui.button("Run"):
#         run_file()
#
# The call declares the widget, lays it out, tests the mouse against it, draws
# it, and returns whether it was activated — all this frame. No object survives.
#
# The three ideas that make that work, all taken from ImGui:
#
#   1. IDENTITY BY HASH. State that must persist (which item is held down, which
#      has keyboard focus) lives in the context keyed by a hash of the widget's
#      label chained through an ID stack. The widget itself is stateless; the
#      context remembers on its behalf. `gui_hash_id` is a native builtin
#      because it runs for every widget every frame.
#
#   2. A LAYOUT CURSOR. Widgets do not receive coordinates. The context carries
#      a cursor; each item advances it. Layout becomes a consequence of call
#      order, so there are no offsets to keep in sync.
#
#   3. HOT / ACTIVE. Exactly one item is `hot` (under the mouse) and at most one
#      is `active` (held). ImGui's key insight is that `active` is set on press
#      and only released on release, so dragging off a button and back does not
#      lose the press — and a click only counts if press and release land on the
#      same item.
#
# Enhancements over the original for this context:
#   - Draw commands are recorded as data, not emitted immediately, so a frame
#     can be diffed against the last one and skipped entirely when unchanged.
#     The IDE's frame loop is interpreted, so not re-drawing is worth far more
#     here than in C++.
#   - `###` stable-ID and `##` hidden-suffix conventions are supported.

class DrawCmd:
    def __init__(self, kind):
        self.kind = kind          # "rect" | "frame" | "text" | "line" | "clip"
        self.x = 0
        self.y = 0
        self.w = 0
        self.h = 0
        self.x2 = 0
        self.y2 = 0
        self.r = 0
        self.g = 0
        self.b = 0
        self.a = 255
        self.text = ""
        self.radius = 0

    # Cheap identity for frame-to-frame comparison.
    # Built with successive assignments rather than one wrapped expression:
    # Nython only continues a line inside brackets, so a bare `+` at the start
    # of the next line is a syntax error.
    def signature(self):
        var s = self.kind + ":" + str(self.x) + "," + str(self.y)
        s = s + "," + str(self.w) + "," + str(self.h)
        s = s + "," + str(self.x2) + "," + str(self.y2)
        s = s + "," + str(self.r) + "," + str(self.g) + "," + str(self.b)
        s = s + "," + str(self.a) + "," + str(self.radius) + "," + self.text
        return s


class DrawList:
    def __init__(self):
        self.cmds = []
        self.count = 0

    def clear(self):
        self.cmds = []
        self.count = 0

    def _push(self, c):
        self.cmds.append(c)
        self.count = self.count + 1
        return c

    def add_rect(self, x, y, w, h, col, radius):
        var c = DrawCmd("rect")
        c.x = x
        c.y = y
        c.w = w
        c.h = h
        c.r = col.r
        c.g = col.g
        c.b = col.b
        c.a = col.a
        c.radius = radius
        return self._push(c)

    def add_frame(self, x, y, w, h, col, radius):
        var c = self.add_rect(x, y, w, h, col, radius)
        c.kind = "frame"
        return c

    def add_text(self, x, y, s, col):
        var c = DrawCmd("text")
        c.x = x
        c.y = y
        c.text = s
        c.r = col.r
        c.g = col.g
        c.b = col.b
        c.a = col.a
        return self._push(c)

    def add_line(self, x1, y1, x2, y2, col):
        var c = DrawCmd("line")
        c.x = x1
        c.y = y1
        c.x2 = x2
        c.y2 = y2
        c.r = col.r
        c.g = col.g
        c.b = col.b
        c.a = col.a
        return self._push(c)

    def push_clip(self, x, y, w, h):
        var c = DrawCmd("clip")
        c.x = x
        c.y = y
        c.w = w
        c.h = h
        return self._push(c)

    # One string standing for the whole frame. Comparing it against the previous
    # frame's is how the loop decides whether to present at all.
    def signature(self):
        var sig = ""
        var i = 0
        while i < self.count:
            sig = sig + self.cmds[i].signature() + ";"
            i = i + 1
        return sig


class Style:
    def __init__(self):
        self.item_spacing_y = 4
        self.item_spacing_x = 8
        self.frame_pad_x = 10
        self.frame_pad_y = 6
        self.indent = 16
        self.radius = 4
        self.text_h = 14
        self.char_w = 7          # replaced by a real font measure when available


class IO:
    def __init__(self):
        self.mouse_x = 0
        self.mouse_y = 0
        self.mouse_down = false
        self.mouse_clicked = false     # went down this frame
        self.mouse_released = false    # came up this frame
        self.key_text = ""
        self.delta_ms = 16
        self._was_down = false

    # Derive the edge flags from the level, so a caller only has to report
    # "is the button down" and the context works out press and release.
    def begin_frame(self):
        self.mouse_clicked = self.mouse_down and not self._was_down
        self.mouse_released = (not self.mouse_down) and self._was_down
        self._was_down = self.mouse_down
        return true


class NyImGui:
    def __init__(self):
        self.io = IO()
        self.style = Style()
        self.draw = DrawList()

        # Persistent-across-frames state, keyed by hashed ID.
        self.hot_id = 0            # under the mouse this frame
        self.active_id = 0         # held since a press
        self.focus_id = 0          # keyboard focus
        self.last_id = 0
        self.storage = {}          # per-widget scratch (open/closed, scroll, ...)

        # ID stack: a widget's identity is its label hashed under its scope, so
        # two "Delete" buttons in different panels are different widgets.
        self.id_stack = []
        self.id_seed = 0

        # Layout cursor.
        self.cursor_x = 0
        self.cursor_y = 0
        self.origin_x = 0
        self.origin_y = 0
        self.avail_w = 0
        self.line_h = 0
        self.same_line_pending = false

        self.frame_count = 0
        self.last_signature = ""
        self.skipped_frames = 0

    # ── identity ─────────────────────────────────────────────────────────────
    def get_id(self, label):
        return gui_hash_id(label, self.id_seed)

    def push_id(self, label):
        self.id_stack.append(self.id_seed)
        self.id_seed = gui_hash_id(label, self.id_seed)
        return self.id_seed

    def pop_id(self):
        var n = len(self.id_stack)
        if n == 0:
            return self.id_seed
        self.id_seed = self.id_stack[n - 1]
        var kept = []
        var i = 0
        while i < n - 1:
            kept.append(self.id_stack[i])
            i = i + 1
        self.id_stack = kept
        return self.id_seed

    # Display text is everything before "##"; the rest disambiguates only.
    def visible_label(self, label):
        var at = string_find(label, "##")
        if at < 0:
            return label
        return label[0:at]

    # ── frame ────────────────────────────────────────────────────────────────
    def begin_frame(self, x, y, w, h):
        self.io.begin_frame()
        self.draw.clear()
        self.origin_x = x
        self.origin_y = y
        self.cursor_x = x
        self.cursor_y = y
        self.avail_w = w
        self.line_h = 0
        self.hot_id = 0
        self.id_seed = 0
        self.id_stack = []
        self.frame_count = self.frame_count + 1
        return true

    # Returns true when this frame differs from the last, i.e. when it is worth
    # presenting. The IDE's loop is interpreted, so skipping an identical frame
    # saves far more here than the equivalent would in C++.
    def end_frame(self):
        # Clear the held item AFTER every widget has been processed. Clearing it
        # in begin_frame meant that on the release frame active_id was already 0
        # by the time button_behavior ran, so `held` was false and the click was
        # never reported: buttons drew their pressed state and did nothing.
        # A release that lands on no widget still has to release the latch here,
        # or a button dragged off and released would stay held forever.
        if self.io.mouse_released:
            self.active_id = 0

        var sig = self.draw.signature()
        if sig == self.last_signature:
            self.skipped_frames = self.skipped_frames + 1
            return false
        self.last_signature = sig
        return true

    # ── layout ───────────────────────────────────────────────────────────────
    def same_line(self):
        self.same_line_pending = true
        return true

    def item_size(self, w, h):
        if self.same_line_pending:
            self.cursor_x = self.cursor_x + w + self.style.item_spacing_x
            if h > self.line_h:
                self.line_h = h
            self.same_line_pending = false
        else:
            self.cursor_x = self.origin_x
            self.cursor_y = self.cursor_y + h + self.style.item_spacing_y
            self.line_h = h
        return true

    # Reserve the rect this item occupies, BEFORE advancing the cursor.
    def item_rect(self, w, h):
        var x = self.cursor_x
        var y = self.cursor_y
        if self.same_line_pending:
            x = self.cursor_x
        return [x, y, w, h]

    def text_width(self, s):
        return len(s) * self.style.char_w

    def spacing(self):
        self.cursor_y = self.cursor_y + self.style.item_spacing_y
        return true

    def separator(self, col):
        var y = self.cursor_y + 2
        self.draw.add_line(self.origin_x, y, self.origin_x + self.avail_w, y, col)
        self.cursor_y = y + self.style.item_spacing_y
        return true

    # ── hit testing / behaviour ──────────────────────────────────────────────
    def hit(self, x, y, w, h):
        var mx = self.io.mouse_x
        var my = self.io.mouse_y
        return mx >= x and mx < x + w and my >= y and my < y + h

    # ImGui's ButtonBehavior, which is the heart of the whole scheme.
    # Returns [pressed, hovered, held].
    #
    # `active` is claimed on press and only surrendered on release. That is what
    # makes dragging off a button and back preserve the press, and what makes a
    # click count only when press and release land on the SAME item — a state
    # machine that a per-widget hover flag cannot express.
    def button_behavior(self, id, x, y, w, h):
        var hovered = self.hit(x, y, w, h)
        if hovered:
            self.hot_id = id
        var pressed = false
        var held = self.active_id == id

        if hovered and self.io.mouse_clicked and self.active_id == 0:
            self.active_id = id
            self.focus_id = id
            held = true
        if held and self.io.mouse_released:
            if hovered:
                pressed = true
            self.active_id = 0
            held = false
        self.last_id = id
        return [pressed, hovered, held]

    # ── widgets ──────────────────────────────────────────────────────────────
    def label(self, s, col):
        var w = self.text_width(s)
        var h = self.style.text_h
        var r = self.item_rect(w, h)
        self.draw.add_text(r[0], r[1], s, col)
        self.item_size(w, h)
        return true

    def button(self, label, theme):
        var id = self.get_id(label)
        var vis = self.visible_label(label)
        var w = self.text_width(vis) + self.style.frame_pad_x * 2
        var h = self.style.text_h + self.style.frame_pad_y * 2
        var r = self.item_rect(w, h)
        var st = self.button_behavior(id, r[0], r[1], w, h)

        var bg = theme.button
        if st[2]:
            bg = theme.button_active
        elif st[1]:
            bg = theme.button_hover
        self.draw.add_frame(r[0], r[1], w, h, bg, self.style.radius)
        self.draw.add_text(r[0] + self.style.frame_pad_x,
                           r[1] + self.style.frame_pad_y, vis, theme.text)
        self.item_size(w, h)
        return st[0]

    def checkbox(self, label, value, theme):
        var id = self.get_id(label)
        var vis = self.visible_label(label)
        var box = self.style.text_h + 2
        var w = box + 6 + self.text_width(vis)
        var h = box
        var r = self.item_rect(w, h)
        var st = self.button_behavior(id, r[0], r[1], w, h)
        var out = value
        if st[0]:
            out = not value
        var bg = theme.button
        if st[1]:
            bg = theme.button_hover
        self.draw.add_frame(r[0], r[1], box, box, bg, 3)
        if out:
            self.draw.add_line(r[0] + 3, r[1] + box / 2,
                               r[0] + box / 2, r[1] + box - 4, theme.accent)
            self.draw.add_line(r[0] + box / 2, r[1] + box - 4,
                               r[0] + box - 3, r[1] + 3, theme.accent)
        self.draw.add_text(r[0] + box + 6, r[1], vis, theme.text)
        self.item_size(w, h)
        return out

    # Persistent per-widget state, keyed by ID: exactly how ImGui remembers a
    # tree node's open state without the caller holding an object.
    def get_state(self, id, dflt):
        var k = str(id)
        var v = self.storage[k]
        if v == none:
            return dflt
        return v

    def set_state(self, id, v):
        self.storage[str(id)] = v
        return v

    def tree_node(self, label, theme):
        var id = self.get_id(label)
        var vis = self.visible_label(label)
        var open = self.get_state(id, false)
        var w = self.avail_w
        var h = self.style.text_h + 4
        var r = self.item_rect(w, h)
        var st = self.button_behavior(id, r[0], r[1], w, h)
        if st[0]:
            open = not open
            self.set_state(id, open)
        if st[1]:
            self.draw.add_frame(r[0], r[1], w, h, theme.button_hover, 0)
        var arrow = "▸"
        if open:
            arrow = "▾"
        self.draw.add_text(r[0], r[1], arrow + " " + vis, theme.text)
        self.item_size(w, h)
        return open

    def indent(self):
        self.origin_x = self.origin_x + self.style.indent
        self.cursor_x = self.origin_x
        self.avail_w = self.avail_w - self.style.indent
        return self.origin_x

    def unindent(self):
        self.origin_x = self.origin_x - self.style.indent
        self.cursor_x = self.origin_x
        self.avail_w = self.avail_w + self.style.indent
        return self.origin_x


    # ── Renderer bridge ──────────────────────────────────────────────────────
    # The draw list is data, so it has to be replayed onto a real renderer. This
    # is what lets an immediate-mode panel live inside the existing retained
    # IDE: the panel is expressed as calls, and its commands are flushed through
    # the same renderer everything else uses. Porting can therefore proceed one
    # panel at a time instead of as a rewrite.
    def flush(self, r, font, font_bold):
        var i = 0
        while i < self.draw.count:
            var c = self.draw.cmds[i]
            var col = Color(c.r, c.g, c.b, c.a)
            if c.kind == "rect" or c.kind == "frame":
                if c.radius > 0:
                    r.fill_round_xywh(c.x, c.y, c.w, c.h, col, c.radius)
                else:
                    r.fill_xywh(c.x, c.y, c.w, c.h, col)
            elif c.kind == "text":
                var f = font
                if c.radius == 1:
                    f = font_bold          # radius reused as a bold flag on text
                r.draw_text(c.text, c.x, c.y, f, col)
            elif c.kind == "line":
                r.draw_line(c.x, c.y, c.x2, c.y2, col, 1)
            elif c.kind == "clip":
                r.set_clip(Rect(c.x, c.y, c.w, c.h))
            i = i + 1
        return self.draw.count

    def add_bold_text(self, x, y, s, col):
        var c = self.draw.add_text(x, y, s, col)
        c.radius = 1
        return c

    # ── Tab bar ──────────────────────────────────────────────────────────────
    # Returns the index of the selected tab. In retained mode this needed three
    # separate pieces that had to agree: a draw loop, a parallel list of hit
    # rectangles, and a click handler elsewhere that walked that list. Here the
    # hit test happens where the tab is laid out, so the three cannot drift.
    #
    # `badges` is an optional parallel list of counts; 0 means no badge.
    def tabs(self, scope, labels, active, badges, theme, x, y, h, measure):
        self.push_id(scope)
        var out = active
        var tx = x + 12
        var i = 0
        while i < len(labels):
            var name = labels[i]
            var tw = measure(name) + 24
            var badge = 0
            if badges != none and i < len(badges):
                badge = badges[i]
            if badge > 0:
                tw = tw + 20
            var st = self.button_behavior(self.get_id(name), tx, y, tw, h)
            if st[0]:
                out = i
            if st[1] and i != active:
                self.draw.add_frame(tx, y, tw, h, theme.button_hover, 0)
            if i == active:
                self.add_bold_text(tx + 12, y + 9, name, theme.text)
                self.draw.add_rect(tx + 6, y + h - 2, tw - 12, 2, theme.accent, 0)
            else:
                self.draw.add_text(tx + 12, y + 9, name, theme.text_faint)
            if badge > 0:
                self.draw.add_rect(tx + tw - 21, y + 8, 14, 14, theme.err, 7)
                self.draw.add_text(tx + tw - 17, y + 8, str(badge), theme.on_badge)
            tx = tx + tw
            i = i + 1
        self.pop_id()
        return out

    # ── Chip row ─────────────────────────────────────────────────────────────
    # A row of small selectable pills, the toolbar's mode selector. Same shape
    # as tabs() but pill-styled and with a caller-controlled start index, since
    # the toolbar deliberately skips entry 0 (the green Run button already is
    # "Run", and drawing both put two Run controls side by side).
    #
    # Returns the selected index, or `active` when nothing was clicked.
    def chips(self, scope, labels, active, first, theme, x, y, h, measure):
        self.push_id(scope)
        var out = active
        var cx = x
        var i = first
        while i < len(labels):
            var name = labels[i]
            var tw = measure(name)
            var w = tw + 26
            var st = self.button_behavior(self.get_id(name), cx, y, w, h)
            if st[0]:
                out = i
            # Text is centred in the chip rather than placed at a fixed inset,
            # so a long label ("Tokenize") and a short one ("VM") both sit in
            # the middle of their own button instead of hugging the left edge.
            var tx = cx + int((w - tw) / 2)
            var ty = y + int((h - 14) / 2)
            if i == active:
                self.draw.add_rect(cx, y, w, h, theme.accent_soft, 5)
                self.draw.add_frame(cx, y, w, h, theme.accent, 5)
                self.draw.add_text(tx, ty, name, theme.text)
            elif st[1]:
                # Hover feedback the retained version never had: the chips were
                # clickable but gave no sign of it until they were selected.
                self.draw.add_rect(cx, y, w, h, theme.hover, 5)
                self.draw.add_text(tx, ty, name, theme.text)
            else:
                # Every chip carries a faint outline so it reads as a control.
                # Bare text on a toolbar looks like a label, which is why these
                # did not appear clickable.
                self.draw.add_frame(cx, y, w, h, theme.border, 5)
                self.draw.add_text(tx, ty, name, theme.text_dim)
            cx = cx + w + 4
            i = i + 1
        self.pop_id()
        return out

    # ── Icon rail ────────────────────────────────────────────────────────────
    # A vertical strip of icon buttons (the activity bar). The icon itself is
    # drawn by a caller-supplied function, so this stays independent of the
    # icon set while still owning layout, hover and selection.
    def icon_rail(self, scope, items, active_key, theme, x, y, w, item_h, gap, draw_icon):
        self.push_id(scope)
        var out = active_key
        var iy = y + 8
        var i = 0
        while i < len(items):
            var it = items[i]
            var st = self.button_behavior(self.get_id(it.key), x + 7, iy, w - 14, item_h)
            if st[0]:
                out = it.key
            if it.key == active_key:
                self.draw.add_rect(x + 7, iy, w - 14, item_h, theme.button_active, 6)
                # Selected marker down the left edge, as VS Code does it.
                self.draw.add_rect(x, iy + 4, 2, item_h - 8, theme.accent, 0)
            elif st[1]:
                self.draw.add_rect(x + 7, iy, w - 14, item_h, theme.button_hover, 6)
            draw_icon(it, x + int(w / 2) - 10, iy + int(item_h / 2) - 10, st[1] or it.key == active_key)
            iy = iy + item_h + gap
            i = i + 1
        self.pop_id()
        return out

    # ── Slider ───────────────────────────────────────────────────────────────
    # Geometry taken from Dear ImGui's SliderBehaviorT (imgui_widgets.cpp), not
    # approximated. The part that is easy to get wrong is the USABLE range: the
    # grab has width, so the track the grab CENTRE can occupy is shorter than
    # the track itself by exactly the grab size. Mapping value to the full track
    # makes the handle overhang both ends and makes the maximum unreachable.
    #
    #   slider_sz        = track - 2*padding
    #   grab_sz          = max(slider_sz / (range+1), grab_min)   clamped
    #   usable_sz        = slider_sz - grab_sz
    #   usable_pos_min   = track_min + padding + grab_sz/2
    #   usable_pos_max   = track_max - padding - grab_sz/2
    def slider(self, label, value, v_min, v_max, theme, x, y, w, h):
        var id = self.get_id(label)
        var grab_padding = 2
        var grab_min = 10
        var slider_sz = w - grab_padding * 2
        var span = v_max - v_min
        var grab_sz = grab_min
        if span > 0:
            var per_unit = float(slider_sz) / (float(span) + 1.0)
            if per_unit > float(grab_min):
                grab_sz = int(per_unit)
        if grab_sz > slider_sz:
            grab_sz = slider_sz
        var usable_sz = slider_sz - grab_sz
        var usable_min = x + grab_padding + int(grab_sz / 2)

        var st = self.button_behavior(id, x, y, w, h)
        var out = value
        if st[2] and usable_sz > 0:
            # Position is taken from the grab CENTRE, so the handle does not
            # jump under the cursor when the drag starts mid-grab.
            var t = float(self.io.mouse_x - usable_min) / float(usable_sz)
            if t < 0.0:
                t = 0.0
            if t > 1.0:
                t = 1.0
            out = v_min + int(t * float(span) + 0.5)

        var frac = 0.0
        if span > 0:
            frac = float(out - v_min) / float(span)
        var gx = usable_min + int(frac * float(usable_sz)) - int(grab_sz / 2)

        self.draw.add_rect(x, y + int(h / 2) - 2, w, 4, theme.border, 2)
        var filled = gx + int(grab_sz / 2) - x
        if filled > 0:
            self.draw.add_rect(x, y + int(h / 2) - 2, filled, 4, theme.accent, 2)
        var gcol = theme.text_dim
        if st[1] or st[2]:
            gcol = theme.accent
        self.draw.add_rect(gx, y + 2, grab_sz, h - 4, gcol, 3)
        return out

    # ── Scrollbar ────────────────────────────────────────────────────────────
    # From ImGui's ScrollbarEx. The thumb length is the VISIBLE FRACTION of the
    # content, floored at a minimum so it stays grabbable in a long document;
    # the travel is then the bar minus the thumb, not the bar itself.
    def scrollbar(self, label, scroll, size_visible, size_contents, theme,
                  x, y, w, h):
        var id = self.get_id(label)
        var win_size = size_contents
        if size_visible > win_size:
            win_size = size_visible
        if win_size < 1:
            win_size = 1
        var grab_min = 12
        var grab_px = int(float(h) * (float(size_visible) / float(win_size)))
        if grab_px < grab_min:
            grab_px = grab_min
        if grab_px > h:
            grab_px = h

        var scroll_max = size_contents - size_visible
        if scroll_max < 1:
            scroll_max = 1
        var out = scroll
        var st = self.button_behavior(id, x, y, w, h)
        if st[2]:
            var travel = h - grab_px
            if travel > 0:
                var t = float(self.io.mouse_y - y - int(grab_px / 2)) / float(travel)
                if t < 0.0:
                    t = 0.0
                if t > 1.0:
                    t = 1.0
                out = int(t * float(scroll_max))

        var ratio = float(out) / float(scroll_max)
        if ratio < 0.0:
            ratio = 0.0
        if ratio > 1.0:
            ratio = 1.0
        var gy = y + int(ratio * float(h - grab_px))
        self.draw.add_rect(x, y, w, h, theme.panel, 0)
        var col = theme.text_faint
        if st[1] or st[2]:
            col = theme.text_dim
        self.draw.add_rect(x + 2, gy, w - 4, grab_px, col, 3)
        return out

    # ── Panel ────────────────────────────────────────────────────────────────
    # A titled, collapsible region — the element the IDE had no equivalent of.
    # Returns whether the body should be drawn, so a caller writes:
    #
    #     if ui.panel("Output", theme, x, y, w, h):
    #         ...draw the body...
    def panel(self, title, theme, x, y, w, h, measure):
        var id = self.get_id(title)
        var open = self.get_state(id, true)
        var head_h = 26
        var st = self.button_behavior(id, x, y, w, head_h)
        if st[0]:
            open = not open
            self.set_state(id, open)

        self.draw.add_rect(x, y, w, head_h, theme.panel, 0)
        if st[1]:
            self.draw.add_rect(x, y, w, head_h, theme.hover, 0)
        var arrow = "\u25b8"
        if open:
            arrow = "\u25be"
        self.draw.add_text(x + 8, y + 6, arrow, theme.text_dim)
        self.draw.add_text(x + 24, y + 6, title, theme.text)
        self.draw.add_line(x, y + head_h, x + w, y + head_h, theme.border)
        if open:
            self.draw.add_rect(x, y + head_h, w, h - head_h, theme.panel, 0)
        return open

    # ── Toolbar separator ────────────────────────────────────────────────────
    # Code::Blocks groups its toolbar into banks divided by a thin rule; VS Code
    # relies on spacing alone. Combining both reads better at a glance than
    # either: grouped AND spaced.
    def toolbar_sep(self, theme, x, y, h):
        self.draw.add_line(x, y + 4, x, y + h - 4, theme.border)
        return x + 9

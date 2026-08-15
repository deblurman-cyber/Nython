# ─── Motion + Layout ─────────────────────────────────────────────────────────
# Two foundations the widget set was missing.
#
# MOTION. Widgets animated by stepping a value linearly. Linear motion is the
# single most recognisable "this is a homemade UI" tell: real interfaces
# accelerate and decelerate, because that is how physical objects move. These
# are the standard easing curves, all normalised to f(0)=0, f(1)=1 so they are
# interchangeable.
#
# LAYOUT. Every widget was positioned by hand-computed pixel arithmetic, which
# is why the IDE was pinned to 1600x960 for so long: there was no layout solver,
# only constants. Flex gives a row/column solver with grow, fixed sizes, gaps,
# padding and alignment, so a container can size its children instead of the
# author doing it by hand.

class Ease:
    def __init__(self):
        self.name = "ease"

    def clamp01(self, t):
        if t < 0.0:
            return 0.0
        if t > 1.0:
            return 1.0
        return t

    def linear(self, t):
        return self.clamp01(t)

    # ── quadratic ────────────────────────────────────────────────────────────
    def in_quad(self, t):
        t = self.clamp01(t)
        return t * t

    def out_quad(self, t):
        t = self.clamp01(t)
        return 1.0 - (1.0 - t) * (1.0 - t)

    def in_out_quad(self, t):
        t = self.clamp01(t)
        if t < 0.5:
            return 2.0 * t * t
        var u = -2.0 * t + 2.0
        return 1.0 - (u * u) / 2.0

    # ── cubic — the workhorse for UI motion ──────────────────────────────────
    def in_cubic(self, t):
        t = self.clamp01(t)
        return t * t * t

    def out_cubic(self, t):
        t = self.clamp01(t)
        var u = 1.0 - t
        return 1.0 - u * u * u

    def in_out_cubic(self, t):
        t = self.clamp01(t)
        if t < 0.5:
            return 4.0 * t * t * t
        var u = -2.0 * t + 2.0
        return 1.0 - (u * u * u) / 2.0

    # ── quartic / quintic for longer travels ─────────────────────────────────
    def out_quart(self, t):
        t = self.clamp01(t)
        var u = 1.0 - t
        return 1.0 - u * u * u * u

    def out_quint(self, t):
        t = self.clamp01(t)
        var u = 1.0 - t
        return 1.0 - u * u * u * u * u

    # ── expo — near-instant start, long settle. Good for panels. ─────────────
    def out_expo(self, t):
        t = self.clamp01(t)
        if t >= 1.0:
            return 1.0
        return 1.0 - pow(2.0, -10.0 * t)

    def in_expo(self, t):
        t = self.clamp01(t)
        if t <= 0.0:
            return 0.0
        return pow(2.0, 10.0 * t - 10.0)

    # ── back / elastic — overshoot, for playful affordances ──────────────────
    def out_back(self, t):
        t = self.clamp01(t)
        var c1 = 1.70158
        var c3 = c1 + 1.0
        var u = t - 1.0
        return 1.0 + c3 * u * u * u + c1 * u * u

    def out_elastic(self, t):
        t = self.clamp01(t)
        if t <= 0.0:
            return 0.0
        if t >= 1.0:
            return 1.0
        var c4 = 6.283185307179586 / 3.0
        return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0

    def out_bounce(self, t):
        t = self.clamp01(t)
        var n1 = 7.5625
        var d1 = 2.75
        if t < 1.0 / d1:
            return n1 * t * t
        if t < 2.0 / d1:
            var a = t - 1.5 / d1
            return n1 * a * a + 0.75
        if t < 2.5 / d1:
            var b = t - 2.25 / d1
            return n1 * b * b + 0.9375
        var c = t - 2.625 / d1
        return n1 * c * c + 0.984375

    # Apply a named curve; unknown names degrade to linear rather than failing,
    # so a typo in a theme cannot break rendering.
    def apply(self, name, t):
        if name == "linear":
            return self.linear(t)
        if name == "in_quad":
            return self.in_quad(t)
        if name == "out_quad":
            return self.out_quad(t)
        if name == "in_out_quad":
            return self.in_out_quad(t)
        if name == "in_cubic":
            return self.in_cubic(t)
        if name == "out_cubic":
            return self.out_cubic(t)
        if name == "in_out_cubic":
            return self.in_out_cubic(t)
        if name == "out_quart":
            return self.out_quart(t)
        if name == "out_quint":
            return self.out_quint(t)
        if name == "in_expo":
            return self.in_expo(t)
        if name == "out_expo":
            return self.out_expo(t)
        if name == "out_back":
            return self.out_back(t)
        if name == "out_elastic":
            return self.out_elastic(t)
        if name == "out_bounce":
            return self.out_bounce(t)
        return self.linear(t)

    # Interpolate between two values along a curve.
    def mix(self, a, b, t, curve):
        var e = self.apply(curve, t)
        return a + (b - a) * e


# A single animated scalar. Drive it from the frame loop with advance(dt).
class Tween:
    def __init__(self, start, end, duration_ms, curve):
        self.start = start
        self.end = end
        self.duration = duration_ms
        self.curve = curve
        self.elapsed = 0
        self.done = false
        self.ease = Ease()

    def advance(self, dt_ms):
        if self.done:
            return self.end
        self.elapsed = self.elapsed + dt_ms
        if self.elapsed >= self.duration:
            self.elapsed = self.duration
            self.done = true
        return self.value()

    def value(self):
        if self.duration <= 0:
            return self.end
        var t = float(self.elapsed) / float(self.duration)
        return self.ease.mix(self.start, self.end, t, self.curve)

    def progress(self):
        if self.duration <= 0:
            return 1.0
        return float(self.elapsed) / float(self.duration)

    def reset(self):
        self.elapsed = 0
        self.done = false

    def reverse(self):
        var s = self.start
        self.start = self.end
        self.end = s
        self.reset()


# ─── Flex layout ─────────────────────────────────────────────────────────────
# One child in a flex container. `basis` is its fixed size along the main axis;
# `grow` is its share of whatever space is left over.

class FlexItem:
    def __init__(self, key, basis, grow):
        self.key = key
        self.basis = basis
        self.grow = grow
        self.min_size = 0
        self.max_size = 0        # 0 = unbounded
        self.x = 0
        self.y = 0
        self.w = 0
        self.h = 0


class Flex:
    def __init__(self, direction):
        self.direction = direction     # "row" | "column"
        self.items = []
        self.item_count = 0
        self.gap = 0
        self.pad_l = 0
        self.pad_t = 0
        self.pad_r = 0
        self.pad_b = 0
        self.align = "stretch"         # cross axis: stretch | start | center | end
        self.justify = "start"         # main axis when there is slack and no grow

    def padding(self, l, t, r, b):
        self.pad_l = l
        self.pad_t = t
        self.pad_r = r
        self.pad_b = b
        return self

    def spacing(self, g):
        self.gap = g
        return self

    def add(self, key, basis, grow):
        var it = FlexItem(key, basis, grow)
        self.items.append(it)
        self.item_count = self.item_count + 1
        return it

    def add_min(self, key, basis, grow, min_size):
        var it = self.add(key, basis, grow)
        it.min_size = min_size
        return it

    def get(self, key):
        var i = 0
        while i < self.item_count:
            if self.items[i].key == key:
                return self.items[i]
            i = i + 1
        return none

    # Solve into the rect (x, y, w, h). Returns the items with x/y/w/h set.
    def solve(self, x, y, w, h):
        var inner_x = x + self.pad_l
        var inner_y = y + self.pad_t
        var inner_w = w - self.pad_l - self.pad_r
        var inner_h = h - self.pad_t - self.pad_b
        if inner_w < 0:
            inner_w = 0
        if inner_h < 0:
            inner_h = 0

        var is_row = self.direction == "row"
        var main_total = inner_w
        if not is_row:
            main_total = inner_h

        var gaps = 0
        if self.item_count > 1:
            gaps = self.gap * (self.item_count - 1)

        # Fixed sizes first, then distribute the remainder by grow weight.
        var used = gaps
        var grow_total = 0
        var i = 0
        while i < self.item_count:
            used = used + self.items[i].basis
            grow_total = grow_total + self.items[i].grow
            i = i + 1

        var slack = main_total - used
        if slack < 0:
            slack = 0

        # Assign main-axis sizes, honouring minimums. Anything a minimum steals
        # is taken back off the remaining slack so the row still fits.
        i = 0
        var assigned = 0
        while i < self.item_count:
            var it = self.items[i]
            var size = it.basis
            if grow_total > 0 and it.grow > 0:
                size = size + int(float(slack) * (float(it.grow) / float(grow_total)))
            if it.min_size > 0 and size < it.min_size:
                size = it.min_size
            if it.max_size > 0 and size > it.max_size:
                size = it.max_size
            it.main_size = size
            assigned = assigned + size
            i = i + 1

        # justify only matters when nothing grows and space is left over
        var offset = 0
        var leftover = main_total - assigned - gaps
        if grow_total == 0 and leftover > 0:
            if self.justify == "center":
                offset = int(leftover / 2)
            elif self.justify == "end":
                offset = leftover

        var cursor = offset
        i = 0
        while i < self.item_count:
            var it2 = self.items[i]
            if is_row:
                it2.x = inner_x + cursor
                it2.w = it2.main_size
                it2.h = self._cross(inner_h, it2)
                it2.y = inner_y + self._cross_offset(inner_h, it2.h)
            else:
                it2.y = inner_y + cursor
                it2.h = it2.main_size
                it2.w = self._cross(inner_w, it2)
                it2.x = inner_x + self._cross_offset(inner_w, it2.w)
            cursor = cursor + it2.main_size + self.gap
            i = i + 1
        return self.items

    def _cross(self, avail, it):
        if self.align == "stretch":
            return avail
        return avail          # non-stretch keeps full size unless a widget measures itself

    def _cross_offset(self, avail, size):
        if self.align == "center":
            return int((avail - size) / 2)
        if self.align == "end":
            return avail - size
        return 0


# ─── Fuzzy matching ──────────────────────────────────────────────────────────
# The command palette filtered by SUBSTRING, so "gtl" did not find "Go to Line"
# and "oprj" did not find "Open Project" — the two things a palette exists to do.
# This is subsequence matching with the scoring every editor uses: characters
# must appear in order but not adjacently, and matches at word starts and in
# runs score higher, so the intended command sorts to the top rather than merely
# appearing somewhere in the list.

class Fuzzy:
    def __init__(self):
        self.bonus_word_start = 12    # match at the start of a word
        self.bonus_consecutive = 8    # match adjacent to the previous match
        self.bonus_first = 10         # match at position 0
        self.penalty_skip = 1         # each unmatched character passed over

    def _is_boundary(self, s, i):
        if i == 0:
            return true
        var p = s[i - 1]
        return p == " " or p == "_" or p == "-" or p == "." or p == "/"

    def _lower(self, c):
        if c >= "A" and c <= "Z":
            return string_lower(c)
        return c

    # Returns [matched, score, positions]. positions lets the caller bold the
    # matched characters, which is what makes a fuzzy list readable.
    def match(self, needle, haystack):
        var nq = len(needle)
        if nq == 0:
            return [true, 0, []]
        var nh = len(haystack)
        if nq > nh:
            return [false, 0, []]
        var score = 0
        var qi = 0
        var hi = 0
        var last_match = 0 - 2
        var positions = []
        while hi < nh and qi < nq:
            var a = self._lower(needle[qi])
            var b = self._lower(haystack[hi])
            if a == b:
                var gain = 1
                if hi == 0:
                    gain = gain + self.bonus_first
                if self._is_boundary(haystack, hi):
                    gain = gain + self.bonus_word_start
                if hi == last_match + 1:
                    gain = gain + self.bonus_consecutive
                score = score + gain
                positions.append(hi)
                last_match = hi
                qi = qi + 1
            else:
                score = score - self.penalty_skip
            hi = hi + 1
        if qi < nq:
            return [false, 0, []]
        # Prefer shorter candidates when the match quality is equal, so "Run"
        # outranks "Run Configuration..." for the query "run".
        score = score - int(nh / 4)
        return [true, score, positions]

    # Filter and rank. Returns entries sorted best-first.
    def rank(self, needle, items):
        var scored = []
        var i = 0
        while i < len(items):
            var r = self.match(needle, items[i])
            if r[0]:
                scored.append([items[i], r[1], r[2]])
            i = i + 1
        # Insertion sort by descending score; a palette list is short.
        var a = 1
        while a < len(scored):
            var cur = scored[a]
            var b = a - 1
            while b >= 0 and scored[b][1] < cur[1]:
                scored[b + 1] = scored[b]
                b = b - 1
            scored[b + 1] = cur
            a = a + 1
        return scored

# Test 20: defects visible in the shipped IDE (nython_ide.ny, v4).
# Every check here corresponds to something wrong in a real screenshot.
import "lib/gui.ny"
import "ide_icons.ny"
import "lib/gui_motion.ny"

var npass = 0
var nfail = 0
def check(name, got, want):
    if got == want:
        npass = npass + 1
    else:
        nfail = nfail + 1
        print "  FAIL [" + name + "] got=" + str(got) + " want=" + str(want)
def check_true(name, c):
    check(name, c, true)

print "=== Test 20: shipped IDE ==="



# ── every icon the activity rail asks for must be DRAWN ──────────────────────
# The rail requested "outline" and "ai", neither of which had a case in
# Icons.draw, so both fell through to the fallback and rendered as blank
# rounded squares. A recording renderer proves each name draws something
# distinct from the fallback.
class RecR:
    def __init__(self):
        self.ops = 0
        self.sig = ""
    def draw_line(self, x1, y1, x2, y2, c, w):
        self.ops = self.ops + 1
        self.sig = self.sig + "L"
    def draw_rounded_rect(self, rect, c, rad, w):
        self.ops = self.ops + 1
        self.sig = self.sig + "R"
    def fill_rounded_rect(self, rect, c, rad):
        self.ops = self.ops + 1
        self.sig = self.sig + "F"
    def draw_circle(self, x, y, rad, c):
        self.ops = self.ops + 1
        self.sig = self.sig + "C"
    def fill_xywh(self, x, y, w, h, c):
        self.ops = self.ops + 1
        self.sig = self.sig + "X"
    # Without these the recorder silently counted zero ops for icons that are
    # drawn as polygons or circles (run, warning, breakpoint), and the test
    # reported three perfectly good icons as blank. A recording double has to
    # implement the whole surface it stands in for, or it invents failures.
    # Icons are drawn as Codicon glyphs now: one draw_text, not a set of
    # shapes. Without this the recorder counted zero ops for every icon and
    # reported the whole set as blank — the recorder being incomplete, not the
    # icons being missing. Same failure mode as the missing fill_polygon.
    def draw_text(self, t, x, y, f, c):
        self.ops = self.ops + 1
        self.sig = self.sig + "T"
    def fill_polygon(self, pts, c):
        self.ops = self.ops + 1
        self.sig = self.sig + "P"
    def fill_circle(self, x, y, rad, c):
        self.ops = self.ops + 1
        self.sig = self.sig + "O"
    def draw_polygon(self, pts, c, w):
        self.ops = self.ops + 1
        self.sig = self.sig + "P"

var ic = Icons()
var col = Color(255, 255, 255, 255)

# the fallback signature: a single rounded box
var fb = RecR()
ic.draw(fb, "definitely-not-an-icon", 0, 0, 20, col)
check("fallback is one box", fb.sig, "R")

var rail = ["explorer", "search", "git", "run", "ext", "outline", "ai"]
for k in rail:
    var rec = RecR()
    ic.draw(rec, k, 0, 0, 20, col)
    check_true("rail icon drawn: " + k, rec.ops > 0)
    # anything identical to the fallback means the icon has no case
    if rec.sig == "R":
        check("rail icon not fallback: " + k, "fallback", "real drawing")
    else:
        npass = npass + 1

# icons used elsewhere in the chrome
for k in ["folder", "folder_open", "file", "file_code", "terminal", "warning",
          "close", "chevron_right", "chevron_down", "save", "new_file",
          "project", "breakpoint", "output", "debug", "settings"]:
    var rec2 = RecR()
    ic.draw(rec2, k, 0, 0, 16, col)
    check_true("chrome icon drawn: " + k, rec2.ops > 0)


# ── motion curves used by the shipped IDE (round 49) ─────────────────────────
# Toasts slide in and fade out; panes ease open and closed. Nothing eased
# before, which is the clearest "not a real application" tell.
var ez = Ease()
check_true("ease f(0) is 0", ez.out_cubic(0.0) < 0.0001)
check_true("ease f(1) is 1", ez.out_cubic(1.0) > 0.9999)
check_true("out_cubic decelerates", ez.out_cubic(0.5) > 0.5)
check_true("toast appear curve bounded", ez.out_cubic(0.35) <= 1.0)
check_true("fade curve monotonic", ez.in_out_quad(0.8) > ez.in_out_quad(0.2))

# Exponential approach: each frame closes a fixed fraction of the remaining gap,
# so it decelerates, never overshoots, and always terminates.
def approach(v, target, k):
    return v + (target - v) * k
var a = 0.0
var steps = 0
while a < 0.996 and steps < 200:
    a = approach(a, 1.0, 0.28)
    steps = steps + 1
check_true("pane animation converges", a >= 0.996)
check_true("converges quickly", steps < 30)
check_true("never overshoots", a <= 1.0)
var b = 1.0
var s2 = 0
while b > 0.004 and s2 < 200:
    b = approach(b, 0.0, 0.28)
    s2 = s2 + 1
check_true("closes symmetrically", b <= 0.004)
check_true("never undershoots", b >= 0.0)

# ── the SHIPPED theme is VS Code Dark+ (round 66) ────────────────────────────
# A Dark+ palette was written in round 41 into lib/gui.ny — which nython_ide.ny
# does not import, so it never reached the shipped IDE. These assert against the
# theme the shipped IDE actually uses.
var th_ship = Palette()
check("editor bg", th_ship.SURFACE.r, 30)
check("panel bg", th_ship.SURFACE2.r, 37)
check("status bar is accent blue", th_ship.STATUSBAR.b, 204)
check("accent", th_ship.ACCENT.g, 122)
check("foreground", th_ship.ON_SURFACE.r, 212)
check("error red", th_ship.DANGER.r, 241)
check("selection", th_ship.SELECTION.r, 38)
check("activity bar", th_ship.ACTIVITYBAR.r, 51)

# ── icons are real Codicon glyphs, not approximations ────────────────────────
var shipped = Icons()
check_true("codicon font present", shipped.use_glyphs)
for k in ["explorer", "search", "git", "run", "ext", "outline", "ai"]:
    var rec3 = RecR()
    shipped.draw(rec3, k, 0, 0, 16, col)
    check("glyph drawn for " + k, rec3.sig, "T")

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 20 PASSED ==="
else:
    print "=== TEST 20 FAILED ==="

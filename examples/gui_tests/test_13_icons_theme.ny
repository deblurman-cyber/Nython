# Test 13: codicon font + VS Code Dark+ palette
import "lib/gui.ny"
import "lib/icons.ny"

var npass = 0
var fail = 0
def check_true(name, c):
    check(name, c, true)
def check(name, got, want):
    if got == want:
        npass = npass + 1
    else:
        fail = fail + 1
        print "  FAIL [" + name + "] got=" + str(got) + " want=" + str(want)

print "=== Test 13: Icons + Dark+ theme ==="

# ── Icon set ─────────────────────────────────────────────────────────────────
var ic = Icons_Codicon()
check("icon count", ic.count(), 460)
check("font path", ic.font_path, "assets/fonts/codicon.ttf")
# every icon the IDE chrome references must resolve
for n in ["files","search","source-control","debug-alt","sparkle","folder","file",
          "play","debug-stop","terminal","settings-gear","close","chevron-right",
          "chevron-down","error","warning","info","git-commit","save","new-file"]:
    check("icon " + n, ic.has(n), true)
check("unknown icon falls back", ic.get("no-such-icon-xyz"), "?")

# ── Dark+ palette values ─────────────────────────────────────────────────────
var p = Palette()
check("editor bg r", p.SURFACE.r, 30)
check("editor bg g", p.SURFACE.g, 30)
check("editor bg b", p.SURFACE.b, 30)
check("sidebar r", p.SURFACE2.r, 37)
check("foreground r", p.ON_SURFACE.r, 212)
check("accent r", p.ACCENT.r, 0)
check("accent g", p.ACCENT.g, 122)
check("accent b", p.ACCENT.b, 204)
check("activitybar r", p.ACTIVITYBAR.r, 51)
check("statusbar b", p.STATUSBAR.b, 204)
check("selection r", p.SELECTION.r, 38)
check("error r", p.DANGER.r, 241)

# syntax tokens
check("keyword r", p.SYN_KEYWORD.r, 197)
check("string r", p.SYN_STRING.r, 206)
check("comment g", p.SYN_COMMENT.g, 153)
check("number r", p.SYN_NUMBER.r, 181)
check("function r", p.SYN_FUNCTION.r, 220)
check("type g", p.SYN_TYPE.g, 201)

# ── Theme wiring ─────────────────────────────────────────────────────────────
var t = Theme()
check("theme border", t.border.r, 59)
check("theme radius", t.radius, 4)
check("theme secondary", t.text_secondary.r, 133)
check("theme tab_active", t.tab_active.r, 30)
check("theme statusbar", t.statusbar.b, 204)


# ── High-DPI (round 45) ──────────────────────────────────────────────────────
# gui_display_scale() reports the panel's content scale. Nothing queried it
# before, so every metric was a raw pixel count and the UI rendered half-size
# with blurry text on a Retina/4K display.
var sc = gui_display_scale()
check_true("display scale positive", sc > 0.0)
check_true("display scale sane", sc <= 8.0)
check_true("window scale positive", gui_window_scale() > 0.0)
# scaling is a pure multiply-and-round, so it must be exact at 1.0
def scaled(v, d):
    return int(float(v) * d + 0.5)
check("scale 1.0 is identity", scaled(38, 1.0), 38)
check("scale 2.0 doubles", scaled(38, 2.0), 76)
check("scale 1.5 rounds", scaled(38, 1.5), 57)
check("scale 1.25 rounds half up", scaled(10, 1.25), 13)

print "Results: " + str(npass) + " passed, " + str(fail) + " failed"
if fail == 0:
    print "=== TEST 13 PASSED ==="
else:
    print "=== TEST 13 FAILED ==="

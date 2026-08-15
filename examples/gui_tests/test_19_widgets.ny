# Test 19: Splitter, ScrollArea, FocusManager + the Flex-solved IDE layout.
import "lib/gui.ny"
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

print "=== Test 19: Widgets ==="

# ── Splitter ─────────────────────────────────────────────────────────────────
var sp = Splitter("vertical", 260, 1)
sp.layout(0, 0, 1000, 600)
check("vertical cursor", sp.cursor_shape(), "sizewe")
check("grab band offset by slop", sp.rect.x, 256)
check("grab band width", sp.rect.w, 9)
check_true("hit inside band", sp.contains(258, 300))
check("miss outside band", sp.contains(400, 300), false)

sp.begin_drag(260, 100)
check_true("dragging flag set", sp.dragging)
check("drag moves position", sp.drag_to(400, 100), 400)
# a drag that runs past either end must clamp, not invert the panes
check("clamps to min_before", sp.drag_to(-500, 100), 80)
check("clamps to min_after", sp.drag_to(99999, 100), 920)
sp.end_drag()
check("drag ends", sp.dragging, false)
# a move after the drag ends is ignored
check("no drift after release", sp.drag_to(10, 10), 920)

var hs = Splitter("horizontal", 100, 1)
check("horizontal cursor", hs.cursor_shape(), "sizens")
hs.layout(0, 0, 800, 500)
check("horizontal band y", hs.rect.y, 96)

# ── ScrollArea ───────────────────────────────────────────────────────────────
var sa = ScrollArea(0, 0, 200, 300)
sa.set_content(200, 3000)
check("max scroll", sa.max_scroll_y(), 2700)
check_true("needs vertical bar", sa.needs_vbar())
check("no horizontal bar", sa.needs_hbar(), false)

sa.scroll_to(0)
var t0 = sa.vbar_thumb()
check("thumb starts at top", t0[0], 0)
check("thumb sized to visible fraction", t0[1], 30)
sa.scroll_to(2700)
var t1 = sa.vbar_thumb()
check("thumb reaches bottom", t1[0], 270)

sa.scroll_to(0)
sa.scroll_wheel(-1)
check("wheel scrolls down", sa.scroll_y, 54)
sa.scroll_wheel(1)
check("wheel scrolls back up", sa.scroll_y, 0)
# scrolling past either end clamps rather than running off
sa.scroll_by(0, -9999)
check("clamped at top", sa.scroll_y, 0)
sa.scroll_by(0, 999999)
check("clamped at bottom", sa.scroll_y, 2700)
sa.scroll_to(0)
sa.page_down()
check("page down by viewport", sa.scroll_y, 300)
sa.page_up()
check("page up by viewport", sa.scroll_y, 0)

# virtualization: a 3000px document renders ~18 rows, not all of them
var vr = sa.visible_range(18)
check("first visible row", vr[0], 0)
check_true("renders only a screenful", vr[1] < 25)
sa.scroll_to(54)
check("first row follows scroll", sa.visible_range(18)[0], 3)

# content smaller than the viewport needs no bar and cannot scroll
var small = ScrollArea(0, 0, 200, 300)
small.set_content(200, 100)
check("small content no bar", small.needs_vbar(), false)
check("small content max scroll", small.max_scroll_y(), 0)
check("small content thumb empty", small.vbar_thumb()[1], 0)

# ── FocusManager ─────────────────────────────────────────────────────────────
var fm = FocusManager()
check("empty ring current", fm.current(), "")
check("empty ring next", fm.next(), "")
fm.register("editor")
fm.register("tree")
fm.register("terminal")
check("first registration focuses", fm.current(), "editor")
check("tab advances", fm.next(), "tree")
check("tab advances again", fm.next(), "terminal")
check("tab wraps to start", fm.next(), "editor")
check("shift-tab wraps to end", fm.prev(), "terminal")
check_true("has_focus true for current", fm.has_focus("terminal"))
check("has_focus false for other", fm.has_focus("editor"), false)
check_true("focus by name", fm.focus("tree"))
check("focus unknown name fails", fm.focus("nope"), false)
check("focus unchanged after failure", fm.current(), "tree")

# ── IDE layout solved by Flex matches the old hand arithmetic ────────────────
def solve_editor(W, H):
    var v = Flex("column")
    v.add("toolbar", 38, 0)
    v.add("content", 0, 1)
    v.add("status", 26, 0)
    v.solve(0, 0, W, H)
    var h = Flex("row")
    h.add("activity", 52, 0)
    h.add("sidebar", 260, 0)
    h.add_min("editor", 0, 1, 120)
    h.add("minimap", 110, 0)
    h.solve(0, v.get("content").y, W, v.get("content").h)
    return [v.get("content").y, v.get("content").h,
            h.get("editor").x, h.get("editor").w, h.get("minimap").x]

check("1600x960 matches hand geometry", solve_editor(1600, 960), [38, 896, 312, 1178, 1490])
check("1280x720 matches", solve_editor(1280, 720), [38, 656, 312, 858, 1170])
check("1920x1080 matches", solve_editor(1920, 1080), [38, 1016, 312, 1498, 1810])
check("800x600 matches", solve_editor(800, 600), [38, 536, 312, 378, 690])
check("640x400 matches", solve_editor(640, 400), [38, 336, 312, 218, 530])

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 19 PASSED ==="
else:
    print "=== TEST 19 FAILED ==="

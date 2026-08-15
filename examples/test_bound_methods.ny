# test_bound_methods.ny
#
# Pins the calling convention for methods. The bug this guards against was
# silent: when a method was read as a VALUE rather than called immediately, its
# instance was not carried along, so at call time every argument shifted left by
# one. Nothing raised — `self` simply became the first argument and attribute
# reads on it returned none. That is what blanked the IDE window, because the
# whole render callback ran with `self` bound to the Renderer.
#
# `self` is now supplied in exactly one place (bindParamsKw), so every
# invocation path below must agree.

var failures = 0

def check(label, got, want):
    if got == want:
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1


class Owner:
    def __init__(self):
        self.n = 7

    def two(self, a, b):
        return str(self.n) + "|" + str(a) + "|" + str(b)

    def kw(self, a, b):
        return str(self.n) + "|" + str(a) + "|" + str(b)

    def varargs(self, *rest):
        return str(self.n) + "|" + str(len(rest))

    def none_args(self):
        return str(self.n)


class Holder:
    def __init__(self):
        self.cb = none

    def fire(self, a, b):
        return self.cb(a, b)


def call_it(fn, a, b):
    return fn(a, b)


print "=== bound methods ==="
var o = Owner()
var want = "7|1|2"

check("called directly",        o.two(1, 2), want)
check("passed as an argument",  call_it(o.two, 1, 2), want)

var h = Holder()
h.cb = o.two
check("stored in an attribute", h.fire(1, 2), want)

var lst = [o.two]
check("stored in a list",       lst[0](1, 2), want)

var m = {"f": o.two}
check("stored in a map",        m["f"](1, 2), want)

var local = o.two
check("assigned to a variable", local(1, 2), want)

check("zero-arg method",        o.none_args(), "7")
check("varargs positional",     o.varargs(1, 2, 3), "7|3")
var v = o.varargs
check("varargs when bound",     call_it(v, 4, 5), "7|2")


print "=== keyword arguments ==="
# Keyword arguments used to be dropped for methods (but not plain functions),
# because callMethod built an empty keyword map and threw the real one away.
def plain(a, b):
    return str(a) + "|" + str(b)

check("plain, all keyword",     plain(b=20, a=10), "10|20")
check("plain, mixed",           plain(10, b=20), "10|20")
check("method, all keyword",    o.kw(b=20, a=10), "7|10|20")
check("method, mixed",          o.kw(10, b=20), "7|10|20")
check("method, positional",     o.kw(10, 20), "7|10|20")


print "=== containers ==="
# map.remove() erases by key; list.remove() removes by value; both used to hit
# the set-removal handler, which aborted the interpreter on a map.
var mm = {"a": 1, "b": 2}
check("map.remove returns value", mm.remove("a"), 1)
check("map.remove erased key",    mm.has_key("a"), false)
check("map.remove kept others",   mm.has_key("b"), true)

var ll = [1, 2, 3]
ll.remove(2)
check("list.remove by value",     len(ll), 2)
check("list.contains present",    [1, 2, 3].contains(2), true)
check("list.contains absent",     [1, 2, 3].contains(9), false)

var ss = Set([1, 2, 3])
ss.remove(2)
check("set.remove",               len(ss), 2)


print "=== inline suites ==="
# `def f(): a; b` used to parse only the first statement and silently drop the
# rest. ide_editor.ny defines set_pos/set_size that way, so set_pos() assigned x
# and left y untouched — which drew the output console over the menu bar
# instead of inside the bottom panel.
class Pt:
    def __init__(self):
        self.x = 0
        self.y = 0
    def set_pos(self, x, y): self.x = x; self.y = y
    def set3(self, a, b, c): self.x = a; self.y = b; self.z = c

var pt = Pt()
pt.set_pos(11, 22)
check("inline suite, 2 statements", str(pt.x) + "|" + str(pt.y), "11|22")
pt.set3(1, 2, 3)
check("inline suite, 3 statements", str(pt.x) + "|" + str(pt.y) + "|" + str(pt.z), "1|2|3")

var q = 1; var w = 2
check("top-level semicolons",       str(q) + "|" + str(w), "1|2")



print "=== parenthesised conditions ==="
# `if (A) or (B):` used to be a syntax error: the if-parser consumed the opening
# paren, then required the closing paren immediately before the colon, so any
# operator after the group failed to parse.
var px = 1
var hit1 = false
if (px > 0) or (px < 5):
    hit1 = true
check("if (A) or (B)", hit1, true)

var hit2 = false
if (px > 0) and (px < 5):
    hit2 = true
check("if (A) and (B)", hit2, true)

var branch = ""
if px > 100:
    branch = "no"
elif (px < 0) or (px == 1):
    branch = "yes"
check("elif (A) or (B)", branch, "yes")

var wy = 3
var wr = ""
if (var wz = wy * 2) > 5:
    wr = "walrus " + str(wz)
check("walrus form still parses", wr, "walrus 6")


print "=== context reclamation ==="
# Per-call contexts are freed when nothing retained them. These check that the
# escape analysis keeps alive everything that is still reachable: a closure over
# a local, nested closures, many simultaneous closures, and deep recursion.
def _mk(startv):
    var n = startv
    def inc():
        n = n + 1
        return n
    return inc

var ca = _mk(10)
var cb = _mk(100)
check("closure keeps its scope", str(ca()) + "," + str(ca()) + "," + str(cb()), "11,12,101")

def _outer(x):
    def _mid(y):
        def _inner(z):
            return x + y + z
        return _inner
    return _mid
check("nested closures", _outer(1)(2)(3), 6)

var many = []
var mi = 0
while mi < 100:
    many.append(_mk(mi))
    mi = mi + 1
check("100 live closures", str(many[0]()) + "," + str(many[99]()), "1,100")

def _rec(n):
    if n <= 0:
        return 0
    return 1 + _rec(n - 1)
check("deep recursion", _rec(200), 200)


print "=== keyword arguments on the VM ==="
# These pass on the interpreter and used to crash the bytecode VM: its compiler
# matched AssignmentNode for keyword arguments, but the parser emits
# KeywordArgNode, so every keyword argument became a positional NOP while argc
# still counted it. Run this file with --vm to exercise that path.
def _kw2(a, key):
    return str(a) + str(key)
check("keyword arg",          _kw2(1, key=2), "12")
check("keyword out of order",  _kw2(key=2, a=1), "12")

var _w = ["bb", "a"]
check("sorted with key",     str(sorted(_w, key=lambda x: len(x))), str(["a", "bb"]))
check("sorted reverse kwarg", str(sorted(_w, reverse=true)), str(["bb", "a"]))

print ""
if failures == 0:
    print "PASS: all bound-method and calling-convention checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

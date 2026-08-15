# Test 26: the `is` / `is not` operators.
#
# `is` answers "does the left operand belong to the right?" in the widest useful
# sense, not only pointer identity. Every assertion here is verified identical
# on the interpreter and the VM.

var npass = 0
var nfail = 0
def check(name, got, want):
    if got == want:
        npass = npass + 1
    else:
        nfail = nfail + 1
        print "  FAIL [" + name + "] got=" + str(got) + " want=" + str(want)

print "=== Test 26: is / is not ==="

class Base:
    def __init__(self):
        self.v = 1
class Child(Base):
    def __init__(self):
        self.v = 2
var c = Child()
var b = Base()

# ── value identity ───────────────────────────────────────────────────────────
check("1 is 1", 1 is 1, true)
check("1 is 2", 1 is 2, false)
check("none is none", none is none, true)
check("true is true", true is true, true)
check("string value identity", "1" is "1", true)

# ── cross-type never matches ─────────────────────────────────────────────────
# A number and its text are different things; this is the case that makes `is`
# more than ==.
check("1 is '1'", 1 is "1", false)
check("'1' is 1", "1" is 1, false)

# ── primitive type names ─────────────────────────────────────────────────────
check("1 is int", 1 is int, true)
check("1 is Integer", 1 is Integer, true)
check("1 is str", 1 is str, false)
check("'a' is str", "a" is str, true)
check("'a' is String", "a" is String, true)
check("1.5 is float", 1.5 is float, true)
check("1.5 is int", 1.5 is int, false)
check("true is bool", true is bool, true)
check("[1] is list", [1] is list, true)
check("[1] is map", [1] is map, false)
check("none is none-type", none is none, true)

# ── Object is the root of everything ─────────────────────────────────────────
check("1 is Object", 1 is Object, true)
check("'a' is Object", "a" is Object, true)
check("[1] is Object", [1] is Object, true)
check("instance is Object", c is Object, true)

# ── classes, walking the inheritance chain ───────────────────────────────────
check("child is its class", c is Child, true)
check("child is its parent", c is Base, true)
check("parent is not the child", b is Child, false)

# ── a variable on the right is a VALUE test, not a type test ─────────────────
# `1 is x` where x holds 1 must compare values; only a bare type name is a type
# test, or shadowing a type name would silently change the meaning of `is`.
var x = 1
check("variable holding 1", 1 is x, true)
var y = 2
check("variable holding 2", 1 is y, false)

# ── is not is the exact negation ─────────────────────────────────────────────
check("1 is not str", 1 is not str, true)
check("1 is not int", 1 is not int, false)
check("1 is not 2", 1 is not 2, true)
check("1 is not 1", 1 is not 1, false)
check("child is not Base", c is not Base, false)
check("parent is not Child", b is not Child, true)
check("1 is not Object", 1 is not Object, false)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 26 PASSED ==="
else:
    print "=== TEST 26 FAILED ==="

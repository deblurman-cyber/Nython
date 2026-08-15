# Test 24: the import system.
#
# Three forms must work, and must work IDENTICALLY on both engines — adding a
# feature to one engine only has been the source of several divergences in this
# project.
import "examples/lib/impdemo.ny"
from "examples/lib/impdemo.ny" import demo_add
import "examples/lib/impdemo.ny" as box

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

print "=== Test 24: imports ==="

# ── plain import: names land in the current scope ────────────────────────────
check("plain import binds a function", demo_add(2, 3), 5)
check("plain import binds a var", DEMO_VERSION, "2.1")
var b1 = DemoBox(7)
check("plain import binds a class", b1.get(), 7)

# ── from ... import: the named binding is present ────────────────────────────
check("from-import binds the name", demo_add(10, 5), 15)

# ── import ... as: the alias is a namespace ──────────────────────────────────
# The parser has always recorded ImportNode::alias; nothing read it, so the
# alias bound nothing and box.demo_add() returned none with no diagnostic.
check("alias exposes a function", box.demo_add(4, 4), 8)
check("alias exposes a var", box.DEMO_VERSION, "2.1")
var b2 = box.DemoBox(9)
check("alias exposes a class", b2.get(), 9)

# ── repeat imports are idempotent ────────────────────────────────────────────
# A module executed twice would re-run its top level and rebind everything.
check("re-import is stable", demo_add(1, 1), 2)

# ── missing modules are an error, not silence ────────────────────────────────
# A module that could not be found used to resolve to nothing, so every name it
# would have defined failed later with no hint the import was the cause.
var caught = false
try:
    import "definitely_not_a_real_module_xyz"
except:
    caught = true
check_true("missing module raises", caught)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 24 PASSED ==="
else:
    print "=== TEST 24 FAILED ==="

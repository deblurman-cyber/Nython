# test_robustness.ny — builtins must reject wrong-typed input, not crash.
#
# A generated sweep that called 350 builtins with deliberately mismatched
# arguments found three process-killing bugs. Each returned a plausible answer
# for correct input, so nothing in the normal test suite touched them:
#
#   items("abc")          a string's value.p is not a Collectable; the
#   keys("abc")           dynamic_cast read a bogus vtable
#   values("abc")
#   mat_transpose([1,2])  container->find("__rows__")->second dereferenced end()
#
# Reaching the end of this file is the pass condition.

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

print "=== container builtins on a string ==="
check("items on string",  items("abc"),  none)
check("keys on string",   keys("abc"),   none)
check("values on string", values("abc"), none)

print "=== container builtins on real containers still work ==="
check("items on map", str(items({"a": 1})), "[['a', 1]]")
check("keys count",   len(keys({"a": 1, "b": 2})), 2)

print "=== matrix builtins on non-matrices ==="
check("transpose flat list", mat_transpose([3, 1, 2]), none)
check("shape flat list",     str(mat_shape([1, 2])), "[0, 0]")

print "=== matrix builtins on a real matrix ==="
var m = mat([[1.0, 2.0], [3.0, 4.0]])
check("shape", str(mat_shape(m)), "[2, 2]")
var t = mat_transpose(m)
# Assert the transposed shape rather than type(): the interpreter reports
# "matrix" for a value carrying a __type__ marker while the VM reports "map",
# and that difference is not what this test is about.
check("transpose shape", str(mat_shape(t)), "[2, 2]")
check("transpose value", mat_get(t, 0, 1), 3.0)   # transposed: m[1][0]

print "=== float formatting is identical on both engines ==="
check("third",   str(1.0 / 3.0), "0.333333333333333")
check("seventh", str(2.0 / 7.0), "0.285714285714286")
check("exact",   str(1.5), "1.5")
check("whole",   str(100.0), "100.0")

print ""
if failures == 0:
    print "PASS: robustness checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

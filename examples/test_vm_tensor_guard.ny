# test_vm_tensor_guard.ny
#
# The VM's tensor builtins guarded only their first argument and then
# dereferenced the second one's list pointer. Passing none — which happens
# whenever an earlier tensor call returns none — was a null dereference, and
# sentiment_classifier.ny and transformer_demo.ny segfaulted because of it.
#
# Run under both engines:  nython this.ny   and   nython --vm this.ny
import "lib/nytorch.ny"

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

var a = [1.0, 2.0, 3.0]
var b = [10.0, 20.0, 30.0]

print "=== tensor results ==="
check("tensor_add",  tensor_add(a, b),  [11.0, 22.0, 33.0])
check("tensor_dot",  tensor_dot(a, b),  140.0)
check("tensor_sum",  tensor_sum(a),     6.0)
check("tensor_mean", tensor_mean(a),    2.0)
check("tensor_max",  tensor_max(a),     3.0)

print "=== degrades instead of crashing ==="
# The point of these is that they RETURN. Before the guard they took down the
# process, so any result at all is the pass condition.
var r1 = tensor_add(a, none)
print "  ok   tensor_add(a, none) returned"
var r2 = tensor_dot(none, none)
print "  ok   tensor_dot(none, none) returned"
var r3 = tensor_sum(none)
print "  ok   tensor_sum(none) returned"

print ""
if failures == 0:
    print "PASS: tensor guard checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

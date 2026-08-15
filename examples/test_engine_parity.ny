# test_engine_parity.ny
#
# The same program must produce the same answers on the interpreter and on the
# bytecode VM. Where both engines implement a builtin, the VM's own version
# shadows the interpreter's, and several had drifted:
#
#   str(["a"])   ->  ['a']  vs  ["a"]      container quoting
#   type("a")    ->  string vs  str        type name
#   pow(2, 10)   ->  1024.0 vs  1024       result type
#
# Anything branching on those got different behaviour depending on how it ran.
# Run this file under BOTH engines; the expected values are the interpreter's.

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

print "=== stringification ==="
check("list of strings", str(["a", "b"]), "['a', 'b']")
check("nested list",     str([["x"]]),    "[['x']]")
check("list of ints",    str([1, 2]),     "[1, 2]")

print "=== type names ==="
check("type string", type("a"), "string")
check("type int",    type(1), "int")
check("type list",   type([1]), "list")

print "=== numeric result types ==="
check("pow is float", pow(2, 10), 1024.0)
check("abs",          abs(0 - 5), 5)
check("round",        round(2.567, 2), 2.57)

print "=== string builtins ==="
check("upper",   string_upper("aBc"), "ABC")
check("split",   str(string_split("a,b", ",")), "['a', 'b']")
check("slice",   string_slice("abcdef", 1, 4), "bcd")
check("find",    string_find("abcdef", "cd"), 2)
check("replace", string_replace("banana", "a", "X"), "bXnXnX")

print "=== collections ==="
check("sorted",   str(sorted([3, 1, 2])), "[1, 2, 3]")
check("reversed", str(reversed([1, 2, 3])), "[3, 2, 1]")
check("sum",      sum([1, 2, 3]), 6)

print ""
if failures == 0:
    print "PASS: engine parity checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

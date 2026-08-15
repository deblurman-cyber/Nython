# Test 16: the profiler measures, it does not estimate.
import "lib/ide_toolchain.ny"

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

print "=== Test 16: Profiler ==="
var tc = Toolchain()

# hot() does ~50x the work of cold(); a real profiler must rank them that way.
# The old implementation invented a duration per "def " line and could not.
var src = "def hot(n):\n    var s = 0\n    var i = 0\n    while i < n:\n        s = s + i\n        i = i + 1\n    return s\n"
src = src + "def cold(n):\n    return n + 1\n"
src = src + "def driver():\n    var t = hot(40000)\n    t = t + cold(1)\n    return t\n"
src = src + "print(driver())\n"

var r = tc.profile(src, "hot.ny")
check("profile ok", r.ok, true)
check("three functions", r.profile_count, 3)

# rows are sorted by self time, hottest first
check("hottest is hot()", r.profile_rows[0][0], "hot")
check_true("hot has self time", r.profile_rows[0][3] > 0.0)

# find each row by name
var hot_self = 0.0
var cold_self = 0.0
var driver_self = 0.0
var driver_total = 0.0
var hot_calls = 0
var i = 0
while i < r.profile_count:
    var row = r.profile_rows[i]
    if row[0] == "hot":
        hot_calls = row[1]
        hot_self = row[3]
    if row[0] == "cold":
        cold_self = row[3]
    if row[0] == "driver":
        driver_total = row[2]
        driver_self = row[3]
    i = i + 1

check("hot called once", hot_calls, 1)
check_true("hot dominates cold", hot_self > cold_self)
# driver spends nearly all its time in callees, so self << total
check_true("self excludes child time", driver_self < driver_total)
check_true("driver total covers hot", driver_total >= hot_self)

# the program's own output is separated from the report
var prog = tc.split_program_output(r)
check("program printed one line", len(prog), 1)
check_true("no report leaked into output", string_find(prog[0], "__NY_PROFILE__") < 0)

# recursion is counted per call but timed once, not once per level
var rsrc = "def fib(n):\n    if n < 2:\n        return n\n    return fib(n-1) + fib(n-2)\nprint(fib(12))\n"
var rr = tc.profile(rsrc, "fib.ny")
check("recursive fn profiled", rr.profile_count, 1)
check("fib call count exact", rr.profile_rows[0][1], 465)
check_true("recursive total not inflated", rr.profile_rows[0][2] < 60000.0)

# a program with no calls profiles cleanly rather than erroring
var nr = tc.profile("var x = 1 + 1\nprint(x)\n", "none.ny")
check("no-call program ok", nr.ok, true)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 16 PASSED ==="
else:
    print "=== TEST 16 FAILED ==="

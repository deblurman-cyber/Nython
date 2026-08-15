# test_syntax_forms.ny — language forms that used to fail to parse.
# Runs identically under the interpreter and under --vm.

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

print "=== method chains across lines ==="
# The lexer emits NewLine + Indent between the receiver and the '.', which ended
# the statement. postfix() now joins the chain and consumes the paired Dedent.
var chained = [10, 5, 8, 3, 12]
    .filter(lambda x: x > 4)
    .map(lambda x: x * 2)
check("multi-line chain", chained, [20, 10, 16, 24])

var one_line = [10, 5, 8, 3, 12].filter(lambda x: x > 4).map(lambda x: x * 2)
check("single-line chain", one_line, [20, 10, 16, 24])

print "=== repeat ==="
# `repeat N:` did not parse: only the repeat/until form existed.
var acc = 0
repeat 5:
    acc = acc + 2
check("repeat N", acc, 10)

var u = 0
repeat:
    u = u + 1
until u >= 3
check("repeat until", u, 3)

print "=== keywords as names ==="
# lib/thread.ny declares `def await(self)`, which the parser rejected.
class Waiter:
    def __init__(self):
        self.done = false
    def await(self):
        self.done = true
        return "awaited"
var w = Waiter()
check("method named await", w.await(), "awaited")
check("await side effect",  w.done, true)

print ""
if failures == 0:
    print "PASS: syntax form checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

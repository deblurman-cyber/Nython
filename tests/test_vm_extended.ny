# Comprehensive VM extended test suite
# Tests all features added in VM improvement sessions

import nytorch

var passed = 0
var failed = 0

def assert_eq(name, a, b):
    if a == b:
        print "  PASS:", name
        passed = passed + 1
    else:
        print "  FAIL:", name, "(got", str(a), "expected", str(b) + ")"
        failed = failed + 1

def assert_true(name, cond):
    if cond:
        print "  PASS:", name
        passed = passed + 1
    else:
        print "  FAIL:", name
        failed = failed + 1

print "--- Inheritance ---"
class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return self.name + " speaks"

class Dog(Animal):
    def __init__(self, name, breed):
        Animal.__init__(self, name)
        self.breed = breed
    def speak(self):
        return self.name + " barks"

var d = Dog("Rex", "Lab")
assert_eq("inheritance name", d.name, "Rex")
assert_eq("inheritance breed", d.breed, "Lab")
assert_eq("method override", d.speak(), "Rex barks")
assert_eq("parent method", Animal("Cat").speak(), "Cat speaks")

print "--- for/while else ---"
var found = false
for i in range(5):
    if i == 3:
        var found = true
        break
else:
    print "  (else ran - wrong)"
assert_eq("for-break no-else", found, true)

var else_ran = false
for i in range(5):
    if i == 99:
        break
else:
    var else_ran = true
assert_eq("for-nobreak else", else_ran, true)

var w_else = false
var n = 3
while n > 0:
    n -= 1
else:
    var w_else = true
assert_eq("while-else ran", w_else, true)
assert_eq("while-else n", n, 0)

print "--- MAP methods ---"
var d1 = {"a": 1, "b": 2, "c": 3}
var keys = d1.keys()
assert_eq("map keys count", len(keys), 3)
assert_eq("map get hit", d1.get("a", 0), 1)
assert_eq("map get miss", d1.get("z", -1), -1)
var vals = d1.values()
assert_eq("map values count", len(vals), 3)
var items = d1.items()
assert_eq("map items count", len(items), 3)

print "--- any / all ---"
assert_eq("any true", any([false, true, false]), true)
assert_eq("any false", any([false, false, false]), false)
assert_eq("all true", all([true, true, true]), true)
assert_eq("all false", all([true, false, true]), false)

print "--- map / filter / reduce ---"
var doubled = map(lambda x: x * 2, [1, 2, 3])
assert_eq("map result", doubled, [2, 4, 6])

var evens = filter(lambda x: x % 2 == 0, [1, 2, 3, 4, 5, 6])
assert_eq("filter result", evens, [2, 4, 6])

var total = reduce(lambda a, b: a + b, [1, 2, 3, 4, 5])
assert_eq("reduce sum", total, 15)

print "--- generators ---"
def count_up(n):
    var i = 0
    while i < n:
        yield i
        var i = i + 1

var gen_vals = list(count_up(4))
assert_eq("generator list", gen_vals, [0, 1, 2, 3])

var gen_sum = 0
for v in count_up(5):
    gen_sum += v
assert_eq("generator for sum", gen_sum, 10)

var g = count_up(3)
assert_eq("next() 0", next(g), 0)
assert_eq("next() 1", next(g), 1)
assert_eq("next() 2", next(g), 2)

print "--- list / set / dict builtins ---"
var lst = list("abc")
assert_eq("list from str len", len(lst), 3)

var uniq = set([1, 2, 2, 3, 3, 3])
assert_eq("set dedupe", len(uniq), 3)

print "--- @ decorators ---"
def double_call(callback):
    def wrapper(x):
        callback(x)
        callback(x)
    return wrapper

var call_count = 0
def inc_count(x):
    call_count += 1

var doubled_inc = double_call(inc_count)
doubled_inc(0)
assert_eq("decorator double call", call_count, 2)

print "--- slice assignment ---"
var arr = [1, 2, 3, 4, 5]
arr[1:3] = [20, 30]
assert_eq("slice assign [1]", arr[1], 20)
assert_eq("slice assign [2]", arr[2], 30)

print ""
print "Results:", passed, "passed,", failed, "failed"
if failed == 0:
    print "=== ALL EXTENDED VM TESTS PASSED ==="

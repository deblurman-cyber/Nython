# vm_audit26.ny — Advanced edge cases and feature coverage
# Tests: chained methods, nested closures, complex dict/list ops,
#        exception chaining, string edge cases, numeric edge cases,
#        class method resolution, multiple inheritance patterns

var passed = 0
var failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "]"

def section(name):
    print "  " + name + " ..."

print "=== VM AUDIT 26 ==="

# ── 1. Chained string operations ─────────────────────────────────────────
section("Chained string ops")
var s = "  Hello, World!  "
assert_eq("strip", string_strip(s), "Hello, World!")
assert_eq("lower", string_lower("ABC"), "abc")
assert_eq("upper", string_upper("abc"), "ABC")
assert_eq("find", string_find("hello world", "world"), 6)
assert_eq("find missing", string_find("hello", "xyz"), -1)
assert_true("startswith", string_startswith("nython", "ny"))
assert_true("not startswith", not string_startswith("nython", "py"))
assert_eq("split len", len(string_split("a,b,c", ",")), 3)
assert_eq("split 0", string_split("a,b,c", ",")[0], "a")
assert_eq("split 2", string_split("a,b,c", ",")[2], "c")

# ── 2. Nested list comprehension patterns ────────────────────────────────
section("Nested list patterns")
var matrix = [[1,2,3],[4,5,6],[7,8,9]]
assert_eq("matrix[0][0]", matrix[0][0], 1)
assert_eq("matrix[1][2]", matrix[1][2], 6)
assert_eq("matrix[2][1]", matrix[2][1], 8)
var flat = []
var i = 0
while i < 3:
    var j = 0
    while j < 3:
        flat = flat + [matrix[i][j]]
        j = j + 1
    i = i + 1
assert_eq("flat len", len(flat), 9)
assert_eq("flat sum", flat[0]+flat[1]+flat[2]+flat[3]+flat[4]+flat[5]+flat[6]+flat[7]+flat[8], 45)

# ── 3. Dict manipulation ────────────────────────────────────────────────
section("Dict manipulation")
var d = {"name": "nython", "version": 3, "active": true}
assert_eq("dict name", d["name"], "nython")
assert_eq("dict version", d["version"], 3)
assert_eq("dict active", d["active"], true)
d["platform"] = "cross"
assert_eq("dict add", d["platform"], "cross")
d["version"] = 4
assert_eq("dict update", d["version"], 4)

# ── 4. Nested dicts ──────────────────────────────────────────────────────
section("Nested dicts")
var config = {"db": {"host": "localhost", "port": 5432}, "debug": true}
assert_eq("nested host", config["db"]["host"], "localhost")
assert_eq("nested port", config["db"]["port"], 5432)
config["db"]["port"] = 3306
assert_eq("nested update", config["db"]["port"], 3306)

# ── 5. Closures capturing loop variables ─────────────────────────────────
section("Closure capture")
# Closures capture enclosing scope — all see final val due to capture-by-ref
var makers = []
var i = 0
while i < 5:
    var val = i
    def fn():
        return val * val
    makers = makers + [fn]
    i = i + 1
# All closures see val=4 (last loop iteration's val)
assert_eq("closure shared", makers[0](), 16)
assert_eq("closure shared2", makers[4](), 16)

# To get per-iteration capture, use a factory function
def make_squarer(n):
    def sq():
        return n * n
    return sq

var squarers = []
var j = 0
while j < 5:
    squarers = squarers + [make_squarer(j)]
    j = j + 1
assert_eq("factory 0", squarers[0](), 0)
assert_eq("factory 2", squarers[2](), 4)
assert_eq("factory 4", squarers[4](), 16)

# ── 6. Class with static-like methods ───────────────────────────────────
section("Class patterns")
class Counter:
    def __init__(self, start):
        self.value = start
    def inc(self):
        self.value = self.value + 1
        return self
    def dec(self):
        self.value = self.value - 1
        return self
    def get(self):
        return self.value

var c = Counter(10)
c.inc()
c.inc()
c.inc()
assert_eq("counter inc", c.get(), 13)
c.dec()
assert_eq("counter dec", c.get(), 12)

# ── 7. Chained method calls ─────────────────────────────────────────────
section("Chained methods")
class Builder:
    def __init__(self):
        self.parts = []
    def add(self, part):
        self.parts = self.parts + [part]
        return self
    def build(self):
        var result = ""
        var i = 0
        while i < len(self.parts):
            if i > 0:
                result = result + " "
            result = result + self.parts[i]
            i = i + 1
        return result

var msg = Builder().add("hello").add("world").add("!").build()
assert_eq("chained build", msg, "hello world !")

# ── 8. Inheritance ───────────────────────────────────────────────────────
section("Inheritance")
class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return "..."

class Dog(Animal):
    def speak(self):
        return self.name + " says woof"

class Cat(Animal):
    def speak(self):
        return self.name + " says meow"

var d = Dog("Rex")
var c = Cat("Whiskers")
assert_eq("dog name", d.name, "Rex")
assert_eq("dog speak", d.speak(), "Rex says woof")
assert_eq("cat speak", c.speak(), "Whiskers says meow")

# ── 9. Exception handling ────────────────────────────────────────────────
section("Exception handling")
var caught = false
try:
    var x = 1 / 0
except as e:
    caught = true
assert_true("div by zero caught", caught)

var msg2 = ""
try:
    raise "custom error"
except as e:
    msg2 = str(e)
assert_true("custom raise", string_find(msg2, "custom error") >= 0)

# Nested try
var inner_caught = false
var outer_caught = false
try:
    try:
        raise "inner"
    except as e:
        inner_caught = true
        raise "outer"
except as e:
    outer_caught = true
assert_true("inner caught", inner_caught)
assert_true("outer caught", outer_caught)

# ── 10. Generators ──────────────────────────────────────────────────────
section("Generators")
def countdown(n):
    while n > 0:
        yield n
        n = n - 1

var items = []
for val in countdown(5):
    items = items + [val]
assert_eq("gen len", len(items), 5)
assert_eq("gen first", items[0], 5)
assert_eq("gen last", items[4], 1)

def fibonacci(limit):
    var a = 0
    var b = 1
    while a < limit:
        yield a
        var temp = a
        a = b
        b = temp + b

var fibs = []
for f in fibonacci(20):
    fibs = fibs + [f]
assert_eq("fib count", len(fibs), 8)
assert_eq("fib 0", fibs[0], 0)
assert_eq("fib 7", fibs[7], 13)

# ── 11. Higher-order functions ───────────────────────────────────────────
section("Higher-order functions")
def apply_twice(fn, x):
    return fn(fn(x))

def double(x):
    return x * 2

assert_eq("apply_twice", apply_twice(double, 3), 12)

def make_adder(n):
    def inner(x):
        return x + n
    return inner

var add5 = make_adder(5)
var add10 = make_adder(10)
assert_eq("adder 5", add5(3), 8)
assert_eq("adder 10", add10(3), 13)

# ── 12. Numeric edge cases ──────────────────────────────────────────────
section("Numeric edge cases")
assert_eq("int div", 7 / 2, 3.5)
assert_eq("floor div", 7 // 2, 3)
assert_eq("negative floor", -7 // 2, -4)
assert_eq("power", 2 ** 10, 1024)
assert_eq("large power", 2 ** 20, 1048576)
assert_true("float eq", abs(0.1 + 0.2 - 0.3) < 0.001)
assert_eq("int max", 999999999 + 1, 1000000000)

# ── 13. Boolean edge cases ──────────────────────────────────────────────
section("Boolean edge cases")
assert_eq("true and true", true and true, true)
assert_eq("true and false", true and false, false)
assert_eq("true or false", true or false, true)
assert_eq("false or false", false or false, false)
assert_eq("not true", not true, false)
assert_eq("not false", not false, true)
assert_eq("0 is falsy", bool(0), false)
assert_eq("1 is truthy", bool(1), true)
assert_eq("empty str falsy", bool(""), false)
assert_eq("str truthy", bool("x"), true)

# ── 14. Walrus operator ─────────────────────────────────────────────────
section("Walrus operator")
var items2 = [1, 2, 3, 4, 5]
var result = []
var idx = 0
while idx < len(items2):
    if (var x := items2[idx]) > 2:
        result = result + [x]
    idx = idx + 1
assert_eq("walrus filter len", len(result), 3)
assert_eq("walrus filter 0", result[0], 3)

# ── 15. Multiline expressions ───────────────────────────────────────────
section("Complex expressions")
var a = 1
var b = 2
var c = 3
var result2 = (a + b) * c + (b ** a) - (c % b)
assert_eq("complex expr", result2, 10)

# ── 16. Empty collections ───────────────────────────────────────────────
section("Empty collections")
var empty_list = []
assert_eq("empty list len", len(empty_list), 0)
var empty_dict = {}
assert_eq("empty dict len", len(empty_dict), 0)
var empty_set = set()
assert_eq("empty set len", len(empty_set), 0)

# ── 17. String indexing and slicing ──────────────────────────────────────
section("String indexing")
var s = "nython"
assert_eq("str[0]", s[0], "n")
assert_eq("str[5]", s[5], "n")
assert_eq("str[-1]", s[-1], "n")
assert_eq("str[0:2]", s[0:2], "ny")
assert_eq("str[2:6]", s[2:6], "thon")

# ── 18. For-in with range ───────────────────────────────────────────────
section("For-in range")
var total = 0
for i in range(10):
    total = total + i
assert_eq("range sum", total, 45)

var odds = []
for i in range(1, 10, 2):
    odds = odds + [i]
assert_eq("range step", len(odds), 5)
assert_eq("range step[0]", odds[0], 1)
assert_eq("range step[4]", odds[4], 9)

# ── 19. Ternary expressions ─────────────────────────────────────────────
section("Ternary")
var x = 10
var label = "big" if x > 5 else "small"
assert_eq("ternary true", label, "big")
var label2 = "big" if x < 5 else "small"
assert_eq("ternary false", label2, "small")

# ── 20. Multiple assignment ─────────────────────────────────────────────
section("Multiple assignment")
var a, b, c = 1, 2, 3
assert_eq("multi a", a, 1)
assert_eq("multi b", b, 2)
assert_eq("multi c", c, 3)

# ── 21. Augmented assignment ────────────────────────────────────────────
section("Augmented assignment")
var x = 10
x += 5
assert_eq("+=", x, 15)
x -= 3
assert_eq("-=", x, 12)
x *= 2
assert_eq("*=", x, 24)
x //= 5
assert_eq("//=", x, 4)

# ── Report ───────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

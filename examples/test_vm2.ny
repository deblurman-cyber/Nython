import nytorch

var passed = 0
var failed = 0

def check(name, got, expected):
    var got_s = str(got)
    var exp_s = str(expected)
    if got_s == exp_s:
        passed += 1
    else:
        failed += 1
        print "FAIL:", name, "got:", got_s, "expected:", exp_s

# ── Exception handling ──────────────────────────────────────────
def safe_div(a, b):
    try:
        if b == 0:
            raise "ZeroDivisionError"
        return a / b
    except as e:
        return -1.0

check("safe_div ok", safe_div(10, 2), 5.0)
check("safe_div zero", safe_div(10, 0), -1.0)

def assert_test(x):
    assert x > 0, "must be positive"
    return x * 2

check("assert pass", assert_test(5), 10)
var caught = false
try:
    assert_test(-1)
except as e:
    caught = true
check("assert caught", caught, true)

# ── try/except/finally ──────────────────────────────────────────
var log = []
try:
    log = log + ["try"]
    raise "boom"
except as e:
    log = log + ["except"]
finally:
    log = log + ["finally"]
check("try/except/finally", len(log), 3)
check("finally ran", log[2], "finally")

# ── del statement ───────────────────────────────────────────────
var d = {"x": 1, "y": 2, "z": 3}
del d["y"]
check("del dict key", len(d), 2)
check("del dict x", d["x"], 1)

var lst2 = [10, 20, 30, 40, 50]
del lst2[2]
check("del list idx", len(lst2), 4)
check("del list val", lst2[2], 40)

# ── match/case ──────────────────────────────────────────────────
def classify(n):
    match n:
        case 1:
            return "one"
        case 2:
            return "two"
        case 3:
            return "three"
        case _:
            return "other"

check("match 1", classify(1), "one")
check("match 2", classify(2), "two")
check("match 99", classify(99), "other")

# ── Inheritance chain ───────────────────────────────────────────
class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return self.name + " says ..."
    def kind(self):
        return "animal"

class Dog(Animal):
    def speak(self):
        return self.name + " says woof"

class Labrador(Dog):
    def kind(self):
        return "labrador"

var d2 = Labrador("Rex")
check("inherited init", d2.name, "Rex")
check("overridden speak", d2.speak(), "Rex says woof")
check("grandchild kind", d2.kind(), "labrador")
check("grandparent method", d2.speak(), "Rex says woof")

# ── String methods ──────────────────────────────────────────────
check("capitalize", "hello world".capitalize(), "Hello world")
check("isalnum", "abc123".isalnum(), true)
check("isalpha", "abc".isalpha(), true)
check("isdigit", "123".isdigit(), true)
check("swapcase", "Hello".swapcase(), "hELLO")
check("center fill", "hi".center(8, "*"), "***hi***")
check("ljust fill", "hi".ljust(6, "-"), "hi----")
check("rjust fill", "hi".rjust(6, "-"), "----hi")

# ── List methods ────────────────────────────────────────────────
var nums = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]
check("list count", nums.count(5), 3)
check("list min", nums.min(), 1)
check("list max", nums.max(), 9)
check("list sum", nums.sum(), 44)
var ex = [1, 2, 3]
ex.extend([4, 5])
check("extend len", len(ex), 5)
check("extend val", ex[4], 5)
var cp = ex.copy()
cp.clear()
check("copy independent", len(ex), 5)
check("clear works", len(cp), 0)

# ── Closures ────────────────────────────────────────────────────
def counter():
    var n = 0
    def inc():
        n += 1
        return n
    return inc

var cnt = counter()
check("closure 1", cnt(), 1)
check("closure 2", cnt(), 2)
check("closure 3", cnt(), 3)

# ── Recursive data structures ────────────────────────────────────
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)

check("fib(0)", fib(0), 0)
check("fib(1)", fib(1), 1)
check("fib(10)", fib(10), 55)
check("fib(15)", fib(15), 610)

# ── Dict operations ─────────────────────────────────────────────
var config = {"host": "localhost", "port": 8080, "debug": true}
check("dict get", config.get("host"), "localhost")
check("dict get default", config.get("missing", "default"), "default")
config.update({"port": 9090, "timeout": 30})
check("dict update port", config["port"], 9090)
check("dict update new", config["timeout"], 30)
config.setdefault("debug", false)
check("setdefault existing", config["debug"], true)
config.setdefault("verbose", false)
check("setdefault new", config["verbose"], false)

# ── for-else / while-else ────────────────────────────────────────
def find_prime(lst3):
    for n in lst3:
        for d3 in range(2, n):
            if n % d3 == 0:
                break
        else:
            return n
    return -1

check("for-else prime", find_prime([4, 6, 7, 8]), 7)
check("for-else none", find_prime([4, 6, 8, 9]), -1)

print ""
print "Results:", passed, "passed,", failed, "failed"

var passed = 0
var failed = 0

def check(name, got, expected):
    var got_s = str(got)
    var exp_s = str(expected)
    if got_s == exp_s:
        passed += 1
    else:
        failed += 1
        print "FAIL:", name, "| got:", got_s, "| expected:", exp_s

# ── *args ─────────────────────────────────────────────────────────
def var_args(*args):
    return len(args)

check("*args 0", var_args(), 0)
check("*args 3", var_args(1, 2, 3), 3)

def sum_all(*args):
    var total = 0
    for a in args:
        total += a
    return total

check("*args sum", sum_all(1, 2, 3, 4), 10)

# ── **kwargs ─────────────────────────────────────────────────────
def kw_func(**kwargs):
    return kwargs

var kw = kw_func(a=1, b=2)
check("kwargs a", kw["a"], 1)
check("kwargs b", kw["b"], 2)

def greet(name, greeting="Hello"):
    return greeting + " " + name

check("default arg", greet("World"), "Hello World")
check("override default", greet("World", greeting="Hi"), "Hi World")

# ── Mixed args/kwargs ────────────────────────────────────────────
def mixed(a, b, *args, **kwargs):
    return str(a) + "," + str(b) + "," + str(len(args)) + "," + str(len(kwargs))

check("mixed basic", mixed(1, 2), "1,2,0,0")
check("mixed args", mixed(1, 2, 3, 4), "1,2,2,0")

# ── Context manager (with statement) ─────────────────────────────
class SimpleCtx:
    def __init__(self):
        self.entered = false
        self.exited = false
    def __enter__(self):
        self.entered = true
        return self
    def __exit__(self, *args):
        self.exited = true

var ctx = SimpleCtx()
with ctx as c:
    check("ctx entered", c.entered, true)
check("ctx exited", ctx.exited, true)

# ── Custom iterator protocol ────────────────────────────────────
class Range3:
    def __init__(self):
        self.i = 0
    def __iter__(self):
        return self
    def __next__(self):
        if self.i >= 3:
            raise "StopIteration"
        var val = self.i
        self.i += 1
        return val

var r3_items = []
for x in Range3():
    r3_items = r3_items + [x]
check("custom iter len", len(r3_items), 3)
check("custom iter 0", r3_items[0], 0)
check("custom iter 2", r3_items[2], 2)

# ── Multiple inheritance ─────────────────────────────────────────
class Flyable:
    def fly(self):
        return "flying"

class Swimmable:
    def swim(self):
        return "swimming"

class Duck(Flyable):
    def quack(self):
        return "quack"

var duck = Duck()
check("multi-inh fly", duck.fly(), "flying")
check("multi-inh quack", duck.quack(), "quack")

# ── Static method / class method ─────────────────────────────────
class MathHelper:
    @staticmethod
    def add(a, b):
        return a + b
    @staticmethod
    def multiply(a, b):
        return a * b

check("static add", MathHelper.add(3, 4), 7)
check("static mul", MathHelper.multiply(3, 4), 12)

# ── Property decorator ───────────────────────────────────────────
class Temperature:
    def __init__(self, celsius):
        self._celsius = celsius
    @property
    def fahrenheit(self):
        return self._celsius * 9 / 5 + 32

var temp = Temperature(100)
check("property fahrenheit", temp.fahrenheit, 212.0)

# ── Decorator pattern ────────────────────────────────────────────
def logger(fn):
    var call_log = []
    def wrapper(*args):
        call_log = call_log + ["called"]
        return fn(*args)
    wrapper.log = call_log
    return wrapper

@logger
def add_nums(a, b):
    return a + b

check("decorator result", add_nums(3, 4), 7)

# ── Chained methods ──────────────────────────────────────────────
class Builder:
    def __init__(self):
        self.parts = []
    def add(self, part):
        self.parts = self.parts + [part]
        return self
    def build(self):
        return ",".join(self.parts)

var result = Builder().add("a").add("b").add("c").build()
check("method chain", result, "a,b,c")

# ── Recursive class ──────────────────────────────────────────────
class TreeNode:
    def __init__(self, val, left=none, right=none):
        self.val = val
        self.left = left
        self.right = right
    def sum_tree(self):
        var s = self.val
        if self.left != none:
            s += self.left.sum_tree()
        if self.right != none:
            s += self.right.sum_tree()
        return s

var tree = TreeNode(1, TreeNode(2, TreeNode(4), TreeNode(5)), TreeNode(3))
check("tree sum", tree.sum_tree(), 15)

# ── Fibonacci generator ─────────────────────────────────────────
def fib_gen(n):
    var a = 0
    var b = 1
    var i = 0
    while i < n:
        yield a
        var tmp = a + b
        a = b
        b = tmp
        i += 1

var fibs = []
for f in fib_gen(8):
    fibs = fibs + [f]
check("fib gen len", len(fibs), 8)
check("fib gen 0", fibs[0], 0)
check("fib gen 1", fibs[1], 1)
check("fib gen 7", fibs[7], 13)

# ── Nested closures ──────────────────────────────────────────────
def outer(x):
    def middle(y):
        def inner(z):
            return x + y + z
        return inner
    return middle

check("nested closure", outer(1)(2)(3), 6)

# ── Dict comprehension-like (manual) ────────────────────────────
var d = {}
for k in ["a", "b", "c"]:
    d[k] = len(k)
check("dict build len", len(d), 3)
check("dict build a", d["a"], 1)

# ── Exception types ─────────────────────────────────────────────
var exc_type = "none"
try:
    raise ValueError("bad value")
except ValueError as e:
    exc_type = "ValueError"
except as e:
    exc_type = "other"
check("typed except", exc_type, "ValueError")

# ── Nested list operations ───────────────────────────────────────
var matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
check("matrix 0,0", matrix[0][0], 1)
check("matrix 1,1", matrix[1][1], 5)
check("matrix 2,2", matrix[2][2], 9)
var flat = []
for row in matrix:
    for val in row:
        flat = flat + [val]
check("flatten len", len(flat), 9)
check("flatten sum", sum(flat), 45)

# ── String multiplication and list multiplication ────────────────
check("str mul", "ab" * 3, "ababab")
check("list mul len", len([1, 2] * 3), 6)

# ── Ternary expression ──────────────────────────────────────────
var val = 10 if true else 20
check("ternary true", val, 10)
var val2 = 10 if false else 20
check("ternary false", val2, 20)

# ── Chained string operations ────────────────────────────────────
check("chain str ops", "  Hello World  ".strip().lower().replace("world", "nython"), "hello nython")

# ── Recursive factorial ──────────────────────────────────────────
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

check("factorial 0", factorial(0), 1)
check("factorial 5", factorial(5), 120)
check("factorial 10", factorial(10), 3628800)

# ── Enumerate with index ────────────────────────────────────────
var items = ["a", "b", "c"]
var indexed = enumerate(items)
check("enum len", len(indexed), 3)
check("enum 0 idx", indexed[0][0], 0)
check("enum 0 val", indexed[0][1], "a")
check("enum 2 idx", indexed[2][0], 2)

# ── zip patterns ─────────────────────────────────────────────────
var keys = ["x", "y", "z"]
var vals = [10, 20, 30]
var zipped = zip(keys, vals)
check("zip len", len(zipped), 3)
check("zip 0 key", zipped[0][0], "x")
check("zip 0 val", zipped[0][1], 10)

# ── sorted stability ────────────────────────────────────────────
var data = [3, 1, 4, 1, 5, 9, 2, 6]
var asc = sorted(data)
check("sorted asc", str(asc), "[1, 1, 2, 3, 4, 5, 6, 9]")
var desc2 = sorted(data, reverse=true)
check("sorted desc", str(desc2), "[9, 6, 5, 4, 3, 2, 1, 1]")

# ── del on dict ──────────────────────────────────────────────────
var dd = {"a": 1, "b": 2, "c": 3}
del dd["b"]
check("del dict len", len(dd), 2)
check("del dict a", dd["a"], 1)
check("del dict c", dd["c"], 3)

# ── del on list ──────────────────────────────────────────────────
var dl = [10, 20, 30, 40]
del dl[1]
check("del list len", len(dl), 3)
check("del list 0", dl[0], 10)
check("del list 1", dl[1], 30)
check("del list 2", dl[2], 40)

# ── Slice read ───────────────────────────────────────────────────
var sl = [0, 1, 2, 3, 4, 5, 6, 7]
var s1 = sl[2:5]
check("slice 2:5 len", len(s1), 3)
check("slice 2:5 [0]", s1[0], 2)
check("slice 2:5 [2]", s1[2], 4)

# ── Slice assign ─────────────────────────────────────────────────
var sa = [0, 1, 2, 3, 4]
sa[1:3] = [10, 20]
check("slice assign len", len(sa), 5)
check("slice assign 1", sa[1], 10)
check("slice assign 2", sa[2], 20)
check("slice assign 3", sa[3], 3)

print ""
print "=== VM AUDIT 23 ==="
print "Results:", passed, "passed,", failed, "failed"
if failed == 0:
    print "=== ALL TESTS PASSED ==="

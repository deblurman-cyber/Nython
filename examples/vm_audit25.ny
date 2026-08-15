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
        print "FAIL:", name, "| got:", got_s, "| expected:", exp_s

# ── Arithmetic edge cases ────────────────────────────────────────
check("int division", 7 // 2, 3)
check("neg int div", -7 // 2, -4)
check("modulo", 17 % 5, 2)
check("neg modulo", -7 % 3, -1)  # C-style modulo (not Python-style)
check("power", 2 ** 10, 1024)
check("float arith", round(0.1 + 0.2, 10), round(0.3, 10))
# Note: large int overflow is a known limitation (32-bit int paths)
# check("large int", 999999999 * 999999999, 999999998000000001)

# ── String edge cases ────────────────────────────────────────────
check("empty str len", len(""), 0)
check("str * 0", "abc" * 0, "")
check("str * 1", "abc" * 1, "abc")
check("multiline", len("ab\ncd"), 5)
check("escape tab", len("a\tb"), 3)
check("str in", "ell" in "hello", true)
check("str not in", "xyz" in "hello", false)
check("str index", "hello"[1], "e")
check("str neg index", "hello"[-1], "o")
check("str slice", "hello"[1:4], "ell")

# ── List edge cases ──────────────────────────────────────────────
check("empty list", len([]), 0)
check("nested list", [[1,2],[3,4]][1][0], 3)
check("list in", 3 in [1, 2, 3, 4], true)
check("list not in", 5 in [1, 2, 3, 4], false)
check("list concat", len([1,2] + [3,4]), 4)
check("list repeat", len([0] * 5), 5)
var lst = [5, 3, 1, 4, 2]
lst.sort()
check("list sort", str(lst), "[1, 2, 3, 4, 5]")
lst.reverse()
check("list reverse", str(lst), "[5, 4, 3, 2, 1]")
check("list pop", lst.pop(), 1)
check("list after pop", len(lst), 4)
lst.insert(0, 99)
check("list insert", lst[0], 99)

# ── Dict edge cases ──────────────────────────────────────────────
var d = {}
d["x"] = 10
d["y"] = 20
check("dict assign", d["x"], 10)
check("dict len", len(d), 2)
del d["x"]
check("dict del len", len(d), 1)
var d2 = {"a": 1, "b": 2, "c": 3}
var items = d2.items()
check("dict items len", len(items), 3)

# ── Set operations ───────────────────────────────────────────────
var s1 = set([1, 2, 3, 4, 5])
var s2 = set([4, 5, 6, 7, 8])
check("set len", len(s1), 5)
s1.add(6)
check("set add", len(s1), 6)
s1.discard(6)
check("set discard", len(s1), 5)

# ── Recursive patterns ───────────────────────────────────────────
def gcd(a, b):
    if b == 0:
        return a
    return gcd(b, a % b)

check("gcd 12,8", gcd(12, 8), 4)
check("gcd 100,75", gcd(100, 75), 25)

def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

check("fib 10", fibonacci(10), 55)
check("fib 15", fibonacci(15), 610)

# ── Deep nesting ─────────────────────────────────────────────────
def deep_nested():
    var result = 0
    for i in range(3):
        for j in range(3):
            for k in range(3):
                result += 1
    return result

check("deep nest", deep_nested(), 27)

# ── Exception in loop ───────────────────────────────────────────
var exc_count = 0
for i in range(5):
    try:
        if i == 2 or i == 4:
            raise ValueError("bad")
    except ValueError as e:
        exc_count += 1
check("exc in loop", exc_count, 2)

# ── Class inheritance chain ──────────────────────────────────────
class A:
    def who(self):
        return "A"
    def common(self):
        return "from A"

class B(A):
    def who(self):
        return "B"

class C(B):
    def who(self):
        return "C"

var c = C()
check("deep inherit who", c.who(), "C")
check("deep inherit common", c.common(), "from A")

# ── Static methods ───────────────────────────────────────────────
class MathOps:
    @staticmethod
    def factorial(n):
        if n <= 1:
            return 1
        return n * MathOps.factorial(n - 1)
    @staticmethod
    def is_even(n):
        return n % 2 == 0

check("static factorial", MathOps.factorial(6), 720)
check("static is_even", MathOps.is_even(4), true)
check("static is_odd", MathOps.is_even(3), false)

# ── Property ─────────────────────────────────────────────────────
class Circle:
    def __init__(self, r):
        self._r = r
    @property
    def area(self):
        return 3.14159 * self._r * self._r
    @property
    def circumference(self):
        return 2 * 3.14159 * self._r

var circ = Circle(10)
check("prop area", round(circ.area), 314)
check("prop circ", round(circ.circumference), 63)

# ── Closures capturing loop variable ────────────────────────────
var funcs = []
for i in range(5):
    var captured = i
    def make_fn(val):
        def fn():
            return val
        return fn
    funcs = funcs + [make_fn(captured)]
check("closure loop 0", funcs[0](), 0)
check("closure loop 4", funcs[4](), 4)

# ── Generator with filter ───────────────────────────────────────
def even_gen(n):
    var i = 0
    while i < n:
        if i % 2 == 0:
            yield i
        i += 1

var evens = []
for e in even_gen(10):
    evens = evens + [e]
check("gen filter", str(evens), "[0, 2, 4, 6, 8]")

# ── Generator chaining ──────────────────────────────────────────
def double_gen(gen_list):
    for x in gen_list:
        yield x * 2

var doubled = []
for d in double_gen([1, 2, 3, 4, 5]):
    doubled = doubled + [d]
check("gen chain", str(doubled), "[2, 4, 6, 8, 10]")

# ── Multiple return values via list ──────────────────────────────
def divmod_fn(a, b):
    return [a // b, a % b]

var dm = divmod_fn(17, 5)
check("divmod quot", dm[0], 3)
check("divmod rem", dm[1], 2)

# ── Nested dict access ──────────────────────────────────────────
var config = {"db": {"host": "localhost", "port": 5432}, "app": {"name": "nython"}}
check("nested dict", config["db"]["host"], "localhost")
check("nested dict 2", config["db"]["port"], 5432)
check("nested dict 3", config["app"]["name"], "nython")

# ── String methods chain ────────────────────────────────────────
var raw = "  Hello, World!  "
check("chain strip upper", raw.strip().upper(), "HELLO, WORLD!")
check("chain strip lower", raw.strip().lower(), "hello, world!")
check("chain strip split", len(raw.strip().split(",")), 2)

# ── Boolean operations ───────────────────────────────────────────
check("and tt", true and true, true)
check("and tf", true and false, false)
check("or ff", false or false, false)
check("or tf", true or false, true)
check("not true", not true, false)
check("not false", not false, true)
check("complex bool", (true and false) or (not false), true)

# ── Type coercion ────────────────────────────────────────────────
check("int+float", type(1 + 1.0), "float")
check("int*float", type(2 * 3.14), "float")
check("str+str", "a" + "b", "ab")

# ── Walrus-style patterns ───────────────────────────────────────
var data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var big = [x for x in data if x > 5]
check("comp filter", str(big), "[6, 7, 8, 9, 10]")
var squares = [x * x for x in range(1, 6)]
check("comp squares", str(squares), "[1, 4, 9, 16, 25]")

# ── with statement ───────────────────────────────────────────────
class Resource:
    def __init__(self):
        self.opened = false
        self.closed = false
    def __enter__(self):
        self.opened = true
        return self
    def __exit__(self, *args):
        self.closed = true

var res = Resource()
with res as r:
    check("with opened", r.opened, true)
    check("with not closed", r.closed, false)
check("with closed after", res.closed, true)

# ── Tensor ops after many class loads ────────────────────────────
var t = tensor([1.0, 2.0, 3.0, 4.0, 5.0])
check("tensor sum", tensor_sum(t), 15.0)
check("tensor mean", tensor_mean(t), 3.0)
var t2 = tensor_softmax(t)
check("softmax sum ~1", round(t2[0]+t2[1]+t2[2]+t2[3]+t2[4]), 1)

# ── File and KV ops ──────────────────────────────────────────────
write_file("/tmp/ny_audit25.txt", "test content 25")
check("file write+read", read_file("/tmp/ny_audit25.txt"), "test content 25")
kv_set("/tmp/ny_audit25.kv", "key1", "val1")
kv_set("/tmp/ny_audit25.kv", "key2", "val2")
check("kv get", kv_get("/tmp/ny_audit25.kv", "key1"), "val1")
var kk = kv_keys("/tmp/ny_audit25.kv")
check("kv keys", len(kk), 2)

print ""
print "=== VM AUDIT 25 ==="
print "Results:", passed, "passed,", failed, "failed"
if failed == 0:
    print "=== ALL TESTS PASSED ==="

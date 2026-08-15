# vm_audit27.ny — enumerate start=, *args/**kwargs, try/else, string methods,
#                  isinstance inheritance, __repr__, callable classes, dict.items,
#                  chained comparisons, lambda multi-arg, property patterns

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

print "=== VM AUDIT 27 ==="

# ── 1. enumerate with start= keyword arg ─────────────────────────────────────
section("enumerate start= kwarg")
var out = []
for i, v in enumerate(["a","b","c"], start=10):
    out = out + [i]
assert_eq("enum kw start[0]", out[0], 10)
assert_eq("enum kw start[1]", out[1], 11)
assert_eq("enum kw start[2]", out[2], 12)

# ── 2. enumerate with positional start ───────────────────────────────────────
section("enumerate positional start")
var out2 = []
for i, v in enumerate(["x","y","z"], 5):
    out2 = out2 + [i]
assert_eq("enum pos start[0]", out2[0], 5)
assert_eq("enum pos start[2]", out2[2], 7)

# ── 3. enumerate default (start=0) ───────────────────────────────────────────
section("enumerate default")
var out3 = []
for i, v in enumerate(["p","q","r"]):
    out3 = out3 + [i]
assert_eq("enum default[0]", out3[0], 0)
assert_eq("enum default[2]", out3[2], 2)

# ── 4. enumerate values preserved ────────────────────────────────────────────
section("enumerate values")
var vals = []
for i, v in enumerate(["hello","world"], start=1):
    vals = vals + [v]
assert_eq("enum val[0]", vals[0], "hello")
assert_eq("enum val[1]", vals[1], "world")

# ── 5. *args function ────────────────────────────────────────────────────────
section("*args function")
def vfn(*args):
    var total = 0
    for a in args:
        total = total + a
    return total
assert_eq("vfn 0 args", vfn(), 0)
assert_eq("vfn 3 args", vfn(1,2,3), 6)
assert_eq("vfn 5 args", vfn(1,2,3,4,5), 15)

# ── 6. **kwargs function ──────────────────────────────────────────────────────
section("**kwargs function")
def kfn(**kwargs):
    return kwargs["x"] + kwargs["y"]
assert_eq("kwargs sum", kfn(x=3, y=7), 10)
assert_eq("kwargs order", kfn(y=1, x=9), 10)

# ── 7. mixed *args + **kwargs ────────────────────────────────────────────────
section("*args + **kwargs mixed")
def mixed(a, b, *args, **kwargs):
    var extra = kwargs.get("extra", 0)
    return a + b + len(args) + extra
assert_eq("mixed basic", mixed(1,2), 3)
assert_eq("mixed varargs", mixed(1,2,10,20), 5)
assert_eq("mixed kwargs", mixed(1,2,10,20,extra=5), 10)

# ── 8. try/else ───────────────────────────────────────────────────────────────
section("try/else")
def safe_div(a, b):
    try:
        var r = a / b
    except:
        return -1
    else:
        return r
assert_eq("try/else success", safe_div(10, 2), 5.0)
assert_eq("try/else fail",    safe_div(10, 0), -1)

def safe_int(s):
    try:
        var n = int(s)
    except:
        return "bad"
    else:
        return n
assert_eq("try/else int ok",  safe_int("42"), 42)
assert_eq("try/else int bad", safe_int("abc"), "bad")

# ── 9. string .replace() ──────────────────────────────────────────────────────
section("string replace")
assert_eq("replace basic",   "hello".replace("l","r"), "herro")
assert_eq("replace all",     "aaa".replace("a","b"),   "bbb")
assert_eq("replace missing", "hello".replace("z","x"), "hello")

# ── 10. string .count() ───────────────────────────────────────────────────────
section("string count")
assert_eq("count basic",   "abcabc".count("a"),  2)
assert_eq("count single",  "hello".count("l"),   2)
assert_eq("count missing", "hello".count("z"),   0)

# ── 11. string join ───────────────────────────────────────────────────────────
section("string join")
assert_eq("join comma",  ",".join(["a","b","c"]), "a,b,c")
assert_eq("join empty",  "".join(["x","y"]),      "xy")
assert_eq("join space",  " ".join(["one","two"]), "one two")

# ── 12. isinstance with direct class ─────────────────────────────────────────
section("isinstance direct")
class Animal:
    def __init__(self, name):
        self.name = name

var a = Animal("cat")
assert_true("isinstance direct true",  isinstance(a, Animal))

# ── 13. isinstance with inheritance ──────────────────────────────────────────
section("isinstance inheritance")
class Dog(Animal):
    def __init__(self, name):
        Animal.__init__(self, name)
        self.species = "dog"

var d = Dog("rex")
assert_true("isinstance child class",  isinstance(d, Dog))
assert_true("isinstance parent class", isinstance(d, Animal))

# ── 14. __repr__ ──────────────────────────────────────────────────────────────
section("__repr__")
class Box:
    def __init__(self, v):
        self.v = v
    def __repr__(self):
        return "Box(" + str(self.v) + ")"
    def __str__(self):
        return "Box(" + str(self.v) + ")"

var bx = Box(42)
assert_eq("repr output", repr(bx), "Box(42)")
assert_eq("str output",  str(bx),  "Box(42)")

# ── 15. callable class (__call__) ────────────────────────────────────────────
section("callable class __call__")
class Multiplier:
    def __init__(self, factor):
        self.factor = factor
    def __call__(self, x):
        return x * self.factor

var double = Multiplier(2)
var triple = Multiplier(3)
assert_eq("call double", double(5),  10)
assert_eq("call triple", triple(5),  15)
assert_eq("call zero",   double(0),  0)

# ── 16. dict.items() iteration ───────────────────────────────────────────────
section("dict.items()")
var scores = {"alice": 90, "bob": 85, "carol": 92}
var total = 0
var count = 0
for k, v in scores.items():
    total = total + v
    count = count + 1
assert_eq("items total",  total, 267)
assert_eq("items count",  count, 3)

# ── 17. dict.keys() and dict.values() ────────────────────────────────────────
section("dict keys/values")
var d2 = {"x": 1, "y": 2, "z": 3}
var ks = list(d2.keys())
assert_eq("keys len",    len(ks), 3)
var vs = list(d2.values())
var vsum = 0
for v in vs:
    vsum = vsum + v
assert_eq("values sum",  vsum, 6)

# ── 18. chained comparison logic ─────────────────────────────────────────────
section("chained comparisons")
var n = 5
assert_true("1 < n and n < 10",  1 < n and n < 10)
assert_true("not 6 < n",         not (6 < n))
assert_true("n >= 5 and n <= 5", n >= 5 and n <= 5)
assert_true("n == 5",            n == 5)
assert_true("not n != 5",        not (n != 5))

# ── 19. lambda multi-arg ─────────────────────────────────────────────────────
section("lambda multi-arg")
var add  = lambda x, y: x + y
var mul  = lambda x, y: x * y
var clamp = lambda v, lo, hi: lo if v < lo else (hi if v > hi else v)
assert_eq("lambda add",   add(3, 4),        7)
assert_eq("lambda mul",   mul(3, 4),        12)
assert_eq("clamp lo",     clamp(-5, 0, 10), 0)
assert_eq("clamp hi",     clamp(15, 0, 10), 10)
assert_eq("clamp mid",    clamp(5, 0, 10),  5)

# ── 20. higher-order: map + filter combined ──────────────────────────────────
section("map+filter combined")
var nums = [1,2,3,4,5,6,7,8,9,10]
var evens = list(filter(lambda x: x % 2 == 0, nums))
var doubled = list(map(lambda x: x * 2, evens))
assert_eq("evens len",     len(evens),   5)
assert_eq("doubled[0]",    doubled[0],   4)
assert_eq("doubled[-1]",   doubled[4],   20)

# ── 21. class method chaining via return self ────────────────────────────────
section("method chaining")
class Builder:
    def __init__(self):
        self.parts = []
    def add(self, part):
        self.parts = self.parts + [part]
        return self
    def build(self):
        return ",".join(self.parts)

var b = Builder()
b.add("a")
b.add("b")
b.add("c")
assert_eq("builder result", b.build(), "a,b,c")

# ── 22. property-like pattern (computed attribute) ───────────────────────────
section("computed property pattern")
class Circle:
    def __init__(self, r):
        self.r = r
    def area(self):
        return 3.14159 * self.r * self.r
    def perimeter(self):
        return 2 * 3.14159 * self.r

var c = Circle(3)
assert_true("area positive",  c.area() > 0)
assert_true("area approx",    c.area() > 28 and c.area() < 29)
assert_true("perim approx",   c.perimeter() > 18 and c.perimeter() < 19)

# ── 23. sorted with key= ──────────────────────────────────────────────────────
section("sorted key=")
var words = ["banana","apple","cherry","date"]
var by_len = sorted(words, key=lambda w: len(w))
assert_eq("sorted by len[0]", by_len[0], "date")
assert_eq("sorted by len[1]", by_len[1], "apple")

var by_last = sorted(words, key=lambda w: w[len(w)-1])
assert_eq("sorted by last char[0]", by_last[0], "banana")

# ── 24. sorted reverse= ──────────────────────────────────────────────────────
section("sorted reverse=")
var nums2 = [3,1,4,1,5,9,2,6]
var desc = sorted(nums2, reverse=true)
assert_eq("sorted desc[0]", desc[0], 9)
assert_eq("sorted desc[1]", desc[1], 6)
var asc = sorted(nums2)
assert_eq("sorted asc[0]", asc[0], 1)

# ── 25. recursive function ───────────────────────────────────────────────────
section("recursive")
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)
assert_eq("fib(0)",  fib(0),  0)
assert_eq("fib(1)",  fib(1),  1)
assert_eq("fib(10)", fib(10), 55)

def flatten(lst):
    var result = []
    for item in lst:
        if isinstance(item, list):
            result = result + flatten(item)
        else:
            result = result + [item]
    return result

var nested = [1,[2,3],[4,[5,6]],7]
var flat = flatten(nested)
assert_eq("flatten len",  len(flat), 7)
assert_eq("flatten[0]",   flat[0],   1)
assert_eq("flatten[4]",   flat[4],   5)
assert_eq("flatten[6]",   flat[6],   7)

# ── 26. string formatting % ──────────────────────────────────────────────────
section("string % formatting")
assert_eq("str %s",    "hello %s" % "world",        "hello world")
assert_eq("str %d",    "value %d" % 42,             "value 42")
assert_eq("str multi", "%s=%d" % ("answer", 42),    "answer=42")

# ── 27. dict.get() with default ──────────────────────────────────────────────
section("dict.get() default")
var cfg = {"host": "localhost", "port": 8080}
assert_eq("get existing",   cfg.get("host", "none"),    "localhost")
assert_eq("get missing",    cfg.get("missing", "none"), "none")
assert_eq("get no default", cfg.get("port", 0),         8080)

# ── 28. in operator on collections ───────────────────────────────────────────
section("in operator")
var lst2 = [1,2,3,4,5]
assert_true("in list true",    3 in lst2)
assert_true("in list false",   not (9 in lst2))
var d3 = {"a":1,"b":2}
assert_true("in dict key",     "a" in d3)
assert_true("not in dict key", not ("z" in d3))
assert_true("in string",       "el" in "hello")
assert_true("not in string",   not ("zz" in "hello"))

# ── Report ────────────────────────────────────────────────────────────────────
print ""
if failed == 0:
    print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
    print "=== ALL TESTS PASSED ==="
else:
    print "Results: " + str(passed) + " passed, " + str(failed) + " failed"

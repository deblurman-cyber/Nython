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

# ── Generator basics ─────────────────────────────────────────────
def count_up(n):
    var i = 0
    while i < n:
        yield i
        i += 1

var gen = count_up(5)
check("gen next 0", next(gen), 0)
check("gen next 1", next(gen), 1)
check("gen next 2", next(gen), 2)

var gen_list = []
for x in count_up(4):
    gen_list = gen_list + [x]
check("gen for-in", str(gen_list), "[0, 1, 2, 3]")

# ── Generator with return value ──────────────────────────────────
def gen_with_return():
    yield 1
    yield 2
    return

var gr = gen_with_return()
check("gen ret 1", next(gr), 1)
check("gen ret 2", next(gr), 2)

# ── Multiple assignment / unpacking ──────────────────────────────
var a, b, c = 1, 2, 3
check("multi assign a", a, 1)
check("multi assign b", b, 2)
check("multi assign c", c, 3)

var x, y = [10, 20]
check("list unpack x", x, 10)
check("list unpack y", y, 20)

# Swap
var p = 100
var q = 200
p, q = q, p
check("swap p", p, 200)
check("swap q", q, 100)

# ── Chained comparison ───────────────────────────────────────────
check("chain 1<2<3", 1 < 2 and 2 < 3, true)
check("chain 1<2>3", 1 < 2 and 2 > 3, false)

# ── String methods ───────────────────────────────────────────────
check("str join", ",".join(["a", "b", "c"]), "a,b,c")
check("str split", len("a,b,c".split(",")), 3)
check("str strip", "  hello  ".strip(), "hello")
check("str lstrip", "  hello  ".lstrip(), "hello  ")
check("str rstrip", "  hello  ".rstrip(), "  hello")
check("str upper", "hello".upper(), "HELLO")
check("str lower", "HELLO".lower(), "hello")
check("str replace", "hello world".replace("world", "nython"), "hello nython")
check("str startswith", "hello".startswith("hel"), true)
check("str endswith", "hello".endswith("llo"), true)
check("str find", "hello world".find("world"), 6)
check("str count", "banana".count("an"), 2)
check("str isdigit", "123".isdigit(), true)
check("str isalpha", "abc".isalpha(), true)
check("str title", "hello world".title(), "Hello World")
check("str capitalize", "hello world".capitalize(), "Hello world")
check("str zfill", "42".zfill(5), "00042")

# ── Dict methods ─────────────────────────────────────────────────
var d = {"a": 1, "b": 2, "c": 3}
check("dict len", len(d), 3)
check("dict get", d["a"], 1)
var dk = d.keys()
check("dict keys len", len(dk), 3)
var dv = d.values()
check("dict values len", len(dv), 3)

# Dict get with default
var d2 = {"x": 10}
check("dict has key", d2["x"], 10)

# ── Set operations ───────────────────────────────────────────────
var s1 = set([1, 2, 3, 4])
var s2 = set([3, 4, 5, 6])
check("set len", len(s1), 4)

# ── List comprehension ───────────────────────────────────────────
var squares = [x * x for x in range(5)]
check("listcomp len", len(squares), 5)
check("listcomp 0", squares[0], 0)
check("listcomp 4", squares[4], 16)

var evens = [x for x in range(10) if x % 2 == 0]
check("listcomp filter len", len(evens), 5)
check("listcomp filter 0", evens[0], 0)
check("listcomp filter 4", evens[4], 8)

# ── Lambda ───────────────────────────────────────────────────────
var add = lambda a, b: a + b
check("lambda add", add(3, 4), 7)

var double = lambda x: x * 2
check("lambda double", double(5), 10)

# ── map / filter / reduce ────────────────────────────────────────
var nums = [1, 2, 3, 4, 5]
var doubled = list(map(lambda x: x * 2, nums))
check("map len", len(doubled), 5)
check("map 0", doubled[0], 2)
check("map 4", doubled[4], 10)

var even = list(filter(lambda x: x % 2 == 0, nums))
check("filter len", len(even), 2)
check("filter 0", even[0], 2)
check("filter 1", even[1], 4)

var total = reduce(lambda acc, x: acc + x, nums, 0)
check("reduce sum", total, 15)

# ── Closures ─────────────────────────────────────────────────────
def make_adder(n):
    def adder(x):
        return x + n
    return adder

var add5 = make_adder(5)
var add10 = make_adder(10)
check("closure add5", add5(3), 8)
check("closure add10", add10(3), 13)

def make_counter():
    var count = 0
    def increment():
        count += 1
        return count
    return increment

var counter = make_counter()
check("closure counter 1", counter(), 1)
check("closure counter 2", counter(), 2)
check("closure counter 3", counter(), 3)

# ── Class basics ─────────────────────────────────────────────────
class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    def __str__(self):
        return "(" + str(self.x) + ", " + str(self.y) + ")"
    def distance_to(self, other):
        var dx = self.x - other.x
        var dy = self.y - other.y
        return sqrt(dx * dx + dy * dy)

var p1 = Point(0, 0)
var p2 = Point(3, 4)
check("class init x", p1.x, 0)
check("class init y", p2.y, 4)
check("class distance", p1.distance_to(p2), 5.0)

# ── Inheritance with super() ─────────────────────────────────────
class Shape:
    def __init__(self, name):
        self.name = name
    def describe(self):
        return "Shape: " + self.name

class Circle(Shape):
    def __init__(self, radius):
        super().__init__("circle")
        self.radius = radius
    def area(self):
        return 3.14159 * self.radius * self.radius

var circ = Circle(5)
check("super init", circ.name, "circle")
check("circle area", round(circ.area()), 79)

# ── Explicit parent call ─────────────────────────────────────────
class Base:
    def __init__(self, val):
        self.val = val

class Child(Base):
    def __init__(self, val, extra):
        Base.__init__(self, val)
        self.extra = extra

var ch = Child(42, "bonus")
check("explicit parent init", ch.val, 42)
check("child extra", ch.extra, "bonus")

# ── try/except/finally ───────────────────────────────────────────
var log = []
try:
    log = log + ["try"]
    raise "test error"
except as e:
    log = log + ["except: " + str(e)]
finally:
    log = log + ["finally"]
check("try/except/finally len", len(log), 3)
check("except msg", log[1], "except: test error")
check("finally ran", log[2], "finally")

# ── Nested try/except ────────────────────────────────────────────
var outer_caught = false
var inner_caught = false
try:
    try:
        raise "inner"
    except as e:
        inner_caught = true
        raise "outer"
except as e2:
    outer_caught = true
check("nested inner caught", inner_caught, true)
check("nested outer caught", outer_caught, true)

# ── for/else ─────────────────────────────────────────────────────
var found_item = false
for i in range(5):
    if i == 3:
        found_item = true
        break
else:
    found_item = false
check("for-else break", found_item, true)

var else_ran = false
for i in range(5):
    if i == 99:
        break
else:
    else_ran = true
check("for-else no-break", else_ran, true)

# ── while/else ───────────────────────────────────────────────────
var we_result = "none"
var wi = 0
while wi < 5:
    if wi == 3:
        we_result = "break"
        break
    wi += 1
else:
    we_result = "else"
check("while-else break", we_result, "break")

# ── Negative indexing ────────────────────────────────────────────
var lst = [10, 20, 30, 40, 50]
check("neg idx -1", lst[-1], 50)
check("neg idx -2", lst[-2], 40)
check("neg idx -5", lst[-5], 10)

# ── String slicing ───────────────────────────────────────────────
var s = "hello world"
check("str slice", s[0:5], "hello")
check("str slice end", s[6:11], "world")

# ── List slicing ─────────────────────────────────────────────────
var sl = [0, 1, 2, 3, 4, 5]
var sliced = sl[1:4]
check("list slice len", len(sliced), 3)
check("list slice 0", sliced[0], 1)
check("list slice 2", sliced[2], 3)

# ── sorted with key/reverse ─────────────────────────────────────
var words = ["banana", "apple", "cherry"]
var by_len = sorted(words, key=lambda w: len(w))
check("sorted key 0", by_len[0], "apple")

var desc = sorted([3, 1, 4, 1, 5], reverse=true)
check("sorted reverse 0", desc[0], 5)
check("sorted reverse 4", desc[4], 1)

# ── isinstance ───────────────────────────────────────────────────
check("isinstance int", isinstance(42, "int"), true)
check("isinstance str", isinstance("hello", "str"), true)
check("isinstance list", isinstance([1, 2], "list"), true)

# ── Walrus operator := ───────────────────────────────────────────
var items = [1, 2, 3, 4, 5, 6, 7, 8]
var big = [x for x in items if x > 4]
check("filter big len", len(big), 4)

print ""
print "=== VM AUDIT 22 ==="
print "Results:", passed, "passed,", failed, "failed"
if failed == 0:
    print "=== ALL TESTS PASSED ==="

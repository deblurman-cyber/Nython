var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== NUMERIC SUFFIXES ==="
t("1k", 1k, 1000)
t("1K", 1K, 1000)
t("10k", 10k, 10000)
t("1.5k", 1.5k, 1500)
t("1M", int(1M), 1000000)
t("1G", int(1G), 1000000000)

print "=== MULTI-SYNTAX FUNCTIONS ==="
def f1(x): return x + 1
fn f2(x): return x + 2
func f3(x): return x + 3
function f4(x) { return x + 4 }
t("def", f1(10), 11)
t("fn", f2(10), 12)
t("func", f3(10), 13)
t("function", f4(10), 14)

print "=== CLASS INHERITANCE VARIANTS ==="
class Base:
    def init(self, v):
        self.v = v
    def get(self):
        return self.v

class Child1(Base):
    def init(self, v):
        super(v)
class Child2 extends Base:
    def init(self, v):
        super(v)
class Child3 inherits Base:
    def init(self, v):
        super(v)

t("parens", Child1(10).get(), 10)
t("extends", Child2(20).get(), 20)
t("inherits", Child3(30).get(), 30)

print "=== SUPER CHAIN ==="
class L1:
    def init(self):
        self.a = "L1"
class L2(L1):
    def init(self):
        super()
        self.b = "L2"
class L3(L2):
    def init(self):
        super()
        self.c = "L3"
class L4(L3):
    def init(self):
        super()
        self.d = "L4"
var deep = L4()
t("chain_a", deep.a, "L1")
t("chain_b", deep.b, "L2")
t("chain_c", deep.c, "L3")
t("chain_d", deep.d, "L4")

print "=== MULTIPLE INHERITANCE ==="
class Flyable:
    def fly(self):
        return "fly"
class Swimmable:
    def swim(self):
        return "swim"
class Duck(Flyable, Swimmable):
    def quack(self):
        return "quack"
var duck = Duck()
t("mi_fly", duck.fly(), "fly")
t("mi_swim", duck.swim(), "swim")
t("mi_quack", duck.quack(), "quack")

print "=== STATIC METHODS ==="
class MathUtil:
    def add(a, b):
        return a + b
    def mul(a, b):
        return a * b
    def square(x):
        return x * x
t("static_add", MathUtil.add(3, 4), 7)
t("static_mul", MathUtil.mul(3, 4), 12)
t("static_square", MathUtil.square(5), 25)

print "=== __str__ ==="
class Vec2:
    def init(self, x, y):
        self.x = x
        self.y = y
    def __str__(self):
        return "Vec2(" + str(self.x) + "," + str(self.y) + ")"
    def add(self, other):
        return Vec2(self.x + other.x, self.y + other.y)
    def length(self):
        return (self.x * self.x + self.y * self.y)

var v1 = Vec2(3, 4)
var v2 = Vec2(1, 2)
var v3 = v1.add(v2)
t("str_vec", str(v1), "Vec2(3,4)")
t("vec_add", str(v3), "Vec2(4,6)")
t("vec_len", v1.length(), 25)

print "=== THIS == SELF ==="
class Widget:
    def init(self, name):
        this.name = name
    def getName(self):
        return this.name
t("this_self", Widget("btn").getName(), "btn")

print "=== INTERFACE ==="
interface Drawable:
    def draw(self): pass
class Circle:
    def init(self, r):
        self.r = r
    def draw(self):
        return "circle r=" + str(self.r)
t("interface", Circle(5).draw(), "circle r=5")

print "=== LOOP/BLOCK/REPEAT ==="
var s1 = 0
var i = 0
loop:
    s1 = s1 + i; i = i + 1
    if i > 5: break
t("loop", s1, 15)

var bv = 0
block:
    bv = 99
t("block", bv, 99)

var rn = 1; var rf = 1
repeat:
    rf = rf * rn; rn = rn + 1
until rn > 6
t("repeat", rf, 720)

print "=== COLLECTIONS ==="
import collections
var words = "apple banana apple cherry banana apple".split(" ")
var wc = Counter(words)
t("counter_apple", wc["apple"], 3)
t("counter_banana", wc["banana"], 2)
t("counter_cherry", wc["cherry"], 1)

var unique = Set(words)
t("set_len", len(unique), 3)

var d = {"name": "Nython", "ver": "0.3"}
t("keys", str(sorted(d.keys())), "[name, ver]")
t("values", len(d.values()), 2)
t("items", len(d.items()), 2)

print "=== FOR K,V IN DICT ==="
var pairs = []
for k, v in {"x": 1, "y": 2}.items():
    pairs.append(k + "=" + str(v))
t("kv_len", len(pairs), 2)

print "=== LIST COMPREHENSION ==="
t("listcomp", str([x*x for x in range(1,6)]), "[1, 4, 9, 16, 25]")
t("filter", str([x for x in range(1,11) if x % 2 == 0]), "[2, 4, 6, 8, 10]")

print "=== DICT COMPREHENSION ==="
var dc = {str(k): k*k for k in range(1,4)}
t("dictcomp", dc["3"], 9)

print "=== F-STRINGS ==="
var lang = "Nython"
t("fstring", f"Hello {lang}!", "Hello Nython!")

print "=== CLOSURES ==="
def make_adder(n):
    def inner(x):
        return x + n
    return inner
var add5 = make_adder(5)
var add10 = make_adder(10)
t("closure_5", add5(3), 8)
t("closure_10", add10(3), 13)

print "=== HIGHER ORDER ==="
t("lambda_iife", (lambda x: x * x)(7), 49)
def apply(f, x): return f(x)
t("hof", apply(lambda x: x + 100, 42), 142)

print "=== CHAINED COMPARISON ==="
t("chain_true", 1 < 5 < 10, true)
t("chain_false", 1 < 15 < 10, false)

print "=== TERNARY ==="
t("ternary_t", "yes" if true else "no", "yes")
t("ternary_f", "yes" if false else "no", "no")

print "=== STRING OPS ==="
t("upper", "hello".upper(), "HELLO")
t("lower", "HELLO".lower(), "hello")
t("strip", "  hi  ".strip(), "hi")
t("split", len("a,b,c".split(",")), 3)
t("join", "-".join(["x", "y", "z"]), "x-y-z")
t("replace", "aabbcc".replace("bb", "XX"), "aaXXcc")
t("find", "abcdef".find("cd"), 2)
t("startswith", "nython".startswith("ny"), true)
t("endswith", "nython".endswith("on"), true)
t("contains", "hello world".contains("world"), true)
t("str_mul", "ab" * 3, "ababab")
t("neg_idx", "hello"[-1], "o")
t("slice", "hello world"[0:5], "hello")

print "=== BUILTINS ==="
t("abs", abs(-42), 42)
t("min_v", min(3, 1, 4, 1, 5), 1)
t("max_v", max(3, 1, 4, 1, 5), 5)
t("sum", sum([1,2,3,4,5]), 15)
t("len_str", len("hello"), 5)
t("len_list", len([1,2,3]), 3)
t("sorted", str(sorted([3,1,4,1,5])), "[1, 1, 3, 4, 5]")
t("reversed", str(reversed([1,2,3])), "[3, 2, 1]")
t("type_int", type(42), "int")
t("type_str", type("hi"), "string")
t("type_list", type([1,2,3]), "list")
t("isinstance", isinstance(42, "int"), true)
t("chr_ord", chr(65), "A")
t("ord_chr", ord("A"), 65)

print "=== ENUMERATE / ZIP ==="
var en = enumerate(["a", "b", "c"])
t("enum_len", len(en), 3)
var zp = zip([1,2,3], ["a","b","c"])
t("zip_len", len(zp), 3)

print "=== SWAP & MULTI-ASSIGN ==="
var sa = 10; var sb = 20
sa, sb = sb, sa
t("swap", str(sa) + "," + str(sb), "20,10")

print "=== DEFAULT PARAMS ==="
def greet(name, msg = "Hello"):
    return msg + " " + name
t("default", greet("World"), "Hello World")
t("override", greet("World", "Hi"), "Hi World")

print "=== METHOD CHAINING ==="
class Builder:
    def init(self):
        self.parts = []
    def add(self, p):
        self.parts.append(p)
        return self
    def build(self):
        return ",".join(self.parts)
t("chain", Builder().add("a").add("b").add("c").build(), "a,b,c")

print "=== ENUM ==="
enum Direction:
    NORTH = 0
    EAST = 1
    SOUTH = 2
    WEST = 3
t("enum_n", Direction.NORTH, 0)
t("enum_s", Direction.SOUTH, 2)

print "=== TRY/EXCEPT ==="
var caught = false
try:
    var x = 1 / 0
except:
    caught = true
t("try", caught, true)

print "=== DESIGN PATTERNS ==="
# Singleton pattern
class Singleton:
    def init(self):
        self.data = "singleton"
    def getData(self):
        return self.data

# Factory pattern
class ShapeFactory:
    def create(kind, size):
        if kind == "circle":
            return Circle(size)
        return none
var shape = ShapeFactory.create("circle", 10)
t("factory", shape.draw(), "circle r=10")

# Observer pattern
class EventBus:
    def init(self):
        self.handlers = []
    def on(self, handler):
        self.handlers.append(handler)
        return self
    def emit(self, data):
        var results = []
        for h in self.handlers:
            results.append(h(data))
        return results

var bus = EventBus()
bus.on(lambda x: x * 2)
bus.on(lambda x: x + 10)
var results = bus.emit(5)
t("observer_0", results[0], 10)
t("observer_1", results[1], 15)

print ""
print "============================================"
print "  V3 COMPREHENSIVE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

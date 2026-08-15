var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== MULTI-SYNTAX FUNCTIONS ==="
def f1(x):
    return x + 1
fn f2(x):
    return x + 2
func f3(x):
    return x + 3
function f4(x) { return x + 4 }
def f5:
    return 5
t("def", f1(10), 11)
t("fn", f2(10), 12)
t("func", f3(10), 13)
t("function", f4(10), 14)
t("def_noparens", f5(), 5)

print "=== LET/VAR/CONST ==="
let x = 42
t("let", x, 42)
var y = 100
t("var", y, 100)
const PI = 3.14159
t("const", PI, 3.14159)
let list = []
t("let_list", str(list), "[]")

print "=== NUMERIC SUFFIXES ==="
t("1k", 1k, 1000)
t("10k", 10k, 10000)
t("1.5k", 1.5k, 1500)
t("1M", int(1M), 1000000)
t("1G", int(1G), 1000000000)

print "=== CLASS SYNTAX VARIANTS ==="
class Animal:
    def init(self, name):
        self.name = name
class Dog(Animal):
    def init(self, name):
        super(name)
    def speak(self):
        return self.name + " barks"

class Cat extends Animal:
    def init(self, name):
        super(name)
    def speak(self):
        return self.name + " meows"

class Bird inherits Animal:
    def init(self, name):
        super(name)
    def speak(self):
        return self.name + " tweets"

t("parens_inherit", Dog("Rex").speak(), "Rex barks")
t("extends_inherit", Cat("Kit").speak(), "Kit meows")
t("inherits_keyword", Bird("Tweety").speak(), "Tweety tweets")

print "=== THIS == SELF ==="
class Widget:
    def init(self, val):
        this.val = val
    def get(self):
        return this.val
t("this_self", Widget(42).get(), 42)

print "=== SUPER CHAIN ==="
class L1:
    def init(self):
        self.a = 1
class L2(L1):
    def init(self):
        super()
        self.b = 2
class L3(L2):
    def init(self):
        super()
        self.c = 3
var deep = L3()
t("super_a", deep.a, 1)
t("super_b", deep.b, 2)
t("super_c", deep.c, 3)

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
    def square(x):
        return x * x
t("static_add", MathUtil.add(3, 4), 7)
t("static_sq", MathUtil.square(5), 25)

print "=== ABSTRACT + INTERFACE ==="
abstract class Shape:
    def area(self):
        return 0
class Rect(Shape):
    def init(self, w, h):
        self.w = w
        self.h = h
    def area(self):
        return self.w * self.h
t("abstract", Rect(3, 4).area(), 12)

interface Drawable:
    def draw(self):
        pass
class Circle:
    def init(self, r):
        self.r = r
    def draw(self):
        return "circle r=" + str(self.r)
t("interface", Circle(5).draw(), "circle r=5")

print "=== ENUM ==="
enum Direction:
    NORTH = 0
    EAST = 1
    SOUTH = 2
    WEST = 3
t("enum_n", Direction.NORTH, 0)
t("enum_w", Direction.WEST, 3)

print "=== CONTROL FLOW VARIANTS ==="
# while with colon
var w1 = 0
while w1 < 3:
    w1 = w1 + 1
t("while_colon", w1, 3)

# while with braces
var w2 = 0
while(w2 < 3) {
    w2 = w2 + 1
}
t("while_brace", w2, 3)

# while with do/end
var w3 = 0
while w3 < 3 do
    w3 = w3 + 1
end
t("while_doend", w3, 3)

# for with colon
var fs = 0
for x in range(1, 6):
    fs = fs + x
t("for_colon", fs, 15)

# for with braces
var fb = 0
for(x in range(1, 6)) {
    fb = fb + x
}
t("for_brace", fb, 15)

# if with colon
var ic = 0
if true:
    ic = 1
t("if_colon", ic, 1)

# if with braces
var ib = 0
if(true) {
    ib = 1
}
t("if_brace", ib, 1)

# if then end
var it = 0
if true then
    it = 1
end
t("if_then", it, 1)

# loop
var ln = 0
loop:
    ln = ln + 1
    if ln == 5:
        break
t("loop", ln, 5)

# block
var bv = 0
block:
    bv = 42
t("block_colon", bv, 42)

var bv2 = 0
block do
    bv2 = 99
end
t("block_do", bv2, 99)

var bv3 = 0
block {
    bv3 = 77
}
t("block_brace", bv3, 77)

# repeat/until
var rn = 1
var rf = 1
repeat:
    rf = rf * rn
    rn = rn + 1
until rn > 6
t("repeat", rf, 720)

print "=== LAMBDA & CLOSURES ==="
t("lambda_iife", (lambda x: x * x)(7), 49)

def make_adder(n):
    return lambda x: x + n
var add5 = make_adder(5)
var add10 = make_adder(10)
t("closure_5", add5(3), 8)
t("closure_10", add10(3), 13)

print "=== MAP/FILTER/REDUCE ==="
t("map", str(map(lambda x: x * 2, [1,2,3])), "[2, 4, 6]")
t("filter", str(filter(lambda x: x > 2, [1,2,3,4,5])), "[3, 4, 5]")
t("reduce", reduce(lambda a, b: a + b, [1,2,3,4,5]), 15)

print "=== COMPREHENSIONS ==="
t("listcomp", str([x*x for x in range(1,6)]), "[1, 4, 9, 16, 25]")
t("filter_comp", str([x for x in range(1,11) if x % 2 == 0]), "[2, 4, 6, 8, 10]")
var dc = {str(k): k*k for k in range(1,4)}
t("dictcomp", dc["3"], 9)

print "=== COLLECTIONS ==="
import collections
var words = "the quick brown fox the fox".split(" ")
var wc = Counter(words)
t("counter", wc["the"], 2)
var unique = Set(words)
t("set_len", len(unique), 4)

print "=== STRING OPS ==="
t("upper", "hello".upper(), "HELLO")
t("lower", "HELLO".lower(), "hello")
t("strip", "  hi  ".strip(), "hi")
t("split", len("a,b,c".split(",")), 3)
t("join", "-".join(["a","b","c"]), "a-b-c")
t("replace", "hello".replace("l", "r"), "herro")
t("startswith", "nython".startswith("ny"), true)
t("endswith", "nython".endswith("on"), true)
t("contains", "hello world".contains("world"), true)
t("str_mul", "ab" * 3, "ababab")
t("slice", "hello world"[0:5], "hello")

print "=== BUILTINS ==="
t("abs", abs(-42), 42)
t("min_v", min(3,1,4,1,5), 1)
t("max_v", max(3,1,4,1,5), 5)
t("sum", sum([1,2,3,4,5]), 15)
t("sorted", str(sorted([3,1,4,1,5])), "[1, 1, 3, 4, 5]")
t("reversed", str(reversed([1,2,3])), "[3, 2, 1]")
t("type_int", type(42), "int")
t("type_str", type("hi"), "string")
t("isinstance", isinstance(42, "int"), true)
t("chr_ord", chr(65), "A")

print "=== TERNARY ==="
t("ternary_t", "yes" if true else "no", "yes")
t("ternary_f", "yes" if false else "no", "no")
def fact(n):
    return n * fact(n - 1) if n > 1 else 1
t("fact5", fact(5), 120)

print "=== INCREMENT/COMPOUND ==="
var n = 5
n++
t("increment", n, 6)
n += 10
t("plus_eq", n, 16)

print "=== SWAP ==="
var sa = 10
var sb = 20
sa, sb = sb, sa
t("swap", str(sa) + "," + str(sb), "20,10")

print "=== CHAINED COMPARISON ==="
t("chain_t", 1 < 5 < 10, true)
t("chain_f", 1 < 15 < 10, false)

print "=== VARARGS ==="
def sum_all(*args):
    var total = 0
    for x in args:
        total = total + x
    return total
t("varargs", sum_all(1,2,3,4,5), 15)

print "=== F-STRINGS ==="
var lang = "Nython"
t("fstring", f"Hello {lang}!", "Hello Nython!")

print "=== DESIGN PATTERNS ==="
class Builder:
    def init(self):
        self.items = []
    def add(self, item):
        self.items.append(item)
        return self
    def build(self):
        return ",".join(self.items)
t("builder", Builder().add("a").add("b").add("c").build(), "a,b,c")

class EventBus:
    def init(self):
        self.handlers = []
    def on(self, h):
        self.handlers.append(h)
        return self
    def emit(self, val):
        var r = []
        for h in self.handlers:
            r.append(h(val))
        return r
var bus = EventBus()
bus.on(lambda x: x * 2).on(lambda x: x + 10)
var results = bus.emit(5)
t("observer_0", results[0], 10)
t("observer_1", results[1], 15)

print ""
print "============================================"
print "  SPEC COMPLIANCE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

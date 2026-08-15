var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== SUPER() ==="
class Animal:
    def init(self, name, legs):
        self.name = name
        self.legs = legs
class Dog(Animal):
    def init(self, name):
        super(name, 4)
        self.sound = "woof"
class Puppy(Dog):
    def init(self, name, color):
        super(name)
        self.color = color

var p = Puppy("Buddy", "brown")
t("super_name", p.name, "Buddy")
t("super_legs", p.legs, 4)
t("super_sound", p.sound, "woof")
t("super_color", p.color, "brown")

print "=== EXTENDS/INHERITS ==="
class Shape:
    def init(self):
        self.kind = "shape"
    def area(self):
        return 0

class Circle extends Shape:
    def init(self, r):
        self.kind = "circle"
        self.r = r
    def area(self):
        return 3.14159 * self.r * self.r

class Square inherits Shape:
    def init(self, side):
        self.kind = "square"
        self.side = side
    def area(self):
        return self.side * self.side

t("extends_area", int(Circle(10).area()), 314)
t("inherits_area", Square(5).area(), 25)

print "=== __str__ ==="
class Point:
    def init(self, x, y):
        self.x = x
        self.y = y
    def __str__(self):
        return "(" + str(self.x) + "," + str(self.y) + ")"

var pt = Point(3, 4)
t("str_method", str(pt), "(3,4)")
t("str_concat", "P=" + str(pt), "P=(3,4)")

print "=== METHOD CHAINING ==="
class Builder:
    def init(self):
        self.items = []
    def add(self, item):
        self.items.append(item)
        return self
    def build(self):
        return ", ".join(self.items)

t("chain", Builder().add("a").add("b").add("c").build(), "a, b, c")

print "=== POLYMORPHISM ==="
def describe(shape):
    return shape.kind + ":" + str(int(shape.area()))

var shapes = [Circle(5), Square(4)]
t("poly_0", describe(shapes[0]), "circle:78")
t("poly_1", describe(shapes[1]), "square:16")

print "=== fn/func/function ==="
fn add1(a, b): return a + b
func add2(a, b): return a + b
function add3(a, b): return a + b
def add4(a, b): return a + b
t("fn", add1(1, 2), 3)
t("func", add2(1, 2), 3)
t("function", add3(1, 2), 3)
t("def", add4(1, 2), 3)

print "=== LOOP ==="
var sum_loop = 0
var i = 1
loop:
    sum_loop = sum_loop + i
    i = i + 1
    if i > 10: break
t("loop", sum_loop, 55)

print "=== REPEAT/UNTIL ==="
var rn = 1
var fact = 1
repeat:
    fact = fact * rn
    rn = rn + 1
until rn > 5
t("repeat_fact", fact, 120)

print "=== BLOCK ==="
var bv = 0
block:
    bv = 42
t("block", bv, 42)

print "=== F-STRINGS ==="
var name = "Nython"
var ver = "0.3"
t("fstring", f"Hello {name} v{ver}!", "Hello Nython v0.3!")
var three = 1 + 2
t("fstring_expr", f"{three}", "3")

print "=== CLOSURES ==="
def make_counter(start):
    var count = start
    def increment():
        count = count + 1
        return count
    return increment

var c1 = make_counter(0)
t("closure1", c1(), 1)
t("closure2", c1(), 2)
t("closure3", c1(), 3)

print "=== HIGHER ORDER ==="
def apply(f, x): return f(x)
t("hof", apply(lambda x: x * x, 5), 25)

var items = [3, 1, 4, 1, 5, 9]
t("sorted", str(sorted(items)), "[1, 1, 3, 4, 5, 9]")
t("reversed", str(reversed([1, 2, 3])), "[3, 2, 1]")
t("sum", sum(items), 23)
t("min_list", min(items), 1)
t("max_list", max(items), 9)

print "=== ENUM ==="
enum Color:
    RED = 1
    GREEN = 2
    BLUE = 3
t("enum_red", Color.RED, 1)
t("enum_green", Color.GREEN, 2)
t("enum_blue", Color.BLUE, 3)

print "=== TRY/EXCEPT ==="
var caught = false
try:
    var x = 1 / 0
except:
    caught = true
t("try_catch", caught, true)

print ""
print "============================================"
print "  OOP v2: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

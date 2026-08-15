var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== KEYWORD ALIASES ==="
fn add_fn(a, b): return a + b
t("fn_keyword", add_fn(3, 4), 7)

func mul_func(a, b): return a * b
t("func_keyword", mul_func(3, 4), 12)

function div_function(a, b): return a / b
t("function_keyword", div_function(10, 2), 5)

def add_def(a, b): return a + b
t("def_keyword", add_def(5, 6), 11)

print "=== CLASS EXTENDS/INHERITS ==="
class Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name

class Dog extends Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " barks"

class Cat inherits Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " meows"

var d = Dog("Rex")
t("extends", d.speak(), "Rex barks")
var c = Cat("Whiskers")
t("inherits", c.speak(), "Whiskers meows")

class Shape:
    def init(self):
        self.kind = "shape"
    def area(self):
        return 0

class Circle(Shape):
    def init(self, r):
        self.r = r
        self.kind = "circle"
    def area(self):
        return 3.14159 * self.r * self.r

class Rectangle extends Shape:
    def init(self, w, h):
        self.w = w
        self.h = h
        self.kind = "rect"
    def area(self):
        return self.w * self.h

var ci = Circle(5)
t("circle_area", int(ci.area()), 78)
var re = Rectangle(4, 6)
t("rect_area", re.area(), 24)

print "=== LOOP STATEMENT ==="
var count = 0
loop:
    count = count + 1
    if count == 10: break
t("loop_break", count, 10)

print "=== BLOCK STATEMENT ==="
var bval = 0
block:
    bval = 42
t("block_exec", bval, 42)

print "=== REPEAT/UNTIL ==="
var rn = 5
var rsum = 0
repeat:
    rsum = rsum + rn
    rn = rn - 1
until rn == 0
t("repeat_until", rsum, 15)

print "=== MULTI-SYNTAX WHILE ==="
var w1 = 0
while w1 < 3:
    w1 = w1 + 1
t("while_colon", w1, 3)

var w2 = 0
while(w2 < 3) {
    w2 = w2 + 1
}
t("while_brace", w2, 3)

var w3 = 0
while w3 < 3 do
    w3 = w3 + 1
end
t("while_do_end", w3, 3)

print "=== MULTI-SYNTAX FOR ==="
var fsum = 0
for x in range(1, 6):
    fsum = fsum + x
t("for_colon", fsum, 15)

var fsum2 = 0
for(x in range(1, 6)) {
    fsum2 = fsum2 + x
}
t("for_brace", fsum2, 15)

print "=== MULTI-SYNTAX IF ==="
var ival = 0
if true:
    ival = 1
t("if_colon", ival, 1)

if(true) {
    ival = 2
}
t("if_brace", ival, 2)

print "=== LAMBDA ==="
var double_it = lambda x: x * 2
t("lambda_var", double_it(7), 14)

var result = (lambda x: x + 10)(5)
t("lambda_iife", result, 15)

var adder = lambda a, b: a + b
t("lambda_multi", adder(3, 4), 7)

print "=== TYPE INTROSPECTION ==="
t("type_int", type(42), "int")
t("type_str", type("hi"), "string")
t("type_list", type([1,2]), "list")
t("type_bool", type(true), "bool")
t("type_float", type(3.14), "float")
t("type_none", type(none), "none")
t("isinstance_int", isinstance(42, "int"), true)
t("isinstance_str", isinstance("x", "string"), true)

print "=== OOP: ENCAPSULATION ==="
class Counter:
    def init(self):
        self.value = 0
    def increment(self):
        self.value = self.value + 1
    def get(self):
        return self.value

var ctr = Counter()
ctr.increment()
ctr.increment()
ctr.increment()
t("counter", ctr.get(), 3)

print "=== OOP: COMPOSITION ==="
class Engine:
    def init(self, hp):
        self.hp = hp
    def describe(self):
        return str(self.hp) + "hp"

class Car:
    def init(self, name, hp):
        self.name = name
        self.engine = Engine(hp)
    def describe(self):
        return self.name + " with " + self.engine.describe()

var car = Car("Tesla", 670)
t("composition", car.describe(), "Tesla with 670hp")

print "=== OOP: POLYMORPHISM ==="
def describe_shape(s):
    return s.kind + ":" + str(int(s.area()))

t("poly_circle", describe_shape(ci), "circle:78")
t("poly_rect", describe_shape(re), "rect:24")

print "=== COLLECTIONS ==="
var nums = [1, 2, 3, 4, 5]
nums.append(6)
t("list_append", str(nums), "[1, 2, 3, 4, 5, 6]")
t("list_len", len(nums), 6)

var m = {"name": "Nython", "version": "0.3.0"}
t("map_access", m["name"], "Nython")
t("map_keys", len(m), 2)

var squares = [x*x for x in range(1,6)]
t("list_comp", str(squares), "[1, 4, 9, 16, 25]")

var filtered = [x for x in range(1,11) if x % 2 == 0]
t("list_filter", str(filtered), "[2, 4, 6, 8, 10]")

var dc = {str(k): k*k for k in range(1,4)}
t("dict_comp", dc["2"], 4)

print "=== SWAP & MULTI-ASSIGN ==="
var sa = 10
var sb = 20
sa, sb = sb, sa
t("swap", str(sa) + "," + str(sb), "20,10")

var p, q = 100, 200
t("multi_assign", str(p) + "," + str(q), "100,200")

print "=== DEFAULT PARAMS ==="
def greeting(name, msg = "Hello"):
    return msg + " " + name
t("default_used", greeting("World"), "Hello World")
t("default_override", greeting("World", "Hi"), "Hi World")

print "=== STRING OPS ==="
t("upper", "hello".upper(), "HELLO")
t("lower", "HELLO".lower(), "hello")
t("strip", "  hi  ".strip(), "hi")
t("split", str("a,b,c".split(",")), "[a, b, c]")
t("replace", "hello".replace("l", "r"), "herro")
t("join", "-".join(["a", "b", "c"]), "a-b-c")
t("startswith", "nython".startswith("ny"), true)
t("endswith", "nython".endswith("on"), true)
t("contains", "hello world".contains("world"), true)
t("find", "abcdef".find("cd"), 2)
t("slice", "hello world"[0:5], "hello")
t("neg_slice", "hello world"[-5:], "world")

print "=== BUILTINS ==="
t("abs", abs(-42), 42)
t("min", min(3, 1, 4, 1, 5), 1)
t("max", max(3, 1, 4, 1, 5), 5)
t("sum", sum([1, 2, 3, 4, 5]), 15)
t("sorted", str(sorted([3, 1, 4, 1, 5])), "[1, 1, 3, 4, 5]")
t("reversed", str(reversed([1, 2, 3])), "[3, 2, 1]")
t("enumerate_b", str(enumerate(["a", "b"])), "[[0, a], [1, b]]")
t("zip_b", str(zip([1, 2], [3, 4])), "[[1, 3], [2, 4]]")
t("chr_ord", chr(ord("A")), "A")

print ""
print "============================================"
print "  OOP SUITE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

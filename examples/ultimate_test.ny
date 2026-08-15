print "============================================="
print "  Nython v0.3.0 — Ultimate Comprehensive Test"
print "============================================="
import math

var pass_count = 0
var fail_count = 0

def test(name, actual, expected):
    if str(actual) == str(expected):
        pass_count = pass_count + 1
    else:
        fail_count = fail_count + 1
        print "FAIL: " + name + " | got: " + str(actual) + " expected: " + str(expected)

print ""
print "--- Types ---"
test("int type", type(42), "int")
test("float type", type(3.14), "float")
test("bool type", type(true), "bool")
test("string type", type("hi"), "string")
test("list type", type([1,2]), "list")
test("map type", type({"a":1}), "map")
test("none type", type(none), "none")

print ""
print "--- Arithmetic ---"
test("add", 2 + 3, 5)
test("sub", 10 - 4, 6)
test("mul", 6 * 7, 42)
test("div", 100 / 4, 25)
test("mod", 17 % 5, 2)
test("power int", 2 ** 10, 1024)
test("power float", 2.5 ** 2, 6.25)
test("precedence", 2 + 3 * 4, 14)

print ""
print "--- Strings ---"
test("concat", "hello" + " " + "world", "hello world")
test("repeat", "ha" * 3, "hahaha")
test("upper", "hello".upper(), "HELLO")
test("lower", "HELLO".lower(), "hello")
test("replace", "foo bar".replace("bar", "baz"), "foo baz")
test("find", "hello".find("ll"), 2)
test("startswith", "hello".startswith("hel"), true)
test("endswith", "hello".endswith("llo"), true)
test("split", str("a,b,c".split(",")), "[a, b, c]")
test("join", ", ".join(["x","y","z"]), "x, y, z")
test("strip", "  hi  ".strip(), "hi")
test("format", "Hello, {}!".format("World"), "Hello, World!")
test("capitalize", "hello".capitalize(), "Hello")
test("title", "hello world".title(), "Hello World")
test("contains", "hello".contains("ell"), true)
test("length", "hello".length(), 5)
test("charAt", "hello".charAt(1), "e")
test("substring", "hello".substring(1, 3), "ell")
test("reverse", "abc".reverse(), "cba")

print ""
print "--- Lists ---"
var lst = [5, 3, 8, 1, 9]
test("index", lst[2], 8)
test("neg index", lst[-1], 9)
test("len", len(lst), 5)
test("sort", str(lst.sort()), "[1, 3, 5, 8, 9]")
test("slice", str(lst.slice(1, 3)), "[3, 8]")
test("indexOf", lst.indexOf(8), 2)
test("contains", lst.contains(8), true)
test("join", lst.join("-"), "5-3-8-1-9")
test("reduce", [1,2,3,4,5].reduce(lambda a, b: a + b, 0), 15)
test("map", str([1,2,3].map(lambda x: x * 2)), "[2, 4, 6]")
test("filter", str([1,2,3,4,5].filter(lambda x: x > 3)), "[4, 5]")
test("chain", str([5,2,8,1].filter(lambda x: x > 2).map(lambda x: x * 10).sort()), "[50, 80]")
test("reverse", str([1,2,3].reverse()), "[3, 2, 1]")

print ""
print "--- Maps ---"
var m = {"name": "Nython", "ver": 3}
test("access", m["name"], "Nython")
test("size", m.size(), 2)
test("has_key", m.has_key("name"), true)
test("get default", m.get("missing", "N/A"), "N/A")

print ""
print "--- Functions ---"
def add(a, b):
    return a + b
test("basic fn", add(3, 4), 7)

def fib(n):
    if n < 2:
        return n
    return fib(n-1) + fib(n-2)
test("recursion", fib(10), 55)

def apply(func, x):
    return func(x)
def sq(x):
    return x * x
test("higher order", apply(sq, 6), 36)

print ""
print "--- Closures ---"
def counter(start):
    var n = start
    def inc():
        n = n + 1
        return n
    return inc
var c = counter(0)
c()
c()
test("mutable closure", c(), 3)

def multiplier(f):
    def m(x):
        return x * f
    return m
test("closure capture", multiplier(5)(7), 35)

print ""
print "--- Classes ---"
class Shape:
    def describe(self):
        return self.name + ": " + str(self.area())
class Circle(Shape):
    def init(self, r):
        self.name = "Circle"
        self.r = r
    def area(self):
        return PI * self.r * self.r
var circ = Circle(1)
test("class method", circ.area(), PI)
test("inheritance", circ.describe(), "Circle: " + str(PI))

print ""
print "--- Control Flow ---"
var result = ""
for i in range(1, 6):
    if i % 2 == 0:
        result = result + str(i) + " "
test("for+if", result.strip(), "2 4")

switch 2 {
case 1:
    result = "one"
case 2:
    result = "two"
}
test("switch", result, "two")

print ""
print "--- Error Handling ---"
var caught = ""
try:
    var x = 10 / 0
except e:
    caught = e
test("try/except", caught, "division by zero")

print ""
print "--- Builtins ---"
test("abs", abs(-42), 42)
test("min", min(3, 7), 3)
test("max", max(3, 7), 7)
test("pow", pow(2, 8), 256)
test("sqrt", sqrt(25), 5)
test("hex", hex(255), "0xff")
test("bin", bin(42), "0b101010")
test("chr", chr(65), "A")
test("ord", ord("A"), 65)
test("sorted", str(sorted([3,1,2])), "[1, 2, 3]")
test("reversed", str(reversed([1,2,3])), "[3, 2, 1]")

print ""
print "--- Conversions ---"
test("str int", str(42), "42")
test("str list", str([1,2,3]), "[1, 2, 3]")
test("str bool", str(true), "true")
test("int str", int("123"), 123)
test("float int", float(42), 42)
test("bool empty", bool(""), false)
test("bool zero", bool(0), false)
test("bool none", bool(none), false)
test("bool list", bool([]), false)

print ""
print "--- File IO ---"
import io
write_file("/tmp/nython_test.txt", "test data")
test("file exists", file_exists("/tmp/nython_test.txt"), true)
test("file read", read_file("/tmp/nython_test.txt"), "test data")

print ""
print "============================================="
print "  Results: " + str(pass_count) + " passed, " + str(fail_count) + " failed"
print "============================================="

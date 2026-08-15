var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== SWITCH/CASE ==="
def http_status(code):
    switch code:
        case 200:
            return "OK"
        case 404:
            return "Not Found"
        case 500:
            return "Server Error"
        default:
            return "Unknown"
t("switch_200", http_status(200), "OK")
t("switch_404", http_status(404), "Not Found")
t("switch_500", http_status(500), "Server Error")
t("switch_def", http_status(999), "Unknown")

print "=== NESTED STRUCTURES ==="
var config = {"db": {"host": "localhost", "port": 5432}, "debug": true}
t("nested_dict", config["db"]["host"], "localhost")
t("nested_port", config["db"]["port"], 5432)

print "=== OBJECT PIPELINES ==="
class Item:
    def init(self, name, price):
        self.name = name
        self.price = price
    def __str__(self):
        return self.name
var items = [Item("Apple", 1), Item("Banana", 2), Item("Cherry", 5)]
var total = reduce(lambda a, b: a + b.price, items, 0)
t("obj_reduce", total, 8)
var expensive = filter(lambda i: i.price > 1, items)
t("obj_filter", len(expensive), 2)

print "=== RECURSION ==="
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)
t("fib_10", fib(10), 55)
t("fib_20", fib(20), 6765)

print "=== CLASS HIERARCHY ==="
class Shape:
    def init(self):
        self.kind = "shape"
    def area(self):
        return 0
    def describe(self):
        return self.kind + ":" + str(self.area())
class Circle(Shape):
    def init(self, r):
        self.kind = "circle"
        self.r = r
    def area(self):
        return int(3.14159 * self.r * self.r)
class Rect(Shape):
    def init(self, w, h):
        self.kind = "rect"
        self.w = w
        self.h = h
    def area(self):
        return self.w * self.h
var shapes = [Circle(5), Rect(3, 4), Circle(10)]
var areas = map(lambda s: s.area(), shapes)
t("poly_areas", str(areas), "[78, 12, 314]")
t("poly_total", sum(areas), 404)

print "=== ERROR HANDLING ==="
def safe_div(a, b):
    try:
        return a / b
    except:
        return -1
t("safe_ok", safe_div(10, 2), 5)
t("safe_err", safe_div(10, 0), -1)

print "=== DICT METHODS ==="
var d = {"a": 1, "b": 2, "c": 3}
t("dict_get", d.get("a", 0), 1)
t("dict_getdef", d.get("z", 99), 99)
t("dict_pop", d.pop("c"), 3)
t("dict_poplen", len(d), 2)
d.update({"x": 10, "y": 20})
t("dict_update", len(d), 4)
t("dict_upval", d["x"], 10)

print "=== LIST METHODS ==="
var lst = [5, 3, 1, 4, 2]
lst.sort()
t("sort", str(lst), "[1, 2, 3, 4, 5]")
lst.reverse()
t("reverse", str(lst), "[5, 4, 3, 2, 1]")
var lst2 = [1, 2]
lst2.extend([3, 4])
t("extend", str(lst2), "[1, 2, 3, 4]")
t("pop_idx", lst2.pop(0), 1)
t("pop_last", lst2.pop(), 4)
t("pop_result", str(lst2), "[2, 3]")

print "=== CLOSURES ==="
def make_counter():
    var count = 0
    def inc():
        count = count + 1
        return count
    return inc
var c = make_counter()
c()
c()
t("counter", c(), 3)

def compose(f, g):
    return lambda x: f(g(x))
var double_then_add1 = compose(lambda x: x + 1, lambda x: x * 2)
t("compose", double_then_add1(5), 11)

print ""
print "============================================"
print "  V12 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

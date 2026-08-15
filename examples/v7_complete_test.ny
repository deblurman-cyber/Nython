var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== OPERATOR OVERLOADING ==="
class Vec:
    def init(self, x, y):
        self.x = x
        self.y = y
    def __add__(self, other):
        return Vec(self.x + other.x, self.y + other.y)
    def __sub__(self, other):
        return Vec(self.x - other.x, self.y - other.y)
    def __eq__(self, other):
        return self.x == other.x and self.y == other.y
    def __str__(self):
        return "(" + str(self.x) + "," + str(self.y) + ")"
    def __len__(self):
        return 2

var va = Vec(1, 2)
var vb = Vec(3, 4)
t("op_add", str(va + vb), "(4,6)")
t("op_sub", str(vb - va), "(2,2)")
t("op_eq_t", va == Vec(1, 2), true)
t("op_eq_f", va == vb, false)
t("op_len", len(va), 2)

print "=== GETITEM ==="
class MyList:
    def init(self, data):
        self.data = data
    def __getitem__(self, idx):
        return self.data[idx]
    def __len__(self):
        return len(self.data)
var ml = MyList([10, 20, 30])
t("getitem", ml[1], 20)
t("getitem_len", len(ml), 3)

print "=== MULTIPLE RETURN ==="
def minmax(lst):
    return min(lst), max(lst)
var lo, hi = minmax([3, 1, 4, 1, 5, 9])
t("ret_lo", lo, 1)
t("ret_hi", hi, 9)

print "=== DECORATOR ==="
def double_result(f):
    def wrapper(x):
        return f(x) * 2
    return wrapper

@double_result
def sq(x):
    return x * x
t("decorator", sq(5), 50)

print "=== FLOOR DIV + BITWISE ==="
t("fdiv", 7 // 2, 3)
t("fdiv_neg", -7 // 2, -4)
t("band", 12 & 10, 8)
t("bor", 12 | 10, 14)
t("bxor", 12 ^ 10, 6)
t("bnot", ~0, -1)

print "=== COMPOUND ASSIGN ==="
var cx = 3
cx **= 3
t("pow_eq", cx, 27)
cx //= 5
t("fdiv_eq", cx, 5)

print "=== BUILTINS ==="
t("divmod", str(divmod(17, 5)), "[3, 2]")
t("round2", round(3.14159, 2), 3.14)
t("all_t", all([1, 2, 3]), true)
t("any_t", any([0, 0, 1]), true)

print "=== CLOSURES ==="
def multiplier(n):
    return lambda x: x * n
var dbl = multiplier(2)
t("cl_dbl", dbl(7), 14)

print "=== STRATEGY ==="
class Calculator:
    def init(self):
        self.ops = {}
    def add_op(self, name, op):
        self.ops[name] = op
        return self
    def run(self, name, a, b):
        return self.ops[name](a, b)
var calc = Calculator()
calc.add_op("add", lambda a, b: a + b)
calc.add_op("mul", lambda a, b: a * b)
t("strat_add", calc.run("add", 3, 4), 7)
t("strat_mul", calc.run("mul", 3, 4), 12)

print "=== ENUM ==="
enum HTTP:
    OK = 200
    NOT_FOUND = 404
t("http_ok", HTTP.OK, 200)
t("http_404", HTTP.NOT_FOUND, 404)

print "=== CHAIN ==="
class Q:
    def init(self):
        self.p = []
    def add(self, s):
        self.p.append(s)
        return self
    def build(self):
        return " ".join(self.p)
t("chain", Q().add("a").add("b").add("c").build(), "a b c")

print "=== IMPORT ==="
import math
t("pi", PI > 3.14, true)
import collections
var wc = Counter("a b a a".split(" "))
t("counter", wc["a"], 3)

print ""
print "============================================"
print "  V7 COMPLETE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"


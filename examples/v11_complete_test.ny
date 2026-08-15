var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== LIST.EXTEND ==="
var a = [1, 2]
a.extend([3, 4, 5])
t("extend", str(a), "[1, 2, 3, 4, 5]")
t("extend_len", len(a), 5)

print "=== DICT.POP ==="
var d = {"a": 1, "b": 2, "c": 3}
t("pop_val", d.pop("b"), 2)
t("pop_len", len(d), 2)
t("pop_default", d.pop("missing", 99), 99)

print "=== DICT.UPDATE ==="
var d2 = {"x": 1}
d2.update({"y": 2, "z": 3})
t("update_len", len(d2), 3)
t("update_val", d2["y"], 2)

print "=== LIST.POP(INDEX) ==="
var lst = [10, 20, 30, 40]
t("pop_last", lst.pop(), 40)
t("pop_first", lst.pop(0), 10)
t("pop_result", str(lst), "[20, 30]")

print "=== __CONTAINS__ ==="
class Set2:
    def init(self, items):
        self.items = items
    def __contains__(self, v):
        return v in self.items
var s = Set2([10, 20, 30])
t("contains_t", 20 in s, true)
t("contains_f", 99 in s, false)

print "=== __SETITEM__ ==="
class Grid:
    def init(self):
        self.data = [0, 0, 0]
    def __getitem__(self, i):
        return self.data[i]
    def __setitem__(self, i, v):
        self.data[i] = v
    def __str__(self):
        return str(self.data)
var g = Grid()
g[1] = 42
t("setitem", g[1], 42)
t("setitem_str", str(g), "[0, 42, 0]")

print "=== COMPLEX PIPELINE ==="
var data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var evens_sq = sum(map(lambda x: x * x, filter(lambda x: x % 2 == 0, data)))
t("pipeline", evens_sq, 220)
var names = ["alice", "bob"]
var uppers = map(lambda s: s.upper(), names)
t("map_str", str(uppers), "[ALICE, BOB]")

print "=== WITH __enter__/__exit__ ==="
class Ctx:
    def init(self):
        self.state = "new"
    def __enter__(self):
        self.state = "entered"
        return self
    def __exit__(self):
        self.state = "exited"
var ctx = Ctx()
with ctx as c:
    t("with_enter", c.state, "entered")
t("with_exit", ctx.state, "exited")

print "=== INT CONVERSION ==="
t("int_hex", int("FF", 16), 255)
t("int_bin", int("1010", 2), 10)
t("int_oct", int("17", 8), 15)
t("int_auto", int("0xFF"), 255)

print "=== STRING CHAIN ==="
t("chain", "  Hello World  ".strip().lower().replace("world", "nython"), "hello nython")

print "=== INHERITANCE 3-LEVEL ==="
class A:
    def init(self, v):
        self.a = v
class B(A):
    def init(self, v, w):
        super(v)
        self.b = w
class C(B):
    def init(self, v, w, x):
        super(v, w)
        self.c = x
var obj = C(1, 2, 3)
t("inherit_a", obj.a, 1)
t("inherit_b", obj.b, 2)
t("inherit_c", obj.c, 3)

print ""
print "============================================"
print "  V11 COMPLETE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== DEEP EQUALITY ==="
t("eq_int", 1 === 1, true)
t("eq_str", "hi" === "hi", true)
t("eq_type", 1 === "1", false)
t("neq_t", 1 !== "1", true)
t("neq_f", 1 !== 1, false)

print "=== TYPEOF / SIZEOF ==="
t("typeof_int", typeof(42), "int")
t("typeof_str", typeof("hello"), "string")
t("sizeof_list", sizeof([1,2,3]), 3)

print "=== REF ==="
ref r = 100
t("ref", r, 100)

print "=== NUMBER FORMATS ==="
t("oct17", 0o17, 15)
t("oct10", 0o10, 8)
t("bin", 0b1010, 10)
t("hex", 0xFF, 255)
t("kilo", 1k, 1000)

print "=== OPERATOR OVERLOADING ==="
class Money:
    def init(self, v):
        self.v = v
    def __add__(self, o):
        return Money(self.v + o.v)
    def __eq__(self, o):
        return self.v == o.v
    def __str__(self):
        return str(self.v)
    def __len__(self):
        return self.v
    def __getitem__(self, k):
        return self.v
var ma = Money(100)
var mb = Money(50)
t("dunder_add", str(ma + mb), "150")
t("dunder_eq", ma == Money(100), true)
t("dunder_len", len(ma), 100)
t("dunder_get", ma["x"], 100)

print "=== LIST METHODS ==="
var lst = [5, 3, 1, 4, 2]
lst.sort()
t("sort", str(lst), "[1, 2, 3, 4, 5]")
lst.reverse()
t("reverse", str(lst), "[5, 4, 3, 2, 1]")
t("count", lst.count(3), 1)
lst.insert(0, 99)
t("insert", lst[0], 99)
lst.remove(99)
t("remove", lst[0], 5)
t("pop", lst.pop(), 1)
var cp = lst.copy()
lst.clear()
t("clear", len(lst), 0)
t("copy", len(cp), 4)

print "=== STRING METHODS ==="
t("center", "hi".center(6, "-"), "--hi--")
t("ljust", "hi".ljust(5, "."), "hi...")
t("rjust", "hi".rjust(5, "."), "...hi")
t("isalnum", "abc123".isalnum(), true)
t("isupper", "HELLO".isupper(), true)
t("islower", "hello".islower(), true)
t("isspace", "   ".isspace(), true)

print "=== MULTIPLE RETURN ==="
def bounds(lst):
    return min(lst), max(lst)
var lo, hi = bounds([7, 2, 9, 1, 5])
t("mret_lo", lo, 1)
t("mret_hi", hi, 9)

print "=== FUNCTIONAL ==="
var data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var result = reduce(lambda a, b: a + b, filter(lambda x: x % 2 == 0, map(lambda x: x * x, data)))
t("pipeline", result, 220)

print ""
print "============================================"
print "  V9 LEXER: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

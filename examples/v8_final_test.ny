var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== LIST METHODS ==="
var lst = [3, 1, 4, 1, 5, 9]
t("count", lst.count(1), 2)
t("index", lst.index(4), 2)
lst.insert(0, 99)
t("insert", lst[0], 99)
lst.remove(99)
t("remove", lst[0], 3)
t("pop", lst.pop(), 9)
t("pop_len", len(lst), 5)
var copy = lst.copy()
t("copy", str(copy), str(lst))
lst.clear()
t("clear", len(lst), 0)
t("copy_intact", len(copy), 5)
var sl = ["z", "a", "m"]
sl.sort()
t("sort_str", str(sl), "[a, m, z]")
sl.reverse()
t("reverse", str(sl), "[z, m, a]")
var nl = [3, 1, 4]
nl.sort()
t("sort_int", str(nl), "[1, 3, 4]")

print "=== STRING METHODS ==="
t("upper", "hello".upper(), "HELLO")
t("lower", "HELLO".lower(), "hello")
t("strip", "  hi  ".strip(), "hi")
t("lstrip", "  hi  ".lstrip(), "hi  ")
t("rstrip", "  hi  ".rstrip(), "  hi")
t("split", len("a,b,c".split(",")), 3)
t("join", "-".join(["x","y","z"]), "x-y-z")
t("replace", "aabb".replace("a","x"), "xxbb")
t("find", "abcdef".find("cd"), 2)
t("starts", "hello".startswith("he"), true)
t("ends", "hello".endswith("lo"), true)
t("contains", "hello".contains("ell"), true)
t("title", "hello world".title(), "Hello World")
t("capitalize", "hello world".capitalize(), "Hello world")
t("center", "hi".center(6, "-"), "--hi--")
t("ljust", "hi".ljust(5, "."), "hi...")
t("rjust", "hi".rjust(5, "."), "...hi")
t("count_s", "hello".count("l"), 2)
t("isalpha", "abc".isalpha(), true)
t("isdigit", "123".isdigit(), true)
t("isalnum", "abc123".isalnum(), true)
t("isupper", "HELLO".isupper(), true)
t("islower", "hello".islower(), true)
t("isspace", "   ".isspace(), true)
t("zfill", "42".zfill(5), "00042")
t("slice", "hello"[1:4], "ell")
t("neg_idx", "hello"[-1], "o")
t("str_mul", "ab" * 3, "ababab")
t("format", "Hello {}!".format("World"), "Hello World!")

print "=== OPERATOR OVERLOADING ==="
class Num:
    def init(self, v):
        self.v = v
    def __add__(self, other):
        return Num(self.v + other.v)
    def __sub__(self, other):
        return Num(self.v - other.v)
    def __mul__(self, other):
        return Num(self.v * other.v)
    def __eq__(self, other):
        return self.v == other.v
    def __lt__(self, other):
        return self.v < other.v
    def __str__(self):
        return str(self.v)
    def __len__(self):
        return 1

var na = Num(10)
var nb = Num(3)
t("dunder_add", str(na + nb), "13")
t("dunder_sub", str(na - nb), "7")
t("dunder_mul", str(na * nb), "30")
t("dunder_eq", na == Num(10), true)
t("dunder_lt", nb < na, true)
t("dunder_len", len(na), 1)

print "=== __getitem__ ==="
class Grid:
    def init(self, data):
        self.data = data
    def __getitem__(self, i):
        return self.data[i]
    def __len__(self):
        return len(self.data)
var g = Grid([10, 20, 30, 40])
t("grid_0", g[0], 10)
t("grid_2", g[2], 30)
t("grid_len", len(g), 4)

print "=== MULTIPLE RETURN ==="
def divmod_fn(a, b):
    return a // b, a % b
var q, r = divmod_fn(17, 5)
t("mret_q", q, 3)
t("mret_r", r, 2)

print "=== DECORATOR ==="
def double_it(f):
    def wrapper(x):
        return f(x) * 2
    return wrapper
@double_it
def sq(x):
    return x * x
t("decorator", sq(5), 50)

print "=== ALL OPERATORS ==="
t("fdiv", 7 // 2, 3)
t("pow", 2 ** 10, 1024)
t("band", 12 & 10, 8)
t("bor", 12 | 10, 14)
t("bxor", 12 ^ 10, 6)
t("bnot", ~0, -1)
t("lsh", 1 << 4, 16)
t("rsh", 16 >> 2, 4)
t("unary_p", +5, 5)
t("divmod_b", str(divmod(17, 5)), "[3, 2]")
t("round", round(3.14159, 2), 3.14)
t("all", all([1, 2, 3]), true)
t("any", any([0, 0, 1]), true)

print "=== COMPOUND ASSIGN ==="
var ca = 3
ca **= 3
t("ca_pow", ca, 27)
ca //= 5
t("ca_fdiv", ca, 5)
ca &= 7
t("ca_band", ca, 5)
ca |= 10
t("ca_bor", ca, 15)

print "=== PATTERNS ==="
class Stack:
    def init(self):
        self.items = []
    def push(self, item):
        self.items.append(item)
        return self
    def peek(self):
        return self.items[-1]
    def size(self):
        return len(self.items)
    def is_empty(self):
        return len(self.items) == 0
var s = Stack()
s.push(1).push(2).push(3)
t("stack_peek", s.peek(), 3)
t("stack_size", s.size(), 3)

print "=== FUNCTIONAL ==="
var nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var evens = filter(lambda x: x % 2 == 0, nums)
var squares = map(lambda x: x * x, evens)
var total = reduce(lambda a, b: a + b, squares)
t("pipeline", total, 220)

print ""
print "============================================"
print "  V8 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

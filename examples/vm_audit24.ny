import nytorch

var passed = 0
var failed = 0

def check(name, got, expected):
    var got_s = str(got)
    var exp_s = str(expected)
    if got_s == exp_s:
        passed += 1
    else:
        failed += 1
        print "FAIL:", name, "| got:", got_s, "| expected:", exp_s

# ── Generator: collect all values ────────────────────────────────
def range_gen(n):
    var i = 0
    while i < n:
        yield i
        i += 1

var items = []
for x in range_gen(5):
    items = items + [x]
check("gen collect", str(items), "[0, 1, 2, 3, 4]")

# ── Generator: next() calls ─────────────────────────────────────
var g = range_gen(3)
check("gen next 0", next(g), 0)
check("gen next 1", next(g), 1)
check("gen next 2", next(g), 2)

# ── Generator: fibonacci ─────────────────────────────────────────
def fib(limit):
    var a = 0
    var b = 1
    while a < limit:
        yield a
        var tmp = a + b
        a = b
        b = tmp

var fibs = []
for f in fib(50):
    fibs = fibs + [f]
check("fib count", len(fibs), 10)
check("fib last", fibs[9], 34)

# ── Nested functions with state ──────────────────────────────────
def make_accumulator(initial):
    var total = initial
    def add(n):
        total += n
        return total
    def get():
        return total
    return [add, get]

var acc = make_accumulator(0)
var add_fn = acc[0]
var get_fn = acc[1]
check("acc add 10", add_fn(10), 10)
check("acc add 20", add_fn(20), 30)
check("acc get", get_fn(), 30)

# ── Higher-order: compose ────────────────────────────────────────
def compose(f, g):
    def composed(x):
        return f(g(x))
    return composed

def double(x):
    return x * 2
def inc(x):
    return x + 1

var double_then_inc = compose(inc, double)
var inc_then_double = compose(double, inc)
check("compose d+i", double_then_inc(5), 11)
check("compose i+d", inc_then_double(5), 12)

# ── Class with __str__ and __repr__ ──────────────────────────────
class Vec2:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    def __str__(self):
        return "Vec2(" + str(self.x) + ", " + str(self.y) + ")"
    def __add__(self, other):
        return Vec2(self.x + other.x, self.y + other.y)
    def __mul__(self, scalar):
        return Vec2(self.x * scalar, self.y * scalar)
    def mag(self):
        return sqrt(self.x * self.x + self.y * self.y)

var v1 = Vec2(3, 4)
check("vec str", str(v1), "Vec2(3, 4)")
check("vec mag", v1.mag(), 5.0)
var v2 = Vec2(1, 2)
var v3 = v1 + v2
check("vec add x", v3.x, 4)
check("vec add y", v3.y, 6)

# ── Class with __getitem__/__setitem__ ───────────────────────────
class Matrix:
    def __init__(self, rows, cols):
        self.rows = rows
        self.cols = cols
        self.data = []
        var i = 0
        while i < rows * cols:
            self.data = self.data + [0]
            i += 1
    def __getitem__(self, idx):
        return self.data[idx]
    def __setitem__(self, idx, val):
        self.data[idx] = val
    def get(self, r, c):
        return self.data[r * self.cols + c]
    def set(self, r, c, val):
        self.data[r * self.cols + c] = val

var m = Matrix(3, 3)
m.set(0, 0, 1)
m.set(1, 1, 5)
m.set(2, 2, 9)
check("matrix get 0,0", m.get(0, 0), 1)
check("matrix get 1,1", m.get(1, 1), 5)
check("matrix get 2,2", m.get(2, 2), 9)
check("matrix getitem", m[4], 5)

# ── Decorator with arguments ─────────────────────────────────────
def repeat_decorator(n):
    def decorator(fn):
        def wrapper(*args):
            var result = none
            var i = 0
            while i < n:
                result = fn(*args)
                i += 1
            return result
        return wrapper
    return decorator

var call_count = 0
@repeat_decorator(3)
def tracked():
    call_count += 1
    return call_count

var final = tracked()
check("repeat deco", final, 3)

# ── Multiple except clauses ──────────────────────────────────────
def test_typed_except(val):
    try:
        if val == 0:
            raise ValueError("zero")
        if val < 0:
            raise TypeError("negative")
        return "ok"
    except ValueError as e:
        return "value_err"
    except TypeError as e:
        return "type_err"
    except as e:
        return "other"

check("typed except val", test_typed_except(0), "value_err")
check("typed except type", test_typed_except(-1), "type_err")
check("typed except ok", test_typed_except(1), "ok")

# ── Recursive data structures ────────────────────────────────────
class LinkedList:
    def __init__(self):
        self.head = none
    def push(self, val):
        self.head = [val, self.head]
    def to_list(self):
        var result = []
        var node = self.head
        while node != none:
            result = result + [node[0]]
            node = node[1]
        return result

var ll = LinkedList()
ll.push(3)
ll.push(2)
ll.push(1)
check("linked list", str(ll.to_list()), "[1, 2, 3]")

# ── Dict iteration ──────────────────────────────────────────────
var d = {"a": 1, "b": 2, "c": 3}
var dk = d.keys()
check("dict keys len", len(dk), 3)
var dv = d.values()
check("dict values len", len(dv), 3)
var di = d.items()
check("dict items len", len(di), 3)

# ── String formatting ───────────────────────────────────────────
var name = "Nython"
var ver = 2
var msg = "${name} v${ver}"
check("str interp", msg, "Nython v2")

# ── Chained comparisons via and ──────────────────────────────────
var x = 5
check("chain cmp true", 1 < x and x < 10, true)
check("chain cmp false", 1 < x and x < 3, false)

# ── Nested list comprehension ────────────────────────────────────
var flat = [x * y for x in range(1, 4) for y in range(1, 4)]
check("nested comp len", len(flat), 9)
check("nested comp 0", flat[0], 1)
check("nested comp 4", flat[4], 4)
check("nested comp 8", flat[8], 9)

# ── Sorted with key function ────────────────────────────────────
var words = ["banana", "apple", "cherry", "date"]
var by_len = sorted(words, key=lambda w: len(w))
check("sorted key 0", by_len[0], "date")
check("sorted key 3", by_len[3], "cherry")

# ── map/filter/reduce ───────────────────────────────────────────
var nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var evens = list(filter(lambda x: x % 2 == 0, nums))
check("filter evens", str(evens), "[2, 4, 6, 8, 10]")

var squares = list(map(lambda x: x * x, evens))
check("map squares", str(squares), "[4, 16, 36, 64, 100]")

var total = reduce(lambda a, b: a + b, squares, 0)
check("reduce sum squares", total, 220)

# ── while with complex condition ─────────────────────────────────
var count = 0
var sum_val = 0
while count < 10 and sum_val < 25:
    count += 1
    sum_val += count
check("while complex count", count, 7)

# ── Ternary in expressions ──────────────────────────────────────
var items2 = [1, 2, 3, 4, 5]
var labels = list(map(lambda x: "even" if x % 2 == 0 else "odd", items2))
check("ternary map 0", labels[0], "odd")
check("ternary map 1", labels[1], "even")

# ── Tensor operations ───────────────────────────────────────────
var t1 = tensor([1.0, 2.0, 3.0])
var t2 = tensor([4.0, 5.0, 6.0])
check("tensor add", tensor_add(t1, t2)[0], 5.0)
check("tensor dot", tensor_dot(t1, t2), 32.0)
check("tensor sum", tensor_sum(t1), 6.0)
check("tensor mean", tensor_mean(t1), 2.0)

# ── KV store ─────────────────────────────────────────────────────
kv_set("/tmp/ny_audit24.kv", "test_key", "test_value")
var kv_val = kv_get("/tmp/ny_audit24.kv", "test_key")
check("kv roundtrip", kv_val, "test_value")
kv_del("/tmp/ny_audit24.kv", "test_key")
var kv_del_val = kv_get("/tmp/ny_audit24.kv", "test_key")
check("kv deleted", kv_del_val, "none")

# ── File I/O ─────────────────────────────────────────────────────
write_file("/tmp/ny_audit24.txt", "hello nython")
var content = read_file("/tmp/ny_audit24.txt")
check("file roundtrip", content, "hello nython")

print ""
print "=== VM AUDIT 24 ==="
print "Results:", passed, "passed,", failed, "failed"
if failed == 0:
    print "=== ALL TESTS PASSED ==="

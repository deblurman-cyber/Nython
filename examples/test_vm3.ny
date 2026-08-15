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

# ── Generators ──────────────────────────────────────────────────
def range_gen(n):
    var i = 0
    while i < n:
        yield i
        i += 1

var gen_vals = []
for v in range_gen(5):
    gen_vals = gen_vals + [v]
check("generator range", gen_vals, [0, 1, 2, 3, 4])

def fibonacci_gen(limit):
    var a = 0
    var b = 1
    while a <= limit:
        yield a
        var tmp = a + b
        a = b
        b = tmp

var fibs = []
for v in fibonacci_gen(20):
    fibs = fibs + [v]
check("fib gen", fibs, [0, 1, 1, 2, 3, 5, 8, 13])

# ── Chained string operations ────────────────────────────────────
var sentence = "  The Quick Brown Fox  "
check("chain strip+lower", sentence.strip().lower(), "the quick brown fox")
check("chain split+len", len("a,b,c,d".split(",")), 4)

# ── Functional patterns ──────────────────────────────────────────
def apply(fn, lst):
    var result = []
    for x in lst:
        result = result + [fn(x)]
    return result

def square(x):
    return x * x

def is_even(x):
    return x % 2 == 0

var squares = apply(square, [1, 2, 3, 4, 5])
check("map-like", squares, [1, 4, 9, 16, 25])

def filter_fn(pred, lst):
    var result = []
    for x in lst:
        if pred(x):
            result = result + [x]
    return result

var evens = filter_fn(is_even, [1, 2, 3, 4, 5, 6, 7, 8])
check("filter-like", evens, [2, 4, 6, 8])

def reduce_fn(fn, lst, init):
    var acc = init
    for x in lst:
        acc = fn(acc, x)
    return acc

def add(a, b):
    return a + b

def mul(a, b):
    return a * b

check("reduce sum", reduce_fn(add, [1,2,3,4,5], 0), 15)
check("reduce product", reduce_fn(mul, [1,2,3,4,5], 1), 120)

# ── Memoization with dict ────────────────────────────────────────
var memo = {}
def fib_memo(n):
    var key = str(n)
    if key in memo:
        return memo[key]
    if n <= 1:
        memo[key] = n
        return n
    var result = fib_memo(n-1) + fib_memo(n-2)
    memo[key] = result
    return result

check("fib_memo(30)", fib_memo(30), 832040)
check("fib_memo(20)", fib_memo(20), 6765)

# ── Class with operator overloading ─────────────────────────────
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    def add(self, other):
        return Vector(self.x + other.x, self.y + other.y)
    def scale(self, s):
        return Vector(self.x * s, self.y * s)
    def magnitude(self):
        return sqrt(self.x * self.x + self.y * self.y)
    def dot(self, other):
        return self.x * other.x + self.y * other.y

var v1 = Vector(3, 4)
var v2 = Vector(1, 2)
check("vector magnitude", v1.magnitude(), 5.0)
check("vector dot", v1.dot(v2), 11)
var v3 = v1.add(v2)
check("vector add x", v3.x, 4)
check("vector add y", v3.y, 6)
var v4 = v1.scale(2)
check("vector scale x", v4.x, 6)
check("vector scale y", v4.y, 8)

# ── Context with nested class ────────────────────────────────────
class Stack:
    def __init__(self):
        self.items = []
    def push(self, x):
        self.items = self.items + [x]
    def pop(self):
        if len(self.items) == 0:
            return none
        var v = self.items[len(self.items) - 1]
        self.items = self.items.slice(0, len(self.items) - 1)
        return v
    def peek(self):
        if len(self.items) == 0:
            return none
        return self.items[len(self.items) - 1]
    def size(self):
        return len(self.items)
    def is_empty(self):
        return len(self.items) == 0

var stk = Stack()
check("stack empty", stk.is_empty(), true)
stk.push(10)
stk.push(20)
stk.push(30)
check("stack size", stk.size(), 3)
check("stack peek", stk.peek(), 30)
check("stack pop", stk.pop(), 30)
check("stack size after pop", stk.size(), 2)

# ── Exception propagation chain ──────────────────────────────────
def level3():
    raise "deep error"

def level2():
    level3()

def level1():
    try:
        level2()
    except as e:
        return "caught: " + e

check("exception chain", level1(), "caught: deep error")

# ── Global counter pattern ────────────────────────────────────────
var call_count = 0
def counted(fn):
    def wrapper(x):
        global call_count
        call_count += 1
        return fn(x)
    return wrapper

var counted_square = counted(square)
counted_square(3)
counted_square(5)
counted_square(7)
check("global counter", call_count, 3)

# ── List as queue ────────────────────────────────────────────────
var queue = []
queue = queue + [1]
queue = queue + [2]
queue = queue + [3]
var front = queue[0]
queue = queue.slice(1, len(queue))
check("queue front", front, 1)
check("queue remaining", queue, [2, 3])

# ── String interpolation patterns ────────────────────────────────
def format_name(first, last, title):
    return title + " " + first + " " + last

check("format name", format_name("John", "Doe", "Dr."), "Dr. John Doe")

var items = ["apple", "banana", "cherry"]
var formatted = ""
for i in range(len(items)):
    if i > 0:
        formatted = formatted + ", "
    formatted = formatted + str(i+1) + ". " + items[i]
check("indexed format", formatted, "1. apple, 2. banana, 3. cherry")

print ""
print "Results:", passed, "passed,", failed, "failed"

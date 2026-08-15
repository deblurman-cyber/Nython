# test_vm.ny — Comprehensive VM bytecode execution test
print("=== Nython VM Test Suite ===")

# 1. Basic arithmetic
var a = 10
var b = 3
print("ADD:      " + str(a + b))       # 13
print("SUB:      " + str(a - b))       # 7
print("MUL:      " + str(a * b))       # 30
print("DIV:      " + str(a / b))       # 3.333...
print("MOD:      " + str(a % b))       # 1
print("POW:      " + str(2 ** 8))      # 256
print("FLOORDIV: " + str(a // b))      # 3

# 2. Comparisons
print("EQ:  " + str(5 == 5))    # true
print("NE:  " + str(5 != 3))    # true
print("LT:  " + str(2 < 5))     # true
print("GT:  " + str(5 > 2))     # true
print("GE:  " + str(5 >= 5))    # true

# 3. Booleans / logic
print("AND: " + str(true and false))   # false
print("OR:  " + str(true or false))    # true
print("NOT: " + str(not true))         # false

# 4. Strings
var s = "Hello"
print("UPPER:   " + s.upper())
print("LOWER:   " + s.lower())
print("LEN:     " + str(len(s)))
print("CONCAT:  " + s + " World")
print("REPEAT:  " + s * 2)

# 5. Lists
var lst = [10, 20, 30, 40, 50]
print("LIST:    " + str(lst))
print("IDX:     " + str(lst[2]))
print("LEN:     " + str(len(lst)))

# 6. If/elif/else
var x = 42
if x > 100:
    print("BIG")
elif x > 40:
    print("MEDIUM")  # expected
else:
    print("SMALL")

# 7. While loop
var i = 0
var total = 0
while i < 5:
    total = total + i
    i = i + 1
print("WHILE SUM: " + str(total))   # 10

# 8. For loop
var acc = 0
for n in range(1, 6):
    acc = acc + n
print("FOR SUM: " + str(acc))       # 15

# 9. Functions
def add(x, y):
    return x + y

def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print("ADD FN:  " + str(add(7, 8)))          # 15
print("FACT(7): " + str(factorial(7)))       # 5040

# 10. Closures / nested
def make_adder(n):
    def adder(x):
        return x + n
    return adder

var add5 = make_adder(5)
print("CLOSURE: " + str(add5(10)))           # 15

# 11. Class
class Counter:
    def __init__(self):
        self.value = 0
    def increment(self):
        self.value = self.value + 1
    def get(self):
        return self.value

var c = Counter()
c.increment()
c.increment()
c.increment()
print("CLASS:   " + str(c.get()))            # 3

# 12. Builtins
print("ABS:     " + str(abs(-42)))           # 42
print("MIN:     " + str(min(3, 1, 4, 1)))    # 1
print("MAX:     " + str(max(3, 1, 4, 1)))    # 4
print("SUM:     " + str(sum([1,2,3,4,5])))   # 15
print("RANGE:   " + str(list(range(5))))     # [0, 1, 2, 3, 4]

# 13. String methods
var sentence = "hello world foo"
print("SPLIT:   " + str(sentence.split(" ")))
print("UPPER:   " + sentence.upper())
print("REPLACE: " + sentence.replace("foo", "bar"))
print("FIND:    " + str(sentence.find("world")))
print("STARTS:  " + str(sentence.startswith("hello")))

# 14. List methods
var nums = [3, 1, 4, 1, 5, 9]
nums.sort()
print("SORT:    " + str(nums))
nums.append(100)
print("APPEND:  " + str(nums))
nums.reverse()
print("REVERSE: " + str(nums))

# 15. Map
var m = {"name": "Nython", "version": 10}
print("MAP KEY: " + str(m["name"]))

print("=== ALL VM TESTS DONE ===")

var vm_passed = 0
var vm_failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        vm_passed = vm_passed + 1
    else:
        vm_failed = vm_failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        vm_passed = vm_passed + 1
    else:
        vm_failed = vm_failed + 1
        print "  FAIL [" + label + "] expected true, got " + str(val)

def section(name):
    print "  " + name + " ..."


# ─── Import / Class from file ────────────────────────────────────────────────
section("Import & stdlib classes (Stack)")
import "lib/stdlib.ny"
var stk2 = Stack()
stk2.push(1)
stk2.push(2)
stk2.push(3)
assert_eq("stack push/size", stk2.size, 3)
assert_eq("stack pop", stk2.pop(), 3)
assert_eq("stack size after pop", stk2.size, 2)

# ─── Try / Except / Raise ────────────────────────────────────────────────────
section("Try / Except / Raise")
var caught = false
try:
    raise "oops"
except e:
    caught = true
assert_true("caught raise", caught)

var safe = 0
try:
    raise "forced error"
    safe = 1
except e:
    safe = 99
assert_eq("try/except skips raise body", safe, 99)

var reraise_ok = false
try:
    raise "inner error"
except err:
    reraise_ok = true
assert_true("except binds message", reraise_ok)

# ─── Assert ──────────────────────────────────────────────────────────────────
section("Assert")
var assert_failed = false
try:
    assert 1 == 2, "one is not two"
except e:
    assert_failed = true
assert_true("assert raises on false", assert_failed)
assert 1 == 1, "this should not raise"
assert_eq("assert passes on true", 1, 1)

# ─── Augmented assignment on attrs/subscripts ─────────────────────────────────
section("Augmented Attr/Subscript Assignment")
class Counter:
    def __init__(self):
        self.n = 0
    def inc(self):
        self.n += 1

var c2 = Counter()
c2.inc()
c2.inc()
c2.inc()
assert_eq("attr += via method", c2.n, 3)

var arr2 = [10, 20, 30]
arr2[1] += 5
assert_eq("subscript +=", arr2[1], 25)

# ─── Lambda ──────────────────────────────────────────────────────────────────
section("Lambda")
var double_fn = lambda x: x * 2
assert_eq("lambda call", double_fn(7), 14)
var add_fn = lambda a, b: a + b
assert_eq("lambda 2-arg", add_fn(3, 4), 7)

print ""
if vm_failed == 0:
    print "=== EXTENDED VM TESTS: " + str(vm_passed) + " passed, 0 failed ==="
else:
    print "=== EXTENDED VM TESTS: " + str(vm_passed) + " passed, " + str(vm_failed) + " failed ==="

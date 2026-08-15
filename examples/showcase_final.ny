print "==============================="
print "  Nython v0.3.0 Final Showcase "
print "==============================="

print ""
print "--- Core Types & Operators ---"
print 2 ** 10
print "Hello" + " " + "World!"
print "ha" * 3
print [1, 2, 3]
print {"name": "Nython", "ver": 3}

print ""
print "--- String Methods ---"
var s = "Hello, World!"
print s.upper()
print s.lower()
print s.replace("World", "Nython")
print s.split(", ")
print ", ".join(["a", "b", "c"])
print s.find("World")
print s.startswith("Hello")
print s.substring(0, 5)
print s.reverse()

print ""
print "--- Lists ---"
var nums = [5, 3, 8, 1, 9]
print nums
print nums.sort()
print nums.slice(1, 3)
nums.append(10)
print len(nums)
print nums.indexOf(8)
print nums.join(" | ")

print ""
print "--- Functional Programming ---"
print [1,2,3,4,5].map(lambda x: x * x)
print [1,2,3,4,5].filter(lambda x: x > 2)
print [1,2,3,4,5].reduce(lambda a, b: a + b, 0)
print [10,5,8,3].filter(lambda x: x > 4).map(lambda x: x * 2).sort()

print ""
print "--- Closures ---"
def counter(start):
    var n = start
    def inc():
        n = n + 1
        return n
    return inc
var c = counter(0)
print c()
print c()
print c()

def multiplier(f):
    def m(x):
        return x * f
    return m
var dbl = multiplier(2)
var trp = multiplier(3)
print dbl(7)
print trp(7)

print ""
print "--- Classes ---"
class Vector:
    def init(self, x, y):
        self.x = x
        self.y = y
    def magnitude(self):
        return sqrt(self.x * self.x + self.y * self.y)
    def to_str(self):
        return "Vec(" + str(self.x) + ", " + str(self.y) + ")"

import math
var v = Vector(3, 4)
print v.to_str()
print v.magnitude()

class Stack:
    def init(self):
        self.items = []
        self.size = 0
    def push(self, item):
        self.items.append(item)
        self.size = self.size + 1
    def pop(self):
        self.size = self.size - 1
        return self.items.pop()
    def peek(self):
        return self.items[self.size - 1]

var stk = Stack()
stk.push(10)
stk.push(20)
stk.push(30)
print stk.peek()
print stk.pop()
print stk.size

print ""
print "--- Multi-Syntax ---"
if true {
    print "C-style braces"
}
if true do
    print "Lua-style do/end"
end
if true:
    print "Python-style indent"

print ""
print "--- Import ---"
print sqrt(PI)
print floor(PI)

print ""
print "--- Algorithms ---"
def is_prime(n):
    if n < 2:
        return false
    for i in range(2, n):
        if n % i == 0:
            return false
    return true

var primes = []
for n in range(2, 30):
    if is_prime(n):
        primes.append(n)
print primes

def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

var fibs = []
for i in range(12):
    fibs.append(fib(i))
print fibs

print ""
print "--- Error Handling ---"
try:
    var x = 10 / 0
except:
    print "caught division by zero"

try:
    assert 1 == 2
except:
    print "caught assertion error"

print ""
print "--- Switch ---"
switch 3 {
case 1:
    print "one"
case 3:
    print "three"
default:
    print "other"
}

print ""
print "--- Decorator Pattern ---"
def twice(func):
    def wrapper(x):
        return func(func(x))
    return wrapper
def add1(x):
    return x + 1
var add2 = twice(add1)
print add2(5)

print ""
print "--- Assert ---"
assert true
assert 1 + 1 == 2
assert "abc" == "abc"
assert len([1,2,3]) == 3
assert [1,2,3].sort() == [1,2,3]

print ""
print "==============================="
print "  All tests passed! v0.3.0     "
print "==============================="

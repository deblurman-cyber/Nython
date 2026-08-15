print "=== Nython v4 Showcase ==="

print "--- Negative Numbers ---"
print -5
print -3 + 10
print 0 - 42

print "--- String Indexing ---"
var s = "Nython"
print s[0]
print s[-1]
print s[2]

print "--- List Negative Index ---"
var lst = [10, 20, 30, 40, 50]
print lst[-1]
print lst[-3]
lst[-1] = 99
print lst

print "--- String Methods ---"
print "hello world".upper()
print "HELLO".lower()
print "hello world".split(" ")
print "hello world".replace("world", "nython")
print ", ".join(["a", "b", "c"])
print "  spaces  ".strip()
print "hello".reverse()
print "hello".startswith("hel")
print "hello".find("ll")

print "--- List Methods ---"
var numbers = [1, 2, 3]
numbers.append(4)
numbers.append(5)
print numbers
print numbers.pop()
print numbers
print numbers.contains(3)

print "--- Functional ---"
def square(x):
    return x * x
print [1, 2, 3, 4, 5].map(square)
def is_even(x):
    return x % 2 == 0
print [1, 2, 3, 4, 5, 6].filter(is_even)

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

print "--- Classes ---"
class Vec2:
    def init(self, x, y):
        self.x = x
        self.y = y
    def mag_sq(self):
        return self.x * self.x + self.y * self.y
    def to_str(self):
        return "(" + str(self.x) + ", " + str(self.y) + ")"

var v = Vec2(3, 4)
print v.to_str()
print v.mag_sq()

class Stack:
    def init(self):
        self.items = []
        self.count = 0
    def push(self, val):
        self.items.append(val)
        self.count = self.count + 1
    def pop(self):
        self.count = self.count - 1
        return self.items.pop()
    def size(self):
        return self.count

var stack = Stack()
stack.push(10)
stack.push(20)
stack.push(30)
print stack.size()
print stack.pop()
print stack.size()

print "--- Recursion ---"
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
for i in range(10):
    print fib(i)

print "--- Error Handling ---"
try:
    var x = 10 / 0
except:
    print "division by zero caught!"

try:
    assert 1 == 2
except:
    print "assertion caught!"

print "--- Assertions ---"
assert true
assert 1 + 1 == 2
assert "hello" == "hello"
assert -5 < 0
assert [1,2,3].contains(2)

print "=== All tests passed! ==="

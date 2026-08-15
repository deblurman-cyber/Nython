print "==============================="
print "  Nython Language Showcase v3  "
print "==============================="

print ""
print "--- Arithmetic ---"
print 2 * 3 + 4 * 5
print 2 ** 10

print ""
print "--- Strings ---"
var hello = "Hello" + " " + "World!"
print hello
print hello.upper()
print hello.lower()
print hello.replace("World", "Nython")
print hello.split(" ")
print ", ".join(["a", "b", "c"])
print "  trimmed  ".strip()
print hello.find("World")
print hello.startswith("Hello")
print hello.reverse()
print hello.substring(0, 5)

print ""
print "--- Lists ---"
var nums = [10, 20, 30, 40, 50]
print nums
print nums[2]
print len(nums)
nums.append(60)
print nums
var last = nums.pop()
print last
print nums

print ""
print "--- Functional Programming ---"
def square(x):
    return x * x
print [1, 2, 3, 4, 5].map(square)

def is_big(x):
    return x > 25
print nums.filter(is_big)

print ""
print "--- Maps ---"
var config = {"host": "localhost", "port": 8080}
print config["host"]
print config["port"]
print config

print ""
print "--- Higher Order Functions ---"
def apply(func, x):
    return func(x)
def triple(x):
    return x * 3
print apply(triple, 7)
print apply(square, 8)

print ""
print "--- Closures ---"
def counter(start):
    var n = start
    def increment():
        n = n + 1
        return n
    return increment
var cnt = counter(0)
print cnt()
print cnt()
print cnt()

print ""
print "--- Classes ---"
class Vector:
    def init(self, x, y):
        self.x = x
        self.y = y
    def magnitude_sq(self):
        return self.x * self.x + self.y * self.y
    def add(self, other):
        return Vector(self.x + other.x, self.y + other.y)
    def to_str(self):
        return "Vec(" + str(self.x) + ", " + str(self.y) + ")"

var v1 = Vector(3, 4)
print v1.to_str()
print v1.magnitude_sq()

var v2 = Vector(1, 2)
print v2.to_str()

print ""
print "--- Control Flow ---"
for i in range(1, 6):
    if i % 2 == 0:
        print str(i) + " is even"
    else:
        print str(i) + " is odd"

print ""
print "--- Switch ---"
switch 3 {
case 1:
    print "one"
case 2:
    print "two"
case 3:
    print "three"
default:
    print "other"
}

print ""
print "--- Error Handling ---"
try:
    var x = 10 / 0
    print x
except:
    print "caught division error!"

try:
    assert 1 == 2
except:
    print "caught assertion!"

print ""
print "--- Builtins ---"
print type(42)
print type("hi")
print type(true)
print abs(-42)
print min(3, 7)
print max(3, 7)
print pow(2, 16)
print hex(255)
print bin(42)
print chr(65)
print ord("A")

print ""
print "--- Fibonacci ---"
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
for i in range(12):
    print fib(i)

print ""
print "==============================="
print "  All tests passed!            "
print "==============================="

print "=== Nython Language Showcase v2 ==="

print "--- Arithmetic & Comparisons ---"
print 2 * 3 + 4 * 5
print 1 == 1
print "abc" == "abc"

print "--- Strings ---"
print "Hello" + " " + "World!"
print "ha" * 3

print "--- Variables & Assignment ---"
var x = 0
x += 10
print x

print "--- If/Elif/Else ---"
var grade = 85
if grade >= 90:
    print "A"
elif grade >= 80:
    print "B"
else:
    print "F"

print "--- Loops ---"
for i in range(5):
    print i

print "--- Lists ---"
var nums = [100, 200, 300]
print len(nums)
print nums[1]
for n in nums:
    print n

print "--- Functions ---"
def square(n):
    return n * n
print square(7)

def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
print fib(10)

print "--- Closures ---"
def multiplier(factor):
    def mult(x):
        return x * factor
    return mult
var double = multiplier(2)
var triple = multiplier(3)
print double(5)
print triple(5)

print "--- Classes ---"
class Point:
    def init(self, x, y):
        self.x = x
        self.y = y
    def distance_sq(self):
        return self.x * self.x + self.y * self.y
    def to_str(self):
        return "(" + str(self.x) + "," + str(self.y) + ")"

var p = Point(3, 4)
print p.distance_sq()
print p.to_str()

class Counter:
    def init(self, start):
        self.count = start
    def inc(self):
        self.count = self.count + 1
        return self.count

var c = Counter(0)
c.inc()
c.inc()
c.inc()
print c.count

print "--- Break/Continue ---"
for i in range(10):
    if i == 5:
        break
    if i == 2:
        continue
    print i

print "--- Switch ---"
switch 2 {
case 1:
    print 100
case 2:
    print 200
default:
    print 999
}

print "--- Builtins ---"
print type(42)
print abs(-99)
print pow(2, 10)
print hex(255)
print min(3, 7)
print max(3, 7)

print "--- Try/Except ---"
try:
    assert false
except:
    print "caught!"

print "--- Repeat ---"
var r = 0
repeat 5:
    r += 1
print r

print "--- String Functions ---"
def greet(name):
    return "Hello, " + name + "!"
print greet("Nython")

print "--- Assert ---"
assert true
assert 1 + 1 == 2
assert "abc" == "abc"
assert 10 > 5

print "=== All tests passed! ==="

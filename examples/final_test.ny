print 1 + 2 + 3
print 100 - 42
print 6 * 7
print 100 / 4
print true
print false
print 1 == 1
print 1 != 2
print 5 < 10
print 5 > 10
print 5 <= 5
print 5 >= 6

var x = 42
x = x + 1
print x

if 5 > 3:
    print 333

var i = 0
while i < 5:
    i = i + 1
print i

for j in range(4):
    print j

def add(a, b):
    return a + b
print add(10, 20)

def factorial(n):
    if n < 2:
        return 1
    return n * factorial(n - 1)
print factorial(5)
print factorial(10)

def make_adder(n):
    def adder(x):
        return x + n
    return adder
var add5 = make_adder(5)
print add5(10)
print add5(100)

print type(42)
print type(true)
print type("hello")
print abs(-10)
print min(3, 7)
print max(3, 7)
print pow(2, 10)
print hex(255)
print bin(10)

var lst = [10, 20, 30]
print len(lst)

assert true
assert 1 == 1
assert 5 > 3
print 999

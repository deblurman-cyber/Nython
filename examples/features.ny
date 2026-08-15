print 42
print 10 + 20
print 100 - 37
print 6 * 7
print 100 / 4

var x = 99
var y = x + 1
print x
print y

if true:
    print 1

if false:
    print 999
else:
    print 0

var i = 0
while i < 5:
    print i
    i = i + 1

def square(n):
    return n * n

print square(7)
print square(12)

def factorial(n):
    if n < 2:
        return 1
    return n * factorial(n - 1)

print factorial(5)
print factorial(10)

var nums = range(5)
for n in nums:
    print n

print len(range(10))
print abs(-42)
print min(3, 7)
print max(3, 7)
print type(42)
print type(true)

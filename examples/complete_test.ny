print 1 + 2 + 3
print 100 - 42
print 6 * 7
print 100 / 4
print 2 * 3 + 4 * 5
print true
print false
print 1 == 1
print 1 == 2
print 1 != 2
print 5 < 10
print 5 > 10
print 5 <= 5
print 5 >= 6

var x = 42
var y = 8
print x + y
print x - y
x = x + 1
print x

if true:
    print 111

if false:
    print 999
else:
    print 222

if 5 > 3:
    print 333

var i = 0
while i < 5:
    print i
    i = i + 1

for j in range(3):
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

var total = 0
for k in range(10):
    total = total + k
print total

assert true
assert 1 == 1
assert 5 > 3
print 999

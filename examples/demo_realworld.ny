print "========================================="
print "  Nython v0.3.0 — Real-World Demo        "
print "========================================="

import math

print ""
print "--- Student Grade Calculator ---"
class Student:
    def init(self, name, grades):
        self.name = name
        self.grades = grades
    def average(self):
        return self.grades.reduce(lambda a, b: a + b, 0) / len(self.grades)
    def highest(self):
        return self.grades.sort().pop()
    def letter_grade(self):
        var avg = self.average()
        if avg >= 90:
            return "A"
        elif avg >= 80:
            return "B"
        elif avg >= 70:
            return "C"
        elif avg >= 60:
            return "D"
        else:
            return "F"
    def report(self):
        return "{}: avg={}, grade={}".format(self.name, str(self.average()), self.letter_grade())

var students = [
    Student("Alice", [95, 87, 92, 88]),
    Student("Bob", [72, 68, 75, 80]),
    Student("Charlie", [88, 92, 95, 91])
]
for s in students:
    print s.report()

print ""
print "--- Shape Hierarchy ---"
class Shape:
    def init(self, name):
        self.name = name
    def area(self):
        return 0
    def describe(self):
        return "{}: area = {}".format(self.name, str(self.area()))

class Circle(Shape):
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius
    def area(self):
        return PI * self.radius * self.radius

class Rectangle(Shape):
    def init(self, width, height):
        self.name = "Rectangle"
        self.width = width
        self.height = height
    def area(self):
        return self.width * self.height

var shapes = [Circle(5), Rectangle(4, 6)]
for shape in shapes:
    print shape.describe()

print ""
print "--- Functional Pipeline ---"
var data = [12, 5, 8, 3, 19, 7, 15, 2, 11, 6]
var result = data
    .filter(lambda x: x > 5)
    .map(lambda x: x * 2)
    .sort()
print "Pipeline: " + str(result)
print "Sum: " + str(data.reduce(lambda a, b: a + b, 0))

print ""
print "--- Fibonacci Generator ---"
def fib_list(n):
    var result = []
    var a = 0
    var b = 1
    for i in range(n):
        result.append(a)
        var temp = a + b
        a = b
        b = temp
    return result
print "Fib(15): " + str(fib_list(15))

print ""
print "--- Prime Sieve ---"
def sieve(n):
    var primes = []
    for i in range(2, n):
        var is_prime = true
        for p in primes:
            if p * p > i:
                break
            if i % p == 0:
                is_prime = false
                break
        if is_prime:
            primes.append(i)
    return primes
print "Primes < 50: " + str(sieve(50))

print ""
print "--- Matrix Operations ---"
def make_matrix(rows, cols, fill):
    var m = []
    for i in range(rows):
        var row = []
        for j in range(cols):
            row.append(fill)
        m.append(row)
    return m

def matrix_set(m, r, c, val):
    m[r][c] = val

var grid = make_matrix(3, 3, 0)
matrix_set(grid, 0, 0, 1)
matrix_set(grid, 1, 1, 5)
matrix_set(grid, 2, 2, 9)
print "Matrix:"
for row in grid:
    print row

print ""
print "--- Closure Counter ---"
def make_counter(name, start):
    var n = start
    def inc():
        n = n + 1
        return name + ": " + str(n)
    def reset():
        n = start
        return name + " reset"
    return {"inc": inc, "reset": reset}

var c = make_counter("hits", 0)
print c["inc"]()
print c["inc"]()
print c["inc"]()
print c["reset"]()
print c["inc"]()

print ""
print "========================================="
print "  Demo complete! All features working.   "
print "========================================="

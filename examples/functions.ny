def add(a, b):
    return a + b

def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print add(3, 4)
print add(100, 200)
print factorial(5)
print factorial(10)

def greet(name):
    print name

greet("World")

def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print factorial(1)
print factorial(5)
print factorial(10)

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

print fib(0)
print fib(1)
print fib(10)

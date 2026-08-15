def memoize(func):
    var cache = {}
    def wrapper(n):
        var key = str(n)
        if cache[key] != none:
            return cache[key]
        var result = func(n)
        cache[key] = result
        return result
    return wrapper

def slow_fib(n):
    if n < 2:
        return n
    return slow_fib(n - 1) + slow_fib(n - 2)

print slow_fib(15)

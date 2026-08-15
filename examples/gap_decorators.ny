def twice(func):
    def wrapper(x):
        return func(func(x))
    return wrapper

def add1(x):
    return x + 1

var add2 = twice(add1)
print add2(5)

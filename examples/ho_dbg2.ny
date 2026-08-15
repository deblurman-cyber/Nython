def double(x):
    return x * 2
def apply(fn, x):
    print type(fn)
    return fn(x)
print apply(double, 10)

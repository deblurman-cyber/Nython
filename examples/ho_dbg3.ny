def double(x):
    return x * 2
def apply(fn, x):
    print 111
    var result = fn(x)
    print 222
    return result
print apply(double, 10)

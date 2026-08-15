def curry(func):
    def first(a):
        def second(b):
            return func(a, b)
        return second
    return first

def add(a, b):
    return a + b

var add5 = curry(add)(5)
print add5(3)
print add5(10)

var mul = curry(lambda a, b: a * b)
var double = mul(2)
var triple = mul(3)
print double(7)
print triple(7)

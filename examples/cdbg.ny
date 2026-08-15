def make_adder(n):
    def adder(x):
        return x + n
    return adder
var f = make_adder(5)
print f(10)

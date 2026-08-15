def compose(f, g):
    def composed(x):
        return f(g(x))
    return composed

def add1(x):
    return x + 1
def double(x):
    return x * 2

var add1_then_double = compose(double, add1)
var double_then_add1 = compose(add1, double)
print add1_then_double(5)
print double_then_add1(5)

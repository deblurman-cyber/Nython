def multiplier(factor):
    def mult(x):
        return x * factor
    return mult
var double = multiplier(2)
var triple = multiplier(3)
print double(5)
print triple(5)
print double(10)
print triple(10)

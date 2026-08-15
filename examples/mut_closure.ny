def counter(start):
    var n = start
    def increment():
        n = n + 1
        return n
    return increment
var cnt = counter(0)
print cnt()
print cnt()
print cnt()
print cnt()

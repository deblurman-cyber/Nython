def make():
    def inner():
        return 42
    return inner

var f = make()
print f
print f()

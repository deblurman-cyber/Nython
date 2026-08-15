class Foo:
    def init(self):
        pass
    def bar(self, handler):
        var result = handler(42)
        print result

var f = Foo()
var h = lambda x: x * 2
f.bar(h)

def printer(x):
    print "Got: " + str(x)
f.bar(printer)

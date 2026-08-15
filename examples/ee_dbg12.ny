print 111
class Foo:
    def init(self):
        pass
    def bar(self, handler):
        handler(42)

var f = Foo()
var h = lambda x: print(x)
f.bar(h)
print 222

print 111
class Foo:
    def init(self):
        pass
    def bar(self, handler):
        handler(42)

var f = Foo()
f.bar(lambda x: print(x))
print 222

print 111
class Foo:
    def init(self):
        pass
    def bar(self, handler):
        print "in bar"
        handler(42)
print 222
var f = Foo()
print 333
var h = lambda x: x * 2
print h(5)
f.bar(h)
print 444

print 111
class Emitter:
    def init(self):
        self.handlers = {}
    def register(self, event, handler):
        self.handlers[event] = handler
print 222
var e = Emitter()
print 333
def my_handler(x):
    print x
e.register("test", my_handler)
print 444

print 111
class Emitter:
    def init(self):
        self.handlers = {}
    def register(self, event, handler):
        self.handlers[event] = handler
print 222
var e = Emitter()
print 333
e.register("test", lambda x: print(x))
print 444

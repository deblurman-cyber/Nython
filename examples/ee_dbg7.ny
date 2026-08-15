print 111
class EventEmitter:
    def init(self):
        self.handlers = {}
    def on(self, event, handler):
        self.handlers[event] = handler
print 222
var e = EventEmitter()
print 333
e.on("test", lambda x: print(x))
print 444

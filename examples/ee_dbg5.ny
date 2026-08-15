class EventEmitter:
    def init(self):
        self.handlers = {}
    def on(self, event, handler):
        self.handlers[event] = handler
        print "registered: " + event
    def emit(self, event, data):
        print "emitting: " + event
        print self.handlers
        var h = self.handlers[event]
        print "handler type: " + type(h)
        if h != none:
            print "calling handler"
            h(data)
        else:
            print "handler is none"

var emitter = EventEmitter()
emitter.on("test", lambda x: print("got: " + str(x)))
emitter.emit("test", 42)

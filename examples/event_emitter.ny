class EventEmitter:
    def init(self):
        self.handlers = {}
    def register(self, event, handler):
        self.handlers[event] = handler
    def emit(self, event, data):
        var h = self.handlers[event]
        if h != none:
            h(data)

var emitter = EventEmitter()
def greet_handler(name):
    print "Hello, " + name + "!"
def square_handler(n):
    print str(n) + " squared = " + str(n * n)

emitter.register("greet", greet_handler)
emitter.register("square", square_handler)
emitter.emit("greet", "Nython")
emitter.emit("square", 7)

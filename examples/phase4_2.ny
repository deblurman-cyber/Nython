class EventEmitter:
    def init(self):
        self.handlers = {}
    def on(self, event, handler):
        self.handlers[event] = handler
    def emit(self, event, data):
        var h = self.handlers.get(event, none)
        if h != none:
            h(data)

var emitter = EventEmitter()
emitter.on("greet", lambda name: print("Hello, " + name + "!"))
emitter.emit("greet", "Nython")

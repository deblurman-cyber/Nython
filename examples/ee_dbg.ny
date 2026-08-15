class Foo:
    def init(self):
        self.handlers = {}
    def set_h(self, key, val):
        self.handlers[key] = val
    def get_h(self, key):
        return self.handlers.get(key, none)

var f = Foo()
f.set_h("test", 42)
print f.get_h("test")
print f.handlers

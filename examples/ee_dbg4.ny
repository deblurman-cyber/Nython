class Foo:
    def init(self):
        self.data = {}
    def store(self, key, val):
        self.data[key] = val
    def retrieve(self, key):
        return self.data[key]

var f = Foo()
var my_fn = lambda x: x * 2
f.store("fn", my_fn)
var retrieved = f.retrieve("fn")
print type(retrieved)
print retrieved(5)

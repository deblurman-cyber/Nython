class Store:
    def init(self):
        self.data = {}
    def set(self, key, val):
        self.data[key] = val
    def get(self, key):
        return self.data[key]

var s = Store()
s.set("x", 42)
print s.get("x")

s.set("fn", lambda x: x * 2)
var func = s.get("fn")
print func(5)

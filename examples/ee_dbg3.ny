class Foo:
    def init(self):
        self.data = {}
    def put(self, key, val):
        self.data[key] = val
        print self.data
    def show(self):
        print self.data

var f = Foo()
f.put("x", 10)
f.show()
f.put("y", 20)
f.show()

class Store:
    def init(self):
        self.data = {}
    def put(self, key, value):
        self.data[key] = value
    def get(self, key):
        return self.data[key]

var s = Store()
s.put("x", 10)
print s.get("x")
print s.data

class Counter:
    def init(self):
        self.count = 0
    def increment(self):
        self.count = self.count + 1

var c = Counter()
print c
print type(c)

class Counter:
    def init(self, start):
        self.count = start
    def increment(self):
        self.count = self.count + 1
        return self.count
    def get(self):
        return self.count

var c = Counter(10)
print c.get()
c.increment()
print c.get()
c.increment()
c.increment()
print c.get()

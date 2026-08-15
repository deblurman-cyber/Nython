class Iterator:
    def init(self, items):
        self.items = items
        self.index = 0
    def has_next(self):
        return self.index < len(self.items)
    def next(self):
        var val = self.items[self.index]
        self.index = self.index + 1
        return val

var it = Iterator([10, 20, 30])
while it.has_next():
    print it.next()

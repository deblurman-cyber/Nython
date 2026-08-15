class Thing:
    def init(self):
        self.val = 0
    def inc(self):
        self.val = self.val + 1
    def get(self):
        return self.val

var t = Thing()
t.inc()
t.inc()
t.inc()
print t.get()
print t.val

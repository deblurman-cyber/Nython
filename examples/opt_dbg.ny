print 111
class Option:
    def init(self, val, has):
        self.val = val
        self.has = has
    def is_some(self):
        return self.has
print 222
var a = Option(42, true)
print 333
print a.is_some()
print a.val

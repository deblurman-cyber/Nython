print 111
class Option:
    def init(self, val, has_val):
        self.val = val
        self.has_val = has_val
    def is_some(self):
        return self.has_val
    def is_none(self):
        return not self.has_val
print 222

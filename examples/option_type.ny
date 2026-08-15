class Option:
    def init(self, val, has_val):
        self.val = val
        self.has_val = has_val
    def is_some(self):
        return self.has_val
    def is_none(self):
        return not self.has_val
    def unwrap(self):
        if self.has_val:
            return self.val
        return none
    def unwrap_or(self, fallback):
        if self.has_val:
            return self.val
        return fallback

def Some(v):
    return Option(v, true)
def None_opt():
    return Option(none, false)

var a = Some(42)
print a.is_some()
print a.unwrap()

var b = None_opt()
print b.is_none()
print b.unwrap_or(0)
print b.unwrap_or("N/A")

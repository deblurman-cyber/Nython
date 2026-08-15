class Option:
    def init(self, value, has_val):
        self.value = value
        self.has_val = has_val
    def is_some(self):
        return self.has_val
    def is_none(self):
        return not self.has_val
    def unwrap(self):
        if self.has_val:
            return self.value
        return none
    def map(self, func):
        if self.has_val:
            return Some(func(self.value))
        return None_opt()
    def unwrap_or(self, default):
        if self.has_val:
            return self.value
        return default

def Some(val):
    return Option(val, true)
def None_opt():
    return Option(none, false)

var a = Some(42)
print a.is_some()
print a.unwrap()
print a.map(lambda x: x * 2).unwrap()

var b = None_opt()
print b.is_none()
print b.unwrap_or(0)

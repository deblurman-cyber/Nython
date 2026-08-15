class Stack:
    def init(self):
        self.count = 0
    def push(self, val):
        self.count = self.count + 1
    def size(self):
        return self.count

var s = Stack()
print s.count
s.push(10)
print s.count
s.push(20)
print s.count
print s.size()

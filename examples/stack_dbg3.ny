class Stack:
    def init(self):
        self.count = 0
    def push(self, val):
        self.count = self.count + 1
    def get_count(self):
        return self.count

var s = Stack()
s.push(10)
s.push(20)
s.push(30)
print s.get_count()
print s.count

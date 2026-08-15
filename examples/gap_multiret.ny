class Stack:
    def init(self):
        self.items = []
        self.size = 0
    def push(self, item):
        self.items.append(item)
        self.size = self.size + 1
    def pop(self):
        self.size = self.size - 1
        return self.items.pop()
    def peek(self):
        return self.items[self.size - 1]
    def is_empty(self):
        return self.size == 0

var s = Stack()
s.push(10)
s.push(20)
s.push(30)
print s.peek()
print s.pop()
print s.size
print s.is_empty()

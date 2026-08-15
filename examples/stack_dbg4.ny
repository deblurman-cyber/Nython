var s = "hello"
print len(s)

class Stack:
    def init(self):
        self.count = 0
    def push(self, val):
        self.count = self.count + 1
    def size(self):
        return self.count

var stack = Stack()
stack.push(10)
stack.push(20)
stack.push(30)
print stack.size()
print stack.count

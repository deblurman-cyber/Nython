class A:
    def init(self, v):
        self.v = v
    def get(self):
        return self.v

class B(A):
    def init(self, v, w):
        super(v)
        self.w = w
    def get_both(self):
        return str(self.v) + "," + str(self.w)

class C:
    def init(self):
        self.items = []
    def add(self, item):
        self.items.append(item)
        return self
    def size(self):
        return len(self.items)

class D:
    def init(self, name):
        self.name = name
    def __str__(self):
        return "D(" + self.name + ")"

class E:
    def init(self, data):
        self.data = data
    def process(self):
        return map(lambda x: x * 2, self.data)

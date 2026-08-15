class Foo:
    def init(self):
        self.a = "AAA"
        self.b = "BBB"
    def get_a(self):
        return self.a
    def get_b(self):
        return self.b

var f = Foo()
print f.get_a()
print f.get_b()
print f.a
print f.b

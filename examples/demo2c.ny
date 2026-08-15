class Shape:
    def init(self, name):
        self.name = name
    def describe(self):
        return self.name

class Circle(Shape):
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius

var c = Circle(5)
print c.describe()

class Shape:
    def describe(self):
        return self.name

class Circle(Shape):
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius

var c = Circle(5)
print c.name
print c.radius
print c.describe()

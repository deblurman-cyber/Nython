class Shape:
    def describe(self):
        return self.name + ": area=" + str(self.area())

class Circle(Shape):
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius
    def area(self):
        return 3.14 * self.radius * self.radius

var c = Circle(5)
print c.area()
print c.name
print c.describe()

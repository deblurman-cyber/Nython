class Shape:
    def init(self, name):
        self.name = name
    def area(self):
        return 0
    def describe(self):
        return "{}: area = {}".format(self.name, str(self.area()))

class Circle(Shape):
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius
    def area(self):
        return 3.14 * self.radius * self.radius

var c = Circle(5)
print c.area()
print c.describe()

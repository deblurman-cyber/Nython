class Circle:
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius
    def get_name(self):
        return self.name

var c = Circle(5)
print c.name
print c.radius
print c.get_name()

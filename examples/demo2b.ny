class Circle:
    def init(self, radius):
        self.name = "Circle"
        self.radius = radius
    def get_name(self):
        return self.name
    def get_radius(self):
        return self.radius

var c = Circle(5)
print c.get_name()
print c.get_radius()

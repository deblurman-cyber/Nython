class Point:
    def init(self, x, y):
        self.x = x
        self.y = y
    def distance(self):
        return self.x * self.x + self.y * self.y
    def to_string(self):
        return "(" + str(self.x) + ", " + str(self.y) + ")"

var p = Point(3, 4)
print p.distance()
print p.to_string()

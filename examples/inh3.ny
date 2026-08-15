class Base:
    def hello(self):
        return 42

class Child(Base):
    def world(self):
        return 99

var c = Child()
print c.world()
print c.hello()

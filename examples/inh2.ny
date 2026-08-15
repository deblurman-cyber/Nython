class Animal:
    def init(self, name):
        self.name = name

class Dog(Animal):
    def bark(self):
        return self.name + " barks"

var d = Dog("Rex")
print d.bark()

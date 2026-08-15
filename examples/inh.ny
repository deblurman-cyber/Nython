class Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " speaks"

class Dog(Animal):
    def bark(self):
        return self.name + " barks"

var d = Dog("Rex")
print d.bark()
print d.speak()

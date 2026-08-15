class Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " makes a sound"

class Dog(Animal):
    def init(self, name, breed):
        self.name = name
        self.breed = breed
    def speak(self):
        return self.name + " barks"

var d = Dog("Rex", "Lab")
print d.speak()
print d.name
print d.breed

class Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " makes a sound"
    def describe(self):
        return "I am " + self.name

class Dog(Animal):
    def init(self, name, breed):
        self.name = name
        self.breed = breed
    def speak(self):
        return self.name + " barks"
    def fetch(self):
        return self.name + " fetches the ball"

var d = Dog("Rex", "Labrador")
print d.speak()
print d.fetch()
print d.describe()
print d.name
print d.breed

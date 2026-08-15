class Animal:
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " makes a sound"

class Dog(Animal):
    def init(self, name):
        self.name = name
    def speak(self):
        return self.name + " barks"
    def fetch(self):
        return self.name + " fetches!"

var d = Dog("Rex")
print d.speak()
print d.fetch()
print d.name

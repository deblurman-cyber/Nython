print 111
class Animal:
    def speak(self):
        return self.name + " says " + self.sound
class Dog(Animal):
    def init(self, name):
        self.name = name
        self.sound = "Woof!"
print Dog("Rex").speak()
print 222

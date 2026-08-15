class Animal:
    def init(self, name, sound):
        self.name = name
        self.sound = sound
    def speak(self):
        return self.name + " says " + self.sound

class Dog:
    def init(self, name):
        self.name = name
        self.sound = "Woof"
    def speak(self):
        return self.name + " says " + self.sound

var d = Dog("Rex")
print d.speak()
var a = Animal("Cat", "Meow")
print a.speak()

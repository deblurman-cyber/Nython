print "--- Edge Cases ---"

var m = {"a": 1, "b": 2}
m["c"] = 3
print m.keys()
print m.values()
print m.items()

print str([1, [2, 3], [4, [5, 6]]])

print bool("")
print bool([])
print bool(0)
print bool(none)
print bool("x")
print bool([1])
print bool(1)

try:
    var x = 10 / 0
except e:
    print "Caught: " + e

class Animal:
    def speak(self):
        return self.name + " says " + self.sound
class Dog(Animal):
    def init(self, name):
        self.name = name
        self.sound = "Woof!"
class Cat(Animal):
    def init(self, name):
        self.name = name
        self.sound = "Meow!"

print Dog("Rex").speak()
print Cat("Whiskers").speak()

print 2.5 ** 3
print 2 ** 0.5

var evens = [1,2,3,4,5,6,7,8,9,10].filter(lambda x: x % 2 == 0)
var sq = evens.map(lambda x: x * x)
var total = sq.reduce(lambda a, b: a + b, 0)
print "Sum of even squares: " + str(total)

print enumerate(["a", "b", "c"])
print zip([1,2,3], ["x","y","z"])
print sorted([5,2,8,1,9,3])
print reversed([1,2,3,4,5])

print "--- All edge cases passed! ---"

# vm_audit30.ny - regressions for round 37.
# All output must be identical under the interpreter and under --vm.

print("== `init` is a constructor, not just `__init__` ==")
# The interpreter accepts either spelling; the VM matched only __init__, so a
# class written with `def init(self, ...)` constructed an instance with no
# fields set. Attributes read back as none - no error, just empty objects.
class A:
    def init(self, x):
        self.x = x
    def get(self):
        return self.x
var a = A(7)
print(a.get())
print(a.x)

class B:
    func __init__(self, v):
        self.v = v
print(B(9).v)

# inheritance: subclass ctor written with `init`, parent field still set
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
print(Dog("Rex", "Lab").speak())
print(Animal("Cat").speak())

print("== list.sort() returns the list ==")
# Returning none broke the chained form the examples use.
var L = [10, 5, 8, 3, 12, 1, 7]
print(L.filter(lambda x: x > 4).map(lambda x: x * 2).sort())
print([3, 1, 2].sort())

print("== io builtins reach the interpreter bridge ==")
# 23 names were registered as none-returning placeholder stubs, which shadowed
# the bridge implementations once the builtin block was registered eagerly.
write("/tmp/ny_audit30.txt", "alpha")
print(readlines("/tmp/ny_audit30.txt"))
print(file_size("/tmp/ny_audit30.txt"))
print(path_exists("/tmp/ny_audit30.txt"))
print(list_dir("/tmp") != none)

print("vm_audit30 ok")

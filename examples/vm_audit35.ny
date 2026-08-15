# vm_audit35.ny - division ruling, dead operators, and new language constructs.
#
# Round 71: covers the fixes made together in one commit, since they all
# touch the same class of bug (interpreter/VM divergence or a construct that
# silently did nothing) and are cheap to pin as one file. Every line's
# expected value is the SAME on both engines - this file is meant to be
# diffed interpreter-vs-VM, not run standalone.

print("== division ruling: / is always float, // and \\ floor ==")
print(10 / 2)
print(10 // 2)
print(10 \ 2)
print(-20 / 4)
print(20 // -4)

print("== instanceof (alias for is) ==")
class Animal:
    def __init__(self):
        pass
class Dog extends Animal:
    def __init__(self):
        pass
var d = Dog()
print(d instanceof Dog)
print(d instanceof Animal)
print(d instanceof int)

print("== strict equality / inequality ==")
print(1 === 1)
print(1 === 1.0)
print(1 !== 1.0)
print("a" === "a")

print("== xor ==")
print(true xor false)
print(true xor true)
print(true ^^ false)

print("== >>>= (treated as >>=) ==")
var sh = 64
sh >>>= 2
print(sh)

print("== ~= (bitwise-complement-assign) ==")
var cm = 5
cm ~= 5
print(cm)

print("== postfix ++/-- ==")
var i = 5
var old = i++
print(old)
print(i)
var j = 5
var old2 = j--
print(old2)
print(j)

print("== enum ==")
enum Color:
    RED
    GREEN
    BLUE
print(Color.RED)
print(Color.BLUE)

print("== namespace binds its own name ==")
namespace Geo:
    var PI = 3
    def area(r):
        return PI * r * r
print(Geo.PI)

print("== module is an alias for namespace ==")
module Util:
    var VERSION = 1
print(Util.VERSION)

print("== interface + implements participates in is-chain ==")
interface Shape:
    def area(self):
        pass
class Circle implements Shape:
    def __init__(self, r):
        self.r = r
    def area(self):
        return self.r * self.r
var c = Circle(3)
print(c is Shape)

print("== struct desugars to a class with self-bound fields ==")
struct Point:
    x
    y = 0
var p = Point(5, 7)
print(p.x)
print(p.y)
var p2 = Point(9)
print(p2.x)
print(p2.y)

print("== new A() / new A / A() / A are distinguishable ==")
class Box:
    def __init__(self):
        self.tag = "box"
var b1 = Box()
var b2 = new Box()
var b3 = new Box
print(b1.tag)
print(b2.tag)
print(b3.tag)

print("== hex/octal/binary integer literals ==")
print(0xFF)
print(0o17)
print(0b1010)

print("vm_audit35 ok")

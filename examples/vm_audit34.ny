# vm_audit34.ny - id()/hash() as global functions.
#
# id(x) and hash(x) were registered as recognised builtin names (so calling
# them was never a NameError) but neither dispatch_core (interpreter) nor
# globals_["id"]/["hash"] (VM) actually computed a real answer for most
# inputs:
#   - interpreter: no dispatch_* module had a case for "id" or "hash" at
#     all, so callBuiltin fell through every module and returned UNDEFINED.
#   - VM: globals_["id"] read only a[0].list, which is null for anything
#     that isn't a LIST, so id() on an instance, a map, a function, a
#     string, or a number always came back 0.
# The exact numeric id of an object is an address and is never printable
# here (non-deterministic across runs and between engines), so this checks
# the properties id()/hash() are supposed to have instead of pinned values.

print("== id() is not always zero/none ==")
class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

var p = Point(1, 2)
print(id(p) != 0)
print(id([1, 2, 3]) != 0)
print(id({"a": 1}) != 0)

print("== id(x) == id(x) for the same object ==")
var a = Point(3, 4)
print(id(a) == id(a))
var lst = [1, 2, 3]
print(id(lst) == id(lst))

print("== id(a) != id(b) for distinct objects ==")
var b = Point(3, 4)
print(id(a) != id(b))
var lst2 = [1, 2, 3]
print(id(lst) != id(lst2))

print("== hash() is repeatable ==")
print(hash("abc") == hash("abc"))
print(hash(42) == hash(42))

print("vm_audit34 ok")

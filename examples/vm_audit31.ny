# vm_audit31.ny - regressions for round 38.
# All output must be identical under the interpreter and under --vm.

print("== function values print as functions ==")
# The interpreter had no display case for a function value, so `print f`
# emitted "none" and str(f) emitted "user-data" - two different meaningless
# answers for a value that is perfectly live (it calls fine and compares
# != none). Now both engines print <function NAME>.
def make():
    def inner():
        return 42
    return inner
var f = make()
print(f)
print(f())

func named(a):
    return a
print(named)

var d = {}
d["k"] = lambda x: x + 1
print(d["k"])
print(d["k"](1))
print(d)

# semantics were always fine - pin them so a display fix never changes them
print(named != none)
print(named == none)
print(type(named))

print("== list.indexOf / map.size / map.length ==")
var L = [5, 3, 8]
print(L.indexOf(8))
print(L.indexOf(99))
print(L.index(3))
var m = {"a": 1, "b": 2, "c": 3}
print(m.size())
print(m.length())

print("vm_audit31 ok")

# vm_audit32.ny - regressions for round 39.
# Found by testing the GUI/IDE/webserver suites, which earlier rounds skipped.
# All output must be identical under the interpreter and under --vm.

print("== default parameters on class methods ==")
# Defaults were filled in at MAKE_FUNCTION runtime. Class methods never go
# through MAKE_FUNCTION - they run straight out of sub_codes - so every method
# default was dropped and the parameter arrived as none. A constructor then
# took the WRONG BRANCH of `if w == 0` and silently built a wrong object.
class W:
    def __init__(self, x_or_w, y=0, w=0, h=0):
        if w == 0:
            self.x = 0
            self.y = 0
            self.w = x_or_w
            self.h = 300
        else:
            self.x = x_or_w
            self.y = y
            self.w = w
            self.h = h
var a = W(280)
print(str(a.x) + "," + str(a.y) + "," + str(a.w) + "," + str(a.h))
var b = W(5, 6, 7, 8)
print(str(b.x) + "," + str(b.y) + "," + str(b.w) + "," + str(b.h))

class D:
    def __init__(self, p, s="hi", f=1.5, t=true, n=none):
        self.s = s
        self.f = f
        self.t = t
        self.n = n
var d = D(1)
print(str(d.s) + " " + str(d.f) + " " + str(d.t) + " " + str(d.n))

# defaults on ordinary methods, not just constructors
class M:
    def __init__(self):
        self.v = 0
    def bump(self, by=5):
        self.v = self.v + by
        return self.v
var m = M()
print(m.bump())
print(m.bump(1))

print("== method chaining evaluates each receiver once ==")
# The callee-lookup fallback re-evaluated the whole callee expression, re-running
# the receiver. The doubling compounded through nesting, so an n-deep chain
# performed 2^n - 1 calls instead of n.
class V:
    def __init__(self):
        self.n = 0
    def add(self, k):
        self.n = self.n + 1
        return self
var v1 = V()
v1.add(1)
print(v1.n)
var v2 = V()
v2.add(1).add(1)
print(v2.n)
var v3 = V()
v3.add(1).add(1).add(1)
print(v3.n)
var v4 = V()
v4.add(1).add(1).add(1).add(1)
print(v4.n)

print("vm_audit32 ok")

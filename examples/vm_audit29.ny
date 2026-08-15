# vm_audit29.ny - regressions for round 36.
# Every print must be identical under the interpreter and under --vm, AND
# arithmetically correct. Round 35 compared exit codes only; these compare values.

print("== integer width ==")
# Results were computed at full width and then truncated by a cast to (int),
# so these wrapped silently: no error, just wrong numbers.
print(100000 * 100000)          # was 1410065408
print(2147483647 + 1)           # was -2147483648
print(1000000 * 1000000)
var x = 1
var i = 0
while i < 40:
    x = x * 2
    i = i + 1
print(x)                        # was 0

print("== floor modulo ==")
# `//` floored while `%` truncated, so a == (a // b) * b + a % b failed.
print(-7 // 3)
print(-7 % 3)                   # was -1, inconsistent with -7 // 3 == -3
print(7 % -3)                   # was 1
print(7 // 2)
print(7 % 3)

print("== exact integer powers ==")
# ** was capped at 2^31 and demoted to double past it.
print(2 ** 10)
print(2 ** 62)                  # was 4.61168601842739e+18

print("== static-style class methods ==")
# A method whose first param is not `self`, called on the class, had the class
# itself prepended as an implicit self, shifting every real argument right.
class S:
    func f(n):
        return n
    func g(a, b):
        return str(a) + "/" + str(b)
    func double(v):
        return v * 2
print(S.f(4))                   # was none
print(S.g(1, 2))                # was user-data/1
print(S.double(4))              # was user-datauser-data

print("== step slicing ==")
# The parser encodes obj[a:b:c] as obj.slice(a,b,c); the VM handlers dropped
# the third argument entirely.
var L = [0,1,2,3,4,5]
print(L[::-1])                  # was []
print(L[::2])                   # was []
print(L[1:5:2])                 # was [1, 2, 3, 4]
print(L[::-2])                  # was []
var s = "abcdef"
print(s[::-1])                  # was ""
print(s[::2])
print(s[1:5:2])

print("== builtins still reach the interpreter bridge ==")
# Round 35 registered the builtin block eagerly, which made a set of
# none-returning placeholder stubs shadow the bridge implementations.
var st = fs_stat("/tmp")
print(st["is_dir"])             # was none
print(json_encode([1, 2, 3]))   # was [1,2,3]

print("vm_audit29 ok")

# vm_audit28.ny - regressions for round 35.
# Every print below must produce identical output under the interpreter and
# under --vm. Each block previously diverged or crashed on the VM.

print("== break leaves the iterator behind ==")
# The VM's `break` jumped past FOR_ITER, which is what pops the loop iterator.
# Nested, the inner loop's abandoned iterator sat above the outer loop's, so the
# outer FOR_ITER advanced the wrong one and the program never terminated.
for a in range(3):
    for b in range(3):
        if b == 1:
            break
        print(str(a) + "," + str(b))
print("nested for/break done")

# break out of a `for` nested in a `while`, and out of a `while` nested in a
# `for` - only the former owns an iterator, so only it must pop one.
var t = 0
while t < 2:
    for x in [10, 20, 30]:
        if x == 20:
            break
        print("x=" + str(x))
    t = t + 1
for y in range(2):
    var k = 0
    while true:
        k = k + 1
        if k > 1:
            break
    print("y=" + str(y) + " k=" + str(k))
print("mixed nesting done")

print("== builtins stranded behind import nytorch ==")
# map/filter/reduce and ~168 others were registered only by
# register_nytorch_builtins(), so without that import they read as none on the
# VM: silently wrong answers rather than errors.
func dbl(n):
    return n * 2
print(map(dbl, [1, 2, 3]))
print(map(lambda n: n * 2, [1, 2, 3]))
print(filter(lambda n: n > 1, [1, 2, 3]))
print(reduce(lambda p, q: p + q, [1, 2, 3, 4], 0))
print(any([false, true]))
print(all([true, true]))
print(exp(0))
print(getattr({"a": 1}, "a", 0))

print("== list() over lazy sources ==")
# Two list() registrations existed and the weaker one won, so list() of a
# generator or an iterator returned [] instead of its elements.
func upto(n):
    var i = 0
    while i < n:
        yield i
        i = i + 1
print(list(upto(3)))
print(list(range(3)))
print(list([1, 2]))

print("== try/throw/catch ==")
# `throw` was aliased to `raise` but `catch` was never aliased to `except`, so
# the JS/C++ spelling of the construct was a syntax error.
try:
    throw "boom"
catch e:
    print("caught " + str(e))
finally:
    print("finally ran")

try:
    raise "second"
catch:
    print("caught bare")

print("== math builtins with no argument ==")
# sin/cos/tan/tanh (and log/log2/log10/exp/fabs) indexed a[0] on an empty
# argument vector; VMVal holds a std::string, so the read segfaulted the VM.
# These must return a value rather than crash.
print(str(sin()) != "")
print(str(cos()) != "")
print(str(tan()) != "")
print(str(tanh()) != "")
print(str(log()) != "")
print(str(exp()) != "")

print("== repr quotes strings ==")
# The VM returned to_string(), making repr identical to str().
print(repr("abc"))
print(repr(5))
print(repr([1, 2]))

print("== time_now has sub-second resolution ==")
# std::time() truncates to whole seconds, so elapsed-time code measured 0.
var t0 = time_now()
var spin = 0
while spin < 200000:
    spin = spin + 1
print(time_now() - t0 > 0)

print("vm_audit28 ok")

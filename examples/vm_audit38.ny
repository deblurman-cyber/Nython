# vm_audit38.ny - lib/nytorch/autograd.ny: reverse-mode automatic
# differentiation, verified against hand-derived AND numerical (finite-
# difference) gradients.
#
# Nothing else in nytorch computes a gradient - optimizers.ny's AdamW/
# AdaGrad/RMSProp/NAdam/Lion all take `grads` as an argument the caller
# already has to have worked out by hand. Variable (autograd.ny) is the
# actual autograd engine: a dynamic computation graph plus backward(), which
# is the single most load-bearing thing to get right in a differentiation
# library - a wrong derivative rule silently trains a network in a slightly
# wrong direction rather than crashing, so this leans hard on the strongest
# check available: comparing the analytic gradient from backward() against
# the numerical gradient from finite differences, for several composed
# expressions, not just eyeballing hand-derived values.
#
# This finally found the bug worth fixing along the way: a closure stored in
# an instance attribute and invoked as obj.attr() (exactly the shape every
# Variable op's backward_fn takes: out._backward_fn = _bw, called later as
# node._backward_fn()) silently lost its captured variables on the VM - they
# read back as none - because vm_call_method's "bare FUNCTION held in an
# attribute" path called exec_code(held.code, args, obj) without passing
# held.closure_env, unlike every other call path. See VirtualMachine.hpp's
# vm_call_method for the fix; the interpreter never had this bug.

import "lib/nytorch.ny"

var pass_n = 0
var fail_n = 0

def check(name, got, want):
    if got == want:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": got " + str(got) + " want " + str(want))

def check_close(name, got, want, tol):
    var d = got - want
    if d < 0.0:
        d = 0.0 - d
    if d <= tol:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": got " + str(got) + " want " + str(want) + " (diff " + str(d) + ")")

print("== scalar add/sub/mul: forward and hand-derived gradients ==")
var a = Variable(2.0, true)
var b = Variable(3.0, true)
var c = a.mul(b).add(a)
# c = a*b + a = 2*3 + 2 = 8; dc/da = b + 1 = 4; dc/db = a = 2
check("forward a*b+a", c.data, 8.0)
c.backward()
check("dc/da", a.grad, 4.0)
check("dc/db", b.grad, 2.0)

print("== gradient accumulates across multiple uses of the same Variable ==")
var x = Variable(3.0, true)
var y = x.mul(x)
# y = x^2, dy/dx = 2x = 6 - both "uses" of x in the mul must contribute
y.backward()
check("dy/dx for x*x", x.grad, 6.0)

print("== pow/exp/log hand-derived gradients ==")
var p = Variable(2.0, true)
var pw = p.pow(3.0)
# pw = p^3 = 8, d/dp = 3*p^2 = 12
check("p^3 forward", pw.data, 8.0)
pw.backward()
check("d(p^3)/dp", p.grad, 12.0)

var ev = Variable(0.0, true)
var ex = ev.exp()
# e^0 = 1, d/dev = e^0 = 1
check_close("exp forward", ex.data, 1.0, 0.0001)
ex.backward()
check_close("d(exp)/dx at 0", ev.grad, 1.0, 0.0001)

var lv = Variable(2.0, true)
var lg = lv.log()
# ln(2), d/dlv = 1/2
lg.backward()
check_close("d(log)/dx at 2", lv.grad, 0.5, 0.0001)

print("== relu, sigmoid, tanh gradients at known points ==")
var r1 = Variable(5.0, true)
var ro1 = r1.relu()
ro1.backward()
check("relu grad, positive input", r1.grad, 1.0)

var r2 = Variable(0.0 - 5.0, true)
var ro2 = r2.relu()
ro2.backward()
check("relu grad, negative input", r2.grad, 0.0)

var s = Variable(0.0, true)
var so = s.sigmoid()
# sigmoid(0) = 0.5, d/dx = sigmoid*(1-sigmoid) = 0.25
check_close("sigmoid(0) forward", so.data, 0.5, 0.0001)
so.backward()
check_close("d(sigmoid)/dx at 0", s.grad, 0.25, 0.0001)

var th = Variable(0.0, true)
var tho = th.tanh()
check_close("tanh(0) forward", tho.data, 0.0, 0.0001)
tho.backward()
check_close("d(tanh)/dx at 0", th.grad, 1.0, 0.0001)

print("== vector ops: dot, sum, mean ==")
var vx = Variable(tensor([1.0, 2.0, 3.0]), true)
var vy = Variable(tensor([4.0, 5.0, 6.0]), true)
var d = vx.dot(vy)
# dot = 1*4+2*5+3*6 = 32; d(dot)/dvx = vy, d(dot)/dvy = vx
check("dot forward", d.data, 32.0)
d.backward()
check("d(dot)/dvx", vx.grad, [4.0, 5.0, 6.0])
check("d(dot)/dvy", vy.grad, [1.0, 2.0, 3.0])

var vs = Variable(tensor([1.0, 2.0, 3.0]), true)
var ssum = vs.sum()
check("vector sum forward", ssum.data, 6.0)
ssum.backward()
check("d(sum)/dv is all-ones", vs.grad, [1.0, 1.0, 1.0])

var vm = Variable(tensor([2.0, 4.0, 6.0]), true)
var mn = vm.mean()
check_close("vector mean forward", mn.data, 4.0, 0.0001)
mn.backward()
var g0 = vm.grad[0]
check_close("d(mean)/dv_i is 1/n", g0, 1.0 / 3.0, 0.0001)

print("== numerical gradient check (finite differences) ==")
# The strongest check: build f(a, b) = ((a*b + a.pow(2.0)).sigmoid()).mul(b)
# as a Variable graph, get backward()'s analytic gradient, then perturb each
# leaf by +-eps and compare against (f(x+eps)-f(x-eps))/(2*eps). Any wrong
# derivative rule anywhere in the chain shows up here even if every
# individual hand-derived test above happened to still pass.
def f_scalar(av, bv):
    var aa = Variable(av, true)
    var bb = Variable(bv, true)
    var out = aa.mul(bb).add(aa.pow(2.0)).sigmoid().mul(bb)
    return out

def f_value(av, bv):
    return f_scalar(av, bv).data

var a0 = 1.3
var b0 = 0.0 - 0.7
var node = f_scalar(a0, b0)
node.backward()
# Recover the two leaves' grads by rebuilding and reading them off the
# actual Variables backward() touched.
var aa2 = Variable(a0, true)
var bb2 = Variable(b0, true)
var out2 = aa2.mul(bb2).add(aa2.pow(2.0)).sigmoid().mul(bb2)
out2.backward()

var eps = 0.0001
var num_da = (f_value(a0 + eps, b0) - f_value(a0 - eps, b0)) / (2.0 * eps)
var num_db = (f_value(a0, b0 + eps) - f_value(a0, b0 - eps)) / (2.0 * eps)
check_close("numerical vs analytic da", aa2.grad, num_da, 0.001)
check_close("numerical vs analytic db", bb2.grad, num_db, 0.001)

print("== end-to-end: gradient descent actually reduces the loss ==")
# LinearVar + mse_loss + SGDVar: the point of the whole exercise. A fixed
# input/target pair with no closed-form shortcut - if any backward rule
# above were wrong, this would not reliably converge.
var model = LinearVar(3, 42)
var input = Variable(tensor([1.0, 0.0 - 1.0, 0.5]), false)
var target = 2.0
var opt = SGDVar(model.parameters(), 0.1)

var pred0 = model.forward(input)
var loss0 = mse_loss(pred0, target)
var first_loss = loss0.data

var step = 0
while step < 50:
    opt.zero_grad()
    var pred = model.forward(input)
    var loss = mse_loss(pred, target)
    loss.backward()
    opt.step()
    step = step + 1

var pred_final = model.forward(input)
var loss_final = mse_loss(pred_final, target)
print("loss before training: " + str(first_loss))
print("loss after 50 steps:  " + str(loss_final.data))
if loss_final.data < first_loss:
    pass_n = pass_n + 1
else:
    fail_n = fail_n + 1
    print("FAIL training: loss did not decrease")
# A real convergence bound, not just "any decrease": MSE on a single fixed
# example under plain SGD with lr=0.1 should be well under 1% of its
# starting value within 50 steps if the gradients are actually correct.
if loss_final.data < first_loss * 0.01:
    pass_n = pass_n + 1
else:
    fail_n = fail_n + 1
    print("FAIL training: loss did not converge tightly (got " + str(loss_final.data) + ", wanted < " + str(first_loss * 0.01) + ")")

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT38 PASSED ===")
else:
    print("=== VM_AUDIT38 FAILED ===")

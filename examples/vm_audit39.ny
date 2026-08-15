# vm_audit39.ny - lib/nytorch/autograd.ny's multi-output layers, softmax
# cross-entropy, and AdamVar: the pieces added on top of round 72's Variable
# engine so it can train something a single linear layer provably cannot
# solve (XOR needs a hidden layer with a nonlinearity in between).
#
# select()/stack_vars() are the new primitives (nytorch has no real 2D
# tensor to hold a weight matrix — see CLAUDE.md's "real ND tensors...
# absent" note — so a multi-output layer is N independent scalar LinearVar
# units combined into one vector Variable instead). softmax_cross_entropy is
# built entirely from ops that already have a verified backward rule (sub,
# exp, sum, log, select), not by differentiating through the native softmax/
# cross_entropy_loss builtins, which return raw tensors with no gradient at
# all.
#
# Every new piece is checked against numerical (finite-difference)
# gradients before the end-to-end training claim is trusted, exactly like
# vm_audit38.ny — a composition bug in select/stack_vars/cross-entropy would
# still let SOME gradient flow, so "the loss goes down" alone would not have
# caught it.

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

print("== select() picks one element, gradient flows only to that index ==")
var v = Variable(tensor([1.0, 2.0, 3.0]), true)
var picked = v.select(1)
check("select forward", picked.data, 2.0)
picked.backward()
check("select grad", v.grad, [0.0, 1.0, 0.0])

print("== stack_vars() combines scalars, is select()'s exact inverse ==")
var a = Variable(2.0, true)
var b = Variable(5.0, true)
var c = Variable(9.0, true)
var st = stack_vars([a, b, c])
check("stack forward", st.data, [2.0, 5.0, 9.0])
var re_picked = st.select(2)
re_picked.backward()
check("stack->select grad routes to only the right source", a.grad, 0.0)
check("stack->select grad routes to only the right source (b)", b.grad, 0.0)
check("stack->select grad routes to only the right source (c)", c.grad, 1.0)

print("== softmax_cross_entropy: numerical gradient check ==")
def ce_value(l0, l1, l2, target):
    var lg = Variable(tensor([l0, l1, l2]), true)
    return softmax_cross_entropy(lg, target).data

var logits = Variable(tensor([2.0, 0.5, 0.1]), true)
var loss = softmax_cross_entropy(logits, 0)
loss.backward()
var eps = 0.0001
var num0 = (ce_value(2.0 + eps, 0.5, 0.1, 0) - ce_value(2.0 - eps, 0.5, 0.1, 0)) / (2.0 * eps)
var num1 = (ce_value(2.0, 0.5 + eps, 0.1, 0) - ce_value(2.0, 0.5 - eps, 0.1, 0)) / (2.0 * eps)
var num2 = (ce_value(2.0, 0.5, 0.1 + eps, 0) - ce_value(2.0, 0.5, 0.1 - eps, 0)) / (2.0 * eps)
check_close("d(ce)/dlogit0 numerical match", logits.grad[0], num0, 0.001)
check_close("d(ce)/dlogit1 numerical match", logits.grad[1], num1, 0.001)
check_close("d(ce)/dlogit2 numerical match", logits.grad[2], num2, 0.001)
# The correct class's gradient component must be negative (increasing that
# logit lowers the loss) and the others positive — the direction a correct
# softmax+NLL gradient always has, regardless of the exact numbers.
if logits.grad[0] < 0.0:
    pass_n = pass_n + 1
else:
    fail_n = fail_n + 1
    print("FAIL: correct-class gradient should be negative, got " + str(logits.grad[0]))

print("== LinearLayerVar + MLPVar: numerical gradient check on a real multi-layer forward pass ==")
var model = MLPVar([2, 4, 2], 3)
var params = model.parameters()
def mlp_loss():
    var x = Variable(tensor([0.0, 1.0]), false)
    var logits2 = model.forward(x)
    return softmax_cross_entropy(logits2, 1).data
var x0 = Variable(tensor([0.0, 1.0]), false)
var out0 = model.forward(x0)
var loss0 = softmax_cross_entropy(out0, 1)
loss0.backward()
var max_diff = 0.0
var pi = 0
while pi < len(params):
    var p = params[pi]
    if p.is_vector():
        var pj = 0
        while pj < len(p.data):
            var orig = p.data[pj]
            var d = p.data
            d[pj] = orig + eps
            var lp = mlp_loss()
            d[pj] = orig - eps
            var lm = mlp_loss()
            d[pj] = orig
            var num = (lp - lm) / (2.0 * eps)
            var diff = num - p.grad[pj]
            if diff < 0.0:
                diff = 0.0 - diff
            if diff > max_diff:
                max_diff = diff
            pj = pj + 1
    else:
        var origs = p.data
        p.data = origs + eps
        var lps = mlp_loss()
        p.data = origs - eps
        var lms = mlp_loss()
        p.data = origs
        var nums = (lps - lms) / (2.0 * eps)
        var diffs = nums - p.grad
        if diffs < 0.0:
            diffs = 0.0 - diffs
        if diffs > max_diff:
            max_diff = diffs
    pi = pi + 1
check_close("MLP max |analytic - numeric| over all 12 params", max_diff, 0.0, 0.001)

print("== end to end: MLPVar + AdamVar solves XOR, which LinearVar alone cannot ==")
# XOR is the standard proof a network needs a hidden layer: no single
# linear boundary separates (0,0)/(1,1) -> 0 from (0,1)/(1,0) -> 1. Fixed
# seed, verified to reach 4/4 with headroom (see the session's seed search)
# rather than tuned to the one seed that happens to barely pass.
var xor_model = MLPVar([2, 6, 2], 1)
var opt = AdamVar(xor_model.parameters(), 0.08, 0.9, 0.999, 0.00000001)
var xs = [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]
var ys = [0, 1, 1, 0]

def xor_total_loss():
    var total = 0.0
    var i = 0
    while i < 4:
        var xi = Variable(tensor(xs[i]), false)
        total = total + softmax_cross_entropy(xor_model.forward(xi), ys[i]).data
        i = i + 1
    return total

var xor_before = xor_total_loss()
var step = 0
while step < 400:
    opt.zero_grad()
    var i = 0
    var batch_loss = none
    while i < 4:
        var xi = Variable(tensor(xs[i]), false)
        var l = softmax_cross_entropy(xor_model.forward(xi), ys[i])
        if batch_loss == none:
            batch_loss = l
        else:
            batch_loss = batch_loss.add(l)
        i = i + 1
    batch_loss.backward()
    opt.step()
    step = step + 1
var xor_after = xor_total_loss()

print("XOR total loss before: " + str(xor_before))
print("XOR total loss after 400 AdamVar steps: " + str(xor_after))

var correct = 0
var i = 0
while i < 4:
    var xi = Variable(tensor(xs[i]), false)
    var logits3 = xor_model.forward(xi)
    var pred = 0
    if logits3.data[1] > logits3.data[0]:
        pred = 1
    if pred == ys[i]:
        correct = correct + 1
    i = i + 1
check("XOR: all 4 truth-table rows classified correctly", correct, 4)
if xor_after < xor_before * 0.05:
    pass_n = pass_n + 1
else:
    fail_n = fail_n + 1
    print("FAIL: XOR loss did not converge tightly (before " + str(xor_before) + ", after " + str(xor_after) + ")")

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT39 PASSED ===")
else:
    print("=== VM_AUDIT39 FAILED ===")

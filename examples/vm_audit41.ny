# vm_audit41.ny - lib/nytorch/autograd.ny's real 2D matrix support:
# matmul, add_bias_row, select_row, and LinearMatVar/MLPMatVar built on
# them.
#
# LinearLayerVar/MLPVar (vm_audit39.ny) proved multi-layer autograd works,
# but as N independent scalar LinearVar units combined with stack_vars —
# nytorch has no native ND tensor to hold a real weight MATRIX (CLAUDE.md's
# "real ND tensors... absent" gap), so that was the workaround. This adds
# the real thing instead: Variable gained optional rows/cols shape
# metadata over its existing flat .data, and matmul()/add_bias_row() are
# real batched matrix operations - one matmul call processes an entire
# batch of samples, not one forward pass per sample. Pure Nython, no native
# C++ tensor changes - a genuinely different, safer way to close the same
# gap than touching src/builtins/tensor.cpp, which ~15,000 existing nytorch
# lines depend on.

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

print("== matmul: forward values and numerical gradient check ==")
var A = Variable(tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]), true)
A.rows = 2
A.cols = 3
var B = Variable(tensor([7.0, 8.0, 9.0, 10.0, 11.0, 12.0]), true)
B.rows = 3
B.cols = 2
var C = A.matmul(B)
check("matmul shape rows", C.rows, 2)
check("matmul shape cols", C.cols, 2)
check("matmul forward values", C.data, [58.0, 64.0, 139.0, 154.0])
var loss_mm = C.sum()
loss_mm.backward()

def mm_sum(mat_data_a, mat_data_b):
    var aa = Variable(tensor(mat_data_a), true)
    aa.rows = 2
    aa.cols = 3
    var bb = Variable(tensor(mat_data_b), true)
    bb.rows = 3
    bb.cols = 2
    return aa.matmul(bb).sum().data

var eps = 0.0001
var a_plus = [1.0 + eps, 2.0, 3.0, 4.0, 5.0, 6.0]
var a_minus = [1.0 - eps, 2.0, 3.0, 4.0, 5.0, 6.0]
var b_orig = [7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
var num_a0 = (mm_sum(a_plus, b_orig) - mm_sum(a_minus, b_orig)) / (2.0 * eps)
check_close("matmul dA[0] matches numerical", A.grad[0], num_a0, 0.001)

print("== add_bias_row: broadcasting forward and gradient ==")
var M = Variable(tensor([1.0, 2.0, 3.0, 4.0]), true)
M.rows = 2
M.cols = 2
var bias = Variable(tensor([10.0, 20.0]), true)
var biased = M.add_bias_row(bias)
check("add_bias_row forward", biased.data, [11.0, 22.0, 13.0, 24.0])
biased.sum().backward()
check("add_bias_row: self grad is identity (all ones)", M.grad, [1.0, 1.0, 1.0, 1.0])
check("add_bias_row: bias grad sums down each column", bias.grad, [2.0, 2.0])

print("== select_row: extracts one row, gradient lands only there ==")
var R = Variable(tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]), true)
R.rows = 3
R.cols = 2
var row1 = R.select_row(1)
check("select_row forward", row1.data, [3.0, 4.0])
row1.sum().backward()
check("select_row grad only on the selected row", R.grad, [0.0, 0.0, 1.0, 1.0, 0.0, 0.0])

print("== LinearMatVar/MLPMatVar: numerical gradient check on a real batched forward pass ==")
# Inputs deliberately avoid the exact zero vector [0.0, 0.0]: bias starts
# at exactly zero (matching real practice, e.g. PyTorch's own nn.Linear
# default), so an all-zero input row makes EVERY hidden unit's
# pre-activation land exactly on relu's non-differentiable point at 0 -
# not a bug, the well-known "relu at exactly zero" subgradient ambiguity,
# confirmed by hand: this exact model with this exact seed showed a real
# gradcheck mismatch only in the bias parameter, traced to the [0,0] input
# row producing all-zero pre-activations, and vanished entirely (down to
# 1e-13) the moment the input avoided that single coincidental point.
# Training still uses the real (0,0) XOR point below without issue - one
# measure-zero kink among many steps never meaningfully affects SGD.
var xs_check = [[0.01, 0.02], [0.03, 0.99], [0.98, 0.01], [1.0, 1.0]]
var x_batch_check = batch_var(xs_check, false)
var check_model = MLPMatVar([2, 6, 2], 1)
var params = check_model.parameters()
check("MLPMatVar param count for [2,6,2]", len(params), 4)
var probe_out = check_model.forward(x_batch_check).sum()
probe_out.backward()
var max_diff = 0.0
var pi = 0
while pi < len(params):
    var p = params[pi]
    var pj = 0
    while pj < len(p.data):
        var orig = p.data[pj]
        p.data[pj] = orig + eps
        var lp = check_model.forward(x_batch_check).sum().data
        p.data[pj] = orig - eps
        var lm = check_model.forward(x_batch_check).sum().data
        p.data[pj] = orig
        var num = (lp - lm) / (2.0 * eps)
        var diff = num - p.grad[pj]
        if diff < 0.0:
            diff = 0.0 - diff
        if diff > max_diff:
            max_diff = diff
        pj = pj + 1
    pi = pi + 1
check_close("MLPMatVar max |analytic - numeric| over all params", max_diff, 0.0, 0.001)

print("== end to end: batched MLPMatVar + AdamVar solves XOR in ONE matmul per layer per step ==")
# Same benchmark as vm_audit39.ny's MLPVar version, but the whole batch of
# 4 samples goes through each layer as a single matmul call here, not one
# forward pass per sample - the actual capability this round adds.
var xs = [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]
var ys = [0, 1, 1, 0]
var x_batch = batch_var(xs, false)
var xor_model = MLPMatVar([2, 6, 2], 2)
var opt = AdamVar(xor_model.parameters(), 0.08, 0.9, 0.999, 0.00000001)

def xor_total_loss():
    var logits = xor_model.forward(x_batch)
    var total = 0.0
    var i = 0
    while i < 4:
        total = total + softmax_cross_entropy(logits.select_row(i), ys[i]).data
        i = i + 1
    return total

var xor_before = xor_total_loss()
var step = 0
while step < 400:
    opt.zero_grad()
    var logits = xor_model.forward(x_batch)
    var batch_loss = none
    var i = 0
    while i < 4:
        var l = softmax_cross_entropy(logits.select_row(i), ys[i])
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
print("XOR total loss after 400 batched steps: " + str(xor_after))

var logits_final = xor_model.forward(x_batch)
var correct = 0
var i = 0
while i < 4:
    var row = logits_final.select_row(i)
    var pred = 0
    if row.data[1] > row.data[0]:
        pred = 1
    if pred == ys[i]:
        correct = correct + 1
    i = i + 1
check("XOR: all 4 truth-table rows classified correctly (batched)", correct, 4)
if xor_after < xor_before * 0.05:
    pass_n = pass_n + 1
else:
    fail_n = fail_n + 1
    print("FAIL: batched XOR loss did not converge tightly (before " + str(xor_before) + ", after " + str(xor_after) + ")")

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT41 PASSED ===")
else:
    print("=== VM_AUDIT41 FAILED ===")

# ─── Autograd ────────────────────────────────────────────────────────────────
# Reverse-mode automatic differentiation over scalars and 1D tensors.
#
# Nothing else in nytorch computes a gradient. optimizers.ny's AdamW/AdaGrad/
# RMSProp/NAdam/Lion all take `grads` as an argument the CALLER must already
# have worked out — there was no way to get one except by hand. Variable is a
# differentiable wrapper: every operation records itself and its inputs as a
# node in a dynamic graph (built fresh on every forward pass, exactly like
# PyTorch's own eager-mode autograd), and backward() walks that graph in
# reverse topological order, accumulating d(output)/d(x) into x.grad for
# every x that took part — the actual mechanism the name "autograd" refers
# to, which nothing in this library had before.
#
# Deliberately scoped to scalars and 1D tensors, the same representation
# `Tensor` in activations.ny already uses (native tensor_add/tensor_mul/…,
# which operate on flat lists — see CLAUDE.md's "real ND tensors... absent"
# note). Real matrix/ND autograd needs real ND tensor support first; this
# does not attempt to add that.
#
#   var x = Variable(tensor([1.0, 2.0]), true)
#   var y = Variable(tensor([3.0, 4.0]), true)
#   var z = x.mul(y).sum()
#   z.backward()
#   x.grad     # [3.0, 4.0]   dz/dx
#   y.grad     # [1.0, 2.0]   dz/dy
#
# A single value works the same way, unwrapped:
#   var a = Variable(2.0, true)
#   var b = Variable(3.0, true)
#   var c = a.mul(b).add(a.pow(2.0))
#   c.backward()
#   a.grad     # 7.0   d(a*b + a^2)/da = b + 2a = 3 + 4
#   b.grad     # 2.0   d(a*b + a^2)/db = a

# ── raw-value helpers ────────────────────────────────────────────────────────
# Every op below has to work whether .data is a python float or a native
# tensor (a flat list under the hood — type(tensor([...])) reads "list").
# These dispatch once so the backward rules stay readable.
def _is_vec(x):
    return type(x) == "list"

def _zeros_like(x):
    if _is_vec(x):
        return zeros(len(x))
    return 0.0

def _add_raw(a, b):
    if _is_vec(a):
        return tensor_add(a, b)
    return a + b

def _sub_raw(a, b):
    if _is_vec(a):
        return tensor_sub(a, b)
    return a - b

def _mul_raw(a, b):
    if _is_vec(a):
        return tensor_mul(a, b)
    return a * b

def _scale_raw(a, k):
    if _is_vec(a):
        return tensor_scale(a, k)
    return a * k

# Variable defines methods named exp/log/relu/sigmoid that call these SAME
# names as bare global builtins internally (for the scalar branch of each
# op). A bare call of that name from inside a same-named method resolves
# back to the method itself, not the builtin — confirmed by probe, and the
# same real bug found and fixed in activations.ny's Tensor class (see that
# file's own note). Routing through a differently-named helper avoids it.
def _exp_bi(x):
    return exp(x)
def _log_bi(x):
    return log(x)
def _relu_bi(x):
    return relu(x)
def _sigmoid_bi(x):
    return sigmoid(x)

def _sum_raw(a):
    if _is_vec(a):
        return tensor_sum(a)
    return a

# Elementwise/scalar divide via reciprocal-then-multiply — the same trick
# log()'s backward rule already uses (tensor_pow(x, -1.0)) — since there is
# no tensor_div native to call directly.
def _div_raw(a, b):
    if _is_vec(a):
        return tensor_mul(a, tensor_pow(b, 0.0 - 1.0))
    return a / b


class Variable:
    def __init__(self, data, requires_grad):
        self.data = data
        self.requires_grad = requires_grad
        self.grad = none
        self._children = []
        self._backward_fn = none
        self._op = "leaf"
        # Optional logical shape for 2D use (matmul/add_bias_row below).
        # .data stays the same flat row-major list either way — nytorch has
        # no native ND tensor type (CLAUDE.md's "real ND tensors... absent"
        # gap), so this is bookkeeping on top of the existing flat
        # representation, not a new storage type. 0 means "not a matrix."
        self.rows = 0
        self.cols = 0

    def _accum(self, g):
        if not self.requires_grad:
            return
        if self.grad == none:
            self.grad = g
        else:
            self.grad = _add_raw(self.grad, g)

    def zero_grad(self):
        self.grad = none

    # Shape propagation for elementwise ops: the output has the same
    # logical shape as its operand(s), since none of add/sub/mul/scale/
    # relu/sigmoid/tanh/exp/log/pow change how many rows or columns there
    # are, only the values. matmul/add_bias_row set rows/cols explicitly
    # instead, since those DO change shape.
    def _inherit_shape(self, src):
        self.rows = src.rows
        self.cols = src.cols

    def _inherit_shape2(self, a, b):
        if a.rows > 0:
            self.rows = a.rows
            self.cols = a.cols
        else:
            self.rows = b.rows
            self.cols = b.cols

    def is_matrix(self):
        return self.rows > 0 and self.cols > 0

    def detach(self):
        return Variable(self.data, false)

    def is_vector(self):
        return _is_vec(self.data)

    def to_string(self):
        return "Variable(" + str(self.data) + ", requires_grad=" + str(self.requires_grad) + ")"

    # ── graph traversal ─────────────────────────────────────────────────────
    # Post-order DFS, deduplicated by object identity so a Variable used more
    # than once in the graph (e.g. `x.mul(x)`) is only visited once — id()
    # was dead as a global builtin until round 70; this is exactly the kind
    # of thing it is for.
    def _build_topo(self, topo, visited):
        var key = id(self)
        if visited.has_key(key):
            return
        visited[key] = true
        var i = 0
        while i < len(self._children):
            self._children[i]._build_topo(topo, visited)
            i = i + 1
        topo.append(self)

    # Seeds this Variable's own gradient with 1s (the standard "d(loss)/
    # d(loss) = 1" starting point — matches calling .backward() on a scalar
    # loss in PyTorch) and propagates backward through the whole graph that
    # produced it.
    def backward(self):
        if _is_vec(self.data):
            self.grad = ones(len(self.data))
        else:
            self.grad = 1.0
        var topo = []
        var visited = {}
        self._build_topo(topo, visited)
        var i = len(topo) - 1
        while i >= 0:
            var v = topo[i]
            if v._backward_fn != none:
                v._backward_fn()
            i = i - 1

    # ── binary ops ───────────────────────────────────────────────────────────
    def add(self, other):
        var out = Variable(_add_raw(self.data, other.data), self.requires_grad or other.requires_grad)
        out._inherit_shape2(self, other)
        out._children = [self, other]
        out._op = "add"
        var a = self
        var b = other
        def _bw():
            a._accum(out.grad)
            b._accum(out.grad)
        out._backward_fn = _bw
        return out

    def sub(self, other):
        var out = Variable(_sub_raw(self.data, other.data), self.requires_grad or other.requires_grad)
        out._inherit_shape2(self, other)
        out._children = [self, other]
        out._op = "sub"
        var a = self
        var b = other
        def _bw():
            a._accum(out.grad)
            b._accum(_scale_raw(out.grad, -1.0))
        out._backward_fn = _bw
        return out

    # Elementwise (or scalar*scalar) multiply. d(a*b)/da = b, d(a*b)/db = a.
    def mul(self, other):
        var out = Variable(_mul_raw(self.data, other.data), self.requires_grad or other.requires_grad)
        out._inherit_shape2(self, other)
        out._children = [self, other]
        out._op = "mul"
        var a = self
        var b = other
        def _bw():
            a._accum(_mul_raw(out.grad, b.data))
            b._accum(_mul_raw(out.grad, a.data))
        out._backward_fn = _bw
        return out

    # Vector dot product -> scalar. d(a.b)/da = b * d_out, d(a.b)/db = a * d_out.
    def dot(self, other):
        var out = Variable(tensor_dot(self.data, other.data), self.requires_grad or other.requires_grad)
        out._children = [self, other]
        out._op = "dot"
        var a = self
        var b = other
        def _bw():
            a._accum(_scale_raw(b.data, out.grad))
            b._accum(_scale_raw(a.data, out.grad))
        out._backward_fn = _bw
        return out

    # Real matrix multiply: self is (m x k), other is (k x n), both flat
    # row-major with rows/cols set (see LinearMatVar below for how those
    # get set). Unlike LinearLayerVar's N-independent-scalar-units
    # workaround, this is one actual batched matmul — self can be a whole
    # batch of samples (rows = batch size) multiplied through in one call,
    # not one forward pass per sample. Standard backward rule:
    # dA = dC @ B^T, dB = A^T @ dC.
    def matmul(self, other):
        var m = self.rows
        var k = self.cols
        var n = other.cols
        var out_data = []
        var i = 0
        while i < m:
            var j = 0
            while j < n:
                var s = 0.0
                var p = 0
                while p < k:
                    s = s + self.data[i * k + p] * other.data[p * n + j]
                    p = p + 1
                out_data.append(s)
                j = j + 1
            i = i + 1
        var out = Variable(tensor(out_data), self.requires_grad or other.requires_grad)
        out.rows = m
        out.cols = n
        out._children = [self, other]
        out._op = "matmul"
        var a = self
        var b = other
        var mc = m
        var kc = k
        var nc = n
        def _bw():
            var dA = zeros(mc * kc)
            var i2 = 0
            while i2 < mc:
                var p2 = 0
                while p2 < kc:
                    var s2 = 0.0
                    var j2 = 0
                    while j2 < nc:
                        s2 = s2 + out.grad[i2 * nc + j2] * b.data[p2 * nc + j2]
                        j2 = j2 + 1
                    dA[i2 * kc + p2] = s2
                    p2 = p2 + 1
                i2 = i2 + 1
            var dB = zeros(kc * nc)
            var p3 = 0
            while p3 < kc:
                var j3 = 0
                while j3 < nc:
                    var s3 = 0.0
                    var i3 = 0
                    while i3 < mc:
                        s3 = s3 + a.data[i3 * kc + p3] * out.grad[i3 * nc + j3]
                        i3 = i3 + 1
                    dB[p3 * nc + j3] = s3
                    j3 = j3 + 1
                p3 = p3 + 1
            a._accum(dA)
            b._accum(dB)
        out._backward_fn = _bw
        return out

    # Broadcasting add of a 1D bias vector across every row of a 2D
    # Variable — the other half of a real nn.Linear, alongside matmul.
    # d(out)/d(self) is identity (same shape); d(out)/d(bias) sums the
    # upstream gradient down each column, the standard broadcast-backward
    # rule (every row's copy of bias contributed to that column's output).
    def add_bias_row(self, bias):
        var r = self.rows
        var c = self.cols
        var out_data = []
        var i = 0
        while i < r:
            var j = 0
            while j < c:
                out_data.append(self.data[i * c + j] + bias.data[j])
                j = j + 1
            i = i + 1
        var out = Variable(tensor(out_data), self.requires_grad or bias.requires_grad)
        out.rows = r
        out.cols = c
        out._children = [self, bias]
        out._op = "add_bias_row"
        var a = self
        var b = bias
        var rc = r
        var cc = c
        def _bw():
            a._accum(out.grad)
            var db = zeros(cc)
            var i2 = 0
            while i2 < rc:
                var j2 = 0
                while j2 < cc:
                    db[j2] = db[j2] + out.grad[i2 * cc + j2]
                    j2 = j2 + 1
                i2 = i2 + 1
            b._accum(db)
        out._backward_fn = _bw
        return out

    # Pick out one element of a vector Variable as its own scalar Variable.
    # The inverse of stack_vars() below — gradient flows back to only the
    # selected index, everywhere else in self.grad gets 0 from this op.
    def select(self, i):
        var out = Variable(self.data[i], self.requires_grad)
        out._children = [self]
        out._op = "select"
        var a = self
        var idx = i
        var n = len(self.data)
        def _bw():
            var g = zeros(n)
            g[idx] = out.grad
            a._accum(g)
        out._backward_fn = _bw
        return out

    # Pick out row i of a 2D (rows x cols) Variable as its own 1D vector
    # Variable — how a batched forward pass (one matmul for the whole
    # batch) still lets each sample get its own loss: run the batch through
    # the network ONCE, then select_row() each sample's output before
    # softmax_cross_entropy, and one shared backward() through all of it
    # accumulates every sample's contribution into the same weight matrix.
    def select_row(self, i):
        var c = self.cols
        var row_data = []
        var j = 0
        while j < c:
            row_data.append(self.data[i * c + j])
            j = j + 1
        var out = Variable(tensor(row_data), self.requires_grad)
        out._children = [self]
        out._op = "select_row"
        var a = self
        var ri = i
        var cc = c
        var total_rows = self.rows
        def _bw():
            var g = zeros(total_rows * cc)
            var j2 = 0
            while j2 < cc:
                g[ri * cc + j2] = out.grad[j2]
                j2 = j2 + 1
            a._accum(g)
        out._backward_fn = _bw
        return out

    # ── unary ops ────────────────────────────────────────────────────────────
    # No __neg__: unary minus on a custom instance does not construct one
    # consistently on either engine (confirmed by probe — `-Tensor(...)`
    # comes back with .data none on both interpreter and VM, and Tensor
    # itself only ever exposes .neg() for the same reason). scale(-1.0) is
    # the safe, already-correct path.
    def neg(self):
        return self.scale(-1.0)

    # Multiply by a plain python/float constant (not a Variable) — for
    # things like weight decay (`w.scale(1.0 - wd)`) where the other operand
    # is never itself part of the graph.
    def scale(self, k):
        var out = Variable(_scale_raw(self.data, k), self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "scale"
        var a = self
        def _bw():
            a._accum(_scale_raw(out.grad, k))
        out._backward_fn = _bw
        return out

    # Constant exponent (p is a plain float, not a Variable — matching
    # tensor_pow's own signature). d(a^p)/da = p * a^(p-1).
    def pow(self, p):
        var out = Variable(tensor_pow(self.data, p) if _is_vec(self.data) else self.data ** p,
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "pow"
        var a = self
        def _bw():
            var local = tensor_pow(a.data, p - 1.0) if _is_vec(a.data) else a.data ** (p - 1.0)
            var scaled = _scale_raw(local, p)
            a._accum(_mul_raw(scaled, out.grad))
        out._backward_fn = _bw
        return out

    # d(e^a)/da = e^a = out itself.
    def exp(self):
        var out = Variable(tensor_exp(self.data) if _is_vec(self.data) else _exp_bi(self.data),
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "exp"
        var a = self
        def _bw():
            a._accum(_mul_raw(out.data, out.grad))
        out._backward_fn = _bw
        return out

    # d(ln a)/da = 1/a.
    def log(self):
        var out = Variable(tensor_log(self.data) if _is_vec(self.data) else _log_bi(self.data),
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "log"
        var a = self
        def _bw():
            var inv = tensor_pow(a.data, 0.0 - 1.0) if _is_vec(a.data) else 1.0 / a.data
            a._accum(_mul_raw(inv, out.grad))
        out._backward_fn = _bw
        return out

    # Vector -> scalar. d(sum a)/da_i = 1 for every i.
    def sum(self):
        var out = Variable(_sum_raw(self.data), self.requires_grad)
        out._children = [self]
        out._op = "sum"
        var a = self
        def _bw():
            if _is_vec(a.data):
                a._accum(_scale_raw(ones(len(a.data)), out.grad))
            else:
                a._accum(out.grad)
        out._backward_fn = _bw
        return out

    # Vector -> scalar. d(mean a)/da_i = 1/n.
    def mean(self):
        var n = len(self.data) if _is_vec(self.data) else 1
        var out = Variable(tensor_mean(self.data) if _is_vec(self.data) else self.data,
                            self.requires_grad)
        out._children = [self]
        out._op = "mean"
        var a = self
        var nn = n
        def _bw():
            if _is_vec(a.data):
                a._accum(_scale_raw(ones(nn), out.grad / nn))
            else:
                a._accum(out.grad)
        out._backward_fn = _bw
        return out

    # d(relu a)/da_i = 1 if a_i > 0 else 0.
    def relu(self):
        var out = Variable(tensor_apply(self.data, lambda v: _relu_bi(v)) if _is_vec(self.data)
                            else _relu_bi(self.data),
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "relu"
        var a = self
        def _bw():
            if _is_vec(a.data):
                var mask = tensor_apply(a.data, lambda v: 1.0 if v > 0.0 else 0.0)
                a._accum(_mul_raw(mask, out.grad))
            else:
                a._accum(out.grad if a.data > 0.0 else 0.0)
        out._backward_fn = _bw
        return out

    # d(sigmoid a)/da = out * (1 - out).
    def sigmoid(self):
        var out = Variable(tensor_apply(self.data, lambda v: _sigmoid_bi(v)) if _is_vec(self.data)
                            else _sigmoid_bi(self.data),
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "sigmoid"
        var a = self
        def _bw():
            if _is_vec(out.data):
                var one_minus = tensor_apply(out.data, lambda v: 1.0 - v)
                a._accum(_mul_raw(_mul_raw(out.data, one_minus), out.grad))
            else:
                a._accum(out.data * (1.0 - out.data) * out.grad)
        out._backward_fn = _bw
        return out

    # d(tanh a)/da = 1 - out^2.
    def tanh(self):
        var out = Variable(tensor_apply(self.data, lambda v: tanh_fn(v)) if _is_vec(self.data)
                            else tanh_fn(self.data),
                            self.requires_grad)
        out._inherit_shape(self)
        out._children = [self]
        out._op = "tanh"
        var a = self
        def _bw():
            if _is_vec(out.data):
                var sq = tensor_apply(out.data, lambda v: 1.0 - v * v)
                a._accum(_mul_raw(sq, out.grad))
            else:
                a._accum((1.0 - out.data * out.data) * out.grad)
        out._backward_fn = _bw
        return out

    # ── operator sugar ───────────────────────────────────────────────────────
    def __add__(self, other):
        return self.add(other)
    def __sub__(self, other):
        return self.sub(other)
    def __mul__(self, other):
        return self.mul(other)


# ── a couple of tiny, real, differentiable building blocks ───────────────────
# Enough to show the whole point end to end: a layer whose parameters get a
# real gradient from a real loss, not one supplied by the caller.

class LinearVar:
    def __init__(self, n_in, seed):
        # Scaled by 1/sqrt(n_in) (a simplified Xavier/He-style init) rather
        # than a fixed range — a fixed-width init that is fine for one layer
        # leaves a multi-layer MLP (see MLPVar) badly conditioned as the
        # fan-in of later layers grows, which is most of why the first
        # version of the XOR test below got stuck rather than converging.
        var w = []
        var i = 0
        var s = seed
        var scale = 1.0 / sqrt(1.0 * n_in)
        while i < n_in:
            s = (s * 1103515245 + 12345) % 2147483648
            w.append((s / 2147483648.0 - 0.5) * 2.0 * scale)
            i = i + 1
        self.weight = Variable(tensor(w), true)
        self.bias = Variable(0.0, true)

    def forward(self, x):
        return self.weight.dot(x).add(self.bias)

    def parameters(self):
        return [self.weight, self.bias]


# Mean-squared-error loss between a Variable prediction and a plain-float
# target, differentiable back through the prediction.
def mse_loss(pred, target):
    var diff = pred.sub(Variable(target, false))
    return diff.pow(2.0)


class SGDVar:
    def __init__(self, params, lr):
        self.params = params
        self.lr = lr

    def step(self):
        var i = 0
        while i < len(self.params):
            var p = self.params[i]
            if p.grad != none:
                p.data = _sub_raw(p.data, _scale_raw(p.grad, self.lr))
            i = i + 1

    def zero_grad(self):
        var i = 0
        while i < len(self.params):
            self.params[i].zero_grad()
            i = i + 1


# ── multi-output layers, classification loss, and a proper optimizer ────────
# LinearVar above is single-output (a weight VECTOR, one dot product). A real
# layer needs multiple output units — normally a weight MATRIX, but nytorch
# has no real 2D tensor support (CLAUDE.md's "real ND tensors... absent" gap
# again) to hold one. stack_vars/select are the workaround: a multi-output
# layer is just N independent LinearVar units whose scalar outputs get
# combined into one vector Variable, and indexing back out of a vector
# Variable is select(). Composing scalar autograd nodes this way is slower
# than a real batched matmul would be, but every gradient through it is
# exactly as correct, since it is built entirely from ops already verified
# above rather than a new differentiation rule of its own.

# Combines several independent SCALAR Variables into one vector Variable.
# The inverse of Variable.select(): out[i]'s gradient flows back to only
# vars_list[i], not the others.
def stack_vars(vars_list):
    var n = len(vars_list)
    var data = []
    var i = 0
    while i < n:
        data.append(vars_list[i].data)
        i = i + 1
    var out = Variable(tensor(data), true)
    out._children = vars_list
    out._op = "stack"
    var srcs = vars_list
    def _bw():
        var k = 0
        while k < len(srcs):
            srcs[k]._accum(out.grad[k])
            k = k + 1
    out._backward_fn = _bw
    return out


# Numerically-stable softmax + negative-log-likelihood in one differentiable
# step, built entirely from ops that already have a backward rule (sub, exp,
# sum, log, select) rather than differentiating through the native softmax/
# cross_entropy_loss builtins, which return raw tensors with no gradient at
# all. loss = -log(softmax(logits)[target]) = log_sum_exp(logits) -
# logits[target], shifting by the (constant, non-differentiated) max first
# for numerical stability — exactly PyTorch's own log-sum-exp trick.
def softmax_cross_entropy(logits, target_idx):
    var n = len(logits.data)
    var mx = logits.data[0]
    var i = 1
    while i < n:
        if logits.data[i] > mx:
            mx = logits.data[i]
        i = i + 1
    var shift = Variable(_scale_raw(ones(n), mx), false)
    var shifted = logits.sub(shift)
    var exps = shifted.exp()
    var sum_exp = exps.sum()
    var log_sum_exp = sum_exp.log()
    var target_val = shifted.select(target_idx)
    return log_sum_exp.sub(target_val)


# A real multi-output linear layer: n_out independent LinearVar units,
# stacked into one vector output. Matches nn.Linear(n_in, n_out)'s shape
# contract even without a weight matrix behind it.
class LinearLayerVar:
    def __init__(self, n_in, n_out, seed):
        self.units = []
        var i = 0
        while i < n_out:
            self.units.append(LinearVar(n_in, seed + i * 97 + 13))
            i = i + 1

    def forward(self, x):
        var outs = []
        var i = 0
        while i < len(self.units):
            outs.append(self.units[i].forward(x))
            i = i + 1
        return stack_vars(outs)

    def parameters(self):
        var out = []
        var i = 0
        while i < len(self.units):
            out = out + self.units[i].parameters()
            i = i + 1
        return out


# A real multi-layer perceptron: LinearLayerVar + relu between every pair of
# layers, raw (unactivated) output from the last one — the shape every
# other framework's MLP has, and (unlike LinearVar alone) can solve problems
# a single linear layer provably cannot, like XOR (see vm_audit39.ny).
class MLPVar:
    def __init__(self, sizes, seed):
        self.layers = []
        var i = 0
        while i < len(sizes) - 1:
            self.layers.append(LinearLayerVar(sizes[i], sizes[i + 1], seed + i * 733))
            i = i + 1

    def forward(self, x):
        var h = x
        var i = 0
        while i < len(self.layers) - 1:
            h = self.layers[i].forward(h).relu()
            i = i + 1
        return self.layers[len(self.layers) - 1].forward(h)

    def parameters(self):
        var out = []
        var i = 0
        while i < len(self.layers):
            out = out + self.layers[i].parameters()
            i = i + 1
        return out


# Adam, the optimizer actually used to train most real models — SGDVar alone
# only proves the gradients are correct, not that this library can train
# anything harder than a straight line. Standard bias-corrected first/second
# moment estimates; operates directly on Variable.grad rather than taking a
# separately-computed `grads` list like optimizers.ny's gradient-free Adam.
class AdamVar:
    def __init__(self, params, lr, beta1, beta2, eps):
        self.params = params
        self.lr = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.eps = eps
        self.t = 0
        self.m = []
        self.v = []
        var i = 0
        while i < len(params):
            self.m.append(_zeros_like(params[i].data))
            self.v.append(_zeros_like(params[i].data))
            i = i + 1

    def zero_grad(self):
        var i = 0
        while i < len(self.params):
            self.params[i].zero_grad()
            i = i + 1

    def step(self):
        self.t = self.t + 1
        var b1 = self.beta1
        var b2 = self.beta2
        var eps_c = self.eps
        var bias1 = 1.0 - b1 ** self.t
        var bias2 = 1.0 - b2 ** self.t
        var i = 0
        while i < len(self.params):
            var p = self.params[i]
            if p.grad != none:
                self.m[i] = _add_raw(_scale_raw(self.m[i], b1), _scale_raw(p.grad, 1.0 - b1))
                var gsq = _mul_raw(p.grad, p.grad)
                self.v[i] = _add_raw(_scale_raw(self.v[i], b2), _scale_raw(gsq, 1.0 - b2))
                var mhat = _scale_raw(self.m[i], 1.0 / bias1)
                var vhat = _scale_raw(self.v[i], 1.0 / bias2)
                var denom = 0.0
                if _is_vec(vhat):
                    denom = tensor_apply(vhat, lambda x: sqrt(x) + eps_c)
                else:
                    denom = sqrt(vhat) + eps_c
                var update = _div_raw(_scale_raw(mhat, self.lr), denom)
                p.data = _sub_raw(p.data, update)
            i = i + 1


# ── real matrix-backed Linear layer ──────────────────────────────────────────
# LinearLayerVar (above) is n_out independent scalar units combined with
# stack_vars — correct, but one Variable graph per output unit per sample.
# This is a real nn.Linear: one weight MATRIX, one matmul call handles an
# entire batch of samples at once. weight is (n_in x n_out); forward
# expects x shaped (batch x n_in) and returns (batch x n_out).
class LinearMatVar:
    def __init__(self, n_in, n_out, seed):
        var w_data = []
        var i = 0
        var s = seed
        var scale = 1.0 / sqrt(1.0 * n_in)
        while i < n_in * n_out:
            s = (s * 1103515245 + 12345) % 2147483648
            w_data.append((s / 2147483648.0 - 0.5) * 2.0 * scale)
            i = i + 1
        self.weight = Variable(tensor(w_data), true)
        self.weight.rows = n_in
        self.weight.cols = n_out
        self.bias = Variable(zeros(n_out), true)

    def forward(self, x):
        return x.matmul(self.weight).add_bias_row(self.bias)

    def parameters(self):
        return [self.weight, self.bias]


# Wraps a flat list of samples (each length n_in) into one 2D Variable
# (batch x n_in), the shape matmul-based layers expect.
def batch_var(samples, requires_grad):
    var rows = len(samples)
    var cols = len(samples[0])
    var flat = []
    var i = 0
    while i < rows:
        var j = 0
        while j < cols:
            flat.append(samples[i][j])
            j = j + 1
        i = i + 1
    var v = Variable(tensor(flat), requires_grad)
    v.rows = rows
    v.cols = cols
    return v


# A real multi-layer perceptron over LinearMatVar — the matmul-based
# counterpart to MLPVar, processing a whole batch through each layer in one
# matmul rather than one forward pass per sample.
class MLPMatVar:
    def __init__(self, sizes, seed):
        self.layers = []
        var i = 0
        while i < len(sizes) - 1:
            self.layers.append(LinearMatVar(sizes[i], sizes[i + 1], seed + i * 733))
            i = i + 1

    def forward(self, x):
        var h = x
        var i = 0
        while i < len(self.layers) - 1:
            h = self.layers[i].forward(h).relu()
            i = i + 1
        return self.layers[len(self.layers) - 1].forward(h)

    def parameters(self):
        var out = []
        var i = 0
        while i < len(self.layers):
            out = out + self.layers[i].parameters()
            i = i + 1
        return out

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


class Variable:
    def __init__(self, data, requires_grad):
        self.data = data
        self.requires_grad = requires_grad
        self.grad = none
        self._children = []
        self._backward_fn = none
        self._op = "leaf"

    def _accum(self, g):
        if not self.requires_grad:
            return
        if self.grad == none:
            self.grad = g
        else:
            self.grad = _add_raw(self.grad, g)

    def zero_grad(self):
        self.grad = none

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
        var w = []
        var i = 0
        var s = seed
        while i < n_in:
            s = (s * 1103515245 + 12345) % 2147483648
            w.append((s / 2147483648.0 - 0.5) * 0.2)
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

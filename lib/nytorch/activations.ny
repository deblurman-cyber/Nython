# import nytorch

class Tensor:
    def init(self, data):
        if type(data) == "list":
            self.data = tensor(data)
        else:
            self.data = data

    # Arithmetic (return Tensor - safe because Tensor already defined here)
    def __add__(self, other):
        var res = Tensor([0.0])
        res.data = tensor_add(self.data, other.data)
        return res
    def __sub__(self, other):
        var res = Tensor([0.0])
        res.data = tensor_sub(self.data, other.data)
        return res
    def __mul__(self, other):
        var res = Tensor([0.0])
        var t = type(other)
        if t == "int" or t == "float" or t == "bool":
            res.data = tensor_scale(self.data, float(other))
        else:
            res.data = tensor_mul(self.data, other.data)
        return res

    # Reductions    scalar
    def sum(self):
        return tensor_sum(self.data)
    def mean(self):
        return tensor_mean(self.data)
    def max(self):
        return tensor_max(self.data)
    def min(self):
        return tensor_min(self.data)
    def var(self):
        return tensor_var(self.data)
    def std(self):
        return tensor_std(self.data)
    def norm(self):
        return tensor_norm(self.data)
    def argmax(self):
        return tensor_argmax(self.data)
    def argmin(self):
        return tensor_argmin(self.data)
    def dot(self, other):
        return tensor_dot(self.data, other.data)

    # Element-wise    raw tensor
    def exp(self):
        return tensor_exp(self.data)
    def log(self):
        return tensor_log(self.data)
    def sqrt(self):
        return tensor_sqrt(self.data)
    def abs(self):
        return tensor_abs(self.data)
    def neg(self):
        return tensor_neg(self.data)
    def pow(self, e):
        return tensor_pow(self.data, e)
    def scale(self, s):
        return tensor_scale(self.data, s)

    # Activations    raw tensor
    def relu(self):
        return tensor_apply(self.data, lambda v: relu(v))
    def sigmoid(self):
        return tensor_apply(self.data, lambda v: sigmoid(v))
    def tanh(self):
        return tensor_apply(self.data, lambda v: tanh_fn(v))
    def gelu(self):
        return tensor_apply(self.data, lambda v: gelu(v))
    def silu(self):
        return tensor_apply(self.data, lambda v: silu(v))
    def swish(self):
        return tensor_apply(self.data, lambda v: swish(v))
    def elu(self):
        return tensor_apply(self.data, lambda v: elu(v))
    def softmax(self):
        return softmax(self.data)
    def mish(self):
        return tensor_apply(self.data, lambda v: v * tanh_fn(log(1.0 + 2.71828182845904 ** v)))
    def hardsigmoid(self):
        return tensor_apply(self.data, lambda v: max(0.0, min(1.0, v / 6.0 + 0.5)))
    def hardswish(self):
        return tensor_apply(self.data, lambda v: v * max(0.0, min(6.0, v + 3.0)) / 6.0)
    def softsign(self):
        return tensor_apply(self.data, lambda v: v / (1.0 + abs(v)))

    # Tensor ops    raw tensor
    def concat(self, other):
        return tensor_concat(self.data, other.data)
    def normalize(self):
        return tensor_normalize(self.data)
    def clip(self, lo, hi):
        return tensor_clip(self.data, lo, hi)
    def slice(self, start, stop):
        return tensor_slice(self.data, start, stop)
    def cumsum(self):
        return tensor_cumsum(self.data)
    def diff(self):
        return tensor_diff(self.data)
    def outer(self, other):
        return tensor_outer(self.data, other.data)

    # Indexing
    def __getitem__(self, i):
        return self.data[i]
    def __len__(self):
        return len(self.data)


# ---------------------------------------------
# SECTION 2: ACTIVATION LAYERS
# ---------------------------------------------

class ReLULayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: relu(v))
        return res

class SigmoidLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: sigmoid(v))
        return res

class TanhLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: tanh_fn(v))
        return res

class SoftmaxLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = softmax(x.data)
        return res

class GeLULayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: gelu(v))
        return res

class SiLULayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: silu(v))
        return res

class ELULayer:
    def init(self, alpha):
        self.alpha = alpha
    def forward(self, x):
        var a = self.alpha
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: elu(v, a))
        return res

class LeakyReLULayer:
    def init(self, alpha):
        self.alpha = alpha
    def forward(self, x):
        var a = self.alpha
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: leaky_relu(v, a))
        return res

class MishLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v * tanh_fn(log(1.0 + 2.71828182845904 ** v)))
        return res

class HardswishLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v * max(0.0, min(6.0, v + 3.0)) / 6.0)
        return res

class SoftsignLayer:
    def forward(self, x):
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v / (1.0 + abs(v)))
        return res

class PReLULayer:
    def init(self, init_val):
        self.alpha = init_val
    def forward(self, x):
        var a = self.alpha
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v if v >= 0.0 else a * v)
        return res

class SoftplusLayer:
    def init(self, beta):
        self.beta = beta
    def forward(self, x):
        var b = self.beta
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: log(1.0 + 2.71828182845904 ** (b * v)) / b)
        return res

class HardshrinkLayer:
    def init(self, lambd):
        self.lambd = lambd
    def forward(self, x):
        var lam = self.lambd
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v if abs(v) > lam else 0.0)
        return res


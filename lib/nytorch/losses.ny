# import nytorch

class SwiGLU:
    # Used in LLaMA, PaLM - SwiGLU(x) = W1(x) * SiLU(W2(x))
    def init(self, in_dim, out_dim):
        self.W1 = Linear(in_dim, out_dim)
        self.W2 = Linear(in_dim, out_dim)
    def forward(self, x):
        var h1 = self.W1.forward(x)
        var h2 = self.W2.forward(x)
        var swish_h2 = Tensor([0.0])
        swish_h2.data = tensor_apply(h2.data, lambda v: silu(v))
        var out = Tensor([0.0])
        out.data = tensor_mul(h1.data, swish_h2.data)
        return out


# ---------------------------------------------
# SECTION 7: LOSS FUNCTIONS
# ---------------------------------------------

class MSELoss:
    def forward(self, pred, target):
        return mse_loss(pred.data, target.data)

class MAELoss:
    def forward(self, pred, target):
        var diff = tensor_abs(tensor_sub(pred.data, target.data))
        return tensor_mean(diff)

class BCELoss:
    def forward(self, pred, target):
        return binary_cross_entropy(pred.data, target.data)

class CrossEntropyLoss:
    def forward(self, pred, target):
        return cross_entropy_loss(pred.data, target.data)

class HuberLoss:
    def init(self, delta):
        self.delta = delta
    def forward(self, pred, target):
        return huber_loss(pred.data, target.data, self.delta)

class FocalLoss:
    def init(self, alpha, gamma):
        self.alpha = alpha
        self.gamma = gamma
    def forward(self, pred, target):
        var total = 0.0
        var n = len(pred.data)
        var i = 0
        while i < n:
            var p = max(0.0000001, min(1.0 - 0.0000001, pred.data[i]))
            var t = target.data[i]
            var fl = -self.alpha * ((1.0 - p) ** self.gamma) * log(p) * t
            var fl = fl - (1.0 - self.alpha) * (p ** self.gamma) * log(1.0 - p) * (1.0 - t)
            var total = total + fl
            var i = i + 1
        return total / float(n)

class LabelSmoothingLoss:
    def init(self, num_classes, smoothing):
        self.num_classes = num_classes
        self.smoothing   = smoothing
    def forward(self, log_pred, target):
        var eps   = self.smoothing
        var k     = float(self.num_classes)
        var st    = tensor_add(tensor_scale(target.data, 1.0 - eps), tensor_scale(ones(len(target.data)), eps / k))
        return -tensor_dot(st, log_pred.data)

class TripletLoss:
    def init(self, margin):
        self.margin = margin
    def forward(self, anchor, positive, negative):
        var d_pos = tensor_mean(tensor_pow(tensor_sub(anchor.data, positive.data), 2.0))
        var d_neg = tensor_mean(tensor_pow(tensor_sub(anchor.data, negative.data), 2.0))
        var loss  = d_pos - d_neg + self.margin
        if loss < 0.0:
            return 0.0
        return loss

class DiceLoss:
    def init(self):
        self.eps = 0.000001
    def forward(self, pred, target):
        var inter = tensor_dot(pred.data, target.data)
        var denom = tensor_sum(pred.data) + tensor_sum(target.data) + self.eps
        return 1.0 - (2.0 * inter + self.eps) / denom

class CosineEmbeddingLoss:
    def init(self, margin):
        self.margin = margin
    def forward(self, x1, x2, label):
        var sim = cosine_similarity(x1.data, x2.data)
        if label == 1.0:
            return 1.0 - sim
        var val = sim - self.margin
        if val < 0.0:
            return 0.0
        return val

class ContrastiveLoss:
    def init(self, margin):
        self.margin = margin
    def forward(self, x1, x2, label):
        var diff = tensor_sub(x1.data, x2.data)
        var dist = sqrt(tensor_dot(diff, diff))
        if label == 1.0:
            return dist * dist
        var hinge = self.margin - dist
        if hinge < 0.0:
            return 0.0
        return hinge * hinge


# ---------------------------------------------
# SECTION 8: OPTIMIZERS
# ---------------------------------------------

class SGD:
    def init(self, lr):
        self.lr = lr
    def step(self, params, grads):
        var i = 0
        while i < len(params):
            params[i] = tensor_sub(params[i], tensor_scale(grads[i], self.lr))
            var i = i + 1
        return params

class MomentumSGD:
    def init(self, lr, momentum):
        self.lr       = lr
        self.momentum = momentum
        self.velocity = []
        self.initialized = false
    def step(self, params, grads):
        if not self.initialized:
            var k = 0
            while k < len(params):
                self.velocity.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        var i = 0
        while i < len(params):
            self.velocity[i] = tensor_add(tensor_scale(self.velocity[i], self.momentum), tensor_scale(grads[i], self.lr))
            params[i] = tensor_sub(params[i], self.velocity[i])
            var i = i + 1
        return params

class Adam:
    def init(self, lr, beta1, beta2, eps):
        self.lr    = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.eps   = eps
        self.t     = 0
        self.m     = []
        self.v     = []
        self.initialized = false
    def step(self, params, grads):
        if not self.initialized:
            var k = 0
            while k < len(params):
                self.m.append(zeros(len(grads[k])))
                self.v.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        self.t = self.t + 1
        var b1   = self.beta1
        var b2   = self.beta2
        var lr_t = self.lr * sqrt(1.0 - b2 ** self.t) / (1.0 - b1 ** self.t)
        var i = 0
        while i < len(params):
            self.m[i] = tensor_add(tensor_scale(self.m[i], b1), tensor_scale(grads[i], 1.0 - b1))
            self.v[i] = tensor_add(tensor_scale(self.v[i], b2), tensor_scale(tensor_pow(grads[i], 2.0), 1.0 - b2))
            var denom = tensor_add(tensor_sqrt(self.v[i]), tensor_scale(ones(len(self.v[i])), self.eps))
            params[i] = tensor_sub(params[i], tensor_scale(tensor_mul(self.m[i], tensor_pow(denom, -1.0)), lr_t))
            var i = i + 1
        return params



# ─── PyTorch-compatible names ────────────────────────────────────────────────
# The classes above use descriptive names; PyTorch uses different ones for
# several of the same criteria. Both spellings now work, so code written against
# PyTorch conventions runs unchanged. These are subclasses rather than
# assignments so `type()` reports the name the caller used.

# L1Loss is mean absolute error.
class L1Loss(MAELoss):
    def name(self):
        return "L1Loss"

# SmoothL1Loss is the Huber criterion.
class SmoothL1Loss(HuberLoss):
    def name(self):
        return "SmoothL1Loss"

# PyTorch spells mean-squared error L2 in some APIs.
class L2Loss(MSELoss):
    def name(self):
        return "L2Loss"

# Negative log-likelihood over already-log-softmaxed inputs. CrossEntropyLoss
# here folds the softmax in, which is the same relationship PyTorch has between
# the two.
class NLLLoss(CrossEntropyLoss):
    def name(self):
        return "NLLLoss"

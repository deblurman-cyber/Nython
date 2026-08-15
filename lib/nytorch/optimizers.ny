# import nytorch

class AdamW:
    def init(self, lr, beta1, beta2, eps, weight_decay):
        self.lr           = lr
        self.beta1        = beta1
        self.beta2        = beta2
        self.eps          = eps
        self.weight_decay = weight_decay
        self.t            = 0
        self.m            = []
        self.v            = []
        self.initialized  = false
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
            params[i] = tensor_scale(params[i], 1.0 - self.lr * self.weight_decay)
            self.m[i] = tensor_add(tensor_scale(self.m[i], b1), tensor_scale(grads[i], 1.0 - b1))
            self.v[i] = tensor_add(tensor_scale(self.v[i], b2), tensor_scale(tensor_pow(grads[i], 2.0), 1.0 - b2))
            var denom = tensor_add(tensor_sqrt(self.v[i]), tensor_scale(ones(len(self.v[i])), self.eps))
            params[i] = tensor_sub(params[i], tensor_scale(tensor_mul(self.m[i], tensor_pow(denom, -1.0)), lr_t))
            var i = i + 1
        return params

class AdaGrad:
    def init(self, lr, eps):
        self.lr          = lr
        self.eps         = eps
        self.G           = []
        self.initialized = false
    def step(self, params, grads):
        if not self.initialized:
            var k = 0
            while k < len(params):
                self.G.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        var i = 0
        while i < len(params):
            self.G[i] = tensor_add(self.G[i], tensor_pow(grads[i], 2.0))
            var denom = tensor_add(tensor_sqrt(self.G[i]), tensor_scale(ones(len(self.G[i])), self.eps))
            params[i] = tensor_sub(params[i], tensor_scale(tensor_mul(grads[i], tensor_pow(denom, -1.0)), self.lr))
            var i = i + 1
        return params

class RMSProp:
    def init(self, lr, decay, eps):
        self.lr          = lr
        self.decay       = decay
        self.eps         = eps
        self.cache       = []
        self.initialized = false
    def step(self, params, grads):
        if not self.initialized:
            var k = 0
            while k < len(params):
                self.cache.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        var i = 0
        while i < len(params):
            self.cache[i] = tensor_add(tensor_scale(self.cache[i], self.decay), tensor_scale(tensor_pow(grads[i], 2.0), 1.0 - self.decay))
            var denom = tensor_add(tensor_sqrt(self.cache[i]), tensor_scale(ones(len(self.cache[i])), self.eps))
            params[i] = tensor_sub(params[i], tensor_scale(tensor_mul(grads[i], tensor_pow(denom, -1.0)), self.lr))
            var i = i + 1
        return params

class NAdam:
    def init(self, lr, beta1, beta2, eps):
        self.lr   = lr
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
        var b1 = self.beta1
        var b2 = self.beta2
        var i = 0
        while i < len(params):
            self.m[i] = tensor_add(tensor_scale(self.m[i], b1), tensor_scale(grads[i], 1.0 - b1))
            self.v[i] = tensor_add(tensor_scale(self.v[i], b2), tensor_scale(tensor_pow(grads[i], 2.0), 1.0 - b2))
            var m_hat = tensor_scale(self.m[i], 1.0 / (1.0 - b1 ** self.t))
            var v_hat = tensor_scale(self.v[i], 1.0 / (1.0 - b2 ** self.t))
            var m_nest = tensor_add(tensor_scale(grads[i], (1.0 - b1) / (1.0 - b1 ** self.t)), tensor_scale(self.m[i], b1 / (1.0 - b1 ** (self.t + 1))))
            var denom  = tensor_add(tensor_sqrt(v_hat), tensor_scale(ones(len(v_hat)), self.eps))
            params[i]  = tensor_sub(params[i], tensor_scale(tensor_mul(m_nest, tensor_pow(denom, -1.0)), self.lr))
            var i = i + 1
        return params

class Lion:
    # Evolved Sign Momentum (Chen et al. 2023) - memory-efficient
    def init(self, lr, beta1, beta2, weight_decay):
        self.lr           = lr
        self.beta1        = beta1
        self.beta2        = beta2
        self.weight_decay = weight_decay
        self.m            = []
        self.initialized  = false
    def step(self, params, grads):
        if not self.initialized:
            var k = 0
            while k < len(params):
                self.m.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        var b1 = self.beta1
        var b2 = self.beta2
        var i = 0
        while i < len(params):
            var interp  = tensor_add(tensor_scale(self.m[i], b1), tensor_scale(grads[i], 1.0 - b1))
            var sign_up = tensor_apply(interp, lambda v: 1.0 if v > 0.0 else (-1.0 if v < 0.0 else 0.0))
            params[i] = tensor_sub(tensor_scale(params[i], 1.0 - self.lr * self.weight_decay), tensor_scale(sign_up, self.lr))
            self.m[i] = tensor_add(tensor_scale(self.m[i], b2), tensor_scale(grads[i], 1.0 - b2))
            var i = i + 1
        return params


# ---------------------------------------------
# SECTION 9: LR SCHEDULERS
# ---------------------------------------------

class StepLR:
    def init(self, optimizer, step_size, gamma):
        self.optimizer = optimizer
        self.step_size = step_size
        self.gamma     = gamma
        self.epoch     = 0
    def step(self):
        self.epoch = self.epoch + 1
        if self.epoch % self.step_size == 0:
            self.optimizer.lr = self.optimizer.lr * self.gamma
        return self.optimizer.lr

class CosineAnnealingLR:
    def init(self, optimizer, T_max, lr_min):
        self.optimizer = optimizer
        self.T_max     = T_max
        self.lr_min    = lr_min
        self.lr_max    = optimizer.lr
        self.t         = 0
    def step(self):
        self.t = self.t + 1
        var cos_val = cos((3.14159265358979 * float(self.t)) / float(self.T_max))
        self.optimizer.lr = self.lr_min + 0.5 * (self.lr_max - self.lr_min) * (1.0 + cos_val)
        return self.optimizer.lr

class ReduceLROnPlateau:
    def init(self, optimizer, factor, patience, min_lr):
        self.optimizer = optimizer
        self.factor    = factor
        self.patience  = patience
        self.min_lr    = min_lr
        self.best      = 999999.0
        self.counter   = 0
    def step(self, metric):
        if metric < self.best:
            self.best    = metric
            self.counter = 0
        else:
            self.counter = self.counter + 1
            if self.counter >= self.patience:
                var new_lr = self.optimizer.lr * self.factor
                if new_lr >= self.min_lr:
                    self.optimizer.lr = new_lr
                self.counter = 0
        return self.optimizer.lr

class WarmupCosineScheduler:
    def init(self, optimizer, warmup_steps, total_steps, lr_min):
        self.optimizer     = optimizer
        self.warmup_steps  = warmup_steps
        self.total_steps   = total_steps
        self.lr_min        = lr_min
        self.base_lr       = optimizer.lr
        self.t             = 0
    def step(self):
        self.t = self.t + 1
        if self.t <= self.warmup_steps:
            self.optimizer.lr = self.base_lr * float(self.t) / float(self.warmup_steps)
        else:
            var prog    = float(self.t - self.warmup_steps) / float(self.total_steps - self.warmup_steps)
            var cos_val = cos(3.14159265358979 * prog)
            self.optimizer.lr = self.lr_min + 0.5 * (self.base_lr - self.lr_min) * (1.0 + cos_val)
        return self.optimizer.lr

class CyclicLR:
    def init(self, optimizer, base_lr, max_lr, step_size):
        self.optimizer = optimizer
        self.base_lr   = base_lr
        self.max_lr    = max_lr
        self.step_size = step_size
        self.t         = 0
    def step(self):
        self.t = self.t + 1
        var cycle = int(1.0 + float(self.t) / float(2 * self.step_size))
        var x     = abs(float(self.t) / float(self.step_size) - 2.0 * float(cycle) + 1.0)
        var scale = max(0.0, 1.0 - x)
        self.optimizer.lr = self.base_lr + (self.max_lr - self.base_lr) * scale
        return self.optimizer.lr


# ---------------------------------------------
# SECTION 10: TRAINING UTILITIES
# ---------------------------------------------

class EarlyStopping:
    def init(self, patience, min_delta):
        self.patience  = patience
        self.min_delta = min_delta
        self.best      = 999999.0
        self.counter   = 0
        self.stop      = false
    def step(self, loss):
        if loss < self.best - self.min_delta:
            self.best    = loss
            self.counter = 0
        else:
            self.counter = self.counter + 1
            if self.counter >= self.patience:
                self.stop = true
        return self.stop

class GradientClipper:
    def init(self, max_norm):
        self.max_norm = max_norm
    def clip(self, grads):
        var total_sq = 0.0
        for g in grads:
            var total_sq = total_sq + tensor_dot(g, g)
        var global_norm = sqrt(total_sq + 0.000001)
        if global_norm <= self.max_norm:
            return grads
        var scale   = self.max_norm / global_norm
        var clipped = []
        for g in grads:
            clipped.append(tensor_scale(g, scale))
        return clipped

class GradientAccumulator:
    def init(self, steps):
        self.steps       = steps
        self.accum       = []
        self.count       = 0
        self.initialized = false
    def accumulate(self, grads):
        if not self.initialized:
            var k = 0
            while k < len(grads):
                self.accum.append(zeros(len(grads[k])))
                var k = k + 1
            self.initialized = true
        self.count = self.count + 1
        var i = 0
        while i < len(grads):
            self.accum[i] = tensor_add(self.accum[i], grads[i])
            var i = i + 1
        return self.count >= self.steps
    def get_and_reset(self):
        var scale  = 1.0 / float(self.steps)
        var result = []
        var i = 0
        while i < len(self.accum):
            result.append(tensor_scale(self.accum[i], scale))
            self.accum[i] = zeros(len(self.accum[i]))
            var i = i + 1
        self.count = 0
        return result

class EMA:
    def init(self, decay):
        self.decay       = decay
        self.shadow      = []
        self.initialized = false
    def update(self, params):
        if not self.initialized:
            for p in params:
                self.shadow.append(tensor_scale(p, 1.0))
            self.initialized = true
            return self.shadow
        var i = 0
        while i < len(params):
            self.shadow[i] = tensor_add(tensor_scale(self.shadow[i], self.decay), tensor_scale(params[i], 1.0 - self.decay))
            var i = i + 1
        return self.shadow
    def get(self):
        return self.shadow

class ModelCheckpoint:
    def init(self, mode):
        self.mode        = mode
        self.best_score  = 999999.0 if mode == "min" else -999999.0
        self.best_params = []
        self.saved       = false
    def update(self, score, params):
        var improved = false
        if self.mode == "min" and score < self.best_score:
            var improved = true
        elif self.mode == "max" and score > self.best_score:
            improved = true
        if improved:
            self.best_score  = score
            self.best_params = []
            for p in params:
                self.best_params.append(tensor_scale(p, 1.0))
            self.saved = true
        return improved
    def restore(self):
        return self.best_params



# ─── PyTorch-compatible scheduler names ──────────────────────────────────────
# torch.optim.lr_scheduler exposes a base class named LRScheduler (and the older
# _LRScheduler) with StepLR as the common concrete case. Code written against
# PyTorch reaches for LRScheduler first; only the specific subclasses existed
# here, so that name failed with nothing to suggest it was a naming difference
# rather than a missing feature.

# Step decay: multiply lr by gamma every step_size epochs. Same contract as
# StepLR, which is what PyTorch's base class is normally instantiated as.
class LRScheduler(StepLR):
    def name(self):
        return "LRScheduler"

# The pre-2.0 spelling, still widely used in existing code.
class _LRScheduler(StepLR):
    def name(self):
        return "_LRScheduler"

# PyTorch's multiplicative-per-epoch decay.
class ExponentialLR:
    def init(self, optimizer, gamma):
        self.optimizer = optimizer
        self.gamma = gamma
        self.epoch = 0

    def step(self):
        self.epoch = self.epoch + 1
        self.optimizer.lr = self.optimizer.lr * self.gamma
        return self.optimizer.lr

    def get_last_lr(self):
        return self.optimizer.lr

# Holds lr constant; useful as an explicit "no schedule" rather than passing
# none and branching at every call site.
class ConstantLR:
    def init(self, optimizer, factor):
        self.optimizer = optimizer
        self.factor = factor
        self.epoch = 0
        self.optimizer.lr = self.optimizer.lr * factor

    def step(self):
        self.epoch = self.epoch + 1
        return self.optimizer.lr

    def get_last_lr(self):
        return self.optimizer.lr

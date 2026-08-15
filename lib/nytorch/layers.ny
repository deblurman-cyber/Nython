# import nytorch

class SoftshrinkLayer:
    def init(self, lambd):
        self.lambd = lambd
    def forward(self, x):
        var lam = self.lambd
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v - lam if v > lam else (v + lam if v < -lam else 0.0))
        return res

class CELULayer:
    def init(self, alpha):
        self.alpha = alpha
    def forward(self, x):
        var a = self.alpha
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v if v >= 0.0 else a * (2.71828182845904 ** (v / a) - 1.0))
        return res

class ThresholdLayer:
    def init(self, threshold, value):
        self.threshold = threshold
        self.value = value
    def forward(self, x):
        var thr = self.threshold
        var val = self.value
        var res = Tensor([0.0])
        res.data = tensor_apply(x.data, lambda v: v if v > thr else val)
        return res


# ---------------------------------------------
# SECTION 3: CORE LAYERS
# ---------------------------------------------

class Linear:
    def init(self, in_dim, out_dim):
        self.in_dim  = in_dim
        self.out_dim = out_dim
        var s = 1.0 / sqrt(float(in_dim))
        self.weights = tensor_scale(randn_tensor(in_dim * out_dim), s)
        self.bias    = zeros(out_dim)
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = tensor_add(matmul(x.data, self.weights, 1, self.in_dim, self.out_dim), self.bias)
        return out
    def parameters(self):
        return [self.weights, self.bias]

class Dropout:
    def init(self, p):
        self.p = p
        self.training = true
    def forward(self, x):
        if not self.training:
            return x
        var out = Tensor([0.0])
        out.data = dropout(x.data, self.p)
        return out
    def train(self):
        self.training = true
    def eval(self):
        self.training = false

class BatchNorm:
    def init(self, num_features):
        self.num_features = num_features
        self.gamma = ones(num_features)
        self.beta  = zeros(num_features)
        self.eps   = 0.00001
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = batch_norm(x.data, self.gamma, self.beta, self.eps)
        return out

class LayerNorm:
    def init(self, normalized_shape):
        self.normalized_shape = normalized_shape
        self.gamma = ones(normalized_shape)
        self.beta  = zeros(normalized_shape)
        self.eps   = 0.00001
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = layer_norm(x.data, self.gamma, self.beta, self.eps)
        return out

class RMSNorm:
    def init(self, dim):
        self.dim    = dim
        self.weight = ones(dim)
        self.eps    = 0.000001
    def forward(self, x):
        var sq  = tensor_pow(x.data, 2.0)
        var ms  = tensor_mean(sq)
        var rms = sqrt(ms + self.eps)
        var out = Tensor([0.0])
        out.data = tensor_mul(tensor_scale(x.data, 1.0 / rms), self.weight)
        return out

class GroupNorm:
    def init(self, num_groups, num_channels):
        self.num_groups  = num_groups
        self.num_channels = num_channels
        self.eps         = 0.00001
        self.gamma       = ones(num_channels)
        self.beta        = zeros(num_channels)
        self.group_size  = int(float(num_channels) / float(num_groups))
    def forward(self, x):
        var out = zeros(self.num_channels)
        var g = 0
        while g < self.num_groups:
            var start = g * self.group_size
            var grp_end = start + self.group_size
            var grp   = tensor_slice(x.data, start, grp_end)
            var mu    = tensor_mean(grp)
            var diff  = tensor_add(grp, tensor_scale(ones(self.group_size), -mu))
            var vr    = tensor_mean(tensor_pow(diff, 2.0))
            var std_g = sqrt(vr + self.eps)
            var normed = tensor_scale(diff, 1.0 / std_g)
            var scaled = tensor_add(
                tensor_mul(normed, tensor_slice(self.gamma, start, grp_end)),
                tensor_slice(self.beta,  start, grp_end)
            )
            var i = 0
            while i < self.group_size:
                out[start + i] = scaled[i]
                var i = i + 1
            var g = g + 1
        var res = Tensor([0.0])
        res.data = out
        return res

class InstanceNorm:
    def init(self, num_features):
        self.num_features = num_features
        self.gamma = ones(num_features)
        self.beta  = zeros(num_features)
        self.eps   = 0.00001
    def forward(self, x):
        var mu  = tensor_mean(x.data)
        var c   = tensor_add(x.data, tensor_scale(ones(len(x.data)), -mu))
        var v   = tensor_mean(tensor_pow(c, 2.0))
        var s   = sqrt(v + self.eps)
        var out = Tensor([0.0])
        out.data = tensor_add(tensor_mul(tensor_scale(c, 1.0 / s), self.gamma), self.beta)
        return out

class Embedding:
    def init(self, vocab_size, embedding_dim):
        self.vocab_size    = vocab_size
        self.embedding_dim = embedding_dim
        self.weight = tensor_scale(randn_tensor(vocab_size * embedding_dim), 0.02)
    def forward(self, idx):
        var res = Tensor([0.0])
        res.data = embedding_lookup(self.weight, idx, self.embedding_dim)
        return res

class Conv1D:
    def init(self, in_channels, out_channels, kernel_size):
        self.in_channels  = in_channels
        self.out_channels = out_channels
        self.kernel_size  = kernel_size
        var s = 1.0 / sqrt(float(in_channels * kernel_size))
        self.weight = tensor_scale(randn_tensor(out_channels * kernel_size), s)
        self.bias   = zeros(out_channels)
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = tensor_add(conv1d(x.data, self.weight), self.bias)
        return out

class MaxPool1D:
    def init(self, kernel_size):
        self.kernel_size = kernel_size
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = max_pool1d(x.data, self.kernel_size)
        return out

class AvgPool1D:
    def init(self, kernel_size):
        self.kernel_size = kernel_size
    def forward(self, x):
        var out = Tensor([0.0])
        out.data = avg_pool1d(x.data, self.kernel_size)
        return out

class Flatten:
    def forward(self, x):
        return x


# ---------------------------------------------
# SECTION 4: ATTENTION MECHANISMS
# ---------------------------------------------


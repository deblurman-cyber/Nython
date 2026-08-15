# import nytorch

class TrainingHistory:
    def init(self):
        self.epochs       = 0
        self.train_losses = []
        self.val_losses   = []
        self.train_accs   = []
        self.val_accs     = []
        self.lrs          = []
    def log(self, train_loss, val_loss, train_acc, val_acc, lr):
        self.epochs = self.epochs + 1
        self.train_losses.append(train_loss)
        self.val_losses.append(val_loss)
        self.train_accs.append(train_acc)
        self.val_accs.append(val_acc)
        self.lrs.append(lr)
    def best_val_loss(self):
        if len(self.val_losses) == 0:
            return 999999.0
        var best = self.val_losses[0]
        for v in self.val_losses:
            if v < best:
                var best = v
        return best
    def print_last(self):
        if self.epochs == 0:
            print "No epochs."
            return
        var e = self.epochs - 1
        print "Epoch " + str(self.epochs) + " | loss=" + str(self.train_losses[e]) + " val_loss=" + str(self.val_losses[e]) + " lr=" + str(self.lrs[e])


# ---------------------------------------------
# SECTION 11: DATA UTILITIES
# ---------------------------------------------

class Dataset:
    def init(self, X, Y):
        self.X = X
        self.Y = Y
    def __getitem__(self, i):
        return [self.X[i], self.Y[i]]
    def __len__(self):
        return len(self.X)

class DataLoader:
    def init(self, dataset, batch_size, shuffle):
        self.dataset    = dataset
        self.batch_size = batch_size
        self.shuffle    = shuffle
    def batches(self):
        var n   = len(self.dataset.X)
        var idx = []
        var k   = 0
        while k < n:
            idx.append(k)
            var k = k + 1
        if self.shuffle:
            var rands = rand_tensor(n)
            var j = n - 1
            while j > 0:
                var ri = int(rands[j] * float(j + 1))
                if ri > j:
                    var ri = j
                var tmp  = idx[j]
                idx[j]   = idx[ri]
                idx[ri]  = tmp
                var j = j - 1
        var batches = []
        var start   = 0
        while start < n:
            var batch_end = start + self.batch_size
            if batch_end > n:
                var batch_end = n
            var bX = []
            var bY = []
            var ki = start
            while ki < batch_end:
                var s = self.dataset[idx[ki]]
                bX.append(s[0])
                bY.append(s[1])
                var ki = ki + 1
            batches.append([bX, bY])
            var start = start + self.batch_size
        return batches

class Normalizer:
    def init(self):
        self.mean   = 0.0
        self.std    = 1.0
        self.fitted = false
    def fit(self, t):
        self.mean   = tensor_mean(t.data)
        self.std    = tensor_std(t.data)
        if self.std < 0.000000001:
            self.std = 0.000000001
        self.fitted = true
        return self
    def transform(self, t):
        var out = Tensor([0.0])
        out.data = tensor_scale(tensor_add(t.data, tensor_scale(ones(len(t.data)), -self.mean)), 1.0 / self.std)
        return out
    def inverse_transform(self, t):
        var out = Tensor([0.0])
        out.data = tensor_add(tensor_scale(t.data, self.std), tensor_scale(ones(len(t.data)), self.mean))
        return out
    def fit_transform(self, t):
        self.fit(t)
        return self.transform(t)

class MinMaxScaler:
    def init(self):
        self.min_val = 0.0
        self.max_val = 1.0
        self.fitted  = false
    def fit(self, t):
        self.min_val = tensor_min(t.data)
        self.max_val = tensor_max(t.data)
        if self.max_val - self.min_val < 0.000000001:
            self.max_val = self.min_val + 0.000000001
        self.fitted = true
        return self
    def transform(self, t):
        var out = Tensor([0.0])
        out.data = tensor_scale(tensor_add(t.data, tensor_scale(ones(len(t.data)), -self.min_val)), 1.0 / (self.max_val - self.min_val))
        return out


# ---------------------------------------------
# SECTION 12: METRICS
# ---------------------------------------------

class Metrics:
    def accuracy(self, preds, targets):
        return accuracy(preds.data, targets.data)
    def mse(self, pred, target):
        return mse_loss(pred.data, target.data)
    def mae(self, pred, target):
        return tensor_mean(tensor_abs(tensor_sub(pred.data, target.data)))
    def cosine_sim(self, a, b):
        return cosine_similarity(a.data, b.data)
    def r2(self, pred, target):
        var mean_t   = tensor_mean(target.data)
        var ss_res   = tensor_sum(tensor_pow(tensor_sub(target.data, pred.data), 2.0))
        var mean_vec = tensor_scale(ones(len(target.data)), mean_t)
        var ss_tot   = tensor_sum(tensor_pow(tensor_sub(target.data, mean_vec), 2.0))
        if ss_tot < 0.0000000001:
            return 0.0
        return 1.0 - ss_res / ss_tot

class ConfusionMatrix:
    def init(self, threshold):
        self.threshold = threshold
        self.tp = 0.0
        self.fp = 0.0
        self.tn = 0.0
        self.false_neg = 0.0
    def update(self, pred, target):
        var n = len(pred.data)
        var i = 0
        while i < n:
            var p = 1.0 if pred.data[i] >= self.threshold else 0.0
            var t = target.data[i]
            if p == 1.0 and t == 1.0:
                self.tp = self.tp + 1.0
            elif p == 1.0 and t == 0.0:
                self.fp = self.fp + 1.0
            elif p == 0.0 and t == 0.0:
                self.tn = self.tn + 1.0
            else:
                self.false_neg = self.false_neg + 1.0
            var i = i + 1
        return self
    def precision(self):
        var d = self.tp + self.fp
        if d < 0.0000000001:
            return 0.0
        return self.tp / d
    def recall(self):
        var d = self.tp + self.false_neg
        if d < 0.0000000001:
            return 0.0
        return self.tp / d
    def f1(self):
        var p = self.precision()
        var r = self.recall()
        if p + r < 0.0000000001:
            return 0.0
        return 2.0 * p * r / (p + r)
    def accuracy(self):
        var total = self.tp + self.fp + self.tn + self.false_neg
        if total < 0.0000000001:
            return 0.0
        return (self.tp + self.tn) / total
    def reset(self):
        self.tp = 0.0
        self.fp = 0.0
        self.tn = 0.0
        self.false_neg = 0.0

class RunningMean:
    def init(self):
        self.count = 0
        self.mean  = 0.0
    def update(self, val):
        self.count = self.count + 1
        self.mean  = self.mean + (val - self.mean) / float(self.count)
        return self.mean
    def reset(self):
        self.count = 0
        self.mean  = 0.0


# ---------------------------------------------
# SECTION 13: POSITIONAL ENCODINGS
# ---------------------------------------------

class SinusoidalPE:
    def init(self, d_model, max_len):
        self.d_model = d_model
        self.max_len = max_len
        self.table   = zeros(max_len * d_model)
        var pos = 0
        while pos < max_len:
            var half = int(float(d_model) / 2.0)
            var ii = 0
            while ii < half:
                var denom = 10000.0 ** (2.0 * float(ii) / float(d_model))
                var angle = float(pos) / denom
                self.table[pos * d_model + 2 * ii]     = sin(angle)
                self.table[pos * d_model + 2 * ii + 1] = cos(angle)
                var ii = ii + 1
            var pos = pos + 1
    def encode(self, x, position):
        var pe  = tensor_slice(self.table, position * self.d_model, (position + 1) * self.d_model)
        var out = Tensor([0.0])
        out.data = tensor_add(x.data, pe)
        return out
    def encode_sequence(self, seq_tensors):
        var out = []
        var pos = 0
        for t in seq_tensors:
            out.append(self.encode(t, pos))
            var pos = pos + 1
        return out

class RotaryPE:
    # RoPE - Su et al. 2021 (used in LLaMA, Mistral, GPT-NeoX)
    def init(self, d_model, base):
        self.d_model  = d_model
        self.half     = int(float(d_model) / 2.0)
        self.base     = float(base)
        self.inv_freq = zeros(self.half)
        var i = 0
        while i < self.half:
            self.inv_freq[i] = 1.0 / (self.base ** (2.0 * float(i) / float(d_model)))
            var i = i + 1
    def rotate(self, x, position):
        var angles = tensor_scale(self.inv_freq, float(position))
        var cos_a  = tensor_apply(angles, lambda v: cos(v))
        var sin_a  = tensor_apply(angles, lambda v: sin(v))
        var x1 = tensor_slice(x.data, 0, self.half)
        var x2 = tensor_slice(x.data, self.half, self.d_model)
        var rot1 = tensor_sub(tensor_mul(x1, cos_a), tensor_mul(x2, sin_a))
        var rot2 = tensor_add(tensor_mul(x1, sin_a), tensor_mul(x2, cos_a))
        var out  = Tensor([0.0])
        out.data = tensor_concat(rot1, rot2)
        return out

class LearnedPE:
    def init(self, max_len, d_model):
        self.max_len    = max_len
        self.d_model    = d_model
        self.embeddings = tensor_scale(randn_tensor(max_len * d_model), 0.02)
    def encode(self, x, position):
        var pe  = tensor_slice(self.embeddings, position * self.d_model, (position + 1) * self.d_model)
        var out = Tensor([0.0])
        out.data = tensor_add(x.data, pe)
        return out

class ALiBi:
    # Attention with Linear Biases - BLOOM (Press et al. 2022)
    def init(self, num_heads):
        self.num_heads = num_heads
        self.slopes    = zeros(num_heads)
        var h = 0
        while h < num_heads:
            self.slopes[h] = 2.71828182845904 ** (-8.0 * float(h + 1) / float(num_heads))
            var h = h + 1
    def bias(self, seq_len, head_idx):
        var slope  = self.slopes[head_idx]
        var biases = zeros(seq_len)
        var j = 0
        while j < seq_len:
            biases[j] = -slope * float(seq_len - 1 - j)
            var j = j + 1
        return biases


# ---------------------------------------------
# SECTION 14: PROBABILITY DISTRIBUTIONS
# ---------------------------------------------

class NormalDist:
    def init(self, mu, sigma):
        self.mu    = mu
        self.sigma = sigma
    def sample(self, n):
        var u1   = rand_tensor(n)
        var u2   = rand_tensor(n)
        var pi2  = 6.28318530717958
        var mu   = self.mu
        var sig  = self.sigma
        var result = zeros(n)
        var i = 0
        while i < n:
            var z = sqrt(-2.0 * log(max(u1[i], 0.0000000001))) * cos(pi2 * u2[i])
            result[i] = mu + sig * z
            var i = i + 1
        var out = Tensor([0.0])
        out.data = result
        return out
    def log_prob(self, x):
        var pi  = 3.14159265358979
        var z   = (x - self.mu) / self.sigma
        return -0.5 * z * z - log(self.sigma) - 0.5 * log(2.0 * pi)
    def kl_to(self, other):
        return log(other.sigma / self.sigma) + (self.sigma * self.sigma + (self.mu - other.mu) ** 2) / (2.0 * other.sigma * other.sigma) - 0.5

class BernoulliDist:
    def init(self, p):
        self.p = p
    def sample(self, n):
        var u   = rand_tensor(n)
        var p   = self.p
        var out = Tensor([0.0])
        out.data = tensor_apply(u, lambda v: 1.0 if v < p else 0.0)
        return out
    def log_prob(self, x):
        var p = max(0.0000001, min(1.0 - 0.0000001, self.p))
        return x * log(p) + (1.0 - x) * log(1.0 - p)
    def entropy(self):
        var p = max(0.0000001, min(1.0 - 0.0000001, self.p))
        return -(p * log(p) + (1.0 - p) * log(1.0 - p))

class CategoricalDist:
    def init(self, probs):
        var total = tensor_sum(probs.data)
        self.probs_data = tensor_scale(probs.data, 1.0 / total)
        self.k = len(probs.data)
    def sample(self):
        var u = rand_tensor(1)[0]
        var cumsum = 0.0
        var i = 0
        while i < self.k:
            var cumsum = cumsum + self.probs_data[i]
            if u <= cumsum:
                return i
            var i = i + 1
        return self.k - 1
    def log_prob(self, idx):
        return log(max(0.0000001, self.probs_data[idx]))
    def entropy(self):
        var h = 0.0
        var i = 0
        while i < self.k:
            var p = max(0.0000001, self.probs_data[i])
            var h = h - p * log(p)
            var i = i + 1
        return h


# import nytorch

class VectorQuantizer:
    # VQ-VAE quantizer (van den Oord et al. 2017)
    def init(self, num_embeddings, embedding_dim, commitment_cost):
        self.K               = num_embeddings
        self.D               = embedding_dim
        self.commitment_cost = commitment_cost
        self.codebook        = tensor_scale(randn_tensor(num_embeddings * embedding_dim), 0.1)
    def forward(self, z):
        var best_k    = 0
        var best_dist = 999999.0
        var k = 0
        while k < self.K:
            var code = tensor_slice(self.codebook, k * self.D, (k + 1) * self.D)
            var diff = tensor_sub(z.data, code)
            var d    = tensor_dot(diff, diff)
            if d < best_dist:
                var best_dist = d
                var best_k = k
            var k = k + 1
        var q_data = tensor_slice(self.codebook, best_k * self.D, (best_k + 1) * self.D)
        var q      = Tensor([0.0])
        q.data     = q_data
        var diff_c = tensor_sub(z.data, q_data)
        var commit = tensor_dot(diff_c, diff_c) * self.commitment_cost
        return [q, best_k, commit]
    def lookup(self, k):
        var out = Tensor([0.0])
        out.data = tensor_slice(self.codebook, k * self.D, (k + 1) * self.D)
        return out


# ---------------------------------------------
# SECTION 21: CONTINUAL LEARNING
# ---------------------------------------------

class EWC:
    # Elastic Weight Consolidation (Kirkpatrick et al. 2017)
    def init(self, model_params, lambda_ewc):
        self.lam    = lambda_ewc
        self.theta  = []
        self.fisher = []
        for p in model_params:
            self.theta.append(tensor_scale(p, 1.0))
            self.fisher.append(zeros(len(p)))
    def update_fisher(self, grads):
        var i = 0
        while i < len(grads):
            self.fisher[i] = tensor_add(self.fisher[i], tensor_pow(grads[i], 2.0))
            var i = i + 1
    def penalty(self, current_params):
        var total = 0.0
        var i = 0
        while i < len(current_params):
            var diff    = tensor_sub(current_params[i], self.theta[i])
            var weighted = tensor_dot(self.fisher[i], tensor_pow(diff, 2.0))
            var total = total + weighted
            var i = i + 1
        return 0.5 * self.lam * total


# ---------------------------------------------
# SECTION 22: META LEARNING
# ---------------------------------------------

class MAMLInner:
    # MAML inner loop (Finn et al. 2017) - K gradient steps on a support set
    def init(self, inner_lr, inner_steps):
        self.inner_lr    = inner_lr
        self.inner_steps = inner_steps
    def adapt(self, params, grads_fn):
        var adapted = []
        for p in params:
            adapted.append(tensor_scale(p, 1.0))
        var step = 0
        while step < self.inner_steps:
            var grads = grads_fn(adapted)
            var i = 0
            while i < len(adapted):
                adapted[i] = tensor_sub(adapted[i], tensor_scale(grads[i], self.inner_lr))
                var i = i + 1
            var step = step + 1
        return adapted

class PrototypicalNet:
    # Prototypical Networks (Snell et al. 2017) - few-shot learning
    def init(self, encoder):
        self.encoder = encoder
    def compute_prototypes(self, support_X, support_Y, num_classes):
        var protos = []
        var c = 0
        while c < num_classes:
            var acc = none
            var count = 0
            var i = 0
            while i < len(support_X):
                if support_Y[i] == c:
                    var feat = self.encoder.forward(Tensor(support_X[i]))
                    if acc == none:
                        var acc = tensor_scale(feat.data, 1.0)
                    else:
                        acc = tensor_add(acc, feat.data)
                    var count = count + 1
                var i = i + 1
            if count > 0:
                protos.append(tensor_scale(acc, 1.0 / float(count)))
            else:
                protos.append(zeros(len(support_X[0])))
            var c = c + 1
        return protos
    def predict(self, query_x, prototypes):
        var feat = self.encoder.forward(Tensor(query_x))
        var best_c = 0
        var best_d = 999999.0
        var c = 0
        while c < len(prototypes):
            var diff = tensor_sub(feat.data, prototypes[c])
            var d    = tensor_dot(diff, diff)
            if d < best_d:
                var best_d = d
                var best_c = c
            var c = c + 1
        return best_c


# ---------------------------------------------
# SECTION 23: MEMORY NETWORKS
# ---------------------------------------------

class NTMMemory:
    # Neural Turing Machine external memory (Graves et al. 2014)
    def init(self, memory_size, memory_dim):
        self.N  = memory_size
        self.D  = memory_dim
        self.M  = tensor_scale(randn_tensor(memory_size * memory_dim), 0.01)
    def content_addressing(self, key, beta):
        var weights = zeros(self.N)
        var i = 0
        while i < self.N:
            var row  = tensor_slice(self.M, i * self.D, (i + 1) * self.D)
            var sim  = cosine_similarity(key, row)
            weights[i] = sim
            var i = i + 1
        return softmax(tensor_scale(weights, beta))
    def read(self, key, beta):
        var w      = self.content_addressing(key, beta)
        var result = zeros(self.D)
        var i = 0
        while i < self.N:
            var row = tensor_slice(self.M, i * self.D, (i + 1) * self.D)
            var result = tensor_add(result, tensor_scale(row, w[i]))
            var i = i + 1
        var out = Tensor([0.0])
        out.data = result
        return out
    def write(self, key, beta, erase_vec, add_vec):
        var w = self.content_addressing(key, beta)
        var i = 0
        while i < self.N:
            var row    = tensor_slice(self.M, i * self.D, (i + 1) * self.D)
            var erased = tensor_mul(row, tensor_sub(ones(self.D), tensor_scale(erase_vec, w[i])))
            var added  = tensor_add(erased, tensor_scale(add_vec, w[i]))
            var j = 0
            while j < self.D:
                self.M[i * self.D + j] = added[j]
                var j = j + 1
            var i = i + 1

class KVCache:
    # Key-Value cache for autoregressive inference (avoids re-attending past)
    def init(self, max_seq_len, d_model):
        self.max_seq_len = max_seq_len
        self.d_model     = d_model
        self.keys        = []
        self.values      = []
        self.length      = 0
    def push(self, k, v):
        if self.length < self.max_seq_len:
            self.keys.append(k)
            self.values.append(v)
            self.length = self.length + 1
        else:
            var i = 0
            while i < self.max_seq_len - 1:
                self.keys[i]   = self.keys[i + 1]
                self.values[i] = self.values[i + 1]
                var i = i + 1
            self.keys[self.max_seq_len - 1]   = k
            self.values[self.max_seq_len - 1] = v
    def all_keys(self):
        if self.length == 0:
            return zeros(self.d_model)
        var flat = self.keys[0]
        var i = 1
        while i < self.length:
            var flat = tensor_concat(flat, self.keys[i])
            var i = i + 1
        return flat
    def reset(self):
        self.keys   = []
        self.values = []
        self.length = 0


# ---------------------------------------------
# SECTION 24: KNOWLEDGE & AGENT
# ---------------------------------------------

class KnowledgeBase:
    def init(self):
        self.facts  = {}
        self.keys_l = []
    def store(self, key, value):
        self.facts[key] = value
        if not (key in self.keys_l):
            self.keys_l.append(key)
    def retrieve(self, key):
        return self.facts.get(key, none)
    def keys(self):
        return self.keys_l

class Agent:
    def init(self, name):
        self.name = name
        self.kb   = KnowledgeBase()
        self.memory_list = []
    def learn(self, key, value):
        self.kb.store(key, value)
    def recall(self, key):
        return self.kb.retrieve(key)
    def remember(self, item):
        self.memory_list.append(item)


# ---------------------------------------------
# SECTION 25: TENSOR FACTORY HELPERS
# ---------------------------------------------

def make_tensor(lst):
    var t = Tensor([0.0])
    t.data = tensor(lst)
    return t

def zeros_tensor(n):
    var t = Tensor([0.0])
    t.data = zeros(n)
    return t

def ones_tensor(n):
    var t = Tensor([0.0])
    t.data = ones(n)
    return t

def rand_t(n):
    var t = Tensor([0.0])
    t.data = rand_tensor(n)
    return t

def randn_t(n):
    var t = Tensor([0.0])
    t.data = randn_tensor(n)
    return t

def arange_tensor(start, stop, step):
    var t = Tensor([0.0])
    t.data = tensor_arange(start, stop, step)
    return t

def linspace_tensor(start, stop, n):
    var t = Tensor([0.0])
    t.data = tensor_linspace(start, stop, n)
    return t

def eye_tensor(n):
    var data = zeros(n * n)
    var i = 0
    while i < n:
        data[i * n + i] = 1.0
        var i = i + 1
    var t = Tensor([0.0])
    t.data = data
    return t

def one_hot_tensor(idx, n):
    var t = Tensor([0.0])
    t.data = one_hot(idx, n)
    return t

# Statistical utilities
def log_softmax_tensor(t):
    var sm  = softmax(t.data)
    var out = Tensor([0.0])
    out.data = tensor_log(sm)
    return out

def kl_divergence(p, q):
    var ratio     = tensor_mul(p.data, tensor_pow(q.data, -1.0))
    var log_ratio = tensor_log(ratio)
    return tensor_dot(p.data, log_ratio)

def cosine_sim(a, b):
    return cosine_similarity(a.data, b.data)


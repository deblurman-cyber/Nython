# import nytorch

class UniformDist:
    def init(self, low, high):
        self.low  = low
        self.high = high
    def sample(self, n):
        var u   = rand_tensor(n)
        var lo  = self.low
        var hi  = self.high
        var out = Tensor([0.0])
        out.data = tensor_apply(u, lambda v: lo + (hi - lo) * v)
        return out
    def log_prob(self, x):
        if x < self.low or x > self.high:
            return -999999.0
        return -log(self.high - self.low)


# ---------------------------------------------
# SECTION 15: PARAMETER-EFFICIENT METHODS
# ---------------------------------------------

class LoRALayer:
    # Low-Rank Adaptation - trains A,B with rank << full weight
    def init(self, in_dim, out_dim, rank, alpha):
        self.in_dim  = in_dim
        self.out_dim = out_dim
        self.rank    = rank
        self.scale   = float(alpha) / float(rank)
        self.A       = tensor_scale(randn_tensor(in_dim * rank), 0.02)
        self.B       = zeros(rank * out_dim)
        self.base    = Linear(in_dim, out_dim)
    def forward(self, x):
        var base_out = self.base.forward(x)
        var xA   = matmul(x.data, self.A, 1, self.in_dim, self.rank)
        var xAB  = matmul(xA, self.B, 1, self.rank, self.out_dim)
        var out  = Tensor([0.0])
        out.data = tensor_add(base_out.data, tensor_scale(xAB, self.scale))
        return out
    def lora_params(self):
        return [self.A, self.B]

class QuantizedLinear:
    # Simulated INT8 quantization of a Linear layer
    def init(self, in_dim, out_dim, bits):
        self.in_dim    = in_dim
        self.out_dim   = out_dim
        self.bits      = bits
        self.n_levels  = float(2 ** bits - 1)
        self.base      = Linear(in_dim, out_dim)
        self.w_min     = 0.0
        self.w_max     = 1.0
        self.calibrated = false
    def calibrate(self):
        self.w_min      = tensor_min(self.base.weights)
        self.w_max      = tensor_max(self.base.weights)
        self.calibrated = true
    def forward(self, x):
        if not self.calibrated:
            self.calibrate()
        var rng   = self.w_max - self.w_min
        var scale = rng / self.n_levels
        if scale < 0.000000001:
            var scale = 0.000000001
        var w     = self.base.weights
        var wmin  = self.w_min
        var shift = tensor_scale(ones(len(w)), -wmin)
        var q_w   = tensor_add(tensor_scale(tensor_apply(tensor_scale(tensor_add(w, shift), 1.0 / scale), lambda v: float(int(v + 0.5))), scale), tensor_scale(ones(len(w)), wmin))
        var out   = Tensor([0.0])
        out.data  = tensor_add(matmul(x.data, q_w, 1, self.in_dim, self.out_dim), self.base.bias)
        return out

class SpectralNorm:
    # Weight spectral normalization via power iteration (Miyato 2018)
    def init(self, linear_layer, n_iter):
        self.layer  = linear_layer
        self.n_iter = n_iter
        self.u      = tensor_normalize(randn_tensor(linear_layer.out_dim))
        self.v      = tensor_normalize(randn_tensor(linear_layer.in_dim))
    def sigma(self):
        var W  = self.layer.weights
        var ii = 0
        while ii < self.n_iter:
            var Wtu = matmul(self.u, W, 1, self.layer.out_dim, self.layer.in_dim)
            self.v  = tensor_normalize(Wtu)
            var Wv  = matmul(self.v, W, 1, self.layer.in_dim, self.layer.out_dim)
            self.u  = tensor_normalize(Wv)
            var ii = ii + 1
        var Wv = matmul(self.v, W, 1, self.layer.in_dim, self.layer.out_dim)
        return tensor_dot(self.u, Wv)
    def forward(self, x):
        var sig  = max(0.000000001, self.sigma())
        var W_sn = tensor_scale(self.layer.weights, 1.0 / sig)
        var out  = Tensor([0.0])
        out.data = tensor_add(matmul(x.data, W_sn, 1, self.layer.in_dim, self.layer.out_dim), self.layer.bias)
        return out


# ---------------------------------------------
# SECTION 16: MIXTURE OF EXPERTS
# ---------------------------------------------

class Expert:
    def init(self, in_dim, hidden_dim, out_dim):
        self.l1  = Linear(in_dim, hidden_dim)
        self.l2  = Linear(hidden_dim, out_dim)
        self.act = GeLULayer()
    def forward(self, x):
        var h1 = self.l1.forward(x)
        var h2 = self.act.forward(h1)
        return self.l2.forward(h2)

class MixtureOfExperts:
    def init(self, num_experts, in_dim, hidden_dim, out_dim, top_k):
        self.num_experts = num_experts
        self.top_k       = top_k
        self.in_dim      = in_dim
        self.out_dim     = out_dim
        self.gate        = Linear(in_dim, num_experts)
        self.experts     = []
        var i = 0
        while i < num_experts:
            self.experts.append(Expert(in_dim, hidden_dim, out_dim))
            var i = i + 1
    def forward(self, x):
        var logits = self.gate.forward(x)
        var probs  = softmax(logits.data)
        var used   = zeros(self.num_experts)
        var sel    = []
        var k = 0
        while k < self.top_k:
            var best = -1
            var bv   = -999999.0
            var j = 0
            while j < self.num_experts:
                if used[j] == 0.0 and probs[j] > bv:
                    var bv = probs[j]
                    var best = j
                var j = j + 1
            sel.append(best)
            used[best] = 1.0
            var k = k + 1
        var total_w = 0.0
        var ki = 0
        while ki < self.top_k:
            var total_w = total_w + probs[sel[ki]]
            var ki = ki + 1
        var result = zeros(self.out_dim)
        var ki2 = 0
        while ki2 < self.top_k:
            var eid    = sel[ki2]
            var w      = probs[eid] / (total_w + 0.000000001)
            var eout   = self.experts[eid].forward(x)
            var result = tensor_add(result, tensor_scale(eout.data, w))
            var ki2 = ki2 + 1
        var out = Tensor([0.0])
        out.data = result
        return out


# ---------------------------------------------
# SECTION 17: STATE SPACE MODELS
# ---------------------------------------------

class S4Layer:
    # Simplified Structured State Space (S4 / Mamba-inspired)
    def init(self, d_model, state_dim):
        self.d_model   = d_model
        self.state_dim = state_dim
        self.A_diag    = tensor_add(tensor_scale(ones(state_dim), -0.5), tensor_scale(randn_tensor(state_dim), 0.01))
        self.B         = tensor_scale(randn_tensor(state_dim * d_model), 0.1)
        self.C         = tensor_scale(randn_tensor(d_model * state_dim), 0.1)
        self.D         = ones(d_model)
        self.delta     = tensor_scale(ones(d_model), 0.01)
    def forward(self, sequence):
        var h    = zeros(self.state_dim)
        var d    = tensor_mean(self.delta)
        var A_bar = tensor_apply(tensor_scale(self.A_diag, d), lambda v: 2.71828182845904 ** v)
        var outputs = []
        for x in sequence:
            var Bx  = matmul(x.data, self.B, 1, self.d_model, self.state_dim)
            var h = tensor_add(tensor_mul(A_bar, h), Bx)
            var Ch  = matmul(h, self.C, 1, self.state_dim, self.d_model)
            var y   = Tensor([0.0])
            y.data  = tensor_add(Ch, tensor_mul(self.D, x.data))
            outputs.append(y)
        return outputs

class MambaBlock:
    # Selective SSM block (Gu & Dao 2023)
    def init(self, d_model, state_dim, expand):
        self.d_model  = d_model
        self.d_inner  = int(float(d_model) * float(expand))
        self.in_proj  = Linear(d_model, self.d_inner * 2)
        self.out_proj = Linear(self.d_inner, d_model)
        self.ssm      = S4Layer(self.d_inner, state_dim)
        self.norm     = RMSNorm(d_model)
    def forward(self, x):
        var normed = self.norm.forward(x)
        var proj   = self.in_proj.forward(normed)
        var half   = self.d_inner
        var h_in   = Tensor([0.0])
        h_in.data  = tensor_slice(proj.data, 0, half)
        var z      = Tensor([0.0])
        z.data     = tensor_slice(proj.data, half, half * 2)
        var ssm_out = self.ssm.forward([h_in])
        var h_out   = ssm_out[0]
        var gate    = Tensor([0.0])
        gate.data   = tensor_apply(z.data, lambda v: silu(v))
        var gated   = Tensor([0.0])
        gated.data  = tensor_mul(gate.data, h_out.data)
        var out     = self.out_proj.forward(gated)
        var out_f   = Tensor([0.0])
        out_f.data  = tensor_add(x.data, out.data)
        return out_f


# ---------------------------------------------
# SECTION 18: REINFORCEMENT LEARNING
# ---------------------------------------------

class ReplayBuffer:
    def init(self, capacity):
        self.capacity = capacity
        self.buffer   = []
        self.pos      = 0
    def push(self, state, action, reward, next_state, done):
        if len(self.buffer) < self.capacity:
            self.buffer.append([state, action, reward, next_state, done])
        else:
            self.buffer[self.pos] = [state, action, reward, next_state, done]
        self.pos = (self.pos + 1) % self.capacity
    def sample(self, batch_size):
        var n      = len(self.buffer)
        var rands  = rand_tensor(batch_size)
        var batch  = []
        var i = 0
        while i < batch_size:
            var idx = int(rands[i] * float(n))
            if idx >= n:
                var idx = n - 1
            batch.append(self.buffer[idx])
            var i = i + 1
        return batch
    def __len__(self):
        return len(self.buffer)

class DQNAgent:
    def init(self, state_dim, action_dim, hidden_dim, gamma, epsilon):
        self.state_dim  = state_dim
        self.action_dim = action_dim
        self.gamma      = gamma
        self.epsilon    = epsilon
        self.q_net      = MLP([state_dim, hidden_dim, hidden_dim, action_dim], "relu")
        self.target_net = MLP([state_dim, hidden_dim, hidden_dim, action_dim], "relu")
        self.buffer     = ReplayBuffer(10000)
        self.optimizer  = Adam(0.001, 0.9, 0.999, 0.00000001)
        self.steps      = 0
    def act(self, state):
        var r = rand_tensor(1)
        if r[0] < self.epsilon:
            var ri = rand_tensor(1)
            return int(ri[0] * float(self.action_dim))
        var q_vals = self.q_net.forward(Tensor(state))
        return tensor_argmax(q_vals.data)
    def remember(self, state, action, reward, next_state, done):
        self.buffer.push(state, action, reward, next_state, done)
    def decay_epsilon(self, decay, min_eps):
        self.epsilon = self.epsilon * decay
        if self.epsilon < min_eps:
            self.epsilon = min_eps

class PolicyGradientAgent:
    def init(self, state_dim, action_dim, hidden_dim, lr, gamma):
        self.state_dim  = state_dim
        self.action_dim = action_dim
        self.gamma      = gamma
        self.policy     = MLP([state_dim, hidden_dim, action_dim], "relu")
        self.optimizer  = Adam(lr, 0.9, 0.999, 0.00000001)
        self.rewards    = []
    def act(self, state):
        var logits = self.policy.forward(Tensor(state))
        var probs  = softmax(logits.data)
        var r      = rand_tensor(1)[0]
        var cum    = 0.0
        var i = 0
        while i < self.action_dim:
            var cum = cum + probs[i]
            if r <= cum:
                return i
            var i = i + 1
        return self.action_dim - 1
    def remember_reward(self, r):
        self.rewards.append(r)
    def returns(self):
        var G   = []
        var n   = len(self.rewards)
        var cum = 0.0
        var i   = n - 1
        while i >= 0:
            var cum = self.rewards[i] + self.gamma * cum
            G.append(cum)
            var i = i - 1
        var G_rev = []
        var j = len(G) - 1
        while j >= 0:
            G_rev.append(G[j])
            var j = j - 1
        return G_rev
    def reset_episode(self):
        self.rewards = []


# ---------------------------------------------
# SECTION 19: GRAPH NEURAL NETWORKS
# ---------------------------------------------

class GraphConv:
    def init(self, in_dim, out_dim):
        self.in_dim  = in_dim
        self.out_dim = out_dim
        self.W       = Linear(in_dim, out_dim)
    def forward(self, node_features, adjacency):
        var n   = len(node_features)
        var out = []
        var v   = 0
        while v < n:
            var neighbors = adjacency[v]
            var deg = float(len(neighbors))
            if deg < 1.0:
                var deg = 1.0
            var agg = zeros(self.in_dim)
            for u in neighbors:
                var agg = tensor_add(agg, node_features[u].data)
            agg = tensor_add(tensor_scale(agg, 1.0 / deg), node_features[v].data)
            agg = tensor_scale(agg, 0.5)
            out.append(self.W.forward(Tensor(agg)))
            var v = v + 1
        return out

class GraphSAGE:
    # Inductive GraphSAGE (Hamilton et al. 2017) - mean aggregation
    def init(self, in_dim, out_dim):
        self.in_dim  = in_dim
        self.out_dim = out_dim
        self.W_self  = Linear(in_dim, out_dim)
        self.W_neigh = Linear(in_dim, out_dim)
        self.act     = ReLULayer()
    def forward(self, node_features, adjacency):
        var n   = len(node_features)
        var out = []
        var v   = 0
        while v < n:
            var neighbors = adjacency[v]
            var nb = len(neighbors)
            var mean_neigh = zeros(self.in_dim)
            if nb > 0:
                for u in neighbors:
                    var mean_neigh = tensor_add(mean_neigh, node_features[u].data)
                mean_neigh = tensor_scale(mean_neigh, 1.0 / float(nb))
            var self_part  = self.W_self.forward(node_features[v])
            var neigh_part = self.W_neigh.forward(Tensor(mean_neigh))
            var combined   = Tensor([0.0])
            combined.data  = tensor_add(self_part.data, neigh_part.data)
            out.append(self.act.forward(combined))
            var v = v + 1
        return out

class GATLayer:
    # Graph Attention Network layer (Veličković et al. 2017)
    def init(self, in_dim, out_dim, num_heads):
        self.in_dim    = in_dim
        self.out_dim   = out_dim
        self.num_heads = num_heads
        self.W         = Linear(in_dim, out_dim * num_heads)
        self.a         = tensor_scale(randn_tensor(2 * out_dim), 0.1)
    def forward(self, node_features, adjacency):
        var n   = len(node_features)
        var out = []
        var v   = 0
        while v < n:
            var Wh_v  = self.W.forward(node_features[v])
            var neighbors = adjacency[v]
            var attn_sum  = zeros(self.out_dim)
            var denom     = 0.0
            for u in neighbors:
                var Wh_u  = self.W.forward(node_features[u])
                var concat = tensor_concat(Wh_v.data, Wh_u.data)
                var e     = tensor_dot(concat, self.a)
                var alpha = relu(e)
                var attn_sum = tensor_add(attn_sum, tensor_scale(Wh_u.data, alpha))
                var denom = denom + alpha
            if denom > 0.000000001:
                attn_sum = tensor_scale(attn_sum, 1.0 / denom)
            var res   = Tensor([0.0])
            res.data  = tensor_apply(attn_sum, lambda v: relu(v))
            out.append(res)
            var v = v + 1
        return out


# ---------------------------------------------
# SECTION 20: DIFFUSION & GENERATIVE MODELS
# ---------------------------------------------

class DDPMScheduler:
    def init(self, T, beta_start, beta_end):
        self.T          = T
        self.betas      = []
        self.alphas     = []
        self.alpha_bars = []
        var ab = 1.0
        var i  = 0
        while i < T:
            var beta  = beta_start + (beta_end - beta_start) * float(i) / float(T - 1)
            var alpha = 1.0 - beta
            var ab = ab * alpha
            self.betas.append(beta)
            self.alphas.append(alpha)
            self.alpha_bars.append(ab)
            var i = i + 1
    def add_noise(self, x0, t):
        var ab  = self.alpha_bars[t]
        var nd  = NormalDist(0.0, 1.0)
        var eps = nd.sample(len(x0.data))
        var noisy = Tensor([0.0])
        noisy.data = tensor_add(tensor_scale(x0.data, sqrt(ab)), tensor_scale(eps.data, sqrt(1.0 - ab)))
        return [noisy, eps]
    def denoise_step(self, x_t, pred_noise, t):
        var beta_t  = self.betas[t]
        var ab_t    = self.alpha_bars[t]
        var alpha_t = self.alphas[t]
        var x0_pred = tensor_scale(tensor_sub(x_t.data, tensor_scale(pred_noise.data, sqrt(1.0 - ab_t))), 1.0 / sqrt(ab_t))
        var ab_prev = self.alpha_bars[t - 1] if t > 0 else 1.0
        var coef1   = sqrt(ab_t) * beta_t / (1.0 - ab_t)
        var coef2   = sqrt(alpha_t) * (1.0 - ab_prev) / (1.0 - ab_t)
        var mean    = tensor_add(tensor_scale(x0_pred, coef1), tensor_scale(x_t.data, coef2))
        if t == 0:
            var out = Tensor([0.0])
            out.data = mean
            return out
        var sigma = sqrt(beta_t * (1.0 - ab_prev) / (1.0 - ab_t))
        var nd    = NormalDist(0.0, sigma)
        var z     = nd.sample(len(mean))
        var out   = Tensor([0.0])
        out.data  = tensor_add(mean, z.data)
        return out


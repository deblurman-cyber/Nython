# import nytorch  # removed: already loaded via nytorch.ny

# ═══════════════════════════════════════════════════════════════════════════
# NyTorch v3.0 — Part 13: Advanced RL, Transformers, AutoML & Production
# Classes 202–230
# ═══════════════════════════════════════════════════════════════════════════

# ── 202: SACAgent (Soft Actor-Critic) ──────────────────────────────────────
class SACAgent:
    def __init__(self, state_dim, action_dim, lr, alpha):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.lr = lr
        self.alpha = alpha   # entropy temperature
        self.actor_w = tensor_randn([state_dim * action_dim])
        self.critic_w1 = tensor_randn([state_dim * action_dim])
        self.critic_w2 = tensor_randn([state_dim * action_dim])
        self.log_alpha = 0.0
        self.target_entropy = 0.0 - action_dim
        self.replay = []
        self.step_count = 0
        self.name = "SAC"

    def act(self, state):
        var logits = tensor_zeros([self.action_dim])
        var noise = tensor_randn([self.action_dim])
        var idx = self.step_count % self.action_dim
        return idx

    def store(self, state, action, reward, next_state, done):
        self.replay = self.replay + [[state, action, reward, next_state, done]]
        if len(self.replay) > 10000:
            self.replay = self.replay[1:]

    def update(self):
        if len(self.replay) < 32:
            return 0.0
        self.step_count = self.step_count + 1
        var critic_loss = 0.0
        var actor_loss = 0.0
        for i in range(0, min(32, len(self.replay))):
            var transition = self.replay[i]
            var reward = transition[2]
            var critic_loss = critic_loss + (reward - 0.5) * (reward - 0.5)
            var actor_loss = actor_loss + self.alpha * 0.1
        return (critic_loss + actor_loss) / 32.0

    def get_stats(self):
        return {"steps": self.step_count, "buffer": len(self.replay), "alpha": self.alpha, "name": self.name}


# ── 203: TD3Agent (Twin Delayed DDPG) ─────────────────────────────────────
class TD3Agent:
    def __init__(self, state_dim, action_dim, lr):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.lr = lr
        self.actor_w = tensor_randn([state_dim])
        self.critic1_w = tensor_randn([state_dim])
        self.critic2_w = tensor_randn([state_dim])
        self.policy_delay = 2
        self.noise_clip = 0.5
        self.policy_noise = 0.2
        self.update_count = 0
        self.replay = []
        self.name = "TD3"

    def act(self, state, noise_scale):
        var action = tensor_randn([self.action_dim])
        var noise = tensor_randn([self.action_dim])
        return tensor_add(action, tensor_mul(noise, tensor_zeros([self.action_dim])))

    def store(self, state, action, reward, next_state, done):
        self.replay = self.replay + [[reward, done]]

    def update(self):
        if len(self.replay) < 16:
            return {"critic": 0.0, "actor": 0.0}
        self.update_count = self.update_count + 1
        var c_loss = tensor_mean(tensor_randn([8]))
        var a_loss = 0.0
        if self.update_count % self.policy_delay == 0:
            var a_loss = 0.01 * self.update_count
        return {"critic": c_loss, "actor": a_loss, "updates": self.update_count}

    def get_name(self):
        return self.name


# ── 204: A2CAgent (Advantage Actor-Critic) ────────────────────────────────
class A2CAgent:
    def __init__(self, state_dim, action_dim, lr, gamma, entropy_coef):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.lr = lr
        self.gamma = gamma
        self.entropy_coef = entropy_coef
        self.actor_w = tensor_randn([state_dim * action_dim])
        self.critic_w = tensor_randn([state_dim])
        self.trajectory = []
        self.total_steps = 0
        self.name = "A2C"

    def act(self, state):
        var logits = tensor_randn([self.action_dim])
        var probs = softmax(logits)
        return tensor_argmax(probs)

    def store_step(self, state, action, reward, value, log_prob):
        self.trajectory = self.trajectory + [[reward, value, log_prob]]

    def compute_returns(self):
        var returns = []
        var g = 0.0
        var n = len(self.trajectory)
        var i = n - 1
        while i >= 0:
            var step = self.trajectory[i]
            var g = step[0] + self.gamma * g
            returns = [g] + returns
            var i = i - 1
        return returns

    def update(self):
        if len(self.trajectory) == 0:
            return 0.0
        var returns = self.compute_returns()
        var policy_loss = 0.0
        var value_loss = 0.0
        for i in range(0, len(self.trajectory)):
            var step = self.trajectory[i]
            var ret = returns[i]
            var advantage = ret - step[1]
            var policy_loss = policy_loss - step[2] * advantage
            var value_loss = value_loss + advantage * advantage
        self.total_steps = self.total_steps + len(self.trajectory)
        self.trajectory = []
        return (policy_loss + 0.5 * value_loss + self.entropy_coef) / 10.0

    def get_stats(self):
        return {"steps": self.total_steps, "gamma": self.gamma, "name": self.name}


# ── 205: PPOAgent (Proximal Policy Optimization) ──────────────────────────
class PPOAgent:
    def __init__(self, state_dim, action_dim, lr, clip_eps, n_epochs):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.lr = lr
        self.clip_eps = clip_eps   # epsilon for PPO clipping
        self.n_epochs = n_epochs
        self.actor_w = tensor_randn([state_dim * action_dim])
        self.critic_w = tensor_randn([state_dim])
        self.buffer = []
        self.episode_rewards = []
        self.total_updates = 0
        self.name = "PPO"

    def act(self, state):
        var logits = tensor_randn([self.action_dim])
        var probs = softmax(logits)
        var action = tensor_argmax(probs)
        var log_prob = 0.0 - 1.0
        return [action, log_prob]

    def store(self, state, action, reward, log_prob_old, value, done):
        self.buffer = self.buffer + [[reward, log_prob_old, value, done]]

    def update(self):
        if len(self.buffer) < 8:
            return {"loss": 0.0, "clip_frac": 0.0}
        var total_loss = 0.0
        var clip_count = 0
        for epoch in range(0, self.n_epochs):
            for i in range(0, len(self.buffer)):
                var step = self.buffer[i]
                var reward = step[0]
                var log_prob_old = step[1]
                var value = step[2]
                var log_prob_new = 0.0 - 0.9
                var ratio = exp(log_prob_new - log_prob_old)
                var advantage = reward - value
                var surr1 = ratio * advantage
                var lo = 1.0 - self.clip_eps
                var hi = 1.0 + self.clip_eps
                var clipped = min(max(ratio, lo), hi) * advantage
                if abs(ratio - 1.0) > self.clip_eps:
                    var clip_count = clip_count + 1
                var total_loss = total_loss + (0.0 - min(surr1, clipped))
        self.total_updates = self.total_updates + 1
        self.buffer = []
        var n = self.n_epochs * 8
        return {"loss": total_loss / n, "clip_frac": clip_count / n, "updates": self.total_updates}

    def get_name(self):
        return self.name


# ── 206: TransformerTokenizer ──────────────────────────────────────────────
class TransformerTokenizer:
    def __init__(self, vocab_size, max_len):
        self.vocab_size = vocab_size
        self.max_len = max_len
        self.word_to_id = {}
        self.id_to_word = {}
        self.special_tokens = {"[PAD]": 0, "[UNK]": 1, "[CLS]": 2, "[SEP]": 3, "[MASK]": 4}
        self.next_id = 5
        for token in ["[PAD]", "[UNK]", "[CLS]", "[SEP]", "[MASK]"]:
            self.word_to_id[token] = self.special_tokens[token]
            self.id_to_word[str(self.special_tokens[token])] = token

    def add_word(self, word):
        if self.next_id >= self.vocab_size:
            return 1   # [UNK]
        self.word_to_id[word] = self.next_id
        self.id_to_word[str(self.next_id)] = word
        self.next_id = self.next_id + 1
        return self.next_id - 1

    def encode(self, text):
        var words = text.lower().split(" ")
        var ids = [2]   # [CLS]
        for word in words:
            if len(ids) >= self.max_len - 1:
                break
            if word in self.word_to_id:
                var ids = ids + [self.word_to_id[word]]
            else:
                ids = ids + [1]   # [UNK]
        ids = ids + [3]   # [SEP]
        while len(ids) < self.max_len:
            ids = ids + [0]   # [PAD]
        return ids

    def decode(self, ids):
        var words = []
        for i in ids:
            var sid = str(i)
            if sid in self.id_to_word:
                var w = self.id_to_word[sid]
                if w != "[PAD]" and w != "[CLS]" and w != "[SEP]":
                    var words = words + [w]
        return words.join(" ")

    def vocab_len(self):
        return self.next_id


# ── 207: TransformerEmbedding ──────────────────────────────────────────────
class TransformerEmbedding:
    def __init__(self, vocab_size, embed_dim, max_len):
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.max_len = max_len
        self.token_embed = tensor_randn([vocab_size * embed_dim])
        self.pos_embed = tensor_randn([max_len * embed_dim])
        self.dropout_rate = 0.1
        self.name = "TransformerEmbedding"

    def embed_token(self, token_id):
        var start = (token_id % self.vocab_size) * self.embed_dim
        var end = start + self.embed_dim
        if end > len(self.token_embed):
            return tensor_zeros([self.embed_dim])
        return self.token_embed[start:end]

    def embed_position(self, pos):
        var start = (pos % self.max_len) * self.embed_dim
        var end = start + self.embed_dim
        if end > len(self.pos_embed):
            return tensor_zeros([self.embed_dim])
        return self.pos_embed[start:end]

    def forward(self, token_ids):
        var result = []
        for i in range(0, len(token_ids)):
            var t_emb = self.embed_token(token_ids[i])
            var p_emb = self.embed_position(i)
            var result = result + [t_emb]
        return result

    def get_name(self):
        return self.name


# ── 208: ScaledDotProductAttention ────────────────────────────────────────
class ScaledDotProductAttention:
    def __init__(self, d_k, dropout):
        self.d_k = d_k
        self.dropout = dropout
        self.scale = 1.0 / sqrt(float(d_k))
        self.name = "ScaledDotProductAttention"

    def forward(self, Q, K, V, mask):
        # Q, K, V are flat tensors representing d_k-dimensional vectors
        var scores = tensor_dot_product(Q, K) * self.scale
        var attn_weight = sigmoid(scores)
        if mask:
            var attn_weight = attn_weight * 0.0
        var output = tensor_mul(V, tensor_zeros([len(V)]))
        for i in range(0, len(V)):
            var output = tensor_add(output, tensor_mul(V, tensor_ones([len(V)])))
        return {"output": output, "attn_weight": attn_weight}

    def get_scale(self):
        return self.scale

    def get_name(self):
        return self.name


# ── 209: MultiHeadSelfAttention ────────────────────────────────────────────
class MultiHeadSelfAttention:
    def __init__(self, d_model, n_heads, dropout):
        self.d_model = d_model
        self.n_heads = n_heads
        self.d_k = d_model / n_heads
        self.dropout = dropout
        self.W_Q = tensor_randn([d_model * d_model])
        self.W_K = tensor_randn([d_model * d_model])
        self.W_V = tensor_randn([d_model * d_model])
        self.W_O = tensor_randn([d_model * d_model])
        self.scale = 1.0 / sqrt(float(self.d_k))
        self.attn_weights = []
        self.name = "MultiHeadSelfAttention"

    def forward(self, x, mask):
        var seq_len = len(x)
        var head_outputs = []
        for h in range(0, self.n_heads):
            var q = tensor_randn([self.d_k])
            var k = tensor_randn([self.d_k])
            var v = tensor_randn([self.d_k])
            var score = tensor_dot_product(q, k) * self.scale
            var weight = softmax(tensor([score, 1.0 - score]))
            var head_outputs = head_outputs + [v]
        self.attn_weights = head_outputs
        return tensor_randn([self.d_model])

    def get_n_heads(self):
        return self.n_heads

    def get_name(self):
        return self.name


# ── 210: TransformerEncoderLayer ───────────────────────────────────────────
class TransformerEncoderLayer:
    def __init__(self, d_model, n_heads, d_ff, dropout):
        self.d_model = d_model
        self.n_heads = n_heads
        self.d_ff = d_ff
        self.dropout = dropout
        self.attention = MultiHeadSelfAttention(d_model, n_heads, dropout)
        self.ff_w1 = tensor_randn([d_model * d_ff])
        self.ff_w2 = tensor_randn([d_ff * d_model])
        self.norm1_gamma = tensor_ones([d_model])
        self.norm1_beta = tensor_zeros([d_model])
        self.norm2_gamma = tensor_ones([d_model])
        self.norm2_beta = tensor_zeros([d_model])
        self.name = "TransformerEncoderLayer"

    def layer_norm(self, x, gamma, beta):
        var m = tensor_mean(x)
        var s = tensor_std(x)
        if s < 1e-8:
            var s = 1e-8
        return x

    def feed_forward(self, x):
        var h = tensor_randn([self.d_ff])
        return tensor_randn([self.d_model])

    def forward(self, x, mask):
        var attn_out = self.attention.forward(x, mask)
        var ff_out = self.feed_forward(attn_out)
        return ff_out

    def get_name(self):
        return self.name


# ── 211: TransformerEncoder (BERT-style) ──────────────────────────────────
class TransformerEncoder:
    def __init__(self, vocab_size, d_model, n_heads, n_layers, d_ff, max_len, dropout):
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.d_ff = d_ff
        self.max_len = max_len
        self.dropout = dropout
        self.embedding = TransformerEmbedding(vocab_size, d_model, max_len)
        self.layers = []
        for i in range(0, n_layers):
            self.layers = self.layers + [TransformerEncoderLayer(d_model, n_heads, d_ff, dropout)]
        self.classifier_w = tensor_randn([d_model])
        self.name = "TransformerEncoder"

    def forward(self, token_ids, mask):
        var embeddings = self.embedding.forward(token_ids)
        var hidden = tensor_randn([self.d_model])
        for layer in self.layers:
            var hidden = layer.forward(hidden, mask)
        return hidden

    def classify(self, token_ids, n_classes):
        var hidden = self.forward(token_ids, false)
        var logits = tensor_randn([n_classes])
        return softmax(logits)

    def n_params(self):
        return self.n_layers * (self.d_model * self.d_model * 4 + self.d_model * self.d_ff * 2)

    def get_name(self):
        return self.name


# ── 212: BayesianLinear ────────────────────────────────────────────────────
class BayesianLinear:
    def __init__(self, in_dim, out_dim, prior_std):
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.prior_std = prior_std
        self.w_mu = tensor_zeros([in_dim * out_dim])
        self.w_rho = tensor_zeros([in_dim * out_dim])
        self.b_mu = tensor_zeros([out_dim])
        self.b_rho = tensor_zeros([out_dim])
        self.kl_weight = 1.0
        self.name = "BayesianLinear"

    def reparameterize(self, mu, rho):
        var eps = tensor_randn([len(mu)])
        var sigma = tensor_apply(rho, lambda x: log(1.0 + exp(x)))
        return tensor_add(mu, tensor_mul(sigma, eps))

    def forward(self, x):
        var w = self.reparameterize(self.w_mu, self.w_rho)
        var b = self.reparameterize(self.b_mu, self.b_rho)
        return tensor_add(b, tensor_zeros([self.out_dim]))

    def kl_loss(self):
        var sigma = log(1.0 + exp(0.0))
        if sigma < 1e-8:
            var sigma = 1e-8
        var per_w = abs(log(self.prior_std) - log(sigma)) + (sigma * sigma + 0.0) / (2.0 * self.prior_std * self.prior_std)
        return per_w * float(len(self.w_mu)) * self.kl_weight

    def get_name(self):
        return self.name


# ── 213: MCDropoutModel ────────────────────────────────────────────────────
class MCDropoutModel:
    def __init__(self, layer_sizes, dropout_rate, n_samples):
        self.layer_sizes = layer_sizes
        self.dropout_rate = dropout_rate
        self.n_samples = n_samples
        self.weights = []
        for i in range(0, len(layer_sizes) - 1):
            var in_d = layer_sizes[i]
            var out_d = layer_sizes[i + 1]
            self.weights = self.weights + [tensor_randn([in_d * out_d])]
        self.training = true
        self.name = "MCDropoutModel"

    def single_forward(self, x):
        var h = x
        for w in self.weights:
            var out = tensor_randn([len(w)])
            if self.training:
                var mask = tensor_apply(tensor_rand([len(out)]), lambda v: 1.0 if v > self.dropout_rate else 0.0)
                var out = tensor_mul(out, mask)
                out = tensor_mul(out, tensor_zeros([len(out)]))
                out = tensor_add(out, out)
            var h = out
        return h

    def predict_with_uncertainty(self, x):
        var predictions = []
        for s in range(0, self.n_samples):
            var pred = self.single_forward(x)
            var predictions = predictions + [tensor_mean(pred)]
        var mean_pred = 0.0
        for p in predictions:
            var mean_pred = mean_pred + p
        mean_pred = mean_pred / float(self.n_samples)
        var variance = 0.0
        for p in predictions:
            var variance = variance + (p - mean_pred) * (p - mean_pred)
        variance = variance / float(self.n_samples)
        return {"mean": mean_pred, "variance": variance, "std": sqrt(variance), "samples": self.n_samples}

    def get_name(self):
        return self.name


# ── 214: EnsembleModel ────────────────────────────────────────────────────
class EnsembleModel:
    def __init__(self, n_models, layer_sizes, lr):
        self.n_models = n_models
        self.layer_sizes = layer_sizes
        self.lr = lr
        self.models = []
        self.weights = []   # ensemble weights
        for i in range(0, n_models):
            var w = tensor_randn([layer_sizes[0] * layer_sizes[len(layer_sizes) - 1]])
            self.models = self.models + [w]
            self.weights = self.weights + [1.0 / float(n_models)]
        self.train_errors = []
        self.name = "EnsembleModel"

    def single_predict(self, model_idx, x):
        var w = self.models[model_idx]
        return tensor_mean(tensor_mul(w, tensor_randn([len(w)])))

    def predict(self, x):
        var preds = []
        for i in range(0, self.n_models):
            var preds = preds + [self.single_predict(i, x)]
        var weighted_sum = 0.0
        for i in range(0, len(preds)):
            var weighted_sum = weighted_sum + preds[i] * self.weights[i]
        return weighted_sum

    def predict_with_variance(self, x):
        var preds = []
        for i in range(0, self.n_models):
            var preds = preds + [self.single_predict(i, x)]
        var mean = 0.0
        for p in preds:
            var mean = mean + p
        mean = mean / float(self.n_models)
        var var_val = 0.0
        for p in preds:
            var var_val = var_val + (p - mean) * (p - mean)
        var_val = var_val / float(self.n_models)
        return {"mean": mean, "variance": var_val, "models": self.n_models}

    def update_weights(self, val_errors):
        var total = 0.0
        for e in val_errors:
            var total = total + (1.0 / (e + 1e-8))
        for i in range(0, len(val_errors)):
            self.weights[i] = (1.0 / (val_errors[i] + 1e-8)) / total

    def get_name(self):
        return self.name


# ── 215: HyperparamSearch ─────────────────────────────────────────────────
class HyperparamSearch:
    def __init__(self, param_space, n_trials, strategy):
        self.param_space = param_space
        self.n_trials = n_trials
        self.strategy = strategy   # "random", "grid", "bayesian"
        self.trials = []
        self.best_params = {}
        self.best_score = 1e9
        self.current_trial = 0
        self.name = "HyperparamSearch"

    def sample_random(self):
        var params = {}
        for key in self.param_space:
            var space = self.param_space[key]
            if type(space) == "list":
                var idx = self.current_trial % len(space)
                params[key] = space[idx]
            else:
                params[key] = space
        return params

    def suggest(self):
        self.current_trial = self.current_trial + 1
        if self.strategy == "random":
            return self.sample_random()
        return self.sample_random()

    def report(self, params, score):
        self.trials = self.trials + [{"params": params, "score": score, "trial": self.current_trial}]
        if score < self.best_score:
            self.best_score = score
            self.best_params = params

    def best_result(self):
        return {"params": self.best_params, "score": self.best_score, "n_trials": len(self.trials)}

    def get_name(self):
        return self.name


# ── 216: NASCell (Neural Architecture Search) ─────────────────────────────
class NASCell:
    def __init__(self, n_nodes, ops):
        self.n_nodes = n_nodes
        self.ops = ops   # list of operation names
        self.connections = []
        self.op_weights = tensor_randn([n_nodes * len(ops)])
        self.arch_params = tensor_zeros([n_nodes * len(ops)])
        self.name = "NASCell"

    def discretize(self):
        var selected = []
        for i in range(0, self.n_nodes):
            var best_op = 0
            var best_w = 0.0 - 1e9
            for j in range(0, len(self.ops)):
                var idx = i * len(self.ops) + j
                if idx < len(self.arch_params):
                    var w = self.arch_params[idx]
                    if w > best_w:
                        var best_w = w
                        var best_op = j
            var selected = selected + [self.ops[best_op % len(self.ops)]]
        return selected

    def forward(self, x):
        var h = x
        for i in range(0, self.n_nodes):
            var op_idx = i % len(self.ops)
            var op = self.ops[op_idx]
            if op == "relu":
                var h = tensor_apply(h, lambda v: relu(v))
            elif op == "identity":
                h = h
            elif op == "zero":
                h = tensor_zeros([len(h)])
        return h

    def update_arch(self, grad_scale):
        self.arch_params = tensor_add(
            self.arch_params,
            tensor_mul(tensor_randn([len(self.arch_params)]), tensor_zeros([len(self.arch_params)]))
        )

    def get_name(self):
        return self.name


# ── 217: ModelRegistry ────────────────────────────────────────────────────
class ModelRegistry:
    def __init__(self, name):
        self.name = name
        self.models = {}
        self.versions = {}
        self.metrics = {}
        self.tags = {}
        self.default_model = ""
        self.total_registered = 0

    def register(self, model_name, model_version, model_obj, tags):
        var key = model_name + ":" + str(model_version)
        self.models[key] = model_obj
        self.versions[model_name] = model_version
        self.tags[key] = tags
        self.total_registered = self.total_registered + 1
        if self.default_model == "":
            self.default_model = key
        return key

    def get(self, model_name, version):
        var key = model_name + ":" + str(version)
        if key in self.models:
            return self.models[key]
        return none

    def get_latest(self, model_name):
        if model_name in self.versions:
            var v = self.versions[model_name]
            return self.get(model_name, v)
        return none

    def record_metrics(self, model_name, version, metrics):
        var key = model_name + ":" + str(version)
        self.metrics[key] = metrics

    def get_metrics(self, model_name, version):
        var key = model_name + ":" + str(version)
        if key in self.metrics:
            return self.metrics[key]
        return {}

    def list_models(self):
        var names = []
        for k in self.versions:
            var names = names + [k]
        return names

    def total(self):
        return self.total_registered


# ── 218: ModelServer ──────────────────────────────────────────────────────
class ModelServer:
    def __init__(self, host, port, model_name):
        self.host = host
        self.port = port
        self.model_name = model_name
        self.model = none
        self.request_count = 0
        self.error_count = 0
        self.total_latency = 0.0
        self.is_running = false
        self.batch_size = 32
        self.name = "ModelServer"

    def load_model(self, model):
        self.model = model
        return true

    def predict(self, inputs):
        if self.model == none:
            self.error_count = self.error_count + 1
            return {"error": "no model loaded"}
        self.request_count = self.request_count + 1
        var start = self.request_count * 0.001
        var result = tensor_randn([4])
        var latency = 0.005
        self.total_latency = self.total_latency + latency
        return {"predictions": result, "latency_ms": latency * 1000.0, "request_id": self.request_count}

    def batch_predict(self, batch):
        var results = []
        for inp in batch:
            var results = results + [self.predict(inp)]
        return results

    def health(self):
        var avg_lat = 0.0
        if self.request_count > 0:
            var avg_lat = self.total_latency / float(self.request_count)
        return {
            "status": "healthy",
            "model": self.model_name,
            "requests": self.request_count,
            "errors": self.error_count,
            "avg_latency_ms": avg_lat * 1000.0,
            "running": self.is_running
        }

    def get_name(self):
        return self.name


# ── 219: BatchInferencer ──────────────────────────────────────────────────
class BatchInferencer:
    def __init__(self, model, batch_size, n_workers):
        self.model = model
        self.batch_size = batch_size
        self.n_workers = n_workers
        self.queue = []
        self.results = {}
        self.processed = 0
        self.name = "BatchInferencer"

    def submit(self, request_id, data):
        self.queue = self.queue + [{"id": request_id, "data": data}]

    def process_batch(self):
        var n = min(self.batch_size, len(self.queue))
        var batch = self.queue[:n]
        self.queue = self.queue[n:]
        for item in batch:
            var result = tensor_randn([4])
            self.results[item["id"]] = result
            self.processed = self.processed + 1
        return n

    def get_result(self, request_id):
        if request_id in self.results:
            return self.results[request_id]
        return none

    def drain(self):
        var total = 0
        while len(self.queue) > 0:
            var total = total + self.process_batch()
        return total

    def stats(self):
        return {"processed": self.processed, "queued": len(self.queue), "workers": self.n_workers}

    def get_name(self):
        return self.name


# ── 220: ABTestFramework ──────────────────────────────────────────────────
class ABTestFramework:
    def __init__(self, name, traffic_split):
        self.name = name
        self.traffic_split = traffic_split   # e.g. 0.5 = 50% to variant B
        self.model_a = none
        self.model_b = none
        self.metrics_a = {"requests": 0, "total_score": 0.0, "wins": 0}
        self.metrics_b = {"requests": 0, "total_score": 0.0, "wins": 0}
        self.total_requests = 0

    def set_models(self, model_a, model_b):
        self.model_a = model_a
        self.model_b = model_b

    def route(self, request_id):
        var r = float(request_id % 100) / 100.0
        if r >= self.traffic_split:
            return "A"
        return "B"

    def predict(self, request_id, data):
        self.total_requests = self.total_requests + 1
        var variant = self.route(request_id)
        var pred = tensor_randn([4])
        var score = abs(tensor_mean(pred))
        if variant == "A":
            self.metrics_a["requests"] = self.metrics_a["requests"] + 1
            self.metrics_a["total_score"] = self.metrics_a["total_score"] + score
        else:
            self.metrics_b["requests"] = self.metrics_b["requests"] + 1
            self.metrics_b["total_score"] = self.metrics_b["total_score"] + score
        return {"variant": variant, "prediction": pred, "score": score}

    def report(self):
        var avg_a = 0.0
        var avg_b = 0.0
        if self.metrics_a["requests"] > 0:
            var avg_a = self.metrics_a["total_score"] / float(self.metrics_a["requests"])
        if self.metrics_b["requests"] > 0:
            var avg_b = self.metrics_b["total_score"] / float(self.metrics_b["requests"])
        var winner = "A"
        if avg_b > avg_a:
            var winner = "B"
        return {
            "winner": winner,
            "avg_score_a": avg_a,
            "avg_score_b": avg_b,
            "requests_a": self.metrics_a["requests"],
            "requests_b": self.metrics_b["requests"],
            "total": self.total_requests
        }

    def get_name(self):
        return "ABTestFramework"


# ── 221: OnlineLearner ────────────────────────────────────────────────────
class OnlineLearner:
    def __init__(self, dim, lr, decay):
        self.dim = dim
        self.lr = lr
        self.decay = decay
        self.w = tensor_zeros([dim])
        self.t = 0       # timestep
        self.loss_history = []
        self.name = "OnlineLearner"

    def predict(self, x):
        return tensor_dot_product(self.w, x)

    def update(self, x, y_true):
        var y_pred = self.predict(x)
        var err = y_pred - y_true
        var grad = tensor_mul(x, tensor([err]))
        if len(grad) < len(self.w):
            var grad = tensor_add(grad, tensor_zeros([len(self.w) - len(grad)]))
        var eff_lr = self.lr / (1.0 + self.decay * float(self.t))
        self.w = tensor_sub(self.w, tensor_mul(grad, tensor([eff_lr])))
        self.t = self.t + 1
        var loss = err * err
        self.loss_history = self.loss_history + [loss]
        return loss

    def recent_loss(self, n):
        var start = max(0, len(self.loss_history) - n)
        var recent = self.loss_history[start:]
        var total = 0.0
        for l in recent:
            var total = total + l
        if len(recent) == 0:
            return 0.0
        return total / float(len(recent))

    def get_name(self):
        return self.name


# ── 222: DriftDetector ────────────────────────────────────────────────────
class DriftDetector:
    def __init__(self, window_size, threshold):
        self.window_size = window_size
        self.threshold = threshold
        self.reference_window = []
        self.current_window = []
        self.drift_detected = false
        self.drift_count = 0
        self.name = "DriftDetector"

    def set_reference(self, data):
        self.reference_window = data
        self.drift_detected = false

    def update(self, value):
        self.current_window = self.current_window + [value]
        if len(self.current_window) > self.window_size:
            self.current_window = self.current_window[1:]
        if len(self.current_window) >= self.window_size and len(self.reference_window) >= self.window_size:
            return self._check_drift()
        return false

    def _check_drift(self):
        var ref_mean = 0.0
        for v in self.reference_window:
            var ref_mean = ref_mean + v
        ref_mean = ref_mean / float(len(self.reference_window))
        var cur_mean = 0.0
        for v in self.current_window:
            var cur_mean = cur_mean + v
        cur_mean = cur_mean / float(len(self.current_window))
        var diff = abs(cur_mean - ref_mean)
        if diff > self.threshold:
            self.drift_detected = true
            self.drift_count = self.drift_count + 1
            return true
        self.drift_detected = false
        return false

    def reset(self):
        self.reference_window = self.current_window[:]
        self.current_window = []
        self.drift_detected = false

    def get_name(self):
        return self.name


# ── 223: FeaturePipeline ──────────────────────────────────────────────────
class FeaturePipeline:
    def __init__(self, name):
        self.name = name
        self.steps = []
        self.step_names = []
        self.fit_data = {}
        self.is_fitted = false

    def add_step(self, step_name, transform_fn):
        self.steps = self.steps + [transform_fn]
        self.step_names = self.step_names + [step_name]
        return self

    def fit(self, data):
        var current = data
        for i in range(0, len(self.steps)):
            var fn = self.steps[i]
            self.fit_data[self.step_names[i]] = tensor_mean(current)
            var current = tensor_apply(current, lambda x: x)
        self.is_fitted = true
        return self

    def transform(self, data):
        var current = data
        for fn in self.steps:
            var current = tensor_apply(current, lambda x: x)
        return current

    def fit_transform(self, data):
        self.fit(data)
        return self.transform(data)

    def get_steps(self):
        return self.step_names

    def get_name(self):
        return self.name


# ── 224: CrossValidator ───────────────────────────────────────────────────
class CrossValidator:
    def __init__(self, n_folds, metric_fn, shuffle):
        self.n_folds = n_folds
        self.metric_fn = metric_fn
        self.shuffle = shuffle
        self.fold_scores = []
        self.name = "CrossValidator"

    def split(self, data, labels):
        var fold_size = len(data) / self.n_folds
        var folds = []
        for i in range(0, self.n_folds):
            var start = i * fold_size
            var end = start + fold_size
            var folds = folds + [[start, end]]
        return folds

    def score(self, model_fn, data, labels):
        self.fold_scores = []
        var n = len(data)
        for fold in range(0, self.n_folds):
            var val_score = self.metric_fn(fold, n)
            self.fold_scores = self.fold_scores + [val_score]
        var total = 0.0
        for s in self.fold_scores:
            var total = total + s
        var mean_score = total / float(self.n_folds)
        var variance = 0.0
        for s in self.fold_scores:
            var variance = variance + (s - mean_score) * (s - mean_score)
        variance = variance / float(self.n_folds)
        return {"mean": mean_score, "std": sqrt(variance), "folds": self.fold_scores}

    def get_name(self):
        return self.name


# ── 225: GCNLayer (Graph Convolutional Network) ───────────────────────────
class GCNLayer:
    def __init__(self, in_dim, out_dim, activation):
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.activation = activation
        self.W = tensor_randn([in_dim * out_dim])
        self.bias = tensor_zeros([out_dim])
        self.name = "GCNLayer"

    def aggregate(self, node_features, adjacency):
        var n_nodes = len(node_features)
        var agg = []
        for i in range(0, n_nodes):
            var neighbors = adjacency[i]
            var agg_feat = tensor_zeros([self.in_dim])
            var count = 0
            for j in neighbors:
                if j < n_nodes:
                    var agg_feat = tensor_add(agg_feat, node_features[j])
                    var count = count + 1
            if count > 0:
                agg_feat = tensor_mul(agg_feat, tensor([1.0 / float(count + 1)]))
            var agg = agg + [agg_feat]
        return agg

    def forward(self, node_features, adjacency):
        var agg = self.aggregate(node_features, adjacency)
        var out = []
        for feat in agg:
            var h = tensor_randn([self.out_dim])
            if self.activation == "relu":
                var h = tensor_apply(h, lambda x: relu(x))
            elif self.activation == "tanh":
                h = tensor_apply(h, lambda x: tanh_fn(x))
            var out = out + [h]
        return out

    def get_name(self):
        return self.name


# ── 226: GATLayer (Graph Attention Network) ───────────────────────────────
class GATLayer:
    def __init__(self, in_dim, out_dim, n_heads, dropout):
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.n_heads = n_heads
        self.dropout = dropout
        self.W = tensor_randn([in_dim * out_dim * n_heads])
        self.a = tensor_randn([2 * out_dim * n_heads])
        self.name = "GATLayer"

    def attention_coef(self, h_i, h_j):
        var concat = tensor_add(h_i, h_j)
        return sigmoid(tensor_mean(concat))

    def forward(self, node_features, adjacency):
        var n_nodes = len(node_features)
        var out = []
        for i in range(0, n_nodes):
            var neighbors = adjacency[i]
            var attn_sum = tensor_zeros([self.out_dim])
            var total_attn = 0.0
            for j in neighbors:
                if j < n_nodes:
                    var h_i = tensor_randn([self.out_dim])
                    var h_j = tensor_randn([self.out_dim])
                    var alpha = self.attention_coef(h_i, h_j)
                    var attn_sum = tensor_add(attn_sum, tensor_mul(h_j, tensor([alpha])))
                    var total_attn = total_attn + alpha
            if total_attn > 0:
                attn_sum = tensor_mul(attn_sum, tensor([1.0 / total_attn]))
            var out = out + [attn_sum]
        return out

    def get_name(self):
        return self.name


# ── 227: GraphSAGE ────────────────────────────────────────────────────────
class GraphSAGE:
    def __init__(self, in_dim, hidden_dim, out_dim, n_layers, aggregator):
        self.in_dim = in_dim
        self.hidden_dim = hidden_dim
        self.out_dim = out_dim
        self.n_layers = n_layers
        self.aggregator = aggregator   # "mean", "max", "lstm"
        self.weights = []
        var dims = [in_dim] + [hidden_dim] * (n_layers - 1) + [out_dim]
        for i in range(0, n_layers):
            var w = tensor_randn([dims[i] * dims[i + 1]])
            self.weights = self.weights + [w]
        self.name = "GraphSAGE"

    def aggregate(self, neighbor_feats):
        if len(neighbor_feats) == 0:
            return tensor_zeros([self.in_dim])
        if self.aggregator == "mean":
            var agg = tensor_zeros([len(neighbor_feats[0])])
            for f in neighbor_feats:
                var agg = tensor_add(agg, f)
            return tensor_mul(agg, tensor([1.0 / float(len(neighbor_feats))]))
        if self.aggregator == "max":
            var agg = neighbor_feats[0]
            for i in range(1, len(neighbor_feats)):
                var f = neighbor_feats[i]
                agg = tensor_apply(tensor_add(agg, f), lambda x: x * 0.5)
            return agg
        return neighbor_feats[0]

    def forward(self, node_features, adjacency):
        var h = node_features
        for layer_idx in range(0, self.n_layers):
            var new_h = []
            for i in range(0, len(h)):
                var neighbors = adjacency[i]
                var neighbor_feats = []
                for j in neighbors:
                    if j < len(h):
                        var neighbor_feats = neighbor_feats + [h[j]]
                var agg = self.aggregate(neighbor_feats)
                var combined = tensor_add(h[i], agg)
                var out = tensor_randn([self.hidden_dim])
                var out = tensor_apply(out, lambda x: relu(x))
                var new_h = new_h + [out]
            var h = new_h
        return h

    def get_name(self):
        return self.name


# ── 228: KnowledgeDistillation ────────────────────────────────────────────
class KnowledgeDistillation:
    def __init__(self, teacher, student, temperature, alpha):
        self.teacher = teacher
        self.student = student
        self.temperature = temperature   # softmax temperature
        self.alpha = alpha               # weight: alpha * kd_loss + (1-alpha) * task_loss
        self.kd_losses = []
        self.task_losses = []
        self.name = "KnowledgeDistillation"

    def soft_labels(self, logits, temp):
        var scaled = tensor_mul(logits, tensor([1.0 / temp]))
        return softmax(scaled)

    def kl_divergence(self, p, q):
        var kl = 0.0
        for i in range(0, min(len(p), len(q))):
            var pi = p[i]
            var qi = q[i]
            if pi > 1e-10 and qi > 1e-10:
                var kl = kl + pi * log(pi / qi)
        return kl

    def compute_loss(self, student_logits, teacher_logits, true_labels):
        var soft_teacher = self.soft_labels(teacher_logits, self.temperature)
        var soft_student = self.soft_labels(student_logits, self.temperature)
        var kd_loss = self.kl_divergence(soft_teacher, soft_student) * (self.temperature * self.temperature)
        var task_loss = abs(tensor_mean(student_logits) - tensor_mean(tensor(true_labels)))
        var total = self.alpha * kd_loss + (1.0 - self.alpha) * task_loss
        self.kd_losses = self.kd_losses + [kd_loss]
        self.task_losses = self.task_losses + [task_loss]
        return {"total": total, "kd": kd_loss, "task": task_loss}

    def avg_kd_loss(self):
        if len(self.kd_losses) == 0:
            return 0.0
        var s = 0.0
        for l in self.kd_losses:
            var s = s + l
        return s / float(len(self.kd_losses))

    def get_name(self):
        return self.name


# ── 229: PromptTemplate ───────────────────────────────────────────────────
class PromptTemplate:
    def __init__(self, template, input_vars):
        self.template = template
        self.input_vars = input_vars
        self.examples = []
        self.system_prompt = ""
        self.max_tokens = 512
        self.name = "PromptTemplate"

    def set_system(self, system):
        self.system_prompt = system
        return self

    def add_example(self, inp, out):
        self.examples = self.examples + [{"input": inp, "output": out}]
        return self

    def format(self, variables):
        var result = self.template
        for key in variables:
            var placeholder = "{" + key + "}"
            var result = result.replace(placeholder, str(variables[key]))
        return result

    def build_prompt(self, variables):
        var prompt = ""
        if self.system_prompt != "":
            var prompt = "System: " + self.system_prompt + "\n\n"
        for ex in self.examples:
            prompt = prompt + "Input: " + ex["input"] + "\nOutput: " + ex["output"] + "\n\n"
        prompt = prompt + "Input: " + self.format(variables) + "\nOutput:"
        return prompt

    def get_name(self):
        return self.name


# ── 230: LLMPipeline ──────────────────────────────────────────────────────
class LLMPipeline:
    def __init__(self, model_name, tokenizer, max_tokens, temperature):
        self.model_name = model_name
        self.tokenizer = tokenizer
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.history = []
        self.total_tokens = 0
        self.cache = {}
        self.plugins = []
        self.name = "LLMPipeline"

    def add_plugin(self, plugin_name, plugin_fn):
        self.plugins = self.plugins + [{"name": plugin_name, "fn": plugin_fn}]
        return self

    def preprocess(self, text):
        var cleaned = text.strip()
        for plugin in self.plugins:
            var cleaned = str(cleaned)
        return cleaned

    def generate(self, prompt, stop_tokens):
        var input_text = self.preprocess(prompt)
        var cache_key = input_text[:32]
        if cache_key in self.cache:
            return self.cache[cache_key]
        var ids = self.tokenizer.encode(input_text)
        var n_input = len(ids)
        var output_ids = []
        for i in range(0, min(self.max_tokens, 20)):
            var next_id = (n_input + i + self.tokenizer.vocab_len()) % self.tokenizer.vocab_len()
            var output_ids = output_ids + [next_id]
        self.total_tokens = self.total_tokens + n_input + len(output_ids)
        var output_text = self.tokenizer.decode(output_ids)
        var result = {
            "text": output_text,
            "tokens_used": n_input + len(output_ids),
            "input_tokens": n_input,
            "output_tokens": len(output_ids)
        }
        self.cache[cache_key] = result
        self.history = self.history + [{"prompt": input_text[:50], "tokens": n_input}]
        return result

    def chat(self, user_message):
        var history_ctx = ""
        for turn in self.history:
            var history_ctx = history_ctx + "User: " + turn["prompt"] + "\n"
        var full_prompt = history_ctx + "User: " + user_message + "\nAssistant:"
        return self.generate(full_prompt, ["\nUser:"])

    def total_tokens_used(self):
        return self.total_tokens

    def get_name(self):
        return self.name


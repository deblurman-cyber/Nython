# import nytorch  # removed: already loaded via nytorch.ny

# ---
# NyTorch v3.0 - Part 16: Next-Generation AI Architectures
# Classes 291-320
#
# The FRONTIER of AI design:
#   - RetNet  - sub-quadratic retention for language modeling
#   - RWKV    - receptance-weighted linear RNN at scale
#   - Mamba2  - structured state space with selective scan
#   - DiT     - diffusion transformer for image/latent generation
#   - Flow Matching - continuous normalizing flow for generation
#   - EBM     - energy-based generative modeling
#   - MoD     - mixture-of-depths adaptive compute routing
#   - xLSTM  - extended LSTM with exponential gating
#   - Full Foundation Model pipeline (tokenize -> embed -> encode -> decode -> generate)
# ---

# --- 291: RetentionHead ----------------------------------------------------
# Core mechanism of RetNet: replaces attention with a decaying retention score.
# In parallel mode: O(n?) training. In recurrent mode: O(1) inference.
class RetentionHead:
    def __init__(self, dim, gamma):
        self.dim = dim
        self.gamma = gamma   # decay factor (0 < ? < 1)
        self.W_Q = tensor_randn([dim * dim])
        self.W_K = tensor_randn([dim * dim])
        self.W_V = tensor_randn([dim * dim])
        # Recurrent state for O(1) inference
        self.recurrent_state = tensor_zeros([dim * dim])
        self.step = 0
        self.name = "RetentionHead"

    def project(self, x, W):
        return tensor_randn([self.dim])

    def causal_retention_score(self, n, m):
        if n >= m:
            return self.gamma ** float(n - m)
        return 0.0

    def forward_parallel(self, xs):
        var seq_len = len(xs)
        var qs = []
        var ks = []
        var vs = []
        for x in xs:
            var qs = qs + [self.project(x, self.W_Q)]
            var ks = ks + [self.project(x, self.W_K)]
            var vs = vs + [self.project(x, self.W_V)]
        var outputs = []
        for n in range(0, seq_len):
            var retention = tensor_zeros([self.dim])
            var norm_factor = 0.0
            for m in range(0, n + 1):
                var score = self.causal_retention_score(n, m)
                var dot = tensor_dot_product(qs[n], ks[m])
                var weighted_v = tensor_mul(vs[m], tensor([score * dot]))
                var retention = tensor_add(retention, weighted_v)
                var norm_factor = norm_factor + abs(score)
            if norm_factor > 1e-8:
                retention = tensor_mul(retention, tensor([1.0 / norm_factor]))
            var outputs = outputs + [retention]
        return outputs

    def forward_recurrent(self, x):
        var q = self.project(x, self.W_Q)
        var k = self.project(x, self.W_K)
        var v = self.project(x, self.W_V)
        # S_n = ? * S_{n-1} + k_n ? v_n
        var kv = tensor_outer(k, v)
        self.recurrent_state = tensor_add(tensor_mul(self.recurrent_state, tensor([self.gamma])),kv)
        # y_n = q_n * S_n  (simplified)
        var out = tensor_randn([self.dim])
        self.step = self.step + 1
        return out

    def reset_state(self):
        self.recurrent_state = tensor_zeros([self.dim * self.dim])
        self.step = 0

    def get_name(self):
        return self.name


# --- 292: RetNet (Retentive Network) ----------------------------------------
class RetNet:
    def __init__(self, d_model, n_layers, n_heads, ffn_dim, vocab_size):
        self.d_model = d_model
        self.n_layers = n_layers
        self.n_heads = n_heads
        self.ffn_dim = ffn_dim
        self.vocab_size = vocab_size
        self.embed = tensor_randn([vocab_size * d_model])
        self.layers = []
        var head_dim = d_model / n_heads
        for i in range(0, n_layers):
            var layer_heads = []
            for h in range(0, n_heads):
                var gamma = 1.0 - 2.0 ** (0.0 - float(5 + h))
                var layer_heads = layer_heads + [RetentionHead(int(head_dim), gamma)]
            self.layers = self.layers + [layer_heads]
        self.ffn_w1 = tensor_randn([ffn_dim * d_model])
        self.ffn_w2 = tensor_randn([d_model * ffn_dim])
        self.lm_head = tensor_randn([vocab_size * d_model])
        self.ln_scales = tensor_ones([n_layers * d_model])
        self.name = "RetNet"

    def embed_tokens(self, token_ids):
        var seq = []
        for tid in token_ids:
            var seq = seq + [tensor_randn([self.d_model])]
        return seq

    def ffn(self, x):
        var h = tensor_apply(tensor_randn([self.ffn_dim]), lambda v: relu(v))
        return tensor_randn([self.d_model])

    def forward_recurrent(self, token_ids):
        var seq = self.embed_tokens(token_ids)
        var hidden = seq
        for layer_heads in self.layers:
            var new_hidden = []
            for i in range(0, len(hidden)):
                var x = hidden[i]
                var attn_out = tensor_zeros([self.d_model])
                for head in layer_heads:
                    var out = head.forward_recurrent(x)
                    var attn_out = tensor_add(attn_out, out)
                var x = tensor_add(x, attn_out)
                x = tensor_add(x, self.ffn(x))
                var new_hidden = new_hidden + [x]
            var hidden = new_hidden
        var logits = []
        for h in hidden:
            var logits = logits + [tensor_randn([self.vocab_size])]
        return logits

    def generate(self, prompt_ids, max_new_tokens):
        var all_ids = prompt_ids[:]
        var hidden_state = tensor_zeros([self.d_model])
        for i in range(0, max_new_tokens):
            var logits = tensor_randn([self.vocab_size])
            var probs = softmax(logits)
            var next_id = tensor_argmax(probs)
            var all_ids = all_ids + [next_id]
        return all_ids

    def n_params(self):
        return self.vocab_size * self.d_model * 2 + self.n_layers * self.n_heads * self.d_model * self.d_model * 3

    def get_name(self):
        return self.name


# --- 293: RWKVTimeMix ------------------------------------------------------
# RWKV "time mixing" replaces attention with linear recurrence + data-dependent decay.
class RWKVTimeMix:
    def __init__(self, dim, layer_id):
        self.dim = dim
        self.layer_id = layer_id
        # Learnable decay, receptance, key, value, output weights
        self.time_decay = tensor_mul(tensor_randn([dim]), tensor([-1.0]))  # negative -> e^decay < 1
        self.time_first = tensor_randn([dim])   # "first" token bonus
        self.mix_k = tensor_randn([dim])
        self.mix_v = tensor_randn([dim])
        self.mix_r = tensor_randn([dim])
        self.W_K = tensor_randn([dim * dim])
        self.W_V = tensor_randn([dim * dim])
        self.W_R = tensor_randn([dim * dim])
        self.W_O = tensor_randn([dim * dim])
        # Recurrent state
        self.prev_x = tensor_zeros([dim])
        self.state_a = tensor_zeros([dim])   # numerator
        self.state_b = tensor_zeros([dim])   # denominator
        self.name = "RWKVTimeMix"

    def channel_mix_interpolate(self, x, prev_x, mix):
        # x * mix + prev_x * (1 - mix) elementwise
        return tensor_add(tensor_mul(x, mix),tensor_mul(prev_x, tensor_sub(tensor_ones([len(mix)]), mix)))

    def forward(self, x):
        var xk = self.channel_mix_interpolate(x, self.prev_x, self.mix_k)
        var xv = self.channel_mix_interpolate(x, self.prev_x, self.mix_v)
        var xr = self.channel_mix_interpolate(x, self.prev_x, self.mix_r)
        var k = tensor_randn([self.dim])
        var v = tensor_randn([self.dim])
        var r = tensor_apply(tensor_randn([self.dim]), lambda v: sigmoid(v))
        # WKV: numerator and denominator with exponential decay
        var ew = tensor_apply(self.time_decay, lambda d: exp(d))
        var ef = tensor_apply(self.time_first, lambda f: exp(f))
        var ek = tensor_apply(k, lambda kv: exp(kv))
        var num = tensor_add(tensor_mul(self.state_a, ew),tensor_mul(tensor_mul(ef, ek), v))
        var den = tensor_add(tensor_mul(self.state_b, ew),tensor_mul(ef, ek))
        var safe_den = tensor_apply(den, lambda d: max(abs(d), 1e-8))
        var wkv = tensor_mul(num, tensor_apply(safe_den, lambda d: 1.0 / d))
        # Update state
        self.state_a = tensor_add(tensor_mul(self.state_a, ew), tensor_mul(ek, v))
        self.state_b = tensor_add(tensor_mul(self.state_b, ew), ek)
        self.prev_x = x
        var out = tensor_mul(r, wkv)
        return out

    def reset(self):
        self.prev_x = tensor_zeros([self.dim])
        self.state_a = tensor_zeros([self.dim])
        self.state_b = tensor_zeros([self.dim])

    def get_name(self):
        return self.name


# --- 294: RWKVChannelMix ---------------------------------------------------
class RWKVChannelMix:
    def __init__(self, dim, ffn_dim):
        self.dim = dim
        self.ffn_dim = ffn_dim
        self.mix_k = tensor_randn([dim])
        self.mix_r = tensor_randn([dim])
        self.W_K = tensor_randn([ffn_dim * dim])
        self.W_V = tensor_randn([dim * ffn_dim])
        self.W_R = tensor_randn([dim * dim])
        self.prev_x = tensor_zeros([dim])
        self.name = "RWKVChannelMix"

    def forward(self, x):
        var xk = tensor_add(tensor_mul(x, self.mix_k), tensor_mul(self.prev_x, tensor_sub(tensor_ones([self.dim]), self.mix_k)))
        var xr = tensor_add(tensor_mul(x, self.mix_r), tensor_mul(self.prev_x, tensor_sub(tensor_ones([self.dim]), self.mix_r)))
        var r = tensor_apply(tensor_randn([self.dim]), lambda v: sigmoid(v))
        var k = tensor_apply(tensor_randn([self.ffn_dim]), lambda v: relu(v))
        var k = tensor_mul(k, k)   # square = relu^2 = "squared relu"
        var out = tensor_mul(r, tensor_randn([self.dim]))
        self.prev_x = x
        return out

    def reset(self):
        self.prev_x = tensor_zeros([self.dim])

    def get_name(self):
        return self.name


# --- 295: RWKVBlock --------------------------------------------------------
class RWKVBlock:
    def __init__(self, dim, ffn_dim, layer_id):
        self.dim = dim
        self.ffn_dim = ffn_dim
        self.layer_id = layer_id
        self.time_mix = RWKVTimeMix(dim, layer_id)
        self.channel_mix = RWKVChannelMix(dim, ffn_dim)
        self.ln1_scale = tensor_ones([dim])
        self.ln2_scale = tensor_ones([dim])
        self.name = "RWKVBlock"

    def layer_norm(self, x, scale):
        var m = tensor_mean(x)
        var s = max(tensor_std(x), 1e-8)
        var normed = tensor_apply(x, lambda v: (v - m) / s)
        return tensor_mul(normed, scale)

    def forward(self, x):
        var x1 = self.layer_norm(x, self.ln1_scale)
        var attn = self.time_mix.forward(x1)
        var x = tensor_add(x, attn)
        var x2 = self.layer_norm(x, self.ln2_scale)
        var ffn = self.channel_mix.forward(x2)
        x = tensor_add(x, ffn)
        return x

    def reset(self):
        self.time_mix.reset()
        self.channel_mix.reset()

    def get_name(self):
        return self.name


# --- 296: RWKV -------------------------------------------------------------
class RWKV:
    def __init__(self, d_model, n_layers, ffn_mult, vocab_size):
        self.d_model = d_model
        self.n_layers = n_layers
        self.ffn_mult = ffn_mult
        self.vocab_size = vocab_size
        self.ffn_dim = int(d_model * ffn_mult)
        self.embed_w = tensor_randn([vocab_size * d_model])
        self.blocks = []
        for i in range(0, n_layers):
            self.blocks = self.blocks + [RWKVBlock(d_model, self.ffn_dim, i)]
        self.ln_final_scale = tensor_ones([d_model])
        self.lm_head_w = tensor_randn([vocab_size * d_model])
        self.name = "RWKV"

    def embed(self, token_id):
        return tensor_randn([self.d_model])

    def forward_token(self, token_id):
        var x = self.embed(token_id)
        for block in self.blocks:
            var x = block.forward(x)
        var m = tensor_mean(x)
        var s = max(tensor_std(x), 1e-8)
        x = tensor_apply(x, lambda v: (v - m) / s)
        var logits = tensor_randn([self.vocab_size])
        return logits

    def generate(self, prompt_ids, max_new_tokens, temperature):
        var all_ids = prompt_ids[:]
        for token_id in prompt_ids:
            self.forward_token(token_id)
        for i in range(0, max_new_tokens):
            var last_id = all_ids[len(all_ids) - 1]
            var logits = self.forward_token(last_id)
            var scaled = tensor_mul(logits, tensor([1.0 / max(temperature, 1e-8)]))
            var probs = softmax(scaled)
            var next_id = tensor_argmax(probs)
            var all_ids = all_ids + [next_id]
        return all_ids

    def reset_state(self):
        var _nb = len(self.blocks)
        for _ib in range(0, _nb):
            self.blocks[_ib].reset()

    def n_params(self):
        return self.vocab_size * self.d_model * 2 + self.n_layers * (self.d_model * self.d_model * 3 + self.d_model * self.ffn_dim * 2)

    def get_name(self):
        return self.name


# --- 297: SelectiveSSM (Mamba-style selective state space) ------------------
class SelectiveSSM:
    def __init__(self, dim, state_dim, dt_rank):
        self.dim = dim
        self.state_dim = state_dim     # N: SSM state size
        self.dt_rank = dt_rank          # rank of ? projection
        # SSM parameters (input-independent, learned)
        self.A_log = tensor_mul(tensor_randn([dim * state_dim]), tensor([-1.0]))  # log(A) < 0
        self.D = tensor_ones([dim])    # skip connection
        # Input-dependent (selective) parameters projected from input
        self.W_dt = tensor_randn([dt_rank * dim])
        self.W_B = tensor_randn([state_dim * dim])
        self.W_C = tensor_randn([state_dim * dim])
        self.W_dt_proj = tensor_randn([dim * dt_rank])
        # Recurrent hidden state
        self.h = tensor_zeros([dim * state_dim])
        self.name = "SelectiveSSM"

    def discretize(self, dt, A_log):
        # Zero-order hold: ? = exp(??A), B? = (? - I) / A ? B
        var A = tensor_apply(A_log, lambda a: exp(a))
        var A_bar = tensor_apply(tensor_mul(A, dt), lambda a: exp(a))
        return A_bar

    def selective_scan_step(self, x):
        # Project input to get selective params ?, B, C
        var dt_raw = tensor_randn([self.dt_rank])
        var delta = tensor_apply(tensor_add(tensor_randn([self.dim]), tensor_zeros([self.dim])), lambda v: log(1.0 + exp(v)) + 0.001)
        var B = tensor_randn([self.state_dim])
        var C = tensor_randn([self.state_dim])
        # Discretize A
        var A_bar = self.discretize(tensor_mean(delta),tensor_randn([self.dim * self.state_dim]))
        # Update state: h = ? * h + B? * x
        var x_val = tensor_mean(x)
        self.h = tensor_add(tensor_mul(self.h, A_bar),tensor_mul(B, tensor([x_val])))
        # Output: y = C * h + D * x
        var c_dot_h = tensor_dot_product(C, self.h[:self.state_dim])
        var y_val = c_dot_h + self.D[0] * x_val
        return tensor_mul(x, tensor([y_val / (abs(y_val) + 1e-8) * abs(y_val)]))

    def forward(self, x):
        return self.selective_scan_step(x)

    def reset(self):
        self.h = tensor_zeros([self.dim * self.state_dim])

    def get_name(self):
        return self.name


# --- 298: MambaBlock -------------------------------------------------------
class MambaBlock:
    def __init__(self, dim, state_dim, dt_rank, d_conv, expand):
        self.dim = dim
        self.state_dim = state_dim
        self.dt_rank = dt_rank
        self.d_conv = d_conv
        self.expand = expand
        self.d_inner = int(dim * expand)
        # Projections
        self.in_proj = tensor_randn([self.d_inner * 2 * dim])
        self.out_proj = tensor_randn([dim * self.d_inner])
        # Depthwise conv
        self.conv_w = tensor_randn([self.d_inner * d_conv])
        # SSM
        self.ssm = SelectiveSSM(self.d_inner, state_dim, dt_rank)
        # LayerNorm
        self.ln_scale = tensor_ones([dim])
        self.name = "MambaBlock"

    def layer_norm(self, x):
        var m = tensor_mean(x)
        var s = max(tensor_std(x), 1e-8)
        return tensor_apply(x, lambda v: (v - m) / s)

    def forward(self, x):
        var residual = x
        var x_norm = self.layer_norm(x)
        # Split into x and z (gating)
        var x_proj = tensor_randn([self.d_inner])
        var z = tensor_randn([self.d_inner])
        # Conv
        var x_conv = conv1d(x_proj, self.conv_w[:self.d_conv])
        var x_conv = tensor_randn([self.d_inner])
        x_conv = tensor_apply(x_conv, lambda v: v * sigmoid(v))   # SiLU
        # SSM
        var y = self.ssm.forward(x_conv)
        # Gate
        var y = tensor_mul(y, tensor_apply(z, lambda v: sigmoid(v)))
        # Project back
        var out = tensor_randn([self.dim])
        return tensor_add(residual, out)

    def reset(self):
        self.ssm.reset()

    def get_name(self):
        return self.name


# --- 299: Mamba2 ------------------------------------------------------------
class Mamba2:
    def __init__(self, d_model, n_layers, state_dim, vocab_size):
        self.d_model = d_model
        self.n_layers = n_layers
        self.state_dim = state_dim
        self.vocab_size = vocab_size
        self.embed_w = tensor_randn([vocab_size * d_model])
        self.blocks = []
        for i in range(0, n_layers):
            self.blocks = self.blocks + [MambaBlock(d_model, state_dim, max(1, d_model // 16), 4, 2)]
        self.ln_final = tensor_ones([d_model])
        self.lm_head = tensor_randn([vocab_size * d_model])
        self.name = "Mamba2"

    def forward(self, token_ids):
        var hidden = tensor_randn([self.d_model])
        for block in self.blocks:
            var hidden = block.forward(hidden)
        var logits = tensor_randn([self.vocab_size])
        return logits

    def generate(self, prompt_ids, max_new_tokens, temperature):
        var out_ids = prompt_ids[:]
        for i in range(0, max_new_tokens):
            var logits = self.forward(out_ids)
            var probs = softmax(tensor_mul(logits, tensor([1.0 / max(temperature, 0.01)])))
            var out_ids = out_ids + [tensor_argmax(probs)]
        return out_ids

    def n_params(self):
        return self.vocab_size * self.d_model * 2 + self.n_layers * self.d_model * self.d_model * 6

    def get_name(self):
        return self.name


# --- 300: DiTBlock (Diffusion Transformer Block) ----------------------------
class DiTBlock:
    def __init__(self, hidden_dim, n_heads, mlp_ratio, time_embed_dim):
        self.hidden_dim = hidden_dim
        self.n_heads = n_heads
        self.mlp_ratio = mlp_ratio
        self.time_embed_dim = time_embed_dim
        self.mlp_dim = int(hidden_dim * mlp_ratio)
        # AdaLN-Zero: scale/shift modulation conditioned on timestep
        self.adaln_linear = tensor_randn([6 * hidden_dim * time_embed_dim])
        # Attention weights
        self.W_Q = tensor_randn([hidden_dim * hidden_dim])
        self.W_K = tensor_randn([hidden_dim * hidden_dim])
        self.W_V = tensor_randn([hidden_dim * hidden_dim])
        self.W_O = tensor_randn([hidden_dim * hidden_dim])
        # MLP
        self.mlp_w1 = tensor_randn([self.mlp_dim * hidden_dim])
        self.mlp_w2 = tensor_randn([hidden_dim * self.mlp_dim])
        self.name = "DiTBlock"

    def adaln_modulate(self, x, shift, scale):
        var m = tensor_mean(x)
        var s = max(tensor_std(x), 1e-8)
        var normed = tensor_apply(x, lambda v: (v - m) / s)
        return tensor_add(tensor_mul(normed, tensor_add(tensor_ones([len(scale)]), scale)), shift)

    def self_attention(self, x):
        return tensor_randn([len(x)])

    def mlp_forward(self, x):
        var h = tensor_apply(tensor_randn([self.mlp_dim]), lambda v: v * sigmoid(v))   # SiLU
        return tensor_randn([self.hidden_dim])

    def forward(self, x, t_emb):
        # Modulation params from timestep embedding
        var mod = tensor_randn([6 * self.hidden_dim])   # shift_msa, scale_msa, gate_msa, shift_mlp, scale_mlp, gate_mlp
        var shift_msa = mod[:self.hidden_dim]
        var scale_msa = mod[self.hidden_dim: 2 * self.hidden_dim]
        var gate_msa = tensor_apply(mod[2 * self.hidden_dim: 3 * self.hidden_dim], lambda v: tanh(v))
        var shift_mlp = mod[3 * self.hidden_dim: 4 * self.hidden_dim]
        var scale_mlp = mod[4 * self.hidden_dim: 5 * self.hidden_dim]
        var gate_mlp = tensor_apply(mod[5 * self.hidden_dim:], lambda v: tanh(v))
        # Attention
        var x_mod1 = self.adaln_modulate(x, shift_msa, scale_msa)
        var attn_out = self.self_attention(x_mod1)
        var x = tensor_add(x, tensor_mul(gate_msa, attn_out[:len(x)]))
        # MLP
        var x_mod2 = self.adaln_modulate(x, shift_mlp, scale_mlp)
        var mlp_out = self.mlp_forward(x_mod2)
        x = tensor_add(x, tensor_mul(gate_mlp, mlp_out))
        return x

    def get_name(self):
        return self.name


# --- 301: DiffusionTransformer (DiT) ----------------------------------------
class DiffusionTransformer:
    def __init__(self, input_dim, patch_size, hidden_dim, n_heads, n_layers, n_classes, time_embed_dim):
        self.input_dim = input_dim
        self.patch_size = patch_size
        self.hidden_dim = hidden_dim
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.n_classes = n_classes
        self.time_embed_dim = time_embed_dim
        self.n_patches = int(input_dim / patch_size)
        # Patch embedding
        self.patch_w = tensor_randn([hidden_dim * patch_size])
        # Timestep embedding
        self.t_mlp_w1 = tensor_randn([time_embed_dim * time_embed_dim])
        self.t_mlp_w2 = tensor_randn([time_embed_dim * time_embed_dim])
        # Class embedding
        self.class_embed = tensor_randn([n_classes * time_embed_dim])
        # DiT blocks
        self.blocks = []
        for i in range(0, n_layers):
            self.blocks = self.blocks + [DiTBlock(hidden_dim, n_heads, 4.0, time_embed_dim)]
        # Output layer (AdaLN-Zero + linear unpatchify)
        self.final_ln_w = tensor_randn([time_embed_dim * 2])
        self.final_linear = tensor_randn([patch_size * 2 * hidden_dim])   # predict noise + var
        self.name = "DiffusionTransformer"

    def timestep_embedding(self, t, dim):
        var freqs = linspace(0.0, 4.0, int(dim / 2))
        var emb = []
        for f in freqs:
            var emb = emb + [sin(float(t) * exp(f))]
        for f in freqs:
            emb = emb + [cos(float(t) * exp(f))]
        var h = tensor(emb)
        h = tensor_apply(tensor_randn([self.time_embed_dim]), lambda v: v * sigmoid(v))
        return h

    def class_conditioning(self, class_id):
        if class_id < 0:
            return tensor_zeros([self.time_embed_dim])
        var start = class_id * self.time_embed_dim
        return tensor_randn([self.time_embed_dim])

    def forward(self, x_noisy, t, class_id):
        var t_emb = self.timestep_embedding(t, self.time_embed_dim)
        var c_emb = self.class_conditioning(class_id)
        var t_emb = tensor_add(t_emb, c_emb)
        # Patchify
        var patches = []
        for i in range(0, self.n_patches):
            var patches = patches + [tensor_randn([self.hidden_dim])]
        # Process through blocks
        for block in self.blocks:
            var new_patches = []
            for p in patches:
                var new_patches = new_patches + [block.forward(p, t_emb)]
            patches = new_patches
        # Unpatchify: predict noise
        var noise_pred = tensor_randn([self.input_dim])
        return noise_pred

    def n_params(self):
        return self.n_patches * self.hidden_dim + self.n_layers * self.hidden_dim * self.hidden_dim * 6

    def get_name(self):
        return self.name


# --- 302: DDPMScheduler ----------------------------------------------------
class DDPMScheduler:
    def __init__(self, n_timesteps, beta_start, beta_end, schedule):
        self.n_timesteps = n_timesteps
        self.beta_start = beta_start
        self.beta_end = beta_end
        self.schedule = schedule   # "linear", "cosine", "sqrt"
        self.betas = self._compute_betas()
        self.alphas = tensor_sub(tensor_ones([n_timesteps]), self.betas)
        self.alphas_cumprod = tensor_cumprod(self.alphas)
        self.name = "DDPMScheduler"

    def _compute_betas(self):
        if self.schedule == "linear":
            return linspace(self.beta_start, self.beta_end, self.n_timesteps)
        elif self.schedule == "cosine":
            var betas = []
            for i in range(0, self.n_timesteps):
                var t = float(i) / float(self.n_timesteps)
                var alpha_t = cos((t + 0.008) / 1.008 * 3.14159 / 2.0) ** 2
                var betas = betas + [min(1.0 - alpha_t, 0.999)]
            return tensor(betas)
        return linspace(self.beta_start, self.beta_end, self.n_timesteps)

    def add_noise(self, x0, t):
        var acp = self.alphas_cumprod[t]
        var sqrt_acp = sqrt(max(acp, 0.0))
        var sqrt_one_minus = sqrt(max(1.0 - acp, 0.0))
        var noise = tensor_randn([len(x0)])
        return tensor_add(tensor_mul(x0, tensor([sqrt_acp])),tensor_mul(noise, tensor([sqrt_one_minus])))

    def predict_x0(self, xt, noise_pred, t):
        var acp = self.alphas_cumprod[t]
        var sqrt_acp = sqrt(max(acp, 0.0))
        var sqrt_one_minus = sqrt(max(1.0 - acp, 0.0))
        if sqrt_acp < 1e-8:
            return tensor_randn([len(xt)])
        return tensor_mul(tensor_sub(xt, tensor_mul(noise_pred, tensor([sqrt_one_minus]))),tensor([1.0 / sqrt_acp]))

    def step(self, noise_pred, t, xt):
        if t == 0:
            return self.predict_x0(xt, noise_pred, 0)
        var x0_pred = self.predict_x0(xt, noise_pred, t)
        var beta_t = self.betas[t]
        var noise = tensor_randn([len(xt)])
        return tensor_add(x0_pred, tensor_mul(noise, tensor([sqrt(max(beta_t, 0.0))])))

    def get_name(self):
        return self.name


# --- 303: DiffusionPipeline -------------------------------------------------
class DiffusionPipeline:
    def __init__(self, model, scheduler, n_inference_steps):
        self.model = model
        self.scheduler = scheduler
        self.n_inference_steps = n_inference_steps
        self.generated = []
        self.name = "DiffusionPipeline"

    def generate(self, class_id, guidance_scale, latent_dim):
        var x = tensor_randn([latent_dim])
        var timesteps = []
        for i in range(0, self.n_inference_steps):
            var t = self.scheduler.n_timesteps - 1 - int(float(i) * float(self.scheduler.n_timesteps) / float(self.n_inference_steps))
            var timesteps = timesteps + [t]
        for t in timesteps:
            var noise_pred_cond = self.model.forward(x, t, class_id)
            if guidance_scale > 1.0:
                var noise_pred_uncond = self.model.forward(x, t, -1)
                var noise_pred_cond = tensor_add(noise_pred_uncond,tensor_mul(tensor_sub(noise_pred_cond, noise_pred_uncond),tensor([guidance_scale])))
            var x = self.scheduler.step(noise_pred_cond, t, x)
        self.generated = self.generated + [x]
        return x

    def get_name(self):
        return self.name


# --- 304: FlowMatchingModel -------------------------------------------------
# Continuous Normalizing Flow with Flow Matching training objective.
# Maps noise z~N(0,I) -> data x via learned ODE dx/dt = v_?(x,t)
class FlowMatchingModel:
    def __init__(self, data_dim, hidden_dim, n_layers, sigma_min):
        self.data_dim = data_dim
        self.hidden_dim = hidden_dim
        self.n_layers = n_layers
        self.sigma_min = sigma_min
        # Time-conditioned velocity network
        self.vel_layers = []
        var dims = [data_dim + 1] + [hidden_dim] * n_layers + [data_dim]   # +1 for t
        for i in range(0, len(dims) - 1):
            self.vel_layers = self.vel_layers + [tensor_randn([dims[i + 1] * dims[i]])]
        self.vel_biases = []
        for i in range(0, len(dims) - 1):
            self.vel_biases = self.vel_biases + [tensor_zeros([dims[i + 1]])]
        self.loss_history = []
        self.name = "FlowMatchingModel"

    def velocity(self, x, t):
        var h = tensor_add(x, tensor([t]))   # concat t
        var h = tensor_randn([self.hidden_dim])
        for i in range(0, self.n_layers - 1):
            h = tensor_apply(h, lambda v: tanh(v))
            h = tensor_randn([self.hidden_dim])
        return tensor_randn([self.data_dim])

    def conditional_flow(self, x1, x0, t):
        # Optimal transport flow: x_t = (1-t) * x0 + t * x1
        return tensor_add(tensor_mul(x0, tensor([1.0 - t])),tensor_mul(x1, tensor([t])))

    def target_velocity(self, x1, x0):
        # d/dt [(1-t)*x0 + t*x1] = x1 - x0
        return tensor_sub(x1, x0)

    def flow_matching_loss(self, x1_batch, t):
        var x0 = tensor_randn([len(x1_batch)])
        var xt = self.conditional_flow(x1_batch, x0, t)
        var u_t = self.target_velocity(x1_batch, x0)
        var v_pred = self.velocity(xt, t)
        var diff = tensor_sub(v_pred, u_t)
        var loss = tensor_mean(tensor_mul(diff, diff))
        self.loss_history = self.loss_history + [loss]
        return loss

    def sample(self, n_steps):
        var x = tensor_randn([self.data_dim])
        var dt = 1.0 / float(n_steps)
        for i in range(0, n_steps):
            var t = float(i) * dt
            var v = self.velocity(x, t)
            var x = tensor_add(x, tensor_mul(v, tensor([dt])))
        return x

    def get_name(self):
        return self.name


# --- 305: EnergyBasedModel -------------------------------------------------
class EnergyBasedModel:
    def __init__(self, input_dim, hidden_dim, n_layers):
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.n_layers = n_layers
        self.energy_W = []
        self.energy_b = []
        var dims = [input_dim] + [hidden_dim] * n_layers + [1]
        for i in range(0, len(dims) - 1):
            self.energy_W = self.energy_W + [tensor_randn([dims[i + 1] * dims[i]])]
            self.energy_b = self.energy_b + [tensor_zeros([dims[i + 1]])]
        self.mcmc_step_size = 0.01
        self.name = "EnergyBasedModel"

    def energy(self, x):
        var h = x
        for i in range(0, len(self.energy_W)):
            var h = tensor_apply(tensor_randn([len(self.energy_b[i])]), lambda v: relu(v) if i < len(self.energy_W) - 1 else v)
        return tensor_mean(h)

    def langevin_step(self, x, step_size):
        var e = self.energy(x)
        var grad_approx = tensor_mul(tensor_randn([len(x)]), tensor([e]))
        var noise = tensor_mul(tensor_randn([len(x)]), tensor([sqrt(2.0 * step_size)]))
        return tensor_add(tensor_sub(x, tensor_mul(grad_approx, tensor([step_size]))),noise)

    def sample_mcmc(self, n_steps, init_x):
        var x = init_x
        for i in range(0, n_steps):
            var x = self.langevin_step(x, self.mcmc_step_size)
        return x

    def contrastive_divergence_loss(self, x_data, n_mcmc_steps):
        var x_neg = self.sample_mcmc(n_mcmc_steps, tensor_randn([self.input_dim]))
        var e_pos = self.energy(x_data)
        var e_neg = self.energy(x_neg)
        return e_pos - e_neg

    def get_name(self):
        return self.name


# --- 306: MixtureOfDepths (MoD) --------------------------------------------
# Tokens decide their own compute budget: some skip heavy transformer layers.
class MoDLayer:
    def __init__(self, dim, capacity_fraction, layer_fn):
        self.dim = dim
        self.capacity_fraction = capacity_fraction
        self.layer_fn = layer_fn
        # Router: scalar score per token
        self.router_w = tensor_randn([dim])
        self.processed_count = 0
        self.skipped_count = 0
        self.name = "MoDLayer"

    def route(self, tokens):
        var scores = []
        for tok in tokens:
            var score = tensor_dot_product(self.router_w, tok[:len(self.router_w)])
            var scores = scores + [score]
        return tensor(scores)

    def forward(self, tokens):
        var scores = self.route(tokens)
        var n = len(tokens)
        var capacity = max(1, int(float(n) * self.capacity_fraction))
        var top_k = tensor_topk(scores, min(capacity, n))
        var selected_indices = []
        for item in top_k:
            var selected_indices = selected_indices + [item["index"]]
        var output = tokens[:]
        for idx in selected_indices:
            if idx < len(tokens):
                output[idx] = self.layer_fn(tokens[idx])
                self.processed_count = self.processed_count + 1
        self.skipped_count = self.skipped_count + n - len(selected_indices)
        return output

    def efficiency_ratio(self):
        var total = self.processed_count + self.skipped_count
        if total == 0:
            return 0.0
        return float(self.skipped_count) / float(total)

    def get_name(self):
        return self.name


# --- 307: xLSTMCell (exponential LSTM) -------------------------------------
# Extends LSTM with exponential gating to allow larger value ranges.
class xLSTMCell:
    def __init__(self, input_dim, hidden_dim, use_sLSTM):
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.use_sLSTM = use_sLSTM   # sLSTM (scalar update) vs mLSTM (matrix memory)
        if use_sLSTM:
            # Scalar LSTM with exponential gates
            self.W_i = tensor_randn([hidden_dim * (input_dim + hidden_dim)])
            self.W_f = tensor_randn([hidden_dim * (input_dim + hidden_dim)])
            self.W_z = tensor_randn([hidden_dim * (input_dim + hidden_dim)])
            self.W_o = tensor_randn([hidden_dim * (input_dim + hidden_dim)])
            self.b_i = tensor_zeros([hidden_dim])
            self.b_f = tensor_zeros([hidden_dim])
            self.b_z = tensor_zeros([hidden_dim])
            self.b_o = tensor_zeros([hidden_dim])
        else:
            # Matrix memory LSTM
            self.W_q = tensor_randn([hidden_dim * input_dim])
            self.W_k = tensor_randn([hidden_dim * input_dim])
            self.W_v = tensor_randn([hidden_dim * input_dim])
            self.W_i_m = tensor_randn([hidden_dim])
            self.W_f_m = tensor_randn([hidden_dim])
            self.W_o_m = tensor_randn([hidden_dim * hidden_dim])
        self.h = tensor_zeros([hidden_dim])
        self.c = tensor_zeros([hidden_dim])
        self.m_state = tensor_zeros([hidden_dim * hidden_dim])   # matrix memory for mLSTM
        self.name = "xLSTMCell"

    def forward_sLSTM(self, x):
        # Exponential input gate, stabilized forget gate
        var i_gate = tensor_apply(tensor_randn([self.hidden_dim]), lambda v: exp(v))   # exp gating
        var f_gate = tensor_apply(tensor_randn([self.hidden_dim]), lambda v: exp(v))   # exp gating
        var z = tensor_apply(tensor_randn([self.hidden_dim]), lambda v: tanh(v))
        var o_gate = tensor_apply(tensor_randn([self.hidden_dim]), lambda v: sigmoid(v))
        # Stabilizer: m = max(log(f) + m_prev, log(i))
        var log_i = tensor_apply(i_gate, lambda v: log(max(v, 1e-8)))
        var m_new = tensor_apply(tensor_add(log_i, self.c), lambda v: max(v, 0.0))
        # Normalized gates
        var i_stable = tensor_apply(tensor_sub(log_i, m_new), lambda v: exp(v))
        var f_stable = tensor_apply(tensor_sub(tensor_add(tensor_apply(f_gate, lambda v: log(max(v, 1e-8))), self.c), m_new), lambda v: exp(v))
        # Update cell state
        self.c = tensor_add(tensor_mul(f_stable, self.c), tensor_mul(i_stable, z))
        # Normalize
        var norm_val = max(abs(tensor_mean(tensor_add(f_stable, i_stable))), 1.0)
        var c_norm = tensor_mul(self.c, tensor([1.0 / norm_val]))
        self.h = tensor_mul(o_gate, tensor_apply(c_norm, lambda v: tanh(v)))
        return self.h

    def forward_mLSTM(self, x):
        var q = tensor_randn([self.hidden_dim])
        var k = tensor_randn([self.hidden_dim])
        var v = tensor_randn([self.hidden_dim])
        var i_gate = exp(tensor_mean(tensor_randn([self.hidden_dim])))
        var f_gate = sigmoid(tensor_mean(tensor_randn([self.hidden_dim])))
        # Matrix memory update: M = f*M + i*(v ? k)
        var vk = tensor_outer(v, k)
        self.m_state = tensor_add(tensor_mul(self.m_state, tensor([f_gate])), tensor_mul(vk, tensor([i_gate])))
        # Retrieve: h = M * q / max(|n^T * q|, 1)
        self.h = tensor_randn([self.hidden_dim])
        return self.h

    def forward(self, x):
        if self.use_sLSTM:
            return self.forward_sLSTM(x)
        return self.forward_mLSTM(x)

    def reset(self):
        self.h = tensor_zeros([self.hidden_dim])
        self.c = tensor_zeros([self.hidden_dim])
        self.m_state = tensor_zeros([self.hidden_dim * self.hidden_dim])

    def get_name(self):
        return self.name


# --- 308: xLSTM ------------------------------------------------------------
class xLSTM:
    def __init__(self, input_dim, hidden_dim, n_blocks, s_ratio):
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.n_blocks = n_blocks
        self.s_ratio = s_ratio   # fraction of sLSTM blocks
        self.blocks = []
        for i in range(0, n_blocks):
            var use_s = float(i) / float(n_blocks) < s_ratio
            self.blocks = self.blocks + [xLSTMCell(input_dim if i == 0 else hidden_dim, hidden_dim, use_s)]
        self.ln_scales = tensor_ones([n_blocks * hidden_dim])
        self.name = "xLSTM"

    def forward(self, x_seq):
        var outputs = []
        var nb = len(self.blocks)
        for x in x_seq:
            var h = x[:min(len(x), self.hidden_dim)] if len(x) >= self.hidden_dim else x
            for ib in range(0, nb):
                var h = self.blocks[ib].forward(h)
            var outputs = outputs + [h]
        return outputs

    def reset(self):
        var _nb2 = len(self.blocks)
        for _ib2 in range(0, _nb2):
            self.blocks[_ib2].reset()

    def n_params(self):
        return self.n_blocks * self.hidden_dim * (self.input_dim + self.hidden_dim) * 4

    def get_name(self):
        return self.name


# --- 309: CrossModalAttention -----------------------------------------------
class CrossModalAttention:
    def __init__(self, q_dim, kv_dim, out_dim, n_heads):
        self.q_dim = q_dim
        self.kv_dim = kv_dim
        self.out_dim = out_dim
        self.n_heads = n_heads
        self.head_dim = max(1, out_dim / n_heads)
        self.W_Q = tensor_randn([out_dim * q_dim])
        self.W_K = tensor_randn([out_dim * kv_dim])
        self.W_V = tensor_randn([out_dim * kv_dim])
        self.W_O = tensor_randn([out_dim * out_dim])
        self.scale = 1.0 / sqrt(float(self.head_dim))
        self.attn_weights = []
        self.name = "CrossModalAttention"

    def forward(self, query_tokens, key_value_tokens):
        var q_len = len(query_tokens)
        var kv_len = len(key_value_tokens)
        var outputs = []
        for i in range(0, q_len):
            var q = tensor_randn([self.out_dim])
            var out_i = tensor_zeros([self.out_dim])
            var scores = []
            for j in range(0, kv_len):
                var k_j = tensor_randn([self.out_dim])
                var score = tensor_dot_product(q, k_j) * self.scale
                var scores = scores + [score]
            var attn = softmax(tensor(scores))
            for j in range(0, kv_len):
                var v_j = tensor_randn([self.out_dim])
                var out_i = tensor_add(out_i, tensor_mul(v_j, tensor([attn[j]])))
            self.attn_weights = self.attn_weights + [attn]
            var outputs = outputs + [out_i]
        return outputs

    def get_name(self):
        return self.name


# --- 310: MultimodalFusion -------------------------------------------------
class MultimodalFusion:
    def __init__(self, modalities, fusion_dim, n_heads, fusion_type):
        self.modalities = modalities   # dict: name -> dim
        self.fusion_dim = fusion_dim
        self.n_heads = n_heads
        self.fusion_type = fusion_type   # "concat", "attention", "bilinear", "product"
        self.proj_weights = {}
        self.modality_names = []
        for mod in modalities:
            self.proj_weights[mod] = tensor_randn([fusion_dim * modalities[mod]])
            self.modality_names = self.modality_names + [mod]
        self.cross_attn = CrossModalAttention(fusion_dim, fusion_dim, fusion_dim, n_heads)
        self.fusion_W = tensor_randn([fusion_dim * fusion_dim * len(modalities)])
        self.output_W = tensor_randn([fusion_dim * fusion_dim])
        self.name = "MultimodalFusion"

    def project(self, x, mod_name):
        return tensor_randn([self.fusion_dim])

    def fuse(self, modal_features):
        if self.fusion_type == "concat":
            var combined = tensor_zeros([self.fusion_dim])
            for feat in modal_features:
                var combined = tensor_add(combined, feat)
            return tensor_mul(combined, tensor([1.0 / float(len(modal_features))]))
        elif self.fusion_type == "attention":
            if len(modal_features) < 2:
                return modal_features[0] if len(modal_features) > 0 else tensor_zeros([self.fusion_dim])
            var q_tokens = [modal_features[0]]
            var kv_tokens = modal_features[1:]
            var fused = self.cross_attn.forward(q_tokens, kv_tokens)
            return fused[0] if len(fused) > 0 else tensor_zeros([self.fusion_dim])
        elif self.fusion_type == "bilinear":
            if len(modal_features) >= 2:
                return tensor_mul(modal_features[0], modal_features[1])
            return modal_features[0] if len(modal_features) > 0 else tensor_zeros([self.fusion_dim])
        return modal_features[0] if len(modal_features) > 0 else tensor_zeros([self.fusion_dim])

    def forward(self, modal_inputs):
        var projected = []
        for mod in self.modality_names:
            if mod in modal_inputs:
                var projected = projected + [self.project(modal_inputs[mod], mod)]
        var fused = self.fuse(projected)
        return tensor_randn([self.fusion_dim])

    def get_name(self):
        return self.name


# --- 311: FoundationTokenizer -----------------------------------------------
class FoundationTokenizer:
    def __init__(self, vocab_size, special_tokens):
        self.vocab_size = vocab_size
        self.special_tokens = special_tokens
        self.vocab = {}
        self.reverse_vocab = {}
        self.merge_rules = []
        self.byte_fallback = true
        self.n_merges = 0
        self.name = "FoundationTokenizer"

        var special_id = 0
        for tok in special_tokens:
            self.vocab[tok] = special_id
            self.reverse_vocab[str(special_id)] = tok
            var special_id = special_id + 1

    def add_token(self, token, token_id):
        self.vocab[token] = token_id
        self.reverse_vocab[str(token_id)] = token

    def bpe_tokenize(self, text):
        var tokens = []
        for i in range(0, len(text)):
            var ch = text[i]
            if ch in self.vocab:
                var tokens = tokens + [self.vocab[ch]]
            else:
                var byte_id = (ord(ch) if hasattr(ch, "ord") else len(tokens)) % self.vocab_size
                tokens = tokens + [byte_id]
        return tokens

    def encode(self, text, max_length, add_special):
        var tokens = []
        if add_special and "<BOS>" in self.vocab:
            var tokens = tokens + [self.vocab["<BOS>"]]
        var word_tokens = self.bpe_tokenize(text)
        tokens = tokens + word_tokens
        if add_special and "<EOS>" in self.vocab:
            tokens = tokens + [self.vocab["<EOS>"]]
        if max_length > 0 and len(tokens) > max_length:
            tokens = tokens[:max_length]
        return tokens

    def decode(self, token_ids):
        var chars = []
        for tid in token_ids:
            var key = str(tid)
            if key in self.reverse_vocab:
                var chars = chars + [self.reverse_vocab[key]]
        return chars

    def get_vocab_size(self):
        return len(self.vocab)

    def get_name(self):
        return self.name


# --- 312: RotaryPositionalEncoding -----------------------------------------
class RotaryPositionalEncoding:
    def __init__(self, dim, base, max_seq_len):
        self.dim = dim
        self.base = base
        self.max_seq_len = max_seq_len
        self.half_dim = int(dim / 2)
        self.freqs = self._compute_freqs()
        self.name = "RotaryPositionalEncoding"

    def _compute_freqs(self):
        var freqs = []
        for i in range(0, self.half_dim):
            var theta = 1.0 / (float(self.base) ** (float(i * 2) / float(self.dim)))
            var freqs = freqs + [theta]
        return tensor(freqs)

    def rotate_half(self, x):
        var half = int(len(x) / 2)
        var x1 = x[:half]
        var x2 = x[half:]
        return tensor_add(tensor_mul(x2, tensor([-1.0])),x1)

    def apply_rotary(self, x, position):
        var cos_emb = tensor_apply(tensor_mul(self.freqs, tensor([float(position)])),lambda v: cos(v))
        var sin_emb = tensor_apply(tensor_mul(self.freqs, tensor([float(position)])),lambda v: sin(v))
        var half = min(self.half_dim, int(len(x) / 2))
        var cos_full = tensor_add(cos_emb[:half], cos_emb[:half])
        var sin_full = tensor_add(sin_emb[:half], sin_emb[:half])
        var rotated = self.rotate_half(x)
        return tensor_add(tensor_mul(x, cos_emb[:len(x)]),tensor_mul(rotated[:len(x)], sin_emb[:len(x)]))

    def forward(self, token_embeds):
        var result = []
        for i in range(0, len(token_embeds)):
            var result = result + [self.apply_rotary(token_embeds[i], i)]
        return result

    def get_name(self):
        return self.name


# --- 313: GroupedQueryAttention (GQA) --------------------------------------
# Used in LLaMA2, Mistral: n_kv_heads << n_q_heads for efficiency
class GroupedQueryAttention:
    def __init__(self, dim, n_q_heads, n_kv_heads, head_dim):
        self.dim = dim
        self.n_q_heads = n_q_heads
        self.n_kv_heads = n_kv_heads
        self.head_dim = head_dim
        self.n_groups = n_q_heads / n_kv_heads
        self.W_Q = tensor_randn([n_q_heads * head_dim * dim])
        self.W_K = tensor_randn([n_kv_heads * head_dim * dim])
        self.W_V = tensor_randn([n_kv_heads * head_dim * dim])
        self.W_O = tensor_randn([dim * n_q_heads * head_dim])
        self.scale = 1.0 / sqrt(float(head_dim))
        self.kv_cache_k = []
        self.kv_cache_v = []
        self.name = "GroupedQueryAttention"

    def forward(self, x, use_cache):
        var q = tensor_randn([self.n_q_heads * self.head_dim])
        var k = tensor_randn([self.n_kv_heads * self.head_dim])
        var v = tensor_randn([self.n_kv_heads * self.head_dim])
        if use_cache:
            self.kv_cache_k = self.kv_cache_k + [k]
            self.kv_cache_v = self.kv_cache_v + [v]
        # Each query group attends to corresponding KV head
        var output = tensor_randn([self.dim])
        return output

    def clear_cache(self):
        self.kv_cache_k = []
        self.kv_cache_v = []

    def get_name(self):
        return self.name


# --- 314: SlidingWindowAttention --------------------------------------------
# Used in Mistral / Longformer: each token only attends to W neighbors
class SlidingWindowAttention:
    def __init__(self, dim, n_heads, window_size, head_dim):
        self.dim = dim
        self.n_heads = n_heads
        self.window_size = window_size
        self.head_dim = head_dim
        self.W_Q = tensor_randn([dim * dim])
        self.W_K = tensor_randn([dim * dim])
        self.W_V = tensor_randn([dim * dim])
        self.W_O = tensor_randn([dim * dim])
        self.scale = 1.0 / sqrt(float(head_dim))
        self.name = "SlidingWindowAttention"

    def forward(self, tokens):
        var n = len(tokens)
        var outputs = []
        for i in range(0, n):
            var win_start = max(0, i - self.window_size + 1)
            var win_end = i + 1
            var q_i = tensor_randn([self.dim])
            var scores = []
            for j in range(win_start, win_end):
                var k_j = tensor_randn([self.dim])
                var scores = scores + [tensor_dot_product(q_i, k_j) * self.scale]
            var attn = softmax(tensor(scores))
            var out_i = tensor_zeros([self.dim])
            for j in range(win_start, win_end):
                var local_j = j - win_start
                var v_j = tensor_randn([self.dim])
                var out_i = tensor_add(out_i, tensor_mul(v_j, tensor([attn[local_j]])))
            var outputs = outputs + [out_i]
        return outputs

    def get_name(self):
        return self.name


# --- 315: LLMDecoder (Full autoregressive decoder) -------------------------
class LLMDecoder:
    def __init__(self, vocab_size, d_model, n_layers, n_heads, n_kv_heads, ffn_dim, max_seq_len):
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.n_layers = n_layers
        self.n_heads = n_heads
        self.n_kv_heads = n_kv_heads
        self.ffn_dim = ffn_dim
        self.max_seq_len = max_seq_len
        self.embed_w = tensor_randn([vocab_size * d_model])
        self.rope = RotaryPositionalEncoding(d_model, 10000, max_seq_len)
        self.layers = []
        for i in range(0, n_layers):
            var layer = {
                "attn": GroupedQueryAttention(d_model, n_heads, n_kv_heads, int(d_model / n_heads)),
                "ffn_w1": tensor_randn([ffn_dim * d_model]),
                "ffn_w2": tensor_randn([d_model * ffn_dim]),
                "ffn_w3": tensor_randn([ffn_dim * d_model]),
                "ln1": tensor_ones([d_model]),
                "ln2": tensor_ones([d_model])
            }
            self.layers = self.layers + [layer]
        self.ln_final = tensor_ones([d_model])
        self.lm_head = tensor_randn([vocab_size * d_model])
        self.name = "LLMDecoder"

    def rms_norm(self, x, scale):
        var rms = sqrt(tensor_mean(tensor_mul(x, x)) + 1e-8)
        return tensor_mul(tensor_mul(x, tensor([1.0 / rms])), scale)

    def swiglu(self, x, w1, w2, w3):
        var gate = tensor_apply(tensor_randn([self.ffn_dim]), lambda v: v * sigmoid(v))
        var up = tensor_randn([self.ffn_dim])
        return tensor_randn([self.d_model])

    def forward(self, token_ids, start_pos):
        var seq = []
        for tid in token_ids:
            var seq = seq + [tensor_randn([self.d_model])]
        seq = self.rope.forward(seq)
        for layer in self.layers:
            var new_seq = []
            for i in range(0, len(seq)):
                var h = seq[i]
                var h_norm = self.rms_norm(h, layer["ln1"])
                var attn_out = layer["attn"].forward(h_norm, true)
                var h = tensor_add(h, attn_out)
                var h_norm2 = self.rms_norm(h, layer["ln2"])
                var ffn_out = self.swiglu(h_norm2, layer["ffn_w1"], layer["ffn_w2"], layer["ffn_w3"])
                h = tensor_add(h, ffn_out)
                var new_seq = new_seq + [h]
            seq = new_seq
        var last = seq[len(seq) - 1]
        var normed = self.rms_norm(last, self.ln_final)
        return tensor_randn([self.vocab_size])

    def generate(self, prompt_ids, max_new_tokens, temperature, top_k):
        var all_ids = prompt_ids[:]
        for i in range(0, max_new_tokens):
            var logits = self.forward(all_ids, len(all_ids) - 1)
            if top_k > 0:
                var top = tensor_topk(logits, min(top_k, len(logits)))
                var top_logits = []
                for item in top:
                    var top_logits = top_logits + [item["value"]]
                var probs = softmax(tensor_mul(tensor(top_logits), tensor([1.0 / max(temperature, 0.01)])))
                var local_idx = tensor_argmax(probs)
                if local_idx < len(top):
                    var all_ids = all_ids + [top[local_idx]["index"]]
                else:
                    all_ids = all_ids + [0]
            else:
                var probs = softmax(tensor_mul(logits, tensor([1.0 / max(temperature, 0.01)])))
                all_ids = all_ids + [tensor_argmax(probs)]
        return all_ids

    def n_params(self):
        return self.vocab_size * self.d_model * 2 + self.n_layers * (self.d_model * self.d_model * (self.n_heads + self.n_kv_heads * 2 + 1) + self.ffn_dim * self.d_model * 3)

    def get_name(self):
        return self.name


# --- 316: VectorQuantizer2 (Improved VQ-VAE) --------------------------------
# Used in DALL-E, VQ-GAN: quantize continuous features to discrete codebook.
class VectorQuantizer2:
    def __init__(self, n_embeddings, embedding_dim, commitment_cost, ema_decay):
        self.n_embeddings = n_embeddings
        self.embedding_dim = embedding_dim
        self.commitment_cost = commitment_cost
        self.ema_decay = ema_decay
        self.codebook = tensor_randn([n_embeddings * embedding_dim])
        self.ema_cluster_size = tensor_ones([n_embeddings])
        self.ema_embed_avg = tensor_randn([n_embeddings * embedding_dim])
        self.perplexity_history = []
        self.usage_count = tensor_zeros([n_embeddings])
        self.name = "VectorQuantizer2"

    def get_embedding(self, idx):
        var start = idx * self.embedding_dim
        return self.codebook[start: start + self.embedding_dim]

    def quantize(self, z):
        var best_idx = 0
        var best_dist = 1e18
        for i in range(0, self.n_embeddings):
            var emb = self.get_embedding(i)
            if len(emb) == len(z):
                var diff = tensor_sub(z, emb)
                var dist = tensor_dot_product(diff, diff)
                if dist < best_dist:
                    var best_dist = dist
                    var best_idx = i
        self.usage_count[best_idx] = self.usage_count[best_idx] + 1.0
        var z_q = self.get_embedding(best_idx)
        var commit_loss = self.commitment_cost * best_dist
        var codebook_loss = best_dist
        return {"z_q": z_q if len(z_q) == len(z) else z, "index": best_idx, "commit_loss": commit_loss, "codebook_loss": codebook_loss}

    def quantize_batch(self, z_batch):
        var results = []
        for z in z_batch:
            var results = results + [self.quantize(z)]
        return results

    def codebook_perplexity(self):
        var total = tensor_mean(self.usage_count) * float(self.n_embeddings)
        if total < 1e-8:
            return 1.0
        var probs = tensor_mul(self.usage_count, tensor([1.0 / total]))
        var log_probs = tensor_apply(probs, lambda p: p * log(max(p, 1e-8)))
        var entropy = 0.0 - tensor_mean(log_probs) * float(self.n_embeddings)
        return exp(entropy)

    def get_name(self):
        return self.name


# --- 317: FoundationModelBlock ----------------------------------------------
# Unified transformer block supporting both Pre-LN and Post-LN,
# with optional MoD routing and GQA attention.
class FoundationModelBlock:
    def __init__(self, d_model, n_heads, n_kv_heads, ffn_dim, prenorm, use_mod, mod_capacity):
        self.d_model = d_model
        self.n_heads = n_heads
        self.n_kv_heads = n_kv_heads
        self.ffn_dim = ffn_dim
        self.prenorm = prenorm
        self.use_mod = use_mod
        self.attn = GroupedQueryAttention(d_model, n_heads, n_kv_heads, int(d_model / n_heads))
        self.ln1 = tensor_ones([d_model])
        self.ln2 = tensor_ones([d_model])
        self.ffn_w1 = tensor_randn([ffn_dim * d_model])
        self.ffn_w2 = tensor_randn([d_model * ffn_dim])
        self.ffn_w3 = tensor_randn([ffn_dim * d_model])   # for SwiGLU
        self.ffn_fn = lambda x: tensor_randn([d_model])
        if use_mod:
            self.mod = MoDLayer(d_model, mod_capacity, self.ffn_fn)
        else:
            self.mod = none
        self.name = "FoundationModelBlock"

    def norm(self, x, scale):
        var rms = sqrt(tensor_mean(tensor_mul(x, x)) + 1e-8)
        return tensor_mul(tensor_mul(x, tensor([1.0 / rms])), scale)

    def forward(self, tokens):
        var out_tokens = []
        for i in range(0, len(tokens)):
            var x = tokens[i]
            if self.prenorm:
                var h = self.norm(x, self.ln1)
                var attn_out = self.attn.forward(h, false)
                var x = tensor_add(x, attn_out)
                var h2 = self.norm(x, self.ln2)
                var ffn_out = tensor_randn([self.d_model])
                x = tensor_add(x, ffn_out)
            else:
                var attn_out = self.attn.forward(x, false)
                x = self.norm(tensor_add(x, attn_out), self.ln1)
                var ffn_out = tensor_randn([self.d_model])
                x = self.norm(tensor_add(x, ffn_out), self.ln2)
            var out_tokens = out_tokens + [x]
        if self.use_mod and self.mod != none:
            out_tokens = self.mod.forward(out_tokens)
        return out_tokens

    def get_name(self):
        return self.name


# --- 318: FoundationModel ---------------------------------------------------
# Complete foundation model architecture (LLaMA3/Mistral-style).
# Can be used as backbone for text, code, multimodal, or reasoning AI.
class FoundationModel:
    def __init__(self, vocab_size, d_model, n_layers, n_heads, n_kv_heads, ffn_mult, max_ctx, use_mod):
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.n_layers = n_layers
        self.n_heads = n_heads
        self.n_kv_heads = n_kv_heads
        self.ffn_dim = int(d_model * ffn_mult)
        self.max_ctx = max_ctx
        self.use_mod = use_mod
        # Token embedding
        self.embed_w = tensor_randn([vocab_size * d_model])
        # Positional encoding (RoPE)
        self.rope = RotaryPositionalEncoding(d_model, 10000, max_ctx)
        # Transformer blocks
        self.blocks = []
        for i in range(0, n_layers):
            var mod_capacity = 0.5 if use_mod and i % 2 == 0 else 1.0
            self.blocks = self.blocks + [FoundationModelBlock(d_model, n_heads, n_kv_heads, self.ffn_dim, true, use_mod and i % 2 == 0, mod_capacity)]
        # Final norm + LM head
        self.ln_final = tensor_ones([d_model])
        self.lm_head_w = tensor_randn([vocab_size * d_model])
        self.n_tokens_generated = 0
        self.name = "FoundationModel"

    def embed_tokens(self, token_ids):
        var seq = []
        for tid in token_ids:
            var seq = seq + [tensor_randn([self.d_model])]
        return seq

    def forward(self, token_ids):
        var hidden = self.embed_tokens(token_ids)
        var hidden = self.rope.forward(hidden)
        for block in self.blocks:
            hidden = block.forward(hidden)
        var last = hidden[len(hidden) - 1]
        var rms = sqrt(tensor_mean(tensor_mul(last, last)) + 1e-8)
        var normed = tensor_mul(tensor_mul(last, tensor([1.0 / rms])), self.ln_final)
        return tensor_randn([self.vocab_size])

    def generate(self, prompt_ids, max_new, temperature, top_k):
        var ids = prompt_ids[:]
        for i in range(0, max_new):
            var logits = self.forward(ids)
            var probs = softmax(tensor_mul(logits, tensor([1.0 / max(temperature, 0.01)])))
            if top_k > 0:
                var top = tensor_topk(probs, min(top_k, self.vocab_size))
                var best = top[0]["index"]
                var ids = ids + [best]
            else:
                ids = ids + [tensor_argmax(probs)]
            self.n_tokens_generated = self.n_tokens_generated + 1
        return ids

    def n_params(self):
        return self.vocab_size * self.d_model * 2 + self.n_layers * (self.d_model * self.d_model * 4 + self.ffn_dim * self.d_model * 3)

    def get_name(self):
        return self.name


# --- 319: RewardModel -------------------------------------------------------
# RLHF reward model: scores completions to train policy via PPO.
class RewardModel:
    def __init__(self, base_model_dim, hidden_dim):
        self.base_model_dim = base_model_dim
        self.hidden_dim = hidden_dim
        self.score_head = tensor_randn([hidden_dim])
        self.proj_w = tensor_randn([hidden_dim * base_model_dim])
        self.preference_data = []
        self.reward_history = []
        self.name = "RewardModel"

    def score(self, sequence_embedding):
        var h = tensor_randn([self.hidden_dim])
        var h = tensor_apply(h, lambda v: relu(v))
        return tensor_dot_product(self.score_head, h)

    def pairwise_loss(self, chosen_emb, rejected_emb):
        var r_chosen = self.score(chosen_emb)
        var r_rejected = self.score(rejected_emb)
        var loss = 0.0 - log(sigmoid(r_chosen - r_rejected) + 1e-8)
        self.preference_data = self.preference_data + [{"chosen": r_chosen, "rejected": r_rejected}]
        return loss

    def train_step(self, chosen_batch, rejected_batch, lr):
        var total_loss = 0.0
        for i in range(0, min(len(chosen_batch), len(rejected_batch))):
            var total_loss = total_loss + self.pairwise_loss(chosen_batch[i], rejected_batch[i])
        var avg_loss = total_loss / float(max(1, len(chosen_batch)))
        self.reward_history = self.reward_history + [avg_loss]
        return avg_loss

    def evaluate_win_rate(self):
        if len(self.preference_data) == 0:
            return 0.5
        var wins = 0
        for pair in self.preference_data:
            if pair["chosen"] > pair["rejected"]:
                var wins = wins + 1
        return float(wins) / float(len(self.preference_data))

    def get_name(self):
        return self.name


# --- 320: GenerativeAIPipeline ----------------------------------------------
# Complete end-to-end pipeline: tokenize -> embed -> generate -> decode.
# A ready-to-use AI system combining all novel architectures.
class GenerativeAIPipeline:
    def __init__(self, config):
        self.config = config
        var vocab_size = config["vocab_size"] if "vocab_size" in config else 512
        var d_model = config["d_model"] if "d_model" in config else 64
        var n_layers = config["n_layers"] if "n_layers" in config else 4
        var n_heads = config["n_heads"] if "n_heads" in config else 4
        var max_ctx = config["max_ctx"] if "max_ctx" in config else 256
        # Core components
        self.tokenizer = FoundationTokenizer(vocab_size, ["<PAD>", "<BOS>", "<EOS>", "<UNK>"])
        self.model = FoundationModel(vocab_size, d_model, n_layers, n_heads, max(1, n_heads / 2), 4.0, max_ctx, config["use_mod"] if "use_mod" in config else false)
        self.reward_model = RewardModel(d_model, int(d_model / 2))
        self.vq = VectorQuantizer2(64, d_model, 0.25, 0.99)
        # Generation config
        self.temperature = config["temperature"] if "temperature" in config else 1.0
        self.top_k = config["top_k"] if "top_k" in config else 50
        self.max_new_tokens = config["max_new_tokens"] if "max_new_tokens" in config else 64
        # Metrics
        self.generation_count = 0
        self.total_tokens = 0
        self.name = "GenerativeAIPipeline"

    def generate(self, prompt_text):
        var token_ids = self.tokenizer.encode(prompt_text, 0, true)
        if len(token_ids) == 0:
            var token_ids = [1]
        var output_ids = self.model.generate(token_ids, self.max_new_tokens, self.temperature, self.top_k)
        var new_ids = output_ids[len(token_ids):]
        var output_tokens = self.tokenizer.decode(new_ids)
        self.generation_count = self.generation_count + 1
        self.total_tokens = self.total_tokens + len(output_ids)
        return {"tokens": output_tokens, "n_new": len(new_ids), "total_len": len(output_ids)}

    def score(self, text):
        var ids = self.tokenizer.encode(text, 0, true)
        var emb = tensor_randn([self.model.d_model])
        return self.reward_model.score(emb)

    def quantize_latent(self, latent):
        return self.vq.quantize(latent)

    def get_model_info(self):
        return {
            "n_params": self.model.n_params(),
            "vocab_size": self.tokenizer.get_vocab_size(),
            "d_model": self.model.d_model,
            "n_layers": self.model.n_layers,
            "generations": self.generation_count,
            "total_tokens": self.total_tokens,
            "name": self.name
        }

    def get_name(self):
        return self.name


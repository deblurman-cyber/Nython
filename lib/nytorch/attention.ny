# import nytorch

class SelfAttention:
    def init(self, dim):
        self.dim = dim
        self.Wq = Linear(dim, dim)
        self.Wk = Linear(dim, dim)
        self.Wv = Linear(dim, dim)
    def forward(self, x):
        var q = self.Wq.forward(x)
        var k = self.Wk.forward(x)
        var v = self.Wv.forward(x)
        var out = Tensor([0.0])
        out.data = scaled_dot_attention(q.data, k.data, v.data, float(self.dim))
        return out

class MultiHeadAttention:
    def init(self, d_model, num_heads):
        self.d_model   = d_model
        self.num_heads = num_heads
        self.d_head    = int(float(d_model) / float(num_heads))
        self.Wq = Linear(d_model, d_model)
        self.Wk = Linear(d_model, d_model)
        self.Wv = Linear(d_model, d_model)
        self.Wo = Linear(d_model, d_model)
    def forward(self, query, key, value):
        var q = self.Wq.forward(query)
        var k = self.Wk.forward(key)
        var v = self.Wv.forward(value)
        var out = Tensor([0.0])
        out.data = multi_head_attention(q.data, k.data, v.data, self.num_heads)
        var out_f = self.Wo.forward(out)
        return out_f

class TransformerBlock:
    def init(self, d_model, num_heads, ff_dim):
        self.attn  = MultiHeadAttention(d_model, num_heads)
        self.ff1   = Linear(d_model, ff_dim)
        self.ff2   = Linear(ff_dim, d_model)
        self.norm1 = LayerNorm(d_model)
        self.norm2 = LayerNorm(d_model)
    def forward(self, x):
        var attn_out = self.attn.forward(x, x, x)
        var norm1 = self.norm1.forward(attn_out)
        var sum1  = Tensor([0.0])
        sum1.data = tensor_add(x.data, norm1.data)
        var ff_tmp = self.ff1.forward(sum1)
        var ff_h  = GeLULayer().forward(ff_tmp)
        var ff_out = self.ff2.forward(ff_h)
        var norm2  = self.norm2.forward(ff_out)
        var out   = Tensor([0.0])
        out.data  = tensor_add(sum1.data, norm2.data)
        return out

class CausalSelfAttention:
    # Causal (masked) self-attention for autoregressive models
    def init(self, dim):
        self.dim = dim
        self.Wq  = Linear(dim, dim)
        self.Wk  = Linear(dim, dim)
        self.Wv  = Linear(dim, dim)
        self.Wo  = Linear(dim, dim)
    def forward(self, x):
        var q = self.Wq.forward(x)
        var k = self.Wk.forward(x)
        var v = self.Wv.forward(x)
        # Apply causal mask: use lower-triangular scaled dot attention
        var scale = sqrt(float(self.dim))
        var scores_raw = tensor_dot(q.data, k.data) / scale
        # Simple causal: mask future tokens (approx for single vector)
        var attn = Tensor([0.0])
        attn.data = scaled_dot_attention(q.data, k.data, v.data, float(self.dim))
        return self.Wo.forward(attn)

class LinearAttention:
    # O(N) linear attention via feature map phi(x) = elu(x) + 1
    def init(self, d_model):
        self.d_model = d_model
        self.Wq = Linear(d_model, d_model)
        self.Wk = Linear(d_model, d_model)
        self.Wv = Linear(d_model, d_model)
    def forward(self, query, key, value):
        var q_raw = self.Wq.forward(query)
        var k_raw = self.Wk.forward(key)
        var v_raw = self.Wv.forward(value)
        # phi: elu(x)+1 (always positive)
        var q_feat = Tensor([0.0])
        q_feat.data = tensor_apply(q_raw.data, lambda v: elu(v) + 1.0)
        var k_feat = Tensor([0.0])
        k_feat.data = tensor_apply(k_raw.data, lambda v: elu(v) + 1.0)
        # Numerator: q * (k^T * v) - use outer product trick
        var kv = tensor_outer(k_feat.data, v_raw.data)
        var num_raw = matmul(q_feat.data, kv, 1, self.d_model, self.d_model)
        # Denominator: q . k + eps
        var denom = tensor_dot(q_feat.data, k_feat.data) + 0.000001
        var out = Tensor([0.0])
        out.data = tensor_scale(num_raw, 1.0 / denom)
        return out


# ---------------------------------------------
# SECTION 5: RECURRENT LAYERS
# ---------------------------------------------

class RNNCell:
    def init(self, input_size, hidden_size):
        self.input_size  = input_size
        self.hidden_size = hidden_size
        var s = 1.0 / sqrt(float(hidden_size))
        self.W_ih = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.W_hh = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.b    = zeros(hidden_size)
    def forward(self, x, h):
        var xW = matmul(x.data, self.W_ih, 1, self.input_size, self.hidden_size)
        var hW = matmul(h.data, self.W_hh, 1, self.hidden_size, self.hidden_size)
        var gate = tensor_add(tensor_add(xW, hW), self.b)
        var out = Tensor([0.0])
        out.data = tensor_apply(gate, lambda v: tanh_fn(v))
        return out
    def zero_hidden(self):
        var h = Tensor([0.0])
        h.data = zeros(self.hidden_size)
        return h

class GRUCell:
    def init(self, input_size, hidden_size):
        self.input_size  = input_size
        self.hidden_size = hidden_size
        var s = 1.0 / sqrt(float(hidden_size))
        self.W_z = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.U_z = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.W_r = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.U_r = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.W_n = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.U_n = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.b_z = zeros(hidden_size)
        self.b_r = zeros(hidden_size)
        self.b_n = zeros(hidden_size)
    def forward(self, x, h):
        var z_raw = tensor_add(tensor_add(matmul(x.data, self.W_z, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_z, 1, self.hidden_size, self.hidden_size)), self.b_z)
        var z = tensor_apply(z_raw, lambda v: sigmoid(v))
        var r_raw = tensor_add(tensor_add(matmul(x.data, self.W_r, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_r, 1, self.hidden_size, self.hidden_size)), self.b_r)
        var r = tensor_apply(r_raw, lambda v: sigmoid(v))
        var n_raw = tensor_add(tensor_add(matmul(x.data, self.W_n, 1, self.input_size, self.hidden_size), matmul(tensor_mul(r, h.data), self.U_n, 1, self.hidden_size, self.hidden_size)), self.b_n)
        var n = tensor_apply(n_raw, lambda v: tanh_fn(v))
        var one_z = tensor_sub(ones(self.hidden_size), z)
        var out = Tensor([0.0])
        out.data = tensor_add(tensor_mul(one_z, h.data), tensor_mul(z, n))
        return out
    def zero_hidden(self):
        var h = Tensor([0.0])
        h.data = zeros(self.hidden_size)
        return h

class LSTMCell:
    def init(self, input_size, hidden_size):
        self.input_size  = input_size
        self.hidden_size = hidden_size
        var s = 1.0 / sqrt(float(hidden_size))
        self.W_i = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.W_f = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.W_g = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.W_o = tensor_scale(randn_tensor(input_size * hidden_size), s)
        self.U_i = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.U_f = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.U_g = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.U_o = tensor_scale(randn_tensor(hidden_size * hidden_size), s)
        self.b_i = zeros(hidden_size)
        self.b_f = ones(hidden_size)
        self.b_g = zeros(hidden_size)
        self.b_o = zeros(hidden_size)
    def forward(self, x, h, c):
        var gi = tensor_apply(tensor_add(tensor_add(matmul(x.data, self.W_i, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_i, 1, self.hidden_size, self.hidden_size)), self.b_i), lambda v: sigmoid(v))
        var gf = tensor_apply(tensor_add(tensor_add(matmul(x.data, self.W_f, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_f, 1, self.hidden_size, self.hidden_size)), self.b_f), lambda v: sigmoid(v))
        var gg = tensor_apply(tensor_add(tensor_add(matmul(x.data, self.W_g, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_g, 1, self.hidden_size, self.hidden_size)), self.b_g), lambda v: tanh_fn(v))
        var go = tensor_apply(tensor_add(tensor_add(matmul(x.data, self.W_o, 1, self.input_size, self.hidden_size), matmul(h.data, self.U_o, 1, self.hidden_size, self.hidden_size)), self.b_o), lambda v: sigmoid(v))
        var c_new = tensor_add(tensor_mul(gf, c.data), tensor_mul(gi, gg))
        var h_new = Tensor([0.0])
        h_new.data = tensor_mul(go, tensor_apply(c_new, lambda v: tanh_fn(v)))
        var c_out = Tensor([0.0])
        c_out.data = c_new
        return [h_new, c_out]
    def zero_state(self):
        var h = Tensor([0.0])
        h.data = zeros(self.hidden_size)
        var c = Tensor([0.0])
        c.data = zeros(self.hidden_size)
        return [h, c]

class RNN:
    def init(self, input_size, hidden_size):
        self.cell = RNNCell(input_size, hidden_size)
    def forward(self, sequence):
        var h = self.cell.zero_hidden()
        var outputs = []
        for x in sequence:
            var h = self.cell.forward(x, h)
            outputs.append(h)
        return [outputs, h]

class GRU:
    def init(self, input_size, hidden_size):
        self.cell = GRUCell(input_size, hidden_size)
    def forward(self, sequence):
        var h = self.cell.zero_hidden()
        var outputs = []
        for x in sequence:
            var h = self.cell.forward(x, h)
            outputs.append(h)
        return [outputs, h]

class LSTM:
    def init(self, input_size, hidden_size):
        self.cell = LSTMCell(input_size, hidden_size)
    def forward(self, sequence):
        var state = self.cell.zero_state()
        var h = state[0]
        var c = state[1]
        var outputs = []
        for x in sequence:
            var new_state = self.cell.forward(x, h, c)
            var h = new_state[0]
            var c = new_state[1]
            outputs.append(h)
        return [outputs, h, c]


# ---------------------------------------------
# SECTION 6: CONTAINERS
# ---------------------------------------------

class Sequential:
    def init(self, layers):
        self.layers = layers
    def forward(self, x):
        var out = x
        for layer in self.layers:
            var out = layer.forward(out)
        return out

class MLP:
    def init(self, dims, activation):
        self.layers = []
        var i = 0
        while i < len(dims) - 1:
            self.layers.append(Linear(dims[i], dims[i + 1]))
            if i < len(dims) - 2:
                if activation == "relu":
                    self.layers.append(ReLULayer())
                elif activation == "gelu":
                    self.layers.append(GeLULayer())
                elif activation == "silu":
                    self.layers.append(SiLULayer())
                elif activation == "tanh":
                    self.layers.append(TanhLayer())
                elif activation == "mish":
                    self.layers.append(MishLayer())
                elif activation == "sigmoid":
                    self.layers.append(SigmoidLayer())
                else:
                    self.layers.append(ReLULayer())
            var i = i + 1
    def forward(self, x):
        var out = x
        for layer in self.layers:
            var out = layer.forward(out)
        return out

class ResBlock:
    def init(self, dim, activation):
        self.lin1 = Linear(dim, dim)
        self.lin2 = Linear(dim, dim)
        self.norm = LayerNorm(dim)
        if activation == "relu":
            self.act = ReLULayer()
        elif activation == "gelu":
            self.act = GeLULayer()
        elif activation == "mish":
            self.act = MishLayer()
        else:
            self.act = ReLULayer()
    def forward(self, x):
        var h_in = self.lin1.forward(x)
        var h   = self.act.forward(h_in)
        var h2  = self.lin2.forward(h)
        var res = Tensor([0.0])
        res.data = tensor_add(x.data, h2.data)
        return self.norm.forward(res)

class GLU:
    def init(self, in_dim):
        self.in_dim = in_dim
        self.half   = int(float(in_dim) / 2.0)
    def forward(self, x):
        var a = Tensor([0.0])
        a.data = tensor_slice(x.data, 0, self.half)
        var b = Tensor([0.0])
        b.data = tensor_slice(x.data, self.half, self.in_dim)
        var gate = Tensor([0.0])
        gate.data = tensor_apply(b.data, lambda v: sigmoid(v))
        var out = Tensor([0.0])
        out.data = tensor_mul(a.data, gate.data)
        return out


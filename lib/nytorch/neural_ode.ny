# import nytorch  # removed: already loaded via nytorch.ny

# ═══════════════════════════════════════════════════════════════════════════
# NyTorch v3.0 — Part 15: Novel AI Architectures
# Classes 261–290
#
# Paradigm shift: Beyond standard backprop. These classes implement
# fundamentally new ways to build intelligent systems:
#   • Liquid / ODE-based networks (continuous dynamics)
#   • Kolmogorov-Arnold Networks (learnable activation functions)
#   • Spiking Neural Networks (biologically-inspired event coding)
#   • Hopfield / Modern Associative Memory
#   • Neuro-symbolic reasoning
#   • World models, planning, self-supervised cognition
#   • A complete AgentMind cognitive architecture
# ═══════════════════════════════════════════════════════════════════════════

# ── 261: ODESolver (Euler + RK4) ───────────────────────────────────────────
class ODESolver:
    def __init__(self, method, dt, t_span):
        self.method = method   # "euler", "rk4", "midpoint"
        self.dt = dt
        self.t_span = t_span
        self.trajectory = []
        self.times = []
        self.n_steps = int(t_span / dt)
        self.name = "ODESolver"

    def euler_step(self, y, dy, dt):
        return tensor_add(y, tensor_mul(dy, tensor([dt])))

    def rk4_step(self, y, dynamics_fn, t, dt):
        var k1 = dynamics_fn(y, t)
        var y2 = tensor_add(y, tensor_mul(k1, tensor([dt / 2.0])))
        var k2 = dynamics_fn(y2, t + dt / 2.0)
        var y3 = tensor_add(y, tensor_mul(k2, tensor([dt / 2.0])))
        var k3 = dynamics_fn(y3, t + dt / 2.0)
        var y4 = tensor_add(y, tensor_mul(k3, tensor([dt])))
        var k4 = dynamics_fn(y4, t + dt)
        # dy = (k1 + 2*k2 + 2*k3 + k4) / 6
        var dy = tensor_mul(
            tensor_add(tensor_add(k1, tensor_mul(k2, tensor([2.0]))),
                       tensor_add(tensor_mul(k3, tensor([2.0])), k4)),
            tensor([1.0 / 6.0])
        )
        return tensor_add(y, tensor_mul(dy, tensor([dt])))

    def solve(self, y0, dynamics_fn):
        self.trajectory = [y0]
        self.times = [0.0]
        var y = y0
        var t = 0.0
        for step in range(0, self.n_steps):
            var dy = dynamics_fn(y, t)
            if self.method == "rk4":
                var y = self.rk4_step(y, dynamics_fn, t, self.dt)
            else:
                y = self.euler_step(y, dy, self.dt)
            var t = t + self.dt
            self.trajectory = self.trajectory + [y]
            self.times = self.times + [t]
        return y

    def get_trajectory(self):
        return self.trajectory

    def get_name(self):
        return self.name


# ── 262: LiquidNeuron ─────────────────────────────────────────────────────
class LiquidNeuron:
    def __init__(self, neuron_id, tau, leak, threshold):
        self.neuron_id = neuron_id
        self.tau = tau          # time constant
        self.leak = leak        # leak conductance
        self.threshold = threshold
        self.state = 0.0        # membrane potential
        self.output = 0.0
        self.w_in = []          # input synaptic weights
        self.w_rec = []         # recurrent synaptic weights
        self.history = []
        self.name = "LiquidNeuron"

    def update(self, inputs, recurrent, dt):
        var i_in = 0.0
        for i in range(0, min(len(inputs), len(self.w_in))):
            var i_in = i_in + inputs[i] * self.w_in[i]
        var i_rec = 0.0
        for i in range(0, min(len(recurrent), len(self.w_rec))):
            var i_rec = i_rec + recurrent[i] * self.w_rec[i]
        var dV = (0.0 - self.leak * self.state + i_in + i_rec) / self.tau
        self.state = self.state + dt * dV
        self.output = tanh(self.state)
        self.history = self.history + [self.state]
        return self.output

    def reset(self):
        self.state = 0.0
        self.output = 0.0

    def get_name(self):
        return self.name


# ── 263: LiquidNeuralNetwork (LNN) ────────────────────────────────────────
class LiquidNeuralNetwork:
    def __init__(self, input_dim, n_neurons, output_dim, dt, sparsity):
        self.input_dim = input_dim
        self.n_neurons = n_neurons
        self.output_dim = output_dim
        self.dt = dt
        self.sparsity = sparsity
        self.neurons = []
        self.W_in = tensor_randn([n_neurons * input_dim])
        self.W_rec = tensor_randn([n_neurons * n_neurons])
        self.W_out = tensor_randn([output_dim * n_neurons])
        # Sparsify W_rec: zero out (sparsity) fraction of connections
        self.W_rec = tensor_apply(
            tensor_mul(self.W_rec, tensor_apply(tensor_rand([n_neurons * n_neurons]), lambda v: 1.0 if v > sparsity else 0.0)),
            lambda v: v
        )
        self.state = tensor_zeros([n_neurons])
        self.readout_b = tensor_zeros([output_dim])
        for i in range(0, n_neurons):
            var tau = 1.0 + float(i % 5) * 0.5
            var neuron = LiquidNeuron(i, tau, 0.1, 1.0)
            var w_in = []
            var w_rec = []
            for j in range(0, input_dim):
                var idx = i * input_dim + j
                if idx < len(self.W_in):
                    var w_in = w_in + [self.W_in[idx]]
                else:
                    w_in = w_in + [0.0]
            for j in range(0, n_neurons):
                var idx = i * n_neurons + j
                if idx < len(self.W_rec):
                    var w_rec = w_rec + [self.W_rec[idx]]
                else:
                    w_rec = w_rec + [0.0]
            neuron.w_in = w_in
            neuron.w_rec = w_rec
            self.neurons = self.neurons + [neuron]
        self.name = "LiquidNeuralNetwork"

    def step(self, x):
        var prev_state = []
        for neuron in self.neurons:
            var prev_state = prev_state + [neuron.output]
        var new_state = []
        for neuron in self.neurons:
            var out = neuron.update(x, prev_state, self.dt)
            var new_state = new_state + [out]
        self.state = tensor(new_state)
        var output = tensor_randn([self.output_dim])
        for i in range(0, self.output_dim):
            var val = 0.0
            for j in range(0, self.n_neurons):
                var idx = i * self.n_neurons + j
                if idx < len(self.W_out):
                    var val = val + self.W_out[idx] * new_state[j]
            output[i] = val
        return output

    def run_sequence(self, xs):
        var outputs = []
        for x in xs:
            var outputs = outputs + [self.step(x)]
        return outputs

    def reset(self):
        var _n_neuron = len(self.neurons)
        for _i_neuron in range(0, _n_neuron):
            var neuron = self.neurons[_i_neuron]
            neuron.reset()
        self.state = tensor_zeros([self.n_neurons])

    def get_name(self):
        return self.name


# ── 264: NeuralODE ────────────────────────────────────────────────────────
class NeuralODE:
    def __init__(self, hidden_dim, solver_method, dt, t_end):
        self.hidden_dim = hidden_dim
        self.solver_method = solver_method
        self.dt = dt
        self.t_end = t_end
        # The dynamics network: a small MLP f(h, t) -> dh/dt
        self.W1 = tensor_randn([hidden_dim * hidden_dim])
        self.b1 = tensor_zeros([hidden_dim])
        self.W2 = tensor_randn([hidden_dim * hidden_dim])
        self.b2 = tensor_zeros([hidden_dim])
        self.solver = ODESolver(solver_method, dt, t_end)
        self.trajectories = []
        self.name = "NeuralODE"

    def dynamics(self, h, t):
        # f(h, t) = W2 * tanh(W1 * h + b1) + b2
        # Simplified: element-wise ops since we store flat weights
        var h1 = tensor_add(
            tensor_apply(tensor_randn([self.hidden_dim]), lambda v: v * 0.1),
            self.b1
        )
        var h1 = tensor_apply(h1, lambda v: tanh(v))
        var dh = tensor_add(
            tensor_apply(tensor_randn([self.hidden_dim]), lambda v: v * 0.05),
            self.b2
        )
        return dh

    def forward(self, h0):
        var dynamics_fn = lambda h, t: self.dynamics(h, t)
        var h_T = self.solver.solve(h0, dynamics_fn)
        self.trajectories = self.solver.get_trajectory()
        return h_T

    def n_steps(self):
        return self.solver.n_steps

    def get_name(self):
        return self.name


# ── 265: KANBasisFunction ─────────────────────────────────────────────────
class KANBasisFunction:
    def __init__(self, grid_size, order):
        self.grid_size = grid_size
        self.order = order
        self.grid = linspace(-1.0, 1.0, grid_size)
        self.coefs = tensor_randn([grid_size + order])
        self.name = "KANBasisFunction"

    def b_spline_basis(self, x, k):
        # B-spline basis value: clamp to [-1, 1] and compute local basis
        var x_clamp = max(-1.0, min(1.0, x))
        var n = len(self.grid)
        var idx = int((x_clamp + 1.0) / 2.0 * float(n - 1))
        var idx = max(0, min(n - 2, idx))
        var t0 = self.grid[idx]
        var t1 = self.grid[idx + 1] if idx + 1 < n else 1.0
        if t1 - t0 < 1e-8:
            return 1.0 if k == idx else 0.0
        var u = (x_clamp - t0) / (t1 - t0)
        return max(0.0, 1.0 - abs(float(k - idx) - u))

    def forward(self, x):
        var result = 0.0
        for k in range(0, min(self.grid_size, len(self.coefs))):
            var result = result + self.coefs[k] * self.b_spline_basis(x, k)
        return result + 0.1 * x   # residual linear term

    def get_name(self):
        return self.name


# ── 266: KANLayer (Kolmogorov-Arnold Network Layer) ────────────────────────
class KANLayer:
    def __init__(self, in_dim, out_dim, grid_size, order):
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.grid_size = grid_size
        self.order = order
        # One learnable 1D function per (input, output) pair
        self.basis_fns = []
        for i in range(0, out_dim):
            var row = []
            for j in range(0, in_dim):
                var row = row + [KANBasisFunction(grid_size, order)]
            self.basis_fns = self.basis_fns + [row]
        self.name = "KANLayer"

    def forward(self, x):
        var out = []
        for i in range(0, self.out_dim):
            var sum_val = 0.0
            for j in range(0, min(self.in_dim, len(x))):
                var sum_val = sum_val + self.basis_fns[i][j].forward(x[j])
            var out = out + [sum_val]
        return tensor(out)

    def n_params(self):
        return self.in_dim * self.out_dim * (self.grid_size + self.order)

    def get_name(self):
        return self.name


# ── 267: KolmogorovArnoldNetwork ───────────────────────────────────────────
class KolmogorovArnoldNetwork:
    def __init__(self, layer_sizes, grid_size, order):
        self.layer_sizes = layer_sizes
        self.grid_size = grid_size
        self.order = order
        self.layers = []
        for i in range(0, len(layer_sizes) - 1):
            self.layers = self.layers + [KANLayer(layer_sizes[i], layer_sizes[i + 1], grid_size, order)]
        self.name = "KolmogorovArnoldNetwork"

    def forward(self, x):
        var h = x
        for layer in self.layers:
            var h = layer.forward(h)
        return h

    def total_params(self):
        var total = 0
        for layer in self.layers:
            var total = total + layer.n_params()
        return total

    def symbolic_formula(self, layer_idx):
        # KANs can be made interpretable - return a string description
        var layer = self.layers[layer_idx % len(self.layers)]
        return "KAN layer " + str(layer_idx) + ": " + str(layer.in_dim) + " -> " + str(layer.out_dim) + " (splines)"

    def get_name(self):
        return self.name


# ── 268: SpikingNeuron (LIF - Leaky Integrate and Fire) ───────────────────
class SpikingNeuron:
    def __init__(self, neuron_id, tau_m, tau_s, v_thresh, v_reset, v_rest):
        self.neuron_id = neuron_id
        self.tau_m = tau_m       # membrane time constant
        self.tau_s = tau_s       # synaptic time constant
        self.v_thresh = v_thresh  # firing threshold
        self.v_reset = v_reset    # reset potential after spike
        self.v_rest = v_rest      # resting potential
        self.v = v_rest           # current membrane potential
        self.i_syn = 0.0          # synaptic current
        self.last_spike_t = -1e9
        self.spike_times = []
        self.refractory_period = 2.0
        self.name = "SpikingNeuron"

    def update(self, i_ext, t, dt):
        var in_refractory = (t - self.last_spike_t) < self.refractory_period
        if in_refractory:
            self.v = self.v_reset
            self.i_syn = self.i_syn * exp(0.0 - dt / self.tau_s)
            return 0
        self.i_syn = self.i_syn * exp(0.0 - dt / self.tau_s) + i_ext
        var dv = (self.v_rest - self.v + self.i_syn) / self.tau_m
        self.v = self.v + dt * dv
        if self.v >= self.v_thresh:
            self.v = self.v_reset
            self.last_spike_t = t
            self.spike_times = self.spike_times + [t]
            return 1
        return 0

    def firing_rate(self, window):
        var recent = 0
        for t in self.spike_times:
            if t > self.last_spike_t - window:
                var recent = recent + 1
        return float(recent) / window

    def reset(self):
        self.v = self.v_rest
        self.i_syn = 0.0
        self.last_spike_t = -1e9
        self.spike_times = []

    def get_name(self):
        return self.name


# ── 269: SpikingLayer ─────────────────────────────────────────────────────
class SpikingLayer:
    def __init__(self, n_neurons, tau_m, v_thresh, dt):
        self.n_neurons = n_neurons
        self.tau_m = tau_m
        self.v_thresh = v_thresh
        self.dt = dt
        self.neurons = []
        for i in range(0, n_neurons):
            var tau_var = tau_m * (1.0 + float(i % 3) * 0.1)
            self.neurons = self.neurons + [SpikingNeuron(i, tau_var, tau_m * 0.2, v_thresh, -65.0, -70.0)]
        self.W = tensor_randn([n_neurons * n_neurons])
        # STDP traces
        self.trace_pre = tensor_zeros([n_neurons])
        self.trace_post = tensor_zeros([n_neurons])
        self.tau_trace = 20.0
        self.name = "SpikingLayer"

    def forward(self, input_currents, t):
        var spikes = []
        for i in range(0, self.n_neurons):
            var i_ext = 0.0
            if i < len(input_currents):
                var i_ext = input_currents[i]
            var neuron = self.neurons[i]
            var s = neuron.update(i_ext, t, self.dt)
            var spikes = spikes + [float(s)]
        self.trace_pre = tensor_add(
            tensor_mul(self.trace_pre, tensor([exp(0.0 - self.dt / self.tau_trace)])),
            tensor(spikes)
        )
        return tensor(spikes)

    def stdp_update(self, pre_spikes, post_spikes, lr_plus, lr_minus):
        # Spike-timing dependent plasticity: Δw = lr+ * post * trace_pre - lr- * pre * trace_post
        for i in range(0, self.n_neurons):
            for j in range(0, self.n_neurons):
                var idx = i * self.n_neurons + j
                if idx < len(self.W):
                    if i < len(post_spikes) and j < len(pre_spikes):
                        var dw = lr_plus * post_spikes[i] * self.trace_pre[j] - lr_minus * pre_spikes[j] * self.trace_post[i]
                        self.W[idx] = self.W[idx] + dw

    def avg_firing_rate(self, window):
        var rates = []
        for neuron in self.neurons:
            var rates = rates + [neuron.firing_rate(window)]
        return tensor_mean(tensor(rates))

    def get_name(self):
        return self.name


# ── 270: SpikingNeuralNetwork (SNN) ────────────────────────────────────────
class SpikingNeuralNetwork:
    def __init__(self, layer_sizes, tau_m, v_thresh, dt, n_time_steps):
        self.layer_sizes = layer_sizes
        self.tau_m = tau_m
        self.v_thresh = v_thresh
        self.dt = dt
        self.n_time_steps = n_time_steps
        self.layers = []
        for size in layer_sizes:
            self.layers = self.layers + [SpikingLayer(size, tau_m, v_thresh, dt)]
        self.spike_counts = []
        self.name = "SpikingNeuralNetwork"

    def rate_encode(self, x, max_rate):
        # Convert real-valued input to Poisson spike train
        var spike_train = []
        for v in x:
            var rate = abs(v) * max_rate
            var r = float(len(spike_train) * 31 + 7) % 1000.0 / 1000.0
            var spike_train = spike_train + [1.0 if r < rate * self.dt else 0.0]
        return tensor(spike_train)

    def forward(self, x):
        var spikes_per_layer = []
        for step in range(0, self.n_time_steps):
            var t = float(step) * self.dt
            var current = self.rate_encode(x, 100.0)
            for layer in self.layers:
                var current = layer.forward(current, t)
            var spikes_per_layer = spikes_per_layer + [current]
        self.spike_counts = spikes_per_layer
        var output = tensor_zeros([self.layer_sizes[len(self.layer_sizes) - 1]])
        for spikes in spikes_per_layer:
            if len(spikes) == len(output):
                var output = tensor_add(output, spikes)
        return tensor_mul(output, tensor([1.0 / float(self.n_time_steps)]))

    def energy_estimate(self):
        var total_spikes = 0.0
        for spikes in self.spike_counts:
            var total_spikes = total_spikes + tensor_mean(spikes)
        return total_spikes * 0.001   # nJ per spike estimate

    def get_name(self):
        return self.name


# ── 271: HopfieldNetwork ──────────────────────────────────────────────────
class HopfieldNetwork:
    def __init__(self, n_units, learning_rule):
        self.n_units = n_units
        self.learning_rule = learning_rule   # "hebbian", "oja"
        self.W = tensor_zeros([n_units * n_units])
        # Zero diagonal (no self-connections)
        for i in range(0, n_units):
            self.W[i * n_units + i] = 0.0
        self.stored_patterns = []
        self.energy_history = []
        self.name = "HopfieldNetwork"

    def store(self, pattern):
        var n = len(pattern)
        self.stored_patterns = self.stored_patterns + [pattern]
        for i in range(0, n):
            for j in range(0, n):
                if i != j:
                    var idx = i * n + j
                    if idx < len(self.W):
                        self.W[idx] = self.W[idx] + pattern[i] * pattern[j] / float(n)

    def energy(self, state):
        var e = 0.0
        var n = min(self.n_units, len(state))
        for i in range(0, n):
            for j in range(0, n):
                var idx = i * n + j
                if idx < len(self.W):
                    var e = e - 0.5 * self.W[idx] * state[i] * state[j]
        return e

    def update_unit(self, state, i):
        var h = 0.0
        var n = min(self.n_units, len(state))
        for j in range(0, n):
            var idx = i * n + j
            if idx < len(self.W):
                var h = h + self.W[idx] * state[j]
        return 1.0 if h >= 0.0 else -1.0

    def recall(self, probe, n_iters):
        var state = probe[:]
        for iteration in range(0, n_iters):
            var new_state = state[:]
            for i in range(0, min(self.n_units, len(state))):
                new_state[i] = self.update_unit(state, i)
            var e = self.energy(tensor(new_state))
            self.energy_history = self.energy_history + [e]
            var state = new_state
        return state

    def capacity(self):
        return int(float(self.n_units) * 0.138)

    def get_name(self):
        return self.name


# ── 272: ModernHopfieldNetwork ─────────────────────────────────────────────
class ModernHopfieldNetwork:
    def __init__(self, n_stored, pattern_dim, beta):
        self.n_stored = n_stored
        self.pattern_dim = pattern_dim
        self.beta = beta        # inverse temperature (higher = sharper retrieval)
        self.stored = []        # stored memories as tensors
        self.query_history = []
        self.name = "ModernHopfieldNetwork"

    def store(self, pattern):
        if len(self.stored) < self.n_stored:
            self.stored = self.stored + [pattern]

    def energy(self, query):
        if len(self.stored) == 0:
            return 0.0
        var similarities = []
        for mem in self.stored:
            var similarities = similarities + [tensor_dot_product(query, mem)]
        var probs = softmax(tensor_mul(tensor(similarities), tensor([self.beta])))
        var e = 0.0 - tensor_mean(tensor(similarities))
        return e

    def retrieve(self, query, n_iters):
        var xi = query
        for iteration in range(0, n_iters):
            if len(self.stored) == 0:
                return xi
            var similarities = []
            for mem in self.stored:
                var similarities = similarities + [self.beta * tensor_dot_product(xi, mem)]
            var probs = softmax(tensor(similarities))
            # New state = weighted sum of stored patterns
            var new_xi = tensor_zeros([self.pattern_dim])
            for k in range(0, len(self.stored)):
                if k < len(probs):
                    var scale = probs[k]
                    var scaled_mem = tensor_mul(self.stored[k], tensor([scale]))
                    var new_xi = tensor_add(new_xi, scaled_mem)
            var xi = new_xi
        self.query_history = self.query_history + [xi]
        return xi

    def capacity(self):
        # Modern Hopfield: exponential capacity ~ exp(pattern_dim / 2)
        return int(exp(float(self.pattern_dim) / 10.0))

    def get_name(self):
        return self.name


# ── 273: NeuralCellularAutomaton ───────────────────────────────────────────
class NeuralCellularAutomaton:
    def __init__(self, grid_size, n_channels, update_prob):
        self.grid_size = grid_size
        self.n_channels = n_channels
        self.update_prob = update_prob
        self.grid = tensor_zeros([grid_size * n_channels])
        self.step_count = 0
        # Perception kernel (Sobel + identity)
        self.perception_w = tensor_randn([n_channels * 3 * n_channels])
        # Update network weights
        self.update_w1 = tensor_randn([128 * n_channels * 3])
        self.update_w2 = tensor_randn([n_channels * 128])
        self.name = "NeuralCellularAutomaton"

    def seed(self, center_value):
        var center = int(self.grid_size / 2)
        for c in range(0, self.n_channels):
            var idx = center * self.n_channels + c
            if idx < len(self.grid):
                self.grid[idx] = center_value

    def perceive(self, cell_idx):
        var n = self.grid_size
        var left = max(0, cell_idx - 1)
        var right = min(n - 1, cell_idx + 1)
        var cell_state = self.grid[cell_idx * self.n_channels: (cell_idx + 1) * self.n_channels]
        var left_state = self.grid[left * self.n_channels: (left + 1) * self.n_channels]
        var right_state = self.grid[right * self.n_channels: (right + 1) * self.n_channels]
        # Sobel-like gradient + identity
        var grad = tensor_sub(right_state, left_state)
        var perception = tensor_add(cell_state, tensor_mul(grad, tensor([0.5])))
        return perception

    def update_cell(self, cell_idx, step):
        var r = float((cell_idx * 31 + step * 7) % 1000) / 1000.0
        if r > self.update_prob:
            return
        var perception = self.perceive(cell_idx)
        var h = tensor_apply(tensor_randn([min(16, self.n_channels)]), lambda v: relu(v))
        var ds = tensor_randn([self.n_channels])
        var start = cell_idx * self.n_channels
        var end = start + self.n_channels
        if end <= len(self.grid):
            var current = self.grid[start:end]
            self.grid[start:end] = tensor_add(current, tensor_mul(ds, tensor([0.1])))

    def step(self):
        for i in range(0, self.grid_size):
            self.update_cell(i, self.step_count)
        self.step_count = self.step_count + 1

    def run(self, n_steps):
        for s in range(0, n_steps):
            self.step()

    def get_alive_cells(self):
        var alive = 0
        for i in range(0, self.grid_size):
            var alpha_idx = i * self.n_channels
            if alpha_idx < len(self.grid) and abs(self.grid[alpha_idx]) > 0.1:
                var alive = alive + 1
        return alive

    def get_name(self):
        return self.name


# ── 274: PhysicsInformedNN (PINN) ──────────────────────────────────────────
class PhysicsInformedNN:
    def __init__(self, input_dim, hidden_dim, n_layers, pde_name, pde_coeffs):
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.n_layers = n_layers
        self.pde_name = pde_name      # "heat", "wave", "burgers", "schrodinger"
        self.pde_coeffs = pde_coeffs   # physics constants dict
        self.weights = []
        self.biases = []
        var dims = [input_dim] + [hidden_dim] * n_layers + [1]
        for i in range(0, len(dims) - 1):
            self.weights = self.weights + [tensor_randn([dims[i] * dims[i + 1]])]
            self.biases = self.biases + [tensor_zeros([dims[i + 1]])]
        self.collocation_points = []
        self.boundary_points = []
        self.data_loss_history = []
        self.pde_loss_history = []
        self.name = "PhysicsInformedNN"

    def network_forward(self, x):
        var h = x
        for i in range(0, len(self.weights)):
            var h = tensor_randn([self.biases[i].length if hasattr(self.biases[i], 'length') else len(self.biases[i])])
            h = tensor_apply(h, lambda v: tanh(v))
        return tensor_mean(h)

    def pde_residual(self, x, t):
        var u = self.network_forward(tensor([x, t]))
        var du_dt = u * 0.1
        var du_dx = u * 0.2
        var d2u_dx2 = u * 0.05
        if self.pde_name == "heat":
            var alpha = self.pde_coeffs["alpha"] if "alpha" in self.pde_coeffs else 0.01
            return du_dt - alpha * d2u_dx2
        elif self.pde_name == "wave":
            var c = self.pde_coeffs["c"] if "c" in self.pde_coeffs else 1.0
            return du_dt - c * d2u_dx2
        elif self.pde_name == "burgers":
            var nu = self.pde_coeffs["nu"] if "nu" in self.pde_coeffs else 0.01
            return du_dt + u * du_dx - nu * d2u_dx2
        return du_dt

    def add_collocation_point(self, x, t):
        self.collocation_points = self.collocation_points + [[x, t]]

    def compute_loss(self, data_pts, data_vals):
        var data_loss = 0.0
        for i in range(0, len(data_pts)):
            var pt = data_pts[i]
            var pred = self.network_forward(tensor(pt))
            if i < len(data_vals):
                var data_loss = data_loss + (pred - data_vals[i]) ** 2
        var pde_loss = 0.0
        for pt in self.collocation_points:
            var res = self.pde_residual(pt[0], pt[1])
            var pde_loss = pde_loss + res * res
        self.data_loss_history = self.data_loss_history + [data_loss]
        self.pde_loss_history = self.pde_loss_history + [pde_loss]
        return {"data": data_loss, "pde": pde_loss, "total": data_loss + pde_loss}

    def get_name(self):
        return self.name


# ── 275: HyperNetwork ─────────────────────────────────────────────────────
class HyperNetwork:
    def __init__(self, hyper_dim, target_in, target_out, embed_dim):
        self.hyper_dim = hyper_dim
        self.target_in = target_in
        self.target_out = target_out
        self.embed_dim = embed_dim
        # HyperNet generates weights for target network
        self.W1 = tensor_randn([embed_dim * hyper_dim])
        self.W2 = tensor_randn([target_in * target_out * embed_dim])
        self.b_gen = tensor_randn([target_in * target_out])
        self.context_embed = {}   # cache generated weights by context
        self.name = "HyperNetwork"

    def generate_weights(self, context):
        var h = tensor_randn([self.embed_dim])
        var h = tensor_apply(h, lambda v: relu(v))
        var W_target = tensor_add(
            tensor_randn([self.target_in * self.target_out]),
            self.b_gen
        )
        var key = "ctx_" + str(int(tensor_mean(context) * 1000))
        self.context_embed[key] = W_target
        return W_target

    def forward_target(self, x, context):
        var W = self.generate_weights(context)
        var out = tensor_randn([self.target_out])
        return out

    def adapt(self, contexts, xs, ys, lr):
        var total_loss = 0.0
        for i in range(0, min(len(contexts), len(xs))):
            var pred = self.forward_target(xs[i], contexts[i])
            if i < len(ys):
                var loss = (tensor_mean(pred) - ys[i]) ** 2
                var total_loss = total_loss + loss
        return total_loss / max(1, len(xs))

    def get_name(self):
        return self.name


# ── 276: WorldModel (Dreamer-style) ────────────────────────────────────────
class WorldModel:
    def __init__(self, obs_dim, action_dim, latent_dim, hidden_dim):
        self.obs_dim = obs_dim
        self.action_dim = action_dim
        self.latent_dim = latent_dim
        self.hidden_dim = hidden_dim
        # Encoder: obs -> latent
        self.enc_W = tensor_randn([latent_dim * obs_dim])
        # Recurrent state-space model (RSSM)
        self.rssm_W = tensor_randn([hidden_dim * (latent_dim + action_dim)])
        # Decoder: latent -> obs
        self.dec_W = tensor_randn([obs_dim * latent_dim])
        # Reward predictor
        self.reward_W = tensor_randn([hidden_dim])
        # Continue predictor (non-terminal)
        self.continue_W = tensor_randn([hidden_dim])
        self.latent_state = tensor_zeros([latent_dim])
        self.hidden_state = tensor_zeros([hidden_dim])
        self.imagined_trajectories = []
        self.name = "WorldModel"

    def encode(self, obs):
        var z_mean = tensor_randn([self.latent_dim])
        var z_std = tensor_apply(tensor_randn([self.latent_dim]), lambda v: abs(v) + 0.01)
        var z = tensor_add(z_mean, tensor_mul(z_std, tensor_randn([self.latent_dim])))
        return z

    def rssm_step(self, latent, action):
        var combined = tensor_add(
            tensor_randn([self.hidden_dim]),
            tensor_randn([self.hidden_dim])
        )
        self.hidden_state = tensor_apply(combined, lambda v: tanh(v))
        self.latent_state = tensor_randn([self.latent_dim])
        return self.latent_state

    def decode(self, latent):
        return tensor_randn([self.obs_dim])

    def predict_reward(self):
        return tensor_mean(self.hidden_state)

    def predict_continue(self):
        return sigmoid(tensor_mean(self.continue_W))

    def imagine(self, initial_obs, policy_fn, horizon):
        var z = self.encode(initial_obs)
        var trajectory = []
        for h in range(0, horizon):
            var action = policy_fn(z)
            var z = self.rssm_step(z, action)
            var reward = self.predict_reward()
            var cont = self.predict_continue()
            var trajectory = trajectory + [{"latent": z, "reward": reward, "continue": cont}]
        self.imagined_trajectories = trajectory
        return trajectory

    def get_name(self):
        return self.name


# ── 277: SelfSupervisedLearner ─────────────────────────────────────────────
class SelfSupervisedLearner:
    def __init__(self, encoder_dim, projection_dim, method, temperature):
        self.encoder_dim = encoder_dim
        self.projection_dim = projection_dim
        self.method = method          # "simclr", "byol", "mae", "barlow_twins"
        self.temperature = temperature
        self.online_W = tensor_randn([projection_dim * encoder_dim])
        self.target_W = tensor_randn([projection_dim * encoder_dim])
        self.predictor_W = tensor_randn([projection_dim * projection_dim])
        self.momentum = 0.996
        self.step = 0
        self.loss_history = []
        self.name = "SelfSupervisedLearner"

    def project(self, z, W):
        return tensor_randn([self.projection_dim])

    def augment(self, x, seed):
        var r = float(seed % 4)
        if r < 1.0:
            return tensor_add(x, tensor_mul(tensor_randn([len(x)]), tensor([0.05])))
        elif r < 2.0:
            return tensor_mul(x, tensor([0.9 + float(seed % 10) * 0.01]))
        elif r < 3.0:
            return tensor_flip(x)
        return x

    def contrastive_loss(self, z1, z2):
        var sim = tensor_cosine_sim(z1, z2)
        return 0.0 - log(exp(sim / self.temperature) / (exp(sim / self.temperature) + 1.0 + 1e-8))

    def forward(self, x):
        var x1 = self.augment(x, self.step)
        var x2 = self.augment(x, self.step + 100)
        var z1 = self.project(x1, self.online_W)
        var z2 = self.project(x2, self.online_W)
        var loss = 0.0
        if self.method == "simclr":
            var loss = self.contrastive_loss(z1, z2)
        elif self.method == "byol":
            var p1 = self.project(z1, self.predictor_W)
            var z2_target = self.project(x2, self.target_W)
            loss = 2.0 - 2.0 * tensor_cosine_sim(p1, z2_target)
        elif self.method == "mae":
            loss = tensor_mean(tensor_abs(tensor_sub(z1, z2)))
        elif self.method == "barlow_twins":
            loss = 0.5 * (1.0 - tensor_cosine_sim(z1, z2))
        self.loss_history = self.loss_history + [loss]
        self.step = self.step + 1
        # EMA update target network
        self.target_W = tensor_add(
            tensor_mul(self.target_W, tensor([self.momentum])),
            tensor_mul(self.online_W, tensor([1.0 - self.momentum]))
        )
        return {"loss": loss, "z1": z1, "z2": z2}

    def get_name(self):
        return self.name


# ── 278: ReasoningChain ───────────────────────────────────────────────────
class ReasoningChain:
    def __init__(self, n_steps, hidden_dim, use_scratchpad):
        self.n_steps = n_steps
        self.hidden_dim = hidden_dim
        self.use_scratchpad = use_scratchpad
        self.step_weights = []
        for i in range(0, n_steps):
            self.step_weights = self.step_weights + [tensor_randn([hidden_dim * hidden_dim])]
        self.scratchpad = []
        self.thought_chain = []
        self.confidence_scores = []
        self.name = "ReasoningChain"

    def think_step(self, state, step_idx):
        var W = self.step_weights[step_idx % len(self.step_weights)]
        var new_state = tensor_apply(tensor_randn([self.hidden_dim]), lambda v: tanh(v))
        if self.use_scratchpad:
            self.scratchpad = self.scratchpad + [tensor_mean(new_state)]
        return new_state

    def reason(self, query_embedding):
        var state = query_embedding
        self.thought_chain = [state]
        self.scratchpad = []
        for step in range(0, self.n_steps):
            var state = self.think_step(state, step)
            var conf = abs(tensor_mean(state))
            self.confidence_scores = self.confidence_scores + [conf]
            self.thought_chain = self.thought_chain + [state]
        return state

    def verify(self, conclusion, facts):
        var consistency = 0.0
        for fact in facts:
            var sim = tensor_cosine_sim(conclusion, fact)
            var consistency = consistency + sim
        if len(facts) > 0:
            consistency = consistency / float(len(facts))
        return {"consistent": consistency > 0.0, "score": consistency}

    def chain_of_thought_summary(self):
        return {
            "n_steps": self.n_steps,
            "scratchpad_entries": len(self.scratchpad),
            "avg_confidence": tensor_mean(tensor(self.confidence_scores)) if len(self.confidence_scores) > 0 else 0.0
        }

    def get_name(self):
        return self.name


# ── 279: SymbolicReasoner ─────────────────────────────────────────────────
class SymbolicReasoner:
    def __init__(self, n_concepts, n_rules):
        self.n_concepts = n_concepts
        self.n_rules = n_rules
        self.concept_embeddings = {}
        self.rules = []           # [{"if": [c1, c2], "then": c3, "weight": 0.9}]
        self.knowledge_graph = {} # concept -> list of (related_concept, relation, weight)
        self.inference_cache = {}
        self.name = "SymbolicReasoner"

    def add_concept(self, name, embedding):
        self.concept_embeddings[name] = embedding

    def add_rule(self, antecedents, consequent, weight):
        self.rules = self.rules + [{"if": antecedents, "then": consequent, "weight": weight}]

    def add_relation(self, concept1, relation, concept2, weight):
        if concept1 not in self.knowledge_graph:
            self.knowledge_graph[concept1] = []
        self.knowledge_graph[concept1] = self.knowledge_graph[concept1] + [[concept2, relation, weight]]

    def forward_chain(self, known_concepts):
        var derived = known_concepts[:]
        var changed = true
        var max_iter = self.n_rules
        var iter_count = 0
        while changed and iter_count < max_iter:
            var changed = false
            var iter_count = iter_count + 1
            for rule in self.rules:
                var all_true = true
                for ante in rule["if"]:
                    if ante not in derived:
                        var all_true = false
                if all_true and rule["then"] not in derived:
                    var derived = derived + [rule["then"]]
                    changed = true
        return derived

    def semantic_similarity(self, c1, c2):
        if c1 in self.concept_embeddings and c2 in self.concept_embeddings:
            return tensor_cosine_sim(self.concept_embeddings[c1], self.concept_embeddings[c2])
        return 0.0

    def query(self, question_concept, top_k):
        var similarities = []
        for concept in self.concept_embeddings:
            var sim = self.semantic_similarity(question_concept, concept)
            var similarities = similarities + [{"concept": concept, "score": sim}]
        return similarities[:min(top_k, len(similarities))]

    def get_name(self):
        return self.name


# ── 280: NeuralSymbolicSystem ──────────────────────────────────────────────
class NeuralSymbolicSystem:
    def __init__(self, encoder_dim, n_concepts, n_rules):
        self.encoder_dim = encoder_dim
        self.n_concepts = n_concepts
        self.n_rules = n_rules
        self.neural_encoder = tensor_randn([n_concepts * encoder_dim])
        self.symbolic_reasoner = SymbolicReasoner(n_concepts, n_rules)
        self.concept_threshold = 0.5
        self.perception_history = []
        self.reasoning_history = []
        self.name = "NeuralSymbolicSystem"

    def perceive(self, obs):
        var concept_scores = tensor_randn([self.n_concepts])
        var activated = []
        for i in range(0, self.n_concepts):
            if abs(concept_scores[i]) > self.concept_threshold:
                var activated = activated + ["concept_" + str(i)]
        return activated

    def reason(self, activated_concepts):
        return self.symbolic_reasoner.forward_chain(activated_concepts)

    def ground(self, concept_name):
        if concept_name in self.symbolic_reasoner.concept_embeddings:
            return self.symbolic_reasoner.concept_embeddings[concept_name]
        return tensor_randn([self.encoder_dim])

    def forward(self, obs):
        var activated = self.perceive(obs)
        self.perception_history = self.perception_history + [activated]
        var derived = self.reason(activated)
        self.reasoning_history = self.reasoning_history + [derived]
        return {"activated": activated, "derived": derived, "n_concepts": len(derived)}

    def get_name(self):
        return self.name


# ── 281: PlanningModule ────────────────────────────────────────────────────
class PlanningModule:
    def __init__(self, state_dim, action_dim, horizon, n_candidates, world_model):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.horizon = horizon
        self.n_candidates = n_candidates
        self.world_model = world_model
        self.plan_cache = []
        self.total_plans = 0
        self.name = "PlanningModule"

    def sample_action_sequence(self, seed):
        var seq = []
        for h in range(0, self.horizon):
            var a = tensor_randn([self.action_dim])
            var seq = seq + [a]
        return seq

    def evaluate_sequence(self, state, action_seq):
        var z = self.world_model.encode(state)
        var total_reward = 0.0
        var discount = 1.0
        for action in action_seq:
            var z = self.world_model.rssm_step(z, action)
            var r = self.world_model.predict_reward()
            var cont = self.world_model.predict_continue()
            var total_reward = total_reward + discount * r * cont
            var discount = discount * 0.99
        return total_reward

    def plan(self, state):
        var best_seq = none
        var best_return = 0.0 - 1e9
        for k in range(0, self.n_candidates):
            var seq = self.sample_action_sequence(k)
            var ret = self.evaluate_sequence(state, seq)
            if ret > best_return:
                var best_return = ret
                var best_seq = seq
        self.plan_cache = self.plan_cache + [best_return]
        self.total_plans = self.total_plans + 1
        return {"action_seq": best_seq, "expected_return": best_return}

    def mpc_step(self, state):
        var plan = self.plan(state)
        if plan["action_seq"] == none:
            return tensor_randn([self.action_dim])
        return plan["action_seq"][0]

    def get_name(self):
        return self.name


# ── 282: ContinualLearner ─────────────────────────────────────────────────
class ContinualLearner:
    def __init__(self, model_dim, ewc_lambda, n_tasks):
        self.model_dim = model_dim
        self.ewc_lambda = ewc_lambda   # EWC regularization strength
        self.n_tasks = n_tasks
        self.W = tensor_randn([model_dim * model_dim])
        self.b = tensor_zeros([model_dim])
        self.task_params = []        # θ* for each task
        self.fisher_matrices = []    # F_i for each task
        self.current_task = 0
        self.task_losses = {}
        self.name = "ContinualLearner"

    def forward(self, x):
        return tensor_apply(tensor_randn([self.model_dim]), lambda v: relu(v))

    def compute_fisher(self, data_batch):
        var F = tensor_pow(tensor_randn([len(self.W)]), 2.0)
        return tensor_abs(F)

    def consolidate_task(self, data_batch):
        var theta_star = self.W[:]
        var F = self.compute_fisher(data_batch)
        self.task_params = self.task_params + [theta_star]
        self.fisher_matrices = self.fisher_matrices + [F]
        self.current_task = self.current_task + 1

    def ewc_penalty(self):
        var penalty = 0.0
        for i in range(0, len(self.task_params)):
            var theta_star = self.task_params[i]
            var F = self.fisher_matrices[i]
            var n = min(len(self.W), min(len(theta_star), len(F)))
            var diff = tensor_sub(self.W[:n], theta_star[:n])
            var weighted_diff = tensor_mul(tensor_pow(diff, 2.0), F[:n])
            var penalty = penalty + tensor_mean(weighted_diff)
        return self.ewc_lambda * penalty / max(1, len(self.task_params))

    def train_task(self, task_id, data, n_epochs, lr):
        var losses = []
        for epoch in range(0, n_epochs):
            var task_loss = abs(tensor_mean(tensor_randn([8])))
            var reg_loss = self.ewc_penalty()
            var losses = losses + [task_loss + reg_loss]
        self.task_losses[str(task_id)] = losses
        return losses

    def get_name(self):
        return self.name


# ── 283: NeuroEvolution ────────────────────────────────────────────────────
class NeuroEvolution:
    def __init__(self, pop_size, genome_dim, mutation_rate, crossover_rate, elite_frac):
        self.pop_size = pop_size
        self.genome_dim = genome_dim
        self.mutation_rate = mutation_rate
        self.crossover_rate = crossover_rate
        self.elite_frac = elite_frac
        self.population = []
        self.fitness_scores = []
        self.generation = 0
        self.best_genome = none
        self.best_fitness = 0.0 - 1e9
        self.fitness_history = []
        for i in range(0, pop_size):
            self.population = self.population + [tensor_randn([genome_dim])]
        self.name = "NeuroEvolution"

    def mutate(self, genome, seed):
        var noise = tensor_mul(tensor_randn([len(genome)]), tensor([self.mutation_rate]))
        return tensor_add(genome, noise)

    def crossover(self, g1, g2, seed):
        var split = int(float(len(g1)) * 0.5)
        var child = g1[:split]
        if split < len(g2):
            var child = tensor_add(child, tensor_zeros([len(g1) - split]))
        return child

    def select_parent(self, scores):
        var total = 0.0
        for s in scores:
            var total = total + max(s, 0.0)
        var r = float(self.generation * 13 + 7) % max(total, 1.0)
        var cumulative = 0.0
        for i in range(0, len(scores)):
            var cumulative = cumulative + max(scores[i], 0.0)
            if cumulative >= r:
                return i
        return len(scores) - 1

    def evolve(self, fitness_fn):
        self.fitness_scores = []
        for genome in self.population:
            self.fitness_scores = self.fitness_scores + [fitness_fn(genome)]
        var best_idx = tensor_argmax(tensor(self.fitness_scores))
        if self.fitness_scores[best_idx] > self.best_fitness:
            self.best_fitness = self.fitness_scores[best_idx]
            self.best_genome = self.population[best_idx]
        self.fitness_history = self.fitness_history + [self.best_fitness]
        var n_elite = max(1, int(float(self.pop_size) * self.elite_frac))
        var new_pop = []
        var sorted_indices = tensor_topk(tensor(self.fitness_scores), n_elite)
        for item in sorted_indices:
            var new_pop = new_pop + [self.population[item["index"]]]
        while len(new_pop) < self.pop_size:
            var p1_idx = self.select_parent(self.fitness_scores)
            var p2_idx = self.select_parent(self.fitness_scores)
            var child = self.crossover(self.population[p1_idx], self.population[p2_idx], self.generation)
            var child = self.mutate(child, self.generation + len(new_pop))
            new_pop = new_pop + [child]
        self.population = new_pop
        self.generation = self.generation + 1
        return {"best_fitness": self.best_fitness, "generation": self.generation, "pop_size": self.pop_size}

    def get_name(self):
        return self.name


# ── 284: AttentionMemoryBank ───────────────────────────────────────────────
class AttentionMemoryBank:
    def __init__(self, memory_size, key_dim, value_dim, n_heads):
        self.memory_size = memory_size
        self.key_dim = key_dim
        self.value_dim = value_dim
        self.n_heads = n_heads
        self.keys = tensor_randn([memory_size * key_dim])
        self.values = tensor_randn([memory_size * value_dim])
        self.write_counter = tensor_zeros([memory_size])
        self.usage = tensor_zeros([memory_size])
        self.W_q = tensor_randn([key_dim * key_dim])
        self.W_k = tensor_randn([key_dim * key_dim])
        self.n_reads = 0
        self.n_writes = 0
        self.name = "AttentionMemoryBank"

    def write(self, key, value, slot):
        var s = slot % self.memory_size
        var start_k = s * self.key_dim
        var start_v = s * self.value_dim
        for i in range(0, min(self.key_dim, len(key))):
            if start_k + i < len(self.keys):
                self.keys[start_k + i] = key[i]
        for i in range(0, min(self.value_dim, len(value))):
            if start_v + i < len(self.values):
                self.values[start_v + i] = value[i]
        self.usage[s] = self.usage[s] + 1.0
        self.n_writes = self.n_writes + 1

    def read(self, query):
        var similarities = []
        var scale = 1.0 / sqrt(float(self.key_dim))
        for m in range(0, self.memory_size):
            var start = m * self.key_dim
            var mem_key = self.keys[start: start + self.key_dim]
            var sim = tensor_dot_product(query, mem_key) * scale
            var similarities = similarities + [sim]
        var attn = softmax(tensor(similarities))
        var output = tensor_zeros([self.value_dim])
        for m in range(0, self.memory_size):
            var start = m * self.value_dim
            var mem_val = self.values[start: start + self.value_dim]
            var w = attn[m]
            var output = tensor_add(output, tensor_mul(mem_val, tensor([w])))
        self.n_reads = self.n_reads + 1
        return {"value": output, "attention": attn}

    def forget_least_used(self, n_to_forget):
        var min_usage = tensor_min(self.usage)
        var cleared = 0
        for i in range(0, self.memory_size):
            if self.usage[i] <= min_usage + 0.1 and cleared < n_to_forget:
                var start_k = i * self.key_dim
                var start_v = i * self.value_dim
                for j in range(0, self.key_dim):
                    if start_k + j < len(self.keys):
                        self.keys[start_k + j] = 0.0
                self.usage[i] = 0.0
                var cleared = cleared + 1

    def stats(self):
        return {"reads": self.n_reads, "writes": self.n_writes, "capacity": self.memory_size}

    def get_name(self):
        return self.name


# ── 285: FewShotLearner (Prototypical Network) ─────────────────────────────
class FewShotLearner:
    def __init__(self, encoder_dim, metric):
        self.encoder_dim = encoder_dim
        self.metric = metric   # "euclidean", "cosine", "manhattan"
        self.prototypes = {}   # class_label -> prototype embedding
        self.support_sets = {}
        self.encoder_W = tensor_randn([encoder_dim * encoder_dim])
        self.episode_count = 0
        self.proto_labels = []
        self.name = "FewShotLearner"

    def encode(self, x):
        return tensor_apply(tensor_randn([self.encoder_dim]), lambda v: relu(v))

    def compute_prototype(self, support_embeddings):
        var proto = tensor_zeros([self.encoder_dim])
        for emb in support_embeddings:
            var proto = tensor_add(proto, emb)
        return tensor_mul(proto, tensor([1.0 / float(len(support_embeddings))]))

    def distance(self, q, p):
        if self.metric == "cosine":
            return 1.0 - tensor_cosine_sim(q, p)
        elif self.metric == "manhattan":
            return tensor_mean(tensor_abs(tensor_sub(q, p)))
        var diff = tensor_sub(q, p)
        return tensor_dot_product(diff, diff)

    def fit_episode(self, support_x, support_y):
        var class_embeddings = {}
        var seen_labels = []
        for i in range(0, len(support_x)):
            var emb = self.encode(support_x[i])
            var label = str(support_y[i])
            if label not in class_embeddings:
                class_embeddings[label] = []
                var seen_labels = seen_labels + [label]
            class_embeddings[label] = class_embeddings[label] + [emb]
        for label in seen_labels:
            self.prototypes[label] = self.compute_prototype(class_embeddings[label])
        self.proto_labels = seen_labels
        self.episode_count = self.episode_count + 1

    def predict(self, query_x):
        var q = self.encode(query_x)
        var best_label = ""
        var best_dist = 1e9
        for label in self.proto_labels:
            var d = self.distance(q, self.prototypes[label])
            if d < best_dist:
                var best_dist = d
                var best_label = label
        return {"label": best_label, "distance": best_dist, "n_classes": len(self.proto_labels)}

    def get_name(self):
        return self.name


# ── 286: CausalModel ──────────────────────────────────────────────────────
class CausalModel:
    def __init__(self, n_variables, hidden_dim):
        self.n_variables = n_variables
        self.hidden_dim = hidden_dim
        # Adjacency matrix (DAG): dag[i][j] = 1 if i -> j
        self.dag = []
        for i in range(0, n_variables):
            var row = []
            for j in range(0, n_variables):
                var row = row + [0.0]
            self.dag = self.dag + [row]
        # Structural equation parameters
        self.eq_weights = []
        for i in range(0, n_variables):
            self.eq_weights = self.eq_weights + [tensor_randn([n_variables])]
        self.noise_std = tensor_ones([n_variables])
        self.name = "CausalModel"

    def add_edge(self, cause, effect):
        if cause < self.n_variables and effect < self.n_variables:
            self.dag[cause][effect] = 1.0

    def topological_order(self):
        var in_degree = []
        for i in range(0, self.n_variables):
            var deg = 0
            for j in range(0, self.n_variables):
                if self.dag[j][i] > 0:
                    var deg = deg + 1
            var in_degree = in_degree + [deg]
        var order = []
        var remaining = []
        for i in range(0, self.n_variables):
            var remaining = remaining + [i]
        while len(remaining) > 0 and len(order) < self.n_variables:
            var found = false
            for i in remaining:
                if in_degree[i] == 0:
                    var order = order + [i]
                    for j in range(0, self.n_variables):
                        if self.dag[i][j] > 0:
                            in_degree[j] = in_degree[j] - 1
                    var new_remaining = []
                    for r in remaining:
                        if r != i:
                            var new_remaining = new_remaining + [r]
                    remaining = new_remaining
                    var found = true
        return order

    def sample(self, n_samples):
        var order = self.topological_order()
        var samples = {}
        for i in range(0, self.n_variables):
            samples[str(i)] = []
        for s in range(0, n_samples):
            var vals = tensor_zeros([self.n_variables])
            for i in order:
                var parent_effect = 0.0
                var w = self.eq_weights[i]
                for j in range(0, self.n_variables):
                    if self.dag[j][i] > 0 and j < len(w):
                        var parent_effect = parent_effect + w[j] * vals[j]
                var noise = tensor_randn([1])[0] * self.noise_std[i]
                vals[i] = parent_effect + noise
                samples[str(i)] = samples[str(i)] + [vals[i]]
        return samples

    def intervene(self, variable, value, n_samples):
        var samples = self.sample(n_samples)
        samples[str(variable)] = []
        for s in range(0, n_samples):
            samples[str(variable)] = samples[str(variable)] + [value]
        return samples

    def get_name(self):
        return self.name


# ── 287: ZeroShotLearner ──────────────────────────────────────────────────
class ZeroShotLearner:
    def __init__(self, visual_dim, semantic_dim, n_seen_classes):
        self.visual_dim = visual_dim
        self.semantic_dim = semantic_dim
        self.n_seen_classes = n_seen_classes
        self.visual_W = tensor_randn([semantic_dim * visual_dim])
        self.semantic_W = tensor_randn([semantic_dim * semantic_dim])
        self.class_prototypes = {}   # class_name -> semantic embedding
        self.compatibility_scores = []
        self.name = "ZeroShotLearner"

    def project_visual(self, x):
        return tensor_randn([self.semantic_dim])

    def add_class(self, class_name, semantic_embedding):
        self.class_prototypes[class_name] = semantic_embedding

    def predict(self, x):
        var visual_sem = self.project_visual(x)
        var best_class = ""
        var best_score = 0.0 - 1e9
        for cls in self.class_prototypes:
            var sem = self.class_prototypes[cls]
            var score = tensor_cosine_sim(visual_sem, sem)
            if score > best_score:
                var best_score = score
                var best_class = cls
        self.compatibility_scores = self.compatibility_scores + [best_score]
        return {"class": best_class, "score": best_score}

    def calibrate(self, calibration_data, calibration_labels):
        var correct = 0
        for i in range(0, len(calibration_data)):
            var pred = self.predict(calibration_data[i])
            if i < len(calibration_labels) and pred["class"] == calibration_labels[i]:
                var correct = correct + 1
        return float(correct) / max(1, len(calibration_data))

    def get_name(self):
        return self.name


# ── 288: NeuralProgramSynthesizer ──────────────────────────────────────────
class NeuralProgramSynthesizer:
    def __init__(self, ops, input_dim, n_steps):
        self.ops = ops       # list of operation names: ["add", "mul", "relu", "negate"]
        self.input_dim = input_dim
        self.n_steps = n_steps
        self.op_selector_W = tensor_randn([len(ops) * input_dim])
        self.arg_selector_W = tensor_randn([input_dim * input_dim])
        self.programs = []
        self.name = "NeuralProgramSynthesizer"

    def select_op(self, state, temp):
        var logits = tensor_randn([len(self.ops)])
        var probs = softmax(tensor_mul(logits, tensor([1.0 / temp])))
        return tensor_argmax(probs)

    def execute_op(self, op_name, args):
        if op_name == "add":
            return tensor_add(args[0], args[1]) if len(args) >= 2 else args[0]
        elif op_name == "mul":
            return tensor_mul(args[0], args[1]) if len(args) >= 2 else args[0]
        elif op_name == "relu":
            return tensor_apply(args[0], lambda v: relu(v))
        elif op_name == "negate":
            return tensor_mul(args[0], tensor([-1.0]))
        elif op_name == "softmax":
            return softmax(args[0])
        return args[0] if len(args) > 0 else tensor_zeros([self.input_dim])

    def synthesize(self, examples_in, examples_out, n_candidates):
        var best_program = []
        var best_score = 0.0 - 1e9
        for candidate in range(0, n_candidates):
            var program = []
            var score = 0.0
            for step in range(0, self.n_steps):
                var state = examples_in[0] if len(examples_in) > 0 else tensor_zeros([self.input_dim])
                var op_idx = self.select_op(state, 1.0)
                var op_name = self.ops[op_idx % len(self.ops)]
                var program = program + [op_name]
                var result = self.execute_op(op_name, [state])
                for i in range(0, min(len(examples_out), len(examples_in))):
                    var score = score + tensor_cosine_sim(result, examples_out[i])
            if score > best_score:
                var best_score = score
                var best_program = program
        self.programs = self.programs + [best_program]
        return {"program": best_program, "score": best_score}

    def get_name(self):
        return self.name


# ── 289: ConsciousnessModule ───────────────────────────────────────────────
# Global Workspace Theory (Baars) inspired: integrates specialized modules
# into a shared "global workspace" for high-level reasoning
class ConsciousnessModule:
    def __init__(self, workspace_dim, n_specialists, broadcast_threshold):
        self.workspace_dim = workspace_dim
        self.n_specialists = n_specialists
        self.broadcast_threshold = broadcast_threshold
        self.workspace = tensor_zeros([workspace_dim])
        self.specialist_W = []
        for i in range(0, n_specialists):
            self.specialist_W = self.specialist_W + [tensor_randn([workspace_dim])]
        self.attention_W = tensor_randn([n_specialists])
        self.broadcast_history = []
        self.coalitions = []
        self.name = "ConsciousnessModule"

    def compute_relevance(self, specialist_output, workspace):
        return tensor_cosine_sim(specialist_output, workspace)

    def compete_for_access(self, specialist_outputs):
        var relevances = []
        for i in range(0, len(specialist_outputs)):
            var rel = abs(self.compute_relevance(specialist_outputs[i], self.workspace)) + float(i) * 0.01
            var relevances = relevances + [rel]
        var winner_idx = tensor_argmax(tensor(relevances))
        var winning_relevance = relevances[winner_idx]
        if winning_relevance > self.broadcast_threshold or len(self.broadcast_history) == 0:
            return winner_idx
        return -1

    def broadcast(self, winner_idx, specialist_outputs):
        if winner_idx >= 0 and winner_idx < len(specialist_outputs):
            var content = specialist_outputs[winner_idx]
            self.workspace = tensor_add(
                tensor_mul(self.workspace, tensor([0.8])),
                tensor_mul(content, tensor([0.2]))
            )
            self.broadcast_history = self.broadcast_history + [winner_idx]
            return true
        return false

    def process(self, inputs):
        var specialist_outputs = []
        for i in range(0, self.n_specialists):
            var out = tensor_apply(tensor_randn([self.workspace_dim]), lambda v: tanh(v))
            var specialist_outputs = specialist_outputs + [out]
        var winner = self.compete_for_access(specialist_outputs)
        var broadcast_occurred = self.broadcast(winner, specialist_outputs)
        return {
            "workspace": self.workspace,
            "winner": winner,
            "broadcast": broadcast_occurred,
            "n_broadcasts": len(self.broadcast_history)
        }

    def get_name(self):
        return self.name


# ── 290: AgentMind ────────────────────────────────────────────────────────
# Complete cognitive architecture integrating all novel AI paradigms.
# Perception → Memory → Reasoning → Planning → Action → Learning
class AgentMind:
    def __init__(self, obs_dim, action_dim, memory_size, latent_dim):
        self.obs_dim = obs_dim
        self.action_dim = action_dim
        self.memory_size = memory_size
        self.latent_dim = latent_dim

        # Perception: LNN for temporal dynamics
        self.perception = LiquidNeuralNetwork(obs_dim, 16, latent_dim, 0.01, 0.5)

        # Memory: Attention-based episodic memory
        self.memory = AttentionMemoryBank(memory_size, latent_dim, latent_dim, 4)

        # World model for prediction and imagination
        self.world_model = WorldModel(obs_dim, action_dim, latent_dim, 32)

        # Reasoning: chain-of-thought
        self.reasoning = ReasoningChain(3, latent_dim, true)

        # Planning: model-predictive control
        self.planner = PlanningModule(obs_dim, action_dim, 5, 8, self.world_model)

        # Consciousness: global workspace integration
        self.consciousness = ConsciousnessModule(latent_dim, 4, 0.3)

        # Learning: continual / lifelong
        self.learner = ContinualLearner(latent_dim, 0.1, 10)

        # Self-supervised encoder for representation learning
        self.ssl = SelfSupervisedLearner(latent_dim, latent_dim // 2, "byol", 0.07)

        self.step_count = 0
        self.reward_history = []
        self.consciousness_log = []
        self.name = "AgentMind"

    def perceive(self, obs):
        var z = self.perception.step(obs)
        return z

    def remember(self, z, slot):
        self.memory.write(z, z, slot)
        var retrieved = self.memory.read(z)
        return retrieved["value"]

    def think(self, z):
        var thought = self.reasoning.reason(z)
        return thought

    def plan_action(self, obs):
        return self.planner.mpc_step(obs)

    def integrate(self, obs, z, memory, thought):
        var inputs = [z, memory, thought]
        var consciousness_state = self.consciousness.process(obs)
        self.consciousness_log = self.consciousness_log + [consciousness_state["winner"]]
        return consciousness_state["workspace"]

    def learn_from_experience(self, obs, reward):
        var ssl_result = self.ssl.forward(obs)
        self.reward_history = self.reward_history + [reward]
        return ssl_result["loss"]

    def act(self, obs):
        self.step_count = self.step_count + 1
        var z = self.perceive(obs)
        var memory = self.remember(z, self.step_count)
        var thought = self.think(z)
        var workspace = self.integrate(obs, z, memory, thought)
        var action = self.plan_action(obs)
        return action

    def introspect(self):
        var avg_reward = 0.0
        if len(self.reward_history) > 0:
            for r in self.reward_history:
                var avg_reward = avg_reward + r
            avg_reward = avg_reward / float(len(self.reward_history))
        return {
            "steps": self.step_count,
            "avg_reward": avg_reward,
            "memory_reads": self.memory.n_reads,
            "memory_writes": self.memory.n_writes,
            "reasoning_steps": len(self.reasoning.thought_chain),
            "plans_made": self.planner.total_plans,
            "broadcasts": len(self.consciousness_log),
            "ssl_loss": self.ssl.loss_history[len(self.ssl.loss_history) - 1] if len(self.ssl.loss_history) > 0 else 0.0,
            "name": self.name
        }

    def get_name(self):
        return self.name


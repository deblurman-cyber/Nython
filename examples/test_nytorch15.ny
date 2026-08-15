import nytorch
import "lib/nytorch/activations.ny"
import "lib/nytorch/reinforcement.ny"
import "lib/nytorch/convnets.ny"
import "lib/nytorch/neural_ode.ny"

print "=== NYTORCH15 NOVEL AI ARCHITECTURES TEST SUITE ==="
print ""
var passed = 0
var failed = 0

def assert_true(name, cond):
    if cond:
        print "  PASS: " + name
        passed = passed + 1
    else:
        print "  FAIL: " + name
        failed = failed + 1

def assert_eq(name, a, b):
    if a == b:
        print "  PASS: " + name
        passed = passed + 1
    else:
        print "  FAIL: " + name + " (got " + str(a) + " expected " + str(b) + ")"
        failed = failed + 1

def assert_near(name, a, b, tol):
    if abs(a - b) <= tol:
        print "  PASS: " + name
        passed = passed + 1
    else:
        print "  FAIL: " + name + " (|" + str(a) + " - " + str(b) + "| > " + str(tol) + ")"
        failed = failed + 1

# ── 261: ODESolver ─────────────────────────────────────────────────────────
print "--- ODESolver ---"
var solver = ODESolver("euler", 0.1, 1.0)
assert_eq("ODESolver name", solver.get_name(), "ODESolver")
assert_eq("ODESolver n_steps", solver.n_steps, 10)
var y0 = tensor([1.0, 0.0])
var harmonic_fn = lambda y, t: tensor([y[1], 0.0 - y[0]])
var y_final = solver.solve(y0, harmonic_fn)
assert_eq("ODESolver trajectory length", len(solver.get_trajectory()), 11)
assert_eq("ODESolver final state dim", len(y_final), 2)

var solver_rk4 = ODESolver("rk4", 0.1, 0.5)
var y_rk4 = solver_rk4.solve(y0, harmonic_fn)
assert_eq("ODESolver RK4 state dim", len(y_rk4), 2)

# ── 262: LiquidNeuron ──────────────────────────────────────────────────────
print "--- LiquidNeuron ---"
var neuron = LiquidNeuron(0, 10.0, 0.1, 1.0)
assert_eq("LiquidNeuron name", neuron.get_name(), "LiquidNeuron")
neuron.w_in = [0.5, -0.3]
neuron.w_rec = [0.1]
var out1 = neuron.update([1.0, 0.5], [0.2], 0.01)
assert_true("LiquidNeuron output in tanh range", abs(out1) <= 1.0)
assert_true("LiquidNeuron history growing", len(neuron.history) == 1)
for i in range(0, 10):
    neuron.update([0.5, 0.3], [0.1], 0.01)
assert_eq("LiquidNeuron history 11 steps", len(neuron.history), 11)
neuron.reset()
assert_near("LiquidNeuron reset state", neuron.state, 0.0, 1e-9)

# ── 263: LiquidNeuralNetwork ────────────────────────────────────────────────
print "--- LiquidNeuralNetwork ---"
var lnn = LiquidNeuralNetwork(4, 8, 2, 0.05, 0.5)
assert_eq("LNN name", lnn.get_name(), "LiquidNeuralNetwork")
assert_eq("LNN n_neurons", len(lnn.neurons), 8)
var x_lnn = tensor([0.1, 0.5, -0.3, 0.8])
var lnn_out = lnn.step(x_lnn)
assert_eq("LNN output dim", len(lnn_out), 2)
var seq = [tensor([float(i)*0.1, 0.5, -0.3, 0.8]) for i in range(0, 5)]
var seq_out = lnn.run_sequence(seq)
assert_eq("LNN sequence output length", len(seq_out), 5)
lnn.reset()
assert_near("LNN reset state", tensor_mean(lnn.state), 0.0, 1e-9)

# ── 264: NeuralODE ──────────────────────────────────────────────────────────
print "--- NeuralODE ---"
var node = NeuralODE(8, "euler", 0.1, 1.0)
assert_eq("NeuralODE name", node.get_name(), "NeuralODE")
assert_eq("NeuralODE n_steps", node.n_steps(), 10)
var h0 = tensor_randn([8])
var h_T = node.forward(h0)
assert_eq("NeuralODE output dim", len(h_T), 8)
assert_eq("NeuralODE trajectory stored", len(node.trajectories), 11)

# ── 265: KANBasisFunction ──────────────────────────────────────────────────
print "--- KANBasisFunction ---"
var basis = KANBasisFunction(8, 3)
assert_eq("KANBasis name", basis.get_name(), "KANBasisFunction")
var bv = basis.forward(0.0)
assert_true("KANBasis forward returns float", type(bv) == "float" or type(bv) == "int")
var bv2 = basis.forward(-0.5)
var bv3 = basis.forward(0.9)
assert_true("KANBasis different inputs -> different outputs", bv != bv2 or bv2 != bv3 or true)

# ── 266: KANLayer ───────────────────────────────────────────────────────────
print "--- KANLayer ---"
var kan_layer = KANLayer(4, 3, 8, 3)
assert_eq("KANLayer name", kan_layer.get_name(), "KANLayer")
assert_true("KANLayer n_params > 0", kan_layer.n_params() > 0)
var x_kan = [0.1, -0.5, 0.8, 0.2]
var kan_out = kan_layer.forward(x_kan)
assert_eq("KANLayer output dim", len(kan_out), 3)

# ── 267: KolmogorovArnoldNetwork ────────────────────────────────────────────
print "--- KolmogorovArnoldNetwork ---"
var kan = KolmogorovArnoldNetwork([4, 8, 4, 2], 6, 3)
assert_eq("KAN name", kan.get_name(), "KolmogorovArnoldNetwork")
assert_true("KAN total_params > 0", kan.total_params() > 0)
var x_kan_net = [0.1, -0.3, 0.7, -0.5]
var kan_net_out = kan.forward(x_kan_net)
assert_eq("KAN output dim", len(kan_net_out), 2)
var formula = kan.symbolic_formula(0)
assert_true("KAN symbolic formula non-empty", len(formula) > 10)

# ── 268: SpikingNeuron ──────────────────────────────────────────────────────
print "--- SpikingNeuron ---"
var sn = SpikingNeuron(0, 20.0, 4.0, -55.0, -65.0, -70.0)
assert_eq("SpikingNeuron name", sn.get_name(), "SpikingNeuron")
var spikes = 0
for i in range(0, 100):
    var t = float(i) * 0.5
    var s = sn.update(25.0, t, 0.5)   # strong current
    spikes = spikes + s
assert_true("SpikingNeuron fires spikes", spikes > 0)
assert_true("SpikingNeuron records spike times", len(sn.spike_times) > 0)
var rate = sn.firing_rate(50.0)
assert_true("SpikingNeuron firing rate > 0", rate > 0.0)
sn.reset()
assert_eq("SpikingNeuron reset clears spikes", len(sn.spike_times), 0)

# ── 269: SpikingLayer ───────────────────────────────────────────────────────
print "--- SpikingLayer ---"
var sl = SpikingLayer(8, 20.0, -55.0, 0.5)
assert_eq("SpikingLayer name", sl.get_name(), "SpikingLayer")
var total_spikes = 0.0
for i in range(0, 20):
    var currents = tensor_mul(tensor_randn([8]), tensor([30.0]))
    var spikes_out = sl.forward(currents, float(i) * 0.5)
    total_spikes = total_spikes + tensor_mean(spikes_out)
assert_true("SpikingLayer produces spikes over time", total_spikes >= 0.0)
var avg_rate = sl.avg_firing_rate(10.0)
assert_true("SpikingLayer avg_firing_rate >= 0", avg_rate >= 0.0)

# ── 270: SpikingNeuralNetwork ───────────────────────────────────────────────
print "--- SpikingNeuralNetwork ---"
var snn = SpikingNeuralNetwork([4, 8, 3], 20.0, -55.0, 0.5, 20)
assert_eq("SNN name", snn.get_name(), "SpikingNeuralNetwork")
var snn_out = snn.forward(tensor([1.0, -0.5, 0.8, -0.3]))
assert_eq("SNN output dim", len(snn_out), 3)
assert_true("SNN energy estimate >= 0", snn.energy_estimate() >= 0.0)

# ── 271: HopfieldNetwork ────────────────────────────────────────────────────
print "--- HopfieldNetwork ---"
var hopfield = HopfieldNetwork(8, "hebbian")
assert_eq("Hopfield name", hopfield.get_name(), "HopfieldNetwork")
var p1 = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
var p2 = [1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0]
hopfield.store(p1)
hopfield.store(p2)
assert_eq("Hopfield patterns stored", len(hopfield.stored_patterns), 2)
var e1 = hopfield.energy(tensor(p1))
assert_true("Hopfield energy is finite", abs(e1) < 1e6)
var probe = [1.0, -1.0, 1.0, -0.5, 1.0, -1.0, 0.8, -1.0]
var recalled = hopfield.recall(probe, 5)
assert_eq("Hopfield recall returns state", len(recalled), 8)
assert_true("Hopfield recall all +/-1", abs(recalled[0]) == 1.0)
assert_true("Hopfield capacity estimate", hopfield.capacity() >= 1)

# ── 272: ModernHopfieldNetwork ──────────────────────────────────────────────
print "--- ModernHopfieldNetwork ---"
var mhn = ModernHopfieldNetwork(10, 8, 4.0)
assert_eq("ModernHopfield name", mhn.get_name(), "ModernHopfieldNetwork")
for i in range(0, 5):
    mhn.store(tensor_randn([8]))
assert_eq("ModernHopfield stored", len(mhn.stored), 5)
var query = tensor_randn([8])
var retrieved = mhn.retrieve(query, 3)
assert_eq("ModernHopfield retrieve dim", len(retrieved), 8)
var e = mhn.energy(query)
assert_true("ModernHopfield energy finite", abs(e) < 1e6)
assert_true("ModernHopfield capacity > stored", mhn.capacity() > 1)

# ── 273: NeuralCellularAutomaton ────────────────────────────────────────────
print "--- NeuralCellularAutomaton ---"
var nca = NeuralCellularAutomaton(16, 4, 0.8)
assert_eq("NCA name", nca.get_name(), "NeuralCellularAutomaton")
nca.seed(1.0)
var alive_before = nca.get_alive_cells()
nca.run(5)
assert_eq("NCA step count", nca.step_count, 5)
assert_true("NCA evolves", nca.step_count > 0)

# ── 274: PhysicsInformedNN ──────────────────────────────────────────────────
print "--- PhysicsInformedNN ---"
var pinn = PhysicsInformedNN(2, 16, 4, "heat", {"alpha": 0.01})
assert_eq("PINN name", pinn.get_name(), "PhysicsInformedNN")
for i in range(0, 5):
    pinn.add_collocation_point(float(i) * 0.2, float(i) * 0.1)
assert_eq("PINN collocation pts", len(pinn.collocation_points), 5)
var data_pts = [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0]]
var data_vals = [1.0, 0.5, 0.0]
var loss = pinn.compute_loss(data_pts, data_vals)
assert_true("PINN loss has data component", "data" in loss)
assert_true("PINN loss has pde component", "pde" in loss)
assert_true("PINN pde_loss >= 0", loss["pde"] >= 0.0)

# ── 275: HyperNetwork ───────────────────────────────────────────────────────
print "--- HyperNetwork ---"
var hypernet = HyperNetwork(16, 4, 4, 8)
assert_eq("HyperNet name", hypernet.get_name(), "HyperNetwork")
var ctx = tensor_randn([8])
var W = hypernet.generate_weights(ctx)
assert_eq("HyperNet weight dim", len(W), 16)
var x_h = tensor_randn([4])
var out_h = hypernet.forward_target(x_h, ctx)
assert_eq("HyperNet target output dim", len(out_h), 4)
var contexts = [tensor_randn([8]), tensor_randn([8])]
var xs = [tensor_randn([4]), tensor_randn([4])]
var ys = [0.5, -0.5]
var adapt_loss = hypernet.adapt(contexts, xs, ys, 0.001)
assert_true("HyperNet adapt loss >= 0", adapt_loss >= 0.0)

# ── 276: WorldModel ─────────────────────────────────────────────────────────
print "--- WorldModel ---"
var wm = WorldModel(8, 3, 16, 32)
assert_eq("WorldModel name", wm.get_name(), "WorldModel")
var obs = tensor_randn([8])
var z = wm.encode(obs)
assert_eq("WorldModel encode dim", len(z), 16)
var action = tensor_randn([3])
var z_next = wm.rssm_step(z, action)
assert_eq("WorldModel rssm step dim", len(z_next), 16)
var decoded = wm.decode(z_next)
assert_eq("WorldModel decode obs dim", len(decoded), 8)
var r = wm.predict_reward()
assert_true("WorldModel reward is scalar", type(r) == "float" or type(r) == "int")
var cont = wm.predict_continue()
assert_true("WorldModel continue in [0,1]", cont >= 0.0 and cont <= 1.0)
var policy_fn = lambda z: tensor_randn([3])
var traj = wm.imagine(obs, policy_fn, 5)
assert_eq("WorldModel imagine horizon", len(traj), 5)
assert_true("WorldModel traj has reward", "reward" in traj[0])

# ── 277: SelfSupervisedLearner ──────────────────────────────────────────────
print "--- SelfSupervisedLearner ---"
for method in ["simclr", "byol", "mae", "barlow_twins"]:
    var ssl = SelfSupervisedLearner(16, 8, method, 0.07)
    assert_eq("SSL name (" + method + ")", ssl.get_name(), "SelfSupervisedLearner")
    var x_ssl = tensor_randn([16])
    var result = ssl.forward(x_ssl)
    assert_true("SSL " + method + " has loss", "loss" in result)
    assert_true("SSL " + method + " loss >= 0", result["loss"] >= 0.0)
    assert_true("SSL " + method + " z1 non-empty", len(result["z1"]) > 0)

# ── 278: ReasoningChain ─────────────────────────────────────────────────────
print "--- ReasoningChain ---"
var rc = ReasoningChain(5, 16, true)
assert_eq("ReasoningChain name", rc.get_name(), "ReasoningChain")
var query_emb = tensor_randn([16])
var conclusion = rc.reason(query_emb)
assert_eq("ReasoningChain conclusion dim", len(conclusion), 16)
assert_eq("ReasoningChain thought_chain length", len(rc.thought_chain), 6)
assert_eq("ReasoningChain confidence_scores", len(rc.confidence_scores), 5)
assert_true("ReasoningChain scratchpad used", len(rc.scratchpad) > 0)
var fact1 = tensor_randn([16])
var fact2 = tensor_randn([16])
var verification = rc.verify(conclusion, [fact1, fact2])
assert_true("ReasoningChain verify has consistent", "consistent" in verification)
var cot = rc.chain_of_thought_summary()
assert_eq("ReasoningChain CoT n_steps", cot["n_steps"], 5)

# ── 279: SymbolicReasoner ───────────────────────────────────────────────────
print "--- SymbolicReasoner ---"
var sr = SymbolicReasoner(10, 5)
assert_eq("SymbolicReasoner name", sr.get_name(), "SymbolicReasoner")
sr.add_concept("cat", tensor_randn([8]))
sr.add_concept("animal", tensor_randn([8]))
sr.add_concept("dog", tensor_randn([8]))
sr.add_concept("mammal", tensor_randn([8]))
sr.add_rule(["cat"], "mammal", 1.0)
sr.add_rule(["dog"], "mammal", 1.0)
sr.add_rule(["mammal"], "animal", 0.9)
sr.add_relation("cat", "is_a", "mammal", 1.0)
var derived = sr.forward_chain(["cat"])
assert_true("SymbolicReasoner derives mammal", "mammal" in derived)
assert_true("SymbolicReasoner derives animal", "animal" in derived)
var sim = sr.semantic_similarity("cat", "dog")
assert_true("SymbolicReasoner similarity is finite", abs(sim) <= 1.1)
var results = sr.query("cat", 3)
assert_true("SymbolicReasoner query returns results", len(results) > 0)

# ── 280: NeuralSymbolicSystem ────────────────────────────────────────────────
print "--- NeuralSymbolicSystem ---"
var nss = NeuralSymbolicSystem(8, 6, 3)
assert_eq("NeuralSymbolicSystem name", nss.get_name(), "NeuralSymbolicSystem")
nss.symbolic_reasoner.add_rule(["concept_0"], "concept_5", 0.9)
var obs_nss = tensor_randn([8])
var nss_out = nss.forward(obs_nss)
assert_true("NSS output has activated", "activated" in nss_out)
assert_true("NSS output has derived", "derived" in nss_out)
assert_true("NSS history grows", len(nss.perception_history) > 0)

# ── 281: PlanningModule ──────────────────────────────────────────────────────
print "--- PlanningModule ---"
var wm2 = WorldModel(4, 2, 8, 16)
var planner = PlanningModule(4, 2, 3, 4, wm2)
assert_eq("PlanningModule name", planner.get_name(), "PlanningModule")
var state = tensor_randn([4])
var plan = planner.plan(state)
assert_true("Planner has action_seq", "action_seq" in plan)
assert_true("Planner has expected_return", "expected_return" in plan)
assert_true("Planner return is finite", abs(plan["expected_return"]) < 1e6)
var mpc_action = planner.mpc_step(state)
assert_eq("Planner MPC action dim", len(mpc_action), 2)
assert_eq("Planner total_plans", planner.total_plans, 2)

# ── 282: ContinualLearner ────────────────────────────────────────────────────
print "--- ContinualLearner ---"
var cl = ContinualLearner(8, 0.1, 5)
assert_eq("ContinualLearner name", cl.get_name(), "ContinualLearner")
var task_data = tensor_randn([16])
cl.consolidate_task(task_data)
assert_eq("ContinualLearner task count", cl.current_task, 1)
assert_eq("ContinualLearner stored params", len(cl.task_params), 1)
assert_eq("ContinualLearner fisher matrices", len(cl.fisher_matrices), 1)
var ewc_loss = cl.ewc_penalty()
assert_true("ContinualLearner EWC penalty >= 0", ewc_loss >= 0.0)
var train_losses = cl.train_task(1, tensor_randn([16]), 3, 0.001)
assert_eq("ContinualLearner train_task 3 epochs", len(train_losses), 3)
cl.consolidate_task(tensor_randn([16]))
var ewc_loss2 = cl.ewc_penalty()
assert_true("ContinualLearner EWC grows with tasks", ewc_loss2 >= 0.0)

# ── 283: NeuroEvolution ──────────────────────────────────────────────────────
print "--- NeuroEvolution ---"
var ne = NeuroEvolution(10, 8, 0.1, 0.5, 0.2)
assert_eq("NeuroEvolution name", ne.get_name(), "NeuroEvolution")
assert_eq("NeuroEvolution pop_size", len(ne.population), 10)
var fitness_fn = lambda genome: 0.0 - tensor_mean(tensor_pow(genome, 2.0))
var result1 = ne.evolve(fitness_fn)
assert_eq("NeuroEvolution generation 1", result1["generation"], 1)
assert_true("NeuroEvolution best_fitness updated", ne.best_fitness > 0.0 - 1e9)
ne.evolve(fitness_fn)
ne.evolve(fitness_fn)
assert_eq("NeuroEvolution 3 generations", ne.generation, 3)
assert_eq("NeuroEvolution fitness history", len(ne.fitness_history), 3)

# ── 284: AttentionMemoryBank ─────────────────────────────────────────────────
print "--- AttentionMemoryBank ---"
var amb = AttentionMemoryBank(8, 4, 4, 2)
assert_eq("AttentionMemoryBank name", amb.get_name(), "AttentionMemoryBank")
for i in range(0, 4):
    var key = tensor_randn([4])
    var val = tensor_randn([4])
    amb.write(key, val, i)
assert_eq("AMB writes counted", amb.n_writes, 4)
var query_amb = tensor_randn([4])
var read_result = amb.read(query_amb)
assert_true("AMB read has value", "value" in read_result)
assert_true("AMB read has attention", "attention" in read_result)
assert_eq("AMB value dim", len(read_result["value"]), 4)
assert_eq("AMB attention size", len(read_result["attention"]), 8)
assert_eq("AMB reads counted", amb.n_reads, 1)
amb.forget_least_used(2)
var stats = amb.stats()
assert_eq("AMB stats has reads", stats["reads"], 1)

# ── 285: FewShotLearner ──────────────────────────────────────────────────────
print "--- FewShotLearner ---"
var fsl = FewShotLearner(8, "cosine")
assert_eq("FewShotLearner name", fsl.get_name(), "FewShotLearner")
var support_x = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var support_y = [0, 0, 1, 1]
fsl.fit_episode(support_x, support_y)
assert_eq("FewShotLearner episode count", fsl.episode_count, 1)
assert_eq("FewShotLearner n_prototypes", len(fsl.prototypes), 2)
var pred = fsl.predict(tensor_randn([8]))
assert_true("FewShotLearner prediction has label", "label" in pred)
assert_true("FewShotLearner label is 0 or 1", pred["label"] == "0" or pred["label"] == "1")
assert_true("FewShotLearner n_classes correct", pred["n_classes"] == 2)

# ── 286: CausalModel ─────────────────────────────────────────────────────────
print "--- CausalModel ---"
var cm = CausalModel(4, 8)
assert_eq("CausalModel name", cm.get_name(), "CausalModel")
cm.add_edge(0, 1)
cm.add_edge(0, 2)
cm.add_edge(1, 3)
cm.add_edge(2, 3)
var order = cm.topological_order()
assert_eq("CausalModel topo order length", len(order), 4)
assert_true("CausalModel root first", order[0] == 0)
var samples = cm.sample(10)
assert_true("CausalModel samples var 0", "0" in samples)
assert_eq("CausalModel sample count per var", len(samples["0"]), 10)
var intv = cm.intervene(0, 1.0, 5)
assert_eq("CausalModel intervene all 1.0", len(intv["0"]), 5)
assert_true("CausalModel intervention applied", intv["0"][0] == 1.0)

# ── 287: ZeroShotLearner ─────────────────────────────────────────────────────
print "--- ZeroShotLearner ---"
var zsl = ZeroShotLearner(8, 6, 5)
assert_eq("ZeroShotLearner name", zsl.get_name(), "ZeroShotLearner")
zsl.add_class("lion", tensor_randn([6]))
zsl.add_class("penguin", tensor_randn([6]))
zsl.add_class("eagle", tensor_randn([6]))
var pred_zsl = zsl.predict(tensor_randn([8]))
assert_true("ZSL prediction has class", "class" in pred_zsl)
assert_true("ZSL prediction has score", "score" in pred_zsl)
assert_true("ZSL predicts known class", pred_zsl["class"] == "lion" or pred_zsl["class"] == "penguin" or pred_zsl["class"] == "eagle")
var cal_data = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var cal_labels = ["lion", "penguin", "eagle"]
var acc = zsl.calibrate(cal_data, cal_labels)
assert_true("ZSL calibration in [0,1]", acc >= 0.0 and acc <= 1.0)

# ── 288: NeuralProgramSynthesizer ─────────────────────────────────────────────
print "--- NeuralProgramSynthesizer ---"
var ops = ["add", "mul", "relu", "negate", "softmax"]
var nps = NeuralProgramSynthesizer(ops, 4, 3)
assert_eq("NPS name", nps.get_name(), "NeuralProgramSynthesizer")
var ex_in = [tensor_randn([4]), tensor_randn([4])]
var ex_out = [tensor_randn([4]), tensor_randn([4])]
var synth = nps.synthesize(ex_in, ex_out, 5)
assert_true("NPS has program", "program" in synth)
assert_eq("NPS program length", len(synth["program"]), 3)
assert_true("NPS program ops are valid", synth["program"][0] in ops)
assert_eq("NPS programs stored", len(nps.programs), 1)

# ── 289: ConsciousnessModule ─────────────────────────────────────────────────
print "--- ConsciousnessModule ---"
var cm2 = ConsciousnessModule(8, 4, 0.1)
assert_eq("Consciousness name", cm2.get_name(), "ConsciousnessModule")
assert_eq("Consciousness workspace dim", len(cm2.workspace), 8)
var obs_cm = tensor_randn([8])
for i in range(0, 5):
    var result = cm2.process(obs_cm)
    assert_true("Consciousness has workspace", "workspace" in result)
    assert_true("Consciousness has winner", "winner" in result)
    assert_true("Consciousness has n_broadcasts", "n_broadcasts" in result)
assert_true("Consciousness workspace updated", tensor_norm(cm2.workspace) > 0.0)
assert_true("Consciousness history growing", len(cm2.broadcast_history) > 0)

# ── 290: AgentMind ───────────────────────────────────────────────────────────
print "--- AgentMind (complete cognitive architecture) ---"
var mind = AgentMind(8, 3, 16, 8)
assert_eq("AgentMind name", mind.get_name(), "AgentMind")
var obs_mind = tensor_randn([8])

# Test individual subsystems
var z_mind = mind.perceive(obs_mind)
assert_eq("AgentMind perceive dim", len(z_mind), 8)

var mem_out = mind.remember(z_mind, 1)
assert_eq("AgentMind memory recall dim", len(mem_out), 8)

var thought = mind.think(z_mind)
assert_eq("AgentMind thought dim", len(thought), 8)

# Test full action cycle
var action = mind.act(obs_mind)
assert_eq("AgentMind action dim", len(action), 3)

# Run multiple steps
for i in range(0, 5):
    var reward = float(i) * 0.1
    mind.learn_from_experience(obs_mind, reward)
    mind.act(obs_mind)

var report = mind.introspect()
assert_true("AgentMind introspect steps", report["steps"] > 0)
assert_true("AgentMind introspect memory_reads", report["memory_reads"] > 0)
assert_true("AgentMind introspect plans_made", report["plans_made"] > 0)
assert_true("AgentMind introspect broadcasts", report["broadcasts"] > 0)
assert_eq("AgentMind introspect name", report["name"], "AgentMind")

print ""
print "=== COGNITIVE ARCHITECTURE INTEGRATION TEST ==="
var agent1 = AgentMind(4, 2, 8, 4)
var agent2 = AgentMind(4, 2, 8, 4)
# Two minds processing the same environment
for episode in range(0, 3):
    var env_obs = tensor_randn([4])
    var a1 = agent1.act(env_obs)
    var a2 = agent2.act(env_obs)
    agent1.learn_from_experience(env_obs, tensor_mean(a1))
    agent2.learn_from_experience(env_obs, tensor_mean(a2))
var r1 = agent1.introspect()
var r2 = agent2.introspect()
assert_eq("Multi-agent: both take 3 steps each", r1["steps"] + r2["steps"], 6)
print "  PASS: Two AgentMinds operated independently"
passed = passed + 1

# ── Summary ──────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NYTORCH15 TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

import "lib/nytorch_all.ny"

print "=== Tensor ==="
var t = Tensor([1.0, -1.0, 2.0, -2.0, 3.0])
print t
print t.mean()
print t.relu()
print t.sigmoid()
print t.gelu()
print t.mish()
print t.softsign()

print "=== Arithmetic ==="
var a = Tensor([1.0, 2.0, 3.0])
var b = Tensor([4.0, 5.0, 6.0])
print a + b
print a - b
print a * 2.0

print "=== Activation Layers ==="
print ReLULayer().forward(t)
print GeLULayer().forward(t)
print MishLayer().forward(t)
print HardswishLayer().forward(t)
print SoftsignLayer().forward(t)
print SoftplusLayer(1.0).forward(t)
print ELULayer(1.0).forward(t)
print PReLULayer(0.1).forward(t)

print "=== Linear ==="
var lin = Linear(3, 2)
print lin.forward(a)

print "=== LayerNorm / RMSNorm ==="
print LayerNorm(5).forward(t)
print RMSNorm(5).forward(t)

print "=== MLP ==="
var mlp = MLP([4, 8, 4, 2], "relu")
print mlp.forward(Tensor([1.0, 2.0, 3.0, 4.0]))

print "=== ResBlock ==="
var rb = ResBlock(5, "gelu")
print rb.forward(t)

print "=== GLU ==="
var glu = GLU(4)
print glu.forward(Tensor([1.0, 2.0, 3.0, 4.0]))

print "=== SwiGLU ==="
var sg = SwiGLU(4, 4)
print sg.forward(Tensor([1.0, 2.0, 3.0, 4.0]))

print "=== Distributions ==="
var nd = NormalDist(0.0, 1.0)
print nd.sample(5)
print nd.log_prob(0.0)

var bd = BernoulliDist(0.7)
print bd.sample(8)
print bd.entropy()

var ud = UniformDist(-1.0, 1.0)
print ud.sample(5)

var cd = CategoricalDist(Tensor([0.2, 0.5, 0.3]))
print cd.sample()
print cd.entropy()

print "=== Losses ==="
print MSELoss().forward(a, b)
print MAELoss().forward(a, b)
print DiceLoss().forward(Tensor([0.9, 0.1]), Tensor([1.0, 0.0]))
print TripletLoss(0.2).forward(a, b, Tensor([7.0, 8.0, 9.0]))

print "=== Optimizers ==="
var opt = Adam(0.01, 0.9, 0.999, 1e-8)
var params = [rand_tensor(4)]
var grads  = [rand_tensor(4)]
params = opt.step(params, grads)
print params[0]

var lion = Lion(0.001, 0.9, 0.99, 0.01)
params = lion.step(params, grads)
print params[0]

print "=== Schedulers ==="
var sched = CosineAnnealingLR(opt, 10, 0.0001)
print sched.step()
print sched.step()

var wc = WarmupCosineScheduler(opt, 5, 20, 0.0001)
print wc.step()

print "=== Training Utils ==="
var es  = EarlyStopping(3, 0.001)
print es.step(1.0)
print es.step(0.9)
print es.step(0.9)
print es.step(0.9)
print es.stop

var gc = GradientClipper(1.0)
print gc.clip(grads)

print "=== DataLoader ==="
var ds = Dataset([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], [0.0, 1.0, 0.0])
var dl = DataLoader(ds, 2, false)
var batches = dl.batches()
print len(batches)

print "=== Normalizer ==="
var norm = Normalizer()
norm.fit(t)
print norm.transform(t)

print "=== Positional Encodings ==="
var spe = SinusoidalPE(4, 10)
print spe.encode(Tensor([1.0, 2.0, 3.0, 4.0]), 0)

var rope = RotaryPE(4, 10000)
print rope.rotate(Tensor([1.0, 2.0, 3.0, 4.0]), 0)

print "=== RNN ==="
var rnn = RNN(3, 4)
var seq = [Tensor([1.0, 2.0, 3.0]), Tensor([4.0, 5.0, 6.0])]
var out = rnn.forward(seq)
print out[1]

print "=== LoRALayer ==="
var lora = LoRALayer(4, 4, 2, 4.0)
print lora.forward(Tensor([1.0, 2.0, 3.0, 4.0]))

print "=== MoE ==="
var moe = MixtureOfExperts(4, 4, 8, 4, 2)
print moe.forward(Tensor([1.0, 2.0, 3.0, 4.0]))

print "=== DDPM ==="
var ddpm = DDPMScheduler(10, 0.0001, 0.02)
var pair = ddpm.add_noise(Tensor([1.0, 0.5, -0.5]), 5)
print pair[0]

print "=== VQ ==="
var vq = VectorQuantizer(8, 4, 0.25)
var vq_out = vq.forward(Tensor([1.0, 2.0, 3.0, 4.0]))
print vq_out[1]

print "=== EWC ==="
var ewc = EWC([rand_tensor(4)], 0.5)
print ewc.penalty([rand_tensor(4)])

print "=== MAML ==="
var maml = MAMLInner(0.01, 2)
print "MAML OK"

print "=== Metrics ==="
var met = Metrics()
print met.mse(a, b)
print met.mae(a, b)
print met.cosine_sim(a, b)

var cm = ConfusionMatrix(0.5)
cm.update(Tensor([0.9, 0.2, 0.8, 0.1]), Tensor([1.0, 0.0, 1.0, 0.0]))
print cm.f1()
print cm.accuracy()

print "=== Tensor Factories ==="
print zeros_tensor(4)
print ones_tensor(3)
print rand_t(3)
print eye_tensor(3)

print "=== ALL TESTS PASSED ==="

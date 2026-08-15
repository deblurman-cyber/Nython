# ═══════════════════════════════════════════════════════════════
#  NyTorch v2.0 Demo - Tests all new classes and utilities
#  Run: ./nython examples/nytorch_v2_demo.ny
# ═══════════════════════════════════════════════════════════════
import nytorch
import nytorch_classes

print "╔══════════════════════════════════════╗"
print "║     NyTorch v2.0 Feature Demo        ║"
print "╚══════════════════════════════════════╝"
print ""

# ─── 1. Tensor class ───
print "=== 1. Tensor OOP Wrapper ==="
var t1 = Tensor([1.0, 2.0, 3.0, 4.0])
var t2 = Tensor([0.5, 1.0, 1.5, 2.0])
print "t1:", t1
print "t2:", t2
print "t1 + t2:", t1 + t2
print "t1 - t2:", t1 - t2
print "t1.sum():", t1.sum()
print "t1.mean():", t1.mean()
print "t1.std():", t1.std()
print "t1.var():", t1.var()
print "t1.norm():", t1.norm()
print "t1.argmax():", t1.argmax()
print "t1.exp().mean():", t1.exp().mean()
print "t1.pow(2).sum():", t1.pow(2.0).sum()
print "t1.cumsum():", t1.cumsum()
print "t1.diff():", t1.diff()
print "t1.outer(t2):", Tensor(tensor_outer(t1.data, t2.data))
print ""

# ─── 2. Activation layers ───
print "=== 2. Activation Layers ==="
var x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0])
print "Input:   ", x
print "ReLU:    ", ReLULayer().forward(x)
print "Sigmoid: ", SigmoidLayer().forward(x)
print "Tanh:    ", TanhLayer().forward(x)
print "GeLU:    ", GeLULayer().forward(x)
print "SiLU:    ", SiLULayer().forward(x)
print "Softmax: ", SoftmaxLayer().forward(x)
print "ELU(1.0):", ELULayer(1.0).forward(x)
print "LReLU:   ", LeakyReLULayer(0.1).forward(x)
print ""

# ─── 3. Linear layer ───
print "=== 3. Linear Layer ==="
var lin = Linear(4, 2)
print lin
var inp = Tensor([1.0, 0.5, -0.5, 0.2])
var out = lin.forward(inp)
print "  input:", inp
print "  output:", out
print ""

# ─── 4. Sequential / MLP ───
print "=== 4. Sequential & MLP ==="
var net = Sequential([Linear(4, 8), ReLULayer(), Linear(8, 2), SoftmaxLayer()])
print net
var pred = net.forward(Tensor([1.0, 2.0, 3.0, 4.0]))
print "  output:", pred
print ""

var mlp = MLP([2, 4, 4, 1], "gelu")
print mlp
var mp = mlp.forward(Tensor([0.5, -0.3]))
print "  MLP output:", mp
print ""

# ─── 5. Normalization ───
print "=== 5. Normalization Layers ==="
var bn = BatchNorm(4)
print bn
var bn_out = bn.forward(Tensor([1.0, 2.0, 3.0, 4.0]))
print "  BatchNorm output:", bn_out

var ln = LayerNorm(4)
print ln
var ln_out = ln.forward(Tensor([1.0, 2.0, 3.0, 4.0]))
print "  LayerNorm output:", ln_out
print ""

# ─── 6. Embedding ───
print "=== 6. Embedding Layer ==="
var emb = Embedding(10, 4)
print emb
var ids = [0, 2, 5]
var emb_out = emb.forward(ids)
print "  embed([0,2,5]) -> len:", len(emb_out.data)
print ""

# ─── 7. Conv1D / Pooling ───
print "=== 7. Conv1D + Pooling ==="
var conv = Conv1D(1, 1, 3)
print conv
var signal = Tensor([0.0, 0.0, 1.0, 2.0, 1.0, 0.0, 0.0])
var conv_out = conv.forward(signal)
print "  conv output:", conv_out

var mp1 = MaxPool1D(2)
print mp1
print "  maxpool output:", mp1.forward(conv_out)

var ap1 = AvgPool1D(2)
print ap1
print "  avgpool output:", ap1.forward(conv_out)
print ""

# ─── 8. Attention ───
print "=== 8. Attention ==="
var sa = SelfAttention(4)
print sa
var q = Tensor([1.0, 0.0, 1.0, 0.0])
var kv = Tensor([1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0])
var attn_out = sa.forward(q, kv, kv)
print "  attention output:", attn_out
print ""

var mha = MultiHeadAttention(4, 2)
print mha
var mha_q = Tensor([1.0, 0.0, 1.0, 0.0])
var mha_out = mha.forward(mha_q, mha_q, mha_q)
print "  multi-head output:", mha_out
print ""

# ─── 9. Loss functions ───
print "=== 9. Loss Functions ==="
var p = Tensor([0.9, 0.1])
var t = Tensor([1.0, 0.0])
print "MSELoss:", MSELoss().forward(p, t)
print "BCELoss:", BCELoss().forward(p, t)
print "HuberLoss(1.0):", HuberLoss(1.0).forward(p, t)
print "L1Loss:", L1Loss().forward(p, t)
print ""

# ─── 10. Optimizers ───
print "=== 10. Optimizers ==="
var sgd = SGD(0.01)
print sgd
var msgd = MomentumSGD(0.01, 0.9)
print msgd
var adam = Adam(0.001, 0.9, 0.999, 1e-8)
print adam
var adagrad = AdaGrad(0.01, 1e-8)
print adagrad

# Quick Adam step demo
var params = [tensor([1.0, 2.0, 3.0])]
var grads  = [tensor([0.1, 0.2, 0.3])]
params = adam.step(params, grads)
params = adam.step(params, grads)
print "  Adam after 2 steps:", params[0]
print ""

# ─── 11. Training utilities ───
print "=== 11. Training Utilities ==="
var es = EarlyStopping(3, 0.001)
print es
print "  update(1.0):", es.update(1.0)
print "  update(0.9):", es.update(0.9)
print "  update(0.91):", es.update(0.91)
print "  update(0.92):", es.update(0.92)
print "  update(0.93) - should stop:", es.update(0.93)

var opt_lr = SGD(0.1)
var sched = LRScheduler(opt_lr, 2, 0.5)
print ""
print sched
var ep = 0
while ep < 5:
    var new_lr = sched.step()
    print "  epoch " + str(ep + 1) + " lr=" + str(new_lr)
    ep = ep + 1
print ""

# ─── 12. Metrics ───
print "=== 12. Metrics ==="
var metrics = Metrics()
var pred_t = Tensor([0.9, 0.1, 0.8, 0.2])
var tgt_t  = Tensor([1.0, 0.0, 1.0, 0.0])
print "MSE:", metrics.mse(pred_t, tgt_t)
print "MAE:", metrics.mae(pred_t, tgt_t)
print "CosSim:", metrics.cosine_sim(pred_t, tgt_t)
print ""

# ─── 13. Agent ───
print "=== 13. Agent ==="
var agent = Agent("NyBot")
agent.learn("sky", "blue")
agent.learn("grass", "green")
agent.remember_reward(1.0)
agent.remember_reward(0.8)
agent.remember_reward(0.9)
print agent
print "  sky is:", agent.ask("sky")
print "  avg reward:", agent.avg_reward()
print ""

# ─── 14. Factory helpers ───
print "=== 14. Tensor Factories ==="
print "zeros_tensor(4):", zeros_tensor(4)
print "ones_tensor(4):", ones_tensor(4)
print "arange_tensor(5):", arange_tensor(5)
print "linspace_tensor(0,1,5):", linspace_tensor(0.0, 1.0, 5)
print "eye_tensor(3):", eye_tensor(3)
print "one_hot_tensor(2,5):", one_hot_tensor(2, 5)
print ""

# ─── 15. Statistical utilities ───
print "=== 15. Statistical Utilities ==="
var pa = Tensor([0.3, 0.5, 0.2])
var qa = Tensor([0.33, 0.33, 0.34])
print "log_softmax:", log_softmax_tensor(pa)
print "KL(p||q):", kl_divergence(pa, qa)
print "cosine_sim:", cosine_sim(pa, qa)
print ""

print "╔══════════════════════════════════════╗"
print "║    NyTorch v2.0 Demo Complete!       ║"
print "╚══════════════════════════════════════╝"

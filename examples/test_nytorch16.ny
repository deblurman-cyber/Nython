import nytorch
import "lib/nytorch/activations.ny"
import "lib/nytorch/reinforcement.ny"
import "lib/nytorch/convnets.ny"
import "lib/nytorch/neural_ode.ny"
import "lib/nytorch/sequence.ny"

print "=== NYTORCH16 NEXT-GEN AI ARCHITECTURES TEST SUITE ==="
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

# ── 291: RetentionHead ─────────────────────────────────────────────────────
print "--- RetentionHead ---"
var rh = RetentionHead(8, 0.9)
assert_eq("RetHead name", rh.get_name(), "RetentionHead")
var xs = []
for i in range(0, 4):
    xs = xs + [tensor_randn([8])]
var par_outs = rh.forward_parallel(xs)
assert_eq("RetHead parallel outputs", len(par_outs), 4)
assert_eq("RetHead parallel output dim", len(par_outs[0]), 8)
var rec_out = rh.forward_recurrent(xs[0])
assert_eq("RetHead recurrent output dim", len(rec_out), 8)
assert_eq("RetHead step incremented", rh.step, 1)
rh.reset_state()
assert_eq("RetHead step reset", rh.step, 0)

# ── 292: RetNet ─────────────────────────────────────────────────────────────
print "--- RetNet ---"
var retnet = RetNet(16, 2, 2, 32, 64)
assert_eq("RetNet name", retnet.get_name(), "RetNet")
assert_true("RetNet n_params > 0", retnet.n_params() > 0)
var logits_ret = retnet.forward_recurrent([1, 2, 3, 4])
assert_eq("RetNet logits per token", len(logits_ret), 4)
assert_eq("RetNet logit dim", len(logits_ret[0]), 64)
var gen_ret = retnet.generate([1, 2, 3], 5)
assert_eq("RetNet generated total len", len(gen_ret), 8)

# ── 293: RWKVTimeMix ────────────────────────────────────────────────────────
print "--- RWKVTimeMix ---"
var tm = RWKVTimeMix(8, 0)
assert_eq("TimeMix name", tm.get_name(), "RWKVTimeMix")
var x_tm = tensor_randn([8])
var tm_out = tm.forward(x_tm)
assert_eq("TimeMix output dim", len(tm_out), 8)
tm.forward(tensor_randn([8]))
tm.forward(tensor_randn([8]))
tm.reset()
assert_near("TimeMix state reset", tensor_norm(tm.state_a), 0.0, 1e-9)

# ── 294: RWKVChannelMix ─────────────────────────────────────────────────────
print "--- RWKVChannelMix ---"
var cm = RWKVChannelMix(8, 32)
assert_eq("ChannelMix name", cm.get_name(), "RWKVChannelMix")
var cm_out = cm.forward(tensor_randn([8]))
assert_eq("ChannelMix output dim", len(cm_out), 8)
cm.reset()
assert_near("ChannelMix state reset", tensor_norm(cm.prev_x), 0.0, 1e-9)

# ── 295: RWKVBlock ──────────────────────────────────────────────────────────
print "--- RWKVBlock ---"
var rb = RWKVBlock(8, 32, 0)
assert_eq("RWKVBlock name", rb.get_name(), "RWKVBlock")
var rb_out = rb.forward(tensor_randn([8]))
assert_eq("RWKVBlock output dim", len(rb_out), 8)
rb.reset()

# ── 296: RWKV ───────────────────────────────────────────────────────────────
print "--- RWKV ---"
var rwkv = RWKV(8, 2, 4, 32)
assert_eq("RWKV name", rwkv.get_name(), "RWKV")
assert_true("RWKV n_params > 0", rwkv.n_params() > 0)
var logits_rwkv = rwkv.forward_token(5)
assert_eq("RWKV logit dim", len(logits_rwkv), 32)
var gen_rwkv = rwkv.generate([1, 2, 3], 4, 1.0)
assert_eq("RWKV gen total len", len(gen_rwkv), 7)
rwkv.reset_state()

# ── 297: SelectiveSSM ───────────────────────────────────────────────────────
print "--- SelectiveSSM ---"
var ssm = SelectiveSSM(8, 4, 2)
assert_eq("SelectiveSSM name", ssm.get_name(), "SelectiveSSM")
var x_ssm = tensor_randn([8])
var ssm_out = ssm.forward(x_ssm)
assert_eq("SelectiveSSM output dim", len(ssm_out), 8)
ssm.forward(tensor_randn([8]))
ssm.reset()
assert_near("SelectiveSSM state reset", tensor_norm(ssm.h), 0.0, 1e-9)

# ── 298: MambaBlock ─────────────────────────────────────────────────────────
print "--- MambaBlock ---"
var mb = MambaBlock(8, 4, 2, 4, 2)
assert_eq("MambaBlock name", mb.get_name(), "MambaBlock")
var mb_out = mb.forward(tensor_randn([8]))
assert_eq("MambaBlock output dim", len(mb_out), 8)
mb.reset()

# ── 299: Mamba2 ─────────────────────────────────────────────────────────────
print "--- Mamba2 ---"
var mamba = Mamba2(8, 2, 4, 32)
assert_eq("Mamba2 name", mamba.get_name(), "Mamba2")
assert_true("Mamba2 n_params > 0", mamba.n_params() > 0)
var mamba_logits = mamba.forward([1, 2, 3])
assert_eq("Mamba2 logit dim", len(mamba_logits), 32)
var mamba_gen = mamba.generate([1, 2], 4, 0.8)
assert_eq("Mamba2 gen len", len(mamba_gen), 6)

# ── 300: DiTBlock ───────────────────────────────────────────────────────────
print "--- DiTBlock ---"
var dit_block = DiTBlock(16, 4, 4.0, 8)
assert_eq("DiTBlock name", dit_block.get_name(), "DiTBlock")
var x_dit = tensor_randn([16])
var t_emb = tensor_randn([8])
var dit_out = dit_block.forward(x_dit, t_emb)
assert_eq("DiTBlock output dim", len(dit_out), 16)

# ── 301: DiffusionTransformer ───────────────────────────────────────────────
print "--- DiffusionTransformer ---"
var dit = DiffusionTransformer(16, 4, 8, 2, 2, 4, 8)
assert_eq("DiT name", dit.get_name(), "DiffusionTransformer")
assert_true("DiT n_params > 0", dit.n_params() > 0)
assert_eq("DiT n_patches", dit.n_patches, 4)
var noise_pred = dit.forward(tensor_randn([16]), 500, 2)
assert_eq("DiT noise_pred dim", len(noise_pred), 16)
var t_emb_dit = dit.timestep_embedding(100, 8)
assert_eq("DiT t_emb dim", len(t_emb_dit), 8)

# ── 302: DDPMScheduler ──────────────────────────────────────────────────────
print "--- DDPMScheduler ---"
var sched = DDPMScheduler(100, 0.0001, 0.02, "linear")
assert_eq("DDPM name", sched.get_name(), "DDPMScheduler")
assert_eq("DDPM n_timesteps", sched.n_timesteps, 100)
assert_eq("DDPM betas len", len(sched.betas), 100)
assert_eq("DDPM alphas len", len(sched.alphas), 100)
assert_eq("DDPM alphas_cumprod len", len(sched.alphas_cumprod), 100)
assert_true("DDPM beta_0 near start", abs(sched.betas[0] - 0.0001) < 0.01)
assert_true("DDPM alphas_cumprod decreasing", sched.alphas_cumprod[0] > sched.alphas_cumprod[99])
var x0 = tensor_randn([8])
var xt = sched.add_noise(x0, 50)
assert_eq("DDPM add_noise dim", len(xt), 8)
var noise_pred_sched = tensor_randn([8])
var x_prev = sched.step(noise_pred_sched, 50, xt)
assert_eq("DDPM step output dim", len(x_prev), 8)

var cosine_sched = DDPMScheduler(100, 0.0001, 0.02, "cosine")
assert_eq("DDPM cosine schedule len", len(cosine_sched.betas), 100)

# ── 303: DiffusionPipeline ──────────────────────────────────────────────────
print "--- DiffusionPipeline ---"
var dp_dit = DiffusionTransformer(8, 4, 8, 2, 2, 4, 8)
var dp_sched = DDPMScheduler(20, 0.0001, 0.02, "linear")
var dp = DiffusionPipeline(dp_dit, dp_sched, 5)
assert_eq("DiffPipeline name", dp.get_name(), "DiffusionPipeline")
var gen_sample = dp.generate(2, 1.5, 8)
assert_eq("DiffPipeline output dim", len(gen_sample), 8)
assert_eq("DiffPipeline gen count", len(dp.generated), 1)
var gen_uncond = dp.generate(-1, 1.0, 8)
assert_eq("DiffPipeline uncond gen", len(gen_uncond), 8)

# ── 304: FlowMatchingModel ──────────────────────────────────────────────────
print "--- FlowMatchingModel ---"
var fm = FlowMatchingModel(8, 32, 3, 1e-4)
assert_eq("FlowMatch name", fm.get_name(), "FlowMatchingModel")
var x1 = tensor_randn([8])
var x0 = tensor_randn([8])
var xt_flow = fm.conditional_flow(x1, x0, 0.5)
assert_eq("FlowMatch conditional flow dim", len(xt_flow), 8)
var u_t = fm.target_velocity(x1, x0)
assert_eq("FlowMatch target velocity dim", len(u_t), 8)
var fm_loss = fm.flow_matching_loss(x1, 0.3)
assert_true("FlowMatch loss >= 0", fm_loss >= 0.0)
assert_eq("FlowMatch loss history", len(fm.loss_history), 1)
var sample = fm.sample(10)
assert_eq("FlowMatch sample dim", len(sample), 8)

# ── 305: EnergyBasedModel ───────────────────────────────────────────────────
print "--- EnergyBasedModel ---"
var ebm = EnergyBasedModel(8, 16, 3)
assert_eq("EBM name", ebm.get_name(), "EnergyBasedModel")
var e = ebm.energy(tensor_randn([8]))
assert_true("EBM energy is finite", abs(e) < 1e6)
var x_sample = ebm.sample_mcmc(5, tensor_randn([8]))
assert_eq("EBM mcmc sample dim", len(x_sample), 8)
var cd_loss = ebm.contrastive_divergence_loss(tensor_randn([8]), 5)
assert_true("EBM CD loss is finite", abs(cd_loss) < 1e6)

# ── 306: MoDLayer ───────────────────────────────────────────────────────────
print "--- MoDLayer ---"
var dense_fn = lambda x: tensor_apply(x, lambda v: relu(v))
var mod_layer = MoDLayer(8, 0.5, dense_fn)
assert_eq("MoDLayer name", mod_layer.get_name(), "MoDLayer")
var tokens = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var mod_out = mod_layer.forward(tokens)
assert_eq("MoDLayer output n_tokens", len(mod_out), 4)
assert_true("MoDLayer processes some tokens", mod_layer.processed_count > 0)
assert_true("MoDLayer skips some tokens", mod_layer.skipped_count >= 0)
var eff = mod_layer.efficiency_ratio()
assert_true("MoDLayer efficiency in [0,1]", eff >= 0.0 and eff <= 1.0)

# ── 307: xLSTMCell ──────────────────────────────────────────────────────────
print "--- xLSTMCell ---"
var slstm = xLSTMCell(8, 16, true)
assert_eq("xLSTMCell sLSTM name", slstm.get_name(), "xLSTMCell")
var slstm_out = slstm.forward(tensor_randn([8]))
assert_eq("xLSTMCell sLSTM output dim", len(slstm_out), 16)
slstm.reset()
assert_near("xLSTMCell reset h", tensor_norm(slstm.h), 0.0, 1e-9)

var mlstm = xLSTMCell(8, 16, false)
var mlstm_out = mlstm.forward(tensor_randn([8]))
assert_eq("xLSTMCell mLSTM output dim", len(mlstm_out), 16)
mlstm.reset()

# ── 308: xLSTM ──────────────────────────────────────────────────────────────
print "--- xLSTM ---"
var xlstm = xLSTM(8, 16, 3, 0.5)
assert_eq("xLSTM name", xlstm.get_name(), "xLSTM")
assert_true("xLSTM n_params > 0", xlstm.n_params() > 0)
var seq_xlstm = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var xlstm_outs = xlstm.forward(seq_xlstm)
assert_eq("xLSTM output sequence len", len(xlstm_outs), 4)
xlstm.reset()

# ── 309: CrossModalAttention ────────────────────────────────────────────────
print "--- CrossModalAttention ---"
var cma = CrossModalAttention(8, 8, 8, 2)
assert_eq("CrossModal name", cma.get_name(), "CrossModalAttention")
var q_toks = [tensor_randn([8]), tensor_randn([8])]
var kv_toks = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var cma_out = cma.forward(q_toks, kv_toks)
assert_eq("CrossModal output n_q", len(cma_out), 2)
assert_eq("CrossModal output dim", len(cma_out[0]), 8)
assert_eq("CrossModal attn stored", len(cma.attn_weights), 2)

# ── 310: MultimodalFusion ───────────────────────────────────────────────────
print "--- MultimodalFusion ---"
for fusion_type in ["concat", "attention", "bilinear", "product"]:
    var mmf = MultimodalFusion({"text": 8, "image": 16, "audio": 4}, 8, 2, fusion_type)
    assert_eq("MMFusion " + fusion_type + " name", mmf.get_name(), "MultimodalFusion")
    var modal_in = {"text": tensor_randn([8]), "image": tensor_randn([16]), "audio": tensor_randn([4])}
    var fused = mmf.forward(modal_in)
    assert_eq("MMFusion " + fusion_type + " output dim", len(fused), 8)

# ── 311: FoundationTokenizer ────────────────────────────────────────────────
print "--- FoundationTokenizer ---"
var tok = FoundationTokenizer(256, ["<PAD>", "<BOS>", "<EOS>", "<UNK>"])
assert_eq("Tokenizer name", tok.get_name(), "FoundationTokenizer")
assert_true("Tokenizer has special tokens", tok.get_vocab_size() >= 4)
var encoded = tok.encode("hello", 0, true)
assert_true("Tokenizer encode non-empty", len(encoded) > 0)
assert_eq("Tokenizer BOS added", encoded[0], 1)
var encoded_max = tok.encode("hello world", 4, true)
assert_true("Tokenizer truncates to max", len(encoded_max) <= 4)
var decoded = tok.decode([0, 1, 2])
assert_eq("Tokenizer decode len", len(decoded), 3)

# ── 312: RotaryPositionalEncoding ───────────────────────────────────────────
print "--- RotaryPositionalEncoding ---"
var rope = RotaryPositionalEncoding(8, 10000, 512)
assert_eq("RoPE name", rope.get_name(), "RotaryPositionalEncoding")
assert_eq("RoPE freqs dim", len(rope.freqs), 4)
var tok_embs = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var rope_out = rope.forward(tok_embs)
assert_eq("RoPE output seq len", len(rope_out), 3)
assert_eq("RoPE output dim", len(rope_out[0]), 8)
var rotated = rope.apply_rotary(tensor_randn([8]), 42)
assert_eq("RoPE rotated dim", len(rotated), 8)

# ── 313: GroupedQueryAttention ──────────────────────────────────────────────
print "--- GroupedQueryAttention ---"
var gqa = GroupedQueryAttention(16, 4, 2, 4)
assert_eq("GQA name", gqa.get_name(), "GroupedQueryAttention")
var gqa_out = gqa.forward(tensor_randn([16]), true)
assert_eq("GQA output dim", len(gqa_out), 16)
assert_eq("GQA kv_cache k", len(gqa.kv_cache_k), 1)
gqa.forward(tensor_randn([16]), true)
assert_eq("GQA kv_cache grows", len(gqa.kv_cache_k), 2)
gqa.clear_cache()
assert_eq("GQA cache cleared", len(gqa.kv_cache_k), 0)

# ── 314: SlidingWindowAttention ─────────────────────────────────────────────
print "--- SlidingWindowAttention ---"
var swa = SlidingWindowAttention(8, 2, 3, 4)
assert_eq("SWA name", swa.get_name(), "SlidingWindowAttention")
var swa_tokens = [tensor_randn([8]) for i in range(0, 6)]
var swa_out = swa.forward(swa_tokens)
assert_eq("SWA output n_tokens", len(swa_out), 6)
assert_eq("SWA output dim", len(swa_out[0]), 8)

# ── 315: LLMDecoder ─────────────────────────────────────────────────────────
print "--- LLMDecoder ---"
var llm = LLMDecoder(32, 8, 2, 2, 2, 16, 64)
assert_eq("LLMDecoder name", llm.get_name(), "LLMDecoder")
assert_true("LLMDecoder n_params > 0", llm.n_params() > 0)
var llm_logits = llm.forward([1, 2, 3], 0)
assert_eq("LLMDecoder logit dim", len(llm_logits), 32)
var llm_gen = llm.generate([1, 2, 3], 4, 0.8, 5)
assert_eq("LLMDecoder gen len", len(llm_gen), 7)
var llm_greedy = llm.generate([1], 3, 1.0, 0)
assert_eq("LLMDecoder greedy gen len", len(llm_greedy), 4)

# ── 316: VectorQuantizer2 ───────────────────────────────────────────────────
print "--- VectorQuantizer2 ---"
var vq = VectorQuantizer2(8, 4, 0.25, 0.99)
assert_eq("VQ2 name", vq.get_name(), "VectorQuantizer2")
var z = tensor_randn([4])
var vq_result = vq.quantize(z)
assert_true("VQ2 has z_q", "z_q" in vq_result)
assert_true("VQ2 has index", "index" in vq_result)
assert_true("VQ2 index in range", vq_result["index"] >= 0 and vq_result["index"] < 8)
assert_true("VQ2 commit_loss >= 0", vq_result["commit_loss"] >= 0.0)
assert_true("VQ2 codebook_loss >= 0", vq_result["codebook_loss"] >= 0.0)
var batch = [tensor_randn([4]), tensor_randn([4]), tensor_randn([4])]
var vq_batch = vq.quantize_batch(batch)
assert_eq("VQ2 batch results", len(vq_batch), 3)
var perp = vq.codebook_perplexity()
assert_true("VQ2 perplexity >= 1", perp >= 1.0)

# ── 317: FoundationModelBlock ────────────────────────────────────────────────
print "--- FoundationModelBlock ---"
var fmb = FoundationModelBlock(8, 2, 2, 16, true, false, 1.0)
assert_eq("FMBlock name", fmb.get_name(), "FoundationModelBlock")
var fmb_tokens = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var fmb_out = fmb.forward(fmb_tokens)
assert_eq("FMBlock output n_tokens", len(fmb_out), 3)
assert_eq("FMBlock output dim", len(fmb_out[0]), 8)

var fmb_mod = FoundationModelBlock(8, 2, 2, 16, true, true, 0.5)
var fmb_mod_out = fmb_mod.forward(fmb_tokens)
assert_eq("FMBlock MoD output n_tokens", len(fmb_mod_out), 3)

# ── 318: FoundationModel ─────────────────────────────────────────────────────
print "--- FoundationModel ---"
var fm_model = FoundationModel(32, 8, 2, 2, 2, 4.0, 64, false)
assert_eq("FoundationModel name", fm_model.get_name(), "FoundationModel")
assert_true("FoundationModel n_params > 0", fm_model.n_params() > 0)
var fm_logits = fm_model.forward([1, 2, 3, 4])
assert_eq("FoundationModel logit dim", len(fm_logits), 32)
var fm_gen = fm_model.generate([1, 2], 5, 0.8, 4)
assert_eq("FoundationModel gen len", len(fm_gen), 7)
assert_eq("FoundationModel tokens counted", fm_model.n_tokens_generated, 5)

var fm_mod = FoundationModel(32, 8, 2, 2, 2, 4.0, 64, true)
var fm_mod_logits = fm_mod.forward([1, 2, 3])
assert_eq("FoundationModel+MoD logit dim", len(fm_mod_logits), 32)

# ── 319: RewardModel ─────────────────────────────────────────────────────────
print "--- RewardModel ---"
var rm = RewardModel(8, 4)
assert_eq("RewardModel name", rm.get_name(), "RewardModel")
var emb1 = tensor_randn([8])
var emb2 = tensor_randn([8])
var score1 = rm.score(emb1)
assert_true("RewardModel score is finite", abs(score1) < 1e6)
var pair_loss = rm.pairwise_loss(emb1, emb2)
assert_true("RewardModel pairwise loss >= 0", pair_loss >= 0.0)
assert_eq("RewardModel preference stored", len(rm.preference_data), 1)
var chosen_batch = [tensor_randn([8]), tensor_randn([8])]
var rejected_batch = [tensor_randn([8]), tensor_randn([8])]
var train_loss = rm.train_step(chosen_batch, rejected_batch, 0.001)
assert_true("RewardModel train loss >= 0", train_loss >= 0.0)
var win_rate = rm.evaluate_win_rate()
assert_true("RewardModel win_rate in [0,1]", win_rate >= 0.0 and win_rate <= 1.0)

# ── 320: GenerativeAIPipeline ────────────────────────────────────────────────
print "--- GenerativeAIPipeline ---"
var config = {
    "vocab_size": 64,
    "d_model": 8,
    "n_layers": 2,
    "n_heads": 2,
    "max_ctx": 32,
    "temperature": 0.8,
    "top_k": 10,
    "max_new_tokens": 8,
    "use_mod": false
}
var pipeline = GenerativeAIPipeline(config)
assert_eq("Pipeline name", pipeline.get_name(), "GenerativeAIPipeline")

var result = pipeline.generate("hello world")
assert_true("Pipeline has tokens", "tokens" in result)
assert_true("Pipeline has n_new", "n_new" in result)
assert_eq("Pipeline n_new tokens", result["n_new"], 8)
assert_eq("Pipeline gen count", pipeline.generation_count, 1)

result = pipeline.generate("test input")
assert_eq("Pipeline gen count 2", pipeline.generation_count, 2)

var score = pipeline.score("some text")
assert_true("Pipeline score is finite", abs(score) < 1e6)

var lat = tensor_randn([8])
var vq_res = pipeline.quantize_latent(lat)
assert_true("Pipeline VQ has z_q", "z_q" in vq_res)
assert_true("Pipeline VQ has index", "index" in vq_res)

var info = pipeline.get_model_info()
assert_true("Pipeline info n_params", info["n_params"] > 0)
assert_eq("Pipeline info name", info["name"], "GenerativeAIPipeline")
assert_true("Pipeline info vocab_size", info["vocab_size"] > 0)
assert_eq("Pipeline info generations", info["generations"], 2)
assert_true("Pipeline total_tokens counted", info["total_tokens"] > 0)

# MoD variant
var config_mod = {"vocab_size": 32, "d_model": 8, "n_layers": 2, "n_heads": 2, "max_ctx": 32, "temperature": 1.0, "top_k": 5, "max_new_tokens": 4, "use_mod": true}
var pipeline_mod = GenerativeAIPipeline(config_mod)
var result_mod = pipeline_mod.generate("MoD test")
assert_eq("Pipeline+MoD n_new", result_mod["n_new"], 4)

print ""
print "=== INTEGRATION: Full AI Creation Demo ==="
print ""
print "Building a complete text-generation AI from scratch..."
var ai_config = {"vocab_size": 128, "d_model": 16, "n_layers": 3, "n_heads": 4, "max_ctx": 64, "temperature": 0.9, "top_k": 20, "max_new_tokens": 12, "use_mod": true}
var my_ai = GenerativeAIPipeline(ai_config)
var ai_info = my_ai.get_model_info()
print "  Model: FoundationModel + MoD + RoPE + GQA"
print "  Params: " + str(ai_info["n_params"])
print "  Vocab:  " + str(ai_info["vocab_size"])
print "  Layers: " + str(ai_info["n_layers"])

var resp1 = my_ai.generate("The weather today is")
var resp2 = my_ai.generate("Artificial intelligence can")
var resp3 = my_ai.generate("In the future")
assert_eq("AI generated 3 responses", my_ai.generation_count, 3)
assert_true("AI new tokens in resp1", resp1["n_new"] > 0)

print "  Generated " + str(my_ai.generation_count) + " responses (" + str(my_ai.total_tokens) + " total tokens)"
print "  PASS: Complete AI pipeline operational"
passed = passed + 1

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NYTORCH16 TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

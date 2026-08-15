import nytorch
import "lib/nytorch/activations.ny"
import "lib/nytorch/reinforcement.ny"
import "lib/nytorch/convnets.ny"

print "=== NYTORCH14 TEST SUITE ==="
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

# ── 231: ConvBlock ─────────────────────────────────────────────────────────
print "--- ConvBlock ---"
var cb = ConvBlock(1, 8, 3, 1, true, "relu")
assert_eq("ConvBlock name", cb.get_name(), "ConvBlock")
assert_true("ConvBlock n_params", cb.get_n_params() > 0)
var x1d = tensor_randn([64])
var cb_out = cb.forward(x1d, true)
assert_true("ConvBlock forward produces output", len(cb_out) > 0)

# ── 232: ResidualBlock ─────────────────────────────────────────────────────
print "--- ResidualBlock ---"
var rb = ResidualBlock(16, 3, 0.1)
assert_eq("ResidualBlock name", rb.get_name(), "ResidualBlock")
var rb_out = rb.forward(tensor_randn([64]), true)
assert_true("ResidualBlock output non-empty", len(rb_out) > 0)

# ── 233: SimpleResNet ──────────────────────────────────────────────────────
print "--- SimpleResNet ---"
var resnet = SimpleResNet(1, 3, 16, 5)
assert_eq("ResNet name", resnet.get_name(), "SimpleResNet")
assert_true("ResNet n_params", resnet.n_params() > 0)
var logits = resnet.forward(tensor_randn([64]), false)
assert_eq("ResNet n_classes output", len(logits), 5)
var probs = resnet.classify(tensor_randn([64]))
assert_eq("ResNet classify n_classes", len(probs), 5)
var prob_sum = 0.0
for p in probs:
    prob_sum = prob_sum + p
assert_true("ResNet probs sum ~1", abs(prob_sum - 1.0) < 0.01)

# ── 234: YOLOHead ─────────────────────────────────────────────────────────
print "--- YOLOHead ---"
var yolo = YOLOHead(80, 3, 13)
assert_eq("YOLO name", yolo.get_name(), "YOLOHead")
var box1 = [0.5, 0.5, 0.4, 0.4]
var box2 = [0.6, 0.6, 0.4, 0.4]
var iou = yolo.compute_iou(box1, box2)
assert_true("YOLO IoU in [0,1]", iou >= 0.0 and iou <= 1.0)
assert_true("YOLO IoU overlapping > 0", iou > 0.0)
var boxes = [[0.5,0.5,0.3,0.3],[0.6,0.6,0.3,0.3],[0.9,0.9,0.1,0.1]]
var scores = [0.9, 0.85, 0.7]
var keep = yolo.nms(boxes, scores)
assert_true("YOLO NMS keeps at least 1", len(keep) >= 1)
var preds = yolo.forward(tensor_randn([64]))
assert_true("YOLO forward returns list", len(preds) >= 0)

# ── 235: SegmentationHead ─────────────────────────────────────────────────
print "--- SegmentationHead ---"
var seg = SegmentationHead(16, 4, 2)
assert_eq("SegHead name", seg.get_name(), "SegmentationHead")
var features = tensor_randn([32])
var seg_out = seg.forward(features)
assert_true("SegHead has pixel_probs", "pixel_probs" in seg_out)
assert_true("SegHead has class_probs", "class_probs" in seg_out)
assert_eq("SegHead n_classes probs", len(seg_out["class_probs"]), 4)

# ── 236: ImagePatchEmbedder ────────────────────────────────────────────────
print "--- ImagePatchEmbedder ---"
var patcher = ImagePatchEmbedder(32, 8, 64)
assert_eq("PatchEmbedder name", patcher.get_name(), "ImagePatchEmbedder")
assert_eq("PatchEmbedder n_patches", patcher.get_n_patches(), 16)
var seq = patcher.forward(tensor_zeros([1024]))
assert_eq("PatchEmbedder seq len = n_patches+1", len(seq), 17)

# ── 237: VisionTransformer ─────────────────────────────────────────────────
print "--- VisionTransformer ---"
var vit = VisionTransformer(32, 8, 64, 4, 2, 10, 4)
assert_eq("ViT name", vit.get_name(), "VisionTransformer")
assert_true("ViT n_params", vit.n_params() > 0)
var vit_out = vit.forward(tensor_zeros([1024]))
assert_eq("ViT output dim", len(vit_out), 10)
var cls_result = vit.classify(tensor_zeros([1024]))
assert_true("ViT classify has probs", "probs" in cls_result)
assert_true("ViT classify has pred_class", "pred_class" in cls_result)

# ── 238: MelSpectrogram ────────────────────────────────────────────────────
print "--- MelSpectrogram ---"
var mel_spec = MelSpectrogram(22050, 512, 128, 40, 0.0, 8000.0)
assert_eq("MelSpec name", mel_spec.get_name(), "MelSpectrogram")
assert_eq("MelSpec n_mels", mel_spec.get_n_mels(), 40)
var wave = linspace(-1.0, 1.0, 2048)
var mel_out = mel_spec.compute(wave)
assert_true("MelSpec output non-empty", len(mel_out) > 0)
var mel_db = mel_spec.compute_db(wave)
assert_true("MelSpec dB output non-empty", len(mel_db) > 0)

# ── 239: MFCCExtractor ─────────────────────────────────────────────────────
print "--- MFCCExtractor ---"
var mfcc_ext = MFCCExtractor(22050, 13, 40, 512, 128)
assert_eq("MFCC name", mfcc_ext.get_name(), "MFCCExtractor")
var wave2 = tensor_randn([2048])
var mfcc_out = mfcc_ext.extract(wave2)
assert_eq("MFCC output n_coeffs", len(mfcc_out), 13)
var delta_result = mfcc_ext.extract_delta(wave2)
assert_true("MFCC delta has mfcc", "mfcc" in delta_result)
assert_true("MFCC delta has delta", "delta" in delta_result)
assert_eq("MFCC delta n_coeffs", delta_result["n_coeffs"], 13)

# ── 240: WaveNetBlock ──────────────────────────────────────────────────────
print "--- WaveNetBlock ---"
var wnb = WaveNetBlock(8, 1, 2)
assert_eq("WaveNetBlock name", wnb.get_name(), "WaveNetBlock")
assert_eq("WaveNetBlock dilation", wnb.get_dilation(), 1)
var wnb_result = wnb.forward(tensor_randn([32]), 0.0)
assert_eq("WaveNetBlock result has [res, skip]", len(wnb_result), 2)
assert_true("WaveNetBlock skip is float", type(wnb_result[1]) == "float" or type(wnb_result[1]) == "int")

# ── 241: WaveNet ───────────────────────────────────────────────────────────
print "--- WaveNet ---"
var wn = WaveNet(8, 3, 2, 256)
assert_eq("WaveNet name", wn.get_name(), "WaveNet")
assert_eq("WaveNet n_blocks", wn.n_blocks(), 6)
var wn_out = wn.forward(tensor_randn([64]))
assert_eq("WaveNet output n_classes", len(wn_out), 256)
var wn_sum = 0.0
for v in wn_out:
    wn_sum = wn_sum + v
assert_true("WaveNet probs sum ~1", abs(wn_sum - 1.0) < 0.05)

# ── 242: CTCDecoder ────────────────────────────────────────────────────────
print "--- CTCDecoder ---"
var vocab = ["_", "a", "b", "c", "d", "e", "f", " "]
var ctc = CTCDecoder(vocab, 0)
assert_eq("CTC name", ctc.get_name(), "CTCDecoder")
var frames = []
for i in range(0, 10):
    frames = frames + [float(i % len(vocab))]
var token_ids = ctc.greedy_decode(frames)
assert_true("CTC greedy decode runs", len(token_ids) >= 0)
var ctc_text = ctc.decode_to_string([1, 2, 3, 7, 4, 5])
assert_true("CTC decode to string", len(ctc_text) > 0)
var ctc_loss_val = ctc.compute_loss(100, 20)
assert_true("CTC loss > 0", ctc_loss_val > 0.0)

# ── 243: ASRPipeline ───────────────────────────────────────────────────────
print "--- ASRPipeline ---"
var asr_vocab = ["_", "a", "b", "c", "d", "e", "h", "i", "l", "o", "t", " "]
var asr = ASRPipeline(16000, 13, asr_vocab, 32)
assert_eq("ASR name", asr.get_name(), "ASRPipeline")
var audio = tensor_randn([4096])
var transcript = asr.transcribe(audio)
assert_true("ASR has text", "text" in transcript)
assert_true("ASR has n_frames", transcript["n_frames"] > 0)

# ── 244: TCNLayer ──────────────────────────────────────────────────────────
print "--- TCNLayer ---"
var tcn_layer = TCNLayer(8, 16, 3, 1, 0.1)
assert_eq("TCNLayer name", tcn_layer.get_name(), "TCNLayer")
var tcn_in = tensor_randn([64])
var tcn_out = tcn_layer.forward(tcn_in, true)
assert_true("TCNLayer output non-empty", len(tcn_out) > 0)

# ── 245: TemporalConvNet ────────────────────────────────────────────────────
print "--- TemporalConvNet ---"
var tcn = TemporalConvNet(8, [16, 32, 16], 3, 0.1)
assert_eq("TCN name", tcn.get_name(), "TemporalConvNet")
assert_eq("TCN n_layers", tcn.n_layers(), 3)
var tcn_full_out = tcn.forward(tensor_randn([64]), true)
assert_true("TCN output non-empty", len(tcn_full_out) > 0)

# ── 246: ARIMAModel ────────────────────────────────────────────────────────
print "--- ARIMAModel ---"
var arima = ARIMAModel(2, 1, 1)
assert_eq("ARIMA name", arima.get_name(), "ARIMAModel")
var ts = linspace(0.0, 10.0, 50)
ts = tensor_add(ts, tensor_mul(tensor_randn([50]), tensor([0.1])))
arima.fit(ts)
var info = arima.get_info()
assert_eq("ARIMA p", info["p"], 2)
assert_eq("ARIMA d", info["d"], 1)
assert_eq("ARIMA q", info["q"], 1)
var forecast = arima.forecast(5)
assert_eq("ARIMA forecast len", len(forecast), 5)

# ── 247: TimeSeriesTransformer ─────────────────────────────────────────────
print "--- TimeSeriesTransformer ---"
var tst = TimeSeriesTransformer(1, 16, 4, 2, 12, 0.1)
assert_eq("TST name", tst.get_name(), "TimeSeriesTransformer")
var history_ts = tensor_randn([48])
var tst_preds = tst.forecast(history_ts)
assert_eq("TST forecast len", len(tst_preds), 12)

# ── 248: ExperimentTracker ─────────────────────────────────────────────────
print "--- ExperimentTracker ---"
var tracker = ExperimentTracker("resnet_exp", ["vision", "classification"])
assert_eq("Tracker name", tracker.get_name(), "ExperimentTracker")
tracker.start_run("run_001")
tracker.log_param("lr", 0.001)
tracker.log_param("batch_size", 32)
tracker.log_metric("loss", 1.5, 0)
tracker.log_metric("loss", 1.2, 100)
tracker.log_metric("loss", 0.9, 200)
tracker.log_metric("accuracy", 0.75, 100)
tracker.log_metric("accuracy", 0.85, 200)
tracker.log_artifact("model_weights.ny")
tracker.end_run("completed")
assert_eq("Tracker run_count", tracker.run_count, 1)
tracker.start_run("run_002")
tracker.log_metric("loss", 0.8, 200)
tracker.log_metric("accuracy", 0.88, 200)
tracker.end_run("completed")
var best_run = tracker.get_best_run("loss", "min")
assert_true("Tracker finds best run", len(best_run["run"]) > 0)
assert_true("Tracker best value < 1.0", best_run["value"] < 1.0)

# ── 249: MetricsCollector ──────────────────────────────────────────────────
print "--- MetricsCollector ---"
var collector = MetricsCollector("training_metrics", 100)
assert_eq("Collector name", collector.get_name(), "training_metrics")
for i in range(0, 20):
    collector.record("loss", 1.0 / (float(i) + 1.0))
    collector.record("accuracy", float(i) / 20.0)
    collector.increment("batch_count", 1.0)
collector.set_gauge("learning_rate", 0.001)
var loss_summary = collector.summary("loss")
assert_true("Collector loss mean > 0", loss_summary["mean"] > 0.0)
assert_true("Collector loss min > 0", loss_summary["min"] > 0.0)
assert_eq("Collector loss count", loss_summary["count"], 20)
var batch_count = collector.counters["batch_count"]
assert_eq("Collector counter correct", batch_count, 20.0)
assert_eq("Collector gauge set", collector.gauges["learning_rate"], 0.001)

# ── 250: AlertManager ─────────────────────────────────────────────────────
print "--- AlertManager ---"
var alerts = AlertManager("prod_alerts")
assert_eq("AlertManager name", alerts.get_name(), "prod_alerts")
alerts.add_rule("high_loss", "loss", ">", 0.5, "warning")
alerts.add_rule("low_accuracy", "accuracy", "<", 0.7, "critical")
alerts.add_rule("max_latency", "latency_ms", ">", 200.0, "warning")
var metrics_snap = {"loss": 0.8, "accuracy": 0.65, "latency_ms": 150.0}
var fired = alerts.check(metrics_snap)
assert_eq("AlertManager fires 2 rules", len(fired), 2)
assert_true("AlertManager total_fired = 2", alerts.total_fired == 2)
alerts.silence("high_loss")
fired = alerts.check(metrics_snap)
assert_eq("AlertManager silences rule", len(fired), 1)

# ── 251: ModelMonitor ──────────────────────────────────────────────────────
print "--- ModelMonitor ---"
var monitor = ModelMonitor("resnet50", {"accuracy": 0.9, "latency_ms": 50.0})
assert_eq("Monitor name", monitor.get_name(), "ModelMonitor")
for i in range(0, 10):
    monitor.record_prediction(0.8, 0.9, 45.0)
for i in range(0, 5):
    monitor.record_prediction(0.2, 0.9, 55.0)
var snap = monitor.get_snapshot()
assert_eq("Monitor total predictions", snap["predictions"], 15)
assert_true("Monitor error_rate tracked", snap["error_rate"] >= 0.0 and snap["error_rate"] <= 1.0)
var health = monitor.check_health()
assert_true("Monitor health has snapshot", "snapshot" in health)
assert_true("Monitor health has alerts", "alerts" in health)

# ── 252: DatasetBuilder ────────────────────────────────────────────────────
print "--- DatasetBuilder ---"
var builder = DatasetBuilder("okra_dataset", {"image": "tensor", "label": "int", "stage": "str"})
assert_eq("DatasetBuilder name", builder.get_name(), "okra_dataset")
for i in range(0, 100):
    builder.add_record({"image": tensor_randn([16]), "label": i % 5, "stage": "ripe" if i % 2 == 0 else "unripe"})
assert_eq("DatasetBuilder total", builder.total_added, 100)
var encoder = builder.fit_label_encoder("stage")
assert_true("DatasetBuilder encoder has 2 classes", len(encoder) == 2)
var splits = builder.build(0.7, 0.15, 0.15)
assert_true("DatasetBuilder train split non-empty", len(splits["train"]) > 0)
assert_true("DatasetBuilder val split non-empty", len(splits["val"]) > 0)

# ── 253: DataSampler ──────────────────────────────────────────────────────
print "--- DataSampler ---"
var sampler = DataSampler("random", 42)
assert_eq("DataSampler name", sampler.get_name(), "DataSampler")
var data = []
var labels = []
for i in range(0, 50):
    data = data + [float(i)]
    labels = labels + [i % 3]
var weights = sampler.compute_class_weights(labels)
assert_true("DataSampler weights non-empty", len(weights) > 0)
var batch = sampler.sample(data, 16)
assert_eq("DataSampler batch size", len(batch), 16)
var boot = sampler.bootstrap_sample(data)
assert_eq("DataSampler bootstrap same size", len(boot), len(data))

# ── 254: DataAugmenter ────────────────────────────────────────────────────
print "--- DataAugmenter ---"
var augmenter = DataAugmenter(1.0)
assert_eq("DataAugmenter name", augmenter.get_name(), "DataAugmenter")
augmenter.add_augmentation("gaussian_noise", lambda x: tensor_add(x, tensor_mul(tensor_randn([len(x)]), tensor([0.05]))), 0.5)
augmenter.add_augmentation("flip", lambda x: tensor_flip(x), 0.5)
augmenter.add_augmentation("scale", lambda x: tensor_mul(x, tensor([0.9 + 0.2 * 0.5])), 0.3)
assert_eq("DataAugmenter n_augmentations", len(augmenter.augmentations), 3)
var sample_data = tensor_randn([16])
var aug_out = augmenter.augment(sample_data, 42)
assert_true("DataAugmenter augment returns tensor", len(aug_out) > 0)
var batch_data = [tensor_randn([8]), tensor_randn([8]), tensor_randn([8])]
var aug_batch = augmenter.augment_batch(batch_data, 0)
assert_eq("DataAugmenter batch size preserved", len(aug_batch), 3)

# ── 255: TensorboardWriter ────────────────────────────────────────────────
print "--- TensorboardWriter ---"
var tb = TensorboardWriter("./logs/exp1", 30)
assert_eq("TB name", tb.get_name(), "TensorboardWriter")
for step in range(0, 10):
    tb.add_scalar("loss/train", 1.0 / (float(step) + 1.0), step)
    tb.add_scalar("loss/val", 1.1 / (float(step) + 1.0), step)
    tb.add_scalar("accuracy/train", float(step) / 10.0, step)
tb.add_scalars("metrics", {"precision": 0.9, "recall": 0.85, "f1": 0.87}, 10)
var grads = tensor_randn([32])
tb.add_histogram("gradients/layer1", grads, 5)
tb.add_text("notes", "Training run 1 - baseline", 0)
var hist = tb.get_scalar_history("loss/train")
assert_eq("TB scalar history length", len(hist), 10)
var flush_info = tb.flush()
assert_true("TB scalars tracked", flush_info["scalars"] > 0)
assert_eq("TB global step", flush_info["step"], 10)

# ── 256: CheckpointManager ────────────────────────────────────────────────
print "--- CheckpointManager ---"
var ckpt = CheckpointManager("./checkpoints", 3, "val_loss", "min")
assert_eq("Ckpt name", ckpt.get_name(), "CheckpointManager")
var r1 = ckpt.save("model_state_v1", 1.5, 100)
var r2 = ckpt.save("model_state_v2", 1.2, 200)
var r3 = ckpt.save("model_state_v3", 0.9, 300)
assert_true("Ckpt r3 is best", r3["is_best"])
assert_true("Ckpt best value updated", ckpt.best_value < 1.0)
var r4 = ckpt.save("model_state_v4", 1.1, 400)
assert_true("Ckpt r4 not best (loss went up)", not r4["is_best"])
assert_true("Ckpt keeps max_to_keep", len(ckpt.list_checkpoints()) <= 3)
var best = ckpt.load_best()
assert_true("Ckpt best path non-empty", len(best["path"]) > 0)

# ── 257: LearningRateFinder ────────────────────────────────────────────────
print "--- LearningRateFinder ---"
var lr_finder = LearningRateFinder("resnet", "adam", 1e-7, 10.0, 100)
assert_eq("LRFinder name", lr_finder.get_name(), "LearningRateFinder")
var lr_result = lr_finder.run([])
assert_true("LRFinder best_lr > 0", lr_result["best_lr"] > 0.0)
assert_true("LRFinder min_loss >= 0", lr_result["min_loss"] >= 0.0)
assert_eq("LRFinder n_steps", lr_result["n_steps"], 100)
var summary = lr_finder.plot_summary()
assert_true("LRFinder summary non-empty", len(summary) > 10)

# ── 258: GradientAnalyzer ─────────────────────────────────────────────────
print "--- GradientAnalyzer ---"
var grad_analyzer = GradientAnalyzer("resnet50", true, true)
assert_eq("GradAnalyzer name", grad_analyzer.get_name(), "GradientAnalyzer")
for step in range(0, 5):
    grad_analyzer.record_grads("conv1", tensor_randn([32]))
    grad_analyzer.record_grads("conv2", tensor_randn([64]))
    grad_analyzer.record_grads("fc", tensor_randn([16]))
var ga_summary = grad_analyzer.summary()
assert_eq("GradAnalyzer tracks 3 layers", ga_summary["layers_tracked"], 3)
grad_analyzer.record_grads("conv_explode", tensor_mul(tensor_randn([8]), tensor([100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0])))
assert_true("GradAnalyzer detects explosion", grad_analyzer.explosion_events > 0)
var problems = grad_analyzer.detect_problems()
assert_true("GradAnalyzer reports problems", len(problems) > 0)

# ── 259: ProfilerSession ──────────────────────────────────────────────────
print "--- ProfilerSession ---"
var profiler = ProfilerSession("training_profiler", true)
assert_eq("Profiler name", profiler.get_name(), "training_profiler")
for i in range(0, 5):
    profiler.start_event("forward_pass")
    profiler.end_event("forward_pass")
    profiler.start_event("backward_pass")
    profiler.end_event("backward_pass")
    profiler.start_event("optimizer_step")
    profiler.end_event("optimizer_step")
profiler.record_memory("after_batch_1", 1024 * 1024 * 512)
var report = profiler.report()
assert_eq("Profiler total_events", report["total_events"], 15)
assert_eq("Profiler memory snapshots", report["memory_snapshots"], 1)
assert_true("Profiler hotspots non-empty", len(report["hotspots"]) > 0)

# ── 260: HyperparameterBayesOpt ────────────────────────────────────────────
print "--- HyperparameterBayesOpt ---"
var bayes_opt = HyperparameterBayesOpt(
    {"lr": [1e-5, 1e-1], "dropout": [0.0, 0.5], "weight_decay": [1e-6, 1e-2]},
    5,
    "ei"
)
assert_eq("BayesOpt name", bayes_opt.get_name(), "HyperparameterBayesOpt")
for trial in range(0, 15):
    var params = bayes_opt.suggest()
    assert_true("BayesOpt suggest has lr", "lr" in params)
    assert_true("BayesOpt suggest has dropout", "dropout" in params)
    var fake_loss = abs(params["lr"] - 0.001) + abs(params["dropout"] - 0.2) + abs(params["weight_decay"] - 0.0001)
    bayes_opt.observe(params, fake_loss)
var best_params = bayes_opt.best()
assert_eq("BayesOpt n_observations", best_params["n_observations"], 15)
assert_true("BayesOpt best_value >= 0", best_params["value"] >= 0.0)

# ── Summary ──────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NYTORCH14 TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

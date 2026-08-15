import nytorch
import "lib/nytorch/activations.ny"
import "lib/nytorch/reinforcement.ny"
import "lib/nytorch/convnets.ny"
import "lib/nytorch/neural_ode.ny"
import "lib/nytorch/sequence.ny"
import "lib/nytorch/compute.ny"

print "=== NYTORCH17 DEVICE-AGNOSTIC AI TEST SUITE ==="
print ""

var passed = 0
var failed = 0

def assert_eq(name, a, b):
    if a == b:
        passed = passed + 1
    else:
        print "  FAIL: " + name + " (got " + str(a) + " expected " + str(b) + ")"
        failed = failed + 1

def assert_true(name, cond):
    if cond:
        passed = passed + 1
    else:
        print "  FAIL: " + name
        failed = failed + 1

def assert_gt(name, val, threshold):
    if val > threshold:
        passed = passed + 1
    else:
        print "  FAIL: " + name + " (got " + str(val) + " expected > " + str(threshold) + ")"
        failed = failed + 1

# ── DeviceManager ──────────────────────────────────────────────────────────
var dm = DeviceManager()
assert_eq("DM name", dm.get_name(), "DeviceManager")
dm.detect()
var info = dm.info()
assert_true("DM backend set", info["backend"] == "cpu" or info["backend"] == "cuda" or info["backend"] == "tpu")
assert_true("DM cpu_cores > 0", info["n_cores"] > 0)
var bench = dm.benchmark()
assert_true("DM bench has bench_ms", "bench_ms" in bench)
assert_true("DM bench_ms >= 0", bench["bench_ms"] >= 0.0)

# ── TensorDevice ───────────────────────────────────────────────────────────
var t_data = tensor_randn([16])
var td = TensorDevice(t_data, "cpu")
assert_eq("TD name", td.get_name(), "TensorDevice")
assert_eq("TD size", td.size(), 16)
td.to("cuda")
assert_eq("TD device changed", td.device, "cuda")
td.cpu()
assert_eq("TD back to cpu", td.device, "cpu")
var td2 = TensorDevice(tensor_randn([16]), "cpu")
var added = td.add(td2)
assert_eq("TD add size", added.size(), 16)
assert_true("TD mean is float", td.mean() != none)

# ── ComputeScheduler ───────────────────────────────────────────────────────
var cs = ComputeScheduler(4)
assert_eq("CS name", cs.get_name(), "ComputeScheduler")
cs.submit("task1", lambda args: tensor_mean(tensor_randn([8])), [])
cs.submit("task2", lambda args: tensor_norm(tensor_randn([8])), [])
var results = cs.run_all()
assert_true("CS results has task1", "task1" in results)
assert_true("CS results has task2", "task2" in results)
assert_eq("CS completed", cs.completed, 2)
assert_true("CS throughput >= 0", cs.throughput() >= 0.0)

# ── OptimizedLayer ─────────────────────────────────────────────────────────
var ol = OptimizedLayer(8, 4, "cpu")
assert_eq("OL name", ol.get_name(), "OptimizedLayer")
assert_gt("OL n_params > 0", ol.n_params(), 0)
var x = tensor_randn([8])
var out = ol.forward(x)
assert_eq("OL output dim", len(out), 4)

# ── UniversalLoader ────────────────────────────────────────────────────────
var ul = UniversalLoader()
assert_eq("UL name", ul.get_name(), "UniversalLoader")
save_text("/tmp/test_doc.txt", "NyTorch is a deep learning framework.\nIt supports GPU and TPU devices.\nAI capabilities are built-in.")
var loaded = ul.load_file("/tmp/test_doc.txt")
assert_true("UL loaded content", len(loaded["content"]) > 10)
assert_eq("UL doc type", loaded["type"], "txt")
assert_gt("UL doc chars > 0", loaded["chars"], 0)
assert_eq("UL doc_count", ul.doc_count, 1)

# CSV loading
save_text("/tmp/test_data.csv", "name,age,score\nAlice,25,92.5\nBob,30,88.0\nCarol,28,95.0")
var csv = ul.load_csv("/tmp/test_data.csv", true)
assert_eq("UL csv n_rows", csv["n_rows"], 3)
assert_eq("UL csv n_cols", csv["n_cols"], 3)
assert_eq("UL csv first header", csv["headers"][0], "name")

# ── WebScraper ─────────────────────────────────────────────────────────────
var ws = WebScraper()
assert_eq("WS name", ws.get_name(), "WebScraper")
var stripped = ws.extract_text("<h1>Hello</h1><p>World</p>")
assert_true("WS strip removes tags", not string_contains(stripped, "<h1>"))
assert_true("WS strip keeps text", string_contains(stripped, "Hello"))

# ── KnowledgeBase ──────────────────────────────────────────────────────────
var kb = KnowledgeBase(32)
assert_eq("KB name", kb.get_name(), "KnowledgeBase")
kb.add_document("doc1", "Deep learning is a subset of machine learning.", {"topic": "AI"})
kb.add_document("doc2", "NyTorch enables GPU-accelerated tensor operations.", {"topic": "framework"})
kb.add_document("doc3", "Natural language processing handles text data.", {"topic": "NLP"})
assert_eq("KB n_docs", kb.n_docs, 3)
var search_results = kb.search("deep learning neural networks", 2)
assert_eq("KB search top_k", len(search_results), 2)
assert_true("KB search has id", "id" in search_results[0])
assert_true("KB search has score", "score" in search_results[0])
var save_ok = kb.save("/tmp/kb_test.txt")
assert_true("KB save ok", save_ok)

# ── LanguageDetector ───────────────────────────────────────────────────────
var ld = LanguageDetector()
assert_eq("LD name", ld.get_name(), "LanguageDetector")
var en_result = ld.detect("The quick brown fox jumps over the lazy dog")
assert_eq("LD detect english", en_result["language"], "english")
assert_gt("LD confidence > 0", en_result["confidence"], 0.0)
assert_gt("LD word count", en_result["words"], 0)
var fr_result = ld.detect("le chat est sur la table et les enfants jouent")
assert_eq("LD detect french", fr_result["language"], "french")

# ── Translator ─────────────────────────────────────────────────────────────
var tr = Translator()
assert_eq("TR name", tr.get_name(), "Translator")
var en_fr = tr.translate("the deep learning model", "en", "fr")
assert_eq("TR status ok", en_fr["status"], "ok")
assert_true("TR translated not empty", len(en_fr["translated"]) > 0)
assert_gt("TR word count > 0", en_fr["words"], 0)
var en_es = tr.translate("the neural network", "en", "es")
assert_eq("TR es status", en_es["status"], "ok")
var unsupported = tr.translate("hello", "en", "zh")
assert_eq("TR unsupported status", unsupported["status"], "unsupported")

# ── CodeAnalyzer ───────────────────────────────────────────────────────────
var ca = CodeAnalyzer()
assert_eq("CA name", ca.get_name(), "CodeAnalyzer")
var py_code = "import numpy as np\nclass MyModel:\n    def __init__(self):\n        pass\n    def forward(self, x):\n        return x\n\ndef train(model, data):\n    for batch in data:\n        loss = model.forward(batch)\n    return loss\n"
var analysis = ca.analyze(py_code)
assert_true("CA lang python or nython", analysis["language"] == "python" or analysis["language"] == "nython")
assert_gt("CA n_lines > 0", analysis["lines"], 0)
assert_gt("CA functions >= 2", analysis["functions"], 1)
assert_gt("CA classes >= 1", analysis["classes"], 0)
var gen_fn = ca.generate_function("compute_loss", ["predictions", "targets"], "Compute MSE loss", "python")
assert_true("CA gen contains def", string_contains(gen_fn, "def compute_loss"))
var gen_cls = ca.generate_class("MyAgent", ["process", "learn", "act"], "nython")
assert_true("CA gen class contains name", string_contains(gen_cls, "MyAgent"))

# ── AIInterface ────────────────────────────────────────────────────────────
var ai = AIInterface("anthropic", "test_key_123", "claude-sonnet-4-20250514")
assert_eq("AI name", ai.get_name(), "AIInterface")
assert_eq("AI provider", ai.provider, "anthropic")
assert_eq("AI model", ai.model_name, "claude-sonnet-4-20250514")
assert_true("AI endpoint set", string_contains(ai.endpoint, "anthropic"))
var payload = ai._build_payload("Hello AI", "You are helpful.", 100, 0.7)
assert_true("AI payload is json", string_contains(payload, "claude"))
ai.reset_context()
assert_eq("AI history cleared", len(ai.conversation_history), 0)

# ── AutonomousLearner ──────────────────────────────────────────────────────
var al = AutonomousLearner("TestLearner", 32)
assert_eq("AL name", al.get_name(), "AutonomousLearner")
var learn_result = al.learn_from_file("/tmp/test_doc.txt")
assert_true("AL learned file", learn_result["total_docs"] > 0)
assert_eq("AL episodes", al.n_learning_episodes, 1)
al.learn_fact("NyTorch version 3.0 has 350 classes")
assert_eq("AL facts count", len(al.learned_facts), 1)
var recall = al.recall("deep learning", 2)
assert_true("AL recall returns list", len(recall) >= 0)
var summary = al.summarize()
assert_eq("AL summary agent", summary["agent"], "TestLearner")
assert_gt("AL summary docs > 0", summary["docs"], 0)

# ── CodeGenerator ──────────────────────────────────────────────────────────
var cg = CodeGenerator("python", none)
assert_eq("CG name", cg.get_name(), "CodeGenerator")
var sort_code = cg.from_description("sort a list of numbers")
assert_true("CG sort contains def", string_contains(sort_code, "def ") or string_contains(sort_code, "sort"))
var neural_code = cg.from_description("neural network model")
assert_true("CG neural contains class", string_contains(neural_code, "class") or string_contains(neural_code, "torch"))
var tests = cg.generate_tests("", "my_function")
assert_true("CG tests contain function", string_contains(tests, "my_function"))
assert_gt("CG programs count > 0", len(cg.generated_programs), 0)

# ── SelfImprovingAgent ─────────────────────────────────────────────────────
var sia = SelfImprovingAgent("Improver", none)
assert_eq("SIA name", sia.get_name(), "SelfImprovingAgent")
var test_data = [tensor_randn([4]), tensor_randn([4]), tensor_randn([4])]
var score = sia.evaluate(lambda x: tensor_mean(x), test_data)
assert_true("SIA score in [0,1]", score >= 0.0 and score <= 1.0)
sia.remember({"type": "evaluation", "score": score})
assert_gt("SIA memory not empty", len(sia.memory), 0)
var improve_result = sia.improve("adaptive")
assert_true("SIA improve has action", "action" in improve_result)
assert_eq("SIA iteration", improve_result["iteration"], 1)

# ── MultiAgentOrchestrator ─────────────────────────────────────────────────
var mao = MultiAgentOrchestrator()
assert_eq("MAO name", mao.get_name(), "MultiAgentOrchestrator")
mao.register_agent("agent_a", none, ["translate", "summarize"])
mao.register_agent("agent_b", none, ["code", "analyze"])
assert_eq("MAO n_agents", len(mao.agent_names), 2)
mao.submit_task("t1", "translate", "Hello world")
mao.submit_task("t2", "code", "Sort function")
var dispatched = mao.dispatch_all()
assert_eq("MAO dispatched", dispatched["dispatched"], 2)
var broadcast_result = mao.broadcast("ping", "status")
assert_true("MAO broadcast both agents", "agent_a" in broadcast_result and "agent_b" in broadcast_result)

# ── MemoryManager ──────────────────────────────────────────────────────────
var mm = MemoryManager(100)
assert_eq("MM name", mm.get_name(), "MemoryManager")
var ep_id = mm.store_episode({"type": "test", "value": 42})
assert_true("MM episode stored", ep_id >= 0)
mm.store_fact("nytorch_version", "3.0")
var fact = mm.recall_fact("nytorch_version")
assert_eq("MM recall fact", fact, "3.0")
mm.set_working("current_task", "testing")
assert_eq("MM working memory", mm.get_working("current_task"), "testing")
mm.clear_working()
assert_eq("MM clear working", mm.get_working("current_task"), none)
var recent = mm.recent_episodes(5)
assert_gt("MM recent episodes >= 1", len(recent), 0)
var stats = mm.stats()
assert_gt("MM stats episodes", stats["episodes"], 0)

# ── ActionPlanner ──────────────────────────────────────────────────────────
var ap = ActionPlanner("Planner")
assert_eq("AP name", ap.get_name(), "ActionPlanner")
ap.register_action("fetch_data", lambda args: {"data": tensor_randn([4])}, [], ["data_available"])
ap.register_action("train_model", lambda args: {"loss": 0.5}, ["data_available"], ["model_trained"])
ap.add_goal("goal_1", "Train a model", 1)
assert_eq("AP goals count", len(ap.goals), 1)
var plan = ap.plan("goal_1")
assert_gt("AP plan has steps", len(plan), 0)
var exec_result = ap.execute_step("fetch_data", [])
assert_eq("AP exec status", exec_result["status"], "ok")
assert_gt("AP exec log", len(ap.execution_log), 0)

# ── DocumentSummarizer ─────────────────────────────────────────────────────
var ds = DocumentSummarizer(100, none)
assert_eq("DS name", ds.get_name(), "DocumentSummarizer")
var long_text = "Deep learning is a transformative technology. It enables computers to learn from data. Neural networks process information hierarchically. Transformers have revolutionized NLP. The future of AI is bright and promising. Many companies invest in AI research. NyTorch makes AI accessible to everyone."
var summary = ds.extractive_summary(long_text, 2)
assert_true("DS summary not empty", len(summary) > 0)
assert_true("DS summary shorter", len(summary) < len(long_text))
var stored = ds.summarize("test_doc", long_text)
assert_true("DS stored summary", "test_doc" in ds.summaries)

# ── NaturalLanguageProcessor ───────────────────────────────────────────────
var nlp = NaturalLanguageProcessor()
assert_eq("NLP name", nlp.get_name(), "NaturalLanguageProcessor")
var tokens = nlp.tokenize("Deep learning is amazing and transformative")
assert_gt("NLP tokenize count", len(tokens), 3)
var clean = nlp.remove_stopwords(tokens)
assert_true("NLP stopwords removed", len(clean) <= len(tokens))
var pos_text = nlp.sentiment("This is a great and amazing product that I love very much!")
assert_eq("NLP positive sentiment", pos_text["sentiment"], "positive")
var neg_text = nlp.sentiment("This is a terrible awful product that I hate")
assert_eq("NLP negative sentiment", neg_text["sentiment"], "negative")
var neutral = nlp.sentiment("The sky is blue and water is wet")
assert_true("NLP neutral is valid", neutral["sentiment"] == "neutral" or neutral["sentiment"] == "positive" or neutral["sentiment"] == "negative")
var keywords = nlp.keyword_extract("deep learning neural networks transform artificial intelligence AI", 5)
assert_true("NLP keywords not empty", len(keywords) > 0)
assert_true("NLP keyword has word", "word" in keywords[0])
var full = nlp.process("NyTorch enables amazing deep learning capabilities")
assert_true("NLP process has tokens", "tokens" in full)
assert_true("NLP process has sentiment", "sentiment" in full)
assert_true("NLP process has keywords", "keywords" in full)

# ── ReplicationEngine ──────────────────────────────────────────────────────
var re_engine = ReplicationEngine()
assert_eq("RE name", re_engine.get_name(), "ReplicationEngine")
var agent_id = re_engine.create_agent("root_agent", {"lr": 0.001, "layers": 3}, none)
assert_eq("RE created agent", agent_id, "root_agent")
assert_eq("RE generation 0", re_engine.get_generation("root_agent"), 0)
var child = re_engine.replicate("root_agent", 0.1)
assert_true("RE child created", child != none)
assert_eq("RE child generation", re_engine.get_generation(child), 1)
var forks = re_engine.fork("root_agent", 3)
assert_eq("RE fork count", len(forks), 3)
var lineage = re_engine.get_lineage("root_agent")
assert_gt("RE lineage not empty", len(lineage), 0)
var re_stats = re_engine.stats()
assert_gt("RE total agents > 4", re_stats["total_agents"], 4)

# ── ModelOptimizer ─────────────────────────────────────────────────────────
var mo = ModelOptimizer("float32")
assert_eq("MO name", mo.get_name(), "ModelOptimizer")
var weights = tensor_randn([64])
var q8 = mo.quantize(weights, 8)
assert_eq("MO quant bits", q8["bits"], 8)
assert_eq("MO quant compression", q8["compression"], 4.0)
assert_eq("MO quant size", len(q8["weights"]), 64)
var pruned = mo.prune(weights, 0.5)
assert_gt("MO prune sparsity > 0", pruned["sparsity"], 0.0)
assert_gt("MO params removed >= 0", pruned["n_params_removed"], -1)
var logits_t = tensor_randn([8])
var logits_s = tensor_randn([8])
var kl = mo.distill(logits_t, logits_s, 2.0)
assert_true("MO distill kl >= 0", kl >= 0.0)
var bench = mo.benchmark_speed(lambda x: tensor_mean(x), 5)
assert_true("MO bench has avg_ms", "avg_ms" in bench)
assert_gt("MO bench throughput > 0", bench["throughput_per_sec"], 0.0)

# ── StreamingProcessor ─────────────────────────────────────────────────────
var sp = StreamingProcessor(8, 4)
assert_eq("SP name", sp.get_name(), "StreamingProcessor")
var stream_data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
var windows = sp.ingest(stream_data)
assert_gt("SP processed windows >= 1", len(windows), 0)
assert_true("SP window has mean", "mean" in windows[0])
assert_true("SP window has std", "std" in windows[0])
var sp_stats = sp.stats()
assert_eq("SP total ingested", sp_stats["total"], 12)
assert_gt("SP windows counted", sp_stats["windows"], 0)

# ── DataAugmentor ──────────────────────────────────────────────────────────
var da = DataAugmentor("universal")
assert_eq("DA name", da.get_name(), "DataAugmentor")
var orig = tensor_randn([16])
var noisy = da.augment_tensor(orig, ["noise"])
assert_eq("DA noise same size", len(noisy), 16)
var normalized = da.augment_tensor(orig, ["normalize"])
assert_eq("DA norm same size", len(normalized), 16)
var text_aug = da.augment_text("Hello World NyTorch", ["lowercase"])
assert_eq("DA text lower", text_aug, "hello world nytorch")
var batch_in = [orig, tensor_randn([16]), tensor_randn([16])]
var batch_out = da.batch_augment(batch_in, ["noise"], 1)
assert_eq("DA batch size doubles", len(batch_out), 6)

# ── ExperimentTracker ──────────────────────────────────────────────────────
var et = ExperimentTracker("NyTorch_Experiment", "/tmp")
assert_eq("ET name", et.get_name(), "ExperimentTracker")
et.start_run("run_001", {"lr": 0.001, "epochs": 10, "batch_size": 32})
assert_true("ET current run set", et.current_run != none)
et.log_metric("loss", 1.5, 0)
et.log_metric("loss", 1.2, 1)
et.log_metric("loss", 0.9, 2)
et.log_metric("accuracy", 0.7, 2)
assert_eq("ET loss metrics count", len(et.current_run["metrics"]["loss"]), 3)
var art_ok = et.log_artifact("config", {"lr": 0.001})
assert_true("ET artifact logged", art_ok)
et.end_run("finished")
assert_eq("ET run complete", et.current_run, none)
assert_eq("ET best run", et.best_run, "run_001")
var comparison = et.compare_runs("loss")
assert_eq("ET compare has 1 run", len(comparison), 1)

# ── ModelDeployment ────────────────────────────────────────────────────────
var md = ModelDeployment("NyTorchModel", "v1.0")
assert_eq("MD name", md.get_name(), "ModelDeployment")
var ep = md.register_model(lambda x: tensor_mean(x if type(x) == "list" or type(x) == "tensor" else tensor_randn([4])), {"input": "tensor"}, {"output": "float"})
assert_eq("MD endpoint", ep, "/predict")
var health = md.handle_request("/health", {})
assert_eq("MD health status", health["status"], "ok")
assert_eq("MD health model", health["model"], "NyTorchModel")
var pred = md.handle_request("/predict", tensor_randn([4]))
assert_true("MD predict not none", pred != none)
assert_eq("MD n_requests", md.n_requests, 2)
var config_json = md.export_config()
assert_true("MD config is json", string_contains(config_json, "NyTorchModel"))

# ── MultimodalAI ───────────────────────────────────────────────────────────
var mmai = MultimodalAI(32)
assert_eq("MMAI name", mmai.get_name(), "MultimodalAI")
var text_emb = mmai.encode("deep learning neural network", "text")
assert_eq("MMAI text emb dim", len(text_emb), 32)
var img_emb = mmai.encode(tensor_randn([16]), "image")
assert_eq("MMAI img emb dim", len(img_emb), 32)
var audio_emb = mmai.encode(tensor_randn([8]), "audio")
assert_eq("MMAI audio emb dim", len(audio_emb), 32)
var fused = mmai.fuse([text_emb, img_emb], [0.6, 0.4])
assert_eq("MMAI fused dim", len(fused), 32)
var answer = mmai.answer("What is NyTorch?", [text_emb, img_emb], none)
assert_true("MMAI answer not none", answer != none)

# ── FederatedLearner ───────────────────────────────────────────────────────
var fl = FederatedLearner(4, 16)
assert_eq("FL name", fl.get_name(), "FederatedLearner")
assert_eq("FL n_clients", fl.n_clients, 4)
assert_eq("FL global model dim", len(fl.global_model), 16)
var local_data = [[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6]]
fl.client_update(0, local_data, 2, 0.01)
fl.client_update(1, local_data, 2, 0.01)
var global_model = fl.fedavg([0, 1, 2, 3])
assert_eq("FL global model dim after avg", len(global_model), 16)
assert_eq("FL round incremented", fl.round, 1)
assert_gt("FL agg log", len(fl.aggregation_log), 0)
fl.distribute_global_model()
var noisy = fl.privacy_noise(global_model, 1.0)
assert_eq("FL noisy model dim", len(noisy), 16)

# ── RealTimeInference ──────────────────────────────────────────────────────
var rti = RealTimeInference(lambda x: tensor_mean(x if type(x) == "tensor" else tensor_randn([4])), 100.0)
assert_eq("RTI name", rti.get_name(), "RealTimeInference")
var pred1 = rti.predict(tensor_randn([8]), false)
assert_true("RTI pred has result", "result" in pred1)
assert_true("RTI pred has latency", "latency_ms" in pred1)
assert_true("RTI pred has sla", "within_sla" in pred1)
assert_eq("RTI not from cache", pred1["from_cache"], false)
var pred2 = rti.predict(tensor_randn([8]), true)
var pred3 = rti.predict(tensor_randn([8]), true)
assert_true("RTI avg latency >= 0", rti.avg_latency() >= 0.0)
assert_true("RTI p99 latency >= 0", rti.p99_latency() >= 0.0)
var batch_preds = rti.batch_predict([tensor_randn([4]), tensor_randn([4])], false)
assert_eq("RTI batch size", len(batch_preds), 2)

# ── IntelligentRouter ──────────────────────────────────────────────────────
var ir = IntelligentRouter()
assert_eq("IR name", ir.get_name(), "IntelligentRouter")
ir.add_route("fast_model", lambda x: tensor_mean(tensor_randn([4])), ["text", "classify"], 0.01, 5.0)
ir.add_route("smart_model", lambda x: tensor_norm(tensor_randn([8])), ["text", "generate", "analyze"], 0.05, 50.0)
ir.add_route("cheap_model", lambda x: 0.0, ["classify"], 0.001, 100.0)
var routed = ir.route("text", "Hello world", "speed")
assert_true("IR routed has result", "result" in routed)
assert_true("IR routed has route", "route" in routed)
assert_true("IR routed has latency", "latency_ms" in routed)
var slow_routed = ir.route("analyze", "code analysis task", "cost")
assert_true("IR cost route", slow_routed["route"] != "")
var usage = ir.get_usage_report()
assert_eq("IR routes count", usage["routes"], 3)
assert_gt("IR total calls > 0", usage["total_calls"], 0)

# ── NyTorchAGI ─────────────────────────────────────────────────────────────
var agi = NyTorchAGI({"embed_dim": 16, "name": "TestAGI", "memory_capacity": 100})
assert_eq("AGI name", agi.get_name(), "NyTorchAGI")
assert_eq("AGI agent name", agi.agent_name, "TestAGI")
assert_eq("AGI embed dim", agi.embed_dim, 16)
var status = agi.status()
assert_eq("AGI status name", status["name"], "TestAGI")
assert_true("AGI has device", "device" in status)
assert_true("AGI has capabilities", "capabilities" in status)
assert_gt("AGI n_capabilities", len(status["capabilities"]), 5)
var learn_result = agi.learn("/tmp/test_doc.txt", "file")
assert_eq("AGI learn status", learn_result["status"], "learned")
var think_result = agi.think("deep learning GPU")
assert_true("AGI think has query", "query" in think_result)
assert_true("AGI think has results", "results" in think_result)
assert_true("AGI think has language", "language" in think_result)
var translate_action = agi.act("translate", {"text": "deep learning model", "target_lang": "fr"})
assert_eq("AGI translate status", translate_action["action"], "translate")
assert_true("AGI translate has result", translate_action["result"] != none)
var code_action = agi.act("generate_code", {"description": "sort a list of numbers"})
assert_eq("AGI code action", code_action["action"], "generate_code")
var sentiment_action = agi.act("sentiment", {"text": "NyTorch is amazing and brilliant!"})
assert_eq("AGI sentiment action", sentiment_action["action"], "sentiment")
var replicate_action = agi.act("replicate", {})
assert_eq("AGI replicate action", replicate_action["action"], "replicate")
assert_true("AGI replicate child", "child_id" in replicate_action["result"])
var converse_result = agi.converse("What is deep learning?", none)
assert_true("AGI converse has reply", "reply" in converse_result)
assert_true("AGI converse has thought", "thought" in converse_result)
var final_status = agi.status()
assert_gt("AGI tasks done > 0", final_status["tasks_done"], 0)
assert_gt("AGI episodes > 0", final_status["episodes"], 0)

print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NYTORCH17 TESTS PASSED ==="
else:
    print "=== SOME TESTS FAILED ==="

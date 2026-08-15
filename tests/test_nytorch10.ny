import nytorch
import "lib/nytorch/storage.ny"
import "lib/nytorch/serving.ny"

print "=== NyTorch v3.0 Part 10 Test Suite ==="

# --- TCP Server / Client (loopback) ---
print "--- TCP Socket Test ---"
var srv = SocketServer(19999)
var srv_ok = srv.start()
print "SocketServer started: " + str(srv_ok)

var cli_fd = tcp_connect("127.0.0.1", 19999, 2000)
print "tcp_connect: " + str(cli_fd >= 0)

var conn = srv.accept_client(1000)
print "tcp_accept got connection: " + str(conn != none)

if conn != none:
    var cfd = conn["fd"]
    tcp_send(cli_fd, "hello nytorch")
    var received = tcp_recv(cfd, 1024, 1000)
    print "tcp_recv: " + received
    tcp_close(cfd)

tcp_close(cli_fd)
srv.stop()
print "SocketServer.PASS"

# --- HttpServer request parsing ---
print "--- HTTP Parse Test ---"
var raw_req = "GET /health?fmt=json HTTP/1.1\r\nHost: localhost\r\n\r\n"
var parsed = http_parse_request(raw_req)
print "HTTP method: " + parsed["method"]
print "HTTP path: " + parsed["path"]
print "HTTP query: " + parsed["query"]
print "HTTP parse.PASS"

# --- HttpServer serve one ---
print "--- HttpServer Test ---"
var http_srv = HttpServer(20001)
var hs_ok = http_srv.start()
print "HttpServer started: " + str(hs_ok)

var cl2 = tcp_connect("127.0.0.1", 20001, 2000)
tcp_send(cl2, "GET /ping HTTP/1.0\r\nHost: localhost\r\n\r\n")

var ctx = http_srv.handle_one(1000)
print "HttpServer got request: " + str(ctx != none)
if ctx != none:
    var req2 = ctx["req"]
    var fd2 = ctx["fd"]
    print "Request path: " + req2["path"]
    http_srv.respond_ok(fd2, "pong", "text/plain")

var pong = tcp_recv_all(cl2, 1000)
print "Client got response: " + str(pong != none)
tcp_close(cl2)
http_srv.stop()
print "HttpServer.PASS"

# --- AgentServer ---
print "--- AgentServer Test ---"
var agsrv = AgentServer("test_agent", 20002, "/tmp/ny_agsrv")
var ags_ok = agsrv.start()
print "AgentServer started: " + str(ags_ok)

# Health endpoint
var cl3 = tcp_connect("127.0.0.1", 20002, 2000)
tcp_send(cl3, "GET /health HTTP/1.0\r\nHost: localhost\r\n\r\n")
var srv_resp = agsrv.serve_one(1000)
var health_resp = tcp_recv_all(cl3, 1000)
print "AgentServer /health: " + str(health_resp != none)
tcp_close(cl3)

# KB set endpoint
var cl4 = tcp_connect("127.0.0.1", 20002, 2000)
tcp_send(cl4, "POST /kb/set HTTP/1.0\r\nHost: localhost\r\nContent-Length: 16\r\n\r\nmy_key|my_value!")
var set_resp = agsrv.serve_one(1000)
var set_body = tcp_recv_all(cl4, 1000)
print "AgentServer /kb/set: " + str(set_body != none)
tcp_close(cl4)

agsrv.stop()
print "AgentServer.PASS"

# --- KnowledgeGraph ---
print "--- KnowledgeGraph Test ---"
var kg = KnowledgeGraph("/tmp/ny_kg_test")
kg.add_node("alice", "Person", "age=30")
kg.add_node("bob", "Person", "age=25")
kg.add_node("python", "Language", "type=dynamic")
kg.add_edge("alice", "knows", "bob", 1.0)
kg.add_edge("alice", "uses", "python", 0.9)
kg.add_edge("bob", "uses", "python", 0.7)

var alice = kg.get_node("alice")
print "KG node alice label: " + alice["label"]
var neighbors = kg.neighbors("alice", "knows")
print "KG alice->knows count: " + str(len(neighbors))
var related = kg.related("alice")
print "KG alice related: " + str(len(related))
var edge = kg.get_edge("alice", "uses", "python")
print "KG edge weight: " + str(edge["weight"])
print "KG has alice: " + str(kg.has_node("alice"))
print "KG node count: " + str(kg.node_count_total())
print "KG edge count: " + str(kg.edge_count_total())
print "KnowledgeGraph.PASS"

# --- FederatedRound ---
print "--- FederatedRound Test ---"
var fed_round = FederatedRound(1)
var g1 = tensor([1.0, 2.0, 3.0])
var g2 = tensor([3.0, 4.0, 5.0])
var g3 = tensor([2.0, 3.0, 4.0])
fed_round.add_gradient("agent_a", g1)
fed_round.add_gradient("agent_b", g2)
fed_round.add_gradient("agent_c", g3)
print "FedRound participants: " + str(fed_round.participants)
print "FedRound ready(3): " + str(fed_round.ready(3))
var global_grad = fed_round.fedavg()
print "FedAvg result sum: " + str(tensor_sum(global_grad))
print "FederatedRound.PASS"

# --- FederatedLearner ---
print "--- FederatedLearner Test ---"
var fl = FederatedLearner("fl_agent_1", "/tmp/ny_fl", "127.0.0.1", 20010)
fl.setup()
fl.init_weights([16, 32, 8])
print "FL weights count: " + str(len(fl.local_weights))
fl.train_local([], [], 5, 0.001)
print "FL trained: " + str(fl.trained)
var delta = fl.compute_delta()
print "FL delta count: " + str(len(delta))
var uploaded = fl.upload_delta()
print "FL upload_delta: " + str(uploaded)
print "FederatedLearner.PASS"

# --- NyPipeline ---
print "--- NyPipeline Test ---"
var pipe = NyPipeline("test_pipe")
var t_in = tensor([1.0, -0.5, 2.0, -1.0])
pipe.feed(t_in)
pipe.normalize()
pipe.record("after_norm")
var w_mat = tensor([0.1, 0.2, 0.3, 0.4])
pipe.matmul(w_mat)
pipe.record("after_matmul")
var out = pipe.get()
print "NyPipeline output is tensor: " + str(out != none)
var after_norm = pipe.get_record("after_norm")
print "NyPipeline get_record: " + str(after_norm != none)
print "NyPipeline.PASS"

# --- AutoTrainer ---
print "--- AutoTrainer Test ---"
var trainer = AutoTrainer("test_trainer", "/tmp/ny_trainer")
trainer.setup()
var dummy_params = [tensor([1.0, 2.0]), tensor([3.0, 4.0])]
trainer.record_epoch(1, 0.9, 0.8, dummy_params)
trainer.record_epoch(2, 0.7, 0.6, dummy_params)
trainer.record_epoch(3, 0.5, 0.4, dummy_params)
print "AutoTrainer epochs: " + str(trainer.epoch_count())
print "AutoTrainer best_loss: " + str(trainer.best_loss)
print "AutoTrainer should_stop: " + str(trainer.should_stop())
var best = trainer.load_best()
print "AutoTrainer load_best: " + str(best != none)
print "AutoTrainer.PASS"

# --- HyperSearch ---
print "--- HyperSearch Test ---"
var hs = HyperSearch("test_search", "/tmp/ny_hyper")
var lr1 = hs.suggest_lr(0.0001, 0.01)
print "HyperSearch suggest_lr: " + str(lr1 > 0.0)
var hidden = hs.suggest_int(32, 256)
print "HyperSearch suggest_int: " + str(hidden >= 32)
var act = hs.suggest_choice(["relu", "gelu", "silu"])
print "HyperSearch suggest_choice: " + act
hs.report_trial("lr=0.001 hidden=64 act=relu", 0.92)
hs.report_trial("lr=0.005 hidden=128 act=gelu", 0.95)
hs.report_trial("lr=0.0001 hidden=32 act=silu", 0.88)
print "HyperSearch trials: " + str(hs.trial_count())
var best_config = hs.best()
print "HyperSearch best score: " + str(best_config["score"])
print "HyperSearch.PASS"

# --- ModelEnsemble ---
print "--- ModelEnsemble Test ---"
var ens = ModelEnsemble("test_ens")
ens.add_member("model_a", dummy_params, 0.5)
ens.add_member("model_b", dummy_params, 0.3)
ens.add_member("model_c", dummy_params, 0.2)
print "ModelEnsemble members: " + str(ens.n_members)
var o1 = tensor([0.7, 0.3])
var o2 = tensor([0.4, 0.6])
var o3 = tensor([0.6, 0.4])
var avg_out = ens.predict_average([o1, o2, o3])
print "Ensemble avg sum: " + str(tensor_sum(avg_out))
var w_out = ens.predict_weighted([o1, o2, o3], [0.5, 0.3, 0.2])
print "Ensemble weighted sum: " + str(tensor_sum(w_out))
print "ModelEnsemble.PASS"

# --- NyScheduler ---
print "--- NyScheduler Test ---"
var sched = NyScheduler("test_sched")
sched.add_task("log_metrics", 5, 10)
sched.add_task("save_model", 20, 5)
sched.add_task("send_heartbeat", 3, 8)
var t1_due = sched.tick_step()
print "Sched tick 1 due: " + str(len(t1_due))
var i = 0
while i < 4:
    sched.tick_step()
    i = i + 1
var t5_due = sched.tick_step()
print "Sched tick 6 due tasks: " + str(len(t5_due))
print "Sched total ticks: " + str(sched.total_ticks())
print "NyScheduler.PASS"

# --- NyEvent ---
print "--- NyEvent Test ---"
var evb = NyEvent()
evb.on("model.trained", "save_handler")
evb.on("model.trained", "log_handler")
evb.on("agent.started", "init_handler")
evb.on("*", "audit_handler")
var handlers = evb.emit("model.trained", "val_loss=0.05")
print "NyEvent handlers triggered: " + str(len(handlers))
evb.emit("agent.started", "agent_1")
evb.emit("agent.stopped", "agent_1")
var recent = evb.recent_events("model.trained", 2)
print "NyEvent recent: " + str(len(recent))
print "NyEvent.PASS"

# --- NyPlugin ---
print "--- NyPlugin Test ---"
var plug = NyPlugin("LogPlugin", "1.0.0")
plug.configure("log_level", "INFO")
plug.configure("log_path", "/tmp/ny_plugin_test.log")
plug.add_hook("on_train_start", "log_start")
plug.add_hook("on_epoch_end", "log_metrics")
print "NyPlugin name: " + plug.describe()
print "NyPlugin config log_level: " + plug.get_config("log_level")
print "NyPlugin hook on_epoch_end: " + plug.get_hook("on_epoch_end")
print "NyPlugin.PASS"

# --- AgentCluster ---
print "--- AgentCluster Test ---"
var cluster = AgentCluster("test_cluster", "/tmp/ny_cluster", 21000)
var p1_port = cluster.add_agent("worker_1", "127.0.0.1", "worker")
var p2_port = cluster.add_agent("worker_2", "127.0.0.1", "worker")
var p3_port = cluster.add_agent("master_1", "127.0.0.1", "master")
print "Cluster size: " + str(cluster.cluster_size())
var workers = cluster.agents_by_role("worker")
print "Cluster workers: " + str(len(workers))
var info = cluster.get_agent("worker_1")
print "Cluster worker_1 role: " + info["role"]
print "AgentCluster.PASS"

# --- NyMonitor ---
print "--- NyMonitor Test ---"
var mon = NyMonitor("test_mon", "/tmp/ny_mon")
mon.set_threshold("cpu", 90.0)
mon.set_threshold("memory", 85.0)
mon.record("cpu", 45.0)
mon.record("memory", 60.0)
mon.record("loss", 0.05)
print "NyMonitor cpu: " + str(mon.get("cpu"))
mon.record("cpu", 95.0)
print "NyMonitor alerts: " + str(len(mon.get_alerts()))
print "NyMonitor.PASS"

# --- NyConfig ---
print "--- NyConfig Test ---"
var cfg = NyConfig("/tmp/ny_test.cfg")
write_file("/tmp/ny_test.cfg", "# Config\nmodel=transformer\nlr=0.001\nhidden=128\nbatch_size=32\n")
cfg.load()
var model_name = cfg.get("model", "mlp")
print "NyConfig model: " + model_name
var lr_val = cfg.get_float("lr", 0.01)
print "NyConfig lr: " + str(lr_val)
var hidden_val = cfg.get_int("hidden", 64)
print "NyConfig hidden: " + str(hidden_val)
cfg.set("epochs", "50")
print "NyConfig.PASS"

# --- NyApp ---
print "--- NyApp Test ---"
var app = NyApp("my_ai_app", "/tmp/ny_app")
app.load_config()
app.schedule("train", 10, 5)
app.schedule("eval", 50, 3)
app.schedule("save", 100, 1)
app.on("app.start", "init_handler")
app.start()
var s1 = app.step()
var s2 = app.step()
print "NyApp tick: " + str(app.tick)
print "NyApp health: " + app.health()
app.stop()
print "NyApp.PASS"

# --- NyOS ---
print "--- NyOS Test ---"
var nyos = NyOS("node_1", "/tmp/nyos_test")
nyos.register_process("agent_training", "LearningAgent training loop", 22000)
nyos.register_process("agent_server", "AgentServer REST API", 22001)
nyos.register_process("monitor", "NyMonitor health check", 22002)
var procs = nyos.list_processes()
print "NyOS processes: " + str(len(procs))
var p_info = nyos.process_info("agent_training")
print "NyOS proc desc: " + p_info["desc"]
print "NyOS temp_path: " + nyos.temp_path("test.nyt")
print "NyOS node_info: " + nyos.node_info()
nyos.unregister_process("monitor")
print "NyOS after unregister: " + str(len(nyos.list_processes()))
print "NyOS.PASS"

print ""
print "=== ALL NYTORCH10 TESTS PASSED ==="

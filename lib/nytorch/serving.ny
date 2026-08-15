# ============================================================
# NyTorch v3.0 -- Part 10: Servers, Federated AI, NyApp
# ============================================================
# Classes 139-163:
#   SocketServer, HttpRouter, HttpServer, AgentServer,
#   AgentHttpClient, KnowledgeGraph, FederatedRound,
#   FederatedLearner, ConsensusVoter, GradientSharer,
#   NyPipeline, AutoTrainer, HyperSearch,
#   ModelEnsemble, NyScheduler, NyEvent, NyPlugin,
#   AgentCluster, NyMonitor, NyConfig,
#   NyApp, NyWorld, NyOS
# ============================================================

import nytorch

# -----------------------------------------
# 139. SocketServer  (TCP accept loop)
# -----------------------------------------
class SocketServer:
    def __init__(self, port):
        self.port = port
        self.fd = -1
        self.running = false
        self.connections = 0

    def start(self):
        self.fd = tcp_server_create(self.port)
        if self.fd >= 0:
            self.running = true
        return self.fd >= 0

    def accept_client(self, timeout_ms):
        return tcp_accept(self.fd, timeout_ms)

    def send_to(self, client_fd, data):
        return tcp_send(client_fd, data)

    def recv_from(self, client_fd, max_bytes, timeout_ms):
        return tcp_recv(client_fd, max_bytes, timeout_ms)

    def recv_all(self, client_fd, timeout_ms):
        return tcp_recv_all(client_fd, timeout_ms)

    def close_client(self, client_fd):
        return tcp_close(client_fd)

    def stop(self):
        if self.fd >= 0:
            tcp_close(self.fd)
            self.fd = -1
        self.running = false
        return self

    def is_running(self):
        return self.running

# -----------------------------------------
# 140. HttpRouter
# -----------------------------------------
class HttpRouter:
    def __init__(self):
        self.routes = []
        self.not_found_body = "404 Not Found"

    def add(self, method, path, handler_name):
        self.routes = self.routes + [{"method": method, "path": path, "handler": handler_name}]
        return self

    def get(self, path, handler_name):
        return self.add("GET", path, handler_name)

    def post(self, path, handler_name):
        return self.add("POST", path, handler_name)

    def match(self, method, path):
        var i = 0
        var n = len(self.routes)
        while i < n:
            var r = self.routes[i]
            if r["method"] == method:
                if r["path"] == path:
                    return r["handler"]
                if r["path"] == "*":
                    return r["handler"]
            var i = i + 1
        return none

    def set_404(self, body):
        self.not_found_body = body
        return self

# -----------------------------------------
# 141. HttpServer  (single-threaded HTTP)
# -----------------------------------------
class HttpServer:
    def __init__(self, port):
        self.port = port
        self.server = SocketServer(port)
        self.router = HttpRouter()
        self.running = false
        self.requests_handled = 0
        self.logger = none

    def set_logger(self, logger):
        self.logger = logger
        return self

    def route(self, method, path, handler):
        self.router.add(method, path, handler)
        return self

    def start(self):
        var ok = self.server.start()
        if ok:
            self.running = true
        return ok

    def stop(self):
        self.server.stop()
        self.running = false
        return self

    def handle_one(self, timeout_ms):
        var conn = self.server.accept_client(timeout_ms)
        if conn == none:
            return none
        var cfd = conn["fd"]
        var raw = self.server.recv_all(cfd, 2000)
        if raw == none:
            tcp_close(cfd)
            return none
        var req = http_parse_request(raw)
        self.requests_handled = self.requests_handled + 1
        return {"fd": cfd, "req": req, "from": conn["from"]}

    def respond_ok(self, fd, body, content_type):
        return http_respond(fd, 200, body, content_type)

    def respond_json(self, fd, json_str):
        return http_respond(fd, 200, json_str, "application/json")

    def respond_404(self, fd):
        return http_respond(fd, 404, self.router.not_found_body, "text/plain")

    def respond_500(self, fd, msg):
        return http_respond(fd, 500, msg, "text/plain")

    def total_handled(self):
        return self.requests_handled

# -----------------------------------------
# 142. AgentServer  (AI agent HTTP API)
# -----------------------------------------
class AgentServer:
    def __init__(self, agent_id, port, storage_dir):
        self.agent_id = agent_id
        self.port = port
        self.http = HttpServer(port)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "_srv.kv")
        self.logger = DataLogger(storage_dir + "/logs", agent_id + "_server")
        self.model_store = ModelStore(storage_dir + "/models")
        self.running = false
        self.tick = 0

    def start(self):
        var ok = self.http.start()
        if ok:
            self.running = true
            self.logger.info("AgentServer " + self.agent_id + " on port " + str(self.port))
        return ok

    def stop(self):
        self.http.stop()
        self.running = false
        return self

    def serve_one(self, timeout_ms):
        var ctx = self.http.handle_one(timeout_ms)
        if ctx == none:
            return none
        self.tick = self.tick + 1
        var req = ctx["req"]
        var fd = ctx["fd"]
        var path = req["path"]
        var method = req["method"]
        var body = req["body"]

        # Built-in REST endpoints
        if path == "/health":
            var resp = "{\"status\":\"ok\",\"agent\":\"" + self.agent_id + "\",\"tick\":" + str(self.tick) + "}"
            self.http.respond_json(fd, resp)
            return {"path": path, "handled": true}

        if path == "/kb/get":
            var key = body
            var val = self.kb.recall(key)
            if val == none:
                var val = ""
            self.http.respond_json(fd, "{\"key\":\"" + key + "\",\"value\":\"" + val + "\"}")
            return {"path": path, "handled": true}

        if path == "/kb/set":
            var parts = body.split("|")
            if len(parts) >= 2:
                self.kb.remember(parts[0], parts[1])
            self.http.respond_json(fd, "{\"ok\":true}")
            return {"path": path, "handled": true}

        if path == "/kb/keys":
            var keys = self.kb.all_keys()
            var kstr = "["
            var ki = 0
            var kn = len(keys)
            while ki < kn:
                if ki > 0:
                    var kstr = kstr + ","
                kstr = kstr + "\"" + keys[ki] + "\""
                var ki = ki + 1
            kstr = kstr + "]"
            self.http.respond_json(fd, kstr)
            return {"path": path, "handled": true}

        if path == "/model/list":
            var names = self.model_store.list_all()
            var s = "["
            var mi = 0
            var mn = len(names)
            while mi < mn:
                if mi > 0:
                    var s = s + ","
                s = s + "\"" + names[mi] + "\""
                var mi = mi + 1
            s = s + "]"
            self.http.respond_json(fd, s)
            return {"path": path, "handled": true}

        self.http.respond_404(fd)
        return {"path": path, "handled": false}

    def is_running(self):
        return self.running

# -----------------------------------------
# 143. AgentHttpClient  (call AgentServer)
# -----------------------------------------
class AgentHttpClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.last_status = 0
        self.last_body = ""

    def _call(self, method, path, body):
        var req = method + " " + path + " HTTP/1.0\r\n"
        var req = req + "Host: " + self.host + "\r\n"
        req = req + "Content-Length: " + str(len(body)) + "\r\n"
        req = req + "Connection: close\r\n\r\n" + body
        var loc_host = self.host
        var loc_port = self.port
        var fd = tcp_connect(loc_host, loc_port, 3000)
        if fd < 0:
            self.last_status = -1
            return none
        tcp_send(fd, req)
        var resp = tcp_recv_all(fd, 3000)
        tcp_close(fd)
        if resp == none:
            self.last_status = 0
            return none
        var parsed = http_parse_request(resp)
        self.last_body = parsed["body"]
        return parsed["body"]

    def get(self, path):
        return self._call("GET", path, "")

    def post(self, path, body):
        return self._call("POST", path, body)

    def health(self):
        var r = self.get("/health")
        return r

    def kb_get(self, key):
        return self.post("/kb/get", key)

    def kb_set(self, key, value):
        return self.post("/kb/set", key + "|" + value)

    def kb_keys(self):
        return self.get("/kb/keys")

    def model_list(self):
        return self.get("/model/list")

    def ok(self):
        if self.last_status >= 200:
            if self.last_status < 300:
                return true
        return false

# -----------------------------------------
# 144. KnowledgeGraph
# -----------------------------------------
class KnowledgeGraph:
    def __init__(self, store_path):
        self.nodes_store = store_path + "_nodes.kv"
        self.edges_store = store_path + "_edges.kv"
        self.node_count = 0
        self.edge_count = 0
        fs_mkdirs(path_dirname(store_path))

    def add_node(self, node_id, label, properties):
        var data = label + "|" + properties
        kv_set(self.nodes_store, node_id, data)
        self.node_count = self.node_count + 1
        return self

    def add_edge(self, from_id, relation, to_id, weight):
        var edge_key = from_id + "->" + relation + "->" + to_id
        kv_set(self.edges_store, edge_key, str(weight))
        self.edge_count = self.edge_count + 1
        return self

    def get_node(self, node_id):
        var data = kv_get(self.nodes_store, node_id)
        if data == none:
            return none
        var parts = data.split("|")
        return {"id": node_id, "label": parts[0], "properties": parts[1]}

    def get_edge(self, from_id, relation, to_id):
        var edge_key = from_id + "->" + relation + "->" + to_id
        var w = kv_get(self.edges_store, edge_key)
        if w == none:
            return none
        return {"from": from_id, "relation": relation, "to": to_id, "weight": to_float(w)}

    def neighbors(self, node_id, relation):
        var all_edges = kv_keys(self.edges_store)
        var prefix = node_id + "->" + relation + "->"
        var result = []
        var i = 0
        var n = len(all_edges)
        while i < n:
            var e = all_edges[i]
            var plen = len(prefix)
            if len(e) > plen:
                if e[:plen] == prefix:
                    var result = result + [e[plen:]]
            var i = i + 1
        return result

    def related(self, node_id):
        var all_edges = kv_keys(self.edges_store)
        var result = []
        var i = 0
        var n = len(all_edges)
        while i < n:
            var e = all_edges[i]
            if e[:len(node_id)] == node_id:
                var result = result + [e]
            var i = i + 1
        return result

    def has_node(self, node_id):
        var v = kv_get(self.nodes_store, node_id)
        if v == none:
            return false
        return true

    def node_count_total(self):
        var keys = kv_keys(self.nodes_store)
        return len(keys)

    def edge_count_total(self):
        var keys = kv_keys(self.edges_store)
        return len(keys)

# -----------------------------------------
# 145. FederatedRound  (one round of FL)
# -----------------------------------------
class FederatedRound:
    def __init__(self, round_id):
        self.round_id = round_id
        self.contributions = []
        self.aggregated = none
        self.participants = 0

    def add_gradient(self, agent_id, grad_tensor):
        self.contributions = self.contributions + [{"id": agent_id, "grad": grad_tensor}]
        self.participants = self.participants + 1
        return self

    def fedavg(self):
        var n = len(self.contributions)
        if n == 0:
            return none
        var acc = self.contributions[0]["grad"]
        var i = 1
        while i < n:
            var acc = tensor_add(acc, self.contributions[i]["grad"])
            var i = i + 1
        var inv_n = 1.0 / to_float(n)
        self.aggregated = tensor_scale(acc, inv_n)
        return self.aggregated

    def get_global(self):
        return self.aggregated

    def ready(self, min_participants):
        if self.participants >= min_participants:
            return true
        return false

# -----------------------------------------
# 146. FederatedLearner
# -----------------------------------------
class FederatedLearner:
    def __init__(self, agent_id, storage_dir, server_host, server_port):
        self.agent_id = agent_id
        self.server_host = server_host
        self.server_port = server_port
        self.storage = StorageManager(storage_dir + "/" + agent_id)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "/fed.kv")
        self.logger = DataLogger(storage_dir + "/logs", agent_id + "_fl")
        self.local_weights = []
        self.global_weights = []
        self.round = 0
        self.trained = false

    def setup(self):
        self.storage.setup()
        return self

    def init_weights(self, sizes):
        self.local_weights = []
        var i = 0
        var n = len(sizes)
        while i < n:
            self.local_weights = self.local_weights + [tensor_randn([sizes[i]])]
            var i = i + 1
        self.global_weights = self.local_weights
        return self

    def train_local(self, data_tensors, labels, epochs, lr):
        self.trained = true
        self.logger.info("Local training: " + str(len(data_tensors)) + " samples")
        self.round = self.round + 1
        return self

    def compute_delta(self):
        if len(self.local_weights) == 0:
            return none
        var idx = 0
        var n = len(self.local_weights)
        var deltas = []
        while idx < n:
            var lw = self.local_weights[idx]
            if idx < len(self.global_weights):
                var gw = self.global_weights[idx]
                var deltas = deltas + [tensor_sub(lw, gw)]
            else:
                deltas = deltas + [lw]
            var idx = idx + 1
        return deltas

    def upload_delta(self):
        var deltas = self.compute_delta()
        if deltas == none:
            return false
        var loc_store = self.storage
        loc_store.save_model("delta_r" + str(self.round), deltas, "round=" + str(self.round))
        self.kb.remember("last_round", str(self.round))
        self.logger.info("Uploaded delta for round " + str(self.round))
        return true

    def download_global(self, round_id):
        var global_key = "global_r" + str(round_id)
        var exists = self.storage.model_exists(global_key)
        if exists:
            self.global_weights = self.storage.load_model(global_key)
            self.local_weights = self.global_weights
            return true
        return false

    def apply_global(self, global_weights):
        self.global_weights = global_weights
        self.local_weights = global_weights
        return self

# -----------------------------------------
# 147. ConsensusVoter  (distributed voting)
# -----------------------------------------
class ConsensusVoter:
    def __init__(self, agent_id, port):
        self.agent_id = agent_id
        self.port = port
        self.votes = {}
        self.my_vote = none
        self.messenger = AgentMessenger(agent_id, port)

    def cast_vote(self, proposal, value):
        var msg = "vote:" + proposal + "=" + value
        self.my_vote = value
        self.votes[self.agent_id] = value
        self.messenger.broadcast(msg)
        return self

    def collect_votes(self, proposal, timeout_ms, n_expected):
        var collected = 0
        var deadline = time_timestamp() + to_float(timeout_ms) / 1000.0
        while collected < n_expected:
            var ts = time_timestamp()
            if ts > deadline:
                var collected = n_expected
            else:
                var pkt = self.messenger.recv(200)
                if pkt != none:
                    var msg = pkt["msg"]
                    if msg[:5] == "vote:":
                        var content = msg[5:]
                        var eq = 0
                        var j = 0
                        var nc = len(content)
                        while j < nc:
                            if content[j] == "=":
                                var eq = j
                                var j = nc
                            j = j + 1
                        var prop = content[:eq]
                        var val = content[eq + 1:]
                        if prop == proposal:
                            self.votes[pkt["from"]] = val
                            collected = collected + 1
        return self.votes

    def tally(self):
        var counts = {}
        var keys = []
        var i = 0
        while i < len(keys):
            var i = i + 1
        var winner = none
        var best = 0
        var vk = kv_keys("/tmp/nyv_tally_" + self.agent_id + ".kv")
        return winner

    def majority(self, votes_map):
        var counts = {}
        var best_val = none
        var best_count = 0
        var i = 0
        var total = 0
        var vals = []
        return best_val

# -----------------------------------------
# 148. GradientSharer  (p2p gradient sync)
# -----------------------------------------
class GradientSharer:
    def __init__(self, agent_id, port, storage_dir):
        self.agent_id = agent_id
        self.port = port
        self.store = storage_dir + "/" + agent_id + "_grads"
        self.messenger = AgentMessenger(agent_id, port)
        fs_mkdirs(self.store)

    def save_gradient(self, name, grad):
        var p = self.store + "/" + name + ".nyt"
        var loc_grad = grad
        return tensor_save(loc_grad, p)

    def load_gradient(self, name):
        var p = self.store + "/" + name + ".nyt"
        return tensor_load(p)

    def announce(self, grad_name):
        var msg = "grad_available:" + self.agent_id + ":" + grad_name
        return self.messenger.broadcast(msg)

    def request_gradient(self, peer_host, grad_name):
        var msg = "grad_request:" + self.agent_id + ":" + grad_name
        var loc_msg = self.messenger
        return loc_msg.send_to(peer_host, msg)

    def receive_announcement(self, timeout_ms):
        var pkt = self.messenger.recv(timeout_ms)
        if pkt == none:
            return none
        var msg = pkt["msg"]
        if msg[:15] == "grad_available:":
            var content = msg[15:]
            var parts = content.split(":")
            return {"peer": parts[0], "grad_name": parts[1], "ip": pkt["ip"]}
        return none

    def average_gradients(self, g1, g2):
        var sum12 = tensor_add(g1, g2)
        return tensor_scale(sum12, 0.5)

# -----------------------------------------
# 149. NyPipeline  (chainable ML pipeline)
# -----------------------------------------
class NyPipeline:
    def __init__(self, name):
        self.name = name
        self.stages = []
        self.data = none
        self.results = []
        self.errors = []
        self.step_index = 0

    def feed(self, data):
        self.data = data
        return self

    def normalize(self):
        if self.data != none:
            var loc_data = self.data
            self.data = tensor_normalize(loc_data)
        return self

    def embed(self, vocab_size, embed_dim):
        if self.data != none:
            var loc_data = self.data
            self.data = embedding(loc_data, vocab_size, embed_dim)
        return self

    def relu_act(self):
        if self.data != none:
            var loc_data = self.data
            self.data = tensor_apply(loc_data, lambda v: relu(v))
        return self

    def softmax_out(self):
        if self.data != none:
            var loc_data = self.data
            self.data = softmax(loc_data)
        return self

    def matmul(self, weight):
        if self.data != none:
            var loc_data = self.data
            self.data = tensor_matmul(loc_data, weight)
        return self

    def scale(self, factor):
        if self.data != none:
            var loc_data = self.data
            self.data = tensor_scale(loc_data, factor)
        return self

    def save(self, path):
        if self.data != none:
            var loc_data = self.data
            tensor_save(loc_data, path)
        return self

    def record(self, label):
        self.results = self.results + [{"label": label, "data": self.data}]
        return self

    def get(self):
        return self.data

    def get_record(self, label):
        var i = 0
        var n = len(self.results)
        while i < n:
            if self.results[i]["label"] == label:
                return self.results[i]["data"]
            var i = i + 1
        return none

# -----------------------------------------
# 150. AutoTrainer
# -----------------------------------------
class AutoTrainer:
    def __init__(self, name, storage_dir):
        self.name = name
        self.storage = StorageManager(storage_dir + "/" + name)
        self.logger = DataLogger(storage_dir + "/logs", name)
        self.best_loss = 999999.0
        self.best_epoch = 0
        self.history = []
        self.patience = 10
        self.patience_counter = 0
        self.stopped_early = false

    def setup(self):
        self.storage.setup()
        return self

    def record_epoch(self, epoch, train_loss, val_loss, params):
        var entry = {"epoch": epoch, "train_loss": train_loss, "val_loss": val_loss}
        self.history = self.history + [entry]
        self.logger.log_metric("train_loss", train_loss)
        self.logger.log_metric("val_loss", val_loss)
        if val_loss < self.best_loss:
            self.best_loss = val_loss
            self.best_epoch = epoch
            self.patience_counter = 0
            if params != none:
                var loc_store = self.storage
                loc_store.save_model("best", params, "epoch=" + str(epoch) + " val_loss=" + str(val_loss))
        else:
            self.patience_counter = self.patience_counter + 1
        return self

    def should_stop(self):
        if self.patience_counter >= self.patience:
            self.stopped_early = true
            return true
        return false

    def load_best(self):
        var loc_store = self.storage
        return loc_store.load_model("best")

    def best_epoch_info(self):
        return "best_epoch=" + str(self.best_epoch) + " best_val_loss=" + str(self.best_loss)

    def epoch_count(self):
        return len(self.history)

# -----------------------------------------
# 151. HyperSearch  (hyperparameter search)
# -----------------------------------------
class HyperSearch:
    def __init__(self, name, storage_dir):
        self.name = name
        self.kb = KnowledgeBase(storage_dir + "/" + name + "_hyper.kv")
        self.logger = DataLogger(storage_dir + "/logs", name + "_hyper")
        self.trials = []
        self.best_score = -999999.0
        self.best_config = none

    def suggest_lr(self, min_lr, max_lr):
        return random_float(min_lr, max_lr)

    def suggest_int(self, low, high):
        return random_int(low, high)

    def suggest_choice(self, choices):
        var idx = random_int(0, len(choices) - 1)
        return choices[idx]

    def report_trial(self, config_str, score):
        var entry = {"config": config_str, "score": score}
        self.trials = self.trials + [entry]
        self.kb.remember("trial_" + str(len(self.trials)), config_str + "|" + str(score))
        if score > self.best_score:
            self.best_score = score
            self.best_config = config_str
            self.kb.remember("best_config", config_str)
            self.kb.remember("best_score", str(score))
        self.logger.log_metric("trial_score", score)
        return self

    def best(self):
        return {"config": self.best_config, "score": self.best_score}

    def trial_count(self):
        return len(self.trials)

# -----------------------------------------
# 152. ModelEnsemble
# -----------------------------------------
class ModelEnsemble:
    def __init__(self, name):
        self.name = name
        self.members = []
        self.weights_list = []
        self.n_members = 0

    def add_member(self, member_id, model_weights, vote_weight):
        self.members = self.members + [{"id": member_id, "weights": model_weights, "vote": vote_weight}]
        self.weights_list = self.weights_list + [vote_weight]
        self.n_members = self.n_members + 1
        return self

    def predict_average(self, outputs_list):
        var n = len(outputs_list)
        if n == 0:
            return none
        var acc = outputs_list[0]
        var i = 1
        while i < n:
            var acc = tensor_add(acc, outputs_list[i])
            var i = i + 1
        var inv = 1.0 / to_float(n)
        return tensor_scale(acc, inv)

    def predict_weighted(self, outputs_list, vote_weights):
        var n = len(outputs_list)
        if n == 0:
            return none
        var total_w = 0.0
        var acc = tensor_scale(outputs_list[0], vote_weights[0])
        var total_w = total_w + vote_weights[0]
        var i = 1
        while i < n:
            var scaled = tensor_scale(outputs_list[i], vote_weights[i])
            var acc = tensor_add(acc, scaled)
            total_w = total_w + vote_weights[i]
            var i = i + 1
        if total_w > 0.0:
            return tensor_scale(acc, 1.0 / total_w)
        return acc

    def majority_vote(self, predictions_list):
        var n = len(predictions_list)
        if n == 0:
            return -1
        var counts = {}
        var i = 0
        while i < n:
            var p = str(predictions_list[i])
            if counts[p] == none:
                counts[p] = 0
            counts[p] = counts[p] + 1
            var i = i + 1
        return predictions_list[0]

# -----------------------------------------
# 153. NyScheduler  (task scheduling)
# -----------------------------------------
class NyScheduler:
    def __init__(self, name):
        self.name = name
        self.tasks = []
        self.done_tasks = []
        self.tick = 0

    def add_task(self, task_name, interval_ticks, priority):
        self.tasks = self.tasks + [{"name": task_name, "interval": interval_ticks, "priority": priority, "last_run": -1, "runs": 0}]
        return self

    def tick_step(self):
        self.tick = self.tick + 1
        var due = []
        var i = 0
        var n = len(self.tasks)
        while i < n:
            var t = self.tasks[i]
            var last = t["last_run"]
            var iv = t["interval"]
            if last < 0:
                var due = due + [t["name"]]
                self.tasks[i]["last_run"] = self.tick
                self.tasks[i]["runs"] = t["runs"] + 1
            else:
                if self.tick - last >= iv:
                    due = due + [t["name"]]
                    self.tasks[i]["last_run"] = self.tick
                    self.tasks[i]["runs"] = t["runs"] + 1
            var i = i + 1
        return due

    def task_info(self, task_name):
        var i = 0
        var n = len(self.tasks)
        while i < n:
            if self.tasks[i]["name"] == task_name:
                return self.tasks[i]
            var i = i + 1
        return none

    def remove_task(self, task_name):
        var new_tasks = []
        var i = 0
        var n = len(self.tasks)
        while i < n:
            if self.tasks[i]["name"] != task_name:
                var new_tasks = new_tasks + [self.tasks[i]]
            var i = i + 1
        self.tasks = new_tasks
        return self

    def total_ticks(self):
        return self.tick

# -----------------------------------------
# 154. NyEvent  (pub/sub event bus)
# -----------------------------------------
class NyEvent:
    def __init__(self):
        self.listeners = []
        self.history = []
        self.max_history = 100

    def on(self, event_name, handler_tag):
        self.listeners = self.listeners + [{"event": event_name, "handler": handler_tag}]
        return self

    def emit(self, event_name, data):
        var entry = {"event": event_name, "data": data, "ts": time_timestamp()}
        self.history = self.history + [entry]
        var n = len(self.history)
        if n > self.max_history:
            self.history = self.history[1:]
        var handlers = []
        var i = 0
        var nl = len(self.listeners)
        while i < nl:
            if self.listeners[i]["event"] == event_name:
                var handlers = handlers + [self.listeners[i]["handler"]]
            if self.listeners[i]["event"] == "*":
                handlers = handlers + [self.listeners[i]["handler"]]
            var i = i + 1
        return handlers

    def recent_events(self, event_name, k):
        var result = []
        var i = len(self.history) - 1
        var found = 0
        while i >= 0:
            if found >= k:
                var i = -1
            else:
                var e = self.history[i]
                if e["event"] == event_name:
                    var result = result + [e]
                    var found = found + 1
                i = i - 1
        return result

    def listener_count(self, event_name):
        var count = 0
        var i = 0
        var n = len(self.listeners)
        while i < n:
            if self.listeners[i]["event"] == event_name:
                var count = count + 1
            var i = i + 1
        return count

# -----------------------------------------
# 155. NyPlugin  (plugin/module system)
# -----------------------------------------
class NyPlugin:
    def __init__(self, name, version):
        self.name = name
        self.version = version
        self.enabled = true
        self.config = {}
        self.hooks = []
        self.metadata = {}

    def configure(self, key, value):
        self.config[key] = value
        return self

    def get_config(self, key):
        return self.config[key]

    def add_hook(self, hook_name, handler):
        self.hooks = self.hooks + [{"hook": hook_name, "handler": handler}]
        return self

    def get_hook(self, hook_name):
        var i = 0
        var n = len(self.hooks)
        while i < n:
            if self.hooks[i]["hook"] == hook_name:
                return self.hooks[i]["handler"]
            var i = i + 1
        return none

    def enable(self):
        self.enabled = true
        return self

    def disable(self):
        self.enabled = false
        return self

    def describe(self):
        return self.name + "@" + self.version + " [" + str(self.enabled) + "]"

# -----------------------------------------
# 156. AgentCluster  (manage many agents)
# -----------------------------------------
class AgentCluster:
    def __init__(self, name, storage_dir, base_port):
        self.name = name
        self.storage_dir = storage_dir
        self.base_port = base_port
        self.agents = []
        self.registry = AgentRegistry(storage_dir + "/" + name + "_registry.kv")
        self.logger = DataLogger(storage_dir + "/logs", name + "_cluster")
        self.event_bus = NyEvent()

    def add_agent(self, agent_id, host, role):
        var port = self.base_port + len(self.agents)
        self.registry.register(agent_id, host, port, role)
        self.agents = self.agents + [{"id": agent_id, "host": host, "port": port, "role": role}]
        self.logger.info("Added " + role + " agent: " + agent_id)
        return port

    def get_agent(self, agent_id):
        return self.registry.lookup(agent_id)

    def agents_by_role(self, role):
        return self.registry.agents_with_role(role)

    def broadcast_cluster(self, msg):
        var i = 0
        var n = len(self.agents)
        var sent = 0
        while i < n:
            var a = self.agents[i]
            var ok = agent_broadcast(a["port"], msg)
            if ok:
                var sent = sent + 1
            var i = i + 1
        return sent

    def cluster_size(self):
        return len(self.agents)

    def all_agent_ids(self):
        return self.registry.all_agents()

    def ping_agent(self, agent_id):
        var info = self.registry.lookup(agent_id)
        if info == none:
            return false
        var loc_host = info["host"]
        var loc_port = info["port"]
        var fd = tcp_connect(loc_host, loc_port, 1000)
        if fd >= 0:
            tcp_close(fd)
            return true
        return false

# -----------------------------------------
# 157. NyMonitor  (system health monitor)
# -----------------------------------------
class NyMonitor:
    def __init__(self, name, storage_dir):
        self.name = name
        self.metrics_store = storage_dir + "/" + name + "_metrics.kv"
        self.alerts = []
        self.thresholds = {}
        fs_mkdirs(storage_dir)

    def record(self, metric_name, value):
        var ts = str(time_timestamp())
        kv_set(self.metrics_store, metric_name + "_last", str(value))
        kv_set(self.metrics_store, metric_name + "_ts", ts)
        var thr = self.thresholds[metric_name]
        if thr != none:
            if value > to_float(thr):
                var alert = metric_name + " exceeded threshold: " + str(value) + " > " + thr
                self.alerts = self.alerts + [alert]
        return self

    def set_threshold(self, metric_name, threshold):
        self.thresholds[metric_name] = str(threshold)
        return self

    def get(self, metric_name):
        var v = kv_get(self.metrics_store, metric_name + "_last")
        if v == none:
            return 0.0
        return to_float(v)

    def get_alerts(self):
        return self.alerts

    def clear_alerts(self):
        self.alerts = []
        return self

    def all_metrics(self):
        return kv_all(self.metrics_store)

    def report(self):
        var s = "=== Monitor: " + self.name + " ===\n"
        var s = s + "Alerts: " + str(len(self.alerts)) + "\n"
        return s

# -----------------------------------------
# 158. NyConfig  (configuration management)
# -----------------------------------------
class NyConfig:
    def __init__(self, config_path):
        self.config_path = config_path
        self.data = {}
        fs_mkdirs(path_dirname(config_path))

    def load(self):
        var raw = read_file(self.config_path)
        if raw == none:
            return self
        var lines = raw.split("\n")
        var i = 0
        var n = len(lines)
        while i < n:
            var line = lines[i]
            if len(line) > 0:
                if line[0] != "#":
                    var eq = 0
                    var j = 0
                    var nc = len(line)
                    while j < nc:
                        if line[j] == "=":
                            var eq = j
                            var j = nc
                        j = j + 1
                    if eq > 0:
                        self.data[line[:eq].strip()] = line[eq + 1:].strip()
            var i = i + 1
        return self

    def save(self):
        var s = "# NyTorch Config\n"
        var keys = kv_keys(self.config_path + ".kv")
        var i = 0
        while i < len(keys):
            var k = keys[i]
            var s = s + k + "=" + str(self.data[k]) + "\n"
            var i = i + 1
        write_file(self.config_path, s)
        return self

    def get(self, key, default_val):
        var v = self.data[key]
        if v == none:
            return default_val
        return v

    def set(self, key, value):
        self.data[key] = value
        return self

    def get_int(self, key, default_val):
        var v = self.data[key]
        if v == none:
            return default_val
        return to_int(v)

    def get_float(self, key, default_val):
        var v = self.data[key]
        if v == none:
            return default_val
        return to_float(v)

# -----------------------------------------
# 159. NyApp  (full application framework)
# -----------------------------------------
class NyApp:
    def __init__(self, app_name, storage_dir):
        self.app_name = app_name
        self.storage_dir = storage_dir
        self.config = NyConfig(storage_dir + "/" + app_name + ".cfg")
        self.logger = DataLogger(storage_dir + "/logs", app_name)
        self.monitor = NyMonitor(app_name, storage_dir + "/metrics")
        self.scheduler = NyScheduler(app_name)
        self.event_bus = NyEvent()
        self.plugins = []
        self.running = false
        self.tick = 0
        self.start_time = 0.0
        fs_mkdirs(storage_dir)
        fs_mkdirs(storage_dir + "/logs")
        fs_mkdirs(storage_dir + "/metrics")

    def load_config(self):
        self.config.load()
        return self

    def install_plugin(self, plugin):
        self.plugins = self.plugins + [plugin]
        self.logger.info("Plugin installed: " + plugin.name)
        return self

    def schedule(self, task_name, interval_ticks, priority):
        self.scheduler.add_task(task_name, interval_ticks, priority)
        return self

    def on(self, event_name, handler_tag):
        self.event_bus.on(event_name, handler_tag)
        return self

    def emit(self, event_name, data):
        self.logger.debug("event:" + event_name + " " + data)
        return self.event_bus.emit(event_name, data)

    def start(self):
        self.running = true
        self.start_time = time_timestamp()
        self.logger.info("NyApp " + self.app_name + " started")
        self.event_bus.emit("app.start", self.app_name)
        return self

    def step(self):
        self.tick = self.tick + 1
        self.monitor.record("tick", to_float(self.tick))
        var due = self.scheduler.tick_step()
        return due

    def uptime(self):
        return time_timestamp() - self.start_time

    def stop(self):
        self.running = false
        self.logger.info("NyApp " + self.app_name + " stopped after " + str(self.tick) + " ticks")
        self.event_bus.emit("app.stop", self.app_name)
        return self

    def health(self):
        var up = str(self.uptime())
        return self.app_name + " ticks=" + str(self.tick) + " uptime=" + up

# -----------------------------------------
# 160. NyOS  (agent operating primitives)
# -----------------------------------------
class NyOS:
    def __init__(self, node_name, storage_root):
        self.node_name = node_name
        self.storage_root = storage_root
        self.process_store = storage_root + "/nyos_procs.kv"
        self.logger = DataLogger(storage_root + "/logs", "nyos_" + node_name)
        self.started_at = time_timestamp()
        fs_mkdirs(storage_root)
        fs_mkdirs(storage_root + "/logs")
        fs_mkdirs(storage_root + "/tmp")
        fs_mkdirs(storage_root + "/models")
        fs_mkdirs(storage_root + "/data")
        fs_mkdirs(storage_root + "/agents")

    def register_process(self, proc_id, desc, port):
        var info = desc + "|" + str(port) + "|" + str(time_timestamp())
        kv_set(self.process_store, proc_id, info)
        self.logger.info("registered: " + proc_id + " on port " + str(port))
        return self

    def unregister_process(self, proc_id):
        kv_del(self.process_store, proc_id)
        return self

    def list_processes(self):
        return kv_keys(self.process_store)

    def process_info(self, proc_id):
        var data = kv_get(self.process_store, proc_id)
        if data == none:
            return none
        var parts = data.split("|")
        return {"id": proc_id, "desc": parts[0], "port": to_int(parts[1]), "started": parts[2]}

    def temp_path(self, filename):
        return path_join(self.storage_root, "tmp", filename)

    def data_path(self, filename):
        return path_join(self.storage_root, "data", filename)

    def model_path(self, filename):
        return path_join(self.storage_root, "models", filename)

    def agent_path(self, agent_id):
        return path_join(self.storage_root, "agents", agent_id)

    def run_cmd(self, cmd):
        self.logger.info("cmd: " + cmd)
        return shell(cmd)

    def uptime(self):
        return time_timestamp() - self.started_at

    def node_info(self):
        var procs = kv_keys(self.process_store)
        return self.node_name + " procs=" + str(len(procs)) + " uptime=" + str(self.uptime())


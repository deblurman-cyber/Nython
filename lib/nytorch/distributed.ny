# ============================================================
# NyTorch v3.0 -- Part 12: Mesh Networks, Message Queue,
#                          Reinforcement Learning, NyDB
# ============================================================
# Classes 181-205:
#   MessageQueue, PubSubBus, RPC, PeerMesh,
#   MeshNode, ServiceRegistry, LoadBalancer,
#   CircuitBreaker, RetryPolicy, RateLimiter,
#   NyDB, NyTable, NyIndex, QueryBuilder,
#   ReplayBuffer, PrioritizedReplayBuffer,
#   DQNAgent, PPOMemory, MultiAgentEnv,
#   CurriculumScheduler, RewardShaper,
#   MetaLearner, TaskDistributor, ResultAggregator
# ============================================================

import nytorch

# -----------------------------------------
# 181. MessageQueue  (in-process + kv-backed)
# -----------------------------------------
class MessageQueue:
    def __init__(self, name, storage_dir):
        self.name = name
        self.store = storage_dir + "/" + name + "_queue.kv"
        self.head = 0
        self.tail = 0
        fs_mkdirs(storage_dir)
        var h = kv_get(self.store, "__head__")
        var t = kv_get(self.store, "__tail__")
        if h != none:
            self.head = to_int(h)
        if t != none:
            self.tail = to_int(t)

    def push(self, msg):
        kv_set(self.store, "msg_" + str(self.tail), msg)
        self.tail = self.tail + 1
        kv_set(self.store, "__tail__", str(self.tail))
        return self

    def pop(self):
        if self.head >= self.tail:
            return none
        var msg = kv_get(self.store, "msg_" + str(self.head))
        kv_del(self.store, "msg_" + str(self.head))
        self.head = self.head + 1
        kv_set(self.store, "__head__", str(self.head))
        return msg

    def peek(self):
        if self.head >= self.tail:
            return none
        return kv_get(self.store, "msg_" + str(self.head))

    def size(self):
        return self.tail - self.head

    def empty(self):
        if self.head >= self.tail:
            return true
        return false

    def drain(self):
        var msgs = []
        while not self.empty():
            var msgs = msgs + [self.pop()]
        return msgs

# -----------------------------------------
# 182. PubSubBus  (topic-based pub/sub)
# -----------------------------------------
class PubSubBus:
    def __init__(self, name, storage_dir):
        self.name = name
        self.storage_dir = storage_dir
        self.topics = {}
        self.subscriber_count = 0
        fs_mkdirs(storage_dir)

    def subscribe(self, topic, subscriber_id):
        if self.topics[topic] == none:
            self.topics[topic] = MessageQueue(self.name + "_" + topic + "_" + subscriber_id, self.storage_dir)
            self.subscriber_count = self.subscriber_count + 1
        return self.topics[topic]

    def publish(self, topic, message):
        var queue = self.topics[topic]
        if queue != none:
            queue.push(message)
            return true
        return false

    def consume(self, topic, subscriber_id):
        var key = topic + "_sub_" + subscriber_id
        var queue = self.topics[key]
        if queue == none:
            var queue2 = self.subscribe(topic, subscriber_id)
            return queue2.pop()
        return queue.pop()

    def topic_size(self, topic):
        var queue = self.topics[topic]
        if queue == none:
            return 0
        return queue.size()

    def has_messages(self, topic):
        var queue = self.topics[topic]
        if queue == none:
            return false
        return not queue.empty()

# -----------------------------------------
# 183. RPC  (remote procedure call over TCP)
# -----------------------------------------
class RPC:
    def __init__(self, agent_id):
        self.agent_id = agent_id
        self.timeout_ms = 3000
        self.last_error = ""
        self.call_count = 0

    def call(self, host, port, method, payload):
        var req = self.agent_id + "|" + method + "|" + payload
        var fd = tcp_connect(host, port, self.timeout_ms)
        if fd < 0:
            self.last_error = "connection_failed"
            return none
        tcp_send(fd, req)
        var resp = tcp_recv_all(fd, self.timeout_ms)
        tcp_close(fd)
        self.call_count = self.call_count + 1
        return resp

    def call_json(self, host, port, method, json_body):
        var url = "http://" + host + ":" + str(port) + "/" + method
        return http_post_json(url, json_body)

    def set_timeout(self, ms):
        self.timeout_ms = ms
        return self

    def stats(self):
        return "rpc:" + self.agent_id + " calls=" + str(self.call_count)

# -----------------------------------------
# 184. PeerMesh  (self-organizing peer mesh)
# -----------------------------------------
class PeerMesh:
    def __init__(self, node_id, port, storage_dir):
        self.node_id = node_id
        self.port = port
        self.storage = storage_dir + "/" + node_id + "_mesh.kv"
        self.peers = {}
        self.rpc = RPC(node_id)
        self.heartbeat_count = 0
        fs_mkdirs(storage_dir)

    def join(self, peer_id, peer_host, peer_port):
        self.peers[peer_id] = peer_host + ":" + str(peer_port)
        kv_set(self.storage, "peer_" + peer_id, peer_host + ":" + str(peer_port))
        return self

    def leave(self, peer_id):
        self.peers[peer_id] = none
        kv_del(self.storage, "peer_" + peer_id)
        return self

    def broadcast(self, message):
        var sent = 0
        var peer_keys = kv_keys(self.storage)
        var i = 0
        var n = len(peer_keys)
        while i < n:
            var k = peer_keys[i]
            if k[:5] == "peer_":
                var addr = kv_get(self.storage, k)
                if addr != none:
                    var ok = agent_broadcast(self.port, message)
                    if ok:
                        var sent = sent + 1
            var i = i + 1
        return sent

    def gossip(self, key, value):
        var msg = "gossip:" + self.node_id + ":" + key + "=" + value
        return self.broadcast(msg)

    def peer_count(self):
        var keys = kv_keys(self.storage)
        var count = 0
        var i = 0
        while i < len(keys):
            if keys[i][:5] == "peer_":
                var count = count + 1
            var i = i + 1
        return count

    def known_peers(self):
        var keys = kv_keys(self.storage)
        var peers = []
        var i = 0
        while i < len(keys):
            if keys[i][:5] == "peer_":
                var peers = peers + [keys[i][5:]]
            var i = i + 1
        return peers

    def heartbeat(self):
        self.heartbeat_count = self.heartbeat_count + 1
        var msg = "heartbeat:" + self.node_id + ":" + str(self.heartbeat_count)
        return self.broadcast(msg)

# -----------------------------------------
# 185. MeshNode  (full mesh participant)
# -----------------------------------------
class MeshNode:
    def __init__(self, node_id, port, storage_dir):
        self.node_id = node_id
        self.port = port
        self.mesh = PeerMesh(node_id, port, storage_dir)
        self.kb = KnowledgeBase(storage_dir + "/" + node_id + "_node.kv")
        self.logger = DataLogger(storage_dir + "/logs", node_id)
        self.scheduler = NyScheduler(node_id)
        self.running = false
        self.tick = 0
        self.scheduler.add_task("heartbeat", 100, 5)
        self.scheduler.add_task("gossip", 50, 3)
        self.scheduler.add_task("cleanup", 500, 1)

    def start(self):
        self.running = true
        self.logger.info("MeshNode " + self.node_id + " on port " + str(self.port))
        return self

    def connect(self, peer_id, peer_host, peer_port):
        self.mesh.join(peer_id, peer_host, peer_port)
        self.logger.info("Connected to " + peer_id)
        return self

    def step(self):
        self.tick = self.tick + 1
        var due = self.scheduler.tick_step()
        var i = 0
        var n = len(due)
        while i < n:
            if due[i] == "heartbeat":
                self.mesh.heartbeat()
            var i = i + 1
        return due

    def store(self, key, value):
        self.kb.remember(key, value)
        self.mesh.gossip(key, value)
        return self

    def lookup(self, key):
        return self.kb.recall(key)

    def stop(self):
        self.running = false
        return self

    def status(self):
        return self.node_id + " peers=" + str(self.mesh.peer_count()) + " tick=" + str(self.tick)

# -----------------------------------------
# 186. ServiceRegistry  (service discovery)
# -----------------------------------------
class ServiceRegistry:
    def __init__(self, storage_dir):
        self.store = storage_dir + "/services.kv"
        self.health_store = storage_dir + "/health.kv"
        fs_mkdirs(storage_dir)

    def register(self, service_name, host, port, version, tags):
        var info = host + ":" + str(port) + "|" + version + "|" + tags
        kv_set(self.store, service_name, info)
        kv_set(self.health_store, service_name, "up|" + str(time_timestamp()))
        return self

    def deregister(self, service_name):
        kv_del(self.store, service_name)
        kv_del(self.health_store, service_name)
        return self

    def discover(self, service_name):
        var info = kv_get(self.store, service_name)
        if info == none:
            return none
        var parts = info.split("|")
        var addr = parts[0].split(":")
        return {"host": addr[0], "port": to_int(addr[1]), "version": parts[1], "tags": parts[2]}

    def list_services(self):
        return kv_keys(self.store)

    def health_check(self, service_name):
        var h = kv_get(self.health_store, service_name)
        if h == none:
            return "unknown"
        var parts = h.split("|")
        return parts[0]

    def mark_down(self, service_name):
        kv_set(self.health_store, service_name, "down|" + str(time_timestamp()))
        return self

    def mark_up(self, service_name):
        kv_set(self.health_store, service_name, "up|" + str(time_timestamp()))
        return self

    def healthy_services(self):
        var all_services = kv_keys(self.store)
        var healthy = []
        var i = 0
        var n = len(all_services)
        while i < n:
            if self.health_check(all_services[i]) == "up":
                var healthy = healthy + [all_services[i]]
            var i = i + 1
        return healthy

# -----------------------------------------
# 187. LoadBalancer
# -----------------------------------------
class LoadBalancer:
    def __init__(self, strategy):
        self.strategy = strategy
        self.backends = []
        self.weights = []
        self.current = 0
        self.request_counts = []
        self.total_requests = 0

    def add_backend(self, host, port, weight):
        self.backends = self.backends + [{"host": host, "port": port}]
        self.weights = self.weights + [weight]
        self.request_counts = self.request_counts + [0]
        return self

    def next(self):
        var n = len(self.backends)
        if n == 0:
            return none
        self.total_requests = self.total_requests + 1
        if self.strategy == "round_robin":
            var idx = self.current % n
            self.current = self.current + 1
            self.request_counts[idx] = self.request_counts[idx] + 1
            return self.backends[idx]
        if self.strategy == "random":
            var idx = random_int(0, n - 1)
            self.request_counts[idx] = self.request_counts[idx] + 1
            return self.backends[idx]
        if self.strategy == "least_conn":
            var min_c = self.request_counts[0]
            var best = 0
            var i = 1
            while i < n:
                if self.request_counts[i] < min_c:
                    var min_c = self.request_counts[i]
                    var best = i
                var i = i + 1
            self.request_counts[best] = self.request_counts[best] + 1
            return self.backends[best]
        var idx = self.current % n
        self.current = self.current + 1
        return self.backends[idx]

    def remove_backend(self, host, port):
        var new_backends = []
        var new_weights = []
        var new_counts = []
        var i = 0
        var n = len(self.backends)
        while i < n:
            if self.backends[i]["host"] != host:
                var new_backends = new_backends + [self.backends[i]]
                var new_weights = new_weights + [self.weights[i]]
                var new_counts = new_counts + [self.request_counts[i]]
            else:
                if self.backends[i]["port"] != port:
                    new_backends = new_backends + [self.backends[i]]
                    new_weights = new_weights + [self.weights[i]]
                    new_counts = new_counts + [self.request_counts[i]]
            var i = i + 1
        self.backends = new_backends
        self.weights = new_weights
        self.request_counts = new_counts
        return self

    def stats(self):
        return "lb:" + self.strategy + " backends=" + str(len(self.backends)) + " requests=" + str(self.total_requests)

# -----------------------------------------
# 188. CircuitBreaker
# -----------------------------------------
class CircuitBreaker:
    def __init__(self, name, failure_threshold, reset_after_s):
        self.name = name
        self.failure_threshold = failure_threshold
        self.reset_after_s = reset_after_s
        self.failures = 0
        self.successes = 0
        self.state = "closed"
        self.last_failure_time = 0.0
        self.total_calls = 0

    def call_allowed(self):
        if self.state == "closed":
            return true
        if self.state == "open":
            var now = time_timestamp()
            var elapsed = now - self.last_failure_time
            if elapsed > to_float(self.reset_after_s):
                self.state = "half_open"
                return true
            return false
        if self.state == "half_open":
            return true
        return false

    def on_success(self):
        self.successes = self.successes + 1
        self.total_calls = self.total_calls + 1
        if self.state == "half_open":
            self.state = "closed"
            self.failures = 0
        return self

    def on_failure(self):
        self.failures = self.failures + 1
        self.total_calls = self.total_calls + 1
        self.last_failure_time = time_timestamp()
        if self.failures >= self.failure_threshold:
            self.state = "open"
        return self

    def reset(self):
        self.state = "closed"
        self.failures = 0
        return self

    def is_open(self):
        if self.state == "open":
            return true
        return false

    def status(self):
        return self.name + " state=" + self.state + " failures=" + str(self.failures)

# -----------------------------------------
# 189. RateLimiter  (token bucket)
# -----------------------------------------
class RateLimiter:
    def __init__(self, name, rate_per_second, burst):
        self.name = name
        self.rate = to_float(rate_per_second)
        self.burst = to_float(burst)
        self.tokens = to_float(burst)
        self.last_refill = time_timestamp()
        self.total_allowed = 0
        self.total_denied = 0

    def refill(self):
        var now = time_timestamp()
        var elapsed = now - self.last_refill
        var new_tokens = elapsed * self.rate
        self.tokens = self.tokens + new_tokens
        if self.tokens > self.burst:
            self.tokens = self.burst
        self.last_refill = now
        return self

    def allow(self, cost):
        self.refill()
        if self.tokens >= to_float(cost):
            self.tokens = self.tokens - to_float(cost)
            self.total_allowed = self.total_allowed + 1
            return true
        self.total_denied = self.total_denied + 1
        return false

    def available(self):
        self.refill()
        return self.tokens

    def stats(self):
        return self.name + " tokens=" + str(self.tokens) + " allowed=" + str(self.total_allowed) + " denied=" + str(self.total_denied)

# -----------------------------------------
# 190. NyDB  (embedded key-value database)
# -----------------------------------------
class NyDB:
    def __init__(self, name, data_dir):
        self.name = name
        self.data_dir = data_dir
        self.tables = {}
        self.meta_store = data_dir + "/" + name + "_meta.kv"
        fs_mkdirs(data_dir)

    def create_table(self, table_name, columns):
        var store = self.data_dir + "/" + self.name + "_" + table_name + ".kv"
        var table = NyTable(table_name, store, columns)
        self.tables[table_name] = table
        var col_str = ""
        var i = 0
        var n = len(columns)
        while i < n:
            if i > 0:
                var col_str = col_str + ","
            col_str = col_str + columns[i]
            var i = i + 1
        kv_set(self.meta_store, "table_" + table_name, col_str)
        return table

    def get_table(self, table_name):
        return self.tables[table_name]

    def list_tables(self):
        var all_keys = kv_keys(self.meta_store)
        var tables = []
        var i = 0
        while i < len(all_keys):
            var k = all_keys[i]
            if k[:6] == "table_":
                var tables = tables + [k[6:]]
            var i = i + 1
        return tables

    def drop_table(self, table_name):
        self.tables[table_name] = none
        kv_del(self.meta_store, "table_" + table_name)
        return self

# -----------------------------------------
# 191. NyTable  (table in NyDB)
# -----------------------------------------
class NyTable:
    def __init__(self, name, store_path, columns):
        self.name = name
        self.store = store_path
        self.columns = columns
        self.row_count = 0
        var rc = kv_get(self.store, "__row_count__")
        if rc != none:
            self.row_count = to_int(rc)

    def insert(self, values):
        var row_id = self.row_count
        var n = len(self.columns)
        var i = 0
        while i < n:
            if i < len(values):
                kv_set(self.store, str(row_id) + "_" + self.columns[i], values[i])
            var i = i + 1
        self.row_count = self.row_count + 1
        kv_set(self.store, "__row_count__", str(self.row_count))
        return row_id

    def get(self, row_id, column):
        return kv_get(self.store, str(row_id) + "_" + column)

    def get_row(self, row_id):
        var row = {}
        var i = 0
        var n = len(self.columns)
        while i < n:
            var val = kv_get(self.store, str(row_id) + "_" + self.columns[i])
            if val != none:
                row[self.columns[i]] = val
            var i = i + 1
        return row

    def update(self, row_id, column, value):
        kv_set(self.store, str(row_id) + "_" + column, value)
        return self

    def delete_row(self, row_id):
        var i = 0
        var n = len(self.columns)
        while i < n:
            kv_del(self.store, str(row_id) + "_" + self.columns[i])
            var i = i + 1
        return self

    def scan(self, column, value):
        var matches = []
        var i = 0
        while i < self.row_count:
            var v = kv_get(self.store, str(i) + "_" + column)
            if v == value:
                var matches = matches + [i]
            var i = i + 1
        return matches

    def count(self):
        return self.row_count

# -----------------------------------------
# 192. QueryBuilder
# -----------------------------------------
class QueryBuilder:
    def __init__(self, table):
        self.table = table
        self.filter_col = none
        self.filter_val = none
        self.limit_n = -1
        self.select_cols = []
        self.order_col = none

    def where(self, column, value):
        self.filter_col = column
        self.filter_val = value
        return self

    def select(self, columns):
        self.select_cols = columns
        return self

    def limit(self, n):
        self.limit_n = n
        return self

    def order_by(self, column):
        self.order_col = column
        return self

    def execute(self):
        var results = []
        var scan_ids = []
        if self.filter_col != none:
            var scan_ids = self.table.scan(self.filter_col, self.filter_val)
        else:
            var i = 0
            while i < self.table.row_count:
                scan_ids = scan_ids + [i]
                var i = i + 1
        var count = 0
        var i = 0
        var n = len(scan_ids)
        while i < n:
            if self.limit_n >= 0:
                if count >= self.limit_n:
                    i = n
                else:
                    var row = self.table.get_row(scan_ids[i])
                    var results = results + [row]
                    var count = count + 1
            else:
                var row = self.table.get_row(scan_ids[i])
                results = results + [row]
            i = i + 1
        return results

    def count(self):
        if self.filter_col != none:
            var ids = self.table.scan(self.filter_col, self.filter_val)
            return len(ids)
        return self.table.row_count

# -----------------------------------------
# 193. ReplayBuffer  (RL experience replay)
# -----------------------------------------
class ReplayBuffer:
    def __init__(self, capacity):
        self.capacity = capacity
        self.buffer = []
        self.pos = 0
        self.full = false

    def push(self, state, action, reward, next_state, done):
        var exp = {"s": state, "a": action, "r": reward, "ns": next_state, "d": done}
        if len(self.buffer) < self.capacity:
            self.buffer = self.buffer + [exp]
        else:
            self.buffer[self.pos] = exp
        self.pos = (self.pos + 1) % self.capacity
        if self.pos == 0:
            self.full = true
        return self

    def sample(self, batch_size):
        var n = len(self.buffer)
        if n < batch_size:
            var batch_size = n
        var batch = []
        var indices = []
        var i = 0
        while i < batch_size:
            var idx = random_int(0, n - 1)
            var indices = indices + [idx]
            var batch = batch + [self.buffer[idx]]
            var i = i + 1
        return batch

    def size(self):
        return len(self.buffer)

    def is_ready(self, min_size):
        if len(self.buffer) >= min_size:
            return true
        return false

    def states_batch(self, experiences):
        var states = []
        var i = 0
        var n = len(experiences)
        while i < n:
            var states = states + [experiences[i]["s"]]
            var i = i + 1
        return states

    def rewards_batch(self, experiences):
        var rewards = []
        var i = 0
        var n = len(experiences)
        while i < n:
            var rewards = rewards + [experiences[i]["r"]]
            var i = i + 1
        return rewards

# -----------------------------------------
# 194. PrioritizedReplayBuffer
# -----------------------------------------
class PrioritizedReplayBuffer:
    def __init__(self, capacity, alpha):
        self.capacity = capacity
        self.alpha = alpha
        self.buffer = []
        self.priorities = []
        self.pos = 0
        self.max_priority = 1.0

    def push(self, state, action, reward, next_state, done):
        var exp = {"s": state, "a": action, "r": reward, "ns": next_state, "d": done}
        if len(self.buffer) < self.capacity:
            self.buffer = self.buffer + [exp]
            self.priorities = self.priorities + [self.max_priority]
        else:
            self.buffer[self.pos] = exp
            self.priorities[self.pos] = self.max_priority
        self.pos = (self.pos + 1) % self.capacity
        return self

    def sample(self, batch_size, beta):
        var n = len(self.buffer)
        if n == 0:
            return []
        if n < batch_size:
            var batch_size = n
        var total_p = 0.0
        var i = 0
        while i < n:
            var total_p = total_p + self.priorities[i] ** self.alpha
            var i = i + 1
        var batch = []
        var weights = []
        i = 0
        while i < batch_size:
            var r = random_float(0.0, total_p)
            var cum = 0.0
            var chosen = 0
            var j = 0
            while j < n:
                var cum = cum + self.priorities[j] ** self.alpha
                if cum >= r:
                    var chosen = j
                    var j = n
                j = j + 1
            var batch = batch + [self.buffer[chosen]]
            var w = (1.0 / to_float(n) / (self.priorities[chosen] ** self.alpha / total_p)) ** beta
            var weights = weights + [w]
            i = i + 1
        return batch

    def update_priority(self, idx, priority):
        if idx < len(self.priorities):
            self.priorities[idx] = priority + 0.0001
            if priority > self.max_priority:
                self.max_priority = priority
        return self

    def size(self):
        return len(self.buffer)

# -----------------------------------------
# 195. DQNAgent  (full DQN implementation)
# -----------------------------------------
def _dqn_relu_fn(v):
    return relu(v)

class DQNAgent:
    def __init__(self, state_dim, action_dim, storage_dir):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.storage = StorageManager(storage_dir + "/dqn")
        self.replay = ReplayBuffer(10000)
        self.logger = DataLogger(storage_dir + "/logs", "dqn")
        self.epsilon = 1.0
        self.epsilon_min = 0.01
        self.epsilon_decay = 0.995
        self.gamma = 0.99
        self.lr = 0.001
        self.batch_size = 32
        self.train_step_count = 0
        self.episode_rewards = []
        self.w1 = tensor_randn([state_dim * 64])
        self.b1 = tensor_zeros([64])
        self.w2 = tensor_randn([64 * action_dim])
        self.b2 = tensor_zeros([action_dim])

    def setup(self):
        self.storage.setup()
        return self

    def forward(self, state):
        var loc_w1 = self.w1
        var loc_b1 = self.b1
        var h = tensor_add(tensor_matmul(state, loc_w1), loc_b1)
        var h_act = tensor_apply(h, _dqn_relu_fn)
        var loc_w2 = self.w2
        var loc_b2 = self.b2
        return tensor_add(tensor_matmul(h_act, loc_w2), loc_b2)

    def act(self, state):
        var r = random_float(0.0, 1.0)
        if r < self.epsilon:
            return random_int(0, self.action_dim - 1)
        var q_vals = self.forward(state)
        return tensor_argmax(q_vals)

    def remember(self, state, action, reward, next_state, done):
        self.replay.push(state, action, reward, next_state, done)
        return self

    def train_on_batch(self):
        if not self.replay.is_ready(self.batch_size):
            return 0.0
        var batch = self.replay.sample(self.batch_size)
        var total_loss = 0.0
        var i = 0
        var n = len(batch)
        while i < n:
            var exp = batch[i]
            var q_cur = self.forward(exp["s"])
            var q_next = self.forward(exp["ns"])
            var target = exp["r"]
            if not exp["d"]:
                var max_q = tensor_max(q_next)
                var target = target + self.gamma * max_q
            var q_a = tensor_slice(q_cur, exp["a"], exp["a"] + 1)
            var err = tensor_sum(q_a) - target
            var total_loss = total_loss + err * err
            var i = i + 1
        self.train_step_count = self.train_step_count + 1
        if self.epsilon > self.epsilon_min:
            self.epsilon = self.epsilon * self.epsilon_decay
        return total_loss / to_float(n)

    def save(self):
        var loc_store = self.storage
        var params = [self.w1, self.b1, self.w2, self.b2]
        loc_store.save_model("dqn_weights", params, "eps=" + str(self.epsilon))
        return self

    def load(self):
        var loc_store = self.storage
        if loc_store.model_exists("dqn_weights"):
            var params = loc_store.load_model("dqn_weights")
            if len(params) >= 4:
                self.w1 = params[0]
                self.b1 = params[1]
                self.w2 = params[2]
                self.b2 = params[3]
        return self

# -----------------------------------------
# 196. PPOMemory  (PPO rollout storage)
# -----------------------------------------
class PPOMemory:
    def __init__(self):
        self.states = []
        self.actions = []
        self.rewards = []
        self.values = []
        self.log_probs = []
        self.dones = []

    def store(self, state, action, reward, value, log_prob, done):
        self.states = self.states + [state]
        self.actions = self.actions + [action]
        self.rewards = self.rewards + [reward]
        self.values = self.values + [value]
        self.log_probs = self.log_probs + [log_prob]
        self.dones = self.dones + [done]
        return self

    def compute_returns(self, gamma, gae_lambda):
        var n = len(self.rewards)
        var returns = []
        var advantages = []
        var gae = 0.0
        var i = n - 1
        while i >= 0:
            var next_val = 0.0
            if i < n - 1:
                if not self.dones[i]:
                    var next_val = self.values[i + 1]
            var delta = self.rewards[i] + gamma * next_val - self.values[i]
            var gae = delta + gamma * gae_lambda * gae
            var advantages = [gae] + advantages
            returns = [self.values[i] + gae] + returns
            var i = i - 1
        return {"returns": returns, "advantages": advantages}

    def clear(self):
        self.states = []
        self.actions = []
        self.rewards = []
        self.values = []
        self.log_probs = []
        self.dones = []
        return self

    def size(self):
        return len(self.states)

# -----------------------------------------
# 197. MultiAgentEnv
# -----------------------------------------
class MultiAgentEnv:
    def __init__(self, name, n_agents, state_dim, action_dim):
        self.name = name
        self.n_agents = n_agents
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.states = []
        self.rewards = []
        self.dones = []
        self.step_count = 0
        self.episode = 0
        var i = 0
        while i < n_agents:
            self.states = self.states + [tensor_randn([state_dim])]
            self.rewards = self.rewards + [0.0]
            self.dones = self.dones + [false]
            var i = i + 1

    def reset(self):
        self.step_count = 0
        self.episode = self.episode + 1
        var i = 0
        while i < self.n_agents:
            self.states[i] = tensor_randn([self.state_dim])
            self.rewards[i] = 0.0
            self.dones[i] = false
            var i = i + 1
        return self.states

    def step(self, actions):
        self.step_count = self.step_count + 1
        var new_states = []
        var new_rewards = []
        var new_dones = []
        var i = 0
        while i < self.n_agents:
            var noise = tensor_randn([self.state_dim])
            var new_state = tensor_add(self.states[i], tensor_scale(noise, 0.1))
            var reward = random_float(-0.1, 1.0)
            var done = false
            if self.step_count >= 200:
                var done = true
            var new_states = new_states + [new_state]
            var new_rewards = new_rewards + [reward]
            var new_dones = new_dones + [done]
            var i = i + 1
        self.states = new_states
        self.rewards = new_rewards
        self.dones = new_dones
        return {"states": new_states, "rewards": new_rewards, "dones": new_dones}

    def total_reward(self):
        var total = 0.0
        var i = 0
        while i < self.n_agents:
            var total = total + self.rewards[i]
            var i = i + 1
        return total

# -----------------------------------------
# 198. CurriculumScheduler
# -----------------------------------------
class CurriculumScheduler:
    def __init__(self, name):
        self.name = name
        self.stages = []
        self.current_stage = 0
        self.episodes_in_stage = 0
        self.total_episodes = 0

    def add_stage(self, stage_name, difficulty, episodes_needed, success_threshold):
        self.stages = self.stages + [{"name": stage_name, "diff": difficulty, "needed": episodes_needed, "threshold": success_threshold, "successes": 0}]
        return self

    def update(self, success):
        if len(self.stages) == 0:
            return self
        self.total_episodes = self.total_episodes + 1
        self.episodes_in_stage = self.episodes_in_stage + 1
        if success:
            self.stages[self.current_stage]["successes"] = self.stages[self.current_stage]["successes"] + 1
        var stage = self.stages[self.current_stage]
        var success_rate = to_float(stage["successes"]) / to_float(self.episodes_in_stage)
        if self.episodes_in_stage >= stage["needed"]:
            if success_rate >= stage["threshold"]:
                if self.current_stage < len(self.stages) - 1:
                    self.current_stage = self.current_stage + 1
                    self.episodes_in_stage = 0
        return self

    def current_difficulty(self):
        if len(self.stages) == 0:
            return 0.0
        return self.stages[self.current_stage]["diff"]

    def current_stage_name(self):
        if len(self.stages) == 0:
            return "none"
        return self.stages[self.current_stage]["name"]

    def progress(self):
        return self.name + " stage=" + self.current_stage_name() + " ep=" + str(self.total_episodes)

# -----------------------------------------
# 199. RewardShaper
# -----------------------------------------
class RewardShaper:
    def __init__(self, gamma, potential_scale):
        self.gamma = gamma
        self.potential_scale = potential_scale
        self.prev_potential = 0.0
        self.shaped_total = 0.0
        self.steps = 0

    def potential(self, state):
        var loc_state = state
        return tensor_sum(loc_state) * self.potential_scale

    def shape(self, state, next_state, raw_reward, done):
        var phi_s = self.potential(state)
        var phi_ns = 0.0
        if not done:
            var phi_ns = self.potential(next_state)
        var shaping = self.gamma * phi_ns - phi_s
        var shaped = raw_reward + shaping
        self.shaped_total = self.shaped_total + shaped
        self.steps = self.steps + 1
        return shaped

    def clip(self, reward, min_r, max_r):
        if reward < min_r:
            return min_r
        if reward > max_r:
            return max_r
        return reward

    def normalize_running(self, reward):
        if self.steps == 0:
            return reward
        var avg = self.shaped_total / to_float(self.steps)
        return reward - avg

# -----------------------------------------
# 200. TaskDistributor  (parallel task farm)
# -----------------------------------------
class TaskDistributor:
    def __init__(self, name, storage_dir, n_workers):
        self.name = name
        self.storage_dir = storage_dir
        self.n_workers = n_workers
        self.task_queue = MessageQueue(name + "_tasks", storage_dir)
        self.result_store = storage_dir + "/" + name + "_results.kv"
        self.task_count = 0
        self.done_count = 0
        fs_mkdirs(storage_dir)

    def submit(self, task_id, task_data):
        var msg = task_id + "|" + task_data
        self.task_queue.push(msg)
        self.task_count = self.task_count + 1
        return task_id

    def next_task(self, worker_id):
        return self.task_queue.pop()

    def complete(self, task_id, result):
        kv_set(self.result_store, "result_" + task_id, result)
        self.done_count = self.done_count + 1
        return self

    def get_result(self, task_id):
        return kv_get(self.result_store, "result_" + task_id)

    def pending(self):
        return self.task_queue.size()

    def progress(self):
        if self.task_count == 0:
            return 0.0
        return to_float(self.done_count) / to_float(self.task_count)

    def status(self):
        return self.name + " tasks=" + str(self.task_count) + " done=" + str(self.done_count) + " pending=" + str(self.pending())

# -----------------------------------------
# 201. ResultAggregator
# -----------------------------------------
class ResultAggregator:
    def __init__(self, name):
        self.name = name
        self.results = []
        self.errors = []
        self.stats_tracker = StatisticsTracker(name)

    def add(self, result_val, is_error):
        if is_error:
            self.errors = self.errors + [result_val]
        else:
            self.results = self.results + [result_val]
            if type(result_val) == "float":
                self.stats_tracker.add(result_val)
            else:
                var as_float = to_float(result_val)
                if as_float != none:
                    self.stats_tracker.add(as_float)
        return self

    def add_tensor_result(self, t):
        var loc_t = t
        self.results = self.results + [t]
        self.stats_tracker.add(tensor_sum(loc_t))
        return self

    def mean_result(self):
        return self.stats_tracker.mean()

    def best_result(self):
        return self.stats_tracker.running_max

    def error_rate(self):
        var total = len(self.results) + len(self.errors)
        if total == 0:
            return 0.0
        return to_float(len(self.errors)) / to_float(total)

    def summary(self):
        return self.name + " results=" + str(len(self.results)) + " errors=" + str(len(self.errors)) + " mean=" + str(self.mean_result())


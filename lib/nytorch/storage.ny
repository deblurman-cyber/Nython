# ============================================================
# NyTorch v3.0 -- Part 9: Agent I/O, Storage, Network & AI
# ============================================================
# Classes 114-137:
#   StorageManager, ModelStore, KnowledgeBase, DataLogger,
#   DataPipeline, CSVReader, BinaryBlob,
#   NetworkClient, APIClient, AgentMessenger, BroadcastHub,
#   AgentRegistry, AgentMemory, AgentGoal, AgentPlan,
#   BaseAgent, ReactiveAgent, LearningAgent, SwarmAgent,
#   NyMind, NyVoice, NySensor, NyActuator,
#   AgentWorld, AgentBuilder
# ============================================================

import nytorch

# -----------------------------------------
# 114. StorageManager
# -----------------------------------------
class StorageManager:
    def __init__(self, base_dir):
        self.base_dir = base_dir
        self.initialized = false

    def setup(self):
        fs_mkdirs(self.base_dir)
        fs_mkdirs(self.base_dir + "/tensors")
        fs_mkdirs(self.base_dir + "/models")
        fs_mkdirs(self.base_dir + "/data")
        fs_mkdirs(self.base_dir + "/logs")
        self.initialized = true
        return self

    def save_tensor(self, name, t):
        var p = self.base_dir + "/tensors/" + name + ".nyt"
        return tensor_save(t, p)

    def load_tensor(self, name):
        var p = self.base_dir + "/tensors/" + name + ".nyt"
        return tensor_load(p)

    def save_model(self, name, params):
        var p = self.base_dir + "/models/" + name + ".nym"
        return model_save(params, p)

    def load_model(self, name):
        var p = self.base_dir + "/models/" + name + ".nym"
        return model_load(p)

    def write_text(self, name, content):
        var p = self.base_dir + "/data/" + name
        return write_file(p, content)

    def read_text(self, name):
        var p = self.base_dir + "/data/" + name
        return read_file(p)

    def list_tensors(self):
        return fs_walk(self.base_dir + "/tensors")

    def list_models(self):
        return fs_walk(self.base_dir + "/models")

    def tensor_exists(self, name):
        var s = fs_stat(self.base_dir + "/tensors/" + name + ".nyt")
        return s.exists

    def model_exists(self, name):
        var s = fs_stat(self.base_dir + "/models/" + name + ".nym")
        return s.exists

# -----------------------------------------
# 115. ModelStore
# -----------------------------------------
class ModelStore:
    def __init__(self, path):
        self.path = path
        self.registry = path + "/registry.kv"
        fs_mkdirs(path)

    def save(self, name, params, meta):
        var ok = model_save(params, self.path + "/" + name + ".nym")
        if ok:
            kv_set(self.registry, name, meta)
        return ok

    def load(self, name):
        return model_load(self.path + "/" + name + ".nym")

    def info(self, name):
        return kv_get(self.registry, name)

    def list_all(self):
        return kv_keys(self.registry)

    def remove(self, name):
        file_delete(self.path + "/" + name + ".nym")
        return kv_del(self.registry, name)

    def exists(self, name):
        var s = fs_stat(self.path + "/" + name + ".nym")
        return s.exists

# -----------------------------------------
# 116. KnowledgeBase
# -----------------------------------------
class KnowledgeBase:
    def __init__(self, store_path):
        self.store = store_path
        var d = path_dirname(store_path)
        fs_mkdirs(d)

    def remember(self, key, value):
        return kv_set(self.store, key, value)

    def recall(self, key):
        return kv_get(self.store, key)

    def forget(self, key):
        return kv_del(self.store, key)

    def all_keys(self):
        return kv_keys(self.store)

    def all_entries(self):
        return kv_all(self.store)

    def has(self, key):
        var v = kv_get(self.store, key)
        if v == none:
            return false
        return true

    def update(self, key, value):
        return kv_set(self.store, key, value)

    def count(self):
        var keys = kv_keys(self.store)
        return len(keys)

    def search(self, prefix):
        var keys = kv_keys(self.store)
        var found = []
        var i = 0
        var n = len(keys)
        while i < n:
            var k = keys[i]
            if k[:len(prefix)] == prefix:
                var found = found + [k]
            var i = i + 1
        return found

# -----------------------------------------
# 117. DataLogger
# -----------------------------------------
class DataLogger:
    def __init__(self, log_dir, agent_id):
        self.log_dir = log_dir
        self.agent_id = agent_id
        self.log_file = log_dir + "/" + agent_id + ".log"
        fs_mkdirs(log_dir)

    def log(self, level, message):
        var ts = str(time_timestamp())
        var line = "[" + ts + "] [" + level + "] [" + self.agent_id + "] " + message + "\n"
        file_append(self.log_file, line)
        return line

    def info(self, msg):
        return self.log("INFO", msg)

    def warn(self, msg):
        return self.log("WARN", msg)

    def error(self, msg):
        return self.log("ERROR", msg)

    def debug(self, msg):
        return self.log("DEBUG", msg)

    def read_logs(self):
        return read_file(self.log_file)

    def clear(self):
        return write_file(self.log_file, "")

    def log_metric(self, name, value):
        var line = name + "=" + str(value)
        return self.log("METRIC", line)

# -----------------------------------------
# 118. DataPipeline
# -----------------------------------------
class DataPipeline:
    def __init__(self, name):
        self.name = name
        self.steps = []
        self.data = none

    def load_text(self, path):
        self.data = read_file(path)
        return self

    def load_tensor(self, path):
        self.data = tensor_load(path)
        return self

    def set_data(self, d):
        self.data = d
        return self

    def to_json(self):
        self.data = json_encode(self.data)
        return self

    def from_json(self):
        self.data = json_decode(self.data)
        return self

    def save_text(self, path):
        write_file(path, str(self.data))
        return self

    def save_tensor(self, path):
        var loc_data = self.data
        tensor_save(loc_data, path)
        return self

    def get(self):
        return self.data

# -----------------------------------------
# 119. CSVReader
# -----------------------------------------
class CSVReader:
    def __init__(self, path):
        self.path = path
        self.rows = []
        self.headers = []
        self.loaded = false

    def load(self):
        var raw = read_file(self.path)
        if raw == none:
            return self
        var lines = raw.split("\n")
        var n = len(lines)
        if n > 0:
            self.headers = lines[0].split(",")
        var i = 1
        self.rows = []
        while i < n:
            var row = lines[i]
            if len(row) > 0:
                self.rows = self.rows + [row.split(",")]
            var i = i + 1
        self.loaded = true
        return self

    def row_count(self):
        return len(self.rows)

    def col_count(self):
        return len(self.headers)

    def get_row(self, i):
        return self.rows[i]

    def get_col(self, col_name):
        var idx = 0
        var n = len(self.headers)
        while idx < n:
            if self.headers[idx] == col_name:
                var col_data = []
                var r = 0
                var nr = len(self.rows)
                while r < nr:
                    var col_data = col_data + [self.rows[r][idx]]
                    var r = r + 1
                return col_data
            var idx = idx + 1
        return []

    def to_tensors(self):
        var tensors = []
        var r = 0
        var nr = len(self.rows)
        while r < nr:
            var row = self.rows[r]
            var floats = []
            var c = 0
            var nc = len(row)
            while c < nc:
                var floats = floats + [to_float(row[c])]
                var c = c + 1
            var tensors = tensors + [tensor(floats)]
            var r = r + 1
        return tensors

# -----------------------------------------
# 120. BinaryBlob
# -----------------------------------------
class BinaryBlob:
    def __init__(self, path):
        self.path = path
        self.data = []

    def read(self):
        self.data = read_bytes(self.path)
        return self

    def write(self):
        return write_bytes(self.path, self.data)

    def size(self):
        return len(self.data)

    def get_byte(self, i):
        return self.data[i]

    def set_byte(self, i, v):
        self.data[i] = v
        return self

    def to_str(self):
        var s = ""
        var i = 0
        var n = len(self.data)
        while i < n:
            var s = s + str(self.data[i]) + " "
            var i = i + 1
        return s

# -----------------------------------------
# 121. NetworkClient
# -----------------------------------------
class NetworkClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.last_status = 0
        self.last_body = ""
        self.headers = ""

    def set_header(self, key, value):
        self.headers = self.headers + key + ": " + value + "\r\n"
        return self

    def get(self, path):
        var url = self.base_url + path
        var resp = http_request("GET", url, self.headers, "")
        self.last_status = resp.status
        self.last_body = resp.body
        return resp.body

    def post(self, path, body):
        var url = self.base_url + path
        var resp = http_request("POST", url, self.headers + "Content-Type: text/plain\r\n", body)
        self.last_status = resp.status
        self.last_body = resp.body
        return resp.body

    def post_json(self, path, json_str):
        var url = self.base_url + path
        var resp = http_post_json(url, json_str)
        self.last_status = resp.status
        self.last_body = resp.body
        return resp.body

    def get_json(self, path):
        var url = self.base_url + path
        var resp = http_get_json(url)
        self.last_status = resp.status
        var parsed = json_decode(resp.body)
        return parsed

    def ok(self):
        if self.last_status >= 200:
            if self.last_status < 300:
                return true
        return false

# -----------------------------------------
# 122. APIClient
# -----------------------------------------
class APIClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.last_resp = none

    def _headers(self):
        return "Authorization: Bearer " + self.api_key + "\r\nContent-Type: application/json\r\n"

    def call(self, method, path, body):
        var url = self.base_url + path
        var h = self._headers()
        var resp = http_request(method, url, h, body)
        self.last_resp = resp
        return resp

    def get(self, path):
        return self.call("GET", path, "")

    def post(self, path, payload):
        var body = json_encode(payload)
        return self.call("POST", path, body)

    def put(self, path, payload):
        var body = json_encode(payload)
        return self.call("PUT", path, body)

    def delete(self, path):
        return self.call("DELETE", path, "")

    def status(self):
        if self.last_resp == none:
            return 0
        return self.last_resp.status

    def body(self):
        if self.last_resp == none:
            return ""
        return self.last_resp.body

# -----------------------------------------
# 123. AgentMessenger
# -----------------------------------------
class AgentMessenger:
    def __init__(self, agent_id, port):
        self.agent_id = agent_id
        self.port = port
        self.inbox = []

    def send_to(self, host, msg):
        var payload = self.agent_id + "|" + msg
        return agent_send(host, self.port, payload)

    def broadcast(self, msg):
        var payload = self.agent_id + "|" + msg
        return agent_broadcast(self.port, payload)

    def recv(self, timeout_ms):
        var pkt = agent_recv(self.port, timeout_ms)
        if pkt == none:
            return none
        var parts = pkt.msg.split("|")
        var sender_id = parts[0]
        var content = parts[1]
        var m = {"from": sender_id, "msg": content, "ip": pkt.from}
        self.inbox = self.inbox + [m]
        return m

    def flush_inbox(self):
        var all_msgs = self.inbox
        self.inbox = []
        return all_msgs

    def inbox_size(self):
        return len(self.inbox)

# -----------------------------------------
# 124. BroadcastHub
# -----------------------------------------
class BroadcastHub:
    def __init__(self, port):
        self.port = port
        self.subscribers = []

    def publish(self, topic, data):
        var msg = topic + ":" + data
        return agent_broadcast(self.port, msg)

    def subscribe(self, topic):
        self.subscribers = self.subscribers + [topic]
        return self

    def receive(self, timeout_ms):
        var raw = agent_listen(self.port, timeout_ms)
        if raw == none:
            return none
        var colon = 0
        var i = 0
        var n = len(raw)
        while i < n:
            if raw[i] == ":":
                var colon = i
                var i = n
            i = i + 1
        var topic = raw[:colon]
        var data = raw[colon + 1:]
        return {"topic": topic, "data": data}

# -----------------------------------------
# 125. AgentRegistry
# -----------------------------------------
class AgentRegistry:
    def __init__(self, registry_path):
        self.store = registry_path
        fs_mkdirs(path_dirname(registry_path))

    def register(self, agent_id, host, port, role):
        var info = host + ":" + str(port) + ":" + role
        return kv_set(self.store, agent_id, info)

    def unregister(self, agent_id):
        return kv_del(self.store, agent_id)

    def lookup(self, agent_id):
        var v = kv_get(self.store, agent_id)
        if v == none:
            return none
        var parts = v.split(":")
        return {"host": parts[0], "port": to_int(parts[1]), "role": parts[2]}

    def all_agents(self):
        return kv_keys(self.store)

    def agents_with_role(self, role):
        var keys = kv_keys(self.store)
        var result = []
        var i = 0
        var n = len(keys)
        while i < n:
            var info = kv_get(self.store, keys[i])
            if info != none:
                var parts = info.split(":")
                if parts[2] == role:
                    var result = result + [keys[i]]
            var i = i + 1
        return result

# -----------------------------------------
# 126. AgentMemory
# -----------------------------------------
class AgentMemory:
    def __init__(self, capacity):
        self.capacity = capacity
        self.short_term = []
        self.episodes = []

    def perceive(self, obs):
        self.short_term = self.short_term + [obs]
        var n = len(self.short_term)
        if n > self.capacity:
            self.short_term = self.short_term[1:]
        return self

    def commit_episode(self, reward):
        var ep = {"obs": self.short_term, "reward": reward}
        self.episodes = self.episodes + [ep]
        self.short_term = []
        return self

    def recent(self, k):
        var n = len(self.short_term)
        if k >= n:
            return self.short_term
        return self.short_term[n - k:]

    def replay_sample(self, k):
        var n = len(self.episodes)
        if n == 0:
            return []
        var result = []
        var i = 0
        while i < k:
            var idx = random_int(0, n - 1)
            var result = result + [self.episodes[idx]]
            var i = i + 1
        return result

    def episode_count(self):
        return len(self.episodes)

    def clear_short(self):
        self.short_term = []
        return self

# -----------------------------------------
# 127. AgentGoal
# -----------------------------------------
class AgentGoal:
    def __init__(self, name, priority):
        self.name = name
        self.priority = priority
        self.achieved = false
        self.progress = 0.0
        self.sub_goals = []
        self.conditions = []

    def add_sub_goal(self, goal):
        self.sub_goals = self.sub_goals + [goal]
        return self

    def update_progress(self, value):
        self.progress = value
        if self.progress >= 1.0:
            self.achieved = true
        return self

    def is_done(self):
        return self.achieved

    def status(self):
        if self.achieved:
            return "done"
        if self.progress > 0.0:
            return "in_progress"
        return "pending"

    def describe(self):
        return self.name + " [" + self.status() + " " + str(self.progress) + "]"

# -----------------------------------------
# 128. AgentPlan
# -----------------------------------------
class AgentPlan:
    def __init__(self, name):
        self.name = name
        self.steps = []
        self.current_step = 0
        self.done = false
        self.failed = false

    def add_step(self, step_name, action):
        self.steps = self.steps + [{"name": step_name, "action": action, "done": false}]
        return self

    def next_step(self):
        var n = len(self.steps)
        if self.current_step >= n:
            self.done = true
            return none
        return self.steps[self.current_step]

    def advance(self):
        self.steps[self.current_step]["done"] = true
        self.current_step = self.current_step + 1
        if self.current_step >= len(self.steps):
            self.done = true
        return self

    def fail(self):
        self.failed = true
        return self

    def reset(self):
        self.current_step = 0
        self.done = false
        self.failed = false
        var i = 0
        var n = len(self.steps)
        while i < n:
            self.steps[i]["done"] = false
            var i = i + 1
        return self

    def progress(self):
        var n = len(self.steps)
        if n == 0:
            return 1.0
        return to_float(self.current_step) / to_float(n)

# -----------------------------------------
# 129. BaseAgent
# -----------------------------------------
class BaseAgent:
    def __init__(self, agent_id, storage_dir, port):
        self.agent_id = agent_id
        self.port = port
        self.alive = true
        self.tick = 0
        self.storage = StorageManager(storage_dir + "/" + agent_id)
        self.memory = AgentMemory(256)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "/kb.kv")
        self.logger = DataLogger(storage_dir + "/logs", agent_id)
        self.messenger = AgentMessenger(agent_id, port)
        self.goals = []
        self.plans = []

    def setup(self):
        self.storage.setup()
        self.logger.info("Agent " + self.agent_id + " started")
        return self

    def add_goal(self, goal):
        self.goals = self.goals + [goal]
        return self

    def add_plan(self, plan):
        self.plans = self.plans + [plan]
        return self

    def sense(self, obs):
        self.memory.perceive(obs)
        return obs

    def remember(self, key, value):
        return self.kb.remember(key, value)

    def recall(self, key):
        return self.kb.recall(key)

    def send(self, host, msg):
        return self.messenger.send_to(host, msg)

    def broadcast(self, msg):
        return self.messenger.broadcast(msg)

    def receive(self, timeout_ms):
        return self.messenger.recv(timeout_ms)

    def save_state(self):
        self.kb.remember("__tick__", str(self.tick))
        self.kb.remember("__alive__", str(self.alive))
        return self

    def load_state(self):
        var t = self.kb.recall("__tick__")
        if t != none:
            self.tick = to_int(t)
        return self

    def log(self, msg):
        return self.logger.info(msg)

    def step(self):
        self.tick = self.tick + 1
        return self.tick

    def stop(self):
        self.alive = false
        self.logger.info("Agent " + self.agent_id + " stopped at tick " + str(self.tick))
        return self

# -----------------------------------------
# 130. ReactiveAgent
# -----------------------------------------
class ReactiveAgent:
    def __init__(self, agent_id, storage_dir, port):
        self.agent_id = agent_id
        self.port = port
        self.alive = true
        self.tick = 0
        self.rules = []
        self.storage = StorageManager(storage_dir + "/" + agent_id)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "/kb.kv")
        self.messenger = AgentMessenger(agent_id, port)
        self.logger = DataLogger(storage_dir + "/logs", agent_id)

    def setup(self):
        self.storage.setup()
        self.logger.info("ReactiveAgent " + self.agent_id + " ready")
        return self

    def add_rule(self, trigger, response):
        self.rules = self.rules + [{"trigger": trigger, "response": response}]
        return self

    def react(self, input_str):
        var i = 0
        var n = len(self.rules)
        while i < n:
            var rule = self.rules[i]
            if input_str == rule["trigger"]:
                return rule["response"]
            var i = i + 1
        return "no_match"

    def run_once(self, obs):
        self.tick = self.tick + 1
        var response = self.react(obs)
        self.logger.info("obs=" + obs + " -> " + response)
        return response

    def send(self, host, msg):
        return self.messenger.send_to(host, msg)

    def broadcast(self, msg):
        return self.messenger.broadcast(msg)

    def receive(self, timeout_ms):
        return self.messenger.recv(timeout_ms)

    def stop(self):
        self.alive = false
        return self

# -----------------------------------------
# 131. LearningAgent
# -----------------------------------------
class LearningAgent:
    def __init__(self, agent_id, storage_dir, port, state_size, action_size):
        self.agent_id = agent_id
        self.port = port
        self.state_size = state_size
        self.action_size = action_size
        self.alive = true
        self.tick = 0
        self.epsilon = 1.0
        self.epsilon_min = 0.05
        self.epsilon_decay = 0.995
        self.gamma = 0.99
        self.lr = 0.001
        self.storage = StorageManager(storage_dir + "/" + agent_id)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "/kb.kv")
        self.messenger = AgentMessenger(agent_id, port)
        self.logger = DataLogger(storage_dir + "/logs", agent_id)
        self.memory = AgentMemory(1000)
        self.w1 = tensor_randn([state_size * 64])
        self.w2 = tensor_randn([64 * action_size])
        self.total_reward = 0.0

    def setup(self):
        self.storage.setup()
        self.logger.info("LearningAgent " + self.agent_id + " initialized")
        return self

    def act(self, state):
        var r = random_float(0.0, 1.0)
        if r < self.epsilon:
            return random_int(0, self.action_size - 1)
        var loc_w1 = self.w1
        var loc_w2 = self.w2
        var tmp1 = tensor_matmul(state, loc_w1)
        var tmp2 = tensor_matmul(tmp1, loc_w2)
        return tensor_argmax(tmp2)

    def store_transition(self, state, action, reward, next_state, done):
        var t = {"s": state, "a": action, "r": reward, "ns": next_state, "d": done}
        self.memory.perceive(t)
        self.total_reward = self.total_reward + reward
        return self

    def decay_epsilon(self):
        if self.epsilon > self.epsilon_min:
            self.epsilon = self.epsilon * self.epsilon_decay
        return self

    def save_weights(self):
        var loc_w1 = self.w1
        var loc_w2 = self.w2
        self.storage.save_tensor("w1", loc_w1)
        self.storage.save_tensor("w2", loc_w2)
        var eps_str = str(self.epsilon)
        var rew_str = str(self.total_reward)
        self.kb.remember("epsilon", eps_str)
        self.kb.remember("total_reward", rew_str)
        return self

    def load_weights(self):
        var loc_store = self.storage
        var has_w1 = loc_store.tensor_exists("w1")
        if has_w1:
            self.w1 = loc_store.load_tensor("w1")
        var has_w2 = loc_store.tensor_exists("w2")
        if has_w2:
            self.w2 = loc_store.load_tensor("w2")
        var loc_kb = self.kb
        var eps = loc_kb.recall("epsilon")
        if eps != none:
            self.epsilon = to_float(eps)
        return self

    def share_weights(self, host):
        self.save_weights()
        var loc_w1 = self.w1
        var w1sum = tensor_sum(loc_w1)
        var info = self.agent_id + ":w1:" + str(w1sum)
        var loc_msg = self.messenger
        return loc_msg.send_to(host, info)

    def step(self):
        self.tick = self.tick + 1
        self.decay_epsilon()
        return self

    def stop(self):
        self.save_weights()
        self.alive = false
        return self

# -----------------------------------------
# 132. SwarmAgent
# -----------------------------------------
class SwarmAgent:
    def __init__(self, agent_id, storage_dir, port):
        self.agent_id = agent_id
        self.port = port
        self.alive = true
        self.tick = 0
        self.role = "worker"
        self.peers = []
        self.storage = StorageManager(storage_dir + "/" + agent_id)
        self.kb = KnowledgeBase(storage_dir + "/" + agent_id + "/kb.kv")
        self.messenger = AgentMessenger(agent_id, port)
        self.logger = DataLogger(storage_dir + "/logs", agent_id)
        self.score = 0.0

    def setup(self):
        self.storage.setup()
        self.logger.info("SwarmAgent " + self.agent_id + " [" + self.role + "] online")
        return self

    def set_role(self, role):
        self.role = role
        return self

    def add_peer(self, host):
        self.peers = self.peers + [host]
        return self

    def gossip(self, key, value):
        self.kb.remember(key, value)
        var msg = "gossip:" + key + "=" + value
        var i = 0
        var n = len(self.peers)
        while i < n:
            self.messenger.send_to(self.peers[i], msg)
            var i = i + 1
        return self

    def listen_gossip(self, timeout_ms):
        var pkt = self.messenger.recv(timeout_ms)
        if pkt == none:
            return none
        var msg = pkt["msg"]
        if msg[:7] == "gossip:":
            var content = msg[7:]
            var eq = 0
            var j = 0
            var nc = len(content)
            while j < nc:
                if content[j] == "=":
                    var eq = j
                    var j = nc
                j = j + 1
            var k = content[:eq]
            var v = content[eq + 1:]
            self.kb.remember(k, v)
            return {"key": k, "value": v}
        return none

    def update_score(self, delta):
        self.score = self.score + delta
        return self

    def broadcast_score(self):
        var msg = "score:" + self.agent_id + "=" + str(self.score)
        return self.messenger.broadcast(msg)

    def step(self):
        self.tick = self.tick + 1
        return self

    def stop(self):
        self.alive = false
        return self

# -----------------------------------------
# 133. NyMind  (AI reasoning core)
# -----------------------------------------
class NyMind:
    def __init__(self, name, storage_dir):
        self.name = name
        self.kb = KnowledgeBase(storage_dir + "/mind_" + name + ".kv")
        self.logger = DataLogger(storage_dir + "/logs", "mind_" + name)
        self.context = []
        self.max_context = 32
        self.inferences = 0
        self.confidence_threshold = 0.5

    def learn(self, fact_key, fact_value):
        self.kb.remember(fact_key, fact_value)
        self.logger.info("learned: " + fact_key + "=" + fact_value)
        return self

    def know(self, fact_key):
        return self.kb.recall(fact_key)

    def forget(self, fact_key):
        return self.kb.forget(fact_key)

    def observe(self, obs_str):
        self.context = self.context + [obs_str]
        var n = len(self.context)
        if n > self.max_context:
            self.context = self.context[1:]
        return self

    def infer(self, query):
        self.inferences = self.inferences + 1
        var known = self.kb.recall(query)
        if known != none:
            return known
        var ctx = len(self.context)
        if ctx > 0:
            return "context_based:" + self.context[ctx - 1]
        return "unknown"

    def reason(self, premise_a, premise_b):
        var a = self.kb.recall(premise_a)
        var b = self.kb.recall(premise_b)
        if a == none:
            return "missing: " + premise_a
        if b == none:
            return "missing: " + premise_b
        return "derived: " + a + " AND " + b

    def summarize(self):
        var n = self.kb.count()
        return self.name + " knows " + str(n) + " facts, made " + str(self.inferences) + " inferences"

    def dump(self):
        return self.kb.all_entries()

# -----------------------------------------
# 134. NyVoice  (text I/O for agents)
# -----------------------------------------
class NyVoice:
    def __init__(self, agent_id, api_url, api_key):
        self.agent_id = agent_id
        self.client = APIClient(api_url, api_key)
        self.history = []
        self.model = "default"
        self.system_prompt = "You are a helpful Nython AI agent named " + agent_id + "."

    def set_model(self, model_name):
        self.model = model_name
        return self

    def set_system(self, prompt):
        self.system_prompt = prompt
        return self

    def speak(self, user_msg):
        self.history = self.history + [{"role": "user", "content": user_msg}]
        var payload = {
            "model": self.model,
            "system": self.system_prompt,
            "messages": self.history
        }
        var resp = self.client.post("/v1/messages", payload)
        var answer = resp.body
        self.history = self.history + [{"role": "assistant", "content": answer}]
        return answer

    def ask(self, question):
        return self.speak(question)

    def reset_history(self):
        self.history = []
        return self

    def save_history(self, path):
        return write_file(path, json_encode(self.history))

    def load_history(self, path):
        var raw = read_file(path)
        if raw != none:
            self.history = json_decode(raw)
        return self

# -----------------------------------------
# 135. NySensor  (data acquisition)
# -----------------------------------------
class NySensor:
    def __init__(self, name, data_path):
        self.name = name
        self.data_path = data_path
        self.buffer = []
        self.max_buffer = 512
        self.readings = 0

    def read_file_sensor(self):
        var raw = read_file(self.data_path)
        if raw != none:
            self.buffer = self.buffer + [raw]
            self.readings = self.readings + 1
            var n = len(self.buffer)
            if n > self.max_buffer:
                self.buffer = self.buffer[1:]
        return raw

    def read_tensor_sensor(self):
        var t = tensor_load(self.data_path)
        if t != none:
            self.buffer = self.buffer + [t]
            self.readings = self.readings + 1
            var n = len(self.buffer)
            if n > self.max_buffer:
                self.buffer = self.buffer[1:]
        return t

    def latest(self):
        var n = len(self.buffer)
        if n == 0:
            return none
        return self.buffer[n - 1]

    def last_k(self, k):
        var n = len(self.buffer)
        if k >= n:
            return self.buffer
        return self.buffer[n - k:]

    def clear(self):
        self.buffer = []
        return self

# -----------------------------------------
# 136. NyActuator  (action executor)
# -----------------------------------------
class NyActuator:
    def __init__(self, name, storage_dir):
        self.name = name
        self.action_log = storage_dir + "/actuator_" + name + ".log"
        self.commands_executed = 0
        self.last_result = none
        fs_mkdirs(storage_dir)

    def execute(self, cmd):
        var result = shell(cmd)
        self.last_result = result
        self.commands_executed = self.commands_executed + 1
        var ts = str(time_timestamp())
        file_append(self.action_log, "[" + ts + "] " + cmd + "\n")
        return result

    def write_output(self, path, content):
        self.last_result = write_file(path, content)
        self.commands_executed = self.commands_executed + 1
        return self.last_result

    def save_model_action(self, store, name, params, meta):
        var s = ModelStore(store)
        var ok = s.save(name, params, meta)
        self.last_result = ok
        self.commands_executed = self.commands_executed + 1
        return ok

    def send_http(self, url, payload):
        var resp = http_post_json(url, payload)
        self.last_result = resp
        self.commands_executed = self.commands_executed + 1
        return resp

    def broadcast_msg(self, port, msg):
        var ok = agent_broadcast(port, msg)
        self.last_result = ok
        self.commands_executed = self.commands_executed + 1
        return ok

    def get_last(self):
        return self.last_result

    def total_actions(self):
        return self.commands_executed

# -----------------------------------------
# 137. AgentWorld  (shared simulation env)
# -----------------------------------------
class AgentWorld:
    def __init__(self, name, storage_dir):
        self.name = name
        self.store = storage_dir + "/world_" + name + ".kv"
        self.event_log = storage_dir + "/world_events.log"
        fs_mkdirs(storage_dir)

    def set(self, key, value):
        return kv_set(self.store, key, value)

    def get(self, key):
        return kv_get(self.store, key)

    def has(self, key):
        var v = kv_get(self.store, key)
        if v == none:
            return false
        return true

    def all(self):
        return kv_all(self.store)

    def log_event(self, agent_id, event):
        var ts = str(time_timestamp())
        var line = "[" + ts + "] [" + agent_id + "] " + event + "\n"
        file_append(self.event_log, line)
        return line

    def read_events(self):
        return read_file(self.event_log)

    def reset(self):
        write_file(self.store, "")
        write_file(self.event_log, "")
        return self

# -----------------------------------------
# 138. AgentBuilder  (fluent factory)
# -----------------------------------------
class AgentBuilder:
    def __init__(self):
        self.agent_id = "agent_1"
        self.storage_dir = "./ny_agents"
        self.port = 9000
        self.agent_type = "base"
        self.state_size = 16
        self.action_size = 4
        self.roles = []
        self.goals_list = []

    def id(self, aid):
        self.agent_id = aid
        return self

    def storage(self, path):
        self.storage_dir = path
        return self

    def network_port(self, p):
        self.port = p
        return self

    def as_reactive(self):
        self.agent_type = "reactive"
        return self

    def as_learner(self, state_size, action_size):
        self.agent_type = "learning"
        self.state_size = state_size
        self.action_size = action_size
        return self

    def as_swarm(self):
        self.agent_type = "swarm"
        return self

    def with_goal(self, goal_name, priority):
        self.goals_list = self.goals_list + [{"name": goal_name, "priority": priority}]
        return self

    def build(self):
        if self.agent_type == "reactive":
            var a = ReactiveAgent(self.agent_id, self.storage_dir, self.port)
            a.setup()
            return a
        if self.agent_type == "learning":
            var a = LearningAgent(self.agent_id, self.storage_dir, self.port, self.state_size, self.action_size)
            a.setup()
            return a
        if self.agent_type == "swarm":
            var a = SwarmAgent(self.agent_id, self.storage_dir, self.port)
            a.setup()
            return a
        var a = BaseAgent(self.agent_id, self.storage_dir, self.port)
        a.setup()
        var gi = 0
        var gn = len(self.goals_list)
        while gi < gn:
            var g = AgentGoal(self.goals_list[gi]["name"], self.goals_list[gi]["priority"])
            a.add_goal(g)
            var gi = gi + 1
        return a


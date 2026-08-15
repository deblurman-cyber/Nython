# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import net
import threading

# clientserver.ny — Nython Client-Server Framework
# Protocol framing, RPC, pub/sub broker, chat server, file transfer
# Usage: import "lib/clientserver.ny"
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Message Protocol ─────────────────────────────────────────────────────────

class Message:
    def __init__(self, topic, payload, from_id):
        self.topic = topic
        self.type = topic
        self.payload = payload
        self.from_id = from_id
        self.to_id = ""
        self.id = str(int(time_ms()))
        self.timestamp = time_now()

    def to_wire(self):
        var data = {}
        data["type"] = self.type
        data["payload"] = self.payload
        data["id"] = self.id
        data["from"] = self.from_id
        data["to"] = self.to_id
        data["ts"] = self.timestamp
        return json_encode(data)

    def from_wire(self, wire):
        var data = json_decode(wire)
        if data == none:
            return false
        self.type = data["type"]
        self.payload = data["payload"]
        self.id = data["id"]
        self.from_id = data["from"]
        self.to_id = data["to"]
        self.timestamp = data["ts"]
        return true

class MessageBus:
    def __init__(self):
        self.subscribers = {}
        self.sub_counts = {}
        self.history = []
        self.history_size = 1000
        self.hist_count = 0

    def subscribe(self, topic, handler):
        var count = self.sub_counts[topic]
        if count == none:
            var count = 0
        self.subscribers[topic + "_" + str(count)] = handler
        self.sub_counts[topic] = count + 1

    def publish(self, msg):
        var topic = msg.topic
        var count = self.sub_counts[topic]
        if count == none:
            return
        var i = 0
        while i < count:
            var h = self.subscribers[topic + "_" + str(i)]
            if h != none:
                h(msg)
            i = i + 1
        if self.hist_count < self.history_size:
            self.history.append(msg)
            self.hist_count = self.hist_count + 1

    def publish_raw(self, topic, payload):
        var msg = Message(topic, payload, "")
        self.publish(msg)

    def unsubscribe(self, topic):
        self.sub_counts[topic] = 0

    def get_history(self):
        return self.history

# ─── RPC Framework ───────────────────────────────────────────────────────────

class RpcServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.methods = {}
        self.running = false
        self.server_fd = -1

    def register(self, name, fn):
        self.methods[name] = fn
        return self

    def _handle(self, client_fd):
        var raw = tcp_recv_all(client_fd)
        if raw == none or len(raw) == 0:
            tcp_close(client_fd)
            return
        var req = json_decode(raw)
        var resp = {}
        resp["id"] = req["id"]
        if req == none:
            resp["error"] = "invalid request"
        else:
            var method = req["method"]
            var fn = self.methods[method]
            if fn == none:
                resp["error"] = "method not found: " + str(method)
            else:
                var params = req["params"]
                var result = fn(params)
                resp["result"] = result
        var wire = json_encode(resp)
        if wire == none:
            var wire = "{}"
        tcp_send(client_fd, wire)
        tcp_close(client_fd)

    def listen(self):
        self.server_fd = tcp_server_create(self.host, self.port)
        if self.server_fd < 0:
            return false
        self.running = true
        print "RpcServer on " + self.host + ":" + str(self.port)
        while self.running:
            var client_fd = tcp_accept(self.server_fd)
            if client_fd >= 0:
                self._handle(client_fd)
        return true

    def stop(self):
        self.running = false

class RpcClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self._call_id = 0

    def call(self, method, params):
        self._call_id = self._call_id + 1
        var req = {}
        req["id"] = self._call_id
        req["method"] = method
        req["params"] = params
        var wire = json_encode(req)
        if wire == none:
            return none
        var fd = socket_create("tcp")
        if fd < 0:
            return none
        var ok = socket_connect(fd, self.host, self.port)
        if ok == false:
            socket_close(fd)
            return none
        tcp_send(fd, wire)
        var resp_raw = tcp_recv_all(fd)
        socket_close(fd)
        if resp_raw == none:
            return none
        var resp = json_decode(resp_raw)
        if resp == none:
            return none
        var err = resp["error"]
        if err != none:
            print "RPC Error: " + str(err)
            return none
        return resp["result"]

# ─── Pub/Sub Broker ──────────────────────────────────────────────────────────

class PubSubBroker:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.topics = {}
        self.topic_counts = {}
        self.clients = {}
        self.client_count = 0
        self.running = false

    def _get_client_id(self, fd):
        return "client_" + str(fd)

    def _subscribe(self, fd, topic):
        var cid = self._get_client_id(fd)
        var count = self.topic_counts[topic]
        if count == none:
            var count = 0
        self.topics[topic + "_" + str(count)] = fd
        self.topic_counts[topic] = count + 1

    def _publish(self, topic, msg):
        var count = self.topic_counts[topic]
        if count == none:
            return
        var i = 0
        while i < count:
            var fd = self.topics[topic + "_" + str(i)]
            if fd != none and fd >= 0:
                tcp_send(fd, msg + "\n")
            i = i + 1

    def _handle(self, client_fd):
        var cid = self._get_client_id(client_fd)
        self.clients[cid] = client_fd
        while true:
            var raw = tcp_recv(client_fd, 4096)
            if raw == none or len(raw) == 0:
                break
            var line = string_strip(raw)
            if string_startswith(line, "SUB "):
                var topic = line[4:]
                self._subscribe(client_fd, topic)
                tcp_send(client_fd, "SUBSCRIBED " + topic + "\n")
            elif string_startswith(line, "PUB "):
                var rest = line[4:]
                var sp = string_find(rest, " ")
                if sp >= 0:
                    var topic = rest[0:sp]
                    var msg = rest[sp + 1:]
                    self._publish(topic, msg)
        self.clients[cid] = none
        tcp_close(client_fd)

    def listen(self):
        var server_fd = tcp_server_create(self.host, self.port)
        if server_fd < 0:
            return false
        self.running = true
        print "PubSubBroker on " + self.host + ":" + str(self.port)
        while self.running:
            var client_fd = tcp_accept(server_fd)
            if client_fd >= 0:
                self._handle(client_fd)
        return true

class PubSubClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.fd = -1
        self._handlers = {}

    def connect(self):
        self.fd = socket_create("tcp")
        if self.fd < 0:
            return false
        return socket_connect(self.fd, self.host, self.port)

    def subscribe(self, topic, handler):
        self._handlers[topic] = handler
        tcp_send(self.fd, "SUB " + topic + "\n")

    def publish(self, topic, msg):
        tcp_send(self.fd, "PUB " + topic + " " + msg + "\n")

    def listen(self):
        while true:
            var raw = tcp_recv(self.fd, 4096)
            if raw == none or len(raw) == 0:
                break
            var line = string_strip(raw)
            var sp = string_find(line, " ")
            if sp >= 0:
                var topic = line[0:sp]
                var msg = line[sp + 1:]
                var h = self._handlers[topic]
                if h != none:
                    h(msg)

    def close(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1

# ─── Chat Server ─────────────────────────────────────────────────────────────

class ChatRoom:
    def __init__(self, name):
        self.name = name
        self.members = {}
        self.member_count = 0
        self.history = []
        self.hist_count = 0
        self.max_history = 100

    def join(self, user_id, conn_fd):
        if conn_fd == none:
            self.members[user_id] = -1
        else:
            self.members[user_id] = conn_fd
        self.member_count = self.member_count + 1
        self.broadcast("SYSTEM", user_id + " joined")

    def is_member(self, user_id):
        var v = self.members[user_id]
        return v != none

    def leave(self, user_id):
        self.members[user_id] = none
        self.member_count = self.member_count - 1
        self.broadcast("SYSTEM", user_id + " left")

    def broadcast(self, from_user, text):
        var msg = "[" + from_user + "] " + text
        if self.hist_count < self.max_history:
            self.history[self.hist_count] = msg
            self.hist_count = self.hist_count + 1
        var all_users = keys(self.members)
        var i = 0
        while i < len(all_users):
            var fd = self.members[all_users[i]]
            if fd != none and fd >= 0:
                tcp_send(fd, msg + "\n")
            i = i + 1

    def send_history(self, conn_fd):
        var i = 0
        while i < self.hist_count:
            tcp_send(conn_fd, self.history[i] + "\n")
            i = i + 1

class ChatServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.rooms = {}
        self.clients = {}
        self.client_names = {}
        self.running = false

    def get_or_create_room(self, name):
        var r = self.rooms[name]
        if r == none:
            var r = ChatRoom(name)
            self.rooms[name] = r
        return r

    def _handle(self, client_fd):
        tcp_send(client_fd, "NICK? ")
        var nick_raw = tcp_recv(client_fd, 64)
        if nick_raw == none:
            tcp_close(client_fd)
            return
        var nick = string_strip(nick_raw)
        self.client_names[str(client_fd)] = nick
        tcp_send(client_fd, "Welcome " + nick + "!\n")
        var room = self.get_or_create_room("general")
        room.join(nick, client_fd)
        while true:
            var raw = tcp_recv(client_fd, 1024)
            if raw == none or len(raw) == 0:
                break
            var line = string_strip(raw)
            if string_startswith(line, "/join "):
                var room_name = line[6:]
                room.leave(nick)
                var room = self.get_or_create_room(room_name)
                room.join(nick, client_fd)
                room.send_history(client_fd)
            elif string_startswith(line, "/quit"):
                break
            else:
                room.broadcast(nick, line)
        room.leave(nick)
        self.client_names[str(client_fd)] = none
        tcp_close(client_fd)

    def listen(self):
        var server_fd = tcp_server_create(self.host, self.port)
        if server_fd < 0:
            return false
        self.running = true
        print "ChatServer on " + self.host + ":" + str(self.port)
        while self.running:
            var client_fd = tcp_accept(server_fd)
            if client_fd >= 0:
                self._handle(client_fd)
        return true

# ─── File Transfer ────────────────────────────────────────────────────────────

class FileServer:
    def __init__(self, host, port, root_dir):
        self.host = host
        self.port = port
        self.root_dir = root_dir
        self.running = false

    def _handle(self, client_fd):
        var raw = tcp_recv(client_fd, 256)
        if raw == none:
            tcp_close(client_fd)
            return
        var filename = string_strip(raw)
        var filepath = self.root_dir + "/" + filename
        var content = read_file(filepath)
        if content == none:
            tcp_send(client_fd, "ERROR:NOT_FOUND")
        else:
            var header = "SIZE:" + str(len(content)) + "\n"
            tcp_send(client_fd, header + content)
        tcp_close(client_fd)

    def listen(self):
        var server_fd = tcp_server_create(self.host, self.port)
        if server_fd < 0:
            return false
        self.running = true
        while self.running:
            var client_fd = tcp_accept(server_fd)
            if client_fd >= 0:
                self._handle(client_fd)
        return true

class FileClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port

    def download(self, filename, save_path):
        var fd = socket_create("tcp")
        if fd < 0:
            return false
        var ok = socket_connect(fd, self.host, self.port)
        if ok == false:
            socket_close(fd)
            return false
        tcp_send(fd, filename)
        var resp = tcp_recv_all(fd)
        socket_close(fd)
        if resp == none or string_startswith(resp, "ERROR"):
            return false
        var nl = string_find(resp, "\n")
        if nl < 0:
            return false
        var content = resp[nl + 1:]
        return write_file(save_path, content)

# ─── Health Check / Heartbeat ─────────────────────────────────────────────────

class HeartbeatServer:
    def __init__(self, host, port, interval_ms):
        self.host = host
        self.port = port
        self.interval_ms = interval_ms
        self.clients = {}
        self.client_count = 0
        self.running = false

    def _send_beats(self):
        while self.running:
            thread_sleep(self.interval_ms)
            var ts = str(time_now())
            var all_ids = keys(self.clients)
            var i = 0
            while i < len(all_ids):
                var fd = self.clients[all_ids[i]]
                if fd != none:
                    var ok = tcp_send(fd, "PING " + ts + "\n")
                    if ok == false:
                        self.clients[all_ids[i]] = none
                i = i + 1

    def _accept_loop(self):
        var server_fd = tcp_server_create(self.host, self.port)
        if server_fd < 0:
            return
        self.running = true
        while self.running:
            var client_fd = tcp_accept(server_fd)
            if client_fd >= 0:
                var cid = "c_" + str(client_fd)
                self.clients[cid] = client_fd
                self.client_count = self.client_count + 1

    def start(self):
        self._accept_loop()

class HeartbeatClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.fd = -1
        self.last_beat = 0.0
        self.alive = false
        self.on_beat_handler = none

    def on_beat(self, fn):
        self.on_beat_handler = fn

    def connect(self):
        self.fd = socket_create("tcp")
        if self.fd < 0:
            return false
        var ok = socket_connect(self.fd, self.host, self.port)
        if ok:
            self.alive = true
        return ok

    def listen(self):
        while self.alive:
            var raw = tcp_recv(self.fd, 64)
            if raw == none or len(raw) == 0:
                self.alive = false
                break
            if string_startswith(raw, "PING"):
                self.last_beat = time_now()
                if self.on_beat_handler != none:
                    self.on_beat_handler(self.last_beat)

    def close(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1
        self.alive = false

# ─── Pipeline ─────────────────────────────────────────────────────────────────

class PipelineStage:
    def __init__(self, name, fn):
        self.name = name
        self.fn = fn
        self.enabled = true
        self.processed = 0
        self.errors = 0


class Pipeline:
    def __init__(self, name):
        self.name = name
        self.stages = []
        self.stage_count = 0
        self.processed = 0
        self.failed = 0
        self._on_error = none
        self._on_success = none

    def add_stage(self, name, fn):
        var stage = PipelineStage(name, fn)
        self.stages.append(stage)
        self.stage_count = self.stage_count + 1
        return self

    def on_error(self, fn):
        self._on_error = fn
        return self

    def on_success(self, fn):
        self._on_success = fn
        return self

    def disable_stage(self, name):
        var i = 0
        while i < self.stage_count:
            if self.stages[i].name == name:
                self.stages[i].enabled = false
            i = i + 1
        return self

    def enable_stage(self, name):
        var i = 0
        while i < self.stage_count:
            if self.stages[i].name == name:
                self.stages[i].enabled = true
            i = i + 1
        return self

    def execute(self, data):
        var current = data
        var i = 0
        while i < self.stage_count:
            var stage = self.stages[i]
            if stage.enabled:
                var result = stage.fn(current)
                stage.processed = stage.processed + 1
                if result == none:
                    stage.errors = stage.errors + 1
                    self.failed = self.failed + 1
                    if self._on_error != none:
                        self._on_error(stage.name, current)
                    return none
                var current = result
            i = i + 1
        self.processed = self.processed + 1
        if self._on_success != none:
            self._on_success(current)
        return current

    def stats(self):
        var s = {}
        s["name"] = self.name
        s["processed"] = self.processed
        s["failed"] = self.failed
        s["stages"] = self.stage_count
        return s


# ─── LoadBalancer ─────────────────────────────────────────────────────────────

class BackendServer:
    def __init__(self, host, port, weight):
        self.host = host
        self.port = port
        self.weight = weight
        self.healthy = true
        self.active_connections = 0
        self.total_requests = 0
        self.failed_requests = 0

    def address(self):
        return self.host + ":" + str(self.port)


class LoadBalancer:
    def __init__(self, strategy):
        self.strategy = strategy
        self.backends = []
        self.backend_count = 0
        self._rr_index = 0
        self.total_requests = 0

    def add_backend(self, host, port, weight):
        var b = BackendServer(host, port, weight)
        self.backends.append(b)
        self.backend_count = self.backend_count + 1
        return self

    def remove_backend(self, host, port):
        var kept = []
        var i = 0
        while i < self.backend_count:
            var b = self.backends[i]
            if b.host != host or b.port != port:
                kept.append(b)
            i = i + 1
        self.backends = kept
        self.backend_count = len(kept)
        return self

    def mark_unhealthy(self, host, port):
        var i = 0
        while i < self.backend_count:
            if self.backends[i].host == host and self.backends[i].port == port:
                self.backends[i].healthy = false
            i = i + 1

    def mark_healthy(self, host, port):
        var i = 0
        while i < self.backend_count:
            if self.backends[i].host == host and self.backends[i].port == port:
                self.backends[i].healthy = true
            i = i + 1

    def _healthy_backends(self):
        var result = []
        var i = 0
        while i < self.backend_count:
            if self.backends[i].healthy:
                result.append(self.backends[i])
            i = i + 1
        return result

    def next(self):
        var healthy = self._healthy_backends()
        if len(healthy) == 0:
            return none
        self.total_requests = self.total_requests + 1
        if self.strategy == "round_robin":
            var idx = self._rr_index % len(healthy)
            self._rr_index = self._rr_index + 1
            healthy[idx].total_requests = healthy[idx].total_requests + 1
            return healthy[idx]
        elif self.strategy == "least_conn":
            var best = healthy[0]
            var i = 1
            while i < len(healthy):
                if healthy[i].active_connections < best.active_connections:
                    var best = healthy[i]
                i = i + 1
            best.total_requests = best.total_requests + 1
            return best
        elif self.strategy == "random":
            var idx = int(time_ms()) % len(healthy)
            healthy[idx].total_requests = healthy[idx].total_requests + 1
            return healthy[idx]
        var idx = self._rr_index % len(healthy)
        self._rr_index = self._rr_index + 1
        return healthy[idx]

    def healthy_count(self):
        return len(self._healthy_backends())

    def stats(self):
        var s = {}
        s["total_backends"] = self.backend_count
        s["healthy"] = self.healthy_count()
        s["total_requests"] = self.total_requests
        s["strategy"] = self.strategy
        return s


# ─── ServiceRegistry ──────────────────────────────────────────────────────────

class ServiceInstance:
    def __init__(self, name, host, port, metadata):
        self.name = name
        self.host = host
        self.port = port
        self.metadata = metadata
        self.registered_at = time_now()
        self.last_heartbeat = time_now()
        self.healthy = true
        self.id = name + "_" + host + "_" + str(port)


class ServiceRegistry:
    def __init__(self):
        self.services = {}
        self.instances = []
        self.instance_count = 0
        self.ttl = 30.0

    def register(self, name, host, port, metadata):
        var svc = ServiceInstance(name, host, port, metadata)
        self.services[svc.id] = svc
        self.instances.append(svc)
        self.instance_count = self.instance_count + 1
        return svc.id

    def deregister(self, service_id):
        var svc = self.services[service_id]
        if svc != none:
            self.services[service_id] = none
            var kept = []
            var i = 0
            while i < self.instance_count:
                if self.instances[i].id != service_id:
                    kept.append(self.instances[i])
                i = i + 1
            self.instances = kept
            self.instance_count = len(kept)

    def heartbeat(self, service_id):
        var svc = self.services[service_id]
        if svc != none:
            svc.last_heartbeat = time_now()
            svc.healthy = true

    def get(self, name):
        var results = []
        var i = 0
        while i < self.instance_count:
            var svc = self.instances[i]
            if svc.name == name and svc.healthy:
                results.append(svc)
            i = i + 1
        return results

    def get_one(self, name):
        var matches = self.get(name)
        if len(matches) == 0:
            return none
        return matches[int(time_ms()) % len(matches)]

    def expire_stale(self):
        var now = time_now()
        var i = 0
        while i < self.instance_count:
            var age = now - self.instances[i].last_heartbeat
            if age > self.ttl:
                self.instances[i].healthy = false
            i = i + 1

    def all_services(self):
        var seen = {}
        var names = []
        var i = 0
        while i < self.instance_count:
            var n = self.instances[i].name
            if seen[n] == none:
                seen[n] = true
                names.append(n)
            i = i + 1
        return names

    def count(self):
        return self.instance_count

    def healthy_count(self):
        var c = 0
        var i = 0
        while i < self.instance_count:
            if self.instances[i].healthy:
                c = c + 1
            i = i + 1
        return c


# ─── EventLog ─────────────────────────────────────────────────────────────────

class LogEntry:
    def __init__(self, level, source, message, data):
        self.level = level
        self.source = source
        self.message = message
        self.data = data
        self.timestamp = time_now()
        self.id = str(int(time_ms()))


class EventLog:
    def __init__(self, max_entries):
        self.entries = []
        self.entry_count = 0
        self.max_entries = max_entries
        self.level_counts = {}
        self._subscribers = []
        self._sub_count = 0

    def _log(self, level, source, message, data):
        var entry = LogEntry(level, source, message, data)
        if self.entry_count >= self.max_entries:
            var trimmed = []
            var i = 1
            while i < self.entry_count:
                trimmed.append(self.entries[i])
                i = i + 1
            self.entries = trimmed
            self.entry_count = self.entry_count - 1
        self.entries.append(entry)
        self.entry_count = self.entry_count + 1
        var count = self.level_counts[level]
        if count == none:
            var count = 0
        self.level_counts[level] = count + 1
        var i = 0
        while i < self._sub_count:
            self._subscribers[i](entry)
            i = i + 1
        return entry

    def info(self, source, message):
        return self._log("INFO", source, message, none)

    def warn(self, source, message):
        return self._log("WARN", source, message, none)

    def error(self, source, message):
        return self._log("ERROR", source, message, none)

    def debug(self, source, message):
        return self._log("DEBUG", source, message, none)

    def event(self, source, message, data):
        return self._log("EVENT", source, message, data)

    def subscribe(self, fn):
        self._subscribers.append(fn)
        self._sub_count = self._sub_count + 1

    def filter_by_level(self, level):
        var result = []
        var i = 0
        while i < self.entry_count:
            if self.entries[i].level == level:
                result.append(self.entries[i])
            i = i + 1
        return result

    def filter_by_source(self, source):
        var result = []
        var i = 0
        while i < self.entry_count:
            if self.entries[i].source == source:
                result.append(self.entries[i])
            i = i + 1
        return result

    def last(self, n):
        if n >= self.entry_count:
            return self.entries
        var result = []
        var start = self.entry_count - n
        var i = start
        while i < self.entry_count:
            result.append(self.entries[i])
            i = i + 1
        return result

    def clear(self):
        self.entries = []
        self.entry_count = 0
        self.level_counts = {}

    def stats(self):
        var s = {}
        s["total"] = self.entry_count
        s["info"] = self.level_counts["INFO"]
        s["warn"] = self.level_counts["WARN"]
        s["error"] = self.level_counts["ERROR"]
        s["debug"] = self.level_counts["DEBUG"]
        return s


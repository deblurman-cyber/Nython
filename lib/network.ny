# ═══════════════════════════════════════════════════════════════════════════════
# network.ny — Nython Network Library
# HTTP client, REST client, WebSocket, rate limiting, connection pool
# Usage: import "lib/network.ny"
# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import net

# ─── URL ─────────────────────────────────────────────────────────────────────

class URL:
    def __init__(self, raw):
        self.raw = raw
        self.scheme = "http"
        self.host = ""
        self.port = 80
        self.path = "/"
        self.query = ""
        self.fragment = ""
        self._parse(raw)

    def _parse(self, raw):
        var rest = raw
        if string_contains(rest, "://"):
            var colon_pos = string_find(rest, "://")
            self.scheme = rest[0:colon_pos]
            var rest = rest[colon_pos+3:len(rest)]
            if self.scheme == "https":
                self.port = 443
        if string_contains(rest, "#"):
            var hash_pos = string_find(rest, "#")
            self.fragment = rest[hash_pos+1:len(rest)]
            rest = rest[0:hash_pos]
        if string_contains(rest, "?"):
            var q_pos = string_find(rest, "?")
            self.query = rest[q_pos+1:len(rest)]
            rest = rest[0:q_pos]
        var slash_pos = string_find(rest, "/")
        if slash_pos >= 0:
            self.path = rest[slash_pos:len(rest)]
            rest = rest[0:slash_pos]
        else:
            self.path = "/"
        if string_contains(rest, ":"):
            var colon = string_find(rest, ":")
            self.host = rest[0:colon]
            self.port = int(rest[colon+1:len(rest)])
        else:
            self.host = rest

    def to_str(self):
        var s = self.scheme + "://" + self.host
        if self.scheme == "http" and self.port != 80:
            s = s + ":" + str(self.port)
        elif self.scheme == "https" and self.port != 443:
            s = s + ":" + str(self.port)
        s = s + self.path
        if self.query != "":
            s = s + "?" + self.query
        if self.fragment != "":
            s = s + "#" + self.fragment
        return s

    def origin(self):
        return self.scheme + "://" + self.host

# ─── Headers ─────────────────────────────────────────────────────────────────

class Headers:
    def __init__(self):
        self.data = {}
        self._keys = []

    def set(self, name, value):
        var lower = string_lower(name)
        if not self.has(name):
            self._keys.append(lower)
        self.data[lower] = value

    def get(self, name):
        var v = self.data[string_lower(name)]
        if v == none:
            return ""
        return v

    def has(self, name):
        var lower = string_lower(name)
        var i = 0
        while i < len(self._keys):
            if self._keys[i] == lower:
                return true
            i = i + 1
        return false

    def delete(self, name):
        var lower = string_lower(name)
        self.data[lower] = none
        var new_keys = []
        var i = 0
        while i < len(self._keys):
            if self._keys[i] != lower:
                new_keys.append(self._keys[i])
            i = i + 1
        self._keys = new_keys

    def count(self):
        return len(self._keys)

    def all(self):
        return self._keys

    def to_str(self):
        var result = ""
        var i = 0
        while i < len(self._keys):
            var k = self._keys[i]
            result = result + k + ": " + str(self.data[k]) + "\r\n"
            i = i + 1
        return result

    def default_request(self):
        self.set("Content-Type", "application/json")
        self.set("Accept", "application/json")
        self.set("User-Agent", "Nython/3.0")

# ─── Response ────────────────────────────────────────────────────────────────

class Response:
    def __init__(self, status, reason, body):
        self.status = status
        self.reason = reason
        self.body = body
        self.headers = Headers()

    def is_ok(self):
        return self.status >= 200 and self.status < 300

    def is_success(self):
        return self.is_ok()

    def is_redirect(self):
        return self.status >= 300 and self.status < 400

    def is_client_error(self):
        return self.status >= 400 and self.status < 500

    def is_server_error(self):
        return self.status >= 500

    def is_error(self):
        return self.status >= 400

    def json(self):
        return json_decode(self.body)

    def text(self):
        return self.body

# ─── HttpClient ───────────────────────────────────────────────────────────────

class HttpClient:
    def __init__(self):
        self.base_url = ""
        self.timeout = 30
        self.retries = 3
        self.retry_delay = 1.0
        self.auth_token = ""
        self.default_headers = Headers()
        self.default_headers.default_request()

    def set_base_url(self, url):
        self.base_url = url

    def set_timeout(self, secs):
        self.timeout = secs

    def set_auth(self, token):
        self.auth_token = token
        self.default_headers.set("Authorization", token)

    def set_header(self, name, value):
        self.default_headers.set(name, value)

    def _make_url(self, path):
        if string_startswith(path, "http"):
            return path
        return self.base_url + path

    def get(self, path):
        var url = self._make_url(path)
        var raw = http_get(url)
        if raw == none:
            return Response(0, "Connection Failed", "")
        return Response(200, "OK", raw)

    def post(self, path, body):
        var url = self._make_url(path)
        var raw = http_post(url, body)
        if raw == none:
            return Response(0, "Connection Failed", "")
        return Response(200, "OK", raw)

    def put(self, path, body):
        var url = self._make_url(path)
        var raw = http_request("PUT", url, body)
        if raw == none:
            return Response(0, "Connection Failed", "")
        return Response(200, "OK", raw)

    def delete_req(self, path):
        var url = self._make_url(path)
        var raw = http_request("DELETE", url, "")
        if raw == none:
            return Response(0, "Connection Failed", "")
        return Response(200, "OK", raw)

    def request(self, method, path, body):
        var url = self._make_url(path)
        var raw = http_request(method, url, body)
        if raw == none:
            return Response(0, "Connection Failed", "")
        return Response(200, "OK", raw)

# ─── RestClient ──────────────────────────────────────────────────────────────

class RestClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.auth_token = ""
        self.headers = Headers()
        self.headers.default_request()

    def set_auth(self, token):
        self.auth_token = token
        self.headers.set("Authorization", "Bearer " + token)

    def set_header(self, name, value):
        self.headers.set(name, value)

    def get(self, path):
        var url = self.base_url + path
        var raw = http_get(url)
        if raw == none:
            return none
        return json_decode(raw)

    def post(self, path, data):
        var url = self.base_url + path
        var body = json_encode(data)
        var raw = http_post(url, body)
        if raw == none:
            return none
        return json_decode(raw)

    def put(self, path, data):
        var url = self.base_url + path
        var body = json_encode(data)
        var raw = http_request("PUT", url, body)
        if raw == none:
            return none
        return json_decode(raw)

    def delete_req(self, path):
        var url = self.base_url + path
        var raw = http_request("DELETE", url, "")
        if raw == none:
            return none
        return json_decode(raw)

    def patch(self, path, data):
        var url = self.base_url + path
        var body = json_encode(data)
        var raw = http_request("PATCH", url, body)
        if raw == none:
            return none
        return json_decode(raw)

# ─── DNS ────────────────────────────────────────────────────────────────────

class DNS:
    def __init__(self):
        self.cache = {}

    def resolve(self, hostname):
        var cached = self.cache[hostname]
        if cached != none:
            return cached
        var ip = dns_resolve(hostname)
        if ip != none and ip != "":
            self.cache[hostname] = ip
        return ip

    def lookup(self, hostname):
        return self.resolve(hostname)

    def clear_cache(self):
        self.cache = {}

    def is_valid_ip(self, ip):
        var parts = string_split(ip, ".")
        if len(parts) != 4:
            return false
        var i = 0
        while i < 4:
            var n = int(parts[i])
            if n < 0 or n > 255:
                return false
            i = i + 1
        return true

# ─── RateLimiter ─────────────────────────────────────────────────────────────

class RateLimiter:
    def __init__(self, max_calls, period_seconds):
        self.max_calls = max_calls
        self.period = period_seconds
        self.calls = []
        self.call_count = 0

    def allow(self):
        var now = time_now()
        var cutoff = now - self.period
        var new_calls = []
        var i = 0
        while i < self.call_count:
            if self.calls[i] > cutoff:
                new_calls.append(self.calls[i])
            i = i + 1
        self.calls = new_calls
        self.call_count = len(new_calls)
        if self.call_count < self.max_calls:
            self.calls.append(now)
            self.call_count = self.call_count + 1
            return true
        return false

    def remaining(self):
        return self.max_calls - self.call_count

    def reset(self):
        self.calls = []
        self.call_count = 0

# ─── ConnectionPool ──────────────────────────────────────────────────────────

class ConnectionPool:
    def __init__(self, host, port, max_size):
        self.host = host
        self.port = port
        self.max_size = max_size
        self.connections = []
        self.conn_count = 0
        self.active = 0

    def active_count(self):
        return self.active

    def available_count(self):
        return self.max_size - self.active

    def acquire(self):
        if self.active < self.max_size:
            var conn = tcp_connect(self.host, self.port)
            if conn != none:
                self.connections.append(conn)
                self.conn_count = self.conn_count + 1
                self.active = self.active + 1
                return conn
        return none

    def release(self, conn):
        if self.active > 0:
            self.active = self.active - 1

    def close_all(self):
        var i = 0
        while i < self.conn_count:
            tcp_close(self.connections[i])
            i = i + 1
        self.connections = []
        self.conn_count = 0
        self.active = 0

# ─── MimeTypes ───────────────────────────────────────────────────────────────

class MimeTypes:
    def __init__(self):
        self.types = {}
        self.types[".html"] = "text/html"
        self.types[".htm"]  = "text/html"
        self.types[".css"]  = "text/css"
        self.types[".js"]   = "application/javascript"
        self.types[".json"] = "application/json"
        self.types[".xml"]  = "application/xml"
        self.types[".txt"]  = "text/plain"
        self.types[".md"]   = "text/markdown"
        self.types[".png"]  = "image/png"
        self.types[".jpg"]  = "image/jpeg"
        self.types[".jpeg"] = "image/jpeg"
        self.types[".gif"]  = "image/gif"
        self.types[".svg"]  = "image/svg+xml"
        self.types[".ico"]  = "image/x-icon"
        self.types[".webp"] = "image/webp"
        self.types[".mp3"]  = "audio/mpeg"
        self.types[".mp4"]  = "video/mp4"
        self.types[".pdf"]  = "application/pdf"
        self.types[".zip"]  = "application/zip"
        self.types[".wasm"] = "application/wasm"
        self.types[".ny"]   = "text/x-nython"
        self.types[".py"]   = "text/x-python"
        self.types[".ts"]   = "application/typescript"

    def get(self, ext):
        var m = self.types[ext]
        if m == none:
            return "application/octet-stream"
        return m

    def get_for_path(self, path):
        var last_dot = 0
        var i = len(path) - 1
        while i >= 0:
            if path[i] == ".":
                var last_dot = i
                var i = -1
            i = i - 1
        var ext = path[last_dot:len(path)]
        return self.get(ext)

    def register(self, ext, mime):
        self.types[ext] = mime

# ─── EventSource (SSE client) ────────────────────────────────────────────────

class EventSource:
    def __init__(self, url):
        self.url = url
        self.handlers = {}
        self.running = false
        self.reconnect_delay = 3.0

    def on(self, event_type, handler):
        self.handlers[event_type] = handler

    def off(self, event_type):
        self.handlers[event_type] = none

    def connect(self):
        self.running = true

    def disconnect(self):
        self.running = false

    def _dispatch(self, event_type, data):
        var h = self.handlers[event_type]
        if h != none:
            h(data)

# ─── WebSocket ────────────────────────────────────────────────────────────────

class WebSocket:
    def __init__(self, url):
        self.url = url
        self.conn = none
        self.on_message = none
        self.on_open = none
        self.on_close = none
        self.on_error = none
        self.connected = false

    def connect(self):
        var u = URL(self.url)
        self.conn = tcp_connect(u.host, u.port)
        if self.conn != none:
            self.connected = true
            if self.on_open != none:
                self.on_open()
        return self.connected

    def send(self, message):
        if self.connected and self.conn != none:
            return tcp_send(self.conn, message)
        return false

    def recv(self):
        if self.connected and self.conn != none:
            return tcp_recv(self.conn, 4096)
        return none

    def close(self):
        if self.conn != none:
            tcp_close(self.conn)
        self.connected = false
        if self.on_close != none:
            self.on_close()

    def is_connected(self):
        return self.connected

# ─── Retry ───────────────────────────────────────────────────────────────────

class Retry:
    def __init__(self, max_attempts, delay_ms, backoff_factor):
        self.max_attempts = max_attempts
        self.delay_ms = delay_ms
        self.backoff_factor = backoff_factor
        self.attempt_count = 0
        self.last_error = ""
        self._on_retry = none

    def on_retry(self, fn):
        self._on_retry = fn
        return self

    def execute(self, fn):
        self.attempt_count = 0
        var current_delay = self.delay_ms
        var i = 0
        while i < self.max_attempts:
            self.attempt_count = self.attempt_count + 1
            var result = fn()
            if result != none:
                return result
            self.last_error = "Attempt " + str(self.attempt_count) + " failed"
            if self._on_retry != none:
                self._on_retry(self.attempt_count, self.last_error)
            if i < self.max_attempts - 1:
                thread_sleep(int(current_delay))
                current_delay = current_delay * self.backoff_factor
            i = i + 1
        return none

    def reset(self):
        self.attempt_count = 0
        self.last_error = ""
        return self

    def remaining(self):
        return self.max_attempts - self.attempt_count

# ─── HttpCache ────────────────────────────────────────────────────────────────

class CacheEntry:
    def __init__(self, response, ttl_seconds):
        self.response = response
        self.created_at = time_now()
        self.ttl = ttl_seconds
        self.hit_count = 0

    def is_expired(self):
        return (time_now() - self.created_at) > self.ttl

    def touch(self):
        self.hit_count = self.hit_count + 1


class HttpCache:
    def __init__(self, default_ttl):
        self.default_ttl = default_ttl
        self.entries = {}
        self.entry_count = 0
        self.hit_count = 0
        self.miss_count = 0
        self.max_entries = 1000

    def get(self, url):
        var entry = self.entries[url]
        if entry == none:
            self.miss_count = self.miss_count + 1
            return none
        if entry.is_expired():
            self.entries[url] = none
            self.entry_count = self.entry_count - 1
            self.miss_count = self.miss_count + 1
            return none
        entry.touch()
        self.hit_count = self.hit_count + 1
        return entry.response

    def set(self, url, response, ttl):
        var existing = self.entries[url]
        if existing == none and self.entry_count >= self.max_entries:
            return
        if existing == none:
            self.entry_count = self.entry_count + 1
        self.entries[url] = CacheEntry(response, ttl)

    def set_default(self, url, response):
        self.set(url, response, self.default_ttl)

    def invalidate(self, url):
        if self.entries[url] != none:
            self.entries[url] = none
            self.entry_count = self.entry_count - 1

    def clear(self):
        self.entries = {}
        self.entry_count = 0

    def hit_rate(self):
        var total = self.hit_count + self.miss_count
        if total == 0:
            return 0.0
        return float(self.hit_count) / float(total)

    def stats(self):
        var s = {}
        s["entries"] = self.entry_count
        s["hits"] = self.hit_count
        s["misses"] = self.miss_count
        s["hit_rate"] = self.hit_rate()
        return s

# ─── OAuth2Client ──────────────────────────────────────────────────────────────

class OAuth2Client:
    def __init__(self, client_id, client_secret, token_url):
        self.client_id = client_id
        self.client_secret = client_secret
        self.token_url = token_url
        self.access_token = ""
        self.refresh_token = ""
        self.token_type = "Bearer"
        self.expires_at = 0.0
        self.scope = ""

    def is_expired(self):
        if self.expires_at == 0.0:
            return true
        return time_now() >= self.expires_at

    def set_token(self, access_token, expires_in, refresh_token):
        self.access_token = access_token
        self.expires_at = time_now() + float(expires_in)
        if refresh_token != "":
            self.refresh_token = refresh_token

    def get_header(self):
        return self.token_type + " " + self.access_token

    def auth_code_url(self, redirect_uri, state, scopes):
        var scope_str = string_join(scopes, " ")
        var url = self.token_url + "?response_type=code"
        url = url + "&client_id=" + self.client_id
        url = url + "&redirect_uri=" + redirect_uri
        url = url + "&scope=" + scope_str
        url = url + "&state=" + state
        return url

    def client_credentials(self):
        var body = "grant_type=client_credentials"
        body = body + "&client_id=" + self.client_id
        body = body + "&client_secret=" + self.client_secret
        var raw = http_post(self.token_url, body)
        if raw == none:
            return false
        var data = json_decode(raw)
        if data == none:
            return false
        self.set_token(data["access_token"], data["expires_in"], "")
        return true

    def refresh(self):
        if self.refresh_token == "":
            return false
        var body = "grant_type=refresh_token"
        body = body + "&refresh_token=" + self.refresh_token
        body = body + "&client_id=" + self.client_id
        body = body + "&client_secret=" + self.client_secret
        var raw = http_post(self.token_url, body)
        if raw == none:
            return false
        var data = json_decode(raw)
        if data == none:
            return false
        self.set_token(data["access_token"], data["expires_in"], self.refresh_token)
        return true

# ─── GraphQL Client ───────────────────────────────────────────────────────────

class GraphQLClient:
    def __init__(self, endpoint):
        self.endpoint = endpoint
        self.headers = Headers()
        self.headers.set("Content-Type", "application/json")
        self.headers.set("Accept", "application/json")

    def set_auth(self, token):
        self.headers.set("Authorization", "Bearer " + token)
        return self

    def set_header(self, name, value):
        self.headers.set(name, value)
        return self

    def query(self, gql_query, variables):
        var payload = {}
        payload["query"] = gql_query
        if variables != none:
            payload["variables"] = variables
        var body = json_encode(payload)
        var raw = http_post(self.endpoint, body)
        if raw == none:
            return none
        var result = json_decode(raw)
        if result == none:
            return none
        return result["data"]

    def mutation(self, gql_mutation, variables):
        return self.query(gql_mutation, variables)

    def introspect(self):
        var q = "{ __schema { types { name } } }"
        return self.query(q, none)

# ─── RequestQueue ─────────────────────────────────────────────────────────────

class QueuedRequest:
    def __init__(self, method, url, body, callback):
        self.method = method
        self.url = url
        self.body = body
        self.callback = callback
        self.priority = 0
        self.id = str(int(time_ms()))


class RequestQueue:
    def __init__(self, max_concurrent):
        self.max_concurrent = max_concurrent
        self.queue = []
        self.queue_size = 0
        self.active = 0
        self.completed = 0
        self.failed = 0

    def enqueue(self, method, url, body, callback):
        var req = QueuedRequest(method, url, body, callback)
        self.queue.append(req)
        self.queue_size = self.queue_size + 1
        return req.id

    def enqueue_get(self, url, callback):
        return self.enqueue("GET", url, "", callback)

    def enqueue_post(self, url, body, callback):
        return self.enqueue("POST", url, body, callback)

    def _process_next(self):
        if self.queue_size == 0 or self.active >= self.max_concurrent:
            return
        var req = self.queue[0]
        var new_queue = []
        var i = 1
        while i < self.queue_size:
            new_queue.append(self.queue[i])
            i = i + 1
        self.queue = new_queue
        self.queue_size = self.queue_size - 1
        self.active = self.active + 1
        var raw = none
        if req.method == "GET":
            var raw = http_get(req.url)
        else:
            raw = http_post(req.url, req.body)
        self.active = self.active - 1
        if raw != none:
            self.completed = self.completed + 1
            if req.callback != none:
                req.callback(Response(200, "OK", raw))
        else:
            self.failed = self.failed + 1
            if req.callback != none:
                req.callback(Response(0, "Failed", ""))

    def flush(self):
        while self.queue_size > 0:
            self._process_next()

    def pending(self):
        return self.queue_size

    def stats(self):
        var s = {}
        s["pending"] = self.queue_size
        s["active"] = self.active
        s["completed"] = self.completed
        s["failed"] = self.failed
        return s

# ─── Webhook ──────────────────────────────────────────────────────────────────

class WebhookPayload:
    def __init__(self, event_type, data, secret):
        self.event_type = event_type
        self.data = data
        self.secret = secret
        self.timestamp = int(time_now())
        self.id = "whk_" + str(self.timestamp)

    def to_json(self):
        var p = {}
        p["id"] = self.id
        p["event"] = self.event_type
        p["data"] = self.data
        p["timestamp"] = self.timestamp
        return json_encode(p)


class WebhookSender:
    def __init__(self, secret):
        self.secret = secret
        self.sent = 0
        self.failed = 0
        self.endpoints = []
        self.endpoint_count = 0

    def add_endpoint(self, url):
        self.endpoints.append(url)
        self.endpoint_count = self.endpoint_count + 1
        return self

    def send(self, url, event_type, data):
        var payload = WebhookPayload(event_type, data, self.secret)
        var body = payload.to_json()
        var resp = http_post(url, body)
        if resp != none:
            self.sent = self.sent + 1
            return true
        self.failed = self.failed + 1
        return false

    def broadcast(self, event_type, data):
        var success_count = 0
        var i = 0
        while i < self.endpoint_count:
            if self.send(self.endpoints[i], event_type, data):
                success_count = success_count + 1
            i = i + 1
        return success_count


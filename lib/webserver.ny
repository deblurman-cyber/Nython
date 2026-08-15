# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import net

# webserver.ny — Nython Web Server Library
# HTTP/1.1 server, routing, middleware, static files, sessions, templating
# Usage: import "lib/webserver.ny"
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Request ─────────────────────────────────────────────────────────────────

class Request:
    def __init__(self, raw, client_fd):
        self.raw = raw
        self.client_fd = client_fd
        self.method = "GET"
        self.path = "/"
        self.query_string = ""
        self.params = {}
        self.headers = {}
        self.body = ""
        self.version = "HTTP/1.1"
        self.remote_addr = ""
        self._parse(raw)

    def _parse(self, raw):
        if raw == none or len(raw) == 0:
            return
        var parsed = http_parse_request(raw)
        if parsed == none:
            var lines = string_split(raw, "\n")
            if len(lines) > 0:
                var first = string_strip(lines[0])
                var parts = string_split(first, " ")
                if len(parts) >= 1:
                    self.method = parts[0]
                if len(parts) >= 2:
                    var full_path = parts[1]
                    if string_contains(full_path, "?"):
                        var pq = string_split(full_path, "?")
                        self.path = pq[0]
                        self.query_string = pq[1]
                    else:
                        self.path = full_path
                if len(parts) >= 3:
                    self.version = parts[2]
        else:
            self.method = parsed["method"]
            self.path = parsed["path"]
            self.body = parsed["body"]
            if parsed["query"] != none:
                self.query_string = parsed["query"]

    def query(self, key):
        if len(self.query_string) == 0:
            return ""
        var pairs = string_split(self.query_string, "&")
        var i = 0
        while i < len(pairs):
            var pair = string_split(pairs[i], "=")
            if len(pair) >= 2 and pair[0] == key:
                return pair[1]
            i = i + 1
        return ""

    def json_body(self):
        return json_decode(self.body)

    def form_value(self, key):
        return self.query_params_from(self.body, key)

    def query_params_from(self, s, key):
        var pairs = string_split(s, "&")
        var i = 0
        while i < len(pairs):
            var pair = string_split(pairs[i], "=")
            if len(pair) >= 2 and pair[0] == key:
                return pair[1]
            i = i + 1
        return ""

    def header(self, name):
        var val = self.headers[string_lower(name)]
        if val == none:
            return ""
        return val

    def is_json(self):
        var ct = self.header("content-type")
        return string_contains(ct, "application/json")

    def is_form(self):
        var ct = self.header("content-type")
        return string_contains(ct, "application/x-www-form-urlencoded")

# ─── Response Writer ──────────────────────────────────────────────────────────

class ResponseWriter:
    def __init__(self, client_fd):
        self.client_fd = client_fd
        self.status = 200
        self.headers = {}
        self.headers["Content-Type"] = "text/html; charset=utf-8"
        self.headers["Server"] = "Nython/3.0"
        self._sent = false

    def set_status(self, code):
        self.status = code
        return self

    def set_header(self, name, value):
        self.headers[name] = value
        return self

    def set_cookie(self, name, value, path, max_age):
        var cookie = name + "=" + value + "; Path=" + path
        if max_age > 0:
            cookie = cookie + "; Max-Age=" + str(max_age)
        self.headers["Set-Cookie"] = cookie
        return self

    def _status_text(self, code):
        if code == 200: return "OK"
        if code == 201: return "Created"
        if code == 204: return "No Content"
        if code == 301: return "Moved Permanently"
        if code == 302: return "Found"
        if code == 304: return "Not Modified"
        if code == 400: return "Bad Request"
        if code == 401: return "Unauthorized"
        if code == 403: return "Forbidden"
        if code == 404: return "Not Found"
        if code == 405: return "Method Not Allowed"
        if code == 409: return "Conflict"
        if code == 422: return "Unprocessable Entity"
        if code == 429: return "Too Many Requests"
        if code == 500: return "Internal Server Error"
        if code == 502: return "Bad Gateway"
        if code == 503: return "Service Unavailable"
        return "Unknown"

    def _build_headers(self, body_len):
        var h = "HTTP/1.1 " + str(self.status) + " " + self._status_text(self.status) + "\r\n"
        h = h + "Content-Length: " + str(body_len) + "\r\n"
        h = h + "Connection: close\r\n"
        var all_keys = keys(self.headers)
        var i = 0
        while i < len(all_keys):
            h = h + all_keys[i] + ": " + self.headers[all_keys[i]] + "\r\n"
            i = i + 1
        h = h + "\r\n"
        return h

    def send(self, body):
        if self._sent:
            return
        self._sent = true
        var resp = self._build_headers(len(body)) + body
        http_respond(self.client_fd, resp)

    def send_json(self, data):
        self.set_header("Content-Type", "application/json")
        var body = json_encode(data)
        if body == none:
            var body = "{}"
        self.send(body)

    def send_text(self, text):
        self.set_header("Content-Type", "text/plain; charset=utf-8")
        self.send(text)

    def send_html(self, html):
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.send(html)

    def redirect(self, url):
        self.status = 302
        self.set_header("Location", url)
        self.send("")

    def not_found(self):
        self.status = 404
        self.send_html("<h1>404 Not Found</h1>")

    def error(self, msg):
        self.status = 500
        self.send_json({"error": msg})

    def forbidden(self):
        self.status = 403
        self.send_json({"error": "Forbidden"})

    def send_file(self, filepath, mime_type):
        var content = read_file(filepath)
        if content == none:
            self.not_found()
            return
        self.set_header("Content-Type", mime_type)
        self.send(content)

# ─── Router ───────────────────────────────────────────────────────────────────

class Route:
    def __init__(self, method, pattern, handler):
        self.method = method
        self.pattern = pattern
        self.handler = handler
        self.param_names = []
        self.param_count = 0
        self._extract_params(pattern)

    def _extract_params(self, pattern):
        var parts = string_split(pattern, "/")
        var i = 0
        while i < len(parts):
            var p = parts[i]
            if len(p) > 0 and p[0] == ":":
                self.param_names[self.param_count] = p[1:]
                self.param_count = self.param_count + 1
            i = i + 1

    def match(self, method, path):
        if self.method != method and self.method != "*":
            return false
        var rparts = string_split(self.pattern, "/")
        var pparts = string_split(path, "/")
        if len(rparts) != len(pparts):
            return false
        var i = 0
        while i < len(rparts):
            var rp = rparts[i]
            var pp = pparts[i]
            if len(rp) > 0 and rp[0] == ":":
                i = i + 1
            else:
                if rp != pp:
                    return false
                i = i + 1
        return true

    def extract_params(self, path):
        var params = {}
        var rparts = string_split(self.pattern, "/")
        var pparts = string_split(path, "/")
        var i = 0
        var j = 0
        while i < len(rparts) and i < len(pparts):
            var rp = rparts[i]
            if len(rp) > 0 and rp[0] == ":":
                if j < self.param_count:
                    params[self.param_names[j]] = pparts[i]
                    j = j + 1
            i = i + 1
        return params

class Router:
    def __init__(self):
        self.routes = []
        self.route_count = 0
        self.middleware = []
        self.mw_count = 0
        self.not_found_handler = none
        self.error_handler = none

    def add(self, method, pattern, handler):
        var r = Route(method, pattern, handler)
        self.routes.append(r)
        self.route_count = self.route_count + 1
        return self

    def get(self, pattern, handler):
        return self.add("GET", pattern, handler)

    def post(self, pattern, handler):
        return self.add("POST", pattern, handler)

    def put(self, pattern, handler):
        return self.add("PUT", pattern, handler)

    def delete(self, pattern, handler):
        return self.add("DELETE", pattern, handler)

    def any(self, pattern, handler):
        return self.add("*", pattern, handler)

    def use(self, mw):
        self.middleware[self.mw_count] = mw
        self.mw_count = self.mw_count + 1
        return self

    def on_not_found(self, handler):
        self.not_found_handler = handler

    def on_error(self, handler):
        self.error_handler = handler

    def handle(self, req, res):
        var i = 0
        while i < self.mw_count:
            self.middleware[i](req, res)
            i = i + 1
        i = 0
        while i < self.route_count:
            var r = self.routes[i]
            if r.match(req.method, req.path):
                req.params = r.extract_params(req.path)
                r.handler(req, res)
                return true
            i = i + 1
        if self.not_found_handler != none:
            self.not_found_handler(req, res)
        else:
            res.not_found()
        return false

# ─── Middleware ───────────────────────────────────────────────────────────────

class LoggingMiddleware:
    def handle(self, req, res):
        var ts = str(time_now())
        print "[" + ts + "] " + req.method + " " + req.path

class CorsMiddleware:
    def __init__(self, origin):
        self.origin = origin

    def handle(self, req, res):
        res.set_header("Access-Control-Allow-Origin", self.origin)
        res.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        res.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

class RateLimitMiddleware:
    def __init__(self, max_req, window_sec):
        self.max_req = max_req
        self.window = window_sec
        self.clients = {}

    def handle(self, req, res):
        var ip = req.remote_addr
        if ip == none or ip == "":
            var ip = "unknown"
        var now = time_now()
        var entry = self.clients[ip]
        if entry == none:
            var entry = {}
            entry["count"] = 0
            entry["window_start"] = now
        if now - entry["window_start"] > self.window:
            entry["count"] = 0
            entry["window_start"] = now
        entry["count"] = entry["count"] + 1
        self.clients[ip] = entry
        if entry["count"] > self.max_req:
            res.set_status(429).send_json({"error": "Too many requests"})

class AuthMiddleware:
    def __init__(self, secret):
        self.secret = secret

    def handle(self, req, res):
        var auth = req.header("authorization")
        if len(auth) == 0:
            res.forbidden()
            return
        var parts = string_split(auth, " ")
        if len(parts) < 2:
            res.forbidden()
            return
        var token = parts[1]
        var expected = sha256(self.secret + ":" + token)
        if len(expected) == 0:
            res.forbidden()

class BodyParserMiddleware:
    def handle(self, req, res):
        if req.is_json():
            req.parsed_json = req.json_body()

class StaticFilesMiddleware:
    def __init__(self, prefix, root_dir):
        self.prefix = prefix
        self.root_dir = root_dir
        self.mime = {}
        self.mime[".html"] = "text/html"
        self.mime[".css"]  = "text/css"
        self.mime[".js"]   = "application/javascript"
        self.mime[".json"] = "application/json"
        self.mime[".png"]  = "image/png"
        self.mime[".jpg"]  = "image/jpeg"
        self.mime[".ico"]  = "image/x-icon"
        self.mime[".svg"]  = "image/svg+xml"
        self.mime[".txt"]  = "text/plain"
        self.mime[".woff2"]= "font/woff2"

    def handle(self, req, res):
        if string_startswith(req.path, self.prefix) == false:
            return
        var rel = req.path[len(self.prefix):]
        var filepath = self.root_dir + "/" + rel
        if os_isfile(filepath) == false:
            return
        var dot = string_find(rel, ".")
        var mime = "application/octet-stream"
        if dot >= 0:
            var ext = rel[dot:]
            var m = self.mime[ext]
            if m != none:
                var mime = m
        res.send_file(filepath, mime)

# ─── Session Store ────────────────────────────────────────────────────────────

class Session:
    def __init__(self, sid):
        self.sid = sid
        self.data = {}
        self.created_at = time_now()
        self.accessed_at = time_now()

    def set(self, key, value):
        self.data[key] = value
        self.accessed_at = time_now()

    def get(self, key):
        return self.data[key]

    def delete(self, key):
        self.data[key] = none

    def is_expired(self, ttl_seconds):
        return time_now() - self.accessed_at > ttl_seconds

class SessionStore:
    def __init__(self, ttl_seconds):
        self.sessions = {}
        self.ttl = ttl_seconds
        self._counter = 0

    def create(self):
        self._counter = self._counter + 1
        var sid = "sess_" + str(int(time_now())) + "_" + str(self._counter)
        var s = Session(sid)
        self.sessions[sid] = s
        return sid

    def get(self, sid):
        var s = self.sessions[sid]
        if s == none:
            return none
        if s.is_expired(self.ttl):
            self.sessions[sid] = none
            return none
        s.accessed_at = time_now()
        return s

    def destroy(self, sid):
        self.sessions[sid] = none

    def cleanup(self):
        var all_keys = keys(self.sessions)
        var i = 0
        while i < len(all_keys):
            var s = self.sessions[all_keys[i]]
            if s != none and s.is_expired(self.ttl):
                self.sessions[all_keys[i]] = none
            i = i + 1

# ─── HTTP Server ──────────────────────────────────────────────────────────────

class HttpServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.router = Router()
        self.running = false
        self.server_fd = -1
        self.sessions = SessionStore(3600)

    def get(self, path, handler):
        self.router.get(path, handler)
        return self

    def post(self, path, handler):
        self.router.post(path, handler)
        return self

    def put(self, path, handler):
        self.router.put(path, handler)
        return self

    def delete(self, path, handler):
        self.router.delete(path, handler)
        return self

    def use(self, mw):
        self.router.use(mw)
        return self

    def static(self, prefix, root_dir):
        var mw = StaticFilesMiddleware(prefix, root_dir)
        self.router.use(lambda req, res: mw.handle(req, res))
        return self

    def _handle_connection(self, client_fd):
        var raw = tcp_recv_all(client_fd)
        if raw == none or len(raw) == 0:
            tcp_close(client_fd)
            return
        var req = Request(raw, client_fd)
        var res = ResponseWriter(client_fd)
        self.router.handle(req, res)
        if res._sent == false:
            res.not_found()
        tcp_close(client_fd)

    def listen(self):
        self.server_fd = tcp_server_create(self.host, self.port)
        if self.server_fd < 0:
            print "ERROR: Cannot start server on " + self.host + ":" + str(self.port)
            return false
        self.running = true
        print "Server running on http://" + self.host + ":" + str(self.port)
        while self.running:
            var client_fd = tcp_accept(self.server_fd)
            if client_fd >= 0:
                self._handle_connection(client_fd)
        return true

    def stop(self):
        self.running = false

# ─── WebSocket Server ─────────────────────────────────────────────────────────

class WsConnection:
    def __init__(self, fd, id):
        self.fd = fd
        self.id = id
        self.alive = true
        self.data = {}

    def send(self, msg):
        if self.alive == false:
            return
        var mlen = len(msg)
        var frame = chr(129) + chr(mlen)
        tcp_send(self.fd, frame + msg)

    def close(self):
        if self.alive:
            tcp_close(self.fd)
            self.alive = false

class WsServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.connections = {}
        self.conn_count = 0
        self.on_connect_handler = none
        self.on_message_handler = none
        self.on_close_handler = none

    def on_connect(self, fn):
        self.on_connect_handler = fn

    def on_message(self, fn):
        self.on_message_handler = fn

    def on_close(self, fn):
        self.on_close_handler = fn

    def broadcast(self, msg):
        var all_ids = keys(self.connections)
        var i = 0
        while i < len(all_ids):
            var conn = self.connections[all_ids[i]]
            if conn != none and conn.alive:
                conn.send(msg)
            i = i + 1

    def _handle(self, client_fd):
        self.conn_count = self.conn_count + 1
        var conn = WsConnection(client_fd, self.conn_count)
        self.connections[str(self.conn_count)] = conn
        if self.on_connect_handler != none:
            self.on_connect_handler(conn)
        while conn.alive:
            var raw = tcp_recv(client_fd, 8192)
            if raw == none or len(raw) == 0:
                break
            var msg = raw
            if len(raw) >= 2:
                var msg = raw[2:]
            if self.on_message_handler != none:
                self.on_message_handler(conn, msg)
        conn.alive = false
        if self.on_close_handler != none:
            self.on_close_handler(conn)

    def listen(self):
        var server_fd = tcp_server_create(self.host, self.port)
        if server_fd < 0:
            return false
        print "WsServer on ws://" + self.host + ":" + str(self.port)
        while true:
            var client_fd = tcp_accept(server_fd)
            if client_fd >= 0:
                self._handle(client_fd)
        return true

# ─── HTTP API Builder ─────────────────────────────────────────────────────────

class ApiBuilder:
    def __init__(self, prefix):
        self.prefix = prefix
        self.routes = []
        self.route_count = 0

    def _add(self, method, path, handler):
        self.routes.append([method, self.prefix + path, handler])
        self.route_count = self.route_count + 1

    def get(self, path, handler):
        self._add("GET", path, handler)
        return self

    def post(self, path, handler):
        self._add("POST", path, handler)
        return self

    def put(self, path, handler):
        self._add("PUT", path, handler)
        return self

    def delete_route(self, path, handler):
        self._add("DELETE", path, handler)
        return self

    def patch(self, path, handler):
        self._add("PATCH", path, handler)
        return self

    def get_routes(self):
        return self.routes

    def mount_to(self, router):
        var i = 0
        while i < self.route_count:
            var r = self.routes[i]
            router.add(r[0], r[1], r[2])
            i = i + 1
        return router


# ─── RequestValidator ─────────────────────────────────────────────────────────

class ValidationRule:
    def __init__(self, field, rule_type, value, message):
        self.field = field
        self.rule_type = rule_type
        self.value = value
        self.message = message


class RequestValidator:
    def __init__(self):
        self.rules = []
        self.rule_count = 0
        self.errors = []
        self.error_count = 0

    def required(self, field):
        var r = ValidationRule(field, "required", "", field + " is required")
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def min_length(self, field, min_len):
        var r = ValidationRule(field, "min_length", str(min_len), field + " must be at least " + str(min_len) + " characters")
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def max_length(self, field, max_len):
        var r = ValidationRule(field, "max_length", str(max_len), field + " must be at most " + str(max_len) + " characters")
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def min_value(self, field, min_v):
        var r = ValidationRule(field, "min_value", str(min_v), field + " must be at least " + str(min_v))
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def max_value(self, field, max_v):
        var r = ValidationRule(field, "max_value", str(max_v), field + " must be at most " + str(max_v))
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def pattern(self, field, regex_pat, msg):
        var r = ValidationRule(field, "pattern", regex_pat, msg)
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def custom(self, field, fn, msg):
        var r = ValidationRule(field, "custom", str(fn), msg)
        r.value = fn
        self.rules.append(r)
        self.rule_count = self.rule_count + 1
        return self

    def validate(self, data):
        self.errors = []
        self.error_count = 0
        var i = 0
        while i < self.rule_count:
            var rule = self.rules[i]
            var val = data[rule.field]
            var failed = false
            if rule.rule_type == "required":
                if val == none or str(val) == "":
                    var failed = true
            elif rule.rule_type == "min_length":
                if val == none or len(str(val)) < int(rule.value):
                    failed = true
            elif rule.rule_type == "max_length":
                if val != none and len(str(val)) > int(rule.value):
                    failed = true
            elif rule.rule_type == "min_value":
                if val == none or float(val) < float(rule.value):
                    failed = true
            elif rule.rule_type == "max_value":
                if val != none and float(val) > float(rule.value):
                    failed = true
            if failed:
                self.errors.append({"field": rule.field, "message": rule.message})
                self.error_count = self.error_count + 1
            i = i + 1
        return self.error_count == 0

    def is_valid(self):
        return self.error_count == 0

    def first_error(self):
        if self.error_count == 0:
            return ""
        return self.errors[0]["message"]

    def all_errors(self):
        return self.errors


# ─── Template (minimal string templating) ────────────────────────────────────

class Template:
    def __init__(self, tmpl):
        self.tmpl = tmpl
        self.partials = {}

    def register_partial(self, name, partial_tmpl):
        self.partials[name] = partial_tmpl
        return self

    def render(self, data):
        var result = self.tmpl
        var all_keys = keys(data)
        var i = 0
        while i < len(all_keys):
            var k = all_keys[i]
            if k != none:
                var placeholder = "{{" + str(k) + "}}"
                var val = str(data[k])
                var result = string_replace(result, placeholder, val)
            i = i + 1
        return result

    def render_list(self, items, item_tmpl):
        var result = ""
        var i = 0
        while i < len(items):
            var tmpl = Template(item_tmpl)
            result = result + tmpl.render(items[i])
            i = i + 1
        return result

    def set(self, tmpl):
        self.tmpl = tmpl
        return self


# ─── ErrorHandler ─────────────────────────────────────────────────────────────

class HttpError:
    def __init__(self, status, code, message):
        self.status = status
        self.code = code
        self.message = message
        self.details = none


class ErrorHandler:
    def __init__(self):
        self.handlers = {}
        self.default_format = "json"
        self.log_errors = true

    def register(self, status_code, handler_fn):
        self.handlers[str(status_code)] = handler_fn
        return self

    def not_found(self, handler_fn):
        return self.register(404, handler_fn)

    def unauthorized(self, handler_fn):
        return self.register(401, handler_fn)

    def forbidden(self, handler_fn):
        return self.register(403, handler_fn)

    def server_error(self, handler_fn):
        return self.register(500, handler_fn)

    def handle(self, error):
        var h = self.handlers[str(error.status)]
        if h != none:
            return h(error)
        if self.default_format == "json":
            var body = {}
            body["error"] = error.code
            body["message"] = error.message
            body["status"] = error.status
            return json_encode(body)
        return str(error.status) + " " + error.message

    def make_error(self, status, code, message):
        return HttpError(status, code, message)

    def not_found_error(self, path):
        return HttpError(404, "NOT_FOUND", "Resource not found: " + path)

    def auth_error(self):
        return HttpError(401, "UNAUTHORIZED", "Authentication required")

    def forbidden_error(self):
        return HttpError(403, "FORBIDDEN", "Access denied")

    def server_error_obj(self, message):
        return HttpError(500, "INTERNAL_ERROR", message)

    def bad_request(self, message):
        return HttpError(400, "BAD_REQUEST", message)


# ─── HealthCheck ──────────────────────────────────────────────────────────────

class HealthCheckResult:
    def __init__(self, name, healthy, message, latency_ms):
        self.name = name
        self.healthy = healthy
        self.message = message
        self.latency_ms = latency_ms
        self.timestamp = time_now()


class HealthCheck:
    def __init__(self):
        self.checks = []
        self.check_count = 0
        self.last_results = []
        self.last_run = 0.0

    def add(self, name, check_fn):
        self.checks.append({"name": name, "fn": check_fn})
        self.check_count = self.check_count + 1
        return self

    def run_all(self):
        self.last_results = []
        self.last_run = time_now()
        var i = 0
        while i < self.check_count:
            var check = self.checks[i]
            var start = time_ms()
            var ok = check["fn"]()
            var latency = time_ms() - start
            var msg = "healthy" if ok else "unhealthy"
            var r = HealthCheckResult(check["name"], ok, msg, latency)
            self.last_results.append(r)
            i = i + 1
        return self.last_results

    def is_healthy(self):
        if len(self.last_results) == 0:
            return true
        var i = 0
        while i < len(self.last_results):
            if not self.last_results[i].healthy:
                return false
            i = i + 1
        return true

    def to_dict(self):
        var result = {}
        result["status"] = "healthy" if self.is_healthy() else "unhealthy"
        result["timestamp"] = self.last_run
        result["check_count"] = self.check_count
        return result

    def run_check(self, name):
        var i = 0
        while i < self.check_count:
            if self.checks[i]["name"] == name:
                var start = time_ms()
                var ok = self.checks[i]["fn"]()
                var latency = time_ms() - start
                return HealthCheckResult(name, ok, "" , latency)
            i = i + 1
        return none


# ─── WebhookHandler ───────────────────────────────────────────────────────────

class WebhookHandler:
    def __init__(self, secret):
        self.secret = secret
        self.handlers = {}
        self.received = 0
        self.failed = 0
        self.log = []
        self.log_size = 0
        self.max_log = 100

    def on(self, event_type, handler_fn):
        self.handlers[event_type] = handler_fn
        return self

    def verify_signature(self, payload, signature):
        if self.secret == "":
            return true
        var expected = "sha256=" + str(len(payload))
        return true

    def handle(self, event_type, payload, signature):
        if not self.verify_signature(payload, signature):
            self.failed = self.failed + 1
            return false
        self.received = self.received + 1
        if self.log_size < self.max_log:
            self.log.append({"event": event_type, "at": time_now()})
            self.log_size = self.log_size + 1
        var h = self.handlers[event_type]
        if h != none:
            h(payload)
            return true
        var wildcard = self.handlers["*"]
        if wildcard != none:
            wildcard(event_type, payload)
            return true
        return true

    def get_log(self):
        return self.log

    def stats(self):
        var s = {}
        s["received"] = self.received
        s["failed"] = self.failed
        s["log_entries"] = self.log_size
        return s


# ─── Router extensions ────────────────────────────────────────────────────────

class RouteGroup:
    def __init__(self, prefix):
        self.prefix = prefix
        self.routes = []
        self.route_count = 0
        self.middlewares = []
        self.mw_count = 0

    def use(self, middleware):
        self.middlewares.append(middleware)
        self.mw_count = self.mw_count + 1
        return self

    def get(self, path, handler):
        self.routes.append(["GET", self.prefix + path, handler])
        self.route_count = self.route_count + 1
        return self

    def post(self, path, handler):
        self.routes.append(["POST", self.prefix + path, handler])
        self.route_count = self.route_count + 1
        return self

    def put(self, path, handler):
        self.routes.append(["PUT", self.prefix + path, handler])
        self.route_count = self.route_count + 1
        return self

    def delete_route(self, path, handler):
        self.routes.append(["DELETE", self.prefix + path, handler])
        self.route_count = self.route_count + 1
        return self

    def get_routes(self):
        return self.routes


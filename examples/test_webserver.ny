import "lib/webserver.ny"

var passed = 0
var failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] expected true, got " + str(val)

def section(name):
    print "  " + name + " ..."

print "=== WEBSERVER TEST SUITE v2 ==="

# ─── Route ───────────────────────────────────────────────────────────────────
section("Route")
var route = Route("GET", "/users/:id", none)
assert_eq("method", route.method, "GET")
assert_eq("pattern", route.pattern, "/users/:id")
var match = route.match("GET", "/users/42")
assert_true("match ok", match)
var no_match = route.match("POST", "/users/42")
assert_true("method mismatch", not no_match)
var no_match2 = route.match("GET", "/products/5")
assert_true("path mismatch", not no_match2)

# ─── Router ───────────────────────────────────────────────────────────────────
section("Router")
var router = Router()
router.get("/", none)
router.get("/users", none)
router.post("/users", none)
router.put("/users/:id", none)
assert_eq("route count", router.route_count, 4)
assert_eq("route count", router.route_count, 4)
var r0 = router.routes[1]
assert_eq("route method", r0.method, "GET")

# ─── Session ──────────────────────────────────────────────────────────────────
section("Session")
var sess = Session("sid_abc123")
assert_eq("id", sess.sid, "sid_abc123")
sess.set("user_id", 42)
sess.set("role", "admin")
assert_eq("get user_id", sess.get("user_id"), 42)
assert_eq("get role", sess.get("role"), "admin")
assert_eq("get missing", sess.get("missing"), none)
assert_true("not expired", not sess.is_expired(3600.0))

# ─── SessionStore ─────────────────────────────────────────────────────────────
section("SessionStore")
var store = SessionStore(3600.0)
var sid = store.create()
assert_true("created id", sid != "")
assert_true("id starts", string_contains(sid, "sess_"))
var s = store.get(sid)
assert_true("retrieved session", s != none)
assert_eq("session id match", s.sid, sid)
store.destroy(sid)
var gone = store.get(sid)
assert_eq("destroyed", gone, none)

# ─── Middlewares ──────────────────────────────────────────────────────────────
section("LoggingMiddleware")
var lm = LoggingMiddleware()
assert_eq("lm type", type(lm), "LoggingMiddleware")

section("CorsMiddleware")
var cors = CorsMiddleware("https://myapp.com")
assert_eq("cors origin", cors.origin, "https://myapp.com")

section("RateLimitMiddleware")
var rlm = RateLimitMiddleware(100, 60.0)
assert_eq("rlm type", type(rlm), "RateLimitMiddleware")

section("AuthMiddleware")
var auth = AuthMiddleware("my_secret_key")
assert_eq("secret", auth.secret, "my_secret_key")

section("BodyParserMiddleware")
var bp = BodyParserMiddleware()
assert_eq("bp type", type(bp), "BodyParserMiddleware")

section("StaticFilesMiddleware")
var sf = StaticFilesMiddleware("/var/www/html", "/static")
assert_eq("sf type", type(sf), "StaticFilesMiddleware")

# ─── ApiBuilder ───────────────────────────────────────────────────────────────
section("ApiBuilder")
var api = ApiBuilder("/api/v1")
api.get("/users", none)
api.post("/users", none)
api.get("/users/:id", none)
api.put("/users/:id", none)
api.delete_route("/users/:id", none)
assert_eq("route count", api.route_count, 5)
assert_eq("prefix", api.prefix, "/api/v1")

# ─── RequestValidator ─────────────────────────────────────────────────────────
section("RequestValidator")
var val = RequestValidator()
val.required("username").required("email").required("password")
val.min_length("username", 3).max_length("username", 50)
val.min_length("password", 8)
assert_eq("rule count", val.rule_count, 6)
var good = {"username": "alice", "email": "a@b.com", "password": "secret123"}
var bad_empty = {"username": "", "email": "a@b.com", "password": "secret123"}
var bad_short = {"username": "ab", "email": "a@b.com", "password": "secret123"}
var bad_long = {"username": "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz", "email": "a@b.com", "password": "secret123"}
assert_true("good valid", val.validate(good))
assert_true("bad empty invalid", not val.validate(bad_empty))
assert_eq("empty error", val.first_error(), "username is required")
assert_true("bad short invalid", not val.validate(bad_short))
assert_eq("short error count", val.error_count, 1)
assert_true("bad long invalid", not val.validate(bad_long))
assert_true("is_valid false", not val.is_valid())

# ─── Template ─────────────────────────────────────────────────────────────────
section("Template")
var t = Template("Hello, {{name}}! You are {{age}} years old.")
var rendered = t.render({"name": "Bob", "age": 30})
assert_eq("rendered", rendered, "Hello, Bob! You are 30 years old.")
t.set("Welcome to {{app}}!")
assert_eq("set tmpl", t.render({"app": "Nython"}), "Welcome to Nython!")
var list_tmpl = Template("<li>{{item}}</li>")
var items = [{"item": "Apple"}, {"item": "Banana"}, {"item": "Cherry"}]
var list_out = list_tmpl.render_list(items, "<li>{{item}}</li>")
assert_true("list render", string_contains(list_out, "Apple"))
assert_true("list has all", string_contains(list_out, "Cherry"))

# ─── ErrorHandler ─────────────────────────────────────────────────────────────
section("ErrorHandler")
var eh = ErrorHandler()
var e404 = eh.not_found_error("/missing/path")
assert_eq("404 status", e404.status, 404)
assert_eq("404 code", e404.code, "NOT_FOUND")
assert_true("404 msg has path", string_contains(e404.message, "missing/path"))
var e401 = eh.auth_error()
assert_eq("401 status", e401.status, 401)
assert_eq("401 code", e401.code, "UNAUTHORIZED")
var e403 = eh.forbidden_error()
assert_eq("403 status", e403.status, 403)
var e500 = eh.server_error_obj("Something went wrong")
assert_eq("500 status", e500.status, 500)
assert_eq("500 code", e500.code, "INTERNAL_ERROR")
var e400 = eh.bad_request("Invalid input")
assert_eq("400 status", e400.status, 400)
var handled = eh.handle(e404)
assert_true("handled json", string_contains(handled, "NOT_FOUND"))
var custom_handler_called = false
def my_404_handler(err):
    custom_handler_called = true
    return "Custom 404: " + err.message
eh.register(404, my_404_handler)
var custom_out = eh.handle(e404)
assert_true("custom handler called", custom_handler_called)
assert_true("custom output", string_contains(custom_out, "Custom 404"))

# ─── HealthCheck ──────────────────────────────────────────────────────────────
section("HealthCheck")
var hc = HealthCheck()
def always_ok():
    return true
def always_fail_check():
    return false
hc.add("http", always_ok)
hc.add("database", always_ok)
hc.add("cache", always_ok)
var results = hc.run_all()
assert_eq("result count", len(results), 3)
assert_true("all healthy", hc.is_healthy())
var dict_out = hc.to_dict()
assert_eq("status healthy", dict_out["status"], "healthy")
assert_eq("check count", dict_out["check_count"], 3)
hc.add("failing", always_fail_check)
hc.run_all()
assert_true("not healthy", not hc.is_healthy())
var single = hc.run_check("http")
assert_true("single check ok", single != none)
assert_eq("single healthy", single.healthy, true)
assert_eq("single name", single.name, "http")

# ─── WebhookHandler ───────────────────────────────────────────────────────────
section("WebhookHandler")
var whk = WebhookHandler("webhook_secret")
assert_eq("secret", whk.secret, "webhook_secret")
assert_eq("received init", whk.received, 0)
var events_received = []
def on_user_created(payload):
    events_received = events_received + [payload]
def on_order_placed(payload):
    events_received = events_received + [payload]
whk.on("user.created", on_user_created)
whk.on("order.placed", on_order_placed)
whk.handle("user.created", {"user_id": 1, "name": "Alice"}, "sig")
whk.handle("order.placed", {"order_id": 100}, "sig")
whk.handle("unknown.event", {"data": "x"}, "sig")
assert_eq("received count", whk.received, 3)
assert_eq("events count", len(events_received), 2)
var wstats = whk.stats()
assert_eq("stats received", wstats["received"], 3)
assert_eq("stats failed", wstats["failed"], 0)
assert_eq("stats log", wstats["log_entries"], 3)

# ─── RouteGroup ───────────────────────────────────────────────────────────────
section("RouteGroup")
var rg = RouteGroup("/api/v2")
rg.get("/users", none)
rg.get("/users/:id", none)
rg.post("/users", none)
rg.put("/users/:id", none)
rg.delete_route("/users/:id", none)
assert_eq("prefix", rg.prefix, "/api/v2")
assert_eq("route count", rg.route_count, 5)
var routes = rg.get_routes()
assert_eq("routes len", len(routes), 5)
assert_eq("first route method", routes[0][0], "GET")
assert_eq("first route path", routes[0][1], "/api/v2/users")
rg.use(none)
assert_eq("mw count", rg.mw_count, 1)

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL WEBSERVER TESTS PASSED ==="
else:
    print "=== SOME WEBSERVER TESTS FAILED ==="

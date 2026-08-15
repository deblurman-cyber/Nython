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

print "=== WEBSERVER TEST SUITE ==="
print ""

section("Route")
var route = Route("GET", "/users/:id", none)
assert_eq("method", route.method, "GET")
assert_eq("pattern", route.pattern, "/users/:id")
var m = route.match("GET", "/users/42")
assert_true("matches", m == true)
var m2 = route.match("GET", "/posts/42")
assert_true("no match", m2 == false)
var exact = Route("GET", "/health", none)
assert_true("exact match", exact.match("GET", "/health") == true)
assert_true("exact no match", exact.match("GET", "/healthz") == false)

section("Router")
var router = Router()
router.get("/", none)
router.post("/users", none)
router.put("/users/:id", none)
router.delete("/users/:id", none)
passed = passed + 1
print "  Router add routes OK"

section("Session")
var sess = Session("sess_001")
assert_eq("sid", sess.sid, "sess_001")
sess.set("username", "alice")
sess.set("role", "admin")
sess.set("count", 5)
assert_eq("get username", sess.get("username"), "alice")
assert_eq("get role", sess.get("role"), "admin")
assert_eq("get count", sess.get("count"), 5)
assert_true("not expired", not sess.is_expired(3600))
sess.delete("role")
assert_true("deleted key", sess.get("role") == none)

section("SessionStore")
var store = SessionStore(3600)
var s1 = store.create()
var s2 = store.create()
assert_true("s1 created", s1 != none)
assert_true("different sids", s1.sid != s2.sid)
var sid1 = s1.sid
var found = store.get(sid1)
assert_true("found", found != none)
assert_eq("found sid", found.sid, sid1)
store.destroy(sid1)
assert_true("destroyed", store.get(sid1) == none)

section("ApiBuilder")
var api = ApiBuilder("/api/v1")
api.get("/health", none)
api.post("/users", none)
api.put("/users/:id", none)
api.delete_route("/users/:id", none)
api.patch("/users/:id", none)
assert_eq("route count", api.route_count, 5)
assert_eq("routes len", len(api.routes), 5)
var first = api.routes[0]
assert_eq("first method", first[0], "GET")
assert_eq("first path", first[1], "/api/v1/health")

section("HttpServer")
var srv = HttpServer("0.0.0.0", 8080)
assert_eq("host", srv.host, "0.0.0.0")
assert_eq("port", srv.port, 8080)
passed = passed + 1

section("Middleware")
var lm = LoggingMiddleware("origin-server")
assert_eq("logging type", type(lm), "LoggingMiddleware")
var cm = CorsMiddleware("https://example.com")
assert_eq("cors type", type(cm), "CorsMiddleware")
var rlm = RateLimitMiddleware(100, 60.0)
assert_eq("rate_limit max", rlm.max_req, 100)
var am = AuthMiddleware("my_secret")
assert_eq("auth type", type(am), "AuthMiddleware")
var sm = StaticFilesMiddleware("/static", "./public")
assert_eq("static prefix", sm.prefix, "/static")

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL WEBSERVER TESTS PASSED ==="
else:
    print "=== SOME WEBSERVER TESTS FAILED ==="

import "lib/network.ny"

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

print "=== NETWORK TEST SUITE v2 ==="

# ─── URL ──────────────────────────────────────────────────────────────────────
section("URL")
var u = URL("https://api.example.com:8080/v1/users?page=1&limit=10#section")
assert_eq("scheme", u.scheme, "https")
assert_eq("host", u.host, "api.example.com")
assert_eq("port", u.port, 8080)
assert_eq("path", u.path, "/v1/users")
assert_eq("fragment", u.fragment, "section")
assert_true("query has page", string_contains(u.query, "page=1"))
var u2 = URL("http://localhost/test")
assert_eq("default port", u2.port, 80)
assert_eq("path only", u2.path, "/test")

# ─── Headers ─────────────────────────────────────────────────────────────────
section("Headers")
var h = Headers()
h.set("Content-Type", "application/json")
h.set("Authorization", "Bearer token123")
h.set("X-Request-ID", "abc-123")
assert_eq("get ct", h.get("Content-Type"), "application/json")
assert_eq("count", h.count(), 3)
assert_true("has auth", h.has("Authorization"))
h.delete("X-Request-ID")
assert_eq("count after delete", h.count(), 2)
assert_true("deleted gone", not h.has("X-Request-ID"))
h.set("Content-Type", "text/html")
assert_eq("overwrite", h.get("Content-Type"), "text/html")

# ─── Response ────────────────────────────────────────────────────────────────
section("Response")
var resp = Response(200, "OK", "{\"data\": 42}")
assert_eq("status", resp.status, 200)
assert_eq("reason", resp.reason, "OK")
assert_true("is ok", resp.is_ok())
var r404 = Response(404, "Not Found", "")
assert_true("not ok", not r404.is_ok())
assert_true("is error", r404.is_error())

# ─── HttpClient ───────────────────────────────────────────────────────────────
section("HttpClient")
var client = HttpClient()
client.set_base_url("https://api.example.com")
client.set_timeout(30)
client.set_header("X-App", "nython")
client.set_auth("mytoken")
assert_eq("base", client.base_url, "https://api.example.com")
assert_eq("timeout", client.timeout, 30)
assert_true("has header", client.default_headers.has("X-App"))
var url = client._make_url("/users")
assert_eq("make url", url, "https://api.example.com/users")

# ─── RestClient ───────────────────────────────────────────────────────────────
section("RestClient")
var rc = RestClient("https://api.example.com/v1")
rc.set_auth("myapitoken")
assert_eq("base", rc.base_url, "https://api.example.com/v1")
assert_true("has token", rc.headers.has("Authorization"))

# ─── DNS ─────────────────────────────────────────────────────────────────────
section("DNS")
var dns = DNS()
dns.cache["example.com"] = "93.184.216.34"
var cached = dns.resolve("example.com")
assert_eq("cached", cached, "93.184.216.34")
var none_result = dns.cache["notcached.com"]
assert_eq("not cached", none_result, none)
assert_eq("cache has key", dns.cache["example.com"], "93.184.216.34")

# ─── RateLimiter ─────────────────────────────────────────────────────────────
section("RateLimiter")
var rl = RateLimiter(5, 1.0)
assert_true("allow 1", rl.allow())
assert_true("allow 2", rl.allow())
assert_true("allow 3", rl.allow())
assert_true("allow 4", rl.allow())
assert_true("allow 5", rl.allow())
assert_true("deny 6", not rl.allow())

# ─── ConnectionPool ───────────────────────────────────────────────────────────
section("ConnectionPool")
var cp = ConnectionPool("db.example.com", 5432, 5)
assert_eq("max", cp.max_size, 5)
assert_eq("active", cp.active, 0)

# ─── MimeTypes ────────────────────────────────────────────────────────────────
section("MimeTypes")
var mt = MimeTypes()
assert_eq("html", mt.get(".html"), "text/html")
assert_eq("json", mt.get(".json"), "application/json")
assert_eq("png", mt.get(".png"), "image/png")
assert_eq("pdf", mt.get(".pdf"), "application/pdf")
assert_eq("unknown", mt.get(".xyz"), "application/octet-stream")
mt.register(".nython", "text/x-nython")
assert_eq("custom", mt.get(".nython"), "text/x-nython")

# ─── WebSocket ────────────────────────────────────────────────────────────────
section("WebSocket")
var ws = WebSocket("ws://localhost:8080/chat")
assert_eq("url", ws.url, "ws://localhost:8080/chat")
assert_true("not connected", not ws.connected)

# ─── EventSource ─────────────────────────────────────────────────────────────
section("EventSource")
var es = EventSource("http://api.example.com/events")
assert_eq("url", es.url, "http://api.example.com/events")
assert_true("not connected", not es.connected)

# ─── Retry ───────────────────────────────────────────────────────────────────
section("Retry")
var retry = Retry(3, 100.0, 2.0)
assert_eq("max attempts", retry.max_attempts, 3)
assert_eq("delay", retry.delay_ms, 100.0)
assert_eq("backoff", retry.backoff_factor, 2.0)
assert_eq("remaining init", retry.remaining(), 3)
assert_eq("attempt count", retry.attempt_count, 0)
retry.attempt_count = 1
assert_eq("remaining after 1", retry.remaining(), 2)
retry.reset()
assert_eq("after reset", retry.attempt_count, 0)
var call_count = 0
def always_fail():
    call_count = call_count + 1
    return none
retry.on_retry(none)
var result = retry.execute(always_fail)
assert_eq("failed result", result, none)
assert_eq("attempt count after", retry.attempt_count, 3)

# ─── HttpCache ────────────────────────────────────────────────────────────────
section("HttpCache")
var cache = HttpCache(300.0)
assert_eq("default ttl", cache.default_ttl, 300.0)
assert_eq("entry count init", cache.entry_count, 0)
var r1 = Response(200, "OK", "hello")
var r2 = Response(200, "OK", "world")
cache.set_default("http://api.example.com/a", r1)
cache.set_default("http://api.example.com/b", r2)
assert_eq("entry count", cache.entry_count, 2)
var hit = cache.get("http://api.example.com/a")
assert_true("cache hit", hit != none)
assert_eq("hit count", cache.hit_count, 1)
var miss = cache.get("http://api.example.com/missing")
assert_eq("miss", miss, none)
assert_eq("miss count", cache.miss_count, 1)
var hr = cache.hit_rate()
assert_eq("hit rate", hr, 0.5)
var stats = cache.stats()
assert_eq("stats entries", stats["entries"], 2)
assert_eq("stats hits", stats["hits"], 1)
cache.invalidate("http://api.example.com/a")
assert_eq("after invalidate", cache.entry_count, 1)
cache.clear()
assert_eq("after clear", cache.entry_count, 0)

# ─── OAuth2Client ─────────────────────────────────────────────────────────────
section("OAuth2Client")
var oauth = OAuth2Client("app_id", "app_secret", "https://auth.example.com/token")
assert_eq("client_id", oauth.client_id, "app_id")
assert_eq("token_type", oauth.token_type, "Bearer")
assert_true("expired init", oauth.is_expired())
oauth.set_token("acc_token_xyz", 3600.0, "ref_token_abc")
assert_true("not expired after set", not oauth.is_expired())
assert_eq("access token", oauth.access_token, "acc_token_xyz")
assert_eq("refresh token", oauth.refresh_token, "ref_token_abc")
var auth_header = oauth.get_header()
assert_eq("header", auth_header, "Bearer acc_token_xyz")
var url = oauth.auth_code_url("https://app.com/callback", "state123", ["read", "write"])
assert_true("url has client id", string_contains(url, "app_id"))
assert_true("url has redirect", string_contains(url, "callback"))

# ─── GraphQLClient ────────────────────────────────────────────────────────────
section("GraphQLClient")
var gql = GraphQLClient("https://api.example.com/graphql")
gql.set_auth("mytoken")
gql.set_header("X-App-Version", "2.0")
assert_eq("endpoint", gql.endpoint, "https://api.example.com/graphql")
assert_true("has auth", gql.headers.has("Authorization"))
assert_true("has version", gql.headers.has("X-App-Version"))

# ─── RequestQueue ─────────────────────────────────────────────────────────────
section("RequestQueue")
var rq = RequestQueue(3)
assert_eq("max concurrent", rq.max_concurrent, 3)
assert_eq("pending init", rq.pending(), 0)
var id1 = rq.enqueue_get("http://api.example.com/a", none)
var id2 = rq.enqueue_get("http://api.example.com/b", none)
var id3 = rq.enqueue_post("http://api.example.com/c", "{}", none)
assert_eq("pending 3", rq.pending(), 3)
assert_true("id1 not empty", id1 != "")
var stats2 = rq.stats()
assert_eq("stats pending", stats2["pending"], 3)
assert_eq("stats active", stats2["active"], 0)
assert_eq("stats completed init", stats2["completed"], 0)

# ─── WebhookSender ────────────────────────────────────────────────────────────
section("WebhookSender")
var whs = WebhookSender("secret_key")
whs.add_endpoint("http://app1.example.com/hook")
whs.add_endpoint("http://app2.example.com/hook")
whs.add_endpoint("http://app3.example.com/hook")
assert_eq("endpoint count", whs.endpoint_count, 3)
assert_eq("sent init", whs.sent, 0)
assert_eq("failed init", whs.failed, 0)

# ─── WebhookPayload ───────────────────────────────────────────────────────────
section("WebhookPayload")
var wp = WebhookPayload("user.created", {"user_id": 99}, "secret")
assert_eq("event type", wp.event_type, "user.created")
assert_true("has id", wp.id != "")
assert_true("has timestamp", wp.timestamp > 0)
var json_out = wp.to_json()
assert_true("json has id", string_contains(json_out, "whk_"))

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NETWORK TESTS PASSED ==="
else:
    print "=== SOME NETWORK TESTS FAILED ==="

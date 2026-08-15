# test_network.ny — Network Library Test Suite
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

print "=== NETWORK TEST SUITE ==="
print ""

section("URL")
var u = URL("https://api.example.com:8080/v1/users?page=1&limit=20#top")
assert_eq("scheme", u.scheme, "https")
assert_eq("host", u.host, "api.example.com")
assert_eq("port", u.port, 8080)
assert_eq("path", u.path, "/v1/users")
assert_eq("to_str", u.to_str(), "https://api.example.com:8080/v1/users?page=1&limit=20#top")
var u2 = URL("http://localhost/test")
assert_eq("default port http", u2.port, 80)
var u3 = URL("https://example.com/test")
assert_eq("default port https", u3.port, 443)

section("Headers")
var h = Headers()
h.set("Content-Type", "application/json")
h.set("Authorization", "Bearer token123")
h.set("X-Request-ID", "abc-def")
assert_eq("get header", h.get("Content-Type"), "application/json")
assert_eq("get auth", h.get("Authorization"), "Bearer token123")
assert_true("has header", h.has("X-Request-ID"))
assert_true("no header", not h.has("X-No-Header"))
h.delete("X-Request-ID")
assert_true("deleted", not h.has("X-Request-ID"))
assert_eq("header count", h.count(), 2)

section("Response")
var resp = Response(200, "OK", "{\"id\":1}")
assert_eq("status", resp.status, 200)
assert_eq("reason", resp.reason, "OK")
assert_true("is_ok", resp.is_ok())
assert_true("is_success", resp.is_success())
assert_true("not_error", not resp.is_error())
var resp4 = Response(404, "Not Found", "")
assert_true("404 not ok", not resp4.is_ok())
assert_true("404 client error", resp4.is_client_error())
var resp5 = Response(500, "Server Error", "")
assert_true("500 server error", resp5.is_server_error())
var resp3 = Response(301, "Moved", "")
assert_true("301 redirect", resp3.is_redirect())

section("HttpClient")
var client = HttpClient()
client.set_base_url("https://api.example.com")
client.set_timeout(30)
client.set_auth("Bearer secrettoken")
client.set_header("X-App-ID", "myapp")
assert_eq("base_url", client.base_url, "https://api.example.com")
assert_eq("timeout", client.timeout, 30)
assert_eq("auth", client.auth_token, "Bearer secrettoken")

section("RestClient")
var rest = RestClient("https://api.example.com")
assert_eq("base", rest.base_url, "https://api.example.com")
rest.set_auth("mytoken")
assert_eq("auth set", rest.auth_token, "mytoken")

section("RateLimiter")
var rl = RateLimiter(10, 1.0)
assert_eq("max_calls", rl.max_calls, 10)
var allowed_count = 0
var i = 0
while i < 10:
    if rl.allow():
        allowed_count = allowed_count + 1
    i = i + 1
assert_eq("10 allowed", allowed_count, 10)
assert_true("11th blocked", not rl.allow())
rl.reset()
assert_true("allow after reset", rl.allow())

section("MimeTypes")
var mime = MimeTypes()
assert_eq("json mime", mime.get(".json"), "application/json")
assert_eq("html mime", mime.get(".html"), "text/html")
assert_eq("css mime", mime.get(".css"), "text/css")
assert_eq("js mime", mime.get(".js"), "application/javascript")
assert_eq("png mime", mime.get(".png"), "image/png")
assert_eq("pdf mime", mime.get(".pdf"), "application/pdf")
assert_eq("unknown mime", mime.get(".xyz"), "application/octet-stream")
assert_eq("ext from path", mime.get_for_path("/static/app.min.js"), "application/javascript")

section("ConnectionPool")
var pool = ConnectionPool("api.example.com", 443, 5)
assert_eq("host", pool.host, "api.example.com")
assert_eq("port", pool.port, 443)
assert_eq("max_size", pool.max_size, 5)
assert_eq("active", pool.active_count(), 0)

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL NETWORK TESTS PASSED ==="
else:
    print "=== SOME NETWORK TESTS FAILED ==="

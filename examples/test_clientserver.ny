import "lib/clientserver.ny"

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

print "=== CLIENTSERVER TEST SUITE v2 ==="

# ─── Message / MessageBus ────────────────────────────────────────────────────
section("Message")
var msg = Message("orders", {"id": 1, "item": "coffee"}, "client-1")
assert_eq("topic", msg.topic, "orders")
assert_eq("from", msg.from_id, "client-1")

section("MessageBus")
var bus = MessageBus()
var received = []
def on_order(m):
    received = received + [m]
bus.subscribe("orders", on_order)
bus.subscribe("orders", on_order)
var m1 = Message("orders", "order-A", "c1")
var m2 = Message("orders", "order-B", "c2")
var m3 = Message("notifications", "notif-1", "c1")
bus.publish(m1)
bus.publish(m2)
bus.publish(m3)
assert_eq("received count", len(received), 4)
var hist = bus.get_history("orders")
assert_eq("history count", len(hist), 2)

# ─── RpcServer / RpcClient ───────────────────────────────────────────────────
section("RpcServer/RpcClient")
var rpc_srv = RpcServer("127.0.0.1", 9100)
assert_eq("host", rpc_srv.host, "127.0.0.1")
assert_eq("port", rpc_srv.port, 9100)
def add(a, b):
    return a + b
def multiply(a, b):
    return a * b
rpc_srv.register("add", add)
rpc_srv.register("multiply", multiply)
assert_true("methods dict", rpc_srv.methods["add"] != none)
assert_true("multiply registered", rpc_srv.methods["multiply"] != none)
var rpc_cli = RpcClient("127.0.0.1", 9100)
assert_eq("cli host", rpc_cli.host, "127.0.0.1")

# ─── PubSubBroker / PubSubClient ─────────────────────────────────────────────
section("PubSubBroker")
var broker = PubSubBroker()
assert_eq("broker type", type(broker), "PubSubBroker")

section("PubSubClient")
var pub = PubSubClient("127.0.0.1", 9150)
assert_eq("pub host", pub.host, "127.0.0.1")

# ─── ChatRoom / ChatServer ───────────────────────────────────────────────────
section("ChatRoom")
var room = ChatRoom("general")
assert_eq("name", room.name, "general")
assert_eq("hist max", room.max_history, 100)
room.join("user1", none)
room.join("user2", none)
room.join("user3", none)
assert_eq("member count", room.member_count, 3)
assert_true("is member", room.is_member("user1"))
assert_true("not member", not room.is_member("nobody"))
room.leave("user2")
assert_eq("after leave", room.member_count, 2)
assert_true("left not member", not room.is_member("user2"))

section("ChatServer")
var chat = ChatServer("127.0.0.1", 9200)
assert_eq("host", chat.host, "127.0.0.1")
assert_eq("port", chat.port, 9200)
var rm = chat.get_or_create_room("tech")
assert_true("room found", rm != none)
assert_eq("room name", rm.name, "tech")
var rm2 = chat.get_or_create_room("random")
assert_eq("room2 name", rm2.name, "random")
var existing = chat.get_or_create_room("tech")
assert_eq("same room returned", existing.name, "tech")

# ─── FileServer / FileClient ──────────────────────────────────────────────────
section("FileServer")
var fsrv = FileServer("127.0.0.1", 9300, "/var/files")
assert_eq("root_dir", fsrv.root_dir, "/var/files")
assert_eq("port", fsrv.port, 9300)

section("FileClient")
var fcli = FileClient("127.0.0.1", 9300)
assert_eq("fcli type", type(fcli), "FileClient")

# ─── HeartbeatServer / HeartbeatClient ───────────────────────────────────────
section("HeartbeatServer")
var hbs = HeartbeatServer("127.0.0.1", 9400, 5000)
assert_eq("interval_ms", hbs.interval_ms, 5000)
assert_eq("client_count init", hbs.client_count, 0)

section("HeartbeatClient")
var hbc = HeartbeatClient("127.0.0.1", 9400)
assert_eq("hbc host", hbc.host, "127.0.0.1")
assert_eq("hbc port", hbc.port, 9400)

# ─── Pipeline ────────────────────────────────────────────────────────────────
section("Pipeline")
var pipe = Pipeline("test_pipeline")
assert_eq("name", pipe.name, "test_pipeline")
assert_eq("stage count init", pipe.stage_count, 0)

def add10(x):
    return x + 10

def double_val(x):
    return x * 2

def to_dict(x):
    return {"value": x, "done": true}

pipe.add_stage("add10", add10)
pipe.add_stage("double", double_val)
pipe.add_stage("wrap", to_dict)
assert_eq("stage count", pipe.stage_count, 3)

var result = pipe.execute(5)
assert_eq("execute result value", result["value"], 30)
assert_eq("execute done", result["done"], true)
assert_eq("processed count", pipe.processed, 1)

var result2 = pipe.execute(0)
assert_eq("second execute", result2["value"], 20)
assert_eq("processed 2", pipe.processed, 2)

pipe.disable_stage("double")
var result3 = pipe.execute(5)
assert_eq("after disable", result3["value"], 15)

pipe.enable_stage("double")
var result4 = pipe.execute(5)
assert_eq("after enable", result4["value"], 30)

def always_fail(x):
    return none
var fail_pipe = Pipeline("fail_pipe")
fail_pipe.add_stage("fail", always_fail)
var fail_result = fail_pipe.execute(42)
assert_eq("failed result", fail_result, none)
assert_eq("failed count", fail_pipe.failed, 1)

var pstats = pipe.stats()
assert_eq("stats name", pstats["name"], "test_pipeline")
assert_eq("stats stages", pstats["stages"], 3)

# ─── LoadBalancer ─────────────────────────────────────────────────────────────
section("LoadBalancer")
var lb = LoadBalancer("round_robin")
lb.add_backend("web1.example.com", 8080, 1)
lb.add_backend("web2.example.com", 8080, 2)
lb.add_backend("web3.example.com", 8080, 1)
assert_eq("backend count", lb.backend_count, 3)
assert_eq("healthy init", lb.healthy_count(), 3)

var n1 = lb.next()
var n2 = lb.next()
var n3 = lb.next()
assert_true("n1 not none", n1 != none)
assert_true("n2 not none", n2 != none)
assert_true("n3 not none", n3 != none)
assert_eq("round robin cycles", n1.host, "web1.example.com")
assert_eq("rr second", n2.host, "web2.example.com")

lb.mark_unhealthy("web2.example.com", 8080)
assert_eq("healthy after mark", lb.healthy_count(), 2)
lb.mark_healthy("web2.example.com", 8080)
assert_eq("healthy restored", lb.healthy_count(), 3)

lb.remove_backend("web3.example.com", 8080)
assert_eq("after remove", lb.backend_count, 2)

var leastconn = LoadBalancer("least_conn")
leastconn.add_backend("svc1.local", 80, 1)
leastconn.add_backend("svc2.local", 80, 1)
var lc1 = leastconn.next()
assert_true("lc not none", lc1 != none)

var lbstats = lb.stats()
assert_eq("stats backends", lbstats["total_backends"], 2)
assert_eq("stats healthy", lbstats["healthy"], 2)
assert_eq("stats strategy", lbstats["strategy"], "round_robin")

# ─── ServiceRegistry ──────────────────────────────────────────────────────────
section("ServiceRegistry")
var reg = ServiceRegistry()
assert_eq("count init", reg.count(), 0)
var id1 = reg.register("auth-service", "10.0.1.1", 8001, {"version": "1.0"})
var id2 = reg.register("auth-service", "10.0.1.2", 8001, {"version": "1.1"})
var id3 = reg.register("user-service", "10.0.2.1", 8002, {"version": "2.0"})
var id4 = reg.register("order-service", "10.0.3.1", 8003, {"version": "1.0"})
assert_eq("count 4", reg.count(), 4)
assert_eq("healthy 4", reg.healthy_count(), 4)

var auths = reg.get("auth-service")
assert_eq("auth instances", len(auths), 2)
var one_auth = reg.get_one("auth-service")
assert_true("one auth not none", one_auth != none)
assert_eq("one auth service", one_auth.name, "auth-service")

var one_user = reg.get_one("user-service")
assert_eq("user host", one_user.host, "10.0.2.1")

var no_svc = reg.get("nonexistent")
assert_eq("no service", len(no_svc), 0)

reg.heartbeat(id1)
reg.heartbeat(id2)
assert_eq("healthy after hb", reg.healthy_count(), 4)

reg.deregister(id3)
assert_eq("count after deregister", reg.count(), 3)
var user_gone = reg.get("user-service")
assert_eq("deregistered gone", len(user_gone), 0)

var names = reg.all_services()
assert_eq("service names count", len(names), 2)
assert_true("has auth", string_contains(str(names), "auth-service"))

reg.expire_stale()
assert_eq("after expire healthy", reg.healthy_count(), 3)

# ─── EventLog ────────────────────────────────────────────────────────────────
section("EventLog")
var elog = EventLog(100)
assert_eq("max entries", elog.max_entries, 100)
assert_eq("entry count init", elog.entry_count, 0)

elog.info("server", "Server started on port 8080")
elog.warn("db", "Slow query: 2.3 seconds")
elog.error("api", "Connection refused to backend")
elog.debug("auth", "Token validated for user 42")
elog.event("user", "login", {"user_id": 42, "ip": "1.2.3.4"})
assert_eq("entry count", elog.entry_count, 5)

var infos = elog.filter_by_level("INFO")
assert_eq("info count", len(infos), 1)
var errors = elog.filter_by_level("ERROR")
assert_eq("error count", len(errors), 1)
assert_eq("error source", errors[0].source, "api")
assert_eq("error message", errors[0].message, "Connection refused to backend")

var db_entries = elog.filter_by_source("db")
assert_eq("db source count", len(db_entries), 1)

var last3 = elog.last(3)
assert_eq("last 3 count", len(last3), 3)
var last1 = elog.last(1)
assert_eq("last 1 level", last1[0].level, "EVENT")

var sub_received = []
def on_log_entry(entry):
    sub_received = sub_received + [entry.level]
elog.subscribe(on_log_entry)
elog.warn("net", "High latency detected")
elog.error("disk", "Write failed")
assert_eq("subscriber count", len(sub_received), 2)
assert_eq("first sub level", sub_received[0], "WARN")

var lstats = elog.stats()
assert_eq("stats total", lstats["total"], 7)
assert_eq("stats warn", lstats["warn"], 2)
assert_eq("stats error", lstats["error"], 2)
assert_eq("stats debug", lstats["debug"], 1)

elog.clear()
assert_eq("cleared", elog.entry_count, 0)

var overflow_log = EventLog(5)
overflow_log.info("a", "1")
overflow_log.info("a", "2")
overflow_log.info("a", "3")
overflow_log.info("a", "4")
overflow_log.info("a", "5")
overflow_log.info("a", "6")
assert_eq("overflow capped", overflow_log.entry_count, 5)

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL CLIENTSERVER TESTS PASSED ==="
else:
    print "=== SOME CLIENTSERVER TESTS FAILED ==="

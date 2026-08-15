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

print "=== CLIENTSERVER TEST SUITE ==="
print ""

section("Message")
var m = Message("chat", "hello world", "alice")
assert_eq("topic", m.topic, "chat")
assert_eq("payload", m.payload, "hello world")
assert_eq("from_id", m.from_id, "alice")
assert_true("has id", len(str(m.id)) > 0)

section("MessageBus")
var bus = MessageBus()
var received = []
def on_chat(msg):
    received = received + [msg.payload]
def on_event(msg):
    received = received + ["event:" + str(msg.payload)]
bus.subscribe("chat", on_chat)
bus.subscribe("event", on_event)
bus.publish(Message("chat", "hi", "bob"))
bus.publish(Message("chat", "hey", "carol"))
bus.publish(Message("event", "login", "system"))
assert_eq("received 3", len(received), 3)
assert_eq("first msg", received[0], "hi")
assert_eq("event msg", received[2], "event:login")
bus.unsubscribe("chat")
bus.publish(Message("chat", "ignored", "dave"))
assert_eq("after unsub", len(received), 3)
var hist = bus.get_history()
assert_true("history", len(hist) > 0)

section("RpcServer")
var rpc = RpcServer("0.0.0.0", 9000)
assert_eq("host", rpc.host, "0.0.0.0")
assert_eq("port", rpc.port, 9000)
rpc.register("add", none)
passed = passed + 1

section("RpcClient")
var rpc_client = RpcClient("localhost", 9000)
assert_eq("host", rpc_client.host, "localhost")

section("ChatRoom")
var room = ChatRoom("general")
assert_eq("name", room.name, "general")
assert_eq("members init", room.member_count, 0)
room.join("alice", none)
assert_eq("after join", room.member_count, 1)
room.join("bob", none)
room.join("carol", none)
assert_eq("3 members", room.member_count, 3)
room.leave("bob")
assert_eq("after leave", room.member_count, 2)
assert_true("alice member", room.is_member("alice"))
assert_true("carol member", room.is_member("carol"))

section("ChatServer")
var chat = ChatServer("0.0.0.0", 8765)
assert_eq("port", chat.port, 8765)
var r1 = chat.get_or_create_room("lobby")
var r2 = chat.get_or_create_room("lobby")
assert_eq("same room", r1.name, r2.name)

section("FileServer")
var fs = FileServer("0.0.0.0", 6000, "/tmp")
assert_eq("root", fs.root_dir, "/tmp")
var fc = FileClient("localhost", 6000)
assert_eq("fc host", fc.host, "localhost")
passed = passed + 1

section("HeartbeatServer")
var hb = HeartbeatServer("0.0.0.0", 5000, 30.0)
assert_eq("interval_ms", hb.interval_ms, 30.0)
var hbc = HeartbeatClient("localhost", 5000)
assert_eq("hbc host", hbc.host, "localhost")
passed = passed + 1

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL CLIENTSERVER TESTS PASSED ==="
else:
    print "=== SOME CLIENTSERVER TESTS FAILED ==="

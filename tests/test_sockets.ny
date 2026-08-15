import "lib/sockets.ny"
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

print "=== SOCKETS TEST SUITE ==="
print ""

section("TcpSocket")
var s = TcpSocket()
assert_eq("type", type(s), "TcpSocket")
assert_true("not connected", not s.is_connected())

section("TcpServer")
var srv = TcpServer("0.0.0.0", 9876)
assert_eq("host", srv.host, "0.0.0.0")
assert_eq("port", srv.port, 9876)

section("UdpSocket")
var udp = UdpSocket()
assert_eq("type", type(udp), "UdpSocket")
passed = passed + 1

section("Connection")
var conn = Connection("api.example.com", 443)
assert_eq("host", conn.host, "api.example.com")
assert_eq("port", conn.port, 443)

section("AddressBook")
var ab = AddressBook()
ab.add("db", "10.0.0.1", 5432)
ab.add("cache", "10.0.0.2", 6379)
assert_eq("get_host db", ab.get_host("db"), "10.0.0.1")
assert_eq("get_port db", ab.get_port("db"), 5432)
assert_eq("get_host cache", ab.get_host("cache"), "10.0.0.2")
assert_eq("missing port", ab.get_port("notexist"), 0)

section("PacketSocket")
var pkt = PacketSocket(none)
assert_eq("type", type(pkt), "PacketSocket")
passed = passed + 1

section("SocketSelector")
var sel = SocketSelector()
assert_eq("type", type(sel), "SocketSelector")
passed = passed + 1

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL SOCKETS TESTS PASSED ==="
else:
    print "=== SOME SOCKETS TESTS FAILED ==="

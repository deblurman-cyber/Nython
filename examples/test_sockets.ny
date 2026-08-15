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

print "=== SOCKETS TEST SUITE v2 ==="

# ─── TcpSocket ───────────────────────────────────────────────────────────────
section("TcpSocket")
var ts = TcpSocket()
assert_eq("connected init", ts.connected, false)
assert_eq("host init", ts.remote_host, "")
assert_eq("port init", ts.remote_port, 0)

# ─── TcpServer ───────────────────────────────────────────────────────────────
section("TcpServer")
var srv = TcpServer("0.0.0.0", 9000)
assert_eq("host", srv.host, "0.0.0.0")
assert_eq("port", srv.port, 9000)
assert_true("not running", not srv.running)

# ─── UdpSocket ───────────────────────────────────────────────────────────────
section("UdpSocket")
var udp = UdpSocket()
assert_eq("bound", udp.bound, false)
assert_true("not bound", not udp.bound)

# ─── UnixSocket ──────────────────────────────────────────────────────────────
section("UnixSocket")
var ux = UnixSocket("/tmp/test.sock")
assert_eq("path", ux.path, "/tmp/test.sock")
assert_true("not connected", not ux.connected)

# ─── PacketSocket ─────────────────────────────────────────────────────────────
section("PacketSocket")
var ps = PacketSocket(none)
assert_eq("sock init", ps.sock, none)

# ─── Connection ──────────────────────────────────────────────────────────────
section("Connection")
var conn = Connection("127.0.0.1", 8080)
assert_eq("host", conn.host, "127.0.0.1")
assert_eq("port", conn.port, 8080)
assert_true("not connected", not conn.connected)

# ─── SocketSelector ──────────────────────────────────────────────────────────
section("SocketSelector")
var sel = SocketSelector()
assert_eq("count init", sel.count, 0)

# ─── TcpProxy ────────────────────────────────────────────────────────────────
section("TcpProxy")
var proxy = TcpProxy(8888, "backend.example.com", 80)
assert_eq("listen port", proxy.listen_port, 8888)
assert_eq("target host", proxy.target_host, "backend.example.com")
assert_eq("target port", proxy.target_port, 80)

# ─── AddressBook ─────────────────────────────────────────────────────────────
section("AddressBook")
var ab = AddressBook()
ab.add("db-primary", "10.0.1.10", 5432)
ab.add("db-replica", "10.0.1.11", 5432)
ab.add("cache", "10.0.1.20", 6379)
var entry_host = ab.get_host("db-primary")
assert_eq("entry host", entry_host, "10.0.1.10")
var entry_port = ab.get_port("db-primary")
assert_eq("entry port", entry_port, 5432)
var missing_host = ab.get_host("unknown")
assert_eq("missing returns empty", missing_host, "")

# ─── TlsSocket ───────────────────────────────────────────────────────────────
section("TlsSocket")
var tls = TlsSocket()
assert_eq("port init", tls.port, 443)
assert_true("not connected", not tls.connected)
assert_true("verify peer default", tls.verify_peer)
tls.set_cert("/etc/ssl/cert.pem", "/etc/ssl/key.pem")
assert_eq("cert file", tls.cert_file, "/etc/ssl/cert.pem")
assert_eq("key file", tls.key_file, "/etc/ssl/key.pem")
tls.set_ca("/etc/ssl/ca.pem")
assert_eq("ca file", tls.ca_file, "/etc/ssl/ca.pem")
tls.set_verify(false)
assert_true("verify off", not tls.verify_peer)
assert_true("not connected after config", not tls.is_connected())

# ─── SocketPool ───────────────────────────────────────────────────────────────
section("SocketPool")
var pool = SocketPool("db.example.com", 5432, 2, 10)
assert_eq("host", pool.host, "db.example.com")
assert_eq("port", pool.port, 5432)
assert_eq("min", pool.min_size, 2)
assert_eq("max", pool.max_size, 10)
assert_eq("pool size init", pool.pool_size, 0)
assert_eq("active init", pool.active_count, 0)
assert_eq("idle init", pool.idle_count(), 0)
var stats = pool.stats()
assert_eq("stats pool_size", stats["pool_size"], 0)
assert_eq("stats active", stats["active"], 0)
assert_eq("stats max", stats["max"], 10)

# ─── PingClient ───────────────────────────────────────────────────────────────
section("PingClient")
var ping = PingClient()
assert_eq("timeout", ping.timeout, 5.0)
assert_eq("packet size", ping.packet_size, 64)

# ─── SocketPair ───────────────────────────────────────────────────────────────
section("SocketPair")
var sp = SocketPair()
assert_true("not created init", not sp.created)
assert_eq("fd_a init", sp.fd_a, none)
assert_eq("fd_b init", sp.fd_b, none)

# ─── MulticastSocket ──────────────────────────────────────────────────────────
section("MulticastSocket")
var mc = MulticastSocket("224.0.0.1", 5007)
assert_eq("group", mc.group_ip, "224.0.0.1")
assert_eq("port", mc.port, 5007)
assert_eq("ttl", mc.ttl, 1)
assert_true("not joined init", not mc.joined)
assert_true("not joined", not mc.is_joined())

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL SOCKETS TESTS PASSED ==="
else:
    print "=== SOME SOCKETS TESTS FAILED ==="

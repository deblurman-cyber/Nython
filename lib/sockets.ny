# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import net

# sockets.ny — Nython Sockets Library
# Raw TCP/UDP sockets, server sockets, broadcasting, multicast
# Usage: import "lib/sockets.ny"
# ═══════════════════════════════════════════════════════════════════════════════

# ─── TCP Socket ──────────────────────────────────────────────────────────────

class TcpSocket:
    def __init__(self):
        self.fd = -1
        self.connected = false
        self.remote_host = ""
        self.remote_port = 0
        self.buffer_size = 4096

    def create(self):
        self.fd = socket_create("tcp")
        return self.fd >= 0

    def connect(self, host, port):
        if self.fd < 0:
            self.create()
        var ok = socket_connect(self.fd, host, port)
        if ok:
            self.connected = true
            self.remote_host = host
            self.remote_port = port
        return ok

    def send(self, data):
        if self.fd < 0 or self.connected == false:
            return false
        return socket_send(self.fd, data)

    def send_line(self, data):
        return self.send(data + "\r\n")

    def recv(self, size):
        if self.fd < 0:
            return ""
        var data = socket_recv(self.fd, size)
        if data == none:
            return ""
        return data

    def recv_all(self):
        if self.fd < 0:
            return ""
        var data = tcp_recv_all(self.fd)
        if data == none:
            return ""
        return data

    def recv_line(self):
        var result = ""
        while true:
            var c = self.recv(1)
            if c == "" or c == none:
                break
            if c == "\n":
                break
            if c != "\r":
                result = result + c
        return result

    def set_timeout(self, ms):
        socket_setsockopt(self.fd, "timeout", ms)

    def set_nodelay(self):
        socket_setsockopt(self.fd, "nodelay", 1)

    def set_keepalive(self):
        socket_setsockopt(self.fd, "keepalive", 1)

    def close(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1
            self.connected = false

    def peer_address(self):
        return socket_getpeername(self.fd)

    def local_address(self):
        return socket_getsockname(self.fd)

    def is_connected(self):
        return self.connected and self.fd >= 0

# ─── TCP Server Socket ────────────────────────────────────────────────────────

class TcpServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.fd = -1
        self.backlog = 128
        self.running = false

    def start(self):
        self.fd = socket_create("tcp")
        if self.fd < 0:
            return false
        socket_setsockopt(self.fd, "reuseaddr", 1)
        var ok = socket_bind(self.fd, self.host, self.port)
        if ok == false:
            socket_close(self.fd)
            self.fd = -1
            return false
        socket_listen(self.fd, self.backlog)
        self.running = true
        return true

    def accept(self):
        if self.fd < 0:
            return none
        var client_fd = socket_accept(self.fd)
        if client_fd < 0:
            return none
        var client = TcpSocket()
        client.fd = client_fd
        client.connected = true
        return client

    def stop(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1
        self.running = false

    def serve(self, handler):
        if self.start() == false:
            return false
        while self.running:
            var client = self.accept()
            if client != none:
                handler(client)
        return true

    def serve_forever(self, handler):
        self.start()
        while true:
            var client = self.accept()
            if client != none:
                handler(client)

# ─── UDP Socket ──────────────────────────────────────────────────────────────

class UdpSocket:
    def __init__(self):
        self.fd = -1
        self.bound = false
        self.buffer_size = 65507

    def create(self):
        self.fd = socket_udp()
        return self.fd >= 0

    def bind(self, host, port):
        if self.fd < 0:
            self.create()
        var ok = socket_bind(self.fd, host, port)
        if ok:
            self.bound = true
        return ok

    def send_to(self, host, port, data):
        if self.fd < 0:
            self.create()
        return socket_sendto(self.fd, data, host, port)

    def recv_from(self):
        if self.fd < 0:
            return none
        return socket_recvfrom(self.fd, self.buffer_size)

    def broadcast(self, port, data):
        if self.fd < 0:
            self.create()
        socket_setsockopt(self.fd, "broadcast", 1)
        return socket_sendto(self.fd, data, "255.255.255.255", port)

    def close(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1
            self.bound = false

# ─── Unix Domain Socket (POSIX only) ─────────────────────────────────────────

class UnixSocket:
    def __init__(self, path):
        self.path = path
        self.fd = -1
        self.connected = false

    def connect(self):
        self.fd = socket_create("unix")
        if self.fd < 0:
            return false
        var ok = socket_connect(self.fd, self.path, 0)
        if ok:
            self.connected = true
        return ok

    def send(self, data):
        if self.fd < 0:
            return false
        return socket_send(self.fd, data)

    def recv(self, size):
        if self.fd < 0:
            return ""
        var data = socket_recv(self.fd, size)
        if data == none:
            return ""
        return data

    def close(self):
        if self.fd >= 0:
            socket_close(self.fd)
            self.fd = -1
            self.connected = false

# ─── Packet Protocol (length-prefixed framing) ───────────────────────────────

class PacketSocket:
    def __init__(self, sock):
        self.sock = sock

    def send_packet(self, data):
        var slen = len(data)
        var header = string_format("{:08d}", slen)
        self.sock.send(header + data)

    def recv_packet(self):
        var header = ""
        var remaining = 8
        while remaining > 0:
            var chunk = self.sock.recv(remaining)
            if chunk == "" or chunk == none:
                return none
            header = header + chunk
            remaining = remaining - len(chunk)
        if isdigit_str(header) == false:
            return none
        var size = int(header)
        var data = ""
        while len(data) < size:
            var needed = size - len(data)
            var chunk = self.sock.recv(needed)
            if chunk == "" or chunk == none:
                return none
            data = data + chunk
        return data

# ─── Connection (high-level wrapper) ─────────────────────────────────────────

class Connection:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.sock = TcpSocket()
        self.connected = false
        self.auto_reconnect = false
        self.reconnect_delay = 2.0

    def open(self):
        var ok = self.sock.connect(self.host, self.port)
        self.connected = ok
        return ok

    def close(self):
        self.sock.close()
        self.connected = false

    def send(self, data):
        if self.connected == false and self.auto_reconnect:
            self.open()
        return self.sock.send(data)

    def recv(self, size):
        return self.sock.recv(size)

    def request(self, data):
        self.send(data)
        return self.sock.recv_all()

    def __enter__(self):
        self.open()
        return self

    def __exit__(self):
        self.close()

# ─── Socket Selector (select/poll wrapper) ────────────────────────────────────

class SocketSelector:
    def __init__(self):
        self.sockets = []
        self.count = 0

    def add(self, sock):
        self.sockets[self.count] = sock
        self.count = self.count + 1

    def remove(self, sock):
        var new_socks = []
        var new_count = 0
        var i = 0
        while i < self.count:
            if self.sockets[i].fd != sock.fd:
                new_socks.append(self.sockets[i])
            i = i + 1
        self.sockets = new_socks
        self.count = new_count

    def wait(self, timeout_ms):
        var fds = []
        var i = 0
        while i < self.count:
            fds.append(self.sockets[i].fd)
        return socket_select(fds, timeout_ms)

# ─── Proxy ───────────────────────────────────────────────────────────────────

class TcpProxy:
    def __init__(self, listen_port, target_host, target_port):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port
        self.server = TcpServer("0.0.0.0", listen_port)
        self.running = false

    def _handle_client(self, client):
        var upstream = TcpSocket()
        if upstream.connect(self.target_host, self.target_port) == false:
            client.close()
            return
        var data = client.recv(4096)
        while len(data) > 0:
            upstream.send(data)
            var resp = upstream.recv(4096)
            if len(resp) == 0:
                break
            client.send(resp)
            var data = client.recv(4096)
        client.close()
        upstream.close()

    def start(self):
        self.running = true
        self.server.serve(lambda c: self._handle_client(c))

# ─── Address Book ─────────────────────────────────────────────────────────────

class AddressBook:
    def __init__(self):
        self.entries = {}

    def add(self, name, host, port):
        var entry = {}
        entry["host"] = host
        entry["port"] = port
        self.entries[name] = entry

    def get_host(self, name):
        var e = self.entries[name]
        if e == none:
            return ""
        return e["host"]

    def get_port(self, name):
        var e = self.entries[name]
        if e == none:
            return 0
        return e["port"]

    def connect(self, name):
        var e = self.entries[name]
        if e == none:
            return none
        var conn = Connection(e["host"], e["port"])
        conn.open()
        return conn

# ─── TlsSocket ────────────────────────────────────────────────────────────────

class TlsSocket:
    def __init__(self):
        self.fd = none
        self.host = ""
        self.port = 443
        self.connected = false
        self.cert_file = ""
        self.key_file = ""
        self.ca_file = ""
        self.verify_peer = true
        self.timeout = 30

    def set_cert(self, cert_file, key_file):
        self.cert_file = cert_file
        self.key_file = key_file
        return self

    def set_ca(self, ca_file):
        self.ca_file = ca_file
        return self

    def set_verify(self, verify):
        self.verify_peer = verify
        return self

    def connect(self, host, port):
        self.host = host
        self.port = port
        self.fd = socket_create("tcp")
        if self.fd == none:
            return false
        var ok = socket_connect(self.fd, host, port)
        if ok:
            self.connected = true
        return ok

    def send(self, data):
        if self.fd == none or not self.connected:
            return false
        return socket_send(self.fd, data) > 0

    def recv(self, size):
        if self.fd == none or not self.connected:
            return none
        return socket_recv(self.fd, size)

    def close(self):
        if self.fd != none:
            socket_close(self.fd)
        self.connected = false
        self.fd = none

    def is_connected(self):
        return self.connected


# ─── SocketPool ───────────────────────────────────────────────────────────────

class PooledSocket:
    def __init__(self, fd, host, port):
        self.fd = fd
        self.host = host
        self.port = port
        self.in_use = false
        self.created_at = time_now()
        self.last_used = time_now()
        self.use_count = 0


class SocketPool:
    def __init__(self, host, port, min_size, max_size):
        self.host = host
        self.port = port
        self.min_size = min_size
        self.max_size = max_size
        self.sockets = []
        self.pool_size = 0
        self.active_count = 0
        self.idle_timeout = 60.0

    def _create_socket(self):
        var fd = socket_create("tcp")
        if fd == none:
            return none
        var ok = socket_connect(fd, self.host, self.port)
        if not ok:
            socket_close(fd)
            return none
        var ps = PooledSocket(fd, self.host, self.port)
        self.sockets.append(ps)
        self.pool_size = self.pool_size + 1
        return ps

    def acquire(self):
        var i = 0
        while i < self.pool_size:
            if not self.sockets[i].in_use:
                self.sockets[i].in_use = true
                self.sockets[i].last_used = time_now()
                self.sockets[i].use_count = self.sockets[i].use_count + 1
                self.active_count = self.active_count + 1
                return self.sockets[i]
            i = i + 1
        if self.pool_size < self.max_size:
            var ps = self._create_socket()
            if ps != none:
                ps.in_use = true
                self.active_count = self.active_count + 1
            return ps
        return none

    def release(self, ps):
        ps.in_use = false
        ps.last_used = time_now()
        if self.active_count > 0:
            self.active_count = self.active_count - 1

    def idle_count(self):
        return self.pool_size - self.active_count

    def close_idle(self):
        var now = time_now()
        var kept = []
        var i = 0
        while i < self.pool_size:
            var ps = self.sockets[i]
            if ps.in_use or (now - ps.last_used) < self.idle_timeout:
                kept.append(ps)
            else:
                socket_close(ps.fd)
            i = i + 1
        self.sockets = kept
        self.pool_size = len(kept)

    def close_all(self):
        var i = 0
        while i < self.pool_size:
            socket_close(self.sockets[i].fd)
            i = i + 1
        self.sockets = []
        self.pool_size = 0
        self.active_count = 0

    def stats(self):
        var s = {}
        s["pool_size"] = self.pool_size
        s["active"] = self.active_count
        s["idle"] = self.idle_count()
        s["max"] = self.max_size
        return s


# ─── PingClient ───────────────────────────────────────────────────────────────

class PingResult:
    def __init__(self, host, success, latency_ms, error):
        self.host = host
        self.success = success
        self.latency_ms = latency_ms
        self.error = error


class PingClient:
    def __init__(self):
        self.timeout = 5.0
        self.packet_size = 64

    def ping(self, host):
        var start = time_ms()
        var fd = socket_create("tcp")
        if fd == none:
            return PingResult(host, false, 0.0, "socket_create failed")
        var ok = socket_connect(fd, host, 80)
        var latency = time_ms() - start
        socket_close(fd)
        if ok:
            return PingResult(host, true, latency, "")
        return PingResult(host, false, latency, "connection refused")

    def ping_many(self, hosts):
        var results = []
        var i = 0
        while i < len(hosts):
            results.append(self.ping(hosts[i]))
            i = i + 1
        return results

    def reachable(self, host):
        var r = self.ping(host)
        return r.success

    def avg_latency(self, host, count):
        var total = 0.0
        var ok_count = 0
        var i = 0
        while i < count:
            var r = self.ping(host)
            if r.success:
                total = total + r.latency_ms
                ok_count = ok_count + 1
            i = i + 1
        if ok_count == 0:
            return -1.0
        return total / float(ok_count)


# ─── UnixSocket (extended) ────────────────────────────────────────────────────

class SocketPair:
    def __init__(self):
        self.fd_a = none
        self.fd_b = none
        self.created = false

    def create(self):
        self.fd_a = socket_create("tcp")
        self.fd_b = socket_create("tcp")
        self.created = (self.fd_a != none and self.fd_b != none)
        return self.created

    def close(self):
        if self.fd_a != none:
            socket_close(self.fd_a)
        if self.fd_b != none:
            socket_close(self.fd_b)
        self.created = false


# ─── MulticastSocket ──────────────────────────────────────────────────────────

class MulticastSocket:
    def __init__(self, group_ip, port):
        self.group_ip = group_ip
        self.port = port
        self.fd = none
        self.joined = false
        self.ttl = 1

    def join(self):
        self.fd = socket_udp()
        if self.fd == none:
            return false
        self.joined = true
        return true

    def leave(self):
        if self.fd != none:
            socket_close(self.fd)
        self.joined = false
        self.fd = none

    def send(self, data):
        if self.fd == none or not self.joined:
            return false
        return socket_sendto(self.fd, data, self.group_ip, self.port) > 0

    def recv(self, size):
        if self.fd == none:
            return none
        return socket_recvfrom(self.fd, size)

    def is_joined(self):
        return self.joined


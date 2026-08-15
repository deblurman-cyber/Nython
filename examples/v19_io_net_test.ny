var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== FILE I/O ==="
import io
write("/tmp/ny19_a.txt", "hello nython")
t("write_read", cat("/tmp/ny19_a.txt"), "hello nython")
t("exists_t", exists("/tmp/ny19_a.txt"), true)
t("exists_f", exists("/tmp/ny19_nonexist"), false)
t("file_size", file_size("/tmp/ny19_a.txt"), 12)

print "=== READLINES ==="
writelines("/tmp/ny19_lines.txt", ["alpha", "beta", "gamma"])
var lines_data = readlines("/tmp/ny19_lines.txt")
t("readlines", len(lines_data), 3)
t("line0", lines_data[0], "alpha")
t("line2", lines_data[2], "gamma")

print "=== FILE HANDLE ==="
var fh = open("/tmp/ny19_handle.txt", "w")
t("open", fh > 0, true)
file_write(fh, "handle test data")
file_close(fh)
var fh2 = open("/tmp/ny19_handle.txt", "r")
t("fread", file_read(fh2), "handle test data")
file_close(fh2)

print "=== FILE OPS ==="
write("/tmp/ny19_orig.txt", "original")
file_copy("/tmp/ny19_orig.txt", "/tmp/ny19_cp.txt")
t("copy", cat("/tmp/ny19_cp.txt"), "original")
file_rename("/tmp/ny19_cp.txt", "/tmp/ny19_mv.txt")
t("rename", cat("/tmp/ny19_mv.txt"), "original")
t("old_gone", exists("/tmp/ny19_cp.txt"), false)
file_delete("/tmp/ny19_mv.txt")
t("delete", exists("/tmp/ny19_mv.txt"), false)

print "=== APPEND ==="
write("/tmp/ny19_app.txt", "A")
file_append("/tmp/ny19_app.txt", "B")
file_append("/tmp/ny19_app.txt", "C")
t("append", cat("/tmp/ny19_app.txt"), "ABC")

print "=== NETWORK ==="
import net
t("dns", dns_resolve("localhost"), "127.0.0.1")
t("url_enc", url_encode("a b"), "a%20b")
t("url_dec", url_decode("a%20b"), "a b")

print "=== TCP ECHO ==="
var srv = socket_tcp()
socket_setsockopt(srv, "reuseaddr", 1)
socket_bind(srv, 59800)
socket_listen(srv, 1)
var cli = socket_tcp()
socket_connect(cli, "127.0.0.1", 59800)
var conn = socket_accept(srv)
socket_send(cli, "ECHO_TEST")
var msg = socket_recv(conn, 1024)
t("tcp_echo", msg, "ECHO_TEST")
socket_send(conn, "REPLY:" + msg)
t("tcp_reply", socket_recv(cli, 1024), "REPLY:ECHO_TEST")
socket_close(cli)
socket_close(conn)
socket_close(srv)

print "=== UDP ==="
var us = socket_udp()
var ur = socket_udp()
socket_bind(ur, 59801)
socket_sendto(us, "UDP_MSG", "127.0.0.1", 59801)
var udp_r = socket_recvfrom(ur, 1024)
t("udp", udp_r[0], "UDP_MSG")
socket_close(us)
socket_close(ur)

print "=== OUTPUT ==="
import io
write("/tmp/ny19_log.txt", "")
print_to("/tmp/ny19_log.txt", "log entry 1")
print_to("/tmp/ny19_log.txt", "log entry 2")
var log_lines = readlines("/tmp/ny19_log.txt")
t("print_to", len(log_lines), 2)

print ""
print "============================================"
print "  V19 IO+NET: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

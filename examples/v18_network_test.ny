var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== NETWORK MODULE ==="
import net

# DNS
t("dns", dns_resolve("localhost"), "127.0.0.1")

# Byte order
t("htons_ntohs", ntohs(htons(8080)), 8080)
t("htonl_ntohl", ntohl(htonl(12345)), 12345)

# URL
t("url_enc", url_encode("a b"), "a%20b")
t("url_dec", url_decode("a%20b"), "a b")

# TCP lifecycle
var tcp = socket_tcp()
t("tcp_create", tcp > 0, true)
socket_close(tcp)

# UDP lifecycle
var udp = socket_udp()
t("udp_create", udp > 0, true)
socket_close(udp)

# TCP Client/Server
var srv = socket_tcp()
socket_setsockopt(srv, "reuseaddr", 1)
socket_bind(srv, 49876)
socket_listen(srv, 1)
var cli = socket_tcp()
socket_connect(cli, "127.0.0.1", 49876)
var conn = socket_accept(srv)
t("accept", conn > 0, true)
socket_send(cli, "ping")
t("recv", socket_recv(conn, 1024), "ping")
socket_send(conn, "pong")
t("resp", socket_recv(cli, 1024), "pong")
socket_close(cli)
socket_close(conn)
socket_close(srv)

# UDP send/recv
var us = socket_udp()
var ur = socket_udp()
socket_bind(ur, 49877)
socket_sendto(us, "udp_test", "127.0.0.1", 49877)
var udp_data = socket_recvfrom(ur, 1024)
t("udp_data", udp_data[0], "udp_test")
t("udp_from", udp_data[1], "127.0.0.1")
socket_close(us)
socket_close(ur)

# Select
var ss = socket_tcp()
socket_setsockopt(ss, "reuseaddr", 1)
socket_bind(ss, 49878)
socket_listen(ss, 1)
var sc = socket_tcp()
socket_connect(sc, "127.0.0.1", 49878)
var ready = socket_select([ss], 100)
t("select", len(ready), 1)
socket_close(sc)
socket_close(ss)

print ""
print "============================================"
print "  V18 NETWORK: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

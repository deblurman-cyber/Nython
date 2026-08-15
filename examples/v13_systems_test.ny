var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== SHELL COMMANDS ==="
var sh_result = shell("echo test")
t("shell", sh_result, "test")
t("pwd", len(pwd()) > 0, true)
write("/tmp/ny_test.txt", "hello nython")
t("write_cat", cat("/tmp/ny_test.txt"), "hello nython")
t("exists_t", exists("/tmp/ny_test.txt"), true)
t("exists_f", exists("/tmp/nonexistent_xyz"), false)
t("env", len(env("HOME")) > 0, true)
var files = ls("/tmp")
t("ls_type", type(files), "list")
t("ls_len", len(files) > 0, true)

print "=== AI/ML TENSORS ==="
import ai
var t1 = tensor([1.0, 2.0, 3.0, 4.0])
var t2 = tensor([5.0, 6.0, 7.0, 8.0])
t("tensor_add", str(tensor_add(t1, t2)), "[6, 8, 10, 12]")
t("tensor_sub", str(tensor_sub(t2, t1)), "[4, 4, 4, 4]")
t("tensor_mul", str(tensor_mul(t1, t2)), "[5, 12, 21, 32]")
t("tensor_dot", tensor_dot(t1, t2), 70)
t("tensor_sum", tensor_sum(t1), 10)
t("tensor_mean", tensor_mean(t1), 2.5)
t("tensor_max", tensor_max(t2), 8)
t("tensor_min", tensor_min(t1), 1)
t("tensor_scale", str(tensor_scale(t1, 3.0)), "[3, 6, 9, 12]")
var sq = tensor_apply(t1, lambda x: x * x)
t("tensor_apply", str(sq), "[1, 4, 9, 16]")

print "=== ACTIVATION FUNCTIONS ==="
t("relu_neg", relu(-5), 0)
t("relu_pos", relu(5), 5)
t("sigmoid_0", sigmoid(0), 0.5)
t("sigmoid_pos", sigmoid(100) > 0.99, true)
t("sigmoid_neg", sigmoid(-100) < 0.01, true)

print "=== THREADING ==="
import threading
var mtx = mutex_create()
t("lock", mutex_lock(mtx), true)
t("unlock", mutex_unlock(mtx), true)

print "=== NETWORK ==="
import net
t("url_enc", url_encode("hello world"), "hello%20world")
t("url_dec", url_decode("hello%20world"), "hello world")

print "=== CRYPTO ==="
import crypto
t("md5", md5("hello"), "5d41402abc4b2a76b9719d911017c592")
t("sha256_len", len(sha256("hello")), 64)

print "=== JSON ==="
import json
var data = {"name": "Nython", "version": 1}
var encoded = json_encode(data)
t("json_enc", "Nython" in encoded, true)

print "=== REGEX ==="
import re
t("re_match", regex_match("[0-9]+", "abc123def"), "123")
t("re_replace", regex_replace("[0-9]+", "N", "a1b2"), "aNbN")

print ""
print "============================================"
print "  V13 SYSTEMS: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

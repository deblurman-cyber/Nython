var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== NYTORCH TENSORS ==="
import nytorch
import "examples/lib/tensor.ny"
import "examples/lib/nn.ny"
import "examples/lib/agent.ny"
var t1 = Tensor([1.0, 2.0, 3.0, 4.0])
var t2 = Tensor([5.0, 6.0, 7.0, 8.0])
t("tensor_str", str(t1), "Tensor([1, 2, 3, 4])")
t("tensor_add", str(t1 + t2), "Tensor([6, 8, 10, 12])")
t("tensor_sub", str(t2 - t1), "Tensor([4, 4, 4, 4])")
t("tensor_mul", str(t1 * t2), "Tensor([5, 12, 21, 32])")
t("tensor_dot", t1.dot(t2), 70)
t("tensor_sum", t1.sum(), 10)
t("tensor_mean", t1.mean(), 2.5)
t("tensor_scale", str(t1.scale(3.0)), "Tensor([3, 6, 9, 12])")
t("tensor_len", len(t1), 4)
t("tensor_idx", t1[0] > 0, true)

print "=== NEURAL NETWORK ==="
var layer = Linear(4, 2)
var output = layer.forward(t1)
t("nn_type", str(output).startswith("Tensor"), true)
t("nn_len", len(output), 2)

print "=== AI AGENT ==="
var bot = Agent("NyBot")
bot.learn("language", "Nython")
bot.learn("creator", "Perrino Varman")
bot.learn("version", "0.3")
bot.learn("paradigm", "multi-syntax")
t("agent_ask", bot.ask("language"), "Nython")
t("agent_creator", bot.ask("creator"), "Perrino Varman")
t("agent_mem", bot.memory(), 4)
t("agent_str", str(bot), "Agent(NyBot,4 facts)")
t("agent_unknown", bot.ask("nonexistent"), none)

print "=== SHELL COMMANDS ==="
write("/tmp/ny_test_file.txt", "hello nython")
t("write_read", cat("/tmp/ny_test_file.txt"), "hello nython")
t("exists_t", exists("/tmp/ny_test_file.txt"), true)
t("exists_f", exists("/tmp/no_such_file_xyz"), false)
t("pwd", len(pwd()) > 0, true)
t("env", len(env("HOME")) > 0, true)
var files = ls("/tmp")
t("ls_type", type(files), "list")
t("ls_len", len(files) > 0, true)

print "=== ACTIVATION FUNCTIONS ==="
t("relu_neg", relu(-5), 0)
t("relu_pos", relu(3), 3)
t("sigmoid_0", sigmoid(0), 0.5)
t("sigmoid_big", sigmoid(100) > 0.99, true)

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

print "=== ALL MODULES ==="
import math
t("pi", PI > 3.14, true)
t("sqrt", sqrt(25), 5)
import collections
var wc = Counter("a b a a".split(" "))
t("counter", wc["a"], 3)
import json
t("json", "hello" in json_encode({"hello": "world"}), true)
import re
t("regex", regex_match("[0-9]+", "abc123"), "123")

print ""
print "============================================"
print "  V14 ALL SYSTEMS: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

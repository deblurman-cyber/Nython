var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== REVERSE MULTIPLY ==="
t("int_str", 3 * "ab", "ababab")
t("int_list", str(2 * [1, 2]), "[1, 2, 1, 2]")
t("str_int", "xy" * 3, "xyxyxy")
t("list_int", str([1] * 4), "[1, 1, 1, 1]")

print "=== SLICE WITH STEP ==="
var lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
t("step2", str(lst[::2]), "[0, 2, 4, 6, 8]")
t("range_step", str(lst[1:8:2]), "[1, 3, 5, 7]")
t("reverse", str(lst[::-1]), "[9, 8, 7, 6, 5, 4, 3, 2, 1, 0]")
t("step3", str(lst[::3]), "[0, 3, 6, 9]")
t("rev_range", str(lst[7:2:-1]), "[7, 6, 5, 4, 3]")

print "=== STRING SLICE STEP ==="
var s = "abcdefghij"
t("str_step", s[::2], "acegi")
t("str_rev", s[::-1], "jihgfedcba")

print "=== NYTORCH ==="
import nytorch
import "examples/lib/tensor.ny"
import "examples/lib/nn.ny"
import "examples/lib/agent.ny"
var t1 = Tensor([1.0, 2.0, 3.0])
var t2 = Tensor([4.0, 5.0, 6.0])
t("t_add", str(t1 + t2), "Tensor([5, 7, 9])")
t("t_dot", t1.dot(t2), 32)
t("t_sum", t1.sum(), 6)
t("t_mean", t1.mean(), 2)
var nn = Linear(3, 2)
var out = nn.forward(t1)
t("nn_out", len(out), 2)
var bot = Agent("Ny")
bot.learn("x", "hello")
t("agent", bot.ask("x"), "hello")
t("agent_mem", bot.memory(), 1)

print "=== SHELL ==="
write("/tmp/ny15.txt", "nython")
t("write", cat("/tmp/ny15.txt"), "nython")
t("exists", exists("/tmp/ny15.txt"), true)
t("pwd", len(pwd()) > 0, true)

print ""
print "============================================"
print "  V15 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

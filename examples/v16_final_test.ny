var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== RANGE ==="
t("range5", str(range(5)), "[0, 1, 2, 3, 4]")
t("range28", str(range(2, 8)), "[2, 3, 4, 5, 6, 7]")
t("range_step", str(range(0, 10, 2)), "[0, 2, 4, 6, 8]")
t("range_neg", str(range(5, 0, -1)), "[5, 4, 3, 2, 1]")

print "=== REVERSE MUL ==="
t("int_str", 3 * "ab", "ababab")
t("int_list", str(2 * [1, 2]), "[1, 2, 1, 2]")

print "=== SLICE STEP ==="
var lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
t("step2", str(lst[::2]), "[0, 2, 4, 6, 8]")
t("reverse", str(lst[::-1]), "[9, 8, 7, 6, 5, 4, 3, 2, 1, 0]")
t("str_rev", "hello"[::-1], "olleh")

print "=== COMPLEX ==="
var words = ["hello", "world"]
t("map_upper", str(map(lambda w: w.upper(), words)), "[HELLO, WORLD]")
t("reduce_join", reduce(lambda a, b: a + " " + b, words), "hello world")
var data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
t("pipeline", sum(filter(lambda x: x % 2 == 0, data)), 30)

print "=== LINKED LIST ==="
class Node:
    def init(self, v, n):
        self.v = v
        self.n = n
    def __str__(self):
        if self.n == none:
            return str(self.v)
        return str(self.v) + "->" + str(self.n)
var ll = Node(1, Node(2, Node(3, none)))
t("linked", str(ll), "1->2->3")

print ""
print "============================================"
print "  V16 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

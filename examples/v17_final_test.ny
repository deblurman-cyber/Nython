var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== NESTED COMPREHENSION ==="
t("nested_mul", str([x*y for x in range(1,4) for y in range(1,4)]), "[1, 2, 3, 2, 4, 6, 3, 6, 9]")
t("nested_pair", len([[i,j] for i in range(3) for j in range(3)]), 9)
t("filter_comp", str([x for x in range(10) if x % 3 == 0]), "[0, 3, 6, 9]")

print "=== DICT COMP WITH FILTER ==="
var scores = {"Alice": 95, "Bob": 67, "Charlie": 88}
var high = {k: v for k, v in scores.items() if v >= 80}
t("dict_filter_len", len(high), 2)
t("dict_filter_val", high["Alice"], 95)
var squares = {str(x): x*x for x in range(5)}
t("dict_comp", squares["4"], 16)

print "=== RANGE ==="
t("range5", str(range(5)), "[0, 1, 2, 3, 4]")
t("range_step", str(range(0,10,3)), "[0, 3, 6, 9]")
t("range_neg", str(range(5,0,-1)), "[5, 4, 3, 2, 1]")

print "=== PATTERNS ==="
# Linked list
class Node:
    def init(self, v, n):
        self.v = v
        self.n = n
    def __str__(self):
        if self.n == none:
            return str(self.v)
        return str(self.v) + "->" + str(self.n)
t("linked", str(Node(1, Node(2, Node(3, none)))), "1->2->3")

# Binary tree
class Tree:
    def init(self, v, l, r):
        self.v = v
        self.l = l
        self.r = r
    def total(self):
        var s = self.v
        if self.l != none:
            s = s + self.l.total()
        if self.r != none:
            s = s + self.r.total()
        return s
var tree = Tree(1, Tree(2, Tree(4, none, none), none), Tree(3, none, Tree(5, none, none)))
t("tree_sum", tree.total(), 15)

# Router pattern
class Router:
    def init(self):
        self.routes = {}
    def add(self, path, handler):
        self.routes[path] = handler
        return self
    def handle(self, path):
        if path in self.routes:
            return self.routes[path](path)
        return "404"
var router = Router()
router.add("/", lambda p: "Home").add("/api", lambda p: "API")
t("router_home", router.handle("/"), "Home")
t("router_api", router.handle("/api"), "API")
t("router_404", router.handle("/x"), "404")

# Closure pipeline
def make_pipeline(*fns):
    def run(x):
        var result = x
        for f in fns:
            result = f(result)
        return result
    return run
var pipe = make_pipeline(lambda x: x+1, lambda x: x*2, lambda x: x-3)
t("pipeline", pipe(5), 9)

print ""
print "============================================"
print "  V17 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

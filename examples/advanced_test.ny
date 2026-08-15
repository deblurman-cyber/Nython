var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== 1. NESTED COMPREHENSION EXPRESSIONS ==="
t("comp_nested", str([x + 1 for x in [y * 2 for y in range(1, 5)]]), "[3, 5, 7, 9]")

print "=== 2. LAMBDA AS DEFAULT STRATEGY ==="
def apply_all(lst, ops):
    var result = lst
    for op in ops:
        result = result.map(op)
    return result
t("multi_map", str(apply_all([1,2,3], [lambda x: x*2, lambda x: x+10, lambda x: x*-1])), "[-12, -14, -16]")

print "=== 3. RECURSIVE FLATTEN ==="
def flat(lst):
    var result = []
    for item in lst:
        if type(item) == "list":
            for sub in flat(item):
                result.append(sub)
        else:
            result.append(item)
    return result
t("flatten_deep", str(flat([1,[2,[3,[4]],5],6])), "[1, 2, 3, 4, 5, 6]")

print "=== 4. MAP-REDUCE WORD COUNT ==="
var words = "the cat sat on the mat the cat".split(" ")
var counts = {}
for w in words:
    if w in counts:
        counts[w] = counts[w] + 1
    else:
        counts[w] = 1
t("wc_the", counts["the"], 3)
t("wc_cat", counts["cat"], 2)
t("wc_sat", counts["sat"], 1)

print "=== 5. CURRYING ==="
def curry_add(a):
    def inner(b):
        return a + b
    return inner
var add5 = curry_add(5)
var add10 = curry_add(10)
t("curry1", add5(3), 8)
t("curry2", add10(7), 17)
t("curry_chain", curry_add(1)(curry_add(2)(3)), 6)

print "=== 6. CLASS METHOD CHAINING ==="
class StringBuilder:
    def init(self):
        self.parts = []
    def add(self, s):
        self.parts.append(s)
        return self
    def build(self):
        return "".join(self.parts)
    def length(self):
        return len(self.build())
t("sb_chain", StringBuilder().add("Hello").add(" ").add("World").build(), "Hello World")
t("sb_len", StringBuilder().add("abc").add("de").length(), 5)

print "=== 7. HIGHER ORDER FILTER ==="
def make_filter(pred):
    def do_filter(lst):
        return lst.filter(pred)
    return do_filter
var get_positives = make_filter(lambda x: x > 0)
var get_evens = make_filter(lambda x: x % 2 == 0)
t("ho_filter_pos", str(get_positives([-3, -1, 0, 2, 5])), "[2, 5]")
t("ho_filter_even", str(get_evens(range(1, 11))), "[2, 4, 6, 8, 10]")

print "=== 8. MATRIX OPS ==="
def mat_new(rows, cols, val):
    var m = []
    for i in range(0, rows):
        var row = []
        for j in range(0, cols):
            row.append(val)
        m.append(row)
    return m

def mat_mul(a, b):
    var rows = len(a)
    var cols = len(b[0])
    var k = len(b)
    var c = mat_new(rows, cols, 0)
    for i in range(0, rows):
        for j in range(0, cols):
            var s = 0
            for p in range(0, k):
                s = s + a[i][p] * b[p][j]
            c[i][j] = s
    return c

var identity = [[1,0],[0,1]]
var mat = [[2,3],[4,5]]
var result = mat_mul(mat, identity)
t("mat_identity", str(result[0]) + "," + str(result[1]), "[2, 3],[4, 5]")

var a = [[1,2],[3,4]]
var b = [[5,6],[7,8]]
var ab = mat_mul(a, b)
t("mat_mul", str(ab[0]) + "," + str(ab[1]), "[19, 22],[43, 50]")

print "=== 9. GRAPH BFS ==="
def bfs(graph, start):
    var visited = []
    var queue = [start]
    while len(queue) > 0:
        var node = queue[0]
        queue = queue.slice(1, len(queue))
        if not (node in visited):
            visited.append(node)
            if node in graph:
                var neighbors = graph[node]
                for n in neighbors:
                    if not (n in visited):
                        queue.append(n)
    return visited

var g = {"A": ["B", "C"], "B": ["D"], "C": ["D", "E"], "D": [], "E": []}
t("bfs", str(bfs(g, "A")), "[A, B, C, D, E]")

print "=== 10. GENERIC SORT ==="
def insertion_sort(lst):
    var result = [] + lst
    for i in range(1, len(result)):
        var key = result[i]
        var j = i - 1
        while j >= 0 and result[j] > key:
            result[j + 1] = result[j]
            j = j - 1
        result[j + 1] = key
    return result
t("isort", str(insertion_sort([64, 34, 25, 12, 22, 11, 90])), "[11, 12, 22, 25, 34, 64, 90]")

print ""
print "============================================"
print "  ADVANCED: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== LAMBDA CLOSURES ==="
def make_adder(n):
    return lambda x: x + n
var add5 = make_adder(5)
var add10 = make_adder(10)
t("closure_add5", add5(3), 8)
t("closure_add10", add10(3), 13)
t("closure_add5b", add5(100), 105)

def multiplier(factor):
    return lambda x: x * factor
var double_fn = multiplier(2)
var triple_fn = multiplier(3)
t("mul_double", double_fn(7), 14)
t("mul_triple", triple_fn(7), 21)

def make_counter(start):
    var count = start
    def inc():
        count = count + 1
        return count
    return inc
var c = make_counter(0)
t("counter1", c(), 1)
t("counter2", c(), 2)
t("counter3", c(), 3)

print "=== MAP/FILTER/REDUCE ==="
t("map_double", str(map(lambda x: x * 2, [1,2,3,4,5])), "[2, 4, 6, 8, 10]")
t("map_square", str(map(lambda x: x * x, [1,2,3])), "[1, 4, 9]")
t("map_str", str(map(lambda x: str(x) + "!", [1,2,3])), "[1!, 2!, 3!]")

t("filter_gt", str(filter(lambda x: x > 3, [1,2,3,4,5])), "[4, 5]")
t("filter_even", str(filter(lambda x: x % 2 == 0, [1,2,3,4,5,6])), "[2, 4, 6]")

t("reduce_sum", reduce(lambda a, b: a + b, [1,2,3,4,5]), 15)
t("reduce_mul", reduce(lambda a, b: a * b, [1,2,3,4,5]), 120)
t("reduce_init", reduce(lambda a, b: a + b, [1,2,3], 100), 106)
t("reduce_max", reduce(lambda a, b: a if a > b else b, [3,1,4,1,5,9,2,6]), 9)

print "=== FUNCTIONAL PIPELINES ==="
var nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var result = filter(lambda x: x % 2 == 0, nums)
result = map(lambda x: x * x, result)
t("pipeline", str(result), "[4, 16, 36, 64, 100]")
t("pipeline_sum", reduce(lambda a, b: a + b, result), 220)

print "=== HIGHER ORDER FUNCTIONS ==="
def compose(f, g):
    return lambda x: f(g(x))
var add1_then_double = compose(lambda x: x * 2, lambda x: x + 1)
t("compose", add1_then_double(5), 12)

def apply_all(fns, x):
    var results = []
    for f in fns:
        results.append(f(x))
    return results
var fns = [lambda x: x + 1, lambda x: x * 2, lambda x: x * x]
t("apply_all", str(apply_all(fns, 5)), "[6, 10, 25]")

print "=== LIST METHOD MAP/FILTER ==="
var data = [1, 2, 3, 4, 5]
t("list_map", str(data.map(lambda x: x * 10)), "[10, 20, 30, 40, 50]")
t("list_filter", str(data.filter(lambda x: x > 3)), "[4, 5]")

print "=== NUMERIC SUFFIXES ==="
t("1k", 1k, 1000)
t("10k", 10k, 10000)
t("1.5k", 1.5k, 1500)
t("1M_int", int(1M), 1000000)
t("1G_int", int(1G), 1000000000)
t("kilo_add", 1k + 500, 1500)
t("kilo_cmp", 2k > 1999, true)

print "=== VARARGS ==="
def sum_all(*args):
    var total = 0
    for x in args:
        total = total + x
    return total
t("varargs3", sum_all(1, 2, 3), 6)
t("varargs5", sum_all(10, 20, 30, 40, 50), 150)

def first_and_rest(first, *rest):
    return str(first) + ":" + str(len(rest))
t("first_rest", first_and_rest(1, 2, 3, 4), "1:3")

print ""
print "============================================"
print "  V4 LAMBDA/FUNCTIONAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

import nytorch

var passed = 0
var failed = 0

def check(name, got, expected):
    var got_s = str(got)
    var exp_s = str(expected)
    if got_s == exp_s:
        passed += 1
    else:
        failed += 1
        print "FAIL:", name, "| got:", got_s, "| expected:", exp_s

# ── NyTorch tensor operations ────────────────────────────────────
var t1 = tensor([1.0, 2.0, 3.0, 4.0])
var t2 = tensor([2.0, 2.0, 2.0, 2.0])
check("tensor add", tensor_add(t1, t2)[0], 3.0)
check("tensor mul", tensor_mul(t1, t2)[1], 4.0)
check("tensor sub", tensor_sub(t2, t1)[2], -1.0)

var t3 = tensor_zeros(3)
check("zeros", t3[0], 0.0)
check("zeros len", len(t3), 3)

var t4 = tensor_ones(4)
check("ones", t4[3], 1.0)

check("dot product", tensor_dot([1,2,3],[4,5,6]), 32.0)
check("tensor sum", tensor_sum([1.0,2.0,3.0,4.0]), 10.0)
check("tensor mean", tensor_mean([1.0,2.0,3.0,4.0]), 2.5)

var t5 = tensor_softmax([1.0, 2.0, 3.0])
check("softmax sums to 1", round(t5[0]+t5[1]+t5[2]), 1)
check("softmax monotonic", t5[0] < t5[1], true)
check("softmax monotonic2", t5[1] < t5[2], true)

# ── Math functions ────────────────────────────────────────────────
check("abs neg", abs(-5), 5)
check("abs pos", abs(5), 5)
check("ceil", ceil(3.2), 4)
check("floor", floor(3.9), 3)
check("round down", round(3.4), 3)
check("round up", round(3.5), 4)
check("pow", int(pow(2, 10)), 1024)
check("sqrt", sqrt(144.0), 12.0)
check("min2", min(3, 7), 3)
check("max2", max(3, 7), 7)
check("min list", min([5, 2, 8, 1, 9]), 1)
check("max list", max([5, 2, 8, 1, 9]), 9)
check("sum list", sum([1, 2, 3, 4, 5]), 15)
check("clamp lo", clamp(-5, 0, 10), 0)
check("clamp hi", clamp(15, 0, 10), 10)
check("clamp mid", clamp(5, 0, 10), 5)

# ── String operations ─────────────────────────────────────────────
check("repeat str", repeat("ab", 3), "ababab")
check("str contains", "hello world".find("world") >= 0, true)
check("str repeat *", "xyz" * 3, "xyzxyzxyz")
check("list * n", len([1, 2] * 4), 8)

var words = ["the", "quick", "brown", "fox"]
words.sort()
check("sort words", words[0], "brown")
var rev = list(reversed(words))
check("reversed", rev[0], "the")

# ── Type conversions ──────────────────────────────────────────────
check("int str", int("42"), 42)
check("float str", float("3.14"), 3.14)
check("str int", str(42), "42")
check("str float", str(3.14), "3.14")
check("bool 0", bool(0), false)
check("bool 1", bool(1), true)
check("bool empty str", bool(""), false)
check("bool nonempty", bool("x"), true)
check("bool empty list", bool([]), false)
check("bool nonempty list", bool([1]), true)

# ── enumerate / zip patterns ──────────────────────────────────────
var items = ["a", "b", "c"]
var indexed = enumerate(items)
check("enumerate 0", indexed[0][0], 0)
check("enumerate val", indexed[0][1], "a")
check("enumerate 2", indexed[2][0], 2)

var la = [1, 2, 3]
var lb = ["x", "y", "z"]
var zipped = zip(la, lb)
check("zip 0", zipped[0][0], 1)
check("zip str", zipped[1][1], "y")

# ── Sorting patterns ──────────────────────────────────────────────
var nums = [3, 1, 4, 1, 5, 9, 2, 6]
var s_nums = sorted(nums)
check("sorted", s_nums[0], 1)
check("sorted last", s_nums[7], 9)
check("original unchanged", nums[0], 3)

var r_nums = list(reversed(sorted(nums)))
check("reverse sorted", r_nums[0], 9)

# ── any/all patterns ──────────────────────────────────────────────
var flags_t = [true, true, true]
var flags_f = [true, false, true]

def any_fn(lst2):
    for x in lst2:
        if x:
            return true
    return false

def all_fn(lst2):
    for x in lst2:
        if not x:
            return false
    return true

check("all true", all_fn(flags_t), true)
check("any mixed", any_fn(flags_f), true)
check("all mixed", all_fn(flags_f), false)

print ""
print "Results:", passed, "passed,", failed, "failed"

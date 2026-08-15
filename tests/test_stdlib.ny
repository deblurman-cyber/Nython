# ─────────────────────────────────────────────────────────────────────────────
# test_stdlib.ny — Nython Standard Library Test Suite
# Run from: examples/ directory
# Usage: ../build/nython test_stdlib.ny
# ─────────────────────────────────────────────────────────────────────────────
import "lib/stdlib.ny"

var passed = 0
var failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] expected true, got " + str(val)

def section(name):
    print "  " + name + " ..."

print "=== STDLIB TEST SUITE ==="
print ""

# ─── Stack ───────────────────────────────────────────────────────────────────
section("Stack")
var stk = Stack()
assert_eq("empty size", stk.size, 0)
stk.push(10)
stk.push(20)
stk.push(30)
assert_eq("size after 3 pushes", stk.size, 3)
assert_eq("pop", stk.pop(), 30)
assert_eq("pop again", stk.pop(), 20)
assert_eq("size after 2 pops", stk.size, 1)
assert_eq("peek", stk.peek(), 10)
assert_true("not empty", not stk.is_empty())
stk.pop()
assert_true("empty after clear", stk.is_empty())
assert_eq("pop empty", stk.pop(), none)

# ─── Queue ───────────────────────────────────────────────────────────────────
section("Queue")
var q = Queue()
q.enqueue("alpha")
q.enqueue("beta")
q.enqueue("gamma")
assert_eq("q size", q.size, 3)
assert_eq("dequeue 1", q.dequeue(), "alpha")
assert_eq("dequeue 2", q.dequeue(), "beta")
assert_eq("q peek", q.peek(), "gamma")
assert_eq("q size after", q.size, 1)

# ─── PriorityQueue ───────────────────────────────────────────────────────────
section("PriorityQueue")
var pq = PriorityQueue()
pq.push(5, "low")
pq.push(1, "high")
pq.push(3, "mid")
assert_eq("pq pop highest priority", pq.pop(), "high")
assert_eq("pq pop next", pq.pop(), "mid")
assert_eq("pq size", pq.size, 1)

# ─── HashMap ─────────────────────────────────────────────────────────────────
section("HashMap")
var hm = HashMap()
hm.set("name", "Nython")
hm.set("version", "3.0")
hm.set("year", 2025)
assert_eq("get name", hm.get("name", ""), "Nython")
assert_eq("get version", hm.get("version", ""), "3.0")
assert_true("contains name", hm.contains("name"))
assert_true("not contains xyz", not hm.contains("xyz"))
assert_eq("get missing", hm.get("missing", "default"), "default")
hm.delete("version")
assert_true("deleted", not hm.contains("version"))
assert_eq("size", hm.size(), 2)

# ─── Set ─────────────────────────────────────────────────────────────────────
section("Set")
var s = Set()
s.add("a")
s.add("b")
s.add("c")
s.add("a")
assert_eq("set size (no duplicates)", s.size(), 3)
assert_true("contains a", s.contains("a"))
assert_true("not contains z", not s.contains("z"))
s.remove("b")
assert_eq("size after remove", s.size(), 2)
var s2 = Set()
s2.add("c")
s2.add("d")
var u = s.union(s2)
assert_eq("union size (a,c,d)", u.size(), 3)
var i = s.intersection(s2)
assert_eq("intersection size", i.size(), 1)

# ─── Sort ────────────────────────────────────────────────────────────────────
section("Sort")
var sorter = Sort()
var nums = [5, 2, 8, 1, 9, 3, 7, 4, 6]
var sorted_asc = sorter.merge_sort(nums, 9, false)
assert_eq("first after sort", sorted_asc[0], 1)
assert_eq("last after sort", sorted_asc[8], 9)
var sorted_desc = sorter.merge_sort(nums, 9, true)
assert_eq("first desc", sorted_desc[0], 9)
assert_eq("idx binary search", sorter.binary_search(sorted_asc, 9, 5), 4)
assert_eq("binary search missing", sorter.binary_search(sorted_asc, 9, 10), -1)

# ─── MathUtils ───────────────────────────────────────────────────────────────
section("MathUtils")
var math = MathUtils()
assert_eq("gcd 48,18", math.gcd(48, 18), 6)
assert_eq("lcm 4,6", math.lcm(4, 6), 12)
assert_true("prime 97", math.is_prime(97))
assert_true("not prime 100", not math.is_prime(100))
assert_eq("factorial 5", math.factorial(5), 120)
assert_eq("fibonacci 10", math.fibonacci(10), 55)
assert_eq("mean", str(int(math.mean([1.0, 2.0, 3.0, 4.0, 5.0], 5))), "3")
assert_eq("clamp", math.clamp(15, 0, 10), 10)
assert_eq("clamp low", math.clamp(-5, 0, 10), 0)
assert_eq("clamp mid", math.clamp(5, 0, 10), 5)
assert_eq("abs", math.absolute(-7), 7)
assert_eq("min", math.minimum(3, 7), 3)
assert_eq("max", math.maximum(3, 7), 7)

# ─── StringUtils ─────────────────────────────────────────────────────────────
section("StringUtils")
var su = StringUtils()
assert_eq("repeat", su.repeat("ab", 3), "ababab")
assert_eq("pad_left", su.pad_left("7", 4, "0"), "0007")
assert_eq("pad_right", su.pad_right("hi", 5, "."), "hi...")
assert_eq("truncate", su.truncate("Hello World", 5, "..."), "Hello...")
assert_eq("word_count", su.word_count("Hello beautiful world"), 3)
assert_eq("reverse", su.reverse("Nython"), "nohtyN")

# ─── Random ──────────────────────────────────────────────────────────────────
section("Random")
var rng = Random()
rng.seed(42)
var r1 = rng.randint(1, 10)
assert_true("randint in range", r1 >= 1 and r1 <= 10)
var rf = rng.randfloat(0.0, 1.0)
assert_true("randfloat in [0,1]", rf >= 0.0 and rf <= 1.0)
rng.seed(42)
var r2 = rng.randint(1, 10)
assert_eq("seed reproducibility", r1, r2)
var arr = [1, 2, 3, 4, 5]
var choice = rng.choice(arr)
assert_true("choice in arr", choice >= 1 and choice <= 5)

# ─── Config ──────────────────────────────────────────────────────────────────
section("Config")
var cfg = Config()
cfg.set("host", "localhost")
cfg.set("port", "8080")
cfg.set("debug", "true")
cfg.set("ratio", "3.14")
assert_eq("get string", cfg.get("host", ""), "localhost")
assert_eq("get int", cfg.get_int("port", 0), 8080)
assert_true("get bool", cfg.get_bool("debug", false))
assert_eq("get missing default", cfg.get("missing", "fallback"), "fallback")
assert_eq("all keys count", len(cfg.all_keys()), 4)
cfg.delete("debug")
assert_eq("after delete", len(cfg.all_keys()), 3)

# ─── Logger ──────────────────────────────────────────────────────────────────
section("Logger")
var log = Logger("test_logger")
log.set_level(log.DEBUG)
log.debug("debug message")
log.info("info message")
log.warn("warn message")
log.error("error message")
assert_true("log count", log.count >= 4)
var last = log.last_message()
assert_true("last has ERROR", string_contains(last, "ERROR"))

# ─── Timer ───────────────────────────────────────────────────────────────────
section("Timer")
var tmr = Timer()
tmr.start()
tmr.stop()
assert_true("elapsed >= 0", tmr.ms() >= 0.0)
assert_true("elapsed_s >= 0", tmr.ms() >= 0.0)
tmr.reset()
assert_true("after reset", tmr.ms() == 0.0)
var sw = Stopwatch()
sw.start()
sw.lap()
sw.lap()
sw.stop()
assert_eq("lap count", sw.laps_count(), 2)

# ─── EventBus ────────────────────────────────────────────────────────────────
section("EventBus")
var bus = EventBus()
var received = []

def on_msg(d):
    received = received + [d]

bus.on("msg", on_msg)
bus.emit("msg", "hello")
bus.emit("msg", "world")
assert_eq("events received", len(received), 2)
assert_eq("first event", received[0], "hello")
bus.off("msg", on_msg)
bus.emit("msg", "ignored")
assert_eq("after off", len(received), 2)

# ─── JSON ────────────────────────────────────────────────────────────────────
section("JSON")
var json = JSON()
var obj = {"name": "Nython", "version": 3, "active": true}
var encoded = json.encode(obj)
assert_true("json not empty", len(encoded) > 2)
var decoded = json.decode(encoded)
assert_eq("json roundtrip name", decoded["name"], "Nython")
assert_eq("json roundtrip version", decoded["version"], 3)
var arr_enc = json.encode([1, 2, 3])
assert_true("json array", string_contains(arr_enc, "1"))

# ─── Result / Option ─────────────────────────────────────────────────────────
section("Result/Option")
var ok = Result(true, 42, "")
var err = Result(false, none, "not found")
assert_true("ok.is_ok", ok.is_ok())
assert_true("err.is_err", err.is_err())
assert_eq("ok.value", ok.unwrap(), 42)
assert_eq("err.unwrap_or", err.unwrap_or(0), 0)
var some = Option(42)
var none_opt = Option(none)
assert_true("some.is_some", some.is_some())
assert_true("none.is_none", none_opt.is_none())
assert_eq("some.get", some.get(), 42)

# ─── ReactiveValue ───────────────────────────────────────────────────────────
section("ReactiveValue")
var changed_count = 0

def on_change(v):
    changed_count = changed_count + 1

var rv = ReactiveValue(0)
rv.subscribe(on_change)
rv.set(1)
rv.set(2)
rv.set(2)
assert_eq("reactive value", rv.get(), 2)
assert_eq("changed twice (skip dup)", changed_count, 2)

# ─── Version ─────────────────────────────────────────────────────────────────
section("Version")
var v1 = Version("1.2.3")
var v2 = Version("2.0.0")
var v3 = Version("1.2.3")
assert_true("v2 > v1", v2.gt(v1))
assert_true("v1 < v2", v1.lt(v2))
assert_true("v1 == v3", v1.eq(v3))
assert_eq("v1.major", v1.major, 1)
assert_eq("v1.minor", v1.minor, 2)
assert_eq("v1.patch", v1.patch, 3)
assert_eq("v1.to_str", v1.to_str(), "1.2.3")
assert_true("compatible", v1.is_compatible(v3))

# ─── Results ─────────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL STDLIB TESTS PASSED ==="
else:
    print "=== SOME STDLIB TESTS FAILED ==="

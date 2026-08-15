# ─────────────────────────────────────────────────────────────────────────────
# test_thread.ny — Nython Threading Library Test Suite
# Run from: examples/ directory
# ─────────────────────────────────────────────────────────────────────────────
import "lib/thread.ny"

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

print "=== THREAD TEST SUITE ==="
print ""

# ─── Mutex ───────────────────────────────────────────────────────────────────
section("Mutex")
var mx = Mutex()
mx.lock()
mx.unlock()
passed = passed + 1
print "  Mutex lock/unlock OK"

# ─── Semaphore ────────────────────────────────────────────────────────────────
section("Semaphore")
var sem = Semaphore(5)
assert_eq("initial available", sem.available(), 5)
sem.acquire()
assert_eq("after acquire", sem.available(), 4)
sem.acquire()
assert_eq("after 2nd acquire", sem.available(), 3)
sem.release()
assert_eq("after release", sem.available(), 4)

# ─── BinarySemaphore ─────────────────────────────────────────────────────────
section("BinarySemaphore")
var bs = BinarySemaphore()
bs.wait()
bs.signal()
passed = passed + 1
print "  BinarySemaphore wait/signal OK"

# ─── AtomicInt ───────────────────────────────────────────────────────────────
section("AtomicInt")
var ai = AtomicInt(0)
assert_eq("initial", ai.get(), 0)
ai.inc()
ai.inc()
ai.inc()
assert_eq("after 3 inc", ai.get(), 3)
ai.dec()
assert_eq("after dec", ai.get(), 2)
ai.set(100)
assert_eq("after set", ai.get(), 100)
ai.add(50)
assert_eq("after add", ai.get(), 150)
assert_true("cas success", ai.compare_and_swap(150, 200))
assert_eq("after cas", ai.get(), 200)
assert_true("cas fail", not ai.compare_and_swap(150, 999))
assert_eq("unchanged after fail cas", ai.get(), 200)

# ─── AtomicBool ──────────────────────────────────────────────────────────────
section("AtomicBool")
var ab = AtomicBool(false)
assert_true("initial false", not ab.get())
ab.set(true)
assert_true("after set true", ab.get())
ab.flip()
assert_true("after flip", not ab.get())
ab.flip()
assert_true("after flip again", ab.get())

# ─── Channel ─────────────────────────────────────────────────────────────────
section("Channel")
var ch = Channel(4)
assert_true("empty initially", ch.is_empty())
assert_eq("initial size", ch.size(), 0)
ch.send("msg1")
ch.send("msg2")
ch.send("msg3")
assert_eq("size after 3 sends", ch.size(), 3)
assert_true("not empty", not ch.is_empty())
var r1 = ch.recv()
assert_eq("recv 1", r1, "msg1")
var r2 = ch.recv()
assert_eq("recv 2", r2, "msg2")
assert_eq("size after 2 recvs", ch.size(), 1)

# ─── UnboundedChannel ────────────────────────────────────────────────────────
section("UnboundedChannel")
var uch = UnboundedChannel()
uch.send(10)
uch.send(20)
uch.send(30)
assert_eq("ubch size", uch.size(), 3)
assert_eq("ubch recv", uch.recv(), 10)
assert_eq("ubch recv 2", uch.recv(), 20)

# ─── ConcurrentMap ───────────────────────────────────────────────────────────
section("ConcurrentMap")
var cmap = ConcurrentMap()
cmap.set("x", 1)
cmap.set("y", 2)
cmap.set("z", 3)
assert_eq("get x", cmap.get("x"), 1)
assert_eq("get y", cmap.get("y"), 2)
assert_true("contains z", cmap.contains("z"))
assert_true("not contains w", not cmap.contains("w"))
cmap.delete("y")
assert_true("deleted y", not cmap.contains("y"))
var k = cmap.get_keys()
assert_eq("keys count after del", len(k), 2)

# ─── CountDownLatch ──────────────────────────────────────────────────────────
section("CountDownLatch")
var latch = CountDownLatch(3)
assert_eq("initial count", latch.get_count(), 3)
latch.count_down()
assert_eq("after 1 down", latch.get_count(), 2)
latch.count_down()
latch.count_down()
assert_eq("after all down", latch.get_count(), 0)

# ─── Scheduler ───────────────────────────────────────────────────────────────
section("Scheduler")
var tick_count = 0

def on_tick():
    tick_count = tick_count + 1

var sched = Scheduler()
var task = sched.every(1, on_tick)
sched.tick()
sched.tick()
sched.tick()
assert_true("scheduler type", type(sched) == "Scheduler")
passed = passed + 1
print "  Scheduler OK"

# ─── Results ─────────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL THREAD TESTS PASSED ==="
else:
    print "=== SOME THREAD TESTS FAILED ==="

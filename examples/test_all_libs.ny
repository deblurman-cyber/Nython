import "lib/stdlib.ny"
import "lib/os.ny"
import "lib/thread.ny"
import "lib/aiagent.ny"

print "=== STDLIB ==="
var stk = Stack()
stk.push("a")
stk.push("b")
stk.push("c")
print "Stack pop: " + str(stk.pop())
var q = Queue()
q.enqueue("first")
q.enqueue("second")
print "Queue: " + str(q.dequeue())
var m = MathUtils()
print "Fib(10)=" + str(m.fibonacci(10))
print "GCD(12,8)=" + str(m.gcd(12, 8))
print "IsPrime(97)=" + str(m.is_prime(97))
var rng = Random()
rng.seed(42)
print "Rand=" + str(rng.randint(1, 100))
var su = StringUtils()
print "PadLeft=" + su.pad_left("9", 5, "0")
var tmr = Timer()
tmr.start()
tmr.stop()
print "Timer=" + str(tmr.ms() >= 0.0)

def on_event(d):
    print "EventBus: " + str(d)

var ev = EventBus()
ev.on("test", on_event)
ev.emit("test", "hello_world")
print "STDLIB PASSED"

print ""
print "=== OS ==="
var p = Path()
print "basename=" + p.basename("/home/user/file.ny")
print "ext=" + p.extension("model.pt")
var env = Env()
print "cwd=" + str(env.cwd())[0:25]
var fs = FileSystem()
fs.write("/tmp/ny_test.txt", "test content 123")
print "read=" + str(fs.read("/tmp/ny_test.txt"))
print "OS PASSED"

print ""
print "=== THREAD ==="
var mx = Mutex()
mx.lock()
mx.unlock()
print "Mutex OK"
var sem = Semaphore(5)
sem.acquire()
sem.acquire()
print "Sem avail=" + str(sem.available())
sem.release()
var ai_cnt = AtomicInt(10)
ai_cnt.inc()
ai_cnt.inc()
print "AtomicInt=" + str(ai_cnt.get())
var ch = Channel(3)
ch.send("msg1")
ch.send("msg2")
print "Channel size=" + str(ch.size())
print "Recv=" + str(ch.recv())
var cmap = ConcurrentMap()
cmap.set("k1", "v1")
cmap.set("k2", "v2")
print "CMap get=" + str(cmap.get("k1"))
print "THREAD PASSED"

print ""
print "=== AIAGENT ==="
var nyx = NyxAI("Nyx", "/tmp/nyx_final")
print nyx.greeting()
nyx.remember("test_key", "test_value_xyz")
print "recall=" + nyx.recall("test_key")
var ans = nyx.ask("how to define a class")
print "ask=" + ans[0:55]
var analysis = nyx.analyze("class MyFoo:\n    def __init__(self):\n        pass\n")
print "classes=" + str(analysis["stats"]["classes"])
var gen = nyx.generate("create crud Product repository")
print "gen_lines=" + str(len(string_split(gen, "\n")))
nyx.save()
print "AIAGENT PASSED"

print ""
print "=== ALL LIBS PASSED ==="

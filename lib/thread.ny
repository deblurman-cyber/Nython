# ═══════════════════════════════════════════════════════════════════════════════
# thread.ny — Nython Synchronization Library
# Mutex, Semaphore, RWLock, AtomicInt, Channel, ConcurrentMap, Scheduler
# Usage: import "lib/thread.ny"
# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import threading

# ─── Mutex ───────────────────────────────────────────────────────────────────

class Mutex:
    def __init__(self):
        self.id = mutex_create()

    def lock(self):
        mutex_lock(self.id)

    def unlock(self):
        mutex_unlock(self.id)

    def __enter__(self):
        self.lock()
        return self

    def __exit__(self):
        self.unlock()

# ─── Semaphore ────────────────────────────────────────────────────────────────

class Semaphore:
    def __init__(self, count):
        self.id = semaphore_create(count)
        self.max_count = count
        self.current = count

    def acquire(self):
        semaphore_acquire(self.id)
        self.current = self.current - 1

    def release(self):
        semaphore_release(self.id)
        self.current = self.current + 1

    def available(self):
        return self.current

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self):
        self.release()

class BinarySemaphore:
    def __init__(self):
        self.id = semaphore_create(1)

    def wait(self):
        semaphore_acquire(self.id)

    def signal(self):
        semaphore_release(self.id)

    def __enter__(self):
        self.wait()
        return self

    def __exit__(self):
        self.signal()

# ─── AtomicInt ────────────────────────────────────────────────────────────────

class AtomicInt:
    def __init__(self, initial):
        self._value = initial
        self._mid = mutex_create()

    def get(self):
        return self._value

    def set(self, val):
        mutex_lock(self._mid)
        self._value = val
        mutex_unlock(self._mid)

    def inc(self):
        mutex_lock(self._mid)
        self._value = self._value + 1
        var v = self._value
        mutex_unlock(self._mid)
        return v

    def dec(self):
        mutex_lock(self._mid)
        self._value = self._value - 1
        var v = self._value
        mutex_unlock(self._mid)
        return v

    def add(self, n):
        mutex_lock(self._mid)
        self._value = self._value + n
        var v = self._value
        mutex_unlock(self._mid)
        return v

    def compare_and_swap(self, expected, new_val):
        mutex_lock(self._mid)
        var ok = false
        if self._value == expected:
            self._value = new_val
            var ok = true
        mutex_unlock(self._mid)
        return ok

class AtomicBool:
    def __init__(self, initial):
        self._value = initial
        self._mid = mutex_create()

    def get(self):
        return self._value

    def set(self, val):
        mutex_lock(self._mid)
        self._value = val
        mutex_unlock(self._mid)

    def flip(self):
        mutex_lock(self._mid)
        if self._value:
            self._value = false
        else:
            self._value = true
        var v = self._value
        mutex_unlock(self._mid)
        return v

# ─── Channel (bounded) ────────────────────────────────────────────────────────

class Channel:
    def __init__(self, capacity):
        self.capacity = capacity
        self.buffer = []
        self.count = 0
        self.head = 0
        self.tail = 0
        self._mid = mutex_create()
        self._not_full_id = semaphore_create(capacity)
        self._not_empty_id = semaphore_create(0)
        self.closed = false

    def send(self, val):
        if self.closed:
            return false
        semaphore_acquire(self._not_full_id)
        mutex_lock(self._mid)
        var idx = self.tail % self.capacity
        self.buffer[idx] = val
        self.tail = self.tail + 1
        self.count = self.count + 1
        mutex_unlock(self._mid)
        semaphore_release(self._not_empty_id)
        return true

    def recv(self):
        if self.closed and self.count == 0:
            return none
        semaphore_acquire(self._not_empty_id)
        mutex_lock(self._mid)
        var idx = self.head % self.capacity
        var val = self.buffer[idx]
        self.head = self.head + 1
        self.count = self.count - 1
        mutex_unlock(self._mid)
        semaphore_release(self._not_full_id)
        return val

    def try_recv(self):
        if self.count == 0:
            return none
        return self.recv()

    def close(self):
        self.closed = true
        semaphore_release(self._not_empty_id)

    def size(self):
        return self.count

    def is_full(self):
        return self.count >= self.capacity

    def is_empty(self):
        return self.count == 0

# ─── UnboundedChannel ────────────────────────────────────────────────────────

class UnboundedChannel:
    def __init__(self):
        self.items = []
        self.count = 0
        self._mid = mutex_create()
        self._sem_id = semaphore_create(0)
        self.closed = false

    def send(self, val):
        if self.closed:
            return false
        mutex_lock(self._mid)
        self.items[self.count] = val
        self.count = self.count + 1
        mutex_unlock(self._mid)
        semaphore_release(self._sem_id)
        return true

    def recv(self):
        semaphore_acquire(self._sem_id)
        mutex_lock(self._mid)
        var val = none
        if self.count > 0:
            var val = self.items[0]
            var new_items = []
            var i = 1
            while i < self.count:
                new_items[i - 1] = self.items[i]
                i = i + 1
            self.items = new_items
            self.count = self.count - 1
        mutex_unlock(self._mid)
        return val

    def close(self):
        self.closed = true
        semaphore_release(self._sem_id)

    def size(self):
        return self.count

# ─── Thread ───────────────────────────────────────────────────────────────────

class Thread:
    def __init__(self, fn):
        self.fn = fn
        self.id = -1
        self.running = false

    def start(self, arg):
        self.running = true
        self.id = thread_create(self.fn)
        return self

    def sleep(self, ms):
        thread_sleep(ms)

    def is_running(self):
        return self.running

# ─── ThreadPool ──────────────────────────────────────────────────────────────

class ThreadPool:
    def __init__(self, num_workers):
        self.num_workers = num_workers
        self.queue_mid = mutex_create()
        self.queue_sem = semaphore_create(0)
        self.tasks = []
        self.task_count = 0
        self.results = []
        self.result_count = 0
        self.running = false

    def submit(self, fn):
        mutex_lock(self.queue_mid)
        self.tasks[self.task_count] = fn
        self.task_count = self.task_count + 1
        mutex_unlock(self.queue_mid)
        semaphore_release(self.queue_sem)

    def get_result(self):
        var i = 0
        while i < 1000:
            if self.result_count > 0:
                mutex_lock(self.queue_mid)
                var r = self.results[0]
                var new_res = []
                var j = 1
                while j < self.result_count:
                    new_res[j - 1] = self.results[j]
                    j = j + 1
                self.results = new_res
                self.result_count = self.result_count - 1
                mutex_unlock(self.queue_mid)
                return r
            thread_sleep(10)
            i = i + 1
        return none

    def stop(self):
        self.running = false

# ─── Barrier ─────────────────────────────────────────────────────────────────

class Barrier:
    def __init__(self, n):
        self.n = n
        self._count = 0
        self._mid = mutex_create()
        self._sem_id = semaphore_create(0)

    def wait(self):
        mutex_lock(self._mid)
        self._count = self._count + 1
        var c = self._count
        mutex_unlock(self._mid)
        if c == self.n:
            mutex_lock(self._mid)
            self._count = 0
            mutex_unlock(self._mid)
            var i = 0
            while i < self.n:
                semaphore_release(self._sem_id)
                i = i + 1
        semaphore_acquire(self._sem_id)

# ─── Scheduler ────────────────────────────────────────────────────────────────

class ScheduledTask:
    def __init__(self, interval_ms, fn):
        self.interval_ms = interval_ms
        self.fn = fn
        self.running = false
        self.count = 0

    def tick(self):
        if self.running:
            self.fn()
            self.count = self.count + 1

    def start(self):
        self.running = true

    def stop(self):
        self.running = false

class Scheduler:
    def __init__(self):
        self.tasks = []
        self.task_count = 0
        self.running = false
        self.last_tick = []

    def every(self, interval_ms, fn):
        var task = ScheduledTask(interval_ms, fn)
        task.start()
        self.tasks[self.task_count] = task
        self.last_tick[self.task_count] = 0.0
        self.task_count = self.task_count + 1
        return task

    def tick(self):
        var now = time_now() * 1000.0
        var i = 0
        while i < self.task_count:
            var t = self.tasks[i]
            if t.running:
                var elapsed = now - self.last_tick[i]
                if elapsed >= t.interval_ms:
                    t.tick()
                    self.last_tick[i] = now
            i = i + 1

    def run(self, duration_ms):
        self.running = true
        var start = time_now() * 1000.0
        while self.running:
            self.tick()
            thread_sleep(1)
            var elapsed = time_now() * 1000.0 - start
            if duration_ms > 0 and elapsed >= duration_ms:
                break
        self.running = false

    def stop(self):
        self.running = false

# ─── ConcurrentMap ────────────────────────────────────────────────────────────

class ConcurrentMap:
    def __init__(self):
        self._data = {}
        self._keylist = []
        self._mid = mutex_create()

    def set(self, key, value):
        mutex_lock(self._mid)
        if not self.contains(key):
            self._keylist.append(key)
        self._data[key] = value
        mutex_unlock(self._mid)

    def get(self, key):
        mutex_lock(self._mid)
        var val = self._data[key]
        mutex_unlock(self._mid)
        return val

    def delete(self, key):
        mutex_lock(self._mid)
        self._data[key] = none
        var new_keys = []
        var i = 0
        while i < len(self._keylist):
            if self._keylist[i] != key:
                new_keys.append(self._keylist[i])
            i = i + 1
        self._keylist = new_keys
        mutex_unlock(self._mid)

    def contains(self, key):
        var i = 0
        while i < len(self._keylist):
            if self._keylist[i] == key:
                return true
            i = i + 1
        return false

    def get_keys(self):
        mutex_lock(self._mid)
        var k = self._keylist
        mutex_unlock(self._mid)
        return k

# ─── Latch ────────────────────────────────────────────────────────────────────

class CountDownLatch:
    def __init__(self, count):
        self._count = count
        self._mid = mutex_create()
        self._sem_id = semaphore_create(0)

    def count_down(self):
        mutex_lock(self._mid)
        if self._count > 0:
            self._count = self._count - 1
            if self._count == 0:
                semaphore_release(self._sem_id)
        mutex_unlock(self._mid)

    def await(self):
        semaphore_acquire(self._sem_id)
        semaphore_release(self._sem_id)

    def get_count(self):
        return self._count

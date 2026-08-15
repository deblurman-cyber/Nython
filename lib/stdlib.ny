# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import os
import time
import json

# stdlib.ny — Nython Standard Library
# Collections, algorithms, math, string utils, date/time, error handling,
# serialisation, logging, config, events, functional helpers, and more.
# Usage: import "lib/stdlib.ny"
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Collections ────────────────────────────────────────────────────────────

class Stack:
    def __init__(self):
        self.data = []
        self.size = 0
    def push(self, val):
        self.data[self.size] = val
        self.size = self.size + 1
    def pop(self):
        if self.size == 0:
            return none
        self.size = self.size - 1
        return self.data[self.size]
    def peek(self):
        if self.size == 0:
            return none
        return self.data[self.size - 1]
    def is_empty(self):
        return self.size == 0
    def clear(self):
        self.data = []
        self.size = 0
    def to_list(self):
        var result = []
        var i = 0
        while i < self.size:
            result.append(self.data[i])
            i = i + 1
        return result

class Queue:
    def __init__(self):
        self.items = []
        self.size = 0
    def enqueue(self, val):
        self.items.append(val)
        self.size = self.size + 1
    def dequeue(self):
        if self.size == 0:
            return none
        var val = self.items[0]
        var new_items = []
        var i = 1
        while i < self.size:
            new_items.append(self.items[i])
            i = i + 1
        self.items = new_items
        self.size = self.size - 1
        return val
    def peek(self):
        if self.size == 0:
            return none
        return self.items[0]
    def front(self):
        return self.peek()
    def is_empty(self):
        return self.size == 0
    def length(self):
        return self.size

class PriorityQueue:
    def __init__(self):
        self.items = []
        self.priorities = []
        self.size = 0
    def push(self, priority, value):
        var pos = 0
        var i = 0
        while i < self.size:
            if self.priorities[i] > priority:
                var pos = i
                var i = self.size
            else:
                pos = i + 1
            i = i + 1
        var new_items = []
        var new_pris = []
        var j = 0
        while j < pos:
            new_items.append(self.items[j])
            new_pris.append(self.priorities[j])
            j = j + 1
        new_items.append(value)
        new_pris.append(priority)
        j = pos
        while j < self.size:
            new_items.append(self.items[j])
            new_pris.append(self.priorities[j])
            j = j + 1
        self.items = new_items
        self.priorities = new_pris
        self.size = self.size + 1
    def pop(self):
        if self.size == 0:
            return none
        var val = self.items[0]
        var new_items = []
        var new_pris = []
        var i = 1
        while i < self.size:
            new_items.append(self.items[i])
            new_pris.append(self.priorities[i])
            i = i + 1
        self.items = new_items
        self.priorities = new_pris
        self.size = self.size - 1
        return val
    def peek(self):
        if self.size == 0:
            return none
        return self.items[0]
    def is_empty(self):
        return self.size == 0


class LinkedList:
    def __init__(self):
        self.data = []
        self.size = 0
    def append(self, val):
        self.data[self.size] = val
        self.size = self.size + 1
    def prepend(self, val):
        var new_data = []
        new_data[0] = val
        var i = 0
        while i < self.size:
            new_data[i + 1] = self.data[i]
            i = i + 1
        self.data = new_data
        self.size = self.size + 1
    def remove_at(self, idx):
        if idx < 0 or idx >= self.size:
            return false
        var new_data = []
        var i = 0
        var j = 0
        while i < self.size:
            if i != idx:
                new_data.append(self.data[i])
            i = i + 1
        self.data = new_data
        self.size = self.size - 1
        return true
    def get(self, idx):
        if idx < 0 or idx >= self.size:
            return none
        return self.data[idx]
    def to_list(self):
        var result = []
        var i = 0
        while i < self.size:
            result.append(self.data[i])
            i = i + 1
        return result

class HashMap:
    def __init__(self):
        self.store = {}
        self._keys = []
    def set(self, key, value):
        if not self.contains(key):
            self._keys.append(key)
        self.store[key] = value
    def get(self, key, default):
        var v = self.store[key]
        if v == none:
            return default
        return v
    def contains(self, key):
        var i = 0
        while i < len(self._keys):
            if self._keys[i] == key:
                return true
            i = i + 1
        return false
    def delete(self, key):
        self.store[key] = none
        var new_keys = []
        var i = 0
        while i < len(self._keys):
            if self._keys[i] != key:
                new_keys.append(self._keys[i])
            i = i + 1
        self._keys = new_keys
    def remove(self, key):
        self.delete(key)
    def size(self):
        return len(self._keys)
    def get_keys(self):
        return self._keys
    def get_values(self):
        var result = []
        var i = 0
        while i < len(self._keys):
            var v = self.store[self._keys[i]]
            if v != none:
                result.append(v)
            i = i + 1
        return result

class OrderedDict:
    def __init__(self):
        self.data = {}
        self.key_order = []
        self.count = 0
    def set(self, key, value):
        if self.data[key] == none:
            self.key_order[self.count] = key
            self.count = self.count + 1
        self.data[key] = value
    def get(self, key):
        return self.data[key]
    def keys_ordered(self):
        return self.key_order
    def items(self):
        var result = []
        var i = 0
        while i < self.count:
            var pair = []
            pair[0] = self.key_order[i]
            pair[1] = self.data[self.key_order[i]]
            result.append(pair)
        return result

class Set:
    def __init__(self):
        self.store = {}
        self.count = 0

    def add(self, val):
        var key = str(val)
        if not self.contains(val):
            self.store[key] = val
            self.count = self.count + 1

    def contains(self, val):
        var key = str(val)
        var v = self.store[key]
        return v != none

    def remove(self, val):
        var key = str(val)
        if self.contains(val):
            self.store[key] = none
            self.count = self.count - 1

    def size(self):
        return self.count

    def is_empty(self):
        return self.count == 0

    def clear(self):
        self.store = {}
        self.count = 0

    def to_list(self):
        var result = []
        var all_keys = keys(self.store)
        var i = 0
        while i < len(all_keys):
            var v = self.store[all_keys[i]]
            if v != none:
                result.append(v)
            i = i + 1
        return result

    def union(self, other):
        var result = Set()
        var mylist = self.to_list()
        var i = 0
        while i < len(mylist):
            result.add(mylist[i])
            i = i + 1
        var otherlist = other.to_list()
        i = 0
        while i < len(otherlist):
            result.add(otherlist[i])
            i = i + 1
        return result

    def intersection(self, other):
        var result = Set()
        var mylist = self.to_list()
        var i = 0
        while i < len(mylist):
            if other.contains(mylist[i]):
                result.add(mylist[i])
            i = i + 1
        return result

    def difference(self, other):
        var result = Set()
        var mylist = self.to_list()
        var i = 0
        while i < len(mylist):
            if not other.contains(mylist[i]):
                result.add(mylist[i])
            i = i + 1
        return result

    def is_subset(self, other):
        var mylist = self.to_list()
        var i = 0
        while i < len(mylist):
            if not other.contains(mylist[i]):
                return false
            i = i + 1
        return true

# ─── Algorithms ─────────────────────────────────────────────────────────────

class Sort:
    def bubble_sort(self, arr, n):
        var result = arr
        var i = 0
        while i < n:
            var j = 0
            while j < n - i - 1:
                if result[j] > result[j + 1]:
                    var tmp = result[j]
                    result[j] = result[j + 1]
                    result[j + 1] = tmp
                j = j + 1
            i = i + 1
        return result

    def merge_sort(self, arr, n, descending):
        if n <= 1:
            return arr
        var result = self.bubble_sort(arr, n)
        if descending:
            var rev = []
            var i = n - 1
            while i >= 0:
                rev.append(result[i])
                i = i - 1
            return rev
        return result

    def sort_asc(self, arr, n):
        return self.merge_sort(arr, n, false)

    def sort_desc(self, arr, n):
        return self.merge_sort(arr, n, true)

    def binary_search(self, arr, n, target):
        var lo = 0
        var hi = n - 1
        while lo <= hi:
            var mid = int((lo + hi) / 2)
            if arr[mid] == target:
                return mid
            if arr[mid] < target:
                var lo = mid + 1
            else:
                var hi = mid - 1
        return -1

    def min_in(self, arr, n):
        var m = arr[0]
        var i = 1
        while i < n:
            if arr[i] < m:
                var m = arr[i]
            i = i + 1
        return m

    def max_in(self, arr, n):
        var m = arr[0]
        var i = 1
        while i < n:
            if arr[i] > m:
                var m = arr[i]
            i = i + 1
        return m

class MathUtils:
    def gcd(self, a, b):
        while b != 0:
            var tmp = b
            var b = a % b
            var a = tmp
        return a
    def lcm(self, a, b):
        return (a * b) // self.gcd(a, b)
    def is_prime(self, n):
        if n < 2:
            return false
        if n == 2:
            return true
        if n % 2 == 0:
            return false
        var i = 3
        while i * i <= n:
            if n % i == 0:
                return false
            i = i + 2
        return true
    def primes_up_to(self, n):
        var result = []
        var count = 0
        var i = 2
        while i <= n:
            if self.is_prime(i):
                result.append(i)
            i = i + 1
        return result
    def factorial(self, n):
        if n <= 1:
            return 1
        var result = 1
        var i = 2
        while i <= n:
            result = result * i
            i = i + 1
        return result
    def fibonacci(self, n):
        if n <= 1:
            return n
        var a = 0
        var b = 1
        var i = 2
        while i <= n:
            var c = a + b
            a = b
            b = c
            i = i + 1
        return b
    def power(self, base, exp):
        var result = 1
        var i = 0
        while i < exp:
            result = result * base
            i = i + 1
        return result
    def clamp(self, val, lo, hi):
        if val < lo:
            return lo
        if val > hi:
            return hi
        return val
    def lerp(self, a, b, t):
        return a + (b - a) * t
    def map_range(self, val, in_lo, in_hi, out_lo, out_hi):
        var t = (val - in_lo) / (in_hi - in_lo)
        return out_lo + t * (out_hi - out_lo)
    def mean(self, arr, n):
        var total = 0.0
        var i = 0
        while i < n:
            total = total + arr[i]
            i = i + 1
        return total / n
    def variance(self, arr, n):
        var m = self.mean(arr, n)
        var total = 0.0
        var i = 0
        while i < n:
            var diff = arr[i] - m
            total = total + diff * diff
            i = i + 1
        return total / n
    def std_dev(self, arr, n):
        return sqrt(self.variance(arr, n))
    def dot_product(self, a, b, n):
        var result = 0.0
        var i = 0
        while i < n:
            result = result + a[i] * b[i]
            i = i + 1
        return result

    def absolute(self, x):
        if x < 0:
            return -x
        return x

    def minimum(self, a, b):
        if a < b:
            return a
        return b

    def maximum(self, a, b):
        if a > b:
            return a
        return b

    def sign(self, x):
        if x < 0:
            return -1
        if x > 0:
            return 1
        return 0

# ─── String Utilities ────────────────────────────────────────────────────────

class StringUtils:
    def repeat(self, s, n):
        var result = ""
        var i = 0
        while i < n:
            result = result + s
            i = i + 1
        return result
    def pad_left(self, s, width, char):
        var slen = len(s)
        while slen < width:
            var s = char + s
            slen = slen + 1
        return s
    def pad_right(self, s, width, char):
        var slen = len(s)
        while slen < width:
            s = s + char
            slen = slen + 1
        return s
    def center(self, s, width, char):
        var slen = len(s)
        var total_pad = width - slen
        var left_pad = total_pad / 2
        var right_pad = total_pad - left_pad
        return self.repeat(char, left_pad) + s + self.repeat(char, right_pad)
    def is_numeric(self, s):
        if len(s) == 0:
            return false
        return isdigit_str(s)
    def is_alpha(self, s):
        if len(s) == 0:
            return false
        return isalpha_str(s)
    def title_case(self, s):
        var words = string_split(s, " ")
        var result = []
        var i = 0
        while i < len(words):
            var w = words[i]
            if len(w) > 0:
                result.append(string_upper(w[0]) + string_lower(w[1:]))
            else:
                result.append(w)
            i = i + 1
        return string_join(result, " ")

    def word_count(self, s):
        return self.count_words(s)

    def reverse(self, s):
        var result = ""
        var i = len(s) - 1
        while i >= 0:
            result = result + s[i]
            i = i - 1
        return result
    def truncate(self, s, max_len, suffix):
        if len(s) <= max_len:
            return s
        return s[0:max_len] + suffix
    def count_words(self, s):
        var words = string_split(string_strip(s), " ")
        var count = 0
        var i = 0
        while i < len(words):
            if len(string_strip(words[i])) > 0:
                count = count + 1
            i = i + 1
        return count

# ─── Date / Time ─────────────────────────────────────────────────────────────

class Timer:
    def __init__(self):
        self.start_time = 0.0
        self.elapsed = 0.0
        self.running = false
    def start(self):
        self.start_time = time_now()
        self.running = true
    def stop(self):
        if self.running:
            self.elapsed = self.elapsed + time_now() - self.start_time
            self.running = false
    def reset(self):
        self.elapsed = 0.0
        self.running = false
    def seconds(self):
        if self.running:
            return self.elapsed + time_now() - self.start_time
        return self.elapsed
    def ms(self):
        return self.seconds() * 1000.0

class Stopwatch:
    def __init__(self):
        self.laps = []
        self.lap_count = 0
        self.t = Timer()
    def start(self):
        self.t.start()
    def lap(self):
        var ms = self.t.ms()
        self.laps.append(ms)
        self.lap_count = self.lap_count + 1
        return ms

    def get_laps(self):
        return self.laps

    def laps_count(self):
        return self.lap_count
    def stop(self):
        self.t.stop()
        return self.t.ms()
    def summary(self):
        if self.lap_count == 0:
            return "No laps recorded"
        var total = 0.0
        var best = self.laps[0]
        var worst = self.laps[0]
        var i = 0
        while i < self.lap_count:
            total = total + self.laps[i]
            if self.laps[i] < best:
                best = self.laps[i]
            if self.laps[i] > worst:
                worst = self.laps[i]
            i = i + 1
        var avg = total / self.lap_count
        return "Laps: " + str(self.lap_count) + " | Avg: " + str(avg) + "ms | Best: " + str(best) + "ms | Worst: " + str(worst) + "ms"

# ─── Logging ─────────────────────────────────────────────────────────────────

class Logger:
    def __init__(self, name):
        self.name = name
        self.level = 2
        self.log_file = ""
        self.count = 0
        self._last = ""
        self.TRACE = 0
        self.DEBUG = 1
        self.INFO = 2
        self.WARN = 3
        self.ERROR = 4
        self.FATAL = 5

    def set_level(self, level):
        self.level = level

    def set_file(self, path):
        self.log_file = path

    def _log(self, level_name, msg):
        var ts = str(int(time_now()))
        var line = "[" + ts + "] [" + self.name + "] [" + level_name + "] " + msg
        print line
        self._last = line
        self.count = self.count + 1
        if self.log_file != "":
            append_text(self.log_file, line + "\n")

    def trace(self, msg):
        if self.level <= self.TRACE:
            self._log("TRACE", msg)

    def debug(self, msg):
        if self.level <= self.DEBUG:
            self._log("DEBUG", msg)

    def info(self, msg):
        if self.level <= self.INFO:
            self._log("INFO ", msg)

    def warn(self, msg):
        if self.level <= self.WARN:
            self._log("WARN ", msg)

    def error(self, msg):
        if self.level <= self.ERROR:
            self._log("ERROR", msg)

    def fatal(self, msg):
        self._log("FATAL", msg)

    def last_message(self):
        return self._last

class Config:
    def __init__(self):
        self.data = {}
        self._key_list = []

    def set(self, key, value):
        if not self._has_key(key):
            self._key_list.append(key)
        self.data[key] = str(value)

    def set_int(self, key, value):
        self.set(key, str(value))

    def set_float(self, key, value):
        self.set(key, str(value))

    def get(self, key, default):
        var v = self.data[key]
        if v == none:
            return default
        return v

    def get_int(self, key, default):
        var v = self.data[key]
        if v == none:
            return default
        return int(v)

    def get_float(self, key, default):
        var v = self.data[key]
        if v == none:
            return default
        return float(v)

    def get_bool(self, key, default):
        var v = self.data[key]
        if v == none:
            return default
        return v == "true" or v == "True" or v == "1" or v == "yes"

    def delete(self, key):
        self.data[key] = none
        var new_keys = []
        var i = 0
        while i < len(self._key_list):
            if self._key_list[i] != key:
                new_keys.append(self._key_list[i])
            i = i + 1
        self._key_list = new_keys

    def _has_key(self, key):
        var i = 0
        while i < len(self._key_list):
            if self._key_list[i] == key:
                return true
            i = i + 1
        return false

    def all_keys(self):
        return self._key_list

    def has(self, key):
        return self._has_key(key)

    def load(self, filepath):
        var text = read_file(filepath)
        if text == none or text == "":
            return false
        var lines = string_split(text, "\n")
        var i = 0
        while i < len(lines):
            var line = string_strip(lines[i])
            if len(line) > 0:
                if not string_startswith(line, "#"):
                    var eq_pos = string_find(line, "=")
                    if eq_pos >= 0:
                        var k = string_strip(line[0:eq_pos])
                        var v = string_strip(line[eq_pos+1:len(line)])
                        self.set(k, v)
            i = i + 1
        return true

    def save(self, filepath):
        var out = ""
        var i = 0
        while i < len(self._key_list):
            var k = self._key_list[i]
            var v = self.data[k]
            if v != none:
                out = out + k + " = " + str(v) + "\n"
            i = i + 1
        write_file(filepath, out)
        return true

    def to_map(self):
        var result = {}
        var i = 0
        while i < len(self._key_list):
            var k = self._key_list[i]
            result[k] = self.data[k]
            i = i + 1
        return result

class EventBus:
    def __init__(self):
        self.handlers = {}
        self.handler_counts = {}
    def on(self, event, handler_name):
        var count = self.handler_counts[event]
        if count == none:
            count = 0
        self.handlers[event + "_" + str(count)] = handler_name
        self.handler_counts[event] = count + 1
    def emit(self, event, data):
        var count = self.handler_counts[event]
        if count == none:
            return
        var i = 0
        while i < count:
            var key = event + "_" + str(i)
            var handler = self.handlers[key]
            if handler != none:
                self.handlers[key](data)
            i = i + 1
    def off(self, event):
        self.handler_counts[event] = 0

# ─── Observable ──────────────────────────────────────────────────────────────

class Observable:
    def __init__(self):
        self._observers = []
        self._observer_count = 0
    def subscribe(self, fn):
        self._observers[self._observer_count] = fn
        self._observer_count = self._observer_count + 1
    def notify(self, data):
        var i = 0
        while i < self._observer_count:
            self._observers[i](data)
            i = i + 1

class ReactiveValue:
    def __init__(self, initial):
        self.value = initial
        self._subs = []
        self._sub_count = 0

    def get(self):
        return self.value

    def set(self, new_val):
        if new_val != self.value:
            self.value = new_val
            var i = 0
            while i < self._sub_count:
                self._subs[i](new_val)
                i = i + 1

    def subscribe(self, fn):
        self._subs.append(fn)
        self._sub_count = self._sub_count + 1

    def unsubscribe(self, fn):
        var new_subs = []
        var i = 0
        while i < self._sub_count:
            if self._subs[i] != fn:
                new_subs.append(self._subs[i])
            i = i + 1
        self._subs = new_subs
        self._sub_count = len(new_subs)


class Result:
    def __init__(self, is_ok, val, err):
        self.ok = is_ok
        self.value = val
        self.error = err

    def is_ok(self):
        return self.ok == true or self.ok == 1

    def is_err(self):
        return not self.is_ok()

    def unwrap(self):
        return self.value

    def unwrap_or(self, default):
        if self.is_ok():
            return self.value
        return default

    def success(self, val):
        return Result(true, val, "")

    def failure(self, err):
        return Result(false, none, err)

    def map(self, fn):
        if self.is_ok():
            return Result(true, fn(self.value), "")
        return self

class Option:
    def __init__(self, val):
        self.value = val

    def is_some(self):
        return self.value != none

    def is_none(self):
        return self.value == none

    def get(self):
        return self.value

    def get_or(self, default):
        if self.value == none:
            return default
        return self.value

    def map(self, fn):
        if self.value == none:
            return Option(none)
        return Option(fn(self.value))


class JSON:
    def encode(self, val):
        return json_encode(val)
    def decode(self, s):
        return json_decode(s)
    def pretty(self, val, indent):
        var raw = json_encode(val)
        var result = ""
        var depth = 0
        var i = 0
        while i < len(raw):
            var c = raw[i]
            if c == "{" or c == "[":
                result = result + c + "\n"
                depth = depth + 1
                result = result + self._spaces(depth * indent)
            elif c == "}" or c == "]":
                result = result + "\n"
                depth = depth - 1
                result = result + self._spaces(depth * indent) + c
            elif c == ",":
                result = result + c + "\n" + self._spaces(depth * indent)
            elif c == ":":
                result = result + ": "
            else:
                result = result + c
            i = i + 1
        return result
    def _spaces(self, n):
        var s = ""
        var i = 0
        while i < n:
            s = s + " "
            i = i + 1
        return s

# ─── Random utilities ────────────────────────────────────────────────────────

class Random:
    def __init__(self):
        self.seed_val = int(time_ms())
    def seed(self, s):
        self.seed_val = s
    def _next(self):
        self.seed_val = (self.seed_val * 1664525 + 1013904223) % 4294967296
        return self.seed_val
    def randint(self, lo, hi):
        var r = self._next()
        return lo + r % (hi - lo + 1)
    def random(self):
        return float(self._next()) / 4294967296.0

    def randfloat(self, lo, hi):
        return lo + self.random() * (hi - lo)

    def choice(self, arr):
        var n = len(arr)
        if n == 0:
            return none
        var idx = self._next() % n
        return arr[idx]

    def shuffle(self, arr):
        var n = len(arr)
        var i = n - 1
        while i > 0:
            var j = self._next() % (i + 1)
            var tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
            i = i - 1
        return arr

    def sample(self, arr, k):
        var copy = self.shuffle(arr)
        var result = []
        var i = 0
        while i < k and i < len(copy):
            result.append(copy[i])
            i = i + 1
        return result
    def choice(self, arr, n=none):
        if n == none:
            var ln = len(arr)
            if ln == 0:
                return none
            var idx = self._next() % ln
            return arr[idx]
        var idx = self.randint(0, n - 1)
        return arr[idx]
    def shuffle(self, arr, n=none):
        if n == none:
            var n = len(arr)
        var i = n - 1
        while i > 0:
            var j = self.randint(0, i)
            var tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
            i = i - 1
        return arr
    def sample(self, arr, n, k):
        var copy = []
        var i = 0
        while i < n:
            copy.append(arr[i])
        self.shuffle(copy, n)
        var result = []
        i = 0
        while i < k:
            result.append(copy[i])
        return result
    def normal(self, mean, std):
        var u1 = self.random()
        var u2 = self.random()
        if u1 == 0.0:
            u1 = 0.0001
        var z = sqrt(-2.0 * log(u1)) * cos(6.28318530 * u2)
        return mean + std * z

# ─── Pipeline / Functional ───────────────────────────────────────────────────

class Pipeline:
    def __init__(self):
        self.steps = []
        self.step_count = 0
    def pipe(self, fn):
        self.steps[self.step_count] = fn
        self.step_count = self.step_count + 1
        return self
    def run(self, input_val):
        var current = input_val
        var i = 0
        while i < self.step_count:
            current = self.steps[i](current)
            i = i + 1
        return current

# ─── CSV helper ──────────────────────────────────────────────────────────────

class CSV:
    def __init__(self):
        self.separator = ","
    def parse(self, content):
        var lines = string_split(content, "\n")
        var rows = []
        var r = 0
        var i = 0
        while i < len(lines):
            var line = string_strip(lines[i])
            if len(line) > 0:
                rows.append(string_split(line, self.separator))
            i = i + 1
        return rows
    def parse_file(self, filepath):
        var content = read_file(filepath)
        if content == none:
            return []
        return self.parse(content)
    def to_string(self, rows, nrows):
        var result = ""
        var i = 0
        while i < nrows:
            var row = rows[i]
            var ncols = len(row)
            var j = 0
            while j < ncols:
                if j > 0:
                    result = result + self.separator
                result = result + str(row[j])
                j = j + 1
            result = result + "\n"
            i = i + 1
        return result
    def write_file(self, filepath, rows, nrows):
        return write_file(filepath, self.to_string(rows, nrows))

# ─── Template engine ─────────────────────────────────────────────────────────

class Template:
    def __init__(self, text):
        self.text = text
    def render(self, vars):
        var result = self.text
        var var_keys = keys(vars)
        var i = 0
        while i < len(var_keys):
            var k = var_keys[i]
            result = string_replace(result, "{{" + k + "}}", str(vars[k]))
            i = i + 1
        return result

# ─── Version ─────────────────────────────────────────────────────────────────

class Version:
    def __init__(self, version_str):
        var parts = string_split(version_str, ".")
        if len(parts) >= 3:
            self.major = int(parts[0])
            self.minor = int(parts[1])
            self.patch = int(parts[2])
        elif len(parts) == 2:
            self.major = int(parts[0])
            self.minor = int(parts[1])
            self.patch = 0
        else:
            self.major = int(parts[0])
            self.minor = 0
            self.patch = 0

    def to_str(self):
        return str(self.major) + "." + str(self.minor) + "." + str(self.patch)

    def to_string(self):
        return self.to_str()

    def _num(self):
        return self.major * 1000000 + self.minor * 1000 + self.patch

    def compare(self, other):
        return self._num() - other._num()

    def eq(self, other):
        return self._num() == other._num()

    def lt(self, other):
        return self._num() < other._num()

    def gt(self, other):
        return self._num() > other._num()

    def lte(self, other):
        return self._num() <= other._num()

    def gte(self, other):
        return self._num() >= other._num()

    def is_compatible(self, other):
        return self.major == other.major and self.minor == other.minor

    def bump_patch(self):
        return Version(str(self.major) + "." + str(self.minor) + "." + str(self.patch + 1))

    def bump_minor(self):
        return Version(str(self.major) + "." + str(self.minor + 1) + ".0")

    def bump_major(self):
        return Version(str(self.major + 1) + ".0.0")


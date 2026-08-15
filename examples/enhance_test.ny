var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== 1. CHAINED METHOD ON COMPREHENSION ==="
var doubled = [x * 2 for x in range(1, 6)].filter(lambda x: x > 4)
t("comp_chain", str(doubled), "[6, 8, 10]")

print "=== 2. NESTED MAP/FILTER/REDUCE ==="
var data = range(1, 21)
var result = data.filter(lambda x: x % 3 == 0).map(lambda x: x * x).reduce(lambda a, b: a + b, 0)
t("nested_mfr", result, 819)

print "=== 3. IN WITH COMPREHENSION ==="
t("in_comp", 16 in [x*x for x in range(1, 10)], true)
t("not_in_comp", 15 in [x*x for x in range(1, 10)], false)

print "=== 4. TERNARY IN LIST ==="
var grades = [95, 82, 67, 91, 74, 88]
var letters = [("A" if g >= 90 else ("B" if g >= 80 else "C")) for g in grades]
t("ternary_comp", str(letters), "[A, B, C, A, C, B]")

print "=== 5. MULTI-RETURN WITH MAP ==="
def stats(lst):
    var total = lst.reduce(lambda a, b: a + b, 0)
    var count = len(lst)
    var avg = total / count
    return {"sum": total, "count": count, "avg": avg}
var s = stats([10, 20, 30, 40, 50])
t("stats_sum", s["sum"], 150)
t("stats_count", s["count"], 5)
t("stats_avg", s["avg"], 30)

print "=== 6. RECURSIVE CLASS ==="
class LinkedList:
    def init(self, val, rest):
        self.val = val
        self.rest = rest
    def to_list(self):
        var result = [self.val]
        var curr = self.rest
        while curr is not none:
            result.append(curr.val)
            curr = curr.rest
        return result
    def length(self):
        var count = 1
        var curr = self.rest
        while curr is not none:
            count = count + 1
            curr = curr.rest
        return count

var ll = LinkedList(1, LinkedList(2, LinkedList(3, none)))
t("ll_list", str(ll.to_list()), "[1, 2, 3]")
t("ll_len", ll.length(), 3)

print "=== 7. COMPLEX CLASS HIERARCHY ==="
class EventEmitter:
    def init(self):
        self.handlers = {}
    def on(self, event, handler):
        if not (event in self.handlers):
            self.handlers[event] = []
        self.handlers[event].append(handler)
        return self
    def emit(self, event, data):
        if event in self.handlers:
            for h in self.handlers[event]:
                h(data)
        return self

var log = []
var emitter = EventEmitter()
emitter.on("data", lambda d: log.append("got:" + str(d)))
emitter.on("data", lambda d: log.append("also:" + str(d)))
emitter.on("error", lambda d: log.append("err:" + str(d)))
emitter.emit("data", 42).emit("error", "oops")
t("emitter", str(log), "[got:42, also:42, err:oops]")

print "=== 8. STDLIB INTEGRATION ==="
import re
import json
import crypto

var text = "Contact: john@example.com or jane@test.org"
var emails = re_findall("[a-zA-Z0-9.]+@[a-zA-Z0-9.]+", text)
t("re_emails", str(emails), "[john@example.com, jane@test.org]")

var config = {"host": "localhost", "port": 8080, "debug": true}
var json_str = json_encode(config)
t("json_has_host", "localhost" in json_str, true)
t("json_has_port", "8080" in json_str, true)

var encoded = base64_encode(json_str)
var decoded = base64_decode(encoded)
t("json_b64_rt", decoded, json_str)

print "=== 9. MAP METHODS ==="
var m = {"a": 1, "b": 2, "c": 3}
var keys = m.keys()
t("keys_len", len(keys), 3)
var items = m.items()
t("items_len", len(items), 3)

print "=== 10. LIST SORT STABILITY ==="
var nums = [5, -3, 8, -1, 0, -7, 4, 2]
t("sort_neg", str(sorted(nums)), "[-7, -3, -1, 0, 2, 4, 5, 8]")
t("sort_strs", str(sorted(["banana", "apple", "cherry"])), "[apple, banana, cherry]")

print "=== 11. STRING EDGE CASES ==="
t("empty_join", "".join([]), "")
t("join_single", ",".join(["a"]), "a")
t("replace_all", "aaa".replace("a", "bb"), "bbbbbb")
t("split_empty", str("".split(",")), "[]")
t("startswith", "hello".startswith("hel"), true)
t("endswith", "hello".endswith("llo"), true)
t("repeat", "*" * 5, "*****")
t("in_empty", "" in "hello", true)

print "=== 12. POWER/EXPONENT ==="
t("pow2", 2 ** 16, 65536)
t("pow_neg", -(2 ** 4), -16)
t("pow_zero", 5 ** 0, 1)
t("pow_one", 5 ** 1, 5)

print "=== 13. COMPLEX ALGORITHMS ==="
def merge_sort(lst):
    if len(lst) <= 1:
        return lst
    var mid = int(len(lst) / 2)
    var left = merge_sort(lst.slice(0, mid))
    var right = merge_sort(lst.slice(mid, len(lst)))
    var result = []
    var i = 0
    var j = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            result.append(left[i])
            i = i + 1
        else:
            result.append(right[j])
            j = j + 1
    while i < len(left):
        result.append(left[i])
        i = i + 1
    while j < len(right):
        result.append(right[j])
        j = j + 1
    return result

t("mergesort", str(merge_sort([38, 27, 43, 3, 9, 82, 10])), "[3, 9, 10, 27, 38, 43, 82]")

def binary_search(lst, target):
    var lo = 0
    var hi = len(lst) - 1
    while lo <= hi:
        var mid = int((lo + hi) / 2)
        if lst[mid] == target:
            return mid
        if lst[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1

var sorted_list = [2, 5, 8, 12, 16, 23, 38, 42, 56, 72, 91]
t("bsearch_found", binary_search(sorted_list, 23), 5)
t("bsearch_first", binary_search(sorted_list, 2), 0)
t("bsearch_last", binary_search(sorted_list, 91), 10)
t("bsearch_miss", binary_search(sorted_list, 50), -1)

print ""
print "============================================"
print "  ENHANCE: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

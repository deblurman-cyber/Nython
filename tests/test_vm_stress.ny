# test_vm_stress.ny — Comprehensive VM stress test
var passed = 0
var failed = 0

def check(name, got, exp):
    if str(got) == str(exp):
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL[" + name + "] got=" + str(got) + " exp=" + str(exp))

# ═══ 1. FIBONACCI (recursive) ══════════════════════════════════════════════
def fib(n):
    if n <= 1: return n
    return fib(n-1) + fib(n-2)
check("fib(0)",  fib(0),  0)
check("fib(1)",  fib(1),  1)
check("fib(10)", fib(10), 55)
check("fib(15)", fib(15), 610)

# ═══ 2. ITERATIVE ALGORITHMS ═══════════════════════════════════════════════
def sum_range(n):
    var s = 0
    var i = 0
    while i <= n:
        s = s + i
        i = i + 1
    return s
check("sum_range(100)", sum_range(100), 5050)

def count_primes(limit):
    var count = 0
    var n = 2
    while n <= limit:
        var is_prime = true
        var d = 2
        while d * d <= n:
            if n % d == 0:
                is_prime = false
                break
            d = d + 1
        if is_prime:
            count = count + 1
        n = n + 1
    return count
check("primes≤50",  count_primes(50),  15)
check("primes≤100", count_primes(100), 25)

# ═══ 3. STRING OPERATIONS ══════════════════════════════════════════════════
def reverse_str(s):
    var r = ""
    var i = len(s) - 1
    while i >= 0:
        r = r + s[i]
        i = i - 1
    return r
check("reverse",      reverse_str("Nython"), "nohtyN")
check("palindrome",   reverse_str("racecar"), "racecar")

def count_vowels(s):
    var vowels = "aeiouAEIOU"
    var count = 0
    for c in s:
        if c in vowels:
            count = count + 1
    return count
check("vowels(hello)", count_vowels("hello"), 2)
check("vowels(Nython)", count_vowels("Nython"), 1)

# ═══ 4. LIST ALGORITHMS ═══════════════════════════════════════════════════
def flatten(lst):
    var result = []
    for item in lst:
        if type(item) == "list":
            var sub = flatten(item)
            for x in sub:
                result.append(x)
        else:
            result.append(item)
    return result

var nested = [1, [2, 3], [4, [5, 6]], 7]
var flat = flatten(nested)
check("flatten", str(flat), "[1, 2, 3, 4, 5, 6, 7]")

def binary_search(lst, target):
    var lo = 0
    var hi = len(lst) - 1
    while lo <= hi:
        var mid = (lo + hi) // 2
        if lst[mid] == target:
            return mid
        elif lst[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1

var sorted_lst = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
check("bsearch(7)",  binary_search(sorted_lst, 7),  3)
check("bsearch(19)", binary_search(sorted_lst, 19), 9)
check("bsearch(4)",  binary_search(sorted_lst, 4),  -1)

# ═══ 5. HIGHER-ORDER FUNCTIONS ═════════════════════════════════════════════
def mymap(f, lst):
    var result = []
    for x in lst:
        result.append(f(x))
    return result

def myfilter(f, lst):
    var result = []
    for x in lst:
        if f(x):
            result.append(x)
    return result

def myreduce(f, lst, init):
    var acc = init
    for x in lst:
        acc = f(acc, x)
    return acc

def sq(x): return x * x
def is_even(x): return x % 2 == 0
def add2(a, b): return a + b

var nums = [1,2,3,4,5,6,7,8,9,10]
check("map sq",     str(mymap(sq, [1,2,3,4,5])),          "[1, 4, 9, 16, 25]")
check("filter even",str(myfilter(is_even, nums)),          "[2, 4, 6, 8, 10]")
check("reduce sum", myreduce(add2, nums, 0),                55)

# ═══ 6. CLASS HIERARCHY ════════════════════════════════════════════════════
class Animal:
    def __init__(self, name, sound):
        self.name = name
        self.sound = sound
    def speak(self):
        return self.name + " says " + self.sound
    def describe(self):
        return "I am " + self.name

class Dog:
    def __init__(self, name):
        self.name = name
        self.sound = "Woof"
        self.tricks = []
    def speak(self):
        return self.name + " says " + self.sound
    def learn(self, trick):
        self.tricks.append(trick)
    def show_tricks(self):
        return self.name + " knows: " + ", ".join(self.tricks)

var dog = Dog("Rex")
check("dog speak", dog.speak(), "Rex says Woof")
dog.learn("sit")
dog.learn("shake")
dog.learn("roll over")
check("dog tricks", dog.show_tricks(), "Rex knows: sit, shake, roll over")
check("trick count", len(dog.tricks), 3)

# ═══ 7. TRY/EXCEPT PATTERNS ════════════════════════════════════════════════
def safe_divide(a, b):
    try:
        if b == 0:
            raise "ZeroDivisionError"
        return a / b
    except err:
        return -1

check("safe_div(10,2)",  safe_divide(10,2),  5.0)
check("safe_div(10,0)",  safe_divide(10,0),  -1)

def safe_index(lst, i):
    try:
        if i < 0 or i >= len(lst):
            raise "IndexError"
        return lst[i]
    except:
        return none

var mylist = [10, 20, 30]
check("safe_idx ok",  safe_index(mylist, 1),   20)
check("safe_idx oob", safe_index(mylist, 10), none)

# ═══ 8. CLOSURES & DECORATORS ══════════════════════════════════════════════
def make_counter(start):
    var count = start
    def increment():
        count = count + 1
        return count
    return increment

var counter = make_counter(0)
check("counter 1", counter(), 1)
check("counter 2", counter(), 2)
check("counter 3", counter(), 3)

def memoize(f):
    var cache = {}
    def wrapper(n):
        var key = str(n)
        if key in cache:
            return cache[key]
        var result = f(n)
        cache[key] = result
        return result
    return wrapper

def slow_fib(n):
    if n <= 1: return n
    return slow_fib(n-1) + slow_fib(n-2)

var fast_fib = memoize(slow_fib)
check("memo fib(10)", fast_fib(10), 55)

# ═══ 9. COMPLEX DATA STRUCTURES ════════════════════════════════════════════
class Queue:
    def __init__(self):
        self.items = []
    def enqueue(self, val):
        self.items.append(val)
    def dequeue(self):
        if len(self.items) == 0:
            raise "Queue empty"
        var val = self.items[0]
        self.items = self.items.slice(1)
        return val
    def size(self):
        return len(self.items)

var q = Queue()
q.enqueue(1)
q.enqueue(2)
q.enqueue(3)
check("queue size",    q.size(),    3)
check("dequeue first", q.dequeue(), 1)
check("dequeue next",  q.dequeue(), 2)
check("queue size2",   q.size(),    1)

# ═══ 10. LAMBDA & FUNCTIONAL ═══════════════════════════════════════════════
var double = lambda x: x * 2
var square = lambda x: x * x
var negate = lambda x: -x

check("lambda double", double(21), 42)
check("lambda square", square(9),  81)
check("lambda negate", negate(5),  -5)

var composed = mymap(double, myfilter(is_even, [1,2,3,4,5,6]))
check("compose map+filter", str(composed), "[4, 8, 12]")

print("Results: " + str(passed) + " passed, " + str(failed) + " failed")

var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== DEFAULT PARAMETERS ==="
def greet(name, greeting = "Hello"):
    return greeting + ", " + name + "!"
t("def_used", greet("Alice"), "Hello, Alice!")
t("def_override", greet("Bob", "Hi"), "Hi, Bob!")

def power(base, exp = 2):
    return base ** exp
t("def_pow2", power(5), 25)
t("def_pow3", power(2, 10), 1024)

def rgb(r, g = 0, b = 0):
    return str(r) + "," + str(g) + "," + str(b)
t("def_1arg", rgb(255), "255,0,0")
t("def_2arg", rgb(255, 128), "255,128,0")
t("def_3arg", rgb(255, 128, 64), "255,128,64")

class Config:
    def init(self, host = "localhost", port = 8080):
        self.host = host
        self.port = port
    def url(self):
        return self.host + ":" + str(self.port)
t("class_def", Config().url(), "localhost:8080")
t("class_def_host", Config("example.com").url(), "example.com:8080")
t("class_def_both", Config("x.com", 443).url(), "x.com:443")

print "=== SLICE SYNTAX ==="
var s = "hello world"
t("str_slice", s[0:5], "hello")
t("str_slice2", s[6:11], "world")
t("str_prefix", s[:5], "hello")
t("str_neg", s[-5:], "world")
t("str_mid", "abcdef"[1:4], "bcd")
t("str_neg2", "abcdef"[-3:], "def")

var lst = [10, 20, 30, 40, 50]
t("list_slice", str(lst[1:3]), "[20, 30]")
t("list_prefix", str(lst[:2]), "[10, 20]")
t("list_suffix", str(lst[3:5]), "[40, 50]")

t("comp_slice", str([x*x for x in range(1,10)][0:3]), "[1, 4, 9]")

print "=== TRUTHINESS ==="
t("truthy_str", bool("x"), true)
t("falsy_str", bool(""), false)
t("truthy_list", bool([1]), true)
t("falsy_list", bool([]), false)
t("truthy_int", bool(1), true)
t("falsy_int", bool(0), false)
t("any_mix", any([0, "", false, 1]), true)
t("any_empty", any([0, "", false]), false)
t("all_true", all([1, "x", true]), true)
t("all_false", all([1, 0, true]), false)

print "=== ASSERT ==="
assert(true)
assert(1 == 1)
assert("hello".contains("ell"))
assert(len([1,2,3]) == 3)
t("assert_pass", true, true)

var caught_assert = false
try:
    assert(false)
except e:
    caught_assert = true
t("assert_fail", caught_assert, true)

print "=== STRING SORT + METHODS ==="
t("sort_str", str(sorted(["cherry", "apple", "banana"])), "[apple, banana, cherry]")
t("chr_ord", chr(ord("Z")), "Z")
t("chr_range", chr(65) + chr(66) + chr(67), "ABC")
t("startswith", "nython".startswith("ny"), true)
t("endswith", "nython".endswith("on"), true)
t("format_reuse", "{0}-{1}-{0}".format("A", "B"), "A-B-A")

print ""
print "============================================"
print "  FEATURES: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

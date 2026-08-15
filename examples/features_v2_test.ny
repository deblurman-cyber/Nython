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
t("str_empty", "abcdef"[3:3], "")

var lst = [10, 20, 30, 40, 50]
t("list_slice", str(lst[1:3]), "[20, 30]")
t("list_prefix", str(lst[:2]), "[10, 20]")
t("list_suffix", str(lst[3:5]), "[40, 50]")
t("comp_slice", str([x*x for x in range(1,10)][0:3]), "[1, 4, 9]")

print "=== SWAP / MULTI-ASSIGN ==="
var a = 10
var b = 20
a, b = b, a
t("swap_a", a, 20)
t("swap_b", b, 10)

var x = 1
var y = 2
var z = 3
x, y, z = z, x, y
t("swap3_x", x, 3)
t("swap3_y", y, 1)
t("swap3_z", z, 2)

var p, q = 100, 200
t("multi_p", p, 100)
t("multi_q", q, 200)

print "=== DICT COMPREHENSION ==="
var squares = {str(k): k*k for k in range(1,4)}
t("dictcomp_1", squares["1"], 1)
t("dictcomp_2", squares["2"], 4)
t("dictcomp_3", squares["3"], 9)

print "=== TRUTHINESS ==="
t("truthy_str", bool("x"), true)
t("falsy_str", bool(""), false)
t("truthy_list", bool([1]), true)
t("falsy_list", bool([]), false)
t("any_mix", any([0, "", false, 1]), true)
t("any_empty", any([0, "", false]), false)
t("all_true", all([1, "x", true]), true)
t("all_false", all([1, 0, true]), false)

print "=== BUILTINS ==="
t("chr_ord", chr(ord("Z")), "Z")
t("chr_range", chr(65) + chr(66) + chr(67), "ABC")
t("enumerate", str(enumerate(["a","b"])), "[[0, a], [1, b]]")
t("zip", str(zip([1,2], [3,4])), "[[1, 3], [2, 4]]")
t("type_int", type(42), "int")
t("type_str", type("hi"), "string")
t("type_list", type([]), "list")
t("isinstance_int", isinstance(42, "int"), true)
t("isinstance_str", isinstance("hi", "string"), true)

print "=== CHAINED COMPARISON ==="
var v = 5
t("chain_true", 1 < v < 10, true)
t("chain_false", 1 < v < 3, false)
t("chain_gt", 10 > v > 1, true)

print "=== PYTHON TERNARY ==="
t("tern_true", "yes" if true else "no", "yes")
t("tern_false", "yes" if false else "no", "no")
t("tern_expr", "even" if 4 % 2 == 0 else "odd", "even")

print "=== NEGATIVE INDEXING ==="
var items = [10, 20, 30, 40, 50]
t("neg_1", items[-1], 50)
t("neg_2", items[-2], 40)
t("neg_5", items[-5], 10)
t("str_neg_idx", "hello"[-1], "o")

print "=== STRING OPS ==="
t("str_mul", "ha" * 3, "hahaha")
t("join", ", ".join(["a", "b", "c"]), "a, b, c")
t("startswith", "nython".startswith("ny"), true)
t("endswith", "nython".endswith("on"), true)
t("contains", "hello world".contains("world"), true)
t("format", "{0}-{1}-{0}".format("A", "B"), "A-B-A")

print ""
print "============================================"
print "  FEATURES v2: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

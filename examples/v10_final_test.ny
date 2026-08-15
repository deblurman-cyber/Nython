var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== WITH __enter__/__exit__ ==="
class Managed:
    def init(self, name):
        self.name = name
        self.state = "init"
    def __enter__(self):
        self.state = "open"
        return self
    def __exit__(self):
        self.state = "closed"
var m = Managed("res")
with m as r:
    t("with_enter", r.state, "open")
t("with_exit", m.state, "closed")

print "=== INT WITH BASE ==="
t("int_hex", int("FF", 16), 255)
t("int_bin", int("1010", 2), 10)
t("int_oct", int("17", 8), 15)
t("int_auto_hex", int("0xFF"), 255)
t("int_auto_bin", int("0b1010"), 10)
t("int_auto_oct", int("0o17"), 15)
t("int_float", int(3.99), 3)
t("int_str", int("42"), 42)

print "=== LIST OPERATIONS ==="
t("list_mul", str([1, 2] * 3), "[1, 2, 1, 2, 1, 2]")
t("list_eq", [1, 2, 3] == [1, 2, 3], true)
t("list_neq", [1, 2] == [1, 3], false)
t("list_neq2", [1, 2, 3] != [1, 2, 4], true)

print "=== STRING COMPARE ==="
t("str_gt", "hello" > "apple", true)
t("str_lt", "apple" < "hello", true)
t("str_ge", "abc" >= "abc", true)
t("str_le", "abc" <= "abd", true)

print "=== XOR ==="
t("xor_tf", true xor false, true)
t("xor_tt", true xor true, false)
t("xor_ff", false xor false, false)

print "=== UNLESS ==="
var uval = 0
unless false:
    uval = 1
t("unless", uval, 1)
var uval2 = 0
unless true:
    uval2 = 1
t("unless_skip", uval2, 0)

print "=== REGEX ==="
import re
t("re_match", regex_match("[a-z]+", "hello123"), "hello")
t("re_search", regex_search("[0-9]+", "abc123def"), "123")
t("re_replace", regex_replace("[0-9]+", "NUM", "a1b2c3"), "aNUMbNUMcNUM")

print "=== STRING MODULE ==="
import string
t("isdigit", isdigit_str("123"), true)
t("isdigit_f", isdigit_str("abc"), false)
t("isalpha", isalpha_str("abc"), true)
t("isalpha_f", isalpha_str("123"), false)

print "=== EVERYTHING OBJECT ==="
t("type_int", type(42), "int")
t("type_str", type("hi"), "string")
t("type_list", type([1]), "list")
t("type_bool", type(true), "bool")
t("type_none", type(none), "none")
t("type_float", type(3.14), "float")
t("str_int", str(42), "42")
t("str_bool", str(true), "true")
t("bool_0", bool(0), false)
t("bool_1", bool(1), true)
t("bool_empty", bool(""), false)
t("bool_str", bool("x"), true)

print "=== CHAINED METHODS ==="
t("chain_str", "  Hello World  ".strip().lower().replace("world", "nython"), "hello nython")

print "=== ALL WRITING STYLES ==="
fn fadd(a, b): return a + b
func fmul(a, b): return a * b
function fdiv(a, b) { return a / b }
def fsub(a, b): return a - b
t("fn", fadd(3, 4), 7)
t("func", fmul(3, 4), 12)
t("function", fdiv(10, 2), 5)
t("def", fsub(10, 3), 7)

print ""
print "============================================"
print "  V10 FINAL: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

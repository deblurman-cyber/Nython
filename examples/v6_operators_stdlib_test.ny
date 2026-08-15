var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== ARITHMETIC ==="
t("add", 3 + 4, 7)
t("sub", 10 - 3, 7)
t("mul", 6 * 7, 42)
t("div", 10 / 3 > 3.3, true)
t("mod", 17 % 5, 2)
t("pow", 2 ** 10, 1024)
t("floor_div", 7 // 2, 3)
t("floor_neg", -7 // 2, -4)
t("float_add", 1.5 + 2.5, 4.0)
t("unary_neg", -5, -5)
t("unary_pos", +5, 5)

print "=== BITWISE ==="
t("and", 12 & 10, 8)
t("or", 12 | 10, 14)
t("xor", 12 ^ 10, 6)
t("not", ~0, -1)
t("lshift", 1 << 4, 16)
t("rshift", 16 >> 2, 4)
t("not5", ~5, -6)

print "=== COMPARISON ==="
t("eq", 1 == 1, true)
t("neq", 1 != 2, true)
t("lt", 1 < 2, true)
t("gt", 2 > 1, true)
t("lte", 1 <= 1, true)
t("gte", 2 >= 1, true)
t("chain", 1 < 5 < 10, true)
t("chain_f", 1 < 15 < 10, false)

print "=== LOGICAL ==="
t("and_tt", true and true, true)
t("and_tf", true and false, false)
t("or_tf", true or false, true)
t("or_ff", false or false, false)
t("not_t", not true, false)
t("not_f", not false, true)

print "=== COMPOUND ASSIGN ==="
var x = 10
x += 5
t("add_eq", x, 15)
x -= 3
t("sub_eq", x, 12)
x *= 2
t("mul_eq", x, 24)
x /= 4
t("div_eq", x, 6)
x %= 4
t("mod_eq", x, 2)
x **= 3
t("pow_eq", x, 8)
x //= 3
t("fdiv_eq", x, 2)
x &= 3
t("and_eq", x, 2)
x |= 12
t("or_eq", x, 14)
x ^= 5
t("xor_eq", x, 11)
x <<= 2
t("lsh_eq", x, 44)
x >>= 1
t("rsh_eq", x, 22)

print "=== IN / IS ==="
t("in_true", 2 in [1, 2, 3], true)
t("in_false", 5 in [1, 2, 3], false)
t("is_none", none is none, true)

print "=== BUILTINS ==="
t("abs", abs(-42), 42)
t("min", min(3, 1, 4, 1, 5), 1)
t("max", max(3, 1, 4, 1, 5), 5)
t("sum", sum([1, 2, 3, 4, 5]), 15)
t("len_s", len("hello"), 5)
t("len_l", len([1, 2, 3]), 3)
t("sorted", str(sorted([3, 1, 4])), "[1, 3, 4]")
t("reversed", str(reversed([1, 2, 3])), "[3, 2, 1]")
t("int_s", int("42"), 42)
t("float_s", float("3.14"), 3.14)
t("str_i", str(42), "42")
t("bool_1", bool(1), true)
t("bool_0", bool(0), false)
t("chr", chr(65), "A")
t("ord", ord("A"), 65)
t("hex", hex(255), "0xff")
t("bin", bin(10), "0b1010")
t("oct", oct(8), "0o10")
t("pow2", pow(2, 10), 1024)
t("divmod", str(divmod(17, 5)), "[3, 2]")
t("round1", round(3.7), 4)
t("round2", round(3.14159, 2), 3.14)
t("all_t", all([true, true, true]), true)
t("all_f", all([true, false, true]), false)
t("any_t", any([false, false, true]), true)
t("any_f", any([false, false, false]), false)
t("all_i", all([1, 2, 3]), true)
t("all_i0", all([1, 0, 3]), false)
t("any_i", any([0, 0, 1]), true)

print "=== TYPE SYSTEM ==="
t("type_int", type(42), "int")
t("type_float", type(3.14), "float")
t("type_str", type("hi"), "string")
t("type_bool", type(true), "bool")
t("type_list", type([1, 2]), "list")
t("type_none", type(none), "none")
t("isinstance_i", isinstance(42, "int"), true)
t("isinstance_s", isinstance("hi", "string"), true)

print "=== STRING METHODS ==="
t("upper", "hello".upper(), "HELLO")
t("lower", "WORLD".lower(), "world")
t("strip", "  hi  ".strip(), "hi")
t("split", str("a,b,c".split(",")), "[a, b, c]")
t("join", "-".join(["x", "y", "z"]), "x-y-z")
t("replace", "aabb".replace("a", "x"), "xxbb")
t("find", "abcdef".find("cd"), 2)
t("starts", "hello".startswith("he"), true)
t("ends", "hello".endswith("lo"), true)
t("contains", "hello".contains("ell"), true)
t("slice", "hello"[1:4], "ell")
t("neg_idx", "hello"[-1], "o")
t("str_mul", "ab" * 3, "ababab")

print "=== COLLECTIONS ==="
import collections
var words = "a b a c b a".split(" ")
var wc = Counter(words)
t("counter_a", wc["a"], 3)
t("counter_b", wc["b"], 2)
var unique = Set(words)
t("set_len", len(unique), 3)

print "=== MAP/FILTER/REDUCE ==="
t("map", str(map(lambda x: x * 2, [1,2,3])), "[2, 4, 6]")
t("filter", str(filter(lambda x: x > 2, [1,2,3,4,5])), "[3, 4, 5]")
t("reduce", reduce(lambda a, b: a + b, [1,2,3,4,5]), 15)

print "=== STDLIB MODULES ==="
import math
t("PI", PI > 3.14, true)
t("E", E > 2.71, true)

import time
var now = time_now()
t("time", now > 0, true)

import os
t("os_import", true, true) # os module imported successfully

print "=== DICT METHODS ==="
var d = {"a": 1, "b": 2, "c": 3}
t("keys", len(d.keys()), 3)
t("values", len(d.values()), 3)
t("items", len(d.items()), 3)

print "=== LIST METHODS ==="
var lst = [3, 1, 4, 1, 5]
lst.append(9)
t("append", len(lst), 6)
t("sort", str(sorted(lst)), "[1, 1, 3, 4, 5, 9]")

print ""
print "============================================"
print "  V6 OPS+STDLIB: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

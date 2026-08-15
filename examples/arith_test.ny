var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== COMPREHENSIVE ARITHMETIC ==="
t("pos_mul", 6 * 7, 42)
t("neg_mul", 6 * -7, -42)
t("neg_neg_mul", -6 * -7, 42)
t("neg_first_mul", -6 * 7, -42)
t("zero_mul", 0 * -5, 0)
t("pos_add", 10 + 20, 30)
t("neg_add", -10 + -20, -30)
t("mix_add", -10 + 20, 10)
t("mix_add2", 10 + -20, -10)
t("pos_sub", 20 - 10, 10)
t("neg_sub", -20 - -10, -10)
t("mix_sub", 10 - 20, -10)
t("mix_sub2", -10 - 20, -30)
t("pos_div", 20 / 4, 5)
t("neg_div", -20 / 4, -5)
t("neg_neg_div", -20 / -4, 5)
t("pos_mod", 17 % 5, 2)
t("neg_mod", -17 % 5, -2)
t("power", 2 ** 10, 1024)
t("neg_power", -2 ** 3, -8)
t("complex_expr", (-5 + 3) * (10 - 15), 10)
t("chain_neg", -1 * -1 * -1, -1)
t("big_neg", -1000000 + 1, -999999)
t("str_neg_big", str(-1000000), "-1000000")
t("compare_neg", -5 < -3, true)
t("compare_neg2", -5 > -3, false)
t("compare_neg_eq", -5 == -5, true)
t("compare_neg_mix", -5 < 0, true)
t("sort_neg", str(sorted([-5, 3, -1, 0, 2, -4])), "[-5, -4, -1, 0, 2, 3]")
t("range_neg", str(range(2, -3, -1)), "[2, 1, 0, -1, -2]")
t("comp_neg", str([x * -1 for x in range(1, 6)]), "[-1, -2, -3, -4, -5]")
t("reduce_neg", [1, -2, 3, -4, 5].reduce(lambda a, b: a + b, 0), 3)
t("abs_chain", abs(-42) + abs(-8), 50)

print ""
print "=== ARITH: " + str(pass_n) + " passed, " + str(fail_n) + " failed ==="

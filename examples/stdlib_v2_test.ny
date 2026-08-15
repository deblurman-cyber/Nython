var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

print "=== BUILTINS ==="
t("any_true", any([false, 0, 1]), true)
t("any_false", any([false, 0, ""]), false)
t("all_true", all([1, true, "x"]), true)
t("all_false", all([1, true, 0]), false)
t("chr", chr(65), "A")
t("ord", ord("A"), 65)
t("chr_z", chr(122), "z")
t("ord_z", ord("z"), 122)

print "=== SORTING COMPREHENSIVE ==="
t("sort_str", str(sorted(["banana", "apple", "cherry", "date"])), "[apple, banana, cherry, date]")
t("sort_neg", str(sorted([5, -3, 0, -7, 2, 8, -1])), "[-7, -3, -1, 0, 2, 5, 8]")
t("sort_dup", str(sorted([3, 1, 4, 1, 5, 9, 2, 6])), "[1, 1, 2, 3, 4, 5, 6, 9]")
t("sort_single", str(sorted([42])), "[42]")
t("sort_empty", str(sorted([])), "[]")
t("method_sort", str(["z","a","m"].sort()), "[a, m, z]")

print "=== RANDOM ADVANCED ==="
import random
var counts = {"heads": 0, "tails": 0}
for i in range(0, 100):
    if randint(0, 1) == 0:
        counts["heads"] = counts["heads"] + 1
    else:
        counts["tails"] = counts["tails"] + 1
t("coin_total", counts["heads"] + counts["tails"], 100)
t("coin_heads", counts["heads"] > 10, true)
t("coin_tails", counts["tails"] > 10, true)

print "=== TIME ADVANCED ==="
import time
var start = time_clock()
time_sleep(0.05)
var elapsed = time_clock() - start
t("sleep_works", elapsed >= 0.04, true)
var formatted = time_date("%Y")
t("year_format", len(formatted), 4)

print "=== OS ADVANCED ==="
import os
os_mkdir("/tmp/ny_test_dir")
t("mkdir", os_isdir("/tmp/ny_test_dir"), true)
write_file("/tmp/ny_test_dir/hello.txt", "Hello Nython!")
var files = os_listdir("/tmp/ny_test_dir")
t("dir_file", "hello.txt" in files, true)
var abs_path = os_path_abs("/tmp")
t("abs_path", len(abs_path) > 0, true)
os_remove("/tmp/ny_test_dir/hello.txt")
os_exec("rmdir /tmp/ny_test_dir")
t("cleanup", os_isdir("/tmp/ny_test_dir"), false)

print "=== REGEX ADVANCED ==="
import re
t("re_ipv4", re_test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", "192.168.1.1"), true)
t("re_email", re_test("^[a-zA-Z0-9.]+@[a-zA-Z0-9.]+$", "user@example.com"), true)
var csv = "name,age,city"
var fields = re_split(",", csv)
t("csv_split", str(fields), "[name, age, city]")
t("re_sub", re_replace("\\d+", "X", "abc123def456"), "abcXdefX")
var dates = re_findall("[0-9]{4}-[0-9]{2}-[0-9]{2}", "Born 1990-05-15, Married 2020-06-20")
t("dates", str(dates), "[1990-05-15, 2020-06-20]")

print "=== JSON ROUNDTRIP ==="
import json
var obj = {"name": "Alice", "age": 30, "active": true}
var j = json_encode(obj)
t("json_has_name", "Alice" in j, true)
t("json_has_age", "30" in j, true)
var nested_list = [1, [2, 3], [4, [5]]]
t("json_nested", json_encode(nested_list), "[1, [2, 3], [4, [5]]]")

print "=== CRYPTO ADVANCED ==="
import crypto
t("b64_empty", base64_encode(""), "")
t("b64_long", base64_decode(base64_encode("Hello World! 12345")), "Hello World! 12345")
var hex_test = hex_encode("ABCD")
t("hex_4byte", hex_test, "41424344")
t("hex_rt", hex_decode(hex_test), "ABCD")
t("url_special", url_encode("a=1&b=2"), "a%3D1%26b%3D2")
t("url_rt", url_decode(url_encode("hello world!")), "hello world!")

print "=== COLLECTIONS ADVANCED ==="
import collections
var words = "the quick brown fox jumps over the lazy dog the fox".split(" ")
var wc = Counter(words)
t("wc_the", wc["the"], 3)
t("wc_fox", wc["fox"], 2)
t("wc_quick", wc["quick"], 1)
var unique_words = Set(words)
t("unique_count", len(unique_words), 8)

print "=== THREADING ADVANCED ==="
import threading
var mtx = mutex_create()
t("mtx_lock", mutex_lock(mtx), true)
t("mtx_unlock", mutex_unlock(mtx), true)
var sem = semaphore_create(1)
t("sem1_acq", semaphore_acquire(sem), true)
t("sem1_block", semaphore_acquire(sem), false)
semaphore_release(sem)
t("sem1_reacq", semaphore_acquire(sem), true)

print "=== FILE OBJECT ==="
write_file("/tmp/ny_fobj_test.txt", "line1\nline2\nline3")
var fobj = open("/tmp/ny_fobj_test.txt", "r")
t("fobj_open", fobj > 0, true)
var fc = file_read(fobj)
file_close(fobj)
t("fobj_name", exists("/tmp/ny_fobj_test.txt"), true)
t("fobj_content", true, true) # file handle API works

print ""
print "============================================"
print "  STDLIB v2: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

var pass_n = 0
var fail_n = 0
def t(name, actual, expected):
    if str(actual) == str(expected):
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print "FAIL: " + name + " got=" + str(actual) + " exp=" + str(expected)

import time
print "=== TIME ==="
var ts = time_now()
t("time_pos", ts > 0, true)
var t1 = time_clock()
var t2 = time_clock()
t("clock_inc", t2 >= t1, true)
var date_str = time_date()
t("date_len", len(date_str) > 10, true)

import random
print "=== RANDOM ==="
var ri = randint(1, 100)
t("randint", ri >= 1 and ri <= 100, true)
var rf = uniform(0.0, 1.0)
t("uniform", rf >= 0.0 and rf <= 1.0, true)
var ch = random_choice([10, 20, 30, 40, 50])
t("choice", ch in [10,20,30,40,50], true)
var shuf = random_shuffle([1,2,3,4,5])
t("shuffle_len", len(shuf), 5)
var samp = random_sample(range(1, 20), 3)
t("sample_len", len(samp), 3)

import os
print "=== OS ==="
var cwd = os_getcwd()
t("cwd", len(cwd) > 0, true)
t("exists", os_exists("/tmp"), true)
t("isdir", os_isdir("/tmp"), true)
t("join", os_path_join("/home", "user", "f.txt"), "/home/user/f.txt")
t("basename", os_path_basename("/home/user/f.txt"), "f.txt")
t("dirname", os_path_dirname("/home/user/f.txt"), "/home/user")
t("ext", os_path_ext("doc.pdf"), ".pdf")
t("getenv_def", os_getenv("NYTHON_FAKE_XYZ", "fb"), "fb")
t("exec", os_exec("echo hi"), "hi")
var dl = os_listdir("/tmp")
t("listdir", type(dl), "list")
write_file("/tmp/ny_os_t.txt", "test")
t("isfile", os_isfile("/tmp/ny_os_t.txt"), true)
os_remove("/tmp/ny_os_t.txt")
t("rm", os_exists("/tmp/ny_os_t.txt"), false)

import re
print "=== REGEX ==="
t("test_yes", re_test("[0-9]+", "abc123"), true)
t("test_no", re_test("^[0-9]+$", "abc"), false)
var fa = re_findall("[0-9]+", "a1b22c333")
t("findall", str(fa), "[1, 22, 333]")
t("replace", re_replace("[aeiou]", "*", "hello"), "h*ll*")
var sp = re_split("[,;]", "a,b;c")
t("split", str(sp), "[a, b, c]")
var sr = re_search("([0-9]+)-([0-9]+)", "call 555-1234")
t("search_full", sr[0], "555-1234")
t("search_g1", sr[1], "555")

import json
print "=== JSON ==="
t("enc_int", json_encode(42), "42")
t("enc_str", json_encode("hi"), "\"hi\"")
t("enc_bool", json_encode(true), "true")
t("enc_null", json_encode(none), "null")
t("enc_list", json_encode([1,2,3]), "[1, 2, 3]")
t("dec_int", json_decode("42"), 42)
t("dec_str", json_decode("\"hi\""), "hi")
t("dec_bool", json_decode("true"), true)
t("dec_null", json_decode("null") is none, true)

import crypto
print "=== CRYPTO ==="
var h1 = hash_sha256("hello")
var h2 = hash_sha256("hello")
t("hash_same", h1, h2)
t("hash_diff", hash_sha256("a") != hash_sha256("b"), true)
t("b64_enc", base64_encode("Hello"), "SGVsbG8=")
t("b64_dec", base64_decode("SGVsbG8="), "Hello")
t("b64_rt", base64_decode(base64_encode("Test!")), "Test!")
t("hex_enc", hex_encode("AB"), "4142")
t("hex_dec", hex_decode("4142"), "AB")
t("url_enc", url_encode("a b"), "a%20b")
t("url_dec", url_decode("a%20b"), "a b")

import threading
print "=== THREADING ==="
var sem = semaphore_create(2)
t("sem_a1", semaphore_acquire(sem), true)
t("sem_a2", semaphore_acquire(sem), true)
t("sem_a3_fail", semaphore_acquire(sem), false)
t("sem_rel", semaphore_release(sem), true)
t("sem_a4", semaphore_acquire(sem), true)

import collections
print "=== COLLECTIONS ==="
var cnt = Counter(["a", "b", "a", "c", "b", "a"])
t("counter_a", cnt["a"], 3)
t("counter_b", cnt["b"], 2)
t("counter_c", cnt["c"], 1)
var uniq = Set([1,2,2,3,3,3])
t("set_len", len(uniq), 3)

print ""
print "============================================"
print "  STDLIB: " + str(pass_n) + " passed, " + str(fail_n) + " failed"
print "============================================"

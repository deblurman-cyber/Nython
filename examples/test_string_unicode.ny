# test_string_unicode.ny — string builtins must all measure in characters.
#
# len() already counted characters, but string_slice() and string_find() worked
# in bytes. Mixing the two silently corrupted non-ASCII text: a slice could end
# mid-character and produce invalid UTF-8, and slice(s, 0, len(s)) did not
# round-trip. This pins them to the same units.

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

var s = "héllo wörld"
var jp = "日本語テキスト"

print "=== length is characters ==="
check("accented len", len(s), 11)
check("cjk len",      len(jp), 7)

print "=== slice is characters ==="
check("slice accented", string_slice(s, 0, 5), "héllo")
check("slice cjk",      string_slice(jp, 0, 3), "日本語")
check("slice mid",      string_slice(jp, 2, 5), "語テキ")
check("round trip",     string_slice(s, 0, len(s)), s)
check("cjk round trip", string_slice(jp, 0, len(jp)), jp)
check("slice tail",     string_slice(s, 6, len(s)), "wörld")

print "=== find returns a character index ==="
check("find accented", string_find(s, "ö"), 7)
check("find cjk",      string_find(jp, "テ"), 3)
check("find missing",  string_find(s, "zz"), 0 - 1)

print "=== find and slice compose ==="
# This is the pairing that byte/character mixing broke.
var at = string_find(s, "w")
check("compose", string_slice(s, at, len(s)), "wörld")

print "=== ascii unaffected ==="
check("ascii slice", string_slice("abcdef", 1, 4), "bcd")
check("ascii find",  string_find("abcdef", "cd"), 2)

print ""
if failures == 0:
    print "PASS: unicode string checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

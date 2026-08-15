# Test 14: the IDE toolchain bridge executes real code and reports real results.
import "lib/ide_toolchain.ny"

var npass = 0
var nfail = 0
def check(name, got, want):
    if got == want:
        npass = npass + 1
    else:
        nfail = nfail + 1
        print "  FAIL [" + name + "] got=" + str(got) + " want=" + str(want)
def check_true(name, cond):
    check(name, cond, true)

print "=== Test 14: Toolchain ==="
var tc = Toolchain()
check_true("toolchain available", tc.available())
check_true("version reports Nython", string_find(tc.version(), "Nython") >= 0)

# ── real execution ───────────────────────────────────────────────────────────
# The value must be COMPUTED by the compiler, not echoed from source text: 6*7
# appears nowhere in the program as the literal 42.
var r = tc.run("var a = 6\nvar b = 7\nprint(a * b)\n", "m.ny", false)
check("run ok", r.ok, true)
check("run exit", r.exit_code, 0)
check("run output count", r.line_count, 1)
check("run computed value", r.lines[0], "42")

var rv = tc.run("var a = 6\nvar b = 7\nprint(a * b)\n", "m.ny", true)
check("vm run ok", rv.ok, true)
check("vm same answer", rv.lines[0], "42")

# ── failure is reported as failure ───────────────────────────────────────────
var bad = tc.run("var x = 1\nprint(x\nvar y = 2\n", "bad.ny", false)
check("syntax error not ok", bad.ok, false)
check_true("syntax error nonzero exit", bad.exit_code != 0)

var rt = tc.run("print(1/0)\n", "z.ny", false)
check("runtime error not ok", rt.ok, false)
check_true("runtime error mentions exception",
           string_find(string_lower(rt.raw), "zerodivision") >= 0)

# ── diagnostics ──────────────────────────────────────────────────────────────
var ds = tc.diagnose("var x = 1\nprint(x\nvar y = 2\n", "bad.ny")
check("diagnostic count", len(ds), 1)
check("diagnostic severity", ds[0].severity, "error")
check_true("diagnostic has message", len(ds[0].message) > 0)
check("clean file no diagnostics", len(tc.diagnose("var q = 1\nprint(q)\n", "ok.ny")), 0)

# ── inspection modes ─────────────────────────────────────────────────────────
var src = "var n = 5\ndef sq(x):\n    return x * x\nprint(sq(n))\n"

var toks = tc.tokens(src, "t.ny")
check_true("tokens produced", len(toks) > 20)
check("first token value", toks[0][0], "var")
check("first token kind", toks[0][1], "Var")
check("first token line", toks[0][2], "1")

var a = tc.ast(src, "t.ny")
check("ast ok", a.ok, true)
check_true("ast is xml", string_find(a.raw, "<Script") >= 0)
check_true("ast has statements", string_find(a.raw, "<Statements>") >= 0)

var d = tc.disasm(src, "t.ny")
check("disasm ok", d.ok, true)
check_true("disasm has module", string_find(d.raw, "<module>") >= 0)
check_true("disasm has instructions", string_find(d.raw, "LOAD_CONST") >= 0)
check_true("disasm has constants pool", string_find(d.raw, "Constants:") >= 0)

# ── timing is measured, not invented ─────────────────────────────────────────
check_true("elapsed is non-negative", r.ms >= 0)

print "Results: " + str(npass) + " passed, " + str(nfail) + " failed"
if nfail == 0:
    print "=== TEST 14 PASSED ==="
else:
    print "=== TEST 14 FAILED ==="

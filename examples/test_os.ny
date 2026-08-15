# ─────────────────────────────────────────────────────────────────────────────
# test_os.ny — Nython OS Library Test Suite
# Run from: examples/ directory
# ─────────────────────────────────────────────────────────────────────────────
import "lib/os.ny"

var passed = 0
var failed = 0

def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)

def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] expected true, got " + str(val)

def section(name):
    print "  " + name + " ..."

print "=== OS TEST SUITE ==="
print ""

# ─── Path ────────────────────────────────────────────────────────────────────
section("Path")
var p = Path()
assert_eq("basename", p.basename("/home/user/file.ny"), "file.ny")
assert_eq("dirname", p.dirname("/home/user/file.ny"), "/home/user")
assert_eq("extension", p.extension("model.weights.pt"), ".pt")
assert_eq("extension no dot", p.extension("Makefile"), "")
assert_true("exists /tmp", p.exists("/tmp"))
assert_true("not exists /xxx", not p.exists("/nonexistent_path_xyz"))
assert_true("is_dir /tmp", p.is_dir("/tmp"))
assert_true("is_file nope", not p.is_file("/tmp"))

# ─── FileSystem ──────────────────────────────────────────────────────────────
section("FileSystem")
var fs = FileSystem()
var test_path = "/tmp/nython_os_test.txt"
var test_dir = "/tmp/nython_test_dir"

assert_true("write", fs.write(test_path, "Hello Nython!"))
assert_eq("read", fs.read(test_path), "Hello Nython!")
assert_true("exists after write", fs.exists(test_path))
assert_true("is_file", fs.is_file(test_path))

assert_true("append", fs.append(test_path, " World"))
var content = fs.read(test_path)
assert_true("read after append", string_contains(content, "World"))

assert_true("mkdir", fs.mkdir(test_dir))
assert_true("dir exists", fs.exists(test_dir))
assert_true("is_dir", fs.is_dir(test_dir))

var file2 = test_dir + "/test2.txt"
fs.write(file2, "test content")
assert_true("file in dir exists", fs.exists(file2))

var listed = fs.listdir(test_dir)
assert_true("listdir not empty", len(listed) > 0)

fs.delete(file2)
assert_true("deleted", not fs.exists(file2))

fs.delete(test_path)
assert_true("deleted main", not fs.exists(test_path))

# ─── Env ─────────────────────────────────────────────────────────────────────
section("Env")
var env = Env()
var cwd = env.cwd()
assert_true("cwd not empty", len(cwd) > 0)
var home = env.home()
assert_true("home not empty", len(str(home)) > 0)
assert_true("is_linux or windows", env.is_linux() or env.is_windows())
assert_true("platform not empty", len(env.platform()) > 0)

# ─── Results ─────────────────────────────────────────────────────────────────
print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL OS TESTS PASSED ==="
else:
    print "=== SOME OS TESTS FAILED ==="

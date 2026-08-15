# test_vm_builtin_bridge.ny
#
# The bytecode VM implements ~64 natives of its own; the interpreter registers
# 536. Everything else evaluated to none under --vm, so most of the standard
# library was unreachable from a program run on the VM. load_var() now falls
# back to the interpreter's builtin table, converting values between the two
# representations.
#
# Run under BOTH engines — the point is that they agree.

var failures = 0

def check(label, got, want):
    if str(got) == str(want):
        print "  ok   " + label
    else:
        print "  FAIL " + label + "  got=" + str(got) + "  want=" + str(want)
        failures = failures + 1

print "=== scalars across the bridge ==="
check("os_path_join",   os_path_join("/a", "b"), "/a/b")
check("os_path_ext",    os_path_ext("x.ny"), ".ny")
check("os_exists",      os_exists("/tmp"), true)
check("base64 round",   base64_decode(base64_encode("hi")), "hi")
check("hex round",      hex_decode(hex_encode("hi")), "hi")
check("json_encode",    json_encode([1, 2, 3]), "[1, 2, 3]")

print "=== containers across the bridge ==="
# Container returns exercise the Value <-> VMVal conversion in both directions.
var st = fs_stat("/tmp")
check("map: is_dir",    st["is_dir"], true)
check("map: is_file",   st["is_file"], false)

var entries = os_listdir("/tmp")
check("list is a list",  type(entries), "list")
check("list non-empty",  len(entries) > 0, true)

print "=== arguments cross the bridge too ==="
# A list built in the program, passed to an interpreter builtin.
check("json of built list", json_encode([10, 20]), "[10, 20]")
check("path from parts",    os_path_basename(os_path_join("/x/y", "z.ny")), "z.ny")

print ""
if failures == 0:
    print "PASS: builtin bridge checks passed"
else:
    print "FAIL: " + str(failures) + " check(s) failed"

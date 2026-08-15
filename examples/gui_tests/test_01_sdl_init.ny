# Test 01: SDL3 init and version check (no window)
print "=== Test 01: SDL3 Init ==="
var ver = gui_sdl_version()
print "SDL3 version: " + str(ver)
var err = gui_get_error()
print "Error: " + str(err)
print "PASS: SDL3 accessible"

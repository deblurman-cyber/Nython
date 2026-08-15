# Test 08: Window.create() - this is where SDL is first called from gui.ny
print "=== Test 08: Window.create() ==="
import "lib/gui.ny"
var w = Window(640, 480, "Test 08")
print "Calling w.create()..."
var ok = w.create()
print "create() returned: " + str(ok)
var err = gui_get_error()
if err != "" and err != none:
    print "SDL error: " + str(err)
if ok:
    print "PASS: Window created via gui.ny"
    thread_sleep(1000)
    w.destroy()
    print "Window destroyed"
else:
    print "FAIL: Window creation failed"

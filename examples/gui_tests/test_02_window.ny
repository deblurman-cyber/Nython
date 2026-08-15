# Test 02: Create window and destroy
print "=== Test 02: Window Create/Destroy ==="
var h = gui_create_window("Test Window", -1, -1, 400, 300, 0)
print "Handle: " + str(h)
if h != none:
    print "PASS: Window created"
    gui_clear(h, 30, 30, 50, 255)
    gui_present(h)
    thread_sleep(500)
    gui_destroy_window(h)
    print "PASS: Window destroyed"
else:
    print "FAIL: " + str(gui_get_error())

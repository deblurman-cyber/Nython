# Test 03: Event loop for 2 seconds
print "=== Test 03: Event Loop (2s) ==="
var h = gui_create_window("Test 03", -1, -1, 400, 300, 0)
if h == none:
    print "FAIL: " + str(gui_get_error())
else:
    var count = 0
    while count < 120:
        var events = gui_poll_events(h)
        gui_clear(h, 20, 20, 40, 255)
        gui_present(h)
        thread_sleep(16)
        count = count + 1
    gui_destroy_window(h)
    print "PASS: Event loop ran 120 frames"

# Test 04: Draw shapes - no font
print "=== Test 04: Drawing Primitives ==="
var h = gui_create_window("Test 04", -1, -1, 640, 480, 0)
if h == none:
    print "FAIL: " + str(gui_get_error())
else:
    var count = 0
    while count < 60:
        var events = gui_poll_events(h)
        gui_clear(h, 15, 15, 30, 255)
        gui_fill_rect(h, 50, 50, 200, 100,  100, 150, 255, 255)
        gui_draw_rect(h, 50, 50, 200, 100,  255, 255, 255, 128, 2)
        gui_draw_line(h, 0, 0, 640, 480,  255, 100, 100, 255, 2)
        gui_draw_circle(h, 320, 240, 80,  255, 200, 100, 200)
        gui_fill_circle(h, 320, 240, 40,  100, 200, 255, 200)
        gui_present(h)
        thread_sleep(16)
        count = count + 1
    gui_destroy_window(h)
    print "PASS: Drawing primitives"

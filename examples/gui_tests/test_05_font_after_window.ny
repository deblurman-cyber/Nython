# Test 05: Font loaded AFTER window creation (correct order)
print "=== Test 05: Font (after window) ==="
var h = gui_create_window("Test 05", -1, -1, 640, 480, 0)
if h == none:
    print "FAIL: " + str(gui_get_error())
else:
    # Load font AFTER window (TTF is now initialized)
    var font = gui_load_font("sans-serif", 20, 0, 0)
    print "Font handle: " + str(font)
    if font == none:
        print "WARN: Font not loaded (no system font found)"
    else:
        var sz = gui_measure_text(font, "Hello World")
        print "Text size: " + str(sz)
        var count = 0
        while count < 60:
            var events = gui_poll_events(h)
            gui_clear(h, 15, 15, 30, 255)
            if font != none:
                gui_draw_text(h, "Hello World", 100, 200, font, 255, 255, 255, 255)
            gui_present(h)
            thread_sleep(16)
            count = count + 1
    gui_destroy_window(h)
    print "PASS: Font after window"

# Test 05b: Isolate gui_draw_text specifically
# If this crashes, the problem is in SDL text rendering
# If it shows text, the bug was the SDL_WINDOW_OPENGL conflict
print "=== Test 05b: gui_draw_text isolation ==="

var h = gui_create_window("Test 05b - Text", -1, -1, 640, 480, 0)
if h == none:
    print "FAIL: " + str(gui_get_error())
else:
    print "Window OK"
    var font = gui_load_font("sans-serif", 24, 0, 0)
    print "Font: " + str(font)

    # Render ONE frame only, then check
    var events = gui_poll_events(h)
    print "poll OK"
    gui_clear(h, 20, 20, 60, 255)
    print "clear OK"

    if font != none:
        gui_draw_text(h, "Hello Nython!", 100, 200, font, 255, 255, 100, 255)
        print "draw_text OK"

    gui_present(h)
    print "present OK"

    # Wait 3 seconds so user can see the window
    thread_sleep(3000)
    gui_destroy_window(h)
    print "PASS: Test 05b complete"

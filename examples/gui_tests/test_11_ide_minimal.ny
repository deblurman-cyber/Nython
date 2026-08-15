# Test 11: Minimal IDE simulation — verifies colored rendering works
import "lib/gui.ny"
print "=== Test 11: Minimal IDE Draw ==="
print "You should see a dark blue window with colored text and shapes."
print "If the window is WHITE, the renderer has a color issue."

var w = Window(800, 600, "Test 11 - Renderer Color Check")
var frames = 0
var font = none

def callback(renderer, event):
    frames = frames + 1

    if frames == 1:
        font = Font("sans-serif", 18, false, false)
        font.load()
        print "Font: " + str(font._handle != none)

    renderer.clear(Color(16, 18, 32, 255))

    # Colored rectangles — should NOT be white
    renderer.fill_rect(Rect(50, 50, 200, 100),   Color(99, 102, 241, 255))   # indigo
    renderer.fill_rect(Rect(270, 50, 200, 100),  Color(74, 222, 128, 255))   # green
    renderer.fill_rect(Rect(490, 50, 200, 100),  Color(248, 113, 113, 255))  # red
    renderer.fill_rounded_rect(Rect(50, 180, 680, 60), Color(30, 32, 60, 255), 8)
    renderer.draw_rounded_rect(Rect(50, 180, 680, 60), Color(99, 102, 241, 128), 8, 2)

    if font != none and font._handle != none:
        renderer.draw_text("Direct3D/Metal/OpenGL rendering test", 70, 196, font, Color(200, 200, 255, 255))
        renderer.draw_text("Frame: " + str(frames), 50, 270, font, Color(180, 220, 180, 255))

    renderer.present()

    if frames >= 120:
        print "PASS: 120 frames rendered"
        w.running = false

w.run(callback)
print "Window closed. Frames: " + str(frames)

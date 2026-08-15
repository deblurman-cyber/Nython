# Test 10: Font loading inside Window.run() context
print "=== Test 10: Font in run() ==="
import "lib/gui.ny"
var w = Window(640, 480, "Test 10")
var frames = 0
var f = none

def callback(renderer, event):
    frames = frames + 1
    # Load font on first frame (SDL/TTF is initialized by now)
    if frames == 1:
        f = Font("sans-serif", 18, false, false)
        f.load()
        print "Font loaded: " + str(f._handle != none)
    renderer.clear(Color(20, 20, 40, 255))
    if f != none and f._handle != none:
        renderer.draw_text("Hello NythonIDE!", 50, 200, f, Color(255, 255, 255, 255))
    renderer.present()
    if frames >= 60:
        w.running = false

w.run(callback)
print "PASS: Font rendering " + str(frames) + " frames"

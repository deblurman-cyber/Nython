# Test 09: Window.run() with 60-frame callback then exit
print "=== Test 09: Window.run() minimal ==="
import "lib/gui.ny"
var w = Window(640, 480, "Test 09")
var frames = 0

def callback(renderer, event):
    frames = frames + 1
    renderer.clear(Color(20, 20, 40, 255))
    renderer.fill_rect(Rect(100, 100, 200, 100), Color(100, 150, 255, 255))
    renderer.present()
    if frames >= 60:
        w.running = false

w.run(callback)
print "PASS: run() completed after " + str(frames) + " frames"

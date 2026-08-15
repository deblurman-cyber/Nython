# Test 07: Create Window class object WITHOUT calling run()
print "=== Test 07: Window class object ==="
import "lib/gui.ny"
print "Creating Window(400, 300, 'Test')..."
var w = Window(400, 300, "Test 07")
print "width=" + str(w.width) + " height=" + str(w.height)
print "handle=" + str(w._handle)
print "PASS: Window class constructed (no SDL call yet)"

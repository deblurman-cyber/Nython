try:
    var x = 10 / 0
except e:
    print "Error: " + e

try:
    assert false
except e:
    print "Assert: " + e

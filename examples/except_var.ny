try:
    var x = 10 / 0
except e:
    print "Error: " + e

try:
    assert 1 == 2
except e:
    print "Assert: " + e

try:
    var lst = [1, 2, 3]
    var x = lst[100]
    print x
except e:
    print "Index: " + e

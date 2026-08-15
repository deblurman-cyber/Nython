try:
    var lst = [1, 2, 3]
    print lst[10]
except:
    print "index error caught"

try:
    var x = undefined_var
except:
    print "undefined caught"

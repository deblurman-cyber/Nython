var nums = [1, 2, 3, 4, 5]
var doubled = []
for n in nums:
    doubled.append(n * 2)
print doubled

for i in range(5):
    if i % 2 == 0:
        continue
    print i

var m = {"x": 10, "y": 20, "z": 30}
print m.keys()
print m.values()

print str(42)
print int("123")
print float("3.14")

print "hello world".split(" ").join("-")

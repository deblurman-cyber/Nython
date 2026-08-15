var fruits = ["apple", "banana", "cherry"]
print enumerate(fruits)
for pair in enumerate(fruits):
    print str(pair[0]) + ": " + pair[1]

print ""
var names = ["Alice", "Bob", "Charlie"]
var scores = [95, 87, 92]
print zip(names, scores)
for pair in zip(names, scores):
    print pair[0] + " scored " + str(pair[1])

print ""
print sorted([5, 2, 8, 1, 9, 3])
print reversed([1, 2, 3, 4, 5])

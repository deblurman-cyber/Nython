var nums = [5, 3, 8, 1, 9, 2, 7, 4, 6]
print nums.sort()
print nums.slice(2, 5)
print nums.indexOf(8)
print nums.join(" -> ")

print [1,2,3,4,5].reduce(lambda a, b: a + b, 0)

var words = ["hello", "world"]
words.forEach(lambda w: print(w.upper()))

var nums = [1, 2, 3, 4, 5]
print nums

def double(x):
    return x * 2
var doubled = nums.map(double)
print doubled

def is_even(x):
    return x % 2 == 0
var evens = nums.filter(is_even)
print evens

var lst = [5, 4, 3, 2, 1]
print lst.reverse()

print lst.contains(3)
print lst.contains(99)

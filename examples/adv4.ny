def map_reduce(lst, mapper, reducer, initial):
    var result = initial
    for item in lst:
        var mapped = mapper(item)
        result = reducer(result, mapped)
    return result

var nums = [1, 2, 3, 4, 5]
def sq(x):
    return x * x
def add(a, b):
    return a + b
print map_reduce(nums, sq, add, 0)

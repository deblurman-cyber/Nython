var nums = [1, 2, 3, 4, 5]
print nums.filter(lambda x: x > 2)
print nums.map(lambda x: x * 10)
print nums.filter(lambda x: x > 2).map(lambda x: x * 10)

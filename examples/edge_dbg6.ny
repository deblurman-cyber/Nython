print 111
var pipeline = [1,2,3,4,5,6,7,8,9,10].filter(lambda x: x % 2 == 0).map(lambda x: x * x).reduce(lambda a, b: a + b, 0)
print pipeline
print 222

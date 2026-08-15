var x = 42
var y = 10
var z = x + y
print z
print 100 - 50
print 3 * 7
print true
print false

if true:
    print 1

while false:
    print 999

def add(a, b):
    return a + b

class Point:
    def init(self, x, y):
        self.x = x
        self.y = y

for i in range(3):
    print i

enum Color:
    RED = 0,
    GREEN = 1,
    BLUE = 2,

switch x:
    case 42:
        print 42
    default:
        print 0

try:
    print 1
except:
    print 0

import math
from os import path

namespace utils:
    def helper():
        pass

lambda x: x + 1

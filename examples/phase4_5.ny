import math
import io

def benchmark(name, func, n):
    var start = 0
    func(n)
    return name + " completed"

def fib_iter(n):
    var a = 0
    var b = 1
    for i in range(n):
        var temp = a + b
        a = b
        b = temp
    return a

print fib_iter(50)
print benchmark("fib_iter", fib_iter, 30)

write_file("/tmp/nython_bench.txt", "Benchmark results:\n" + str(fib_iter(30)) + "\n")
print read_file("/tmp/nython_bench.txt")

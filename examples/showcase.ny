import nytorch
import net
import io
import crypto
import math
import collections

# Data generation
print "=== DATA PIPELINE ==="
var X = map(lambda i: sin(i * 0.5) * 10, range(50))
var Y = map(lambda i: 1 if sin(i * 0.5) > 0 else 0, range(50))
print "Samples:", len(X)
print "Positive:", sum(Y), "Negative:", len(Y) - sum(Y)

# Normalize
var xmin = min(X)
var xmax = max(X)
var X_norm = map(lambda v: (v - xmin) / (xmax - xmin), X)

# Logistic regression
print ""
print "=== LOGISTIC REGRESSION ==="
var w = 0.0
var b = 0.0
var lr = 0.5

var epoch = 0
while epoch < 30:
    var loss = 0.0
    var i = 0
    while i < len(X_norm):
        var pred = sigmoid(w * X_norm[i] + b)
        var err = pred - Y[i]
        loss = loss + err * err
        w = w - lr * err * pred * (1 - pred) * X_norm[i]
        b = b - lr * err * pred * (1 - pred)
        i = i + 1
    if epoch % 10 == 0:
        print "  epoch " + str(epoch) + " loss=" + str(loss / len(X))
    epoch = epoch + 1

var correct = 0
var j = 0
while j < len(X_norm):
    var pred = sigmoid(w * X_norm[j] + b)
    var label = 1 if pred > 0.5 else 0
    if label == Y[j]:
        correct = correct + 1
    j = j + 1
print "Accuracy:", correct, "/", len(X)

# RPN Calculator
print ""
print "=== RPN CALCULATOR ==="
class Stack:
    def init(self):
        self.items = []
    def push(self, v):
        self.items.append(v)
        return self
    def pop_val(self):
        return self.items.pop()
    def peek(self):
        return self.items[-1]

def rpn(tokens):
    var s = Stack()
    for tok in tokens:
        if is_int(tok) or is_float(tok):
            s.push(tok)
        else:
            var bv = s.pop_val()
            var av = s.pop_val()
            if tok == "+": s.push(av + bv)
            if tok == "*": s.push(av * bv)
            if tok == "-": s.push(av - bv)
    return s.peek()

print "3 4 + 2 * =", rpn([3, 4, "+", 2, "*"])
print "5 3 - 4 * =", rpn([5, 3, "-", 4, "*"])

# Tensor operations
print ""
print "=== NYTORCH ==="
var t = tensor([1.0, 2.0, 3.0, 4.0, 5.0])
print "sum:", tensor_sum(t)
print "mean:", tensor_mean(t)
print "norm:", norm(t)
print "gradient:", numerical_gradient(lambda x: tensor_sum(tensor_pow(x, 2)), t)

var A = tensor([1.0, 2.0, 3.0, 4.0])
var B = tensor([5.0, 6.0, 7.0, 8.0])
print "matmul 2x2:", matmul(A, B, 2, 2, 2)

# Security
print ""
print "=== CRYPTO ==="
print "SHA256:", sha256("nython")
print "Base64:", base64_encode("Hello!")

# File I/O
print ""
print "=== FILE I/O ==="
write("/tmp/ny_show.txt", "showcase")
print "Written:", cat("/tmp/ny_show.txt")
writelines("/tmp/ny_lines.txt", ["alpha", "beta", "gamma"])
print "Lines:", readlines("/tmp/ny_lines.txt")

# Network
print ""
print "=== NETWORK ==="
print "DNS:", dns_resolve("localhost")
var srv = socket_tcp()
socket_setsockopt(srv, "reuseaddr", 1)
socket_bind(srv, 59991)
socket_listen(srv, 1)
var cli = socket_tcp()
socket_connect(cli, "127.0.0.1", 59991)
var conn = socket_accept(srv)
socket_send(cli, "SHOWCASE")
print "TCP:", socket_recv(conn, 1024)
socket_close(cli)
socket_close(conn)
socket_close(srv)

# Collections
print ""
print "=== COLLECTIONS ==="
var words = "the quick brown fox jumps over the lazy dog the fox".split(" ")
var freq = Counter(words)
print "the:", freq["the"]
print "unique:", len(Set(words))

# Functional
print ""
print "=== FUNCTIONAL ==="
print "Sum of even squares:", reduce(lambda a, b: a + b, map(lambda x: x * x, filter(lambda x: x % 2 == 0, range(1, 11))))
print "Flatten:", flatten([[1, 2], [3, 4], [5, 6]])
print "Nested comp:", [x * y for x in range(1, 4) for y in range(1, 4)]

print ""
print "============================"
print "  Nython v0.3.0 Complete"
print "============================"

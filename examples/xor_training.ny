# XOR Neural Network Training in Nython
# Demonstrates full backpropagation with NyTorch
import nytorch

var w1 = tensor_scale(randn_tensor(8), 0.5)
var b1 = zeros(4)
var w2 = tensor_scale(randn_tensor(4), 0.5)
var b2 = zeros(1)

var X = [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]
var Y = [0.0, 1.0, 1.0, 0.0]
var lr = 1.0

var epoch = 0
while epoch < 500:
    var total_loss = 0.0
    var i = 0
    while i < 4:
        var x = tensor(X[i])
        var z1 = tensor_add(matmul(x, w1, 1, 2, 4), b1)
        var h = tensor_apply(z1, lambda v: sigmoid(v))
        var z2 = tensor_add(matmul(h, w2, 1, 4, 1), b2)
        var o = tensor_apply(z2, lambda v: sigmoid(v))
        var pred = o[0]
        var error = pred - Y[i]
        total_loss = total_loss + error * error
        var d_out = error * pred * (1 - pred)
        w2 = tensor_sub(w2, tensor_scale(h, lr * d_out))
        b2 = tensor_sub(b2, tensor_scale(tensor([1.0]), lr * d_out))
        var d_hidden = tensor_mul(tensor_scale(w2, d_out), tensor_mul(h, tensor_sub(ones(4), h)))
        var k = 0
        while k < 4:
            var j = 0
            while j < 2:
                w1 = tensor_sub(w1, tensor_scale(one_hot(j*4+k, 8), lr * d_hidden[k] * x[j]))
                j = j + 1
            b1 = tensor_sub(b1, tensor_scale(one_hot(k, 4), lr * d_hidden[k]))
            k = k + 1
        i = i + 1
    if epoch % 100 == 0:
        print "epoch " + str(epoch) + " loss=" + str(total_loss / 4)
    epoch = epoch + 1

print "\nXOR Results:"
var j = 0
while j < 4:
    var x = tensor(X[j])
    var h = tensor_apply(tensor_add(matmul(x, w1, 1, 2, 4), b1), lambda v: sigmoid(v))
    var o = tensor_apply(tensor_add(matmul(h, w2, 1, 4, 1), b2), lambda v: sigmoid(v))
    var label = 1 if o[0] > 0.5 else 0
    print "  " + str(X[j]) + " -> " + str(label) + " (confidence: " + str(o[0]) + ")"
    j = j + 1

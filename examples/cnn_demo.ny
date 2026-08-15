import nytorch

# ═══════════════════════════════════════
# 1D CNN for Pattern Detection
# ═══════════════════════════════════════

print "=== 1D CNN PATTERN DETECTION ==="

# Signal: contains a spike pattern
var signal = tensor([0.0, 0.0, 0.0, 1.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0, 0.0, 0.0])
print "Input signal (" + str(len(signal)) + " samples)"

# Layer 1: Edge detection kernel
var kernel1 = tensor([1.0, 0.0, -1.0])
var conv_out = conv1d(signal, kernel1)
print "Conv1 (edge detect):", conv_out

# Layer 2: ReLU activation
var relu_out = tensor_apply(conv_out, lambda x: relu(x))
print "ReLU:", relu_out

# Layer 3: Max pooling
var pool_out = max_pool1d(relu_out, 2)
print "MaxPool(2):", pool_out

# Batch normalize
var normed = batch_norm(pool_out)
print "BatchNorm:", normed

# Classification: sum of features
var score = tensor_sum(pool_out)
print "Detection score:", score
print "Spike detected:", score > 1.0

# ═══════════════════════════════════════
# Training a Simple CNN
# ═══════════════════════════════════════

print ""
print "=== CNN TRAINING ==="

# Train kernel to detect rising edges
var samples = [
    [tensor([0.0, 0.0, 1.0, 2.0, 2.0]), 1.0],
    [tensor([2.0, 2.0, 1.0, 0.0, 0.0]), 0.0],
    [tensor([0.0, 1.0, 2.0, 3.0, 3.0]), 1.0],
    [tensor([3.0, 2.0, 1.0, 0.0, 0.0]), 0.0],
    [tensor([0.0, 0.0, 0.0, 1.0, 2.0]), 1.0],
    [tensor([2.0, 1.0, 0.0, 0.0, 0.0]), 0.0]
]

var kern = tensor_scale(randn_tensor(3), 0.3)
var lr = 0.1

var epoch = 0
while epoch < 50:
    var total_loss = 0.0
    for sample in samples:
        var x = sample[0]
        var target = sample[1]
        var features = conv1d(x, kern)
        features = tensor_apply(features, lambda v: relu(v))
        var pooled = max_pool1d(features, len(features))
        var pred = sigmoid(pooled[0])
        var error = pred - target
        total_loss = total_loss + error * error
        
        # Simple gradient update on kernel
        var grad = numerical_gradient(lambda k: sigmoid(max_pool1d(tensor_apply(conv1d(x, k), lambda v: relu(v)), 3)[0]) - target, kern)
        kern = tensor_sub(kern, tensor_scale(grad, lr * 2 * error))
    
    if epoch % 10 == 0:
        print "  epoch " + str(epoch) + " loss=" + str(total_loss / len(samples))
    epoch = epoch + 1

print ""
print "Learned kernel:", kern
print ""
print "Predictions:"
for sample in samples:
    var x = sample[0]
    var features = conv1d(x, kern)
    features = tensor_apply(features, lambda v: relu(v))
    var pooled = max_pool1d(features, len(features))
    var pred = sigmoid(pooled[0])
    var label = 1 if pred > 0.5 else 0
    print "  " + str(x) + " -> " + str(label) + " (target " + str(int(sample[1])) + ")"

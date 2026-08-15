# =========================================================
# NyTorch Sentiment Classifier
# A complete ML pipeline: tokenize -> embed -> classify
# =========================================================
import nytorch
import math

print "=== NyTorch Sentiment Classifier ==="
print ""

# 1. Training data
var texts = [
    "great movie loved it",
    "amazing film wonderful acting",
    "best movie ever seen",
    "terrible waste of time",
    "horrible movie avoid it",
    "worst film ever made"
]
var labels = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0]

# 2. Build vocabulary
print "Building vocabulary..."
var vocab = {}
var next_id = 0
for text in texts:
    var words = text.split(" ")
    for word in words:
        if not (word in vocab):
            vocab[word] = next_id
            next_id = next_id + 1
print "  Vocab size:", next_id

# 3. Tokenize
def tokenize(text_str):
    var result = []
    var words = text_str.split(" ")
    for word in words:
        result.append(vocab.get(word, 0))
    return result

# 4. Simple bag-of-words encoding
def encode(text_str):
    var vec = zeros(next_id)
    var tokens = tokenize(text_str)
    for tok in tokens:
        vec = tensor_add(vec, one_hot(tok, next_id))
    return vec

# 5. Initialize model weights
var w = tensor_scale(randn_tensor(next_id), 0.1)
var bias = 0.0
var lr = 0.1

# 6. Training loop
print "Training..."
var epoch = 0
while epoch < 50:
    var total_loss = 0.0
    var i = 0
    while i < len(texts):
        var x = encode(texts[i])
        var z = tensor_dot(x, w) + bias
        var pred = sigmoid(z)
        var err = pred - labels[i]
        total_loss = total_loss + err * err

        # Gradient descent
        var grad = tensor_scale(x, 2 * err * pred * (1 - pred))
        w = tensor_sub(w, tensor_scale(grad, lr))
        bias = bias - lr * 2 * err * pred * (1 - pred)
        i = i + 1

    if epoch % 10 == 0:
        print "  epoch " + str(epoch) + " loss=" + str(total_loss / len(texts))
    epoch = epoch + 1

# 7. Evaluate
print ""
print "Training Results:"
var correct = 0
var i = 0
while i < len(texts):
    var x = encode(texts[i])
    var pred = sigmoid(tensor_dot(x, w) + bias)
    var label = 1 if pred > 0.5 else 0
    var sentiment = "positive" if label == 1 else "negative"
    if label == labels[i]:
        correct = correct + 1
    print "  \"" + texts[i] + "\" -> " + sentiment + " (" + str(pred) + ")"
    i = i + 1
print "Accuracy:", correct, "/", len(texts)

# 8. Test on new sentences
print ""
print "Predictions on new text:"
var test_texts = ["great acting loved", "terrible horrible waste", "amazing wonderful"]
for test_text in test_texts:
    var x = encode(test_text)
    var pred = sigmoid(tensor_dot(x, w) + bias)
    var sentiment = "positive" if pred > 0.5 else "negative"
    print "  \"" + test_text + "\" -> " + sentiment + " (" + str(pred) + ")"

print ""
print "=== Classifier Complete ==="

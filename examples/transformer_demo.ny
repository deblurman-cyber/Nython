import nytorch

# ═══════════════════════════════════════
# Mini Transformer: Text Classification
# ═══════════════════════════════════════

print "=== MINI TRANSFORMER ==="

# Vocabulary: 8 words, embedding dim: 4
var vocab_size = 8
var embed_dim = 4

# Random embedding table
var embed_table = randn_tensor(vocab_size * embed_dim)
embed_table = tensor_scale(embed_table, 0.3)

# Encode a "sentence" as word indices
var sentence1 = [0, 1, 2, 3]
var sentence2 = [4, 5, 6, 7]

# Lookup embeddings
var emb1 = embedding(embed_table, sentence1, embed_dim)
var emb2 = embedding(embed_table, sentence2, embed_dim)

print "Sentence 1 embeddings: " + str(len(emb1)) + " values"
print "Sentence 2 embeddings: " + str(len(emb2)) + " values"

# Self-attention on sentence 1
var seq_len = len(sentence1)
print ""
print "Self-attention on sentence 1:"
var q_idx = 0
while q_idx < seq_len:
    var query = tensor_slice(emb1, q_idx * embed_dim, (q_idx + 1) * embed_dim)
    var attn_out = attention(query, emb1, emb1, embed_dim)
    print "  Token " + str(q_idx) + " -> " + str(attn_out)
    q_idx = q_idx + 1

# Cosine similarity between sentences (mean pooling)
var mean1 = zeros(embed_dim)
var mean2 = zeros(embed_dim)
var i = 0
while i < seq_len:
    var t1 = tensor_slice(emb1, i * embed_dim, (i + 1) * embed_dim)
    var t2 = tensor_slice(emb2, i * embed_dim, (i + 1) * embed_dim)
    mean1 = tensor_add(mean1, t1)
    mean2 = tensor_add(mean2, t2)
    i = i + 1
mean1 = tensor_scale(mean1, 1.0 / seq_len)
mean2 = tensor_scale(mean2, 1.0 / seq_len)

print ""
print "Sentence similarity:", cos_sim(mean1, mean2)

# Classification head: mean_pool -> linear -> sigmoid
var cls_weights = tensor_scale(randn_tensor(embed_dim), 0.5)
var cls_bias = 0.0

def classify(emb_flat, seq_l):
    var pooled = zeros(embed_dim)
    var j = 0
    while j < seq_l:
        var tok = tensor_slice(emb_flat, j * embed_dim, (j + 1) * embed_dim)
        pooled = tensor_add(pooled, tok)
        j = j + 1
    pooled = tensor_scale(pooled, 1.0 / seq_l)
    var logit = tensor_dot(pooled, cls_weights) + cls_bias
    return sigmoid(logit)

print ""
print "Classification:"
print "  Sentence 1 prob:", classify(emb1, seq_len)
print "  Sentence 2 prob:", classify(emb2, seq_len)
print ""
print "Transformer demo complete"

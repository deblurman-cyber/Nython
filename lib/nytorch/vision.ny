# ============================================================
# NyTorch v3.0 -- Part 11: Vision, NLP, Signal Processing
# ============================================================
# Classes 161-185:
#   ImageTensor, ImageAugmentor, FeatureExtractor,
#   ObjectDetector, ClassificationHead, AnchorBox,
#   Vocabulary, Tokenizer, TextEncoder, NGramLM,
#   BagOfWords, TFIDFVectorizer, SentenceEmbedder,
#   SignalProcessor, AudioFeatures, TimeSeriesWindow,
#   TimeSeriesForecaster, AnomalyDetector, ChangeDetector,
#   StatisticsTracker, CorrelationAnalyzer,
#   DataNormalizer, DataAugmentor, Preprocessor, DataSplitter
# ============================================================

import nytorch

# -----------------------------------------
# 161. ImageTensor  (H x W x C flat tensor)
# -----------------------------------------
class ImageTensor:
    def __init__(self, height, width, channels):
        self.H = height
        self.W = width
        self.C = channels
        self.data = tensor_zeros([height * width * channels])
        self.normalized = false

    def load_flat(self, flat_list):
        self.data = tensor(flat_list)
        return self

    def pixel(self, r, c, ch):
        var idx = (r * self.W + c) * self.C + ch
        return tensor2d_get(self.data, 0, idx, self.H * self.W * self.C)

    def set_pixel(self, r, c, ch, val):
        var idx = (r * self.W + c) * self.C + ch
        tensor2d_set(self.data, 0, idx, self.H * self.W * self.C, val)
        return self

    def to_grayscale(self):
        var n = self.H * self.W
        var gray_data = []
        var i = 0
        while i < n:
            var base = i * self.C
            var r_val = tensor2d_get(self.data, 0, base, n * self.C)
            var g_val = tensor2d_get(self.data, 0, base + 1, n * self.C)
            var b_val = tensor2d_get(self.data, 0, base + 2, n * self.C)
            var gray = 0.299 * r_val + 0.587 * g_val + 0.114 * b_val
            var gray_data = gray_data + [gray]
            var i = i + 1
        var result = ImageTensor(self.H, self.W, 1)
        result.data = tensor(gray_data)
        return result

    def normalize_01(self):
        self.data = tensor_normalize(self.data)
        self.normalized = true
        return self

    def flatten(self):
        return self.data

    def size(self):
        return self.H * self.W * self.C

    def shape(self):
        return str(self.H) + "x" + str(self.W) + "x" + str(self.C)

# -----------------------------------------
# 162. ImageAugmentor
# -----------------------------------------
class ImageAugmentor:
    def __init__(self, seed):
        self.seed = seed
        self.flip_prob = 0.5
        self.noise_std = 0.02
        self.scale_range = [0.8, 1.2]
        self.ops_applied = 0

    def set_flip_prob(self, p):
        self.flip_prob = p
        return self

    def set_noise(self, std_val):
        self.noise_std = std_val
        return self

    def random_flip(self, img):
        var r = random_float(0.0, 1.0)
        if r < self.flip_prob:
            self.ops_applied = self.ops_applied + 1
            var flipped = ImageTensor(img.H, img.W, img.C)
            var row = 0
            while row < img.H:
                var col = 0
                while col < img.W:
                    var ch = 0
                    while ch < img.C:
                        var v = img.pixel(row, img.W - 1 - col, ch)
                        flipped.set_pixel(row, col, ch, v)
                        var ch = ch + 1
                    var col = col + 1
                var row = row + 1
            return flipped
        return img

    def add_noise(self, img):
        var noise = tensor_randn([img.size()])
        var std_v = self.noise_std
        var scaled = tensor_scale(noise, std_v)
        var noisy_data = tensor_add(img.data, scaled)
        var result = ImageTensor(img.H, img.W, img.C)
        result.data = noisy_data
        self.ops_applied = self.ops_applied + 1
        return result

    def random_scale(self, tensor_in):
        var lo = self.scale_range[0]
        var hi = self.scale_range[1]
        var s = random_float(lo, hi)
        self.ops_applied = self.ops_applied + 1
        return tensor_scale(tensor_in, s)

    def cutout(self, img, size):
        var r_start = random_int(0, img.H - size)
        var c_start = random_int(0, img.W - size)
        var result = ImageTensor(img.H, img.W, img.C)
        result.data = img.data
        var r = r_start
        while r < r_start + size:
            var c = c_start
            while c < c_start + size:
                var ch = 0
                while ch < img.C:
                    result.set_pixel(r, c, ch, 0.0)
                    var ch = ch + 1
                var c = c + 1
            var r = r + 1
        self.ops_applied = self.ops_applied + 1
        return result

# -----------------------------------------
# 163. FeatureExtractor
# -----------------------------------------
class FeatureExtractor:
    def __init__(self, name, input_dim, feature_dim):
        self.name = name
        self.input_dim = input_dim
        self.feature_dim = feature_dim
        self.w1 = tensor_randn([input_dim * feature_dim])
        self.b1 = tensor_zeros([feature_dim])
        self.trained = false

    def extract(self, x):
        var loc_w = self.w1
        var loc_b = self.b1
        var h = tensor_matmul(x, loc_w)
        var out = tensor_add(h, loc_b)
        return out

    def extract_batch(self, tensors):
        var features = []
        var i = 0
        var n = len(tensors)
        while i < n:
            var features = features + [self.extract(tensors[i])]
            var i = i + 1
        return features

    def cosine_distance(self, a, b):
        return tensor_cosine_sim(a, b)

    def euclidean_distance(self, a, b):
        var diff = tensor_sub(a, b)
        var loc_diff = diff
        var sq = tensor_mul(loc_diff, loc_diff)
        return tensor_sum(sq)

    def top_k_similar(self, query, gallery, k):
        var scores = []
        var i = 0
        var n = len(gallery)
        while i < n:
            var s = self.cosine_distance(query, gallery[i])
            var scores = scores + [{"score": s, "idx": i}]
            var i = i + 1
        return scores

# -----------------------------------------
# 164. ClassificationHead
# -----------------------------------------
class ClassificationHead:
    def __init__(self, in_dim, num_classes):
        self.in_dim = in_dim
        self.num_classes = num_classes
        self.w = tensor_randn([in_dim * num_classes])
        self.b = tensor_zeros([num_classes])

    def forward(self, features):
        var loc_w = self.w
        var loc_b = self.b
        var logits = tensor_add(tensor_matmul(features, loc_w), loc_b)
        return logits

    def predict(self, features):
        var logits = self.forward(features)
        return tensor_argmax(logits)

    def predict_proba(self, features):
        var logits = self.forward(features)
        return softmax(logits)

    def top_k(self, features, k):
        var logits = self.forward(features)
        var probs = softmax(logits)
        return tensor_topk(probs, k)

# -----------------------------------------
# 165. AnchorBox  (object detection helpers)
# -----------------------------------------
class AnchorBox:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h

    def iou(self, other):
        var x1 = max(self.x, other.x)
        var y1 = max(self.y, other.y)
        var x2 = min(self.x + self.w, other.x + other.w)
        var y2 = min(self.y + self.h, other.y + other.h)
        if x2 <= x1:
            return 0.0
        if y2 <= y1:
            return 0.0
        var inter = (x2 - x1) * (y2 - y1)
        var union_area = self.w * self.h + other.w * other.h - inter
        if union_area <= 0.0:
            return 0.0
        return inter / union_area

    def area(self):
        return self.w * self.h

    def center(self):
        return [self.x + self.w / 2.0, self.y + self.h / 2.0]

    def scale(self, factor):
        var cx = self.x + self.w / 2.0
        var cy = self.y + self.h / 2.0
        var nw = self.w * factor
        var nh = self.h * factor
        return AnchorBox(cx - nw / 2.0, cy - nh / 2.0, nw, nh)

    def describe(self):
        return "box[" + str(self.x) + "," + str(self.y) + "," + str(self.w) + "x" + str(self.h) + "]"

# -----------------------------------------
# 166. Vocabulary
# -----------------------------------------
class Vocabulary:
    def __init__(self, name):
        self.name = name
        self.word2id = {}
        self.id2word = []
        self.counts = {}
        self.size = 0
        self.add_token("<PAD>")
        self.add_token("<UNK>")
        self.add_token("<BOS>")
        self.add_token("<EOS>")

    def add_token(self, token):
        if self.word2id[token] == none:
            self.word2id[token] = self.size
            self.id2word = self.id2word + [token]
            self.counts[token] = 0
            self.size = self.size + 1
        return self.word2id[token]

    def add_from_tokens(self, tokens):
        var i = 0
        var n = len(tokens)
        while i < n:
            var t = tokens[i]
            var existing_count = self.counts[t]
            if existing_count == none:
                self.add_token(t)
                self.counts[t] = 1
            else:
                self.counts[t] = existing_count + 1
            var i = i + 1
        return self

    def encode(self, token):
        var id_val = self.word2id[token]
        if id_val == none:
            return 1
        return id_val

    def decode(self, id_val):
        if id_val < 0:
            return "<UNK>"
        if id_val >= len(self.id2word):
            return "<UNK>"
        return self.id2word[id_val]

    def encode_sequence(self, tokens):
        var ids = []
        var i = 0
        var n = len(tokens)
        while i < n:
            var ids = ids + [self.encode(tokens[i])]
            var i = i + 1
        return ids

    def to_tensor(self, tokens):
        var ids = self.encode_sequence(tokens)
        return tensor(ids)

    def top_k_frequent(self, k):
        var pairs = []
        var i = 0
        var n = len(self.id2word)
        while i < n:
            var w = self.id2word[i]
            var c = self.counts[w]
            if c == none:
                var c = 0
            var pairs = pairs + [[c, w]]
            var i = i + 1
        return pairs

# -----------------------------------------
# 167. Tokenizer
# -----------------------------------------
class Tokenizer:
    def __init__(self, vocab, max_len):
        self.vocab = vocab
        self.max_len = max_len
        self.pad_id = 0
        self.unk_id = 1
        self.bos_id = 2
        self.eos_id = 3

    def tokenize(self, text):
        return text_tokenize(text, true)

    def encode(self, text):
        var tokens = self.tokenize(text)
        var ids = [self.bos_id]
        var i = 0
        var n = len(tokens)
        while i < n:
            var ids = ids + [self.vocab.encode(tokens[i])]
            var i = i + 1
        ids = ids + [self.eos_id]
        var ml = self.max_len
        var cur_len = len(ids)
        while cur_len < ml:
            ids = ids + [self.pad_id]
            var cur_len = cur_len + 1
        if cur_len > ml:
            ids = ids[:ml]
        return ids

    def decode(self, ids):
        var tokens = []
        var i = 0
        var n = len(ids)
        while i < n:
            var w = self.vocab.decode(ids[i])
            if w != "<PAD>":
                if w != "<BOS>":
                    if w != "<EOS>":
                        var tokens = tokens + [w]
            var i = i + 1
        return tokens

    def encode_batch(self, texts):
        var result = []
        var i = 0
        var n = len(texts)
        while i < n:
            var result = result + [self.encode(texts[i])]
            var i = i + 1
        return result

# -----------------------------------------
# 168. TextEncoder  (word embeddings)
# -----------------------------------------
class TextEncoder:
    def __init__(self, vocab_size, embed_dim, max_len):
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.max_len = max_len
        self.embed_table = tensor_randn([vocab_size * embed_dim])
        self.pos_enc = tensor_randn([max_len * embed_dim])

    def embed_token(self, token_id):
        var start = token_id * self.embed_dim
        return tensor_slice(self.embed_table, start, start + self.embed_dim)

    def encode_ids(self, ids):
        var n = len(ids)
        var result = tensor_zeros([n * self.embed_dim])
        var i = 0
        while i < n:
            var tok_id = ids[i]
            var emb = self.embed_token(tok_id)
            var pos_start = i * self.embed_dim
            var pos_emb = tensor_slice(self.pos_enc, pos_start, pos_start + self.embed_dim)
            var combined = tensor_add(emb, pos_emb)
            var j = 0
            var dim = self.embed_dim
            while j < dim:
                var val = tensor_slice(combined, j, j + 1)
                tensor2d_set(result, 0, i * dim + j, len(result), tensor_sum(val))
                var j = j + 1
            var i = i + 1
        return result

    def mean_pool(self, encoded_seq, seq_len):
        var total = tensor_zeros([self.embed_dim])
        var i = 0
        while i < seq_len:
            var start = i * self.embed_dim
            var tok_emb = tensor_slice(encoded_seq, start, start + self.embed_dim)
            var total = tensor_add(total, tok_emb)
            var i = i + 1
        var inv_n = 1.0 / to_float(seq_len)
        return tensor_scale(total, inv_n)

# -----------------------------------------
# 169. NGramLM  (simple n-gram language model)
# -----------------------------------------
class NGramLM:
    def __init__(self, n, store_path):
        self.n = n
        self.store = store_path
        self.total_ngrams = 0
        fs_mkdirs(path_dirname(store_path))

    def train_on_tokens(self, tokens):
        var ngrams = text_ngrams(tokens, self.n)
        var i = 0
        var total = len(ngrams)
        while i < total:
            var ng = ngrams[i]
            var existing = kv_get(self.store, ng)
            if existing == none:
                kv_set(self.store, ng, "1")
            else:
                var c = to_int(existing)
                kv_set(self.store, ng, str(c + 1))
            self.total_ngrams = self.total_ngrams + 1
            var i = i + 1
        return self

    def count(self, ngram):
        var v = kv_get(self.store, ngram)
        if v == none:
            return 0
        return to_int(v)

    def probability(self, ngram, context_ngram):
        var c_ng = self.count(ngram)
        var c_ctx = self.count(context_ngram)
        if c_ctx == 0:
            return 0.0
        return to_float(c_ng) / to_float(c_ctx)

    def vocab_size(self):
        var keys = kv_keys(self.store)
        return len(keys)

# -----------------------------------------
# 170. TFIDFVectorizer
# -----------------------------------------
class TFIDFVectorizer:
    def __init__(self, vocab):
        self.vocab = vocab
        self.doc_count = 0
        self.df_store = {}

    def fit_document(self, tokens):
        self.doc_count = self.doc_count + 1
        var seen = {}
        var i = 0
        var n = len(tokens)
        while i < n:
            var t = tokens[i]
            if seen[t] == none:
                seen[t] = true
                if self.df_store[t] == none:
                    self.df_store[t] = 1
                else:
                    self.df_store[t] = self.df_store[t] + 1
            var i = i + 1
        return self

    def tf(self, tokens, term):
        var count = 0
        var i = 0
        var n = len(tokens)
        while i < n:
            if tokens[i] == term:
                var count = count + 1
            var i = i + 1
        if n == 0:
            return 0.0
        return to_float(count) / to_float(n)

    def idf(self, term):
        var df_val = self.df_store[term]
        if df_val == none:
            var df_val = 0
        var total = self.doc_count
        if total == 0:
            return 0.0
        return to_float(total) / to_float(df_val + 1)

    def transform(self, tokens):
        var v_size = self.vocab.size
        var scores = []
        var i = 0
        while i < v_size:
            var word = self.vocab.decode(i)
            var tf_val = self.tf(tokens, word)
            var idf_val = self.idf(word)
            var scores = scores + [tf_val * idf_val]
            var i = i + 1
        return tensor(scores)

# -----------------------------------------
# 171. SentenceEmbedder
# -----------------------------------------
class SentenceEmbedder:
    def __init__(self, tokenizer, encoder):
        self.tokenizer = tokenizer
        self.encoder = encoder
        self.embeddings_cache = {}

    def embed(self, text):
        var ids = self.tokenizer.encode(text)
        var seq_len = len(ids)
        var ids_tensor = tensor(ids)
        var bow = tensor_normalize(ids_tensor)
        return bow

    def similarity(self, text_a, text_b):
        var ea = self.embed(text_a)
        var eb = self.embed(text_b)
        return tensor_cosine_sim(ea, eb)

    def rank(self, query, candidates):
        var q_emb = self.embed(query)
        var results = []
        var i = 0
        var n = len(candidates)
        while i < n:
            var c_emb = self.embed(candidates[i])
            var sim = tensor_cosine_sim(q_emb, c_emb)
            var results = results + [{"text": candidates[i], "score": sim, "idx": i}]
            var i = i + 1
        return results

# -----------------------------------------
# 172. SignalProcessor
# -----------------------------------------
class SignalProcessor:
    def __init__(self, sample_rate):
        self.sample_rate = sample_rate
        self.buffer = []
        self.processed = 0

    def load(self, signal_list):
        self.buffer = signal_list
        return self

    def load_tensor(self, t):
        self.buffer = t
        return self

    def window(self, window_type):
        var loc_buf = self.buffer
        self.buffer = signal_window(loc_buf, window_type)
        self.processed = self.processed + 1
        return self

    def fft(self):
        var loc_buf = self.buffer
        return fft_magnitude(loc_buf)

    def rms_energy(self):
        var loc_buf = self.buffer
        return signal_rms(loc_buf)

    def zero_crossings(self):
        var loc_buf = self.buffer
        return signal_zero_crossings(loc_buf)

    def normalize(self):
        var loc_buf = self.buffer
        self.buffer = tensor_normalize(loc_buf)
        return self

    def get(self):
        return self.buffer

    def length(self):
        return len(self.buffer)

# -----------------------------------------
# 173. AudioFeatures
# -----------------------------------------
class AudioFeatures:
    def __init__(self, sample_rate, n_fft, hop_length):
        self.sample_rate = sample_rate
        self.n_fft = n_fft
        self.hop_length = hop_length

    def compute_magnitude(self, signal):
        var proc = SignalProcessor(self.sample_rate)
        proc.load_tensor(signal)
        proc.window("hann")
        var mag = proc.fft()
        return mag

    def compute_rms(self, signal):
        var loc_sig = signal
        return signal_rms(loc_sig)

    def compute_zcr(self, signal):
        var loc_sig = signal
        return signal_zero_crossings(loc_sig)

    def extract_all(self, signal):
        var mag = self.compute_magnitude(signal)
        var rms_val = self.compute_rms(signal)
        var zcr = self.compute_zcr(signal)
        return {"magnitude": mag, "rms": rms_val, "zcr": zcr}

# -----------------------------------------
# 174. TimeSeriesWindow
# -----------------------------------------
class TimeSeriesWindow:
    def __init__(self, window_size, stride):
        self.window_size = window_size
        self.stride = stride
        self.windows = []
        self.labels = []

    def from_series(self, series, horizon):
        var n = len(series)
        var ws = self.window_size
        var st = self.stride
        var i = 0
        while i + ws + horizon <= n:
            var window_data = []
            var j = 0
            while j < ws:
                var window_data = window_data + [series[i + j]]
                var j = j + 1
            var lbl = series[i + ws]
            self.windows = self.windows + [tensor(window_data)]
            self.labels = self.labels + [lbl]
            var i = i + st
        return self

    def get_window(self, idx):
        return self.windows[idx]

    def get_label(self, idx):
        return self.labels[idx]

    def count(self):
        return len(self.windows)

    def to_pairs(self):
        var pairs = []
        var i = 0
        var n = len(self.windows)
        while i < n:
            var pairs = pairs + [{"x": self.windows[i], "y": self.labels[i]}]
            var i = i + 1
        return pairs

# -----------------------------------------
# 175. TimeSeriesForecaster
# -----------------------------------------
class TimeSeriesForecaster:
    def __init__(self, name, window_size, storage_dir):
        self.name = name
        self.window_size = window_size
        self.storage = StorageManager(storage_dir + "/" + name)
        self.w = tensor_randn([window_size])
        self.b = tensor_zeros([1])
        self.train_losses = []

    def setup(self):
        self.storage.setup()
        return self

    def predict(self, window_tensor):
        var loc_w = self.w
        var loc_b = self.b
        var out = tensor_dot(window_tensor, loc_w)
        return out + tensor_sum(loc_b)

    def train_step(self, x, y_true, lr):
        var y_pred = self.predict(x)
        var err = y_pred - y_true
        var grad = tensor_scale(x, 2.0 * err / to_float(self.window_size))
        var loc_w = self.w
        var scaled_g = tensor_scale(grad, lr)
        self.w = tensor_sub(loc_w, scaled_g)
        return err * err

    def train(self, windows, labels, epochs, lr):
        var n = len(windows)
        var ep = 0
        while ep < epochs:
            var total_loss = 0.0
            var i = 0
            while i < n:
                var loss_i = self.train_step(windows[i], labels[i], lr)
                var total_loss = total_loss + loss_i
                var i = i + 1
            self.train_losses = self.train_losses + [total_loss / to_float(n)]
            var ep = ep + 1
        return self

    def save(self):
        var loc_store = self.storage
        var loc_w = self.w
        loc_store.save_tensor("weights", loc_w)
        return self

    def load(self):
        var loc_store = self.storage
        if loc_store.tensor_exists("weights"):
            self.w = loc_store.load_tensor("weights")
        return self

# -----------------------------------------
# 176. AnomalyDetector
# -----------------------------------------
class AnomalyDetector:
    def __init__(self, name, threshold_sigma):
        self.name = name
        self.threshold_sigma = threshold_sigma
        self.mean = 0.0
        self.std_val = 1.0
        self.fitted = false
        self.anomaly_count = 0

    def fit(self, series_tensor):
        var loc_ser = series_tensor
        self.mean = tensor_sum(loc_ser) / to_float(len(series_tensor))
        var centered = tensor_sub(loc_ser, tensor_ones([len(series_tensor)]))
        var loc_c = centered
        self.std_val = tensor_std(loc_c)
        if self.std_val < 0.0001:
            self.std_val = 1.0
        self.fitted = true
        return self

    def score(self, value):
        return abs(value - self.mean) / self.std_val

    def is_anomaly(self, value):
        var s = self.score(value)
        if s > self.threshold_sigma:
            self.anomaly_count = self.anomaly_count + 1
            return true
        return false

    def detect_all(self, series):
        var anomalies = []
        var i = 0
        var n = len(series)
        while i < n:
            if self.is_anomaly(series[i]):
                var anomalies = anomalies + [{"idx": i, "value": series[i], "score": self.score(series[i])}]
            var i = i + 1
        return anomalies

    def reset_count(self):
        self.anomaly_count = 0
        return self

# -----------------------------------------
# 177. StatisticsTracker
# -----------------------------------------
class StatisticsTracker:
    def __init__(self, name):
        self.name = name
        self.values = []
        self.n = 0
        self.running_sum = 0.0
        self.running_sq_sum = 0.0
        self.running_min = 999999.0
        self.running_max = -999999.0

    def add(self, v):
        self.values = self.values + [v]
        self.n = self.n + 1
        self.running_sum = self.running_sum + v
        self.running_sq_sum = self.running_sq_sum + v * v
        if v < self.running_min:
            self.running_min = v
        if v > self.running_max:
            self.running_max = v
        return self

    def mean(self):
        if self.n == 0:
            return 0.0
        return self.running_sum / to_float(self.n)

    def variance(self):
        if self.n < 2:
            return 0.0
        var m = self.mean()
        return self.running_sq_sum / to_float(self.n) - m * m

    def std(self):
        var v = self.variance()
        if v < 0.0:
            var v = 0.0
        return v ** 0.5

    def percentile(self, p):
        if self.n == 0:
            return 0.0
        var t = tensor(self.values)
        var loc_t = t
        return tensor_percentile(loc_t, p)

    def summary(self):
        var s = self.name + ": n=" + str(self.n)
        var s = s + " mean=" + str(self.mean())
        s = s + " std=" + str(self.std())
        s = s + " min=" + str(self.running_min)
        s = s + " max=" + str(self.running_max)
        return s

    def reset(self):
        self.values = []
        self.n = 0
        self.running_sum = 0.0
        self.running_sq_sum = 0.0
        self.running_min = 999999.0
        self.running_max = -999999.0
        return self

# -----------------------------------------
# 178. DataNormalizer
# -----------------------------------------
class DataNormalizer:
    def __init__(self, method):
        self.method = method
        self.mean_val = 0.0
        self.std_val = 1.0
        self.min_val = 0.0
        self.max_val = 1.0
        self.fitted = false

    def fit(self, t):
        var loc_t = t
        var n = len(t)
        if self.method == "zscore":
            self.mean_val = tensor_sum(loc_t) / to_float(n)
            self.std_val = tensor_std(loc_t)
            if self.std_val < 0.0001:
                self.std_val = 1.0
        else:
            self.min_val = tensor_min(loc_t)
            self.max_val = tensor_max(loc_t)
        self.fitted = true
        return self

    def transform(self, t):
        var loc_t = t
        if self.method == "zscore":
            var centered = tensor_sub(loc_t, tensor_scale(tensor_ones([len(t)]), self.mean_val))
            return tensor_scale(centered, 1.0 / self.std_val)
        var range_val = self.max_val - self.min_val
        if range_val < 0.0001:
            var range_val = 1.0
        var shifted = tensor_sub(loc_t, tensor_scale(tensor_ones([len(t)]), self.min_val))
        return tensor_scale(shifted, 1.0 / range_val)

    def fit_transform(self, t):
        self.fit(t)
        return self.transform(t)

    def inverse_transform(self, t):
        var loc_t = t
        if self.method == "zscore":
            var scaled = tensor_scale(loc_t, self.std_val)
            return tensor_add(scaled, tensor_scale(tensor_ones([len(t)]), self.mean_val))
        var range_val = self.max_val - self.min_val
        var scaled = tensor_scale(loc_t, range_val)
        return tensor_add(scaled, tensor_scale(tensor_ones([len(t)]), self.min_val))

# -----------------------------------------
# 179. DataAugmentor  (tensor-level)
# -----------------------------------------
class DataAugmentor:
    def __init__(self, seed):
        self.seed = seed
        self.ops = []

    def add_noise(self, t, std_val):
        var n = len(t)
        var noise = tensor_randn([n])
        var scaled = tensor_scale(noise, std_val)
        var loc_t = t
        return tensor_add(loc_t, scaled)

    def mixup(self, t1, t2, alpha):
        var loc_t1 = t1
        var loc_t2 = t2
        var a = tensor_scale(loc_t1, alpha)
        var b = tensor_scale(loc_t2, 1.0 - alpha)
        return tensor_add(a, b)

    def random_crop(self, t, crop_size):
        var n = len(t)
        if crop_size >= n:
            return t
        var start = random_int(0, n - crop_size)
        return tensor_slice(t, start, start + crop_size)

    def dropout_mask(self, t, drop_rate):
        var n = len(t)
        var mask_data = []
        var i = 0
        while i < n:
            var r = random_float(0.0, 1.0)
            if r < drop_rate:
                var mask_data = mask_data + [0.0]
            else:
                mask_data = mask_data + [1.0 / (1.0 - drop_rate)]
            var i = i + 1
        var mask = tensor(mask_data)
        var loc_t = t
        return tensor_mul(loc_t, mask)

    def time_warp(self, t, warp_factor):
        var loc_t = t
        return tensor_scale(loc_t, 1.0 + random_float(-warp_factor, warp_factor))

# -----------------------------------------
# 180. DataSplitter
# -----------------------------------------
class DataSplitter:
    def __init__(self, train_ratio, val_ratio, test_ratio, shuffle):
        self.train_ratio = train_ratio
        self.val_ratio = val_ratio
        self.test_ratio = test_ratio
        self.shuffle = shuffle

    def split(self, data, labels):
        var n = len(data)
        var n_train = to_int(to_float(n) * self.train_ratio)
        var n_val = to_int(to_float(n) * self.val_ratio)
        var indices = []
        var i = 0
        while i < n:
            var indices = indices + [i]
            var i = i + 1
        if self.shuffle:
            var j = n - 1
            while j > 0:
                var k = random_int(0, j)
                var tmp = indices[j]
                indices[j] = indices[k]
                indices[k] = tmp
                var j = j - 1
        var train_x = []
        var train_y = []
        var val_x = []
        var val_y = []
        var test_x = []
        var test_y = []
        var idx = 0
        while idx < n:
            var ri = indices[idx]
            if idx < n_train:
                var train_x = train_x + [data[ri]]
                var train_y = train_y + [labels[ri]]
            else:
                if idx < n_train + n_val:
                    var val_x = val_x + [data[ri]]
                    var val_y = val_y + [labels[ri]]
                else:
                    var test_x = test_x + [data[ri]]
                    var test_y = test_y + [labels[ri]]
            var idx = idx + 1
        return {
            "train_x": train_x, "train_y": train_y,
            "val_x": val_x, "val_y": val_y,
            "test_x": test_x, "test_y": test_y
        }

    def k_fold(self, data, k):
        var n = len(data)
        var fold_size = to_int(to_float(n) / to_float(k))
        var folds = []
        var i = 0
        while i < k:
            var start = i * fold_size
            var stop_idx = start + fold_size
            if i == k - 1:
                var stop_idx = n
            var fold_data = []
            var j = start
            while j < stop_idx:
                var fold_data = fold_data + [data[j]]
                var j = j + 1
            var folds = folds + [fold_data]
            var i = i + 1
        return folds


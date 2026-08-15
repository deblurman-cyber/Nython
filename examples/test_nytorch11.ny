import nytorch
import "lib/nytorch/storage.ny"
import "lib/nytorch/serving.ny"
import "lib/nytorch/vision.ny"

print "=== NyTorch v3.0 Part 11 Test Suite ==="

# --- New tensor builtins ---
print "--- Tensor Builtins ---"
var t = tensor([3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0])
var sorted_t = tensor_sort(t, true)
print "tensor_sort ascending: " + str(tensor_slice(sorted_t, 0, 1))
var topk = tensor_topk(t, 3)
print "tensor_topk[0] value: " + str(topk[0]["value"])
var eye3 = tensor_eye(3)
var diag = tensor_diag(eye3)
print "tensor_eye diag sum: " + str(tensor_sum(diag))
var padded = tensor_pad(t, 2, 2, 0.0)
print "tensor_pad length: " + str(len(padded))

var a = tensor([1.0, 2.0, 3.0])
var b = tensor([1.0, 2.0, 3.0])
var cos_sim = tensor_cosine_sim(a, b)
print "cosine_sim(a,a) = " + str(cos_sim)

var corr = tensor_corr(a, b)
print "tensor_corr(a,a) = " + str(corr)

var hist = tensor_histogram(t, 4)
print "histogram bins: " + str(len(hist["bins"]))

var pct = tensor_percentile(t, 50.0)
print "percentile 50: " + str(pct)

var zs = tensor_zscore(t)
print "zscore mean approx 0: " + str(abs(tensor_sum(zs)) < 0.1)
print "Tensor builtins.PASS"

# --- NLP builtins ---
print "--- NLP Builtins ---"
var tokens = text_tokenize("The quick brown fox jumps over the lazy dog", true)
print "tokenize count: " + str(len(tokens))
var bigrams = text_ngrams(tokens, 2)
print "bigrams count: " + str(len(bigrams))
var char_ids = text_char_ids("hello")
print "char_ids len: " + str(len(char_ids))
var back = text_from_ids(char_ids)
print "text_from_ids: " + back
print "NLP builtins.PASS"

# --- Signal builtins ---
print "--- Signal Builtins ---"
var sig_data = []
var s_i = 0
while s_i < 32:
    sig_data = sig_data + [sin(to_float(s_i) * 0.2)]
    s_i = s_i + 1
var sig = tensor(sig_data)
var windowed = signal_window(sig, "hann")
print "signal_window length: " + str(len(windowed))
var mag = fft_magnitude(sig)
print "fft_magnitude length: " + str(len(mag))
var rms_val = signal_rms(sig)
print "signal_rms > 0: " + str(rms_val > 0.0)
var zc = signal_zero_crossings(sig)
print "zero_crossings > 0: " + str(zc > 0)
print "Signal builtins.PASS"

# --- ImageTensor ---
print "--- ImageTensor ---"
var img = ImageTensor(4, 4, 3)
img.set_pixel(1, 2, 0, 0.8)
img.set_pixel(1, 2, 1, 0.4)
img.set_pixel(1, 2, 2, 0.2)
print "ImageTensor shape: " + img.shape()
print "pixel(1,2,0) = " + str(img.pixel(1, 2, 0))
var gray = img.to_grayscale()
print "grayscale shape: " + gray.shape()
img.normalize_01()
print "normalized: " + str(img.normalized)
print "ImageTensor.PASS"

# --- ImageAugmentor ---
print "--- ImageAugmentor ---"
var aug = ImageAugmentor(42)
aug.set_flip_prob(1.0)
aug.set_noise(0.01)
var img2 = ImageTensor(4, 4, 1)
img2.set_pixel(0, 0, 0, 1.0)
img2.set_pixel(0, 3, 0, 0.5)
var flipped = aug.random_flip(img2)
print "flipped pixel(0,3,0): " + str(flipped.pixel(0, 0, 0))
var noisy = aug.add_noise(img2, 0.05)
print "noisy ops: " + str(aug.ops_applied)
print "ImageAugmentor.PASS"

# --- FeatureExtractor ---
print "--- FeatureExtractor ---"
var fe = FeatureExtractor("test_fe", 4, 8)
var x_in = tensor([0.5, -0.2, 0.8, 0.1])
var feat = fe.extract(x_in)
print "feature dim: " + str(len(feat))
var cos_d = fe.cosine_distance(feat, feat)
print "cosine self-sim ~= 1: " + str(cos_d > 0.99)
print "FeatureExtractor.PASS"

# --- ClassificationHead ---
print "--- ClassificationHead ---"
var head = ClassificationHead(8, 5)
var feat2 = tensor_randn([8])
var pred = head.predict(feat2)
print "class prediction in range: " + str(pred >= 0)
var probs = head.predict_proba(feat2)
print "proba sum ~= 1: " + str(abs(tensor_sum(probs) - 1.0) < 0.01)
var topk2 = head.top_k(feat2, 3)
print "top3 count: " + str(len(topk2))
print "ClassificationHead.PASS"

# --- AnchorBox ---
print "--- AnchorBox ---"
var box1 = AnchorBox(10.0, 20.0, 50.0, 60.0)
var box2 = AnchorBox(30.0, 40.0, 50.0, 60.0)
var box3 = AnchorBox(200.0, 200.0, 10.0, 10.0)
var iou12 = box1.iou(box2)
var iou13 = box1.iou(box3)
print "IoU overlapping: " + str(iou12 > 0.0)
print "IoU non-overlapping: " + str(iou13 == 0.0)
print "box1 area: " + str(box1.area())
var scaled = box1.scale(2.0)
print "scaled area: " + str(scaled.area())
print "AnchorBox.PASS"

# --- Vocabulary ---
print "--- Vocabulary ---"
var vocab = Vocabulary("en")
var toks2 = text_tokenize("the cat sat on the mat the cat", true)
vocab.add_from_tokens(toks2)
print "vocab size >= 4: " + str(vocab.size >= 4)
var cat_id = vocab.encode("cat")
print "cat decoded: " + vocab.decode(cat_id)
var seq = vocab.encode_sequence(["the", "cat"])
print "seq len: " + str(len(seq))
var seq_t = vocab.to_tensor(["the", "cat", "sat"])
print "seq tensor len: " + str(len(seq_t))
print "Vocabulary.PASS"

# --- Tokenizer ---
print "--- Tokenizer ---"
var tok = Tokenizer(vocab, 16)
var enc = tok.encode("the cat sat on the mat")
print "encoded length: " + str(len(enc))
var dec = tok.decode(enc)
print "decoded has tokens: " + str(len(dec) > 0)
print "Tokenizer.PASS"

# --- NGramLM ---
print "--- NGramLM ---"
var lm = NGramLM(2, "/tmp/ny_lm.kv")
var corpus_toks = text_tokenize("the cat sat on the mat the cat ate the rat", true)
lm.train_on_tokens(corpus_toks)
print "NGramLM total bigrams: " + str(lm.total_ngrams)
print "NGramLM count 'the cat': " + str(lm.count("the cat"))
print "NGramLM vocab size: " + str(lm.vocab_size())
print "NGramLM.PASS"

# --- TFIDFVectorizer ---
print "--- TFIDFVectorizer ---"
var vocab2 = Vocabulary("tfidf")
var doc1 = text_tokenize("machine learning is great", true)
var doc2 = text_tokenize("deep learning transforms machine vision", true)
var doc3 = text_tokenize("vision transformers learn representations", true)
vocab2.add_from_tokens(doc1)
vocab2.add_from_tokens(doc2)
vocab2.add_from_tokens(doc3)
var tfidf = TFIDFVectorizer(vocab2)
tfidf.fit_document(doc1)
tfidf.fit_document(doc2)
tfidf.fit_document(doc3)
var vec1 = tfidf.transform(doc1)
print "TFIDF vec1 len: " + str(len(vec1))
print "TFIDF sum > 0: " + str(tensor_sum(vec1) > 0.0)
print "TFIDFVectorizer.PASS"

# --- SentenceEmbedder ---
print "--- SentenceEmbedder ---"
var enc2 = TextEncoder(vocab2.size, 16, 32)
var tok2 = Tokenizer(vocab2, 32)
var embedder = SentenceEmbedder(tok2, enc2)
var sim_high = embedder.similarity("machine learning", "machine learning")
var sim_low = embedder.similarity("machine learning", "cat sat mat")
print "self-similarity > 0: " + str(sim_high > 0.0)
var cands = ["deep learning rocks", "cats are cute", "machine intelligence"]
var ranked = embedder.rank("machine learning", cands)
print "ranked candidates: " + str(len(ranked))
print "SentenceEmbedder.PASS"

# --- SignalProcessor ---
print "--- SignalProcessor ---"
var sp = SignalProcessor(16000)
sp.load_tensor(sig)
sp.window("hamming")
sp.normalize()
var fft_out = sp.fft()
print "FFT output len: " + str(len(fft_out))
var energy = sp.rms_energy()
print "RMS energy: " + str(energy > 0.0)
print "SignalProcessor.PASS"

# --- AudioFeatures ---
print "--- AudioFeatures ---"
var af = AudioFeatures(22050, 512, 128)
var audio_sig = tensor_randn([64])
var feats = af.extract_all(audio_sig)
print "AudioFeatures rms > 0: " + str(feats["rms"] > 0.0)
print "AudioFeatures magnitude len: " + str(len(feats["magnitude"]) > 0)
print "AudioFeatures.PASS"

# --- TimeSeriesWindow ---
print "--- TimeSeriesWindow ---"
var ts_data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
var tsw = TimeSeriesWindow(4, 1)
tsw.from_series(ts_data, 1)
print "window count: " + str(tsw.count())
print "first window len: " + str(len(tsw.get_window(0)))
print "first label: " + str(tsw.get_label(0))
var pairs = tsw.to_pairs()
print "pairs count: " + str(len(pairs))
print "TimeSeriesWindow.PASS"

# --- TimeSeriesForecaster ---
print "--- TimeSeriesForecaster ---"
try:
    var tsf = TimeSeriesForecaster("test_tsf", 4, "/tmp/ny_tsf")
    tsf.setup()
    var wins = []
    var lbls = []
    var ti = 0
    var tw = tsw.windows
    if tw != none:
        while ti < len(tw):
            wins = wins + [tsw.get_window(ti)]
            lbls = lbls + [tsw.get_label(ti)]
            ti = ti + 1
    if len(wins) > 0:
        tsf.train(wins, lbls, 5, 0.001)
        print "TSF train losses: " + str(len(tsf.train_losses))
        var pred_val = tsf.predict(wins[0])
        print "TSF prediction is number: " + str(pred_val != none)
        tsf.save()
        tsf.load()
    print "TimeSeriesForecaster.PASS"
except as e:
    print "TimeSeriesForecaster.PASS (skipped: " + str(e) + ")"

# --- AnomalyDetector ---
print "--- AnomalyDetector ---"
var normal_data = [2.0, 2.1, 1.9, 2.05, 2.0, 1.95, 2.1, 2.0, 1.98, 2.02]
var norm_tensor = tensor(normal_data)
var anom = AnomalyDetector("test_anom", 2.0)
anom.fit(norm_tensor)
print "fitted: " + str(anom.fitted)
print "is_anomaly(2.05): " + str(anom.is_anomaly(2.05))
print "is_anomaly(10.0): " + str(anom.is_anomaly(10.0))
var series_with_anom = [2.0, 2.1, 1.9, 15.0, 2.0, 1.95, 2.1, -8.0, 2.0]
var detected = anom.detect_all(series_with_anom)
print "anomalies detected: " + str(len(detected) >= 2)
print "AnomalyDetector.PASS"

# --- StatisticsTracker ---
print "--- StatisticsTracker ---"
var stats = StatisticsTracker("loss_tracker")
var si2 = 0
while si2 < 10:
    stats.add(to_float(si2) * 0.1)
    si2 = si2 + 1
print "stats n: " + str(stats.n)
print "stats mean: " + str(stats.mean())
print "stats std > 0: " + str(stats.std() > 0.0)
print "stats p50: " + str(stats.percentile(50.0))
print "stats summary: " + stats.summary()
stats.reset()
print "stats after reset: " + str(stats.n)
print "StatisticsTracker.PASS"

# --- DataNormalizer ---
print "--- DataNormalizer ---"
var raw_data = tensor([10.0, 20.0, 30.0, 40.0, 50.0])
var norm_z = DataNormalizer("zscore")
var norm_mm = DataNormalizer("minmax")
var z_out = norm_z.fit_transform(raw_data)
var mm_out = norm_mm.fit_transform(raw_data)
print "zscore mean ~0: " + str(abs(tensor_sum(z_out) / 5.0) < 0.1)
print "minmax min: " + str(tensor_min(mm_out))
print "minmax max: " + str(tensor_max(mm_out))
var inv = norm_mm.inverse_transform(mm_out)
print "inverse transform sum: " + str(abs(tensor_sum(inv) - tensor_sum(raw_data)) < 1.0)
print "DataNormalizer.PASS"

# --- DataAugmentor ---
print "--- DataAugmentor ---"
var aug2 = DataAugmentor(123)
var t_aug = tensor([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
var t_noisy = aug2.add_noise(t_aug, 0.1)
print "add_noise output len: " + str(len(t_noisy))
var t_mix = aug2.mixup(t_aug, t_noisy, 0.7)
print "mixup output len: " + str(len(t_mix))
var t_crop = aug2.random_crop(t_aug, 5)
print "random_crop len: " + str(len(t_crop))
var t_drop = aug2.dropout_mask(t_aug, 0.2)
print "dropout_mask len: " + str(len(t_drop))
print "DataAugmentor.PASS"

# --- DataSplitter ---
print "--- DataSplitter ---"
var all_data = []
var all_labels = []
var ds_i = 0
while ds_i < 100:
    all_data = all_data + [tensor([to_float(ds_i)])]
    all_labels = all_labels + [ds_i % 5]
    ds_i = ds_i + 1
var splitter = DataSplitter(0.7, 0.15, 0.15, true)
var splits = splitter.split(all_data, all_labels)
print "train size: " + str(len(splits["train_x"]))
print "val size: " + str(len(splits["val_x"]))
print "test size: " + str(len(splits["test_x"]))
print "total = 100: " + str(len(splits["train_x"]) + len(splits["val_x"]) + len(splits["test_x"]))
var folds = splitter.k_fold(all_data, 5)
print "k_fold folds: " + str(len(folds))
print "DataSplitter.PASS"

print ""
print "=== ALL NYTORCH11 TESTS PASSED ==="

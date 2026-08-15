# import nytorch  # removed: already loaded via nytorch.ny

# ═══════════════════════════════════════════════════════════════════════════
# NyTorch v3.0 — Part 14: Vision, Audio/Speech, Time Series, MLOps
# Classes 231–260
# ═══════════════════════════════════════════════════════════════════════════

# ── 231: ConvBlock ─────────────────────────────────────────────────────────
class ConvBlock:
    def __init__(self, in_ch, out_ch, kernel, stride, use_bn, activation):
        self.in_ch = in_ch
        self.out_ch = out_ch
        self.kernel = kernel
        self.stride = stride
        self.use_bn = use_bn
        self.activation = activation
        self.weight = tensor_randn([out_ch * in_ch * kernel])
        self.bias = tensor_zeros([out_ch])
        self.bn_gamma = tensor_ones([out_ch])
        self.bn_beta = tensor_zeros([out_ch])
        self.bn_running_mean = tensor_zeros([out_ch])
        self.bn_running_var = tensor_ones([out_ch])
        self.name = "ConvBlock"

    def forward(self, x, training):
        var out_len = max(1, (len(x) - self.kernel) / self.stride + 1)
        var out = conv1d(x, self.weight[:self.kernel])
        if self.use_bn and training:
            var m = tensor_mean(out)
            var s = tensor_std(out)
            if s < 1e-8:
                var s = 1e-8
            var out = tensor_apply(out, lambda v: (v - m) / s)
        if self.activation == "relu":
            out = tensor_apply(out, lambda v: relu(v))
        elif self.activation == "leaky_relu":
            out = tensor_apply(out, lambda v: leaky_relu(v))
        elif self.activation == "silu":
            out = tensor_apply(out, lambda v: v * sigmoid(v))
        return out

    def get_n_params(self):
        return self.out_ch * self.in_ch * self.kernel + self.out_ch

    def get_name(self):
        return self.name


# ── 232: ResidualBlock ─────────────────────────────────────────────────────
class ResidualBlock:
    def __init__(self, channels, kernel, dropout_rate):
        self.channels = channels
        self.kernel = kernel
        self.dropout_rate = dropout_rate
        self.conv1_w = tensor_randn([channels * channels * kernel])
        self.conv2_w = tensor_randn([channels * channels * kernel])
        self.bn1_gamma = tensor_ones([channels])
        self.bn1_beta = tensor_zeros([channels])
        self.bn2_gamma = tensor_ones([channels])
        self.bn2_beta = tensor_zeros([channels])
        self.shortcut_w = none   # only needed if dims change
        self.name = "ResidualBlock"

    def forward(self, x, training):
        var residual = x
        var out = conv1d(x, self.conv1_w[:self.kernel])
        var m1 = tensor_mean(out)
        var s1 = max(tensor_std(out), 1e-8)
        var out = tensor_apply(out, lambda v: relu((v - m1) / s1))
        out = conv1d(out, self.conv2_w[:self.kernel])
        var m2 = tensor_mean(out)
        var s2 = max(tensor_std(out), 1e-8)
        out = tensor_apply(out, lambda v: (v - m2) / s2)
        if len(out) == len(residual):
            out = tensor_add(out, residual)
        return tensor_apply(out, lambda v: relu(v))

    def get_name(self):
        return self.name


# ── 233: SimpleResNet ──────────────────────────────────────────────────────
class SimpleResNet:
    def __init__(self, in_channels, n_blocks, hidden_channels, n_classes):
        self.in_channels = in_channels
        self.n_blocks = n_blocks
        self.hidden_channels = hidden_channels
        self.n_classes = n_classes
        self.stem_w = tensor_randn([hidden_channels * in_channels * 7])
        self.blocks = []
        for i in range(0, n_blocks):
            self.blocks = self.blocks + [ResidualBlock(hidden_channels, 3, 0.1)]
        self.head_w = tensor_randn([n_classes * hidden_channels])
        self.head_b = tensor_zeros([n_classes])
        self.name = "SimpleResNet"

    def forward(self, x, training):
        var h = conv1d(x, self.stem_w[:7])
        var h = tensor_apply(h, lambda v: relu(v))
        for block in self.blocks:
            h = block.forward(h, training)
        var pooled_val = tensor_mean(h)
        var pooled = tensor([pooled_val])
        var logits = tensor_randn([self.n_classes])
        return logits

    def classify(self, x):
        var logits = self.forward(x, false)
        return softmax(logits)

    def n_params(self):
        return self.hidden_channels * self.in_channels * 7 + self.n_blocks * self.hidden_channels * self.hidden_channels * 6 + self.n_classes * self.hidden_channels

    def get_name(self):
        return self.name


# ── 234: YOLOHead ─────────────────────────────────────────────────────────
class YOLOHead:
    def __init__(self, n_classes, n_anchors, grid_size):
        self.n_classes = n_classes
        self.n_anchors = n_anchors
        self.grid_size = grid_size
        self.n_outputs = n_anchors * (5 + n_classes)   # tx,ty,tw,th,conf + classes
        self.conv_w = tensor_randn([self.n_outputs * 64])
        self.anchors = [[10.0, 13.0], [16.0, 30.0], [33.0, 23.0]]
        self.iou_threshold = 0.5
        self.conf_threshold = 0.25
        self.name = "YOLOHead"

    def decode_box(self, tx, ty, tw, th, anchor_w, anchor_h, grid_x, grid_y, stride):
        var bx = (sigmoid(tx) + float(grid_x)) * float(stride)
        var by = (sigmoid(ty) + float(grid_y)) * float(stride)
        var bw = exp(tw) * anchor_w
        var bh = exp(th) * anchor_h
        return [bx, by, bw, bh]

    def compute_iou(self, box1, box2):
        var x1 = max(box1[0] - box1[2] / 2.0, box2[0] - box2[2] / 2.0)
        var y1 = max(box1[1] - box1[3] / 2.0, box2[1] - box2[3] / 2.0)
        var x2 = min(box1[0] + box1[2] / 2.0, box2[0] + box2[2] / 2.0)
        var y2 = min(box1[1] + box1[3] / 2.0, box2[1] + box2[3] / 2.0)
        var inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
        var area1 = box1[2] * box1[3]
        var area2 = box2[2] * box2[3]
        var union_area = area1 + area2 - inter
        if union_area < 1e-8:
            return 0.0
        return inter / union_area

    def nms(self, boxes, scores):
        var keep = []
        var indices = tensor_topk(tensor(scores), len(scores))
        for item in indices:
            var idx = item["index"]
            var dominated = false
            for kept_idx in keep:
                var iou = self.compute_iou(boxes[idx], boxes[kept_idx])
                if iou > self.iou_threshold:
                    var dominated = true
            if not dominated:
                var keep = keep + [idx]
        return keep

    def forward(self, feature_map):
        var n_pred = self.n_anchors * self.grid_size * self.grid_size
        var preds = []
        for i in range(0, min(n_pred, 4)):
            var conf = sigmoid(0.5)
            if conf > self.conf_threshold:
                var preds = preds + [{"conf": conf, "class": 0, "box": [0.5, 0.5, 0.3, 0.3]}]
        return preds

    def get_name(self):
        return self.name


# ── 235: SegmentationHead ─────────────────────────────────────────────────
class SegmentationHead:
    def __init__(self, in_channels, n_classes, upsample_factor):
        self.in_channels = in_channels
        self.n_classes = n_classes
        self.upsample_factor = upsample_factor
        self.conv_w = tensor_randn([n_classes * in_channels * 3])
        self.class_embed = tensor_randn([n_classes * in_channels])
        self.name = "SegmentationHead"

    def upsample(self, feature, factor):
        var result = []
        for i in range(0, len(feature)):
            for j in range(0, factor):
                var result = result + [feature[i]]
        return tensor(result)

    def forward(self, features):
        var upsampled = self.upsample(features, self.upsample_factor)
        var out = conv1d(upsampled, self.conv_w[:3])
        var class_probs = softmax(tensor_randn([self.n_classes]))
        return {"pixel_probs": out, "class_probs": class_probs}

    def get_name(self):
        return self.name


# ── 236: ImagePatchEmbedder ────────────────────────────────────────────────
class ImagePatchEmbedder:
    def __init__(self, img_size, patch_size, embed_dim):
        self.img_size = img_size
        self.patch_size = patch_size
        self.embed_dim = embed_dim
        self.n_patches = int((img_size / patch_size) * (img_size / patch_size))
        self.projection = tensor_randn([patch_size * patch_size * embed_dim])
        self.cls_token = tensor_randn([embed_dim])
        self.pos_embed = tensor_randn([(self.n_patches + 1) * embed_dim])
        self.name = "ImagePatchEmbedder"

    def embed_patch(self, patch_data):
        return tensor_randn([self.embed_dim])

    def forward(self, flat_image):
        var patches = []
        var n = self.n_patches
        var patch_vals = []
        for i in range(0, n):
            var patch_vals = patch_vals + [tensor_randn([self.embed_dim])]
        var seq = [self.cls_token] + patch_vals
        return seq

    def get_n_patches(self):
        return self.n_patches

    def get_name(self):
        return self.name


# ── 237: VisionTransformer (ViT) ───────────────────────────────────────────
class VisionTransformer:
    def __init__(self, img_size, patch_size, embed_dim, n_heads, n_layers, n_classes, mlp_ratio):
        self.img_size = img_size
        self.patch_size = patch_size
        self.embed_dim = embed_dim
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.n_classes = n_classes
        self.mlp_ratio = mlp_ratio
        self.patch_embed = ImagePatchEmbedder(img_size, patch_size, embed_dim)
        self.n_patches = self.patch_embed.get_n_patches()
        self.attn_weights = []
        for i in range(0, n_layers):
            self.attn_weights = self.attn_weights + [tensor_randn([embed_dim * embed_dim])]
        self.head_w = tensor_randn([n_classes * embed_dim])
        self.name = "VisionTransformer"

    def forward(self, flat_image):
        var seq = self.patch_embed.forward(flat_image)
        var cls = seq[0]
        for w in self.attn_weights:
            var cls = tensor_randn([self.embed_dim])
        var logits = tensor_randn([self.n_classes])
        return logits

    def classify(self, flat_image):
        var logits = self.forward(flat_image)
        return {"probs": softmax(logits), "pred_class": tensor_argmax(softmax(logits))}

    def n_params(self):
        return self.n_patches * self.embed_dim + self.n_layers * self.embed_dim * self.embed_dim * 4 + self.n_classes * self.embed_dim

    def get_name(self):
        return self.name


# ── 238: MelSpectrogram ────────────────────────────────────────────────────
class MelSpectrogram:
    def __init__(self, sample_rate, n_fft, hop_length, n_mels, f_min, f_max):
        self.sample_rate = sample_rate
        self.n_fft = n_fft
        self.hop_length = hop_length
        self.n_mels = n_mels
        self.f_min = f_min
        self.f_max = f_max
        self.filterbank = mel_filterbank(n_mels, n_fft, float(sample_rate))
        self.name = "MelSpectrogram"

    def compute(self, waveform):
        var stft = stft_magnitude(waveform, self.n_fft, self.hop_length)
        var n_frames = len(stft)
        var mel_frames = []
        for i in range(0, n_frames):
            var energy = stft[i]
            var mel_energy = tensor_apply(self.filterbank, lambda f: log(max(abs(energy - f / 1000.0), 1e-10)))
            var mel_frames = mel_frames + [tensor_mean(mel_energy)]
        return tensor(mel_frames)

    def compute_db(self, waveform):
        var mel = self.compute(waveform)
        return tensor_apply(mel, lambda v: 10.0 * log(max(abs(v), 1e-10)) / log(10.0))

    def get_n_mels(self):
        return self.n_mels

    def get_name(self):
        return self.name


# ── 239: MFCCExtractor ─────────────────────────────────────────────────────
class MFCCExtractor:
    def __init__(self, sample_rate, n_mfcc, n_mels, n_fft, hop_length):
        self.sample_rate = sample_rate
        self.n_mfcc = n_mfcc
        self.n_mels = n_mels
        self.n_fft = n_fft
        self.hop_length = hop_length
        self.mel_spec = MelSpectrogram(sample_rate, n_fft, hop_length, n_mels, 0.0, float(sample_rate) / 2.0)
        self.filterbank = mel_filterbank(n_mels, n_fft, float(sample_rate))
        self.name = "MFCCExtractor"

    def extract(self, waveform):
        var mel = self.mel_spec.compute(waveform)
        var coeffs = mfcc(mel, self.n_mfcc)
        return coeffs

    def extract_delta(self, waveform):
        var coeffs = self.extract(waveform)
        var delta = tensor_diff(coeffs)
        return {"mfcc": coeffs, "delta": delta, "n_coeffs": self.n_mfcc}

    def get_name(self):
        return self.name


# ── 240: WaveNetBlock ──────────────────────────────────────────────────────
class WaveNetBlock:
    def __init__(self, channels, dilation, kernel):
        self.channels = channels
        self.dilation = dilation
        self.kernel = kernel
        self.filter_w = tensor_randn([channels * channels * kernel])
        self.gate_w = tensor_randn([channels * channels * kernel])
        self.res_w = tensor_randn([channels * channels])
        self.skip_w = tensor_randn([channels * channels])
        self.name = "WaveNetBlock"

    def dilated_conv(self, x, weight, dilation):
        if dilation == 1:
            return conv1d(x, weight[:self.kernel])
        var dilated = []
        for i in range(0, len(x)):
            if i % dilation == 0:
                var dilated = dilated + [x[i]]
        var out = conv1d(tensor(dilated), weight[:self.kernel])
        return out

    def forward(self, x, skip_accum):
        var h_filter = self.dilated_conv(x, self.filter_w, self.dilation)
        var h_gate = self.dilated_conv(x, self.gate_w, self.dilation)
        var n = min(len(h_filter), len(h_gate))
        var h = tensor_mul(
            tensor_apply(h_filter[:n], lambda v: tanh_fn(v)),
            tensor_apply(h_gate[:n], lambda v: sigmoid(v))
        )
        var skip_val = tensor_mean(h)
        var res_out = tensor_add(x[:len(h)], h)
        return [res_out, skip_accum + skip_val]

    def get_dilation(self):
        return self.dilation

    def get_name(self):
        return self.name


# ── 241: WaveNet ───────────────────────────────────────────────────────────
class WaveNet:
    def __init__(self, channels, n_layers, n_cycles, n_classes):
        self.channels = channels
        self.n_layers = n_layers
        self.n_cycles = n_cycles
        self.n_classes = n_classes
        self.input_conv_w = tensor_randn([channels * channels])
        self.blocks = []
        for cycle in range(0, n_cycles):
            for layer in range(0, n_layers):
                var dilation = 1
                var d = 1
                for k in range(0, layer):
                    var d = d * 2
                var dilation = d
                self.blocks = self.blocks + [WaveNetBlock(channels, dilation, 2)]
        self.output_w1 = tensor_randn([channels * channels])
        self.output_w2 = tensor_randn([n_classes * channels])
        self.name = "WaveNet"

    def forward(self, x):
        var h = conv1d(x, self.input_conv_w[:3])
        var h = tensor_apply(h, lambda v: relu(v))
        var skip_total = 0.0
        for block in self.blocks:
            var result = block.forward(h, skip_total)
            h = result[0]
            var skip_total = result[1]
        var output = tensor_apply(tensor_randn([self.n_classes]), lambda v: relu(v))
        var output = softmax(output)
        return output

    def n_blocks(self):
        return self.n_layers * self.n_cycles

    def get_name(self):
        return self.name


# ── 242: CTCDecoder ────────────────────────────────────────────────────────
class CTCDecoder:
    def __init__(self, vocab, blank_id):
        self.vocab = vocab
        self.blank_id = blank_id
        self.vocab_size = len(vocab)
        self.name = "CTCDecoder"

    def greedy_decode(self, log_probs_seq):
        var tokens = []
        var prev = self.blank_id
        for frame in log_probs_seq:
            if type(frame) == "list" or type(frame) == "tensor":
                var best = tensor_argmax(softmax(tensor(frame)))
                if best != self.blank_id and best != prev:
                    var tokens = tokens + [best]
                var prev = best
            else:
                var best_id = int(frame) % self.vocab_size
                if best_id != self.blank_id and best_id != prev:
                    tokens = tokens + [best_id]
                prev = best_id
        return tokens

    def decode_to_string(self, token_ids):
        var chars = []
        for tid in token_ids:
            if tid < len(self.vocab):
                var chars = chars + [self.vocab[tid]]
        return chars.join("")

    def compute_loss(self, input_len, target_len):
        return ctc_loss(input_len, target_len)

    def get_name(self):
        return self.name


# ── 243: ASRPipeline ───────────────────────────────────────────────────────
class ASRPipeline:
    def __init__(self, sample_rate, n_mfcc, vocab, model_channels):
        self.sample_rate = sample_rate
        self.n_mfcc = n_mfcc
        self.vocab = vocab
        self.model_channels = model_channels
        self.feature_extractor = MFCCExtractor(sample_rate, n_mfcc, 40, 512, 128)
        self.encoder_w = tensor_randn([model_channels * n_mfcc])
        self.decoder_w = tensor_randn([len(vocab) * model_channels])
        self.ctc_decoder = CTCDecoder(vocab, 0)
        self.name = "ASRPipeline"

    def transcribe(self, waveform):
        var features = self.feature_extractor.extract(waveform)
        var encoded = tensor_randn([self.model_channels])
        var logits_per_frame = []
        var n_frames = max(1, len(features) / self.n_mfcc)
        for i in range(0, n_frames):
            var logits_per_frame = logits_per_frame + [tensor_randn([len(self.vocab)])]
        var token_ids = self.ctc_decoder.greedy_decode(logits_per_frame)
        var text = self.ctc_decoder.decode_to_string(token_ids)
        return {"text": text, "n_frames": n_frames, "n_tokens": len(token_ids)}

    def get_name(self):
        return self.name


# ── 244: TCNLayer (Temporal Convolutional Network) ─────────────────────────
class TCNLayer:
    def __init__(self, in_channels, out_channels, kernel, dilation, dropout):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel = kernel
        self.dilation = dilation
        self.dropout = dropout
        self.conv_w = tensor_randn([out_channels * in_channels * kernel])
        self.bn_gamma = tensor_ones([out_channels])
        self.downsample_w = none
        if in_channels != out_channels:
            self.downsample_w = tensor_randn([out_channels * in_channels])
        self.name = "TCNLayer"

    def causal_conv(self, x):
        var pad_size = (self.kernel - 1) * self.dilation
        var padded = tensor_zeros([pad_size])
        if len(x) > 0:
            var padded = tensor_add(tensor_zeros([pad_size]), tensor_zeros([pad_size]))
        var combined_list = []
        for i in range(0, pad_size):
            var combined_list = combined_list + [0.0]
        for i in range(0, len(x)):
            combined_list = combined_list + [x[i]]
        var combined = tensor(combined_list)
        return conv1d(combined, self.conv_w[:self.kernel])

    def forward(self, x, training):
        var residual = x
        var out = self.causal_conv(x)
        var m = tensor_mean(out)
        var s = max(tensor_std(out), 1e-8)
        var out = tensor_apply(out, lambda v: relu((v - m) / s))
        if training and self.dropout > 0.0:
            var mask = tensor_apply(tensor_rand([len(out)]), lambda v: 1.0 if v > self.dropout else 0.0)
            out = tensor_mul(out, mask)
        if len(out) >= len(residual):
            out = tensor_add(out[:len(residual)], residual)
        return tensor_apply(out, lambda v: relu(v))

    def get_name(self):
        return self.name


# ── 245: TemporalConvNet ────────────────────────────────────────────────────
class TemporalConvNet:
    def __init__(self, input_size, channel_sizes, kernel, dropout):
        self.input_size = input_size
        self.channel_sizes = channel_sizes
        self.kernel = kernel
        self.dropout = dropout
        self.layers = []
        var n_levels = len(channel_sizes)
        for i in range(0, n_levels):
            var in_ch = input_size if i == 0 else channel_sizes[i - 1]
            var out_ch = channel_sizes[i]
            var dilation = 1
            var d = 1
            for k in range(0, i):
                var d = d * 2
            var dilation = d
            self.layers = self.layers + [TCNLayer(in_ch, out_ch, kernel, dilation, dropout)]
        self.name = "TemporalConvNet"

    def forward(self, x, training):
        var h = x
        for layer in self.layers:
            var h = layer.forward(h, training)
        return h

    def n_layers(self):
        return len(self.layers)

    def get_name(self):
        return self.name


# ── 246: ARIMAModel ────────────────────────────────────────────────────────
class ARIMAModel:
    def __init__(self, p, d, q):
        self.p = p   # AR order
        self.d = d   # differencing order
        self.q = q   # MA order
        self.ar_coefs = tensor_zeros([p])
        self.ma_coefs = tensor_zeros([q])
        self.intercept = 0.0
        self.residuals = []
        self.fitted_values = []
        self.aic = 0.0
        self.bic = 0.0
        self.name = "ARIMAModel"

    def difference(self, series, order):
        var diff = series
        for d in range(0, order):
            var diff = tensor_diff(diff)
        return diff

    def fit(self, series):
        var diff_series = self.difference(series, self.d)
        var n = len(diff_series)
        var mean = tensor_mean(diff_series)
        self.intercept = mean
        for i in range(0, self.p):
            self.ar_coefs[i] = tensor_std(diff_series) * 0.1 * float(i + 1)
        for i in range(0, self.q):
            self.ma_coefs[i] = tensor_std(diff_series) * 0.05
        var n_params = float(self.p + self.q + 1)
        self.aic = 2.0 * n_params - 2.0 * float(n) * log(max(tensor_std(diff_series), 1e-8))
        self.bic = n_params * log(float(n)) - 2.0 * float(n) * log(max(tensor_std(diff_series), 1e-8))
        self.fitted_values = tensor_apply(diff_series, lambda v: v * 0.95 + mean * 0.05)
        return self

    def forecast(self, n_steps):
        var preds = []
        var history = self.fitted_values
        for step in range(0, n_steps):
            var pred = self.intercept
            for i in range(0, self.p):
                var lag = len(history) - 1 - i
                if lag >= 0:
                    var pred = pred + self.ar_coefs[i] * history[lag]
            var preds = preds + [pred]
            var history = tensor_add(history, tensor([pred]))
        return tensor(preds)

    def get_info(self):
        return {"p": self.p, "d": self.d, "q": self.q, "aic": self.aic, "bic": self.bic}

    def get_name(self):
        return self.name


# ── 247: TimeSeriesTransformer ─────────────────────────────────────────────
class TimeSeriesTransformer:
    def __init__(self, input_dim, d_model, n_heads, n_layers, pred_len, dropout):
        self.input_dim = input_dim
        self.d_model = d_model
        self.n_heads = n_heads
        self.n_layers = n_layers
        self.pred_len = pred_len
        self.dropout = dropout
        self.input_proj = tensor_randn([d_model * input_dim])
        self.encoder_layers = []
        for i in range(0, n_layers):
            self.encoder_layers = self.encoder_layers + [tensor_randn([d_model * d_model * 4])]
        self.output_proj = tensor_randn([pred_len * d_model])
        self.name = "TimeSeriesTransformer"

    def encode(self, x):
        var h = tensor_randn([self.d_model])
        for w in self.encoder_layers:
            var attn = tensor_randn([self.d_model])
            var ff = tensor_randn([self.d_model])
            var h = tensor_add(attn, ff)
        return h

    def forecast(self, history):
        var h = self.encode(history)
        var preds = []
        for i in range(0, self.pred_len):
            var preds = preds + [tensor_mean(h) + tensor_mean(tensor_randn([4])) * 0.1]
        return tensor(preds)

    def get_name(self):
        return self.name


# ── 248: ExperimentTracker ─────────────────────────────────────────────────
class ExperimentTracker:
    def __init__(self, experiment_name, tags):
        self.experiment_name = experiment_name
        self.tags = tags
        self.runs = {}
        self.current_run = ""
        self.run_count = 0
        self.name = "ExperimentTracker"

    def start_run(self, run_name):
        self.current_run = run_name
        self.runs[run_name] = {
            "metrics": {},
            "params": {},
            "artifacts": [],
            "status": "running",
            "step": 0
        }
        self.run_count = self.run_count + 1
        return run_name

    def log_param(self, key, value):
        if self.current_run in self.runs:
            self.runs[self.current_run]["params"][key] = value

    def log_metric(self, key, value, step):
        if self.current_run in self.runs:
            var run = self.runs[self.current_run]
            if key not in run["metrics"]:
                run["metrics"][key] = []
            run["metrics"][key] = run["metrics"][key] + [{"step": step, "value": value}]
            run["step"] = step

    def log_artifact(self, path):
        if self.current_run in self.runs:
            self.runs[self.current_run]["artifacts"] = self.runs[self.current_run]["artifacts"] + [path]

    def end_run(self, status):
        if self.current_run in self.runs:
            self.runs[self.current_run]["status"] = status

    def get_best_run(self, metric, mode):
        var best_name = ""
        var best_val = 0.0
        if mode == "min":
            var best_val = 1e18
        else:
            best_val = 0.0 - 1e18
        for run_name in self.runs:
            var run = self.runs[run_name]
            if metric in run["metrics"]:
                var history = run["metrics"][metric]
                if len(history) > 0:
                    var last_val = history[len(history) - 1]["value"]
                    if mode == "min" and last_val < best_val:
                        best_val = last_val
                        var best_name = run_name
                    elif mode == "max" and last_val > best_val:
                        best_val = last_val
                        best_name = run_name
        return {"run": best_name, "value": best_val}

    def get_name(self):
        return self.name


# ── 249: MetricsCollector ──────────────────────────────────────────────────
class MetricsCollector:
    def __init__(self, name, window_size):
        self.name = name
        self.window_size = window_size
        self.metrics = {}
        self.counters = {}
        self.gauges = {}
        self.histograms = {}
        self.total_updates = 0

    def record(self, metric_name, value):
        if metric_name not in self.metrics:
            self.metrics[metric_name] = []
        self.metrics[metric_name] = self.metrics[metric_name] + [value]
        if len(self.metrics[metric_name]) > self.window_size:
            self.metrics[metric_name] = self.metrics[metric_name][1:]
        self.total_updates = self.total_updates + 1

    def increment(self, counter_name, amount):
        if counter_name not in self.counters:
            self.counters[counter_name] = 0.0
        self.counters[counter_name] = self.counters[counter_name] + amount

    def set_gauge(self, gauge_name, value):
        self.gauges[gauge_name] = value

    def summary(self, metric_name):
        if metric_name not in self.metrics or len(self.metrics[metric_name]) == 0:
            return {"mean": 0.0, "min": 0.0, "max": 0.0, "count": 0}
        var vals = tensor(self.metrics[metric_name])
        return {
            "mean": tensor_mean(vals),
            "min": tensor_min(vals),
            "max": tensor_max(vals),
            "std": tensor_std(vals),
            "count": len(self.metrics[metric_name])
        }

    def all_summaries(self):
        var result = {}
        for key in self.metrics:
            result[key] = self.summary(key)
        return result

    def get_name(self):
        return self.name


# ── 250: AlertManager ─────────────────────────────────────────────────────
class AlertManager:
    def __init__(self, name):
        self.name = name
        self.rules = []
        self.alerts = []
        self.silenced = []
        self.total_fired = 0

    def add_rule(self, rule_name, metric, op, threshold, severity):
        self.rules = self.rules + [{
            "name": rule_name,
            "metric": metric,
            "op": op,
            "threshold": threshold,
            "severity": severity,
            "firing": false
        }]

    def check(self, metrics_snapshot):
        var new_alerts = []
        for i in range(0, len(self.rules)):
            var rule = self.rules[i]
            var metric = rule["metric"]
            if metric in metrics_snapshot:
                var val = metrics_snapshot[metric]
                var fired = false
                if rule["op"] == ">" and val > rule["threshold"]:
                    var fired = true
                elif rule["op"] == "<" and val < rule["threshold"]:
                    fired = true
                elif rule["op"] == ">=" and val >= rule["threshold"]:
                    fired = true
                elif rule["op"] == "<=" and val <= rule["threshold"]:
                    fired = true
                elif rule["op"] == "==" and val == rule["threshold"]:
                    fired = true
                if fired and rule["name"] not in self.silenced:
                    var alert = {"rule": rule["name"], "metric": metric, "value": val, "severity": rule["severity"]}
                    var new_alerts = new_alerts + [alert]
                    self.alerts = self.alerts + [alert]
                    self.total_fired = self.total_fired + 1
        return new_alerts

    def silence(self, rule_name):
        self.silenced = self.silenced + [rule_name]

    def active_alerts(self):
        return self.alerts[max(0, len(self.alerts) - 10):]

    def get_name(self):
        return self.name


# ── 251: ModelMonitor ──────────────────────────────────────────────────────
class ModelMonitor:
    def __init__(self, model_name, baseline_metrics):
        self.model_name = model_name
        self.baseline_metrics = baseline_metrics
        self.metrics_history = []
        self.drift_detector = DriftDetector(50, 0.1)
        self.alert_manager = AlertManager("model_alerts")
        self.prediction_count = 0
        self.error_count = 0
        self.latency_history = []
        self.name = "ModelMonitor"

        self.alert_manager.add_rule("high_error_rate", "error_rate", ">", 0.1, "critical")
        self.alert_manager.add_rule("high_latency", "avg_latency_ms", ">", 100.0, "warning")
        self.alert_manager.add_rule("low_accuracy", "accuracy", "<", 0.8, "warning")

    def record_prediction(self, predicted, actual, latency_ms):
        self.prediction_count = self.prediction_count + 1
        var is_error = 0.0
        if abs(predicted - actual) > 0.5:
            var is_error = 1.0
            self.error_count = self.error_count + 1
        self.latency_history = self.latency_history + [latency_ms]
        if len(self.latency_history) > 1000:
            self.latency_history = self.latency_history[1:]
        self.drift_detector.update(predicted - actual)

    def get_snapshot(self):
        var error_rate = 0.0
        if self.prediction_count > 0:
            var error_rate = float(self.error_count) / float(self.prediction_count)
        var avg_latency = 0.0
        if len(self.latency_history) > 0:
            for l in self.latency_history:
                var avg_latency = avg_latency + l
            avg_latency = avg_latency / float(len(self.latency_history))
        var accuracy = 1.0 - error_rate
        return {
            "error_rate": error_rate,
            "avg_latency_ms": avg_latency,
            "accuracy": accuracy,
            "predictions": self.prediction_count,
            "drift_detected": self.drift_detector.drift_detected
        }

    def check_health(self):
        var snapshot = self.get_snapshot()
        var alerts = self.alert_manager.check(snapshot)
        return {"snapshot": snapshot, "alerts": alerts, "n_alerts": len(alerts)}

    def get_name(self):
        return self.name


# ── 252: DatasetBuilder ────────────────────────────────────────────────────
class DatasetBuilder:
    def __init__(self, name, schema):
        self.name = name
        self.schema = schema   # dict of field_name -> type
        self.records = []
        self.splits = {}
        self.transforms = []
        self.label_encoders = {}
        self.total_added = 0

    def add_record(self, record):
        self.records = self.records + [record]
        self.total_added = self.total_added + 1

    def add_transform(self, field, transform_fn):
        self.transforms = self.transforms + [{"field": field, "fn": transform_fn}]

    def fit_label_encoder(self, field):
        var seen = []
        for record in self.records:
            if field in record:
                var val = str(record[field])
                if val not in seen:
                    var seen = seen + [val]
        var encoder = {}
        for i in range(0, len(seen)):
            encoder[seen[i]] = i
        self.label_encoders[field] = encoder
        return encoder

    def build(self, train_frac, val_frac, test_frac):
        var n = len(self.records)
        var n_train = int(float(n) * train_frac)
        var n_val = int(float(n) * val_frac)
        self.splits = {
            "train": self.records[:n_train],
            "val": self.records[n_train:n_train + n_val],
            "test": self.records[n_train + n_val:]
        }
        return self.splits

    def stats(self):
        return {"total": self.total_added, "splits": len(self.splits), "transforms": len(self.transforms)}

    def get_name(self):
        return self.name


# ── 253: DataSampler ──────────────────────────────────────────────────────
class DataSampler:
    def __init__(self, strategy, seed):
        self.strategy = strategy   # "random", "weighted", "stratified", "oversampling"
        self.seed = seed
        self.weights = []
        self.class_counts = {}
        self.total_sampled = 0
        self.name = "DataSampler"

    def set_weights(self, weights):
        self.weights = weights

    def compute_class_weights(self, labels):
        for label in labels:
            var key = str(label)
            if key not in self.class_counts:
                self.class_counts[key] = 0
            self.class_counts[key] = self.class_counts[key] + 1
        var n = len(labels)
        var inv_weights = []
        for label in labels:
            var key = str(label)
            var count = self.class_counts[key]
            var inv_weights = inv_weights + [float(n) / (float(count) * float(len(self.class_counts)) + 1e-8)]
        return tensor(inv_weights)

    def sample(self, data, n):
        var indices = []
        var m = len(data)
        if m == 0:
            return []
        for i in range(0, n):
            var idx = (i * 7 + self.seed) % m
            var indices = indices + [idx]
        var sampled = []
        for idx in indices:
            var sampled = sampled + [data[idx]]
        self.total_sampled = self.total_sampled + n
        return sampled

    def bootstrap_sample(self, data):
        return self.sample(data, len(data))

    def get_name(self):
        return self.name


# ── 254: DataAugmenter ────────────────────────────────────────────────────
class DataAugmenter:
    def __init__(self, augmentation_prob):
        self.augmentation_prob = augmentation_prob
        self.augmentations = []
        self.applied_count = 0
        self.name = "DataAugmenter"

    def add_augmentation(self, name, aug_fn, prob):
        self.augmentations = self.augmentations + [{"name": name, "fn": aug_fn, "prob": prob}]

    def augment(self, x, step):
        var out = x
        for aug in self.augmentations:
            var r = float((step * 31 + 17) % 100) / 100.0
            if r < aug["prob"] * self.augmentation_prob:
                var out = aug["fn"](out)
                self.applied_count = self.applied_count + 1
        return out

    def augment_batch(self, batch, step):
        var result = []
        for i in range(0, len(batch)):
            var result = result + [self.augment(batch[i], step + i)]
        return result

    def stats(self):
        return {"augmentations": len(self.augmentations), "applied": self.applied_count}

    def get_name(self):
        return self.name


# ── 255: TensorboardWriter ────────────────────────────────────────────────
class TensorboardWriter:
    def __init__(self, log_dir, flush_secs):
        self.log_dir = log_dir
        self.flush_secs = flush_secs
        self.scalars = {}
        self.histograms = {}
        self.images = []
        self.texts = []
        self.global_step = 0
        self.name = "TensorboardWriter"

    def add_scalar(self, tag, value, step):
        if tag not in self.scalars:
            self.scalars[tag] = []
        self.scalars[tag] = self.scalars[tag] + [{"step": step, "value": value}]
        if step > self.global_step:
            self.global_step = step

    def add_scalars(self, main_tag, tag_scalar_dict, step):
        for tag in tag_scalar_dict:
            self.add_scalar(main_tag + "/" + tag, tag_scalar_dict[tag], step)

    def add_histogram(self, tag, values, step):
        if tag not in self.histograms:
            self.histograms[tag] = []
        var hist_summary = {
            "step": step,
            "mean": tensor_mean(values),
            "std": tensor_std(values),
            "min": tensor_min(values),
            "max": tensor_max(values)
        }
        self.histograms[tag] = self.histograms[tag] + [hist_summary]

    def add_text(self, tag, text, step):
        self.texts = self.texts + [{"tag": tag, "text": text, "step": step}]

    def get_scalar_history(self, tag):
        if tag in self.scalars:
            return self.scalars[tag]
        return []

    def flush(self):
        return {"scalars": len(self.scalars), "histograms": len(self.histograms), "step": self.global_step}

    def get_name(self):
        return self.name


# ── 256: CheckpointManager ────────────────────────────────────────────────
class CheckpointManager:
    def __init__(self, save_dir, max_to_keep, monitor_metric, mode):
        self.save_dir = save_dir
        self.max_to_keep = max_to_keep
        self.monitor_metric = monitor_metric
        self.mode = mode   # "min" or "max"
        self.checkpoints = []
        self.best_value = 0.0
        self.best_path = ""
        self.save_count = 0
        if mode == "min":
            self.best_value = 1e18
        else:
            self.best_value = 0.0 - 1e18
        self.name = "CheckpointManager"

    def save(self, model_state, metric_value, step):
        var path = self.save_dir + "/ckpt_step_" + str(step) + ".ny"
        var checkpoint = {"path": path, "value": metric_value, "step": step, "state_size": len(str(model_state))}
        self.checkpoints = self.checkpoints + [checkpoint]
        self.save_count = self.save_count + 1
        var is_best = false
        if self.mode == "min" and metric_value < self.best_value:
            self.best_value = metric_value
            self.best_path = path
            var is_best = true
        elif self.mode == "max" and metric_value > self.best_value:
            self.best_value = metric_value
            self.best_path = path
            is_best = true
        if len(self.checkpoints) > self.max_to_keep:
            self.checkpoints = self.checkpoints[len(self.checkpoints) - self.max_to_keep:]
        return {"path": path, "is_best": is_best, "best_value": self.best_value}

    def load_best(self):
        return {"path": self.best_path, "value": self.best_value}

    def list_checkpoints(self):
        return self.checkpoints

    def get_name(self):
        return self.name


# ── 257: LearningRateFinder ───────────────────────────────────────────────
class LearningRateFinder:
    def __init__(self, model, optimizer, min_lr, max_lr, n_steps):
        self.model = model
        self.optimizer = optimizer
        self.min_lr = min_lr
        self.max_lr = max_lr
        self.n_steps = n_steps
        self.lrs = []
        self.losses = []
        self.best_lr = min_lr
        self.name = "LearningRateFinder"

    def compute_lr(self, step):
        var ratio = float(step) / float(self.n_steps)
        return self.min_lr * (self.max_lr / self.min_lr) ** ratio

    def run(self, data_iterator):
        self.lrs = []
        self.losses = []
        var smoothed_loss = 1e9
        var beta = 0.98
        for step in range(0, self.n_steps):
            var lr = self.compute_lr(step)
            var loss = abs(tensor_mean(tensor_randn([8]))) + 1.0 / (1.0 + float(step))
            var smoothed_loss = beta * smoothed_loss + (1.0 - beta) * loss
            self.lrs = self.lrs + [lr]
            self.losses = self.losses + [smoothed_loss]
        var best_step = 0
        var best_rate = 0.0
        var min_loss = 1e18
        for i in range(1, len(self.losses) - 1):
            if self.losses[i] < min_loss:
                var min_loss = self.losses[i]
                var best_step = i
        if best_step > 0:
            self.best_lr = self.lrs[best_step - 1]
        else:
            self.best_lr = self.lrs[0] if len(self.lrs) > 0 else self.min_lr
        return {"best_lr": self.best_lr, "min_loss": min_loss, "n_steps": self.n_steps}

    def plot_summary(self):
        if len(self.lrs) == 0:
            return "No data - run first"
        return "LR range: [" + str(self.lrs[0]) + ", " + str(self.lrs[len(self.lrs) - 1]) + "] best_lr=" + str(self.best_lr)

    def get_name(self):
        return self.name


# ── 258: GradientAnalyzer ─────────────────────────────────────────────────
class GradientAnalyzer:
    def __init__(self, model_name, track_norms, track_histogram):
        self.model_name = model_name
        self.track_norms = track_norms
        self.track_histogram = track_histogram
        self.grad_norms = {}
        self.grad_stats = {}
        self.explosion_events = 0
        self.vanish_events = 0
        self.norm_threshold_high = 10.0
        self.norm_threshold_low = 1e-7
        self.step = 0
        self.name = "GradientAnalyzer"

    def record_grads(self, layer_name, grad_tensor):
        var norm = tensor_norm(grad_tensor)
        if layer_name not in self.grad_norms:
            self.grad_norms[layer_name] = []
        self.grad_norms[layer_name] = self.grad_norms[layer_name] + [norm]
        self.grad_stats[layer_name] = {
            "mean": tensor_mean(grad_tensor),
            "std": tensor_std(grad_tensor),
            "norm": norm,
            "min": tensor_min(grad_tensor),
            "max": tensor_max(grad_tensor)
        }
        if norm > self.norm_threshold_high:
            self.explosion_events = self.explosion_events + 1
        if norm < self.norm_threshold_low and norm > 0.0:
            self.vanish_events = self.vanish_events + 1
        self.step = self.step + 1

    def detect_problems(self):
        var problems = []
        if self.explosion_events > 0:
            var problems = problems + ["gradient_explosion: " + str(self.explosion_events) + " events"]
        if self.vanish_events > 0:
            problems = problems + ["gradient_vanishing: " + str(self.vanish_events) + " events"]
        return problems

    def summary(self):
        var layer_norms = {}
        for layer in self.grad_norms:
            var norms = self.grad_norms[layer]
            if len(norms) > 0:
                var avg = 0.0
                for n in norms:
                    var avg = avg + n
                layer_norms[layer] = avg / float(len(norms))
        return {
            "layers_tracked": len(self.grad_norms),
            "explosion_events": self.explosion_events,
            "vanish_events": self.vanish_events,
            "avg_norms_per_layer": layer_norms
        }

    def get_name(self):
        return self.name


# ── 259: ProfilerSession ──────────────────────────────────────────────────
class ProfilerSession:
    def __init__(self, name, enabled):
        self.name = name
        self.enabled = enabled
        self.events = []
        self.active_timers = {}
        self.total_time = {}
        self.call_count = {}
        self.memory_snapshots = []

    def start_event(self, event_name):
        if not self.enabled:
            return
        self.active_timers[event_name] = float(len(self.events)) * 0.001

    def end_event(self, event_name):
        if not self.enabled:
            return
        var elapsed = 0.001
        if event_name not in self.total_time:
            self.total_time[event_name] = 0.0
            self.call_count[event_name] = 0
        self.total_time[event_name] = self.total_time[event_name] + elapsed
        self.call_count[event_name] = self.call_count[event_name] + 1
        self.events = self.events + [{"name": event_name, "elapsed_ms": elapsed * 1000.0}]

    def record_memory(self, label, bytes_used):
        self.memory_snapshots = self.memory_snapshots + [{"label": label, "bytes": bytes_used}]

    def report(self):
        var hotspots = []
        for event in self.total_time:
            var hotspots = hotspots + [{"name": event, "total_ms": self.total_time[event] * 1000.0, "calls": self.call_count[event]}]
        return {"total_events": len(self.events), "hotspots": hotspots, "memory_snapshots": len(self.memory_snapshots)}

    def get_name(self):
        return self.name


# ── 260: HyperparameterBayesOpt ────────────────────────────────────────────
class HyperparameterBayesOpt:
    def __init__(self, param_bounds, n_initial, acquisition):
        self.param_bounds = param_bounds   # dict: param -> [low, high]
        self.n_initial = n_initial
        self.acquisition = acquisition   # "ei", "ucb", "pi"
        self.observations_x = []
        self.observations_y = []
        self.best_x = {}
        self.best_y = 1e18
        self.iteration = 0
        self.name = "HyperparameterBayesOpt"

    def _random_sample(self):
        var params = {}
        for key in self.param_bounds:
            var bounds = self.param_bounds[key]
            var lo = bounds[0]
            var hi = bounds[1]
            var r = float(self.iteration * 7919 + 17) % 1000.0 / 1000.0
            params[key] = lo + (hi - lo) * r
        return params

    def _surrogate_mean(self, x):
        if len(self.observations_y) == 0:
            return 0.0
        var total = 0.0
        for y in self.observations_y:
            var total = total + y
        return total / float(len(self.observations_y))

    def _acquisition_value(self, x):
        var mu = self._surrogate_mean(x)
        var sigma = 0.1 + 0.01 * float(self.iteration)
        if self.acquisition == "ucb":
            return mu - 2.0 * sigma
        elif self.acquisition == "ei":
            var z = (self.best_y - mu) / max(sigma, 1e-8)
            return 0.0 - (self.best_y - mu) * sigmoid(z) + sigma * 0.4
        return mu

    def suggest(self):
        self.iteration = self.iteration + 1
        if self.iteration <= self.n_initial:
            return self._random_sample()
        var best_cand = self._random_sample()
        var best_acq = self._acquisition_value(best_cand)
        for i in range(0, 10):
            var cand = self._random_sample()
            var acq = self._acquisition_value(cand)
            if acq < best_acq:
                var best_acq = acq
                var best_cand = cand
        return best_cand

    def observe(self, x, y):
        self.observations_x = self.observations_x + [x]
        self.observations_y = self.observations_y + [y]
        if y < self.best_y:
            self.best_y = y
            self.best_x = x

    def best(self):
        return {"params": self.best_x, "value": self.best_y, "n_observations": len(self.observations_y)}

    def get_name(self):
        return self.name


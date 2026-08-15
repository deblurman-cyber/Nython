# ─── examples/lib/nn.ny ──────────────────────────────────────────────────────
# A single dense layer, enough for the v14/v15 examples. Weights are fixed
# rather than random so the examples are reproducible: a test that asserts on a
# forward pass cannot depend on an unseeded RNG.

import "examples/lib/tensor.ny"

class Linear:
    def __init__(self, in_features, out_features):
        self.in_features = in_features
        self.out_features = out_features
        self.weights = []
        self.bias = []
        var o = 0
        while o < out_features:
            var row = []
            var i = 0
            while i < in_features:
                # Deterministic, spread over a small range.
                row.append(float((o * in_features + i) % 7 + 1) / 10.0)
                i = i + 1
            self.weights.append(row)
            self.bias.append(0.0)
            o = o + 1

    def forward(self, x):
        var out = []
        var o = 0
        while o < self.out_features:
            var acc = self.bias[o]
            var i = 0
            while i < self.in_features and i < len(x.data):
                acc = acc + x.data[i] * self.weights[o][i]
                i = i + 1
            out.append(acc)
            o = o + 1
        return Tensor(out)

    def __str__(self):
        return "Linear(" + str(self.in_features) + " -> " + str(self.out_features) + ")"

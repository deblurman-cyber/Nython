# ─── examples/lib/tensor.ny ──────────────────────────────────────────────────
# A small 1-D tensor used by the v14/v15 example suites. Independent of
# lib/nytorch/, which is the full package; this is the minimal type those two
# examples exercise.
#
# The file was referenced by both examples and did not exist. A module that
# could not be found used to resolve silently, so the examples failed later on
# `Tensor is not defined` with nothing indicating the import was the cause.

class Tensor:
    def __init__(self, data):
        self.data = data
        self.size = len(data)


    # These examples build tensors from float literals (Tensor([1.0, 2.0, 3.0]))
    # but assert on integer output (Tensor([5, 7, 9]), dot == 32). Whole-valued
    # floats are therefore normalised to integers on the way out, which is the
    # convention the examples were written against. Fractional values are left
    # untouched.
    def _norm(self, v):
        if v == int(v):
            return int(v)
        return v

    def _norm_list(self, xs):
        var out = []
        var i = 0
        while i < len(xs):
            out.append(self._norm(xs[i]))
            i = i + 1
        return out

    def __add__(self, other):
        var out = []
        var i = 0
        while i < self.size:
            out.append(self.data[i] + other.data[i])
            i = i + 1
        return Tensor(out)

    def __sub__(self, other):
        var out = []
        var i = 0
        while i < self.size:
            out.append(self.data[i] - other.data[i])
            i = i + 1
        return Tensor(out)

    # Elementwise, not matrix multiply: the examples expect
    # Tensor([1,2,3,4]) * Tensor([5,6,7,8]) == Tensor([5,12,21,32]).
    def __mul__(self, other):
        var out = []
        var i = 0
        while i < self.size:
            out.append(self.data[i] * other.data[i])
            i = i + 1
        return Tensor(out)

    def scale(self, k):
        var out = []
        var i = 0
        while i < self.size:
            out.append(self.data[i] * k)
            i = i + 1
        return Tensor(out)

    def dot(self, other):
        var acc = 0
        var i = 0
        while i < self.size:
            acc = acc + self.data[i] * other.data[i]
            i = i + 1
        return self._norm(acc)

    def sum(self):
        var acc = 0
        var i = 0
        while i < self.size:
            acc = acc + self.data[i]
            i = i + 1
        return self._norm(acc)

    def mean(self):
        if self.size == 0:
            return 0
        return self._norm(self.sum() / self.size)

    def get(self, i):
        return self._norm(self.data[i])

    # t[0] — the examples index tensors directly.
    def __getitem__(self, i):
        return self._norm(self.data[i])

    def __len__(self):
        return self.size

    def __str__(self):
        return "Tensor(" + str(self._norm_list(self.data)) + ")"

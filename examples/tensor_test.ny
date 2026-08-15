class Tensor:
    def init(self, data):
        if type(data) == "list":
            self.data = tensor(data)
            self.shape = [len(data)]
        else:
            self.data = data
            self.shape = [len(data)]
    def __add__(self, other):
        return Tensor(tensor_add(self.data, other.data))
    def __sub__(self, other):
        return Tensor(tensor_sub(self.data, other.data))
    def __mul__(self, other):
        return Tensor(tensor_mul(self.data, other.data))
    def dot(self, other):
        return tensor_dot(self.data, other.data)
    def sum(self):
        return tensor_sum(self.data)
    def mean(self):
        return tensor_mean(self.data)
    def __str__(self):
        return "Tensor(" + str(self.data) + ")"

class LinkedList:
    def init(self):
        self.head = none
        self.size = 0
    def prepend(self, val):
        var node = {"val": val, "next": self.head}
        self.head = node
        self.size = self.size + 1
    def to_list(self):
        var result = []
        var current = self.head
        var i = 0
        while i < self.size:
            result.append(current["val"])
            current = current["next"]
            i = i + 1
        return result

var ll = LinkedList()
ll.prepend(3)
ll.prepend(2)
ll.prepend(1)
print ll.to_list()
print ll.size

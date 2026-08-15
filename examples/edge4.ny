class Node:
    def init(self, val, next_node):
        self.val = val
        self.next = next_node
    def to_list(self):
        var result = []
        var current = self
        while current != none:
            result.append(current.val)
            current = current.next
        return result

var list = Node(1, Node(2, Node(3, none)))
print list.to_list()

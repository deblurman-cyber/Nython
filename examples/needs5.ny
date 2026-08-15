class TreeNode:
    def init(self, val):
        self.val = val
        self.left = none
        self.right = none

def inorder(node):
    if node == none:
        return []
    var result = []
    var left = inorder(node.left)
    for item in left:
        result.append(item)
    result.append(node.val)
    var right = inorder(node.right)
    for item in right:
        result.append(item)
    return result

var root = TreeNode(5)
root.left = TreeNode(3)
root.right = TreeNode(7)
root.left.left = TreeNode(1)
root.left.right = TreeNode(4)
print inorder(root)

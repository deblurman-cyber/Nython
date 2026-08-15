# Fixture for the import-system test. Deliberately small, with one name of each
# kind so the alias namespace can be checked for completeness.
var DEMO_VERSION = "2.1"

def demo_add(a, b):
    return a + b

class DemoBox:
    def __init__(self, v):
        self.v = v
    def get(self):
        return self.v

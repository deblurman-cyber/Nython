# main.ny
# main.ny
class
import "lib/gui.ny"

class App:
    def __init__(self, title):
        self.title = title
        self.count = 0

    def tick(self):
        self.count = self.count + 1
        return self.count

var app = App("Nython")
print app.tick()
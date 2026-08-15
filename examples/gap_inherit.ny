def make_list():
    var items = []
    def add(x):
        items.append(x)
    def get():
        return items
    return {"add": add, "get": get}

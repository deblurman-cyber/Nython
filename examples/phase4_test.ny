def make_iterator(items):
    var idx = 0
    def has_next():
        return idx < len(items)
    def next_val():
        var v = items[idx]
        idx = idx + 1
        return v
    return {"has_next": has_next, "next": next_val}

var it = make_iterator([10, 20, 30, 40])
while it["has_next"]():
    print it["next"]()

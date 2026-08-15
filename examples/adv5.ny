var words = ["hello", "world", "foo", "bar", "baz"]
def starts_with_b(s):
    return s.startswith("b")
print words.filter(starts_with_b)
def to_upper(s):
    return s.upper()
print words.map(to_upper)

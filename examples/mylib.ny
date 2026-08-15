# ─── examples/mylib.ny ───────────────────────────────────────────────────────
# Demo module for the import examples.
#
# import_test.ny calls greet() and square(); import2.ny calls lib_greet() and
# reads LIB_VERSION. Only the first pair existed, so import2 failed on an
# undefined name — silently, until undefined calls started raising NameError.
# Both naming styles are provided rather than editing the examples.

var LIB_VERSION = "1.0.0"

def greet(name):
    return "Hello, " + name + "!"

def square(x):
    return x * x

var VERSION = 1


# Prefixed aliases used by import2.ny.
def lib_greet(name):
    return greet(name)

def lib_square(x):
    return square(x)

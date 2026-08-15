# ─── examples/lib/io.ny ──────────────────────────────────────────────────────
# Object wrappers over the io builtins: File (usable with `with`), TextFile and
# Logger.
#
# `ctx_io_test.ny` and `oop_io_test.ny` import this file, but it did not exist.
# Because a module that could not be found used to resolve silently, both
# examples appeared to import successfully and then failed on
# `File is not defined` with nothing pointing at the missing import. The API
# below is exactly what those two examples call, and nothing more.

class File:
    def __init__(self, path, mode):
        self.path = path
        self.mode = mode
        self.closed = false
        self.buffer = ""
        # "w" truncates on open, the way a real file handle does; "a" and "r"
        # leave whatever is already there.
        if mode == "w":
            write_file(path, "")

    # `with File(...) as f` calls these.
    def __enter__(self):
        return self

    def __exit__(self):
        self.close()
        return false

    def write(self, text):
        if self.closed:
            return false
        self.buffer = self.buffer + text
        # Append rather than overwrite, so two writes in one block both survive.
        append_file(self.path, text)
        return true

    def read(self):
        return read_file(self.path)

    def close(self):
        self.closed = true
        return true

    def __str__(self):
        var state = "open"
        if self.closed:
            state = "closed"
        return "File(" + self.path + ", " + self.mode + ", " + state + ")"


class TextFile:
    def __init__(self, path):
        self.path = path

    def write(self, text):
        write_file(self.path, text)
        return true

    def append(self, text):
        append_file(self.path, text)
        return true

    def read(self):
        return read_file(self.path)

    def lines(self):
        var t = self.read()
        if t == none or len(t) == 0:
            return []
        return string_split(t, "\n")

    def size(self):
        var t = self.read()
        if t == none:
            return 0
        return len(t)

    def exists(self):
        return path_exists(self.path)

    def delete(self):
        return file_delete(self.path)

    def __str__(self):
        return "TextFile(" + self.path + ")"


class Logger:
    def __init__(self, path):
        self.path = path
        self.count = 0
        write_file(path, "")

    def _emit(self, level, msg):
        self.count = self.count + 1
        append_file(self.path, "[" + level + "] " + msg + "\n")
        return true

    def info(self, msg):
        return self._emit("INFO", msg)

    def warn(self, msg):
        return self._emit("WARN", msg)

    def error(self, msg):
        return self._emit("ERROR", msg)

    # Trailing newline would otherwise produce a final empty entry, which shows
    # up as a phantom blank line in every caller that prints these.
    def lines(self):
        var t = read_file(self.path)
        if t == none or len(t) == 0:
            return []
        var parts = string_split(t, "\n")
        var out = []
        var i = 0
        while i < len(parts):
            if len(parts[i]) > 0:
                out.append(parts[i])
            i = i + 1
        return out

    def clear(self):
        write_file(self.path, "")
        self.count = 0
        return true

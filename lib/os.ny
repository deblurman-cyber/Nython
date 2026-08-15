# ═══════════════════════════════════════════════════════════════════════════════
import nytorch
import os

# os.ny — Operating System Interface Library
# Filesystem, processes, environment, paths, temp files, permissions, …
# Usage: import "lib/os.ny"
# ═══════════════════════════════════════════════════════════════════════════════

class Path:
    def join(self, a, b):
        return os_path_join(a, b)
    def basename(self, p):
        return os_path_basename(p)
    def dirname(self, p):
        return os_path_dirname(p)
    def extension(self, p):
        return os_path_ext(p)
    def abspath(self, p):
        return os_path_abs(p)
    def exists(self, p):
        return os_exists(p)
    def is_file(self, p):
        return os_isfile(p)
    def is_dir(self, p):
        return os_isdir(p)
    def without_ext(self, p):
        var ext = self.extension(p)
        if len(ext) == 0:
            return p
        return p[0:len(p) - len(ext)]
    def normalize(self, p):
        var result = string_replace(p, "\\", "/")
        while string_contains(result, "//"):
            result = string_replace(result, "//", "/")
        return result

class FileSystem:
    def __init__(self):
        self.path = Path()
    def read(self, filepath):
        return read_file(filepath)
    def write(self, filepath, content):
        return write_file(filepath, content)
    def append(self, filepath, content):
        return append_text(filepath, content)
    def delete(self, filepath):
        return os_remove(filepath)
    def rename(self, src, dst):
        return os_rename(src, dst)
    def copy(self, src, dst):
        var content = self.read(src)
        if content == none:
            return false
        return self.write(dst, content)
    def move(self, src, dst):
        if self.copy(src, dst):
            return self.delete(src)
        return false
    def mkdir(self, dirpath):
        return os_mkdir(dirpath)
    def listdir(self, dirpath):
        return os_listdir(dirpath)
    def listdir_full(self, dirpath):
        var entries = os_listdir(dirpath)
        var result = []
        var i = 0
        while i < len(entries):
            result.append(os_path_join(dirpath, entries[i]))
        return result
    def exists(self, p):
        return os_exists(p)
    def is_file(self, p):
        return os_isfile(p)
    def is_dir(self, p):
        return os_isdir(p)
    def stat(self, p):
        return fs_stat(p)
    def size(self, p):
        var info = fs_stat(p)
        if info == none:
            return -1
        return info["size"]
    def walk(self, dirpath):
        var result = []
        var count = 0
        var entries = self.listdir(dirpath)
        var i = 0
        while i < len(entries):
            var full = os_path_join(dirpath, entries[i])
            result.append(full)
            if self.is_dir(full):
                var sub = self.walk(full)
                var j = 0
                while j < len(sub):
                    result.append(sub[j])
                    j = j + 1
            i = i + 1
        return result
    def read_lines(self, filepath):
        var content = self.read(filepath)
        if content == none:
            return []
        return string_split(content, "\n")
    def write_lines(self, filepath, lines):
        var content = ""
        var i = 0
        while i < len(lines):
            content = content + lines[i] + "\n"
            i = i + 1
        return self.write(filepath, content)
    def find_files(self, dirpath, extension):
        var all_files = self.walk(dirpath)
        var result = []
        var count = 0
        var i = 0
        while i < len(all_files):
            if string_endswith(all_files[i], extension):
                result.append(all_files[i])
            i = i + 1
        return result
    def ensure_dir(self, dirpath):
        if self.exists(dirpath) == false:
            return self.mkdir(dirpath)
        return true
    def temp_file(self, prefix):
        var ts = str(int(time_ms()))
        return os_path_join(self.temp_dir(), prefix + "_" + ts + ".tmp")
    def temp_dir(self):
        var td = os_getenv("TMPDIR", "")
        if len(td) > 0:
            return td
        td = os_getenv("TMP", "")
        if len(td) > 0:
            return td
        td = os_getenv("TEMP", "")
        if len(td) > 0:
            return td
        return "/tmp"

class Env:
    def get(self, key):
        return os_getenv(key, "")
    def get_or(self, key, default_val):
        return os_getenv(key, default_val)
    def set(self, key, val):
        os_setenv(key, str(val))
    def home(self):
        var h = self.get("HOME")
        if len(h) == 0:
            h = self.get("USERPROFILE")
        return h
    def user(self):
        var u = self.get("USER")
        if len(u) == 0:
            u = self.get("USERNAME")
        return u
    def cwd(self):
        return os_getcwd()
    def path_list(self):
        var p = self.get("PATH")
        return string_split(p, ":")
    def is_windows(self):
        return len(self.get("WINDIR")) > 0 or len(self.get("ComSpec")) > 0
    def is_linux(self):
        return string_contains(self.get("OSTYPE"), "linux") or path_exists("/proc/version")
    def platform(self):
        if self.is_windows():
            return "windows"
        return "unix"

class Process:
    def run(self, cmd):
        return os_exec(cmd)
    def run_get_lines(self, cmd):
        var output = os_exec(cmd)
        if output == none or output == "":
            return []
        return string_split(string_strip(output), "\n")
    def run_check(self, cmd):
        var result = os_exec(cmd)
        return result != none
    def shell(self, cmd):
        return shell(cmd)
    def which(self, program):
        var result = self.run("which " + program)
        if result == none:
            result = self.run("where " + program)
        if result == none:
            return ""
        return string_strip(result)
    def pid(self):
        return os_exec("echo $$")

class WatchDog:
    def __init__(self, filepath):
        self.filepath = filepath
        self.last_size = -1
        self.last_content = ""
    def has_changed(self):
        var info = fs_stat(self.filepath)
        if info == none:
            return false
        var current_size = info["size"]
        if current_size != self.last_size:
            self.last_size = current_size
            return true
        return false
    def read_new(self):
        var content = read_file(self.filepath)
        if content == none:
            return ""
        if content == self.last_content:
            return ""
        var new_part = content[len(self.last_content):]
        self.last_content = content
        return new_part

class TempFile:
    def __init__(self, prefix):
        var ts = str(int(time_ms()))
        self.path = "/tmp/" + prefix + "_" + ts + ".tmp"
        self.content = ""
    def write(self, data):
        self.content = data
        write_file(self.path, data)
    def read(self):
        return read_file(self.path)
    def delete(self):
        os_remove(self.path)
    def __enter__(self):
        return self
    def __exit__(self):
        self.delete()

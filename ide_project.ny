# ══════════════════════════════════════════════════════════════════════════════
#  ide_project.ny — workspace, project and file-tree model
#
#  Backed by the real filesystem through os_listdir / os_isdir / file_read /
#  file_write, so "Open Folder" opens an actual directory rather than a canned
#  list. Projects are a small text manifest (.nyproj) in the Code::Blocks spirit:
#  a named project with a target file and a set of source files.
# ══════════════════════════════════════════════════════════════════════════════


# A single row in the rendered tree. Rows are flattened from the directory
# structure each time something expands or collapses, so drawing stays a simple
# linear walk.
class TreeRow:
    def __init__(self, name, path, is_dir, depth):
        self.name = name
        self.path = path
        self.is_dir = is_dir
        self.depth = depth
        self.expanded = false
        self.kind = "file"
        if is_dir:
            self.kind = "dir"


class Project:
    def __init__(self):
        self.name = "(no project)"
        self.root = ""
        self.manifest = ""
        self.target = ""
        self.loaded = false

    # ── manifest ─────────────────────────────────────────────────────────────
    # A .nyproj is deliberately plain text, one "key = value" per line, so it can
    # be read and edited without the IDE.
    def create(self, root, name):
        self.root = root
        self.name = name
        self.manifest = os_path_join(root, name + ".nyproj")
        self.target = os_path_join(root, "main.ny")
        if not os_exists(root):
            os_mkdir(root)
        var src = os_path_join(root, "src")
        if not os_exists(src):
            os_mkdir(src)
        var body = "# Nython project\nname = " + name + "\ntarget = main.ny\nstandard = ny2\n"
        write(self.manifest, body)
        if not os_exists(self.target):
            write(self.target, "# " + name + " - main.ny\n\nprint \"Hello from " + name + "\"\n")
        self.loaded = true
        return true

    def load(self, manifest_path):
        if not os_exists(manifest_path):
            return false
        var text = read_file(manifest_path)
        if text == none:
            return false
        self.manifest = manifest_path
        self.root = os_path_dirname(manifest_path)
        self.name = os_path_basename(manifest_path)
        var lines = string_split(text, "\n")
        var i = 0
        while i < len(lines):
            var ln = string_strip(lines[i])
            if len(ln) > 0 and string_find(ln, "#") != 0:
                var eq = string_find(ln, "=")
                if eq > 0:
                    var k = string_strip(string_slice(ln, 0, eq))
                    var v = string_strip(string_slice(ln, eq + 1, len(ln)))
                    if k == "name":
                        self.name = v
                    elif k == "target":
                        self.target = os_path_join(self.root, v)
            i = i + 1
        self.loaded = true
        return true


class Workspace:
    def __init__(self):
        self.root = ""
        self.rows = []
        self.row_count = 0
        self.expanded = {}
        self.project = Project()
        self.error = ""

    def open_folder(self, path):
        if not os_exists(path):
            self.error = "No such folder: " + path
            return false
        if not os_isdir(path):
            self.error = "Not a folder: " + path
            return false
        self.root = path
        self.expanded = {}
        self.expanded[path] = true
        self.error = ""
        self.rebuild()
        return true

    def toggle(self, path):
        if self.expanded.has_key(path):
            if self.expanded[path]:
                self.expanded[path] = false
            else:
                self.expanded[path] = true
        else:
            self.expanded[path] = true
        self.rebuild()

    def is_expanded(self, path):
        if self.expanded.has_key(path):
            return self.expanded[path]
        return false

    # Flatten the visible part of the tree into self.rows.
    def rebuild(self):
        self.rows = []
        self.row_count = 0
        if self.root == "":
            return
        var top = TreeRow(os_path_basename(self.root), self.root, true, 0)
        top.expanded = self.is_expanded(self.root)
        top.kind = "root"
        self.rows = [top]
        self.row_count = 1
        if top.expanded:
            self._walk(self.root, 1)

    def _walk(self, dir_path, depth):
        if depth > 12:
            return
        var entries = os_listdir(dir_path)
        if entries == none:
            return
        # directories first, then files; each group alphabetical
        var dirs = []
        var files = []
        var i = 0
        while i < len(entries):
            var nm = entries[i]
            if string_find(nm, ".") != 0:
                var full = os_path_join(dir_path, nm)
                if os_isdir(full):
                    dirs.append(nm)
                else:
                    files.append(nm)
            i = i + 1
        dirs = sorted(dirs)
        files = sorted(files)

        i = 0
        while i < len(dirs):
            var dn = dirs[i]
            var dfull = os_path_join(dir_path, dn)
            var row = TreeRow(dn, dfull, true, depth)
            row.expanded = self.is_expanded(dfull)
            self.rows.append(row)
            self.row_count = self.row_count + 1
            if row.expanded:
                self._walk(dfull, depth + 1)
            i = i + 1

        i = 0
        while i < len(files):
            var fn = files[i]
            var ffull = os_path_join(dir_path, fn)
            var frow = TreeRow(fn, ffull, false, depth)
            frow.kind = self.classify(fn)
            self.rows.append(frow)
            self.row_count = self.row_count + 1
            i = i + 1

    def classify(self, filename):
        var ext = os_path_ext(filename)
        if ext == ".ny" or ext == ".nyx":
            return "code"
        if ext == ".nyproj":
            return "project"
        if ext == ".md" or ext == ".txt":
            return "text"
        return "file"

    # Code::Blocks-style grouping used by the project view.
    def sources(self):
        var out = []
        var i = 0
        while i < self.row_count:
            var r = self.rows[i]
            if not r.is_dir and r.kind == "code":
                out.append(r)
            i = i + 1
        return out

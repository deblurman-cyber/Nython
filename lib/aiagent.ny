# ═══════════════════════════════════════════════════════════════════════════════
# aiagent.ny — NyxAI: The Nython Intelligent Programming Agent
# An AI agent built on NyTorch that lives inside the language itself.
# It learns from code, documents, conversations, and GitHub at runtime.
# It can answer questions, refactor code, create files, suggest ideas,
# and share knowledge across all instances through a synchronized memory.
# Usage: import "lib/aiagent.ny"
# ═══════════════════════════════════════════════════════════════════════════════

import "lib/nytorch.ny"

# ─── Memory Cell ─────────────────────────────────────────────────────────────

class MemoryCell:
    def __init__(self, key, value, source, confidence):
        self.key = key
        self.value = value
        self.source = source
        self.confidence = confidence
        self.access_count = 0
        self.created_at = time_now()
        self.updated_at = time_now()
        self.tags = []
        self.tag_count = 0
        self.embedding = none

    def touch(self):
        self.access_count = self.access_count + 1
        self.updated_at = time_now()

    def add_tag(self, tag):
        self.tags[self.tag_count] = tag
        self.tag_count = self.tag_count + 1

    def has_tag(self, tag):
        var i = 0
        while i < self.tag_count:
            if self.tags[i] == tag:
                return true
            i = i + 1
        return false

    def to_dict(self):
        return {
            "key": self.key,
            "value": self.value,
            "source": self.source,
            "confidence": self.confidence,
            "access_count": self.access_count,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }

# ─── Memory Store (persistent, synchronized) ─────────────────────────────────

class MemoryStore:
    def __init__(self, store_path):
        self.store_path = store_path
        self.cells = {}
        self.cell_count = 0
        self.max_cells = 100000
        self.dirty = false
        self._load()

    def _load(self):
        var content = read_file(self.store_path)
        if content == none or len(content) == 0:
            return
        var data = json_decode(content)
        if data == none:
            return
        var all_keys = keys(data)
        var i = 0
        while i < len(all_keys):
            var k = all_keys[i]
            var entry = data[k]
            var cell = MemoryCell(
                entry["key"],
                entry["value"],
                entry["source"],
                entry["confidence"]
            )
            cell.access_count = entry["access_count"]
            cell.created_at = entry["created_at"]
            cell.updated_at = entry["updated_at"]
            self.cells[k] = cell
            self.cell_count = self.cell_count + 1
            i = i + 1

    def save(self):
        if self.dirty == false:
            return
        var data = {}
        var all_keys = keys(self.cells)
        var i = 0
        while i < len(all_keys):
            var cell = self.cells[all_keys[i]]
            if cell != none:
                data[all_keys[i]] = cell.to_dict()
            i = i + 1
        var wire = json_encode(data)
        if wire != none:
            write_file(self.store_path, wire)
        self.dirty = false

    def store(self, key, value, source, confidence):
        var cell = MemoryCell(key, value, source, confidence)
        var existing = self.cells[key]
        if existing == none:
            self.cell_count = self.cell_count + 1
        self.cells[key] = cell
        self.dirty = true
        return cell

    def recall(self, key):
        var cell = self.cells[key]
        if cell == none:
            return none
        cell.touch()
        self.dirty = true
        return cell

    def forget(self, key):
        self.cells[key] = none
        self.cell_count = self.cell_count - 1
        self.dirty = true

    def search(self, query):
        var results = []
        var query_lower = string_lower(query)
        var all_keys = keys(self.cells)
        var i = 0
        while i < len(all_keys):
            var cell = self.cells[all_keys[i]]
            if cell != none:
                var ck = string_lower(cell.key)
                var cv = string_lower(str(cell.value))
                if string_contains(query_lower, ck) or string_contains(ck, query_lower) or string_contains(cv, query_lower):
                    results.append(cell)
            i = i + 1
        return results

    def search_by_tag(self, tag):
        var results = []
        var count = 0
        var all_keys = keys(self.cells)
        var i = 0
        while i < len(all_keys):
            var cell = self.cells[all_keys[i]]
            if cell != none and cell.has_tag(tag):
                results.append(cell)
            i = i + 1
        return results

    def most_accessed(self, n):
        var all_keys = keys(self.cells)
        var sorted_cells = []
        var count = 0
        var i = 0
        while i < len(all_keys):
            var c = self.cells[all_keys[i]]
            if c != none:
                sorted_cells.append(c)
            i = i + 1
        var j = 0
        while j < count:
            var k = j + 1
            while k < count:
                if sorted_cells[k].access_count > sorted_cells[j].access_count:
                    var tmp = sorted_cells[j]
                    sorted_cells[j] = sorted_cells[k]
                    sorted_cells.append(tmp)
            j = j + 1
        var result = []
        var max_n = n
        if count < max_n:
            max_n = count
        i = 0
        while i < max_n:
            result.append(sorted_cells[i])
        return result

    def size(self):
        return self.cell_count

# ─── Knowledge Base ──────────────────────────────────────────────────────────

class KnowledgeBase:
    def __init__(self, store_path):
        self.memory = MemoryStore(store_path)
        self.index = {}
        self.doc_count = 0
        self.code_snippets = []
        self.snippet_count = 0

    def add_document(self, title, content, source):
        var words = string_split(string_lower(content), " ")
        var i = 0
        while i < len(words):
            var word = string_strip(words[i])
            if len(word) > 3:
                var cell = self.memory.recall(word)
                if cell == none:
                    self.memory.store(word, title, source, 0.5)
                else:
                    cell.confidence = cell.confidence + 0.01
            i = i + 1
        self.memory.store("doc:" + title, content[0:500], source, 1.0)
        self.doc_count = self.doc_count + 1

    def add_code_snippet(self, description, code, language, tags):
        var snippet = {}
        snippet["description"] = description
        snippet["code"] = code
        snippet["language"] = language
        snippet["tags"] = tags
        snippet["ts"] = time_now()
        self.code_snippets[self.snippet_count] = snippet
        self.snippet_count = self.snippet_count + 1
        var key = "code:" + sha256(code)[0:16]
        self.memory.store(key, description, "code", 0.9)
        var cell = self.memory.recall(key)
        if cell != none:
            var i = 0
            while i < len(tags):
                cell.add_tag(tags[i])
                i = i + 1

    def query(self, question):
        var results = self.memory.search(question)
        var answers = []
        var count = 0
        var i = 0
        while i < len(results):
            if results[i].confidence > 0.3:
                answers.append(results[i])
            i = i + 1
        return answers

    def find_code(self, description):
        var query_lower = string_lower(description)
        var results = []
        var count = 0
        var i = 0
        while i < self.snippet_count:
            var s = self.code_snippets[i]
            if string_contains(string_lower(s["description"]), query_lower):
                results.append(s)
            i = i + 1
        return results

    def save(self):
        self.memory.save()

# ─── Code Analyzer ───────────────────────────────────────────────────────────

class CodeAnalyzer:
    def __init__(self):
        self.patterns = {}
        self._init_patterns()

    def _init_patterns(self):
        self.patterns["TODO"] = "TODO/FIXME comments found"
        self.patterns["print "] = "Debug print statement"
        self.patterns["while true"] = "Infinite loop"
        self.patterns["= none"] = "Null assignment"

    def analyze(self, code):
        var issues = []
        var count = 0
        var lines = string_split(code, "\n")
        var i = 0
        while i < len(lines):
            var line = lines[i]
            var pattern_keys = keys(self.patterns)
            var j = 0
            while j < len(pattern_keys):
                var pat = pattern_keys[j]
                if string_contains(line, pat):
                    var issue = {}
                    issue["line"] = i + 1
                    issue["pattern"] = pat
                    issue["message"] = self.patterns[pat]
                    issue["code"] = string_strip(line)
                    issues.append(issue)
                j = j + 1
            i = i + 1
        return issues

    def count_lines(self, code):
        return len(string_split(code, "\n"))

    def count_classes(self, code):
        var lines = string_split(code, "\n")
        var count = 0
        var i = 0
        while i < len(lines):
            if string_startswith(string_strip(lines[i]), "class "):
                count = count + 1
            i = i + 1
        return count

    def count_functions(self, code):
        var lines = string_split(code, "\n")
        var count = 0
        var i = 0
        while i < len(lines):
            var stripped = string_strip(lines[i])
            if string_startswith(stripped, "def "):
                count = count + 1
            i = i + 1
        return count

    def extract_class_names(self, code):
        var lines = string_split(code, "\n")
        var names = []
        var count = 0
        var i = 0
        while i < len(lines):
            var line = string_strip(lines[i])
            if string_startswith(line, "class "):
                var rest = line[6:]
                var colon = string_find(rest, ":")
                var paren = string_find(rest, "(")
                var end = len(rest)
                if colon >= 0 and colon < end:
                    end = colon
                if paren >= 0 and paren < end:
                    end = paren
                names.append(string_strip(rest[0:end]))
            i = i + 1
        return names

    def suggest_improvements(self, code):
        var suggestions = []
        var count = 0
        var n_lines = self.count_lines(code)
        if n_lines > 500:
            suggestions.append("Consider splitting this file into smaller modules (>500 lines)")
        var n_classes = self.count_classes(code)
        var n_functions = self.count_functions(code)
        if n_functions > 0 and n_classes == 0:
            suggestions.append("Consider organizing functions into classes for better structure")
        if string_contains(code, "while true"):
            suggestions.append("Infinite loops detected - ensure they have proper exit conditions")
        return suggestions

# ─── Code Generator ──────────────────────────────────────────────────────────

class CodeGenerator:
    def __init__(self):
        self.indent = "    "

    def class_template(self, name, fields, methods):
        var code = "class " + name + ":\n"
        code = code + self.indent + "def __init__(self"
        var i = 0
        while i < len(fields):
            code = code + ", " + fields[i]
            i = i + 1
        code = code + "):\n"
        i = 0
        while i < len(fields):
            code = code + self.indent + self.indent + "self." + fields[i] + " = " + fields[i] + "\n"
            i = i + 1
        i = 0
        while i < len(methods):
            code = code + "\n" + self.indent + "def " + methods[i] + "(self):\n"
            code = code + self.indent + self.indent + "pass\n"
            i = i + 1
        return code

    def getter_setter(self, field):
        var code = self.indent + "def get_" + field + "(self):\n"
        code = code + self.indent + self.indent + "return self." + field + "\n"
        code = code + "\n"
        code = code + self.indent + "def set_" + field + "(self, val):\n"
        code = code + self.indent + self.indent + "self." + field + " = val\n"
        return code

    def crud_api(self, entity):
        var code = "# CRUD API for " + entity + "\n"
        code = code + "class " + entity + "Repository:\n"
        code = code + self.indent + "def __init__(self):\n"
        code = code + self.indent + self.indent + "self.items = {}\n"
        code = code + self.indent + self.indent + "self.count = 0\n\n"
        code = code + self.indent + "def create(self, data):\n"
        code = code + self.indent + self.indent + "id = str(int(time_ms()))\n"
        code = code + self.indent + self.indent + "data[\"id\"] = id\n"
        code = code + self.indent + self.indent + "self.items[id] = data\n"
        code = code + self.indent + self.indent + "self.count = self.count + 1\n"
        code = code + self.indent + self.indent + "return data\n\n"
        code = code + self.indent + "def read(self, id):\n"
        code = code + self.indent + self.indent + "return self.items[id]\n\n"
        code = code + self.indent + "def read_all(self):\n"
        code = code + self.indent + self.indent + "result = []\n"
        code = code + self.indent + self.indent + "all_ids = keys(self.items)\n"
        code = code + self.indent + self.indent + "i = 0\n"
        code = code + self.indent + self.indent + "while i < len(all_ids):\n"
        code = code + self.indent + self.indent + self.indent + "result[i] = self.items[all_ids[i]]\n"
        code = code + self.indent + self.indent + self.indent + "i = i + 1\n"
        code = code + self.indent + self.indent + "return result\n\n"
        code = code + self.indent + "def update(self, id, data):\n"
        code = code + self.indent + self.indent + "existing = self.items[id]\n"
        code = code + self.indent + self.indent + "if existing == none:\n"
        code = code + self.indent + self.indent + self.indent + "return none\n"
        code = code + self.indent + self.indent + "data[\"id\"] = id\n"
        code = code + self.indent + self.indent + "self.items[id] = data\n"
        code = code + self.indent + self.indent + "return data\n\n"
        code = code + self.indent + "def delete(self, id):\n"
        code = code + self.indent + self.indent + "self.items[id] = none\n"
        code = code + self.indent + self.indent + "self.count = self.count - 1\n"
        code = code + self.indent + self.indent + "return true\n"
        return code

    def rest_handler(self, entity, port):
        var code = "# REST server for " + entity + "\n"
        code = code + "import \"lib/webserver.ny\"\n"
        code = code + "repo = " + entity + "Repository()\n"
        code = code + "server = HttpServer(\"0.0.0.0\", " + str(port) + ")\n"
        code = code + "server.get(\"/" + string_lower(entity) + "s\", lambda req, res: res.send_json(repo.read_all()))\n"
        code = code + "server.post(\"/" + string_lower(entity) + "s\", lambda req, res: res.send_json(repo.create(req.json_body())))\n"
        code = code + "server.get(\"/" + string_lower(entity) + "s/:id\", lambda req, res: res.send_json(repo.read(req.params[\"id\"])))\n"
        code = code + "server.listen()\n"
        return code

# ─── GitHub Learner ───────────────────────────────────────────────────────────

class GitHubLearner:
    def __init__(self, kb):
        self.kb = kb
        self.learned_repos = []
        self.repo_count = 0
        self.api_base = "https://api.github.com"
        self.token = ""

    def set_token(self, token):
        self.token = token

    def learn_from_repo(self, owner, repo_name):
        var url = "https://raw.githubusercontent.com/" + owner + "/" + repo_name + "/main/README.md"
        var content = http_get(url)
        if content == none or len(content) == 0:
            url = "https://raw.githubusercontent.com/" + owner + "/" + repo_name + "/master/README.md"
            content = http_get(url)
        if content != none and len(content) > 0:
            self.kb.add_document(owner + "/" + repo_name, content, "github:" + owner + "/" + repo_name)
            self.learned_repos[self.repo_count] = owner + "/" + repo_name
            self.repo_count = self.repo_count + 1
            return true
        return false

    def learn_from_url(self, url, title):
        var content = http_get(url)
        if content == none or len(content) == 0:
            return false
        self.kb.add_document(title, content, url)
        return true

    def search_patterns(self, language, pattern):
        var url = self.api_base + "/search/code?q=" + pattern + "+language:" + language + "&per_page=10"
        var resp = http_get(url)
        if resp == none:
            return []
        var data = json_decode(resp)
        if data == none:
            return []
        return data

# ─── Document Learner ────────────────────────────────────────────────────────

class DocumentLearner:
    def __init__(self, kb):
        self.kb = kb
        self.learned_files = []
        self.file_count = 0

    def learn_file(self, filepath):
        var content = read_file(filepath)
        if content == none or len(content) == 0:
            return false
        var title = os_path_basename(filepath)
        self.kb.add_document(title, content, "file:" + filepath)
        self.learned_files[self.file_count] = filepath
        self.file_count = self.file_count + 1
        return true

    def learn_directory(self, dirpath, extension):
        var entries = os_listdir(dirpath)
        if entries == none:
            return 0
        var count = 0
        var i = 0
        while i < len(entries):
            var name = entries[i]
            if string_endswith(name, extension):
                var full = os_path_join(dirpath, name)
                if self.learn_file(full):
                    count = count + 1
            i = i + 1
        return count

    def learn_url(self, url, title):
        var content = http_get(url)
        if content == none or len(content) == 0:
            return false
        var text = html_strip(content)
        if len(text) > 0:
            self.kb.add_document(title, text, url)
            return true
        return false

# ─── On-the-fly Learner ───────────────────────────────────────────────────────

class OnlineLearner:
    def __init__(self, kb):
        self.kb = kb
        self.examples = []
        self.example_count = 0
        self.feedback = []
        self.feedback_count = 0

    def learn_from_conversation(self, question, answer, quality):
        var key = "qa:" + sha256(question)[0:16]
        var cell = self.kb.memory.store(key, answer, "conversation", quality)
        if cell != none:
            cell.add_tag("qa")
            cell.add_tag("conversation")
        var entry = {}
        entry["q"] = question
        entry["a"] = answer
        entry["quality"] = quality
        entry["ts"] = time_now()
        self.examples[self.example_count] = entry
        self.example_count = self.example_count + 1

    def learn_from_correction(self, wrong, correct, context):
        var key = "correction:" + sha256(wrong)[0:12]
        self.kb.memory.store(key, correct, "correction", 0.95)
        var fb = {}
        fb["wrong"] = wrong
        fb["correct"] = correct
        fb["context"] = context
        fb["ts"] = time_now()
        self.feedback[self.feedback_count] = fb
        self.feedback_count = self.feedback_count + 1

    def best_examples(self, n):
        var result = []
        var count = 0
        var i = 0
        while i < self.example_count and count < n:
            if self.examples[i]["quality"] > 0.7:
                result.append(self.examples[i])
            i = i + 1
        return result

# ─── Reasoning Engine ─────────────────────────────────────────────────────────

class ReasoningEngine:
    def __init__(self, kb):
        self.kb = kb
        self.rules = []
        self.rule_count = 0

    def add_rule(self, condition_key, action_template):
        var rule = {}
        rule["condition"] = condition_key
        rule["action"] = action_template
        self.rules[self.rule_count] = rule
        self.rule_count = self.rule_count + 1

    def infer(self, context):
        var conclusions = []
        var count = 0
        var i = 0
        while i < self.rule_count:
            var rule = self.rules[i]
            if string_contains(string_lower(context), string_lower(rule["condition"])):
                conclusions.append(rule["action"])
            i = i + 1
        return conclusions

    def explain(self, question):
        var results = self.kb.query(question)
        if len(results) == 0:
            return "I don't have information about that yet. Ask me to learn it!"
        var best = results[0]
        var i = 1
        while i < len(results):
            if results[i].confidence > best.confidence:
                best = results[i]
            i = i + 1
        return "Based on my knowledge (source: " + best.source + ", confidence: " + str(best.confidence) + "): " + str(best.value)

# ─── File Assistant ───────────────────────────────────────────────────────────

class FileAssistant:
    def __init__(self, workspace):
        self.workspace = workspace
        os_mkdir(workspace)

    def create_file(self, filename, content):
        var path = os_path_join(self.workspace, filename)
        var ok = write_file(path, content)
        if ok:
            return "Created: " + path
        return "Failed to create: " + path

    def read_file(self, filename):
        var path = os_path_join(self.workspace, filename)
        # `cat` rather than `read_file`: inside a method named read_file the
        # bare name resolves back to this method, so the call recursed until the
        # stack ran out. `cat` is the same path-based read under another name.
        var content = cat(path)
        if content == none:
            return "File not found: " + path
        return content

    def list_files(self):
        var entries = os_listdir(self.workspace)
        if entries == none:
            return []
        return entries

    def delete_file(self, filename):
        var path = os_path_join(self.workspace, filename)
        var ok = os_remove(path)
        if ok:
            return "Deleted: " + path
        return "Failed to delete: " + path

    def append_to_file(self, filename, content):
        var path = os_path_join(self.workspace, filename)
        return append_text(path, content)

    def create_nython_file(self, filename, description, classes, functions):
        var code = "# " + description + "\n"
        code = code + "# Generated by NyxAI at " + str(time_now()) + "\n\n"
        var gen = CodeGenerator()
        var i = 0
        while i < len(classes):
            code = code + gen.class_template(classes[i], [], []) + "\n"
            i = i + 1
        return self.create_file(filename, code)

# ─── IDE Integration ──────────────────────────────────────────────────────────

class IdeIntegration:
    def __init__(self, nyx):
        self.nyx = nyx
        self.socket_path = "/tmp/nyx_ide.sock"
        self.server_fd = -1

    def autocomplete(self, prefix, context):
        var results = self.nyx.kb.query(prefix)
        var suggestions = []
        var count = 0
        var i = 0
        while i < len(results):
            var cell = results[i]
            if string_startswith(cell.key, prefix):
                suggestions.append(cell.key)
            i = i + 1
        var all_class_names = self.nyx.analyzer.extract_class_names(context)
        var j = 0
        while j < len(all_class_names):
            if string_startswith(all_class_names[j], prefix):
                suggestions.append(all_class_names[j])
            j = j + 1
        return suggestions

    def hover_info(self, symbol):
        var cell = self.nyx.kb.memory.recall(symbol)
        if cell != none:
            return "Symbol: " + symbol + "\nSource: " + cell.source + "\nInfo: " + str(cell.value)
        return "No info for: " + symbol

    def quick_fix(self, issue_msg, code_context):
        var suggestions = self.nyx.suggest_fix(issue_msg, code_context)
        return suggestions

    def format_code(self, code):
        var lines = string_split(code, "\n")
        formatted = []
        var i = 0
        while i < len(lines):
            var line = lines[i]
            var stripped = string_strip(line)
            if len(stripped) == 0:
                formatted[i] = ""
            else:
                formatted.append(line)
        return string_join(formatted, "\n")

    def start_server(self):
        var fd = tcp_server_create("127.0.0.1", 9999)
        if fd < 0:
            return false
        self.server_fd = fd
        return true

    def handle_request(self, raw):
        var req = json_decode(raw)
        if req == none:
            return json_encode({"error": "invalid request"})
        var cmd = req["command"]
        var resp = {}
        if cmd == "autocomplete":
            resp["suggestions"] = self.autocomplete(req["prefix"], req["context"])
        elif cmd == "hover":
            resp["info"] = self.hover_info(req["symbol"])
        elif cmd == "ask":
            resp["answer"] = self.nyx.ask(req["question"])
        elif cmd == "fix":
            resp["fix"] = self.quick_fix(req["issue"], req["code"])
        elif cmd == "generate":
            resp["code"] = self.nyx.generate(req["prompt"])
        elif cmd == "analyze":
            resp["issues"] = self.nyx.analyze(req["code"])
        else:
            resp["error"] = "unknown command: " + str(cmd)
        return json_encode(resp)

# ─── NyxAI Core ───────────────────────────────────────────────────────────────

class NyxAI:
    def __init__(self, name, workspace):
        self.name = name
        self.workspace = workspace
        self.version = "1.0.0"
        self.started_at = time_now()
        self.interaction_count = 0

        var kb_path = os_path_join(workspace, "nyx_memory.json")
        os_mkdir(workspace)
        self.kb = KnowledgeBase(kb_path)
        self.analyzer = CodeAnalyzer()
        self.generator = CodeGenerator()
        self.files = FileAssistant(workspace)
        self.github = GitHubLearner(self.kb)
        self.docs = DocumentLearner(self.kb)
        self.online = OnlineLearner(self.kb)
        self.reasoning = ReasoningEngine(self.kb)
        self.ide = IdeIntegration(self)

        self.context_history = []
        self.history_count = 0
        self.max_history = 50
        self.is_learning = true
        self.verbose = false

        self._init_rules()
        self._load_builtins()

    def _init_rules(self):
        self.reasoning.add_rule("error", "Check for syntax errors and undefined variables")
        self.reasoning.add_rule("slow", "Profile with Stopwatch, consider algorithmic improvements")
        self.reasoning.add_rule("memory", "Use generators, avoid storing large datasets in memory at once")
        self.reasoning.add_rule("network", "Check connection, implement retry logic and timeouts")
        self.reasoning.add_rule("class", "Use __init__ to initialize all instance variables")
        self.reasoning.add_rule("loop", "Prefer while loops with explicit bounds for safety")
        self.reasoning.add_rule("import", "Put imports at the top of your file")
        self.reasoning.add_rule("test", "Write test functions with descriptive names and assertions")

    def _load_builtins(self):
        self.kb.memory.store("Nython", "A multi-syntax scripting language with Python-like syntax", "builtin", 1.0)
        self.kb.memory.store("NyTorch", "Deep learning library for Nython with 350+ classes", "builtin", 1.0)
        self.kb.memory.store("import", "Use: import \"lib/module.ny\" to import a library", "builtin", 1.0)
        self.kb.memory.store("class", "Define with: class Name: then def __init__(self): or def init(self):", "builtin", 1.0)
        self.kb.memory.store("while", "Use while condition: body (indent with 4 spaces)", "builtin", 1.0)
        self.kb.memory.store("for", "Use: for i in range(start, end): or for item in list:", "builtin", 1.0)
        self.kb.memory.store("def", "Define function: def name(self, args): body", "builtin", 1.0)
        self.kb.memory.store("print", "Use: print value or print \"text\"", "builtin", 1.0)
        self.kb.memory.store("none", "Null value in Nython (like None in Python, null in C++)", "builtin", 1.0)
        self.kb.memory.store("tensor", "Create with: tensor([1.0, 2.0, 3.0]) - returns a native tensor", "builtin", 1.0)

    def ask(self, question):
        self.interaction_count = self.interaction_count + 1
        var entry = {"q": question, "ts": time_now()}
        if self.history_count < self.max_history:
            self.context_history[self.history_count] = entry
            self.history_count = self.history_count + 1
        var answer = self.reasoning.explain(question)
        var inferences = self.reasoning.infer(question)
        if len(inferences) > 0:
            answer = answer + "\n\nSuggestions:\n"
            var i = 0
            while i < len(inferences):
                answer = answer + "• " + inferences[i] + "\n"
                i = i + 1
        if self.is_learning:
            self.online.learn_from_conversation(question, answer, 0.6)
        return answer

    def analyze(self, code):
        var issues = self.analyzer.analyze(code)
        var suggestions = self.analyzer.suggest_improvements(code)
        var stats = {}
        stats["lines"] = self.analyzer.count_lines(code)
        stats["classes"] = self.analyzer.count_classes(code)
        stats["functions"] = self.analyzer.count_functions(code)
        stats["issues"] = len(issues)
        stats["suggestions"] = len(suggestions)
        var result = {}
        result["stats"] = stats
        result["issues"] = issues
        result["suggestions"] = suggestions
        result["class_names"] = self.analyzer.extract_class_names(code)
        return result

    def generate(self, prompt):
        var prompt_lower = string_lower(prompt)
        if string_contains(prompt_lower, "class"):
            var name = "MyClass"
            var words = string_split(prompt, " ")
            var i = 0
            while i < len(words):
                var w = words[i]
                if len(w) > 0 and w[0] >= "A" and w[0] <= "Z":
                    name = w
                    break
                i = i + 1
            return self.generator.class_template(name, ["value"], ["process", "to_string"])
        if string_contains(prompt_lower, "crud") or string_contains(prompt_lower, "repository"):
            words = string_split(prompt, " ")
            var entity = "Entity"
            i = 0
            while i < len(words):
                w = words[i]
                if len(w) > 1 and w[0] >= "A" and w[0] <= "Z":
                    entity = w
                    break
                i = i + 1
            return self.generator.crud_api(entity)
        if string_contains(prompt_lower, "rest") or string_contains(prompt_lower, "api") or string_contains(prompt_lower, "server"):
            return self.generator.rest_handler("Item", 8080)
        var snippets = self.kb.find_code(prompt)
        if len(snippets) > 0:
            return "# Found existing snippet:\n" + snippets[0]["code"]
        return "# TODO: Implement - " + prompt + "\n# NyxAI suggestion: Break into smaller functions\nclass " + "Solution" + ":\n    def __init__(self):\n        pass\n    def solve(self):\n        pass\n"

    def suggest_fix(self, issue, code_context):
        var suggestions = []
        var count = 0
        var issue_lower = string_lower(issue)
        if string_contains(issue_lower, "undefined") or string_contains(issue_lower, "not found"):
            suggestions.append("Check variable/function is defined before use")
            suggestions.append("Verify import statements at top of file")
        if string_contains(issue_lower, "indent") or string_contains(issue_lower, "syntax"):
            suggestions.append("Use exactly 4 spaces for indentation (no tabs)")
            suggestions.append("Check that all blocks are properly closed")
        if string_contains(issue_lower, "none") or string_contains(issue_lower, "null"):
            suggestions.append("Add null check: if variable != none:")
        if string_contains(issue_lower, "type"):
            suggestions.append("Use str(), int(), float() for explicit conversion")
        var kb_results = self.kb.query(issue)
        var i = 0
        while i < len(kb_results) and count < 10:
            suggestions.append("From KB: " + str(kb_results[i].value))
            i = i + 1
        return suggestions

    def learn_github(self, owner, repo):
        var ok = self.github.learn_from_repo(owner, repo)
        if ok:
            return self.name + ": Learned from " + owner + "/" + repo
        return self.name + ": Could not learn from " + owner + "/" + repo

    def learn_file(self, filepath):
        var ok = self.docs.learn_file(filepath)
        if ok:
            return self.name + ": Learned from " + filepath
        return self.name + ": Could not read " + filepath

    def learn_url(self, url, title):
        var ok = self.docs.learn_url(url, title)
        if ok:
            return self.name + ": Learned from " + url
        return self.name + ": Could not fetch " + url

    def remember(self, key, value):
        self.kb.memory.store(key, value, "user", 1.0)
        return self.name + ": Remembered '" + key + "'"

    def recall(self, key):
        var cell = self.kb.memory.recall(key)
        if cell == none:
            return self.name + ": I don't know about '" + key + "' yet"
        return str(cell.value)

    def forget(self, key):
        self.kb.memory.forget(key)
        return self.name + ": Forgot '" + key + "'"

    def create_file(self, filename, content):
        return self.files.create_file(filename, content)

    def read_file(self, filename):
        return self.files.read_file(filename)

    def list_workspace(self):
        return self.files.list_files()

    def correct(self, wrong, correct):
        self.online.learn_from_correction(wrong, correct, "user feedback")
        return self.name + ": Thanks for the correction! I'll remember that."

    def save(self):
        self.kb.save()
        return self.name + ": Memory saved to disk"

    def status(self):
        var uptime = time_now() - self.started_at
        return {
            "name": self.name,
            "version": self.version,
            "memory_cells": self.kb.memory.size(),
            "code_snippets": self.kb.snippet_count,
            "interactions": self.interaction_count,
            "uptime_seconds": uptime,
            "workspace": self.workspace,
            "github_repos_learned": self.github.repo_count,
            "files_learned": self.docs.file_count
        }

    def greeting(self):
        return "Hi! I'm " + self.name + " v" + self.version + ", your Nython AI assistant.\n" + "I have " + str(self.kb.memory.size()) + " knowledge cells loaded.\n" + "Ask me anything, or say 'learn github owner/repo' to teach me!"

    def start_ide_server(self):
        return self.ide.start_server()

    def handle_ide(self, raw_request):
        return self.ide.handle_request(raw_request)

    def autocomplete(self, prefix, context):
        return self.ide.autocomplete(prefix, context)

# ─── Shared Memory Bus (synchronizes knowledge across all NyxAI instances) ───

class NyxSharedBus:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.instances = {}
        self.instance_count = 0
        self.server_fd = -1
        self.running = false

    def register(self, nyx):
        self.instances[nyx.name] = nyx
        self.instance_count = self.instance_count + 1

    def broadcast_memory(self, key, value, source):
        var all_names = keys(self.instances)
        var i = 0
        while i < len(all_names):
            var inst = self.instances[all_names[i]]
            if inst != none:
                inst.kb.memory.store(key, value, "shared:" + source, 0.8)
            i = i + 1

    def sync_all(self):
        var all_names = keys(self.instances)
        if len(all_names) < 2:
            return
        var i = 0
        while i < len(all_names):
            var src = self.instances[all_names[i]]
            var popular = src.kb.memory.most_accessed(50)
            var j = 0
            while j < len(all_names):
                if all_names[j] != all_names[i]:
                    var dst = self.instances[all_names[j]]
                    if dst != none:
                        var k = 0
                        while k < len(popular):
                            var cell = popular[k]
                            dst.kb.memory.store(cell.key, cell.value, "sync:" + all_names[i], cell.confidence * 0.9)
                            k = k + 1
                j = j + 1
            i = i + 1

    def save_all(self):
        var all_names = keys(self.instances)
        var i = 0
        while i < len(all_names):
            var inst = self.instances[all_names[i]]
            if inst != none:
                inst.save()
            i = i + 1

# ─── Factory ─────────────────────────────────────────────────────────────────

class NyxFactory:
    def __init__(self):
        self.bus = none

    def create(self, name, workspace):
        var nyx = NyxAI(name, workspace)
        if self.bus != none:
            self.bus.register(nyx)
        return nyx

    def create_cluster(self, names, workspace_root):
        var cluster = []
        var i = 0
        while i < len(names):
            var ws = os_path_join(workspace_root, names[i])
            var nyx = NyxAI(names[i], ws)
            cluster.append(nyx)
            i = i + 1
        return cluster

    def sync_cluster(self):
        if self.bus != none:
            self.bus.sync_all()

    def save_cluster(self):
        if self.bus != none:
            self.bus.save_all()

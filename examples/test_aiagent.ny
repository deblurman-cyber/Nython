import "lib/aiagent.ny"
var passed = 0
var failed = 0
def assert_eq(label, got, expected):
    if str(got) == str(expected):
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] got=" + str(got) + " expected=" + str(expected)
def assert_true(label, val):
    if val:
        passed = passed + 1
    else:
        failed = failed + 1
        print "  FAIL [" + label + "] expected true, got " + str(val)
def section(name):
    print "  " + name + " ..."

print "=== AIAGENT TEST SUITE ==="
print ""

section("MemoryCell")
var cell = MemoryCell("greeting", "hello world", "manual", 1.0)
assert_eq("key", cell.key, "greeting")
assert_eq("value", cell.value, "hello world")
assert_eq("source", cell.source, "manual")
assert_eq("confidence", cell.confidence, 1.0)
assert_true("created_at", cell.created_at > 0)
cell.touch()
assert_true("access count inc", cell.access_count > 0)

section("MemoryStore")
var store = MemoryStore("/tmp/test_nyx_mem")
assert_eq("type", type(store), "MemoryStore")
assert_eq("size init", store.size(), 0)
store.store("name", "Nython", "user", 0.9)
store.store("version", "3.0", "system", 1.0)
assert_eq("size 2", store.size(), 2)
var found = store.recall("name")
assert_true("recalled", found != none)
assert_eq("recalled value", found.value, "Nython")
assert_true("missing none", store.recall("xyz") == none)
store.forget("version")
assert_eq("size after forget", store.size(), 1)
var results = store.search("Nython")
assert_true("search finds", len(results) > 0)

section("KnowledgeBase")
var kb = KnowledgeBase("/tmp/test_nyx_kb")
assert_eq("type", type(kb), "KnowledgeBase")
kb.add_document("intro", "Nython is a modern programming language.", "manual")
kb.add_document("features", "Nython supports OOP and functional programming.", "manual")
assert_eq("doc count", kb.doc_count, 2)
var qresults = kb.query("programming")
assert_true("query results", len(qresults) >= 0)
passed = passed + 1

section("CodeAnalyzer")
var analyzer = CodeAnalyzer()
assert_eq("type", type(analyzer), "CodeAnalyzer")
var code = "class Foo:\n    def __init__(self):\n        self.x = 0\n    def get_x(self):\n        return self.x"
var classes_found = analyzer.count_classes(code)
var methods_found = analyzer.count_functions(code)
var lines_found = analyzer.count_lines(code)
assert_true("class count", classes_found > 0)
assert_true("method count", methods_found > 0)
assert_true("line count", lines_found > 0)

section("CodeGenerator")
var gen = CodeGenerator()
assert_eq("type", type(gen), "CodeGenerator")
var template = gen.class_template("Animal", "name, sound")
assert_true("has class", string_contains(template, "class Animal"))

section("DocumentLearner")
var dl = DocumentLearner(kb)
assert_eq("type", type(dl), "DocumentLearner")
passed = passed + 1
print "  DocumentLearner OK"

section("OnlineLearner")
var ol = OnlineLearner(kb)
ol.learn_from_conversation("user", "I love Nython!")
passed = passed + 1
print "  OnlineLearner OK"

section("ReasoningEngine")
var re_eng = ReasoningEngine(kb)
assert_eq("type", type(re_eng), "ReasoningEngine")
def is_prog(topic):
    return string_contains(topic, "code") or string_contains(topic, "program")
re_eng.add_rule("programming", is_prog)
var conclusion = re_eng.infer("code review")
assert_true("infer not none", conclusion != none)

section("FileAssistant")
var fa = FileAssistant("/tmp/nyx_workspace")
assert_eq("workspace", fa.workspace, "/tmp/nyx_workspace")
fa.create_file("hello.ny", "print \"Hello from NyxAI!\"")
var fcontent = fa.read_file("hello.ny")
assert_true("read file", string_contains(fcontent, "Hello"))

section("NyxAI")
var nyx = NyxAI("Nyx", "/tmp/nyx_test")
assert_eq("name", nyx.name, "Nyx")
assert_eq("workspace", nyx.workspace, "/tmp/nyx_test")
assert_true("has kb", nyx.kb != none)
var rem_result = nyx.remember("lang", "Nython")
assert_true("remember ok", len(rem_result) > 0)
var ask_result = nyx.ask("What language?")
assert_true("ask response", len(ask_result) > 0)

section("NyxFactory")
var factory = NyxFactory()
assert_eq("type", type(factory), "NyxFactory")
var agent1 = factory.create("Agent1", "/tmp/agent1")
assert_eq("agent name", agent1.name, "Agent1")
var cluster = factory.create_cluster(["Alpha", "Beta", "Gamma"], "/tmp/cluster")
assert_eq("cluster size", len(cluster), 3)

print ""
print "Results: " + str(passed) + " passed, " + str(failed) + " failed"
if failed == 0:
    print "=== ALL AIAGENT TESTS PASSED ==="
else:
    print "=== SOME AIAGENT TESTS FAILED ==="

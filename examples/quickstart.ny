# ================================================================
# NyTorch v3.0 -- QUICKSTART
# The AI framework that lives in your language.
# ================================================================
# Run: ./nython examples/quickstart.ny
# ================================================================

import nytorch
import "lib/nytorch_full.ny"

print "================================================="
print " NyTorch v3.0 -- Quickstart Demo"
print "================================================="
print ""

# 1. TENSORS & MATH
print "[1] Tensors & Math"
var x = tensor([1.0, 2.0, 3.0, 4.0, 5.0])
var y = tensor([5.0, 4.0, 3.0, 2.0, 1.0])
var z = tensor_add(x, y)
print "   x + y = " + str(tensor_sum(z))
print "   dot(x, y) = " + str(tensor_dot(x, y))
var probs = softmax(x)
print "   softmax sum = " + str(tensor_sum(probs))
print ""

# 2. NEURAL NETWORK
print "[2] Neural Network Layer"
var net = Sequential()
net.add(Linear(4, 8))
net.add(ReLULayer())
net.add(Linear(8, 2))
var inp = tensor([0.5, -0.2, 0.8, 0.1])
var out = net.forward(inp)
print "   Network output is tensor: " + str(out != none)
print ""

# 3. KNOWLEDGE BASE
print "[3] Knowledge Base"
var kb = KnowledgeBase("/tmp/qs_kb.kv")
kb.remember("task", "image_classification")
kb.remember("dataset", "okra_maturity")
kb.remember("accuracy", "0.97")
print "   task: " + kb.recall("task")
print "   dataset: " + kb.recall("dataset")
print "   facts stored: " + str(kb.count())
print ""

# 4. KNOWLEDGE GRAPH -------------------------------
print "[4] Knowledge Graph"
var kg = KnowledgeGraph("/tmp/qs_kg")
kg.add_node("okra", "Crop", "origin=Africa")
kg.add_node("immature", "Stage", "color=green")
kg.add_node("mature", "Stage", "color=yellow")
kg.add_node("overripe", "Stage", "color=brown")
kg.add_edge("okra", "has_stage", "immature", 1.0)
kg.add_edge("okra", "has_stage", "mature", 1.0)
kg.add_edge("okra", "has_stage", "overripe", 1.0)
kg.add_edge("immature", "precedes", "mature", 1.0)
kg.add_edge("mature", "precedes", "overripe", 1.0)
var stages = kg.neighbors("okra", "has_stage")
print "   Okra stages: " + str(len(stages))
var next_stage = kg.neighbors("immature", "precedes")
print "   After immature comes: " + next_stage[0]
print ""

# 5. AGENT---------
print "[5] AI Agent"
var os = NyOS("quickstart_node", "/tmp/qs_nyos")
var agent_b = AgentBuilder()
agent_b.id("qs_agent")
agent_b.storage("/tmp/qs_agents")
agent_b.network_port(29001)
agent_b.with_goal("classify_okra", 10)
agent_b.with_goal("share_knowledge", 5)
var agent = agent_b.build()

agent.remember("model_type", "ViT")
agent.remember("input_size", "224x224")
agent.step()
agent.step()
agent.step()
print "   Agent ID: " + agent.agent_id
print "   Agent tick: " + str(agent.tick)
print "   model_type: " + agent.recall("model_type")
print "   goals: " + str(len(agent.goals))
print ""

# 6. STORAGE-------
print "[6] Model Storage"
var store = ModelStore("/tmp/qs_models")
var params = [tensor([0.1, 0.2, 0.3]), tensor([0.4, 0.5, 0.6])]
store.save("okra_v1", params, "acc=0.97 dataset=okra epoch=50")
print "   Model saved: " + str(store.exists("okra_v1"))
print "   Model info: " + store.info("okra_v1")
var loaded = store.load("okra_v1")
print "   Loaded params: " + str(len(loaded))
print ""

# 7. FEDERATED LEARNING ----------------------------
print "[7] Federated Learning Round"
var round1 = FederatedRound(1)
var g1 = tensor_randn([8])
var g2 = tensor_randn([8])
var g3 = tensor_randn([8])
round1.add_gradient("agent_a", g1)
round1.add_gradient("agent_b", g2)
round1.add_gradient("agent_c", g3)
var global_g = round1.fedavg()
print "   Participants: " + str(round1.participants)
print "   Global gradient computed: " + str(global_g != none)
print ""

# 8. HTTP API SERVER -------------------------------
print "[8] AI Agent HTTP API Server"
var ai_server = AgentServer("okra_ai", 29500, "/tmp/qs_api")
var started = ai_server.start()
print "   AgentServer on :29500 -- " + str(started)
if started:
    # Client queries the server
    var cli = AgentHttpClient("127.0.0.1", 29500)
    var hr = cli.get("/health")
    var ctx2 = ai_server.serve_one(500)
    print "   /health served: " + str(ctx2 != none)
    cli.kb_set("inference_count", "0")
    var ctx3 = ai_server.serve_one(500)
    print "   /kb/set served: " + str(ctx3 != none)
    ai_server.stop()
print ""

# 9. PIPELINE------
print "[9] ML Data Pipeline"
var pipe = NyPipeline("okra_preprocess")
var raw = tensor([120.0, 95.0, 210.0, 80.0])
pipe.feed(raw)
pipe.normalize()
pipe.record("normalized")
var w = tensor([0.25, 0.25, 0.25, 0.25])
pipe.matmul(w)
pipe.record("pooled")
print "   Pipeline stages recorded: " + str(len(pipe.results))
print ""

# 10. APP FRAMEWORK
print "[10] NyApp Framework"
var app = NyApp("okra_detector", "/tmp/qs_app")
app.schedule("inference", 1, 10)
app.schedule("save_checkpoint", 100, 5)
app.schedule("broadcast_status", 50, 3)
app.start()
var due1 = app.step()
var due2 = app.step()
var due3 = app.step()
print "   App health: " + app.health()
print "   Tasks due on tick 1: " + str(len(due1))
app.stop()
print ""

print "================================================="
print " NyTorch Quickstart Complete!"
print " Your AI is ready to:"
print "   * Train models and save/load checkpoints"
print "   * Serve REST APIs for inference"
print "   * Communicate with other agents over LAN"
print "   * Store and reason over knowledge graphs"
print "   * Run federated learning across devices"
print "   * Build full AI apps with NyApp + NyOS"
print "================================================="

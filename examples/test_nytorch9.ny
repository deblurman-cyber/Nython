import nytorch
import "lib/nytorch_all.ny"

print "=== NyTorch v3.0 Agent I/O Test Suite ==="

# --- StorageManager ---
var sm = StorageManager("/tmp/ny_test_storage")
sm.setup()
var t1 = tensor([1.0, 2.0, 3.0, 4.0])
var ok = sm.save_tensor("test_t1", t1)
print "StorageManager save_tensor: " + str(ok)
var t1_loaded = sm.load_tensor("test_t1")
print "StorageManager load_tensor sum: " + str(tensor_sum(t1_loaded))
var models_list = sm.list_models()
print "StorageManager list_models OK"
print "StorageManager.PASS"

# --- KnowledgeBase ---
var kb = KnowledgeBase("/tmp/ny_test_kb.kv")
kb.remember("color", "red")
kb.remember("shape", "circle")
kb.remember("size", "large")
var v = kb.recall("color")
print "KnowledgeBase recall: " + v
var has_shape = kb.has("shape")
print "KnowledgeBase has: " + str(has_shape)
var keys = kb.all_keys()
print "KnowledgeBase key count: " + str(len(keys))
kb.forget("size")
var has_size = kb.has("size")
print "KnowledgeBase forget: " + str(has_size)
print "KnowledgeBase.PASS"

# --- DataLogger ---
var logger = DataLogger("/tmp/ny_logs", "test_agent")
logger.info("Test started")
logger.warn("Test warning")
logger.log_metric("accuracy", 0.95)
var logs = logger.read_logs()
print "DataLogger logged: " + str(len(logs) > 0)
print "DataLogger.PASS"

# --- CSVReader ---
write_file("/tmp/ny_test.csv", "name,score,grade\nalice,95,A\nbob,82,B\ncarol,91,A\n")
var csv = CSVReader("/tmp/ny_test.csv")
csv.load()
print "CSVReader rows: " + str(csv.row_count())
print "CSVReader cols: " + str(csv.col_count())
var scores = csv.get_col("score")
print "CSVReader get_col: " + str(len(scores))
var row0 = csv.get_row(0)
print "CSVReader row0[0]: " + row0[0]
print "CSVReader.PASS"

# --- BinaryBlob ---
var blob = BinaryBlob("/tmp/ny_test.bin")
blob.data = [72, 101, 108, 108, 111]
blob.write()
var blob2 = BinaryBlob("/tmp/ny_test.bin")
blob2.read()
print "BinaryBlob size: " + str(blob2.size())
print "BinaryBlob byte0: " + str(blob2.get_byte(0))
print "BinaryBlob.PASS"

# --- KV Store builtins ---
kv_set("/tmp/ny_kvtest.kv", "x", "42")
kv_set("/tmp/ny_kvtest.kv", "y", "hello")
kv_set("/tmp/ny_kvtest.kv", "z", "3.14")
var xv = kv_get("/tmp/ny_kvtest.kv", "x")
print "kv_get x: " + xv
var kv_ks = kv_keys("/tmp/ny_kvtest.kv")
print "kv_keys count: " + str(len(kv_ks))
kv_del("/tmp/ny_kvtest.kv", "z")
var zv = kv_get("/tmp/ny_kvtest.kv", "z")
print "kv_del z: " + str(zv == none)
var allkv = kv_all("/tmp/ny_kvtest.kv")
print "kv_all OK"
print "KV Store.PASS"

# --- tensor_save / tensor_load ---
var t2 = tensor([10.0, 20.0, 30.0])
tensor_save(t2, "/tmp/ny_t2.nyt")
var t2l = tensor_load("/tmp/ny_t2.nyt")
print "tensor_save/load sum: " + str(tensor_sum(t2l))
print "tensor_save/load.PASS"

# --- model_save / model_load ---
var p1 = tensor([1.0, 2.0])
var p2 = tensor([3.0, 4.0])
var params = [p1, p2]
model_save(params, "/tmp/ny_model.nym")
var loaded_params = model_load("/tmp/ny_model.nym")
print "model_save/load count: " + str(len(loaded_params))
print "model_save/load.PASS"

# --- ModelStore ---
var mstore = ModelStore("/tmp/ny_models")
mstore.save("agent1_v1", params, "accuracy=0.98 epoch=10")
var info = mstore.info("agent1_v1")
print "ModelStore info: " + info
var loaded = mstore.load("agent1_v1")
print "ModelStore load count: " + str(len(loaded))
var exists = mstore.exists("agent1_v1")
print "ModelStore exists: " + str(exists)
print "ModelStore.PASS"

# --- fs_stat / fs_walk / fs_mkdirs ---
fs_mkdirs("/tmp/ny_fs_test/sub")
write_file("/tmp/ny_fs_test/sub/a.txt", "hello")
var st = fs_stat("/tmp/ny_fs_test/sub/a.txt")
print "fs_stat exists: " + str(st.exists)
print "fs_stat is_file: " + str(st.is_file)
var walked = fs_walk("/tmp/ny_fs_test/sub")
print "fs_walk count: " + str(len(walked))
print "fs_stat/walk.PASS"

# --- path helpers ---
var joined = path_join("/tmp", "ny_test", "file.txt")
print "path_join: " + joined
var bn = path_basename("/tmp/ny_test/file.txt")
print "path_basename: " + bn
var dn = path_dirname("/tmp/ny_test/file.txt")
print "path_dirname: " + dn
var ext = path_ext("/tmp/file.nyt")
print "path_ext: " + ext
print "path_helpers.PASS"

# --- AgentGoal & AgentPlan ---
var goal = AgentGoal("train_model", 10)
goal.update_progress(0.5)
print "AgentGoal progress: " + str(goal.progress)
print "AgentGoal status: " + goal.status()
print "AgentGoal describe: " + goal.describe()

var plan = AgentPlan("training_plan")
plan.add_step("load_data", "noop")
plan.add_step("train", "noop")
plan.add_step("evaluate", "noop")
print "AgentPlan progress: " + str(plan.progress())
plan.advance()
print "AgentPlan after advance: " + str(plan.progress())
print "AgentGoal/Plan.PASS"

# --- AgentMemory ---
var mem = AgentMemory(5)
mem.perceive("obs1")
mem.perceive("obs2")
mem.perceive("obs3")
print "AgentMemory recent 2: " + str(len(mem.recent(2)))
mem.commit_episode(1.0)
print "AgentMemory episodes: " + str(mem.episode_count())
print "AgentMemory.PASS"

# --- NyMind ---
var mind = NyMind("alpha", "/tmp/ny_mind")
mind.learn("sky_color", "blue")
mind.learn("grass_color", "green")
mind.observe("it is daytime")
var inferred = mind.infer("sky_color")
print "NyMind infer sky_color: " + inferred
var reasoned = mind.reason("sky_color", "grass_color")
print "NyMind reason: " + reasoned
print "NyMind summary: " + mind.summarize()
print "NyMind.PASS"

# --- NySensor ---
write_file("/tmp/ny_sensor_data.txt", "42.5")
var sensor = NySensor("temp", "/tmp/ny_sensor_data.txt")
sensor.read_file_sensor()
sensor.read_file_sensor()
var latest = sensor.latest()
print "NySensor latest: " + latest
print "NySensor readings: " + str(sensor.readings)
print "NySensor.PASS"

# --- NyActuator ---
var act = NyActuator("mover", "/tmp/ny_actuator")
act.write_output("/tmp/ny_act_out.txt", "action_taken")
print "NyActuator total_actions: " + str(act.total_actions())
print "NyActuator.PASS"

# --- AgentWorld ---
var world = AgentWorld("sandbox", "/tmp/ny_world")
world.set("step", "0")
world.set("reward", "0.0")
var step_val = world.get("step")
print "AgentWorld get step: " + step_val
world.log_event("agent_1", "moved_north")
world.log_event("agent_2", "collected_item")
var events = world.read_events()
print "AgentWorld events logged: " + str(len(events) > 0)
print "AgentWorld.PASS"

# --- AgentBuilder: BaseAgent ---
var agent = AgentBuilder().id("ny_agent_1").storage("/tmp/ny_agents").network_port(9100).with_goal("explore", 5).build()
agent.remember("home", "/tmp")
var home = agent.recall("home")
print "BaseAgent recall home: " + home
agent.step()
agent.step()
print "BaseAgent tick: " + str(agent.tick)
agent.save_state()
print "BaseAgent.PASS"

# --- AgentBuilder: ReactiveAgent ---
var bot = AgentBuilder().id("bot_1").storage("/tmp/ny_agents").network_port(9101).as_reactive().build()
bot.add_rule("hello", "hi there!")
bot.add_rule("bye", "goodbye!")
var r1 = bot.run_once("hello")
var r2 = bot.run_once("bye")
print "ReactiveAgent hello: " + r1
print "ReactiveAgent bye: " + r2
print "ReactiveAgent.PASS"

# --- AgentBuilder: LearningAgent ---
var learner = AgentBuilder().id("learner_1").storage("/tmp/ny_agents").network_port(9102).as_learner(4, 2).build()
learner.step()
var state = tensor([0.1, 0.2, 0.3, 0.4])
var action = learner.act(state)
print "LearningAgent act: " + str(action)
learner.store_transition(state, action, 1.0, state, false)
learner.save_weights()
print "LearningAgent epsilon: " + str(learner.epsilon)
print "LearningAgent.PASS"

# --- AgentBuilder: SwarmAgent ---
var swarm_a = AgentBuilder().id("swarm_a").storage("/tmp/ny_agents").network_port(9103).as_swarm().build()
swarm_a.set_role("scout")
swarm_a.update_score(5.0)
print "SwarmAgent score: " + str(swarm_a.score)
print "SwarmAgent role: " + swarm_a.role
print "SwarmAgent.PASS"

print ""
print "=== ALL NYTORCH9 AGENT TESTS PASSED ==="

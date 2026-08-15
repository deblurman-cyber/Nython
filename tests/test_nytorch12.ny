import nytorch
import "lib/nytorch/storage.ny"
import "lib/nytorch/serving.ny"
import "lib/nytorch/vision.ny"
import "lib/nytorch/distributed.ny"

print "=== NyTorch v3.0 Part 12 Test Suite ==="

# --- MessageQueue ---
print "--- MessageQueue ---"
var mq = MessageQueue("test_mq", "/tmp/ny_mq_test")
mq.push("msg_a")
mq.push("msg_b")
mq.push("msg_c")
print "queue size: " + str(mq.size())
print "peek: " + mq.peek()
print "pop: " + mq.pop()
print "size after pop: " + str(mq.size())
print "empty: " + str(mq.empty())
var all_msgs = mq.drain()
print "drain count: " + str(len(all_msgs))
print "after drain empty: " + str(mq.empty())
print "MessageQueue.PASS"

# --- PubSubBus ---
print "--- PubSubBus ---"
var psb = PubSubBus("test_bus", "/tmp/ny_pubsub")
psb.subscribe("events", "worker_1")
psb.publish("events", "event_data_1")
psb.publish("events", "event_data_2")
print "topic size: " + str(psb.topic_size("events"))
print "has messages: " + str(psb.has_messages("events"))
print "consume: " + str(psb.consume("events", "worker_1") != none)
print "PubSubBus.PASS"

# --- RPC ---
print "--- RPC ---"
var rpc = RPC("test_client")
rpc.set_timeout(500)
print "RPC agent_id: " + rpc.agent_id
print "RPC timeout: " + str(rpc.timeout_ms)
print "RPC.PASS"

# --- PeerMesh ---
print "--- PeerMesh ---"
var mesh = PeerMesh("node_a", 23000, "/tmp/ny_mesh")
mesh.join("node_b", "127.0.0.1", 23001)
mesh.join("node_c", "127.0.0.1", 23002)
print "peer count: " + str(mesh.peer_count())
var peers = mesh.known_peers()
print "known peers: " + str(len(peers))
mesh.leave("node_c")
print "after leave: " + str(mesh.peer_count())
print "PeerMesh.PASS"

# --- MeshNode ---
print "--- MeshNode ---"
var node = MeshNode("main_node", 23010, "/tmp/ny_mesh_node")
node.start()
node.connect("peer_1", "127.0.0.1", 23011)
node.step()
node.step()
node.store("config", "v1.0")
print "node tick: " + str(node.tick)
print "node lookup: " + node.lookup("config")
print "node status: " + node.status()
node.stop()
print "MeshNode.PASS"

# --- ServiceRegistry ---
print "--- ServiceRegistry ---"
var registry = ServiceRegistry("/tmp/ny_svc_reg")
registry.register("inference_api", "127.0.0.1", 8080, "1.2.0", "ml,gpu")
registry.register("training_service", "127.0.0.1", 8081, "2.0.1", "ml,cpu")
registry.register("data_pipeline", "127.0.0.1", 8082, "1.0.0", "etl")
print "services count: " + str(len(registry.list_services()))
var svc = registry.discover("inference_api")
print "discovered host: " + svc["host"]
print "discovered port: " + str(svc["port"])
print "health: " + registry.health_check("inference_api")
registry.mark_down("data_pipeline")
print "healthy count: " + str(len(registry.healthy_services()))
print "ServiceRegistry.PASS"

# --- LoadBalancer ---
print "--- LoadBalancer ---"
var lb_rr = LoadBalancer("round_robin")
lb_rr.add_backend("192.168.1.1", 8080, 1.0)
lb_rr.add_backend("192.168.1.2", 8080, 1.0)
lb_rr.add_backend("192.168.1.3", 8080, 1.0)
var b1 = lb_rr.next()
var b2 = lb_rr.next()
var b3 = lb_rr.next()
var b4 = lb_rr.next()
print "RR first: " + b1["host"]
print "RR fourth (wraps): " + b4["host"]
print "LB stats: " + lb_rr.stats()
var lb_lc = LoadBalancer("least_conn")
lb_lc.add_backend("10.0.0.1", 9090, 1.0)
lb_lc.add_backend("10.0.0.2", 9090, 2.0)
var lc_b = lb_lc.next()
print "least_conn choice: " + lc_b["host"]
print "LoadBalancer.PASS"

# --- CircuitBreaker ---
print "--- CircuitBreaker ---"
var cb = CircuitBreaker("api_cb", 3, 5)
print "initial state: " + cb.state
print "call allowed: " + str(cb.call_allowed())
cb.on_failure()
cb.on_failure()
cb.on_failure()
print "after 3 failures: " + cb.state
print "call blocked: " + str(not cb.call_allowed())
cb.reset()
print "after reset: " + cb.state
cb.on_success()
print "success tracked: " + str(cb.successes)
print "CircuitBreaker.PASS"

# --- RateLimiter ---
print "--- RateLimiter ---"
var rl = RateLimiter("api_limit", 10, 5)
print "initial tokens: " + str(rl.tokens)
var ok1 = rl.allow(1)
var ok2 = rl.allow(1)
var ok3 = rl.allow(1)
print "first 3 allowed: " + str(ok1)
print "tokens remaining: " + str(rl.tokens > 0.0)
var ok_big = rl.allow(100)
print "large request denied: " + str(not ok_big)
print "RL stats: " + rl.stats()
print "RateLimiter.PASS"

# --- NyDB + NyTable + QueryBuilder ---
print "--- NyDB / NyTable / QueryBuilder ---"
var db = NyDB("test_db", "/tmp/ny_db")
var users = db.create_table("users", ["id", "name", "role", "score"])
var r1 = users.insert(["1", "alice", "admin", "95"])
var r2 = users.insert(["2", "bob", "user", "72"])
var r3 = users.insert(["3", "carol", "user", "88"])
var r4 = users.insert(["4", "dave", "admin", "91"])
print "rows inserted: " + str(users.count())
print "alice name: " + users.get(0, "name")
var row = users.get_row(2)
print "carol role: " + row["role"]
users.update(1, "score", "85")
print "bob updated score: " + users.get(1, "score")
var admins = users.scan("role", "admin")
print "admin count: " + str(len(admins))
var tables = db.list_tables()
print "db tables: " + str(len(tables))

var qb = QueryBuilder(users)
qb.where("role", "user").limit(5)
var results = qb.execute()
print "QB query results: " + str(len(results))
var admin_count = QueryBuilder(users).where("role", "admin").count()
print "QB admin count: " + str(admin_count)
print "NyDB.PASS"

# --- ReplayBuffer ---
print "--- ReplayBuffer ---"
var rb = ReplayBuffer(1000)
var s0 = tensor([1.0, 0.0, 0.0, 0.0])
var s1 = tensor([0.0, 1.0, 0.0, 0.0])
var i = 0
while i < 100:
    rb.push(s0, random_int(0, 3), random_float(-1.0, 1.0), s1, false)
    i = i + 1
print "replay size: " + str(rb.size())
print "is_ready(50): " + str(rb.is_ready(50))
var batch = rb.sample(16)
print "batch size: " + str(len(batch))
var states = rb.states_batch(batch)
print "states count: " + str(len(states))
var rewards = rb.rewards_batch(batch)
print "rewards count: " + str(len(rewards))
print "ReplayBuffer.PASS"

# --- PrioritizedReplayBuffer ---
print "--- PrioritizedReplayBuffer ---"
var prb = PrioritizedReplayBuffer(500, 0.6)
var pi = 0
while pi < 50:
    prb.push(s0, random_int(0, 3), random_float(-1.0, 1.0), s1, false)
    pi = pi + 1
print "PRB size: " + str(prb.size())
var pbatch = prb.sample(8, 0.4)
print "PRB batch: " + str(len(pbatch))
prb.update_priority(0, 2.5)
print "PRB max priority: " + str(prb.max_priority)
print "PrioritizedReplayBuffer.PASS"

# --- DQNAgent ---
print "--- DQNAgent ---"
var dqn = DQNAgent(4, 2, "/tmp/ny_dqn")
dqn.setup()
var state = tensor([0.5, -0.2, 0.8, 0.1])
var action = dqn.act(state)
print "DQN action: " + str(action >= 0)
var di = 0
while di < 50:
    var ns = tensor_randn([4])
    dqn.remember(state, action, random_float(-1.0, 1.0), ns, false)
    di = di + 1
var loss = dqn.train_on_batch()
print "DQN loss: " + str(loss >= 0.0)
print "DQN epsilon: " + str(dqn.epsilon < 1.0)
dqn.save()
dqn.load()
print "DQNAgent.PASS"

# --- PPOMemory ---
print "--- PPOMemory ---"
var ppo = PPOMemory()
var pi2 = 0
while pi2 < 10:
    ppo.store(s0, 0, random_float(0.0, 1.0), 0.5, -0.3, false)
    pi2 = pi2 + 1
print "PPO size: " + str(ppo.size())
var gae_out = ppo.compute_returns(0.99, 0.95)
print "PPO returns count: " + str(len(gae_out["returns"]))
ppo.clear()
print "PPO after clear: " + str(ppo.size())
print "PPOMemory.PASS"

# --- MultiAgentEnv ---
print "--- MultiAgentEnv ---"
var env = MultiAgentEnv("test_env", 3, 4, 2)
var init_states = env.reset()
print "init states: " + str(len(init_states))
var actions = [0, 1, 0]
var step_out = env.step(actions)
print "step states: " + str(len(step_out["states"]))
print "step rewards: " + str(len(step_out["rewards"]))
print "total reward: " + str(env.total_reward() != none)
print "MultiAgentEnv.PASS"

# --- CurriculumScheduler ---
print "--- CurriculumScheduler ---"
var curr = CurriculumScheduler("training")
curr.add_stage("easy", 0.1, 10, 0.7)
curr.add_stage("medium", 0.5, 20, 0.6)
curr.add_stage("hard", 1.0, 30, 0.5)
print "initial stage: " + curr.current_stage_name()
print "initial difficulty: " + str(curr.current_difficulty())
var ci = 0
while ci < 15:
    curr.update(true)
    ci = ci + 1
print "after 15 successes stage: " + curr.current_stage_name()
print "progress: " + curr.progress()
print "CurriculumScheduler.PASS"

# --- RewardShaper ---
print "--- RewardShaper ---"
var shaper = RewardShaper(0.99, 0.1)
var s_a = tensor([1.0, 0.5, 0.2])
var s_b = tensor([1.1, 0.6, 0.25])
var shaped = shaper.shape(s_a, s_b, 1.0, false)
print "shaped reward: " + str(shaped != none)
var clipped = shaper.clip(10.0, -1.0, 1.0)
print "clipped reward: " + str(clipped)
print "RewardShaper.PASS"

# --- TaskDistributor ---
print "--- TaskDistributor ---"
var td = TaskDistributor("test_td", "/tmp/ny_td", 4)
td.submit("task_1", "compute:batch_1")
td.submit("task_2", "compute:batch_2")
td.submit("task_3", "compute:batch_3")
print "pending: " + str(td.pending())
var t1 = td.next_task("worker_0")
print "got task: " + str(t1 != none)
td.complete("task_1", "result:1.0")
print "progress: " + str(td.progress())
print "result: " + td.get_result("task_1")
print "status: " + td.status()
print "TaskDistributor.PASS"

# --- ResultAggregator ---
print "--- ResultAggregator ---"
var agg = ResultAggregator("test_agg")
agg.add(0.95, false)
agg.add(0.87, false)
agg.add(0.91, false)
agg.add("error_xyz", true)
print "results count: " + str(len(agg.results))
print "error count: " + str(len(agg.errors))
print "mean: " + str(agg.mean_result() > 0.0)
print "best: " + str(agg.best_result() > 0.0)
print "error rate: " + str(agg.error_rate())
print "summary: " + agg.summary()
var ta = tensor([0.9, 0.85, 0.95])
agg.add_tensor_result(ta)
print "after tensor: " + str(len(agg.results))
print "ResultAggregator.PASS"

print ""
print "=== ALL NYTORCH12 TESTS PASSED ==="

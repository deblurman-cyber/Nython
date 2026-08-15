# Nython Standard Library

## Core Modules

| Module | Description | Key Features |
|--------|-------------|--------------|
| `stdlib.ny` | Standard library | Math, collections, functional programming, sorting, string utilities |
| `gui.ny` | GUI framework | SDL2+OpenGL windowing, widgets, layout, event handling, drawing |
| `os.ny` | OS interface | File I/O, paths, directories, environment variables, process control |
| `thread.ny` | Threading | Mutex, locks, thread spawn/join, synchronization primitives |

## Networking Stack

| Module | Description | Key Features |
|--------|-------------|--------------|
| `network.ny` | Network library | HTTP client, URL parsing, headers, request/response |
| `sockets.ny` | Raw sockets | TCP/UDP client/server, socket options, timeouts |
| `webserver.ny` | Web server | HTTP server, routing, middleware, static files, JSON API |
| `clientserver.ny` | Client-Server | RPC framework, message protocol, connection management |

## AI & Machine Learning

| Module | Description | Key Features |
|--------|-------------|--------------|
| `aiagent.ny` | AI Agent framework | NyxAI: tool-using agents, planning, memory, reasoning |
| `nytorch.ny` | ML framework (entry point) | Imports all 17 NyTorch modules (220+ classes) |

## Language Extension

| Module | Description | Key Features |
|--------|-------------|--------------|
| `langdef.ny` | Runtime language extension | Define new tokens, operators, syntax rules at runtime |

---

## NyTorch Module Reference (`lib/nytorch/`)

Import everything: `import nytorch` or `import "lib/nytorch.ny"`
Import selectively: `import "lib/nytorch/losses.ny"`

### Core ML
| Module | Classes |
|--------|---------|
| `activations.ny` | Tensor, ReLULayer, SigmoidLayer, TanhLayer, SoftmaxLayer, GeLULayer, SiLULayer, ELULayer |
| `layers.ny` | Linear, Dropout, BatchNorm, LayerNorm, RMSNorm, SoftshrinkLayer, CELULayer, ThresholdLayer |
| `attention.ny` | SelfAttention, MultiHeadAttention, TransformerBlock, CausalSelfAttention, RNNCell, GRUCell, LSTMCell |
| `losses.ny` | MSELoss, MAELoss, BCELoss, CrossEntropyLoss, HuberLoss, FocalLoss, LabelSmoothingLoss, SwiGLU |
| `optimizers.ny` | AdamW, AdaGrad, RMSProp, NAdam, Lion, StepLR, CosineAnnealingLR, ReduceLROnPlateau |

### Data & Training
| Module | Classes |
|--------|---------|
| `data.ny` | Dataset, DataLoader, Normalizer, MinMaxScaler, Metrics, ConfusionMatrix, TrainingHistory, RunningMean |

### Advanced Architectures
| Module | Classes |
|--------|---------|
| `advanced.ny` | LoRALayer, QuantizedLinear, SpectralNorm, MixtureOfExperts, Expert, S4Layer, MambaBlock, UniformDist |
| `memory.ny` | VectorQuantizer, EWC, MAMLInner, PrototypicalNet, NTMMemory, KVCache, KnowledgeBase, Agent |
| `sequence.ny` | RetentionHead, RetNet, RWKVTimeMix, RWKVChannelMix, RWKVBlock, RWKV, SelectiveSSM |

### Computer Vision
| Module | Classes |
|--------|---------|
| `vision.ny` | ImageTensor, ImageAugmentor, FeatureExtractor, ClassificationHead, AnchorBox |
| `convnets.ny` | ConvBlock, ResidualBlock, SimpleResNet, YOLOHead |

### Reinforcement Learning
| Module | Classes |
|--------|---------|
| `reinforcement.ny` | SACAgent, TD3Agent, A2CAgent, PPOAgent |

### Scientific Computing
| Module | Classes |
|--------|---------|
| `neural_ode.ny` | ODESolver, LiquidNeuron, LiquidNeuralNetwork, NeuralODE |

### Infrastructure
| Module | Classes |
|--------|---------|
| `storage.ny` | StorageManager, ModelStore, KnowledgeBase, DataLogger, DataPipeline |
| `serving.ny` | SocketServer, HttpRouter, HttpServer, AgentServer, AgentHttpClient |
| `distributed.ny` | MessageQueue, PubSubBus, RPC, PeerMesh, MeshNode |
| `compute.ny` | DeviceManager, TensorDevice, ComputeScheduler, OptimizedLayer, UniversalLoader, WebScraper |

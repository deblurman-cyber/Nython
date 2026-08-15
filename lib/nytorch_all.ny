# ─── nytorch, all modules ────────────────────────────────────────────────────
# Aggregator for the nytorch package.
#
# Several bundled examples (quickstart.ny, test_nytorch3.ny, test_nytorch9.ny)
# import "lib/nytorch_all.ny", but the file did not exist. Because a module that
# could not be found used to resolve silently, those examples appeared to import
# successfully and then failed later on `Tensor is not defined` — with nothing
# pointing at the missing import as the cause. All seventeen submodules were
# present the whole time; only this aggregator was absent.
#
# Order matters: activations.ny defines Tensor, which the rest build on.

import "lib/nytorch/activations.ny"
import "lib/nytorch/compute.ny"
import "lib/nytorch/layers.ny"
import "lib/nytorch/losses.ny"
import "lib/nytorch/optimizers.ny"
import "lib/nytorch/attention.ny"
import "lib/nytorch/convnets.ny"
import "lib/nytorch/sequence.ny"
import "lib/nytorch/vision.ny"
import "lib/nytorch/data.ny"
import "lib/nytorch/storage.ny"
import "lib/nytorch/memory.ny"
import "lib/nytorch/advanced.ny"
import "lib/nytorch/neural_ode.ny"
import "lib/nytorch/reinforcement.ny"
import "lib/nytorch/distributed.ny"
import "lib/nytorch/serving.ny"

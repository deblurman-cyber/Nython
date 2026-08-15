# Writing Nython that the runtime can afford

The interpreter does not reclaim containers (see FIXES round 22 onward). Every
list a program builds and discards stays resident for the life of the process.
That makes a few ordinary-looking patterns extremely expensive, and the cost
shows up as resident memory rather than as a slow function, so it is easy to
miss until a large input arrives.

Numbers below are measured, not estimated.

## 1. Never grow a list with `x = x + [y]`

```
var a = []
while i < 4000:
    a = a + [i]        # 19,881 ms   2,417 MB
    i = i + 1

var b = []
while i < 4000:
    b.append(i)        #     23 ms       1 MB
    i = i + 1
```

**~860x slower, ~2400x the memory, identical result.** `x = x + [y]` allocates a
new list of length n on every iteration; `append` mutates in place. At 20,000
elements the concatenating version is OOM-killed at 3.8 GB.

The same applies to strings built in a loop (`s = s + piece`) and to slicing a
remainder repeatedly (`rem = rem[n:]`). Prefer `string_split`, `join`, or an
index that walks the original.

## 2. Do not snapshot state for undo/history

A history entry that copies a data structure costs O(size) allocation per edit,
and the discards are permanent. `lib/gui_piecetable.ny` originally stored a copy
of its piece list per edit:

```
400 edits, max_undo=200   ->  373 MB
400 edits, max_undo=50    ->  367 MB
400 edits, max_undo=10    ->  363 MB
```

Capping the history barely helped, which is the diagnostic: the memory was the
*discarded* snapshots, not the retained ones, so no cap could ever fix it.

Recording the inverse **operation** instead — four scalars, plus the removed
text for a delete — is O(1) per edit:

```
400 edits, operation-based ->   56 MB
```

`nython_ide.ny` still snapshots whole file text for undo. It is bounded (~4 MB
budget, identical states skipped), but the bound is a mitigation; the piece
table's operation log is the fix.

## 3. Mutating in place changes aliasing

Switching `_push_undo` from `stack = stack + [snap]` to `stack.append(snap)`
silently broke `replace()`, which had saved and restored `self.undo_stack` to
discard an entry. That worked only while the stack was *replaced* each push;
once it was mutated in place, the saved name referred to the same object and the
restore did nothing.

When converting concatenation to `append`, check every place that holds a
second reference to the list.

## 4. Reuse buffers across frames

The IDE's frame loop runs at display rate. Anything allocated per frame is
allocated forever. Build lists once and clear them, or keep an index into
existing data instead of materialising a new list to draw from.

## Rule of thumb

If a loop body allocates, ask what happens when the loop runs 10,000 times. On
this runtime the answer is "the memory is gone until the process exits", so
prefer in-place mutation, operation logs over state copies, and indices over
slices.

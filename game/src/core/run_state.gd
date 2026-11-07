class_name RunState
extends RefCounted
## Mutable state of one run (Story 1.6 DC1). Owned by Game as Game.run.
## deaths_on_boss (2.9) and the register snapshot (2.3) arrive with their stories.

## 0, 1, 2 for Fight 1, 2, 3.
var boss_index: int = 0

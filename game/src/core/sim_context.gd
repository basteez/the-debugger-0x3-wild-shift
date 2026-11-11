class_name SimContext
extends RefCounted
## Shared simulation context passed to every SimSystem.tick (AD-01).
## Holds the one seeded RNG: all simulation randomness comes from `rng`, never the global RNG.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The held direction for the current polled frame (Story 2.2, D-S22-3), components in {-1, 0, 1}.
## Set by SimClock before the systems tick; read-only for systems.
var move_dir: Vector2i = Vector2i.ZERO
## The polled frame being ticked (SimClock.poll_frame before it advances, D-S23-2): the InputBuffer
## time base for consume calls. Set by SimClock before the systems tick; read-only for systems.
var poll_frame: int = 0
## Story 5.4 (D-S54-2): the raw Watch input of the current polled frame (R down), set by SimClock
## from the InputSource before the poll hooks. Only the Watch module reads it (its poll).
var watch_input: bool = false
## Story 5.4 (D-S54-3): Watch is held this tick. Copied by SimClock from its generic
## watch_gate_active after the poll hooks, before the systems tick; read-only for systems (Player,
## ActionStateMachine and the Null Pointer body read it; nothing else does).
var watch_held: bool = false
## Story 5.5 (D-S55-3): a slows_move action (Null Dodge) is in its ACTIVE frames this tick.
## Written only by ActionStateMachine (end of its tick), read by Player (x0.5 top speed, the Watch
## factor; the two do not stack).
var move_slowed: bool = false


## Reseeds the RNG (fight start, retry). The same seed always gives the same sequence.
func reseed(seed_value: int) -> void:
	rng.seed = seed_value

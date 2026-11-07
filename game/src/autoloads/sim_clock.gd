extends Node
## Fixed 60 Hz simulation clock (AD-01, NP-2). Each physics frame: gate on pause, poll the
## InputSource into the InputBuffer, gate on Breakpoint then hit-stop, else tick the registered
## SimSystems by phase and advance sim_frame. Only SimClock calls tick().

## World ticks since the session started (not paused or gated frames, D-S21-2). Monotonic.
var sim_frame: int = 0
## Pause gate. Written only by Game (Story 1.7 DC2).
var paused: bool = false
## Input for the simulation. LiveInput in play (_ready); null = no presses (headless tests).
var input_source: InputSource = null
var buffer: InputBuffer = InputBuffer.new()
var ctx: SimContext = SimContext.new()
## Breakpoint gate hook (Story 4.3 owns its body). While true the world and hit-stop are frozen.
var breakpoint_gate_active: bool = false
## Remaining hit-stop frames. Counts down once per physics frame outside pause and Breakpoint.
var hitstop_frames: int = 0
## Debug input recorder (F11). Null unless DebugKeys started one (Debug.enabled only).
var recorder: InputRecorder = null

var _pending_hitstop: int = 0
## Registered systems, kept sorted by phase, registration order within a phase.
var _systems: Array[SimSystem] = []


func _ready() -> void:
	input_source = LiveInput.new()


func _physics_process(_delta: float) -> void:
	tick()


## One physics frame (called only from _physics_process, and directly by headless tests).
func tick() -> void:
	if paused: # D-S21-9: no poll, so a press made during pause never fires on resume
		return
	var presses: Array[StringName] = []
	if input_source != null:
		presses = input_source.presses_for_frame()
	for action: StringName in presses:
		buffer.push(action, sim_frame)
	if recorder != null:
		recorder.record(presses)
	if breakpoint_gate_active: # world frozen, hit-stop counter untouched (NP-2, D-S21-11)
		return
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return
	for system: SimSystem in _systems:
		system.tick(ctx)
	if _pending_hitstop > 0:
		hitstop_frames = maxi(hitstop_frames, _pending_hitstop)
		Log.debug(&"sim", "hit-stop %d frames" % hitstop_frames)
		_pending_hitstop = 0
	sim_frame += 1


## Adds a system to the tick. Stable: after every system of the same or an earlier phase.
func register_system(system: SimSystem) -> void:
	var at: int = _systems.size()
	for i: int in _systems.size():
		if _systems[i].phase > system.phase:
			at = i
			break
	_systems.insert(at, system)


## Requests a hit-stop from inside a world tick. The maximum request of the tick wins (AD-01).
func request_hitstop(frames: int) -> void:
	_pending_hitstop = maxi(_pending_hitstop, frames)


## Fight start / retry: reseed the RNG, drop buffered presses and any hit-stop.
## sim_frame is not reset (monotonic per session).
func begin_fight(seed_value: int) -> void:
	ctx.reseed(seed_value)
	buffer.clear()
	hitstop_frames = 0
	_pending_hitstop = 0
	Log.debug(&"sim", "begin fight seed=%d" % seed_value)

extends Node
## Fixed 60 Hz simulation clock (AD-01, NP-2). Each physics frame: gate on pause, poll the
## InputSource (presses into the InputBuffer stamped with poll_frame, held direction into
## ctx.move_dir, ctx.poll_frame), advance poll_frame, gate on
## Breakpoint then hit-stop, else tick the registered SimSystems by phase and advance
## sim_frame. Only SimClock calls tick().

## World ticks since the session started (not paused or gated frames, D-S21-2). Monotonic.
var sim_frame: int = 0
## Polled (non-paused) physics frames since the session started, including hit-stop and Breakpoint
## frames (D-S23-2). The InputBuffer time base, so a press made during hit-stop still ages and
## expires. Monotonic. sim_frame keeps counting world ticks only.
var poll_frame: int = 0
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
## Story 2.9 (D-S29-12): the next polled tick drops its presses (the retry press never fires).
var _swallow_presses: bool = false
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
	if _swallow_presses:
		_swallow_presses = false
		presses = [] # never clear(): the source may hand back its own backing array
	for action: StringName in presses:
		buffer.push(action, poll_frame)
	ctx.move_dir = input_source.move_for_frame() if input_source != null else Vector2i.ZERO
	ctx.poll_frame = poll_frame
	if recorder != null:
		recorder.record(presses, ctx.move_dir)
	poll_frame += 1 # counts this polled frame even when a gate below freezes the world
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
	if _systems.has(system): # never tick a system twice (double speed)
		return
	var at: int = _systems.size()
	for i: int in _systems.size():
		if _systems[i].phase > system.phase:
			at = i
			break
	_systems.insert(at, system)


## Removes a system from the tick (by identity). No-op when it is not registered (D-S22-10).
func unregister_system(system: SimSystem) -> void:
	var at: int = _systems.find(system)
	if at >= 0:
		_systems.remove_at(at)


## Requests a hit-stop from inside a world tick. The maximum request of the tick wins (AD-01).
func request_hitstop(frames: int) -> void:
	_pending_hitstop = maxi(_pending_hitstop, frames)


## Retry only (D-S29-12): the next polled tick drops that tick's presses; movement is still read.
func swallow_presses_next_poll() -> void:
	_swallow_presses = true


## Fight start / retry: reseed the RNG, drop buffered presses and any hit-stop.
## sim_frame is not reset (monotonic per session).
func begin_fight(seed_value: int) -> void:
	ctx.reseed(seed_value)
	buffer.clear()
	hitstop_frames = 0
	_pending_hitstop = 0
	Log.debug(&"sim", "begin fight seed=%d" % seed_value)

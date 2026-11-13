class_name GhostEchoSystem
extends SimSystem
## Owns the one Ghost Echo decoy (Story 6.1, D-S61-3, D-S61-4, D-S61-5). A SimSystem in the
## BOSS_HAZARDS phase, registered by the Arena before any boss, so a decoy spawned this tick is
## already the boss's aim. Each world tick (hit-stop and Breakpoint freeze it, since SimClock does not
## tick systems then): the live decoy counts down one frame (removed at 0), then a change of
## ActionStateMachine.decoy_spawn_serial replaces it with a new one at the published start point,
## with its full lifetime. Never touches the FSM.

## The decoy (one object, reused). Shared with CombatResolver and the arena's target source.
var decoy: GhostDecoy = GhostDecoy.new()

var _actions: ActionStateMachine
## The FSM serial already turned into a decoy (or skipped by clear()).
var _seen_serial: int = 0


func _init(p_actions: ActionStateMachine = null) -> void:
	phase = SimPhase.BOSS_HAZARDS
	_actions = p_actions
	_seen_serial = p_actions.decoy_spawn_serial if p_actions != null else 0


## One world frame (only SimClock calls this).
func tick(_ctx: SimContext) -> void:
	if decoy.is_live():
		decoy.tick()
		if not decoy.is_live():
			Log.debug(&"combat", "ghost decoy expired")
	if _actions == null or _actions.decoy_spawn_serial == _seen_serial:
		return
	_seen_serial = _actions.decoy_spawn_serial
	decoy.spawn(_actions.decoy_origin_px, _actions.decoy_window, _actions.decoy_frames)
	Log.debug(&"combat", "ghost decoy at %s for %d" % [decoy.position_px, decoy.frames_left])


## Fight start, retry, defeat and fight exit (D-S61-6): no decoy, and a spawn published before the
## clear is never turned into one.
func clear() -> void:
	decoy.clear()
	if _actions != null:
		_seen_serial = _actions.decoy_spawn_serial

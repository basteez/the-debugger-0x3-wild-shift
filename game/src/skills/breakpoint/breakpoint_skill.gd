class_name BreakpointSkill
extends FightSkill
## Breakpoint (Story 4.3, FR24, NP-2, cut ladder #3): Space freezes the world for at most 120 polled
## frames while register shifts stay allowed; J or K ends it early (that press executes on the first
## unfrozen tick); then a 720-frame cooldown counted in world ticks. A leaf module (AD-12,
## D-S43-2): built only when FeatureFlags.breakpoint is on, held by the wiring as a FightSkill, and
## it talks to the core only through SimClock's generic hooks (poll, breakpoint_gate_active) and
## the EventBus breakpoint_started / breakpoint_ended signals.
## Registered with SimClock in the TIMERS phase: poll() runs every polled frame (start, end, the
## frozen-poll count), tick() runs on world ticks only (the cooldown).

## Longest Breakpoint in polled frames, the start poll included (GDD 2.0 s, D-S43-5, D-S43-16).
const MAX_FROZEN_POLLS := 120
## Cooldown in world ticks from the ending tick (GDD 12 s, D-S43-7). 7.4's assist halves it.
const COOLDOWN_FRAMES := 720
const START_ACTION := &"breakpoint"
## The presses that end a running Breakpoint (D-S43-8): the two action slots, never Q, E or Space.
const END_ACTIONS: Array[StringName] = [&"action_1", &"action_2"]

## True while the world is frozen by this skill.
var active: bool = false
## Polled frames since the start, the start poll counted as 1; 0 while not active.
var frozen_polls: int = 0
## World ticks left before Space is accepted again (0 = ready).
var cooldown_left: int = 0
## Breakpoint is usable this fight (Fight 2 or later, D-S43-6). Set by reset_for_fight.
var unlocked: bool = false
## True between reset_for_fight and end_fight (FIGHT only, D-S43-15).
var in_fight: bool = false
## The cooldown length this instance starts at each end (COOLDOWN_FRAMES unless injected).
var cooldown_frames: int = COOLDOWN_FRAMES

## The clock whose breakpoint_gate_active this skill writes (the SimClock autoload in play, a fresh
## clock in tests). Any Object with that bool property.
var _gate: Object
## Set when a Breakpoint ends: the next world tick (the ending tick, even if hit-stop delays it past
## the end poll) never decrements the cooldown (D-S43-7).
var _skip_next_tick: bool = false


func _init(p_gate: Object = null, p_cooldown_frames: int = COOLDOWN_FRAMES) -> void:
	phase = SimPhase.TIMERS
	_gate = p_gate
	cooldown_frames = maxi(p_cooldown_frames, 0)


func reset_for_fight(p_unlocked: bool) -> void:
	_stop(&"reset")
	unlocked = p_unlocked
	cooldown_left = 0 # the first use of every fight attempt is free (D-S43-6)
	_skip_next_tick = false
	in_fight = true


func end_fight() -> void:
	_stop(&"fight left")
	in_fight = false
	unlocked = false # the readout hides outside a fight; the next reset_for_fight sets it again
	cooldown_left = 0


func is_active() -> bool:
	return active


func is_unlocked() -> bool:
	return unlocked


func cooldown_left_frames() -> int:
	return cooldown_left


## True when a Space press this poll would start Breakpoint.
func can_start() -> bool:
	return in_fight and unlocked and not active and cooldown_left == 0


## Every polled frame, before the gates (D-S43-3): ends a running Breakpoint on J/K or at the cap,
## else starts one on Space.
func poll(presses: Array[StringName], ctx: SimContext) -> void:
	if not in_fight:
		return
	if active:
		frozen_polls += 1
		if _has_any(presses, END_ACTIONS):
			_end(ctx, &"action")
		elif frozen_polls >= MAX_FROZEN_POLLS:
			_end(ctx, &"cap")
		return
	if presses.has(START_ACTION) and can_start():
		active = true
		frozen_polls = 1
		_set_gate(true)
		Log.debug(&"sim", "breakpoint started at poll %d" % ctx.poll_frame)
		EventBus.breakpoint_started.emit()


## World ticks only (never frozen, hit-stop or paused frames): counts the cooldown down. The ending
## tick does not count, so Space is refused on the cooldown_frames world ticks after it (AC 8).
func tick(ctx: SimContext) -> void:
	if not in_fight:
		return
	if _skip_next_tick:
		_skip_next_tick = false
		return
	if cooldown_left > 0:
		cooldown_left -= 1


## Ends a running Breakpoint from poll: gate cleared before the world tick of this frame (NP-2).
func _end(ctx: SimContext, reason: StringName) -> void:
	_skip_next_tick = true
	cooldown_left = cooldown_frames
	_stop(reason)


## Clears the gate and emits breakpoint_ended once, if running. No cooldown change.
func _stop(reason: StringName) -> void:
	if not active:
		return
	active = false
	frozen_polls = 0
	_set_gate(false)
	Log.debug(&"sim", "breakpoint ended (%s)" % reason)
	EventBus.breakpoint_ended.emit()


func _set_gate(on: bool) -> void:
	if _gate != null:
		_gate.set(&"breakpoint_gate_active", on)


static func _has_any(presses: Array[StringName], actions: Array[StringName]) -> bool:
	for action: StringName in presses:
		if actions.has(action):
			return true
	return false

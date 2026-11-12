class_name WatchSkill
extends FightSkill
## Watch (Story 5.4, FR25, cut ladder #2): hold R to see what is hidden and what is coming. A held
## state, not a press (D-S54-2): every polled frame R is down in a fight where Watch is unlocked
## (Boss 2 on, D-S54-4) the skill is held; the first frame R is up ends it. A leaf module (AD-12,
## D-S54-3): built only when FeatureFlags.watch is on, held by the wiring as a FightSkill, and it
## talks to the core only through SimClock's generic hooks (poll, watch_gate_active, which SimClock
## copies into SimContext.watch_held) and the EventBus watch_started / watch_ended signals. The
## effects (half speed, no new J/K action, the ghost reveal) live in the core systems that read
## ctx.watch_held; this module never reads the boss (no decoy getter, AC 11) and draws no RNG.
## Registered with SimClock in the TIMERS phase: everything happens in poll(); tick() is a no-op.

## True while Watch is held this polled frame.
var held: bool = false
## Watch is usable this fight (Boss 2 or later, D-S54-4). Set by reset_for_fight.
var unlocked: bool = false
## True between reset_for_fight and end_fight (FIGHT only, D-S54-11).
var in_fight: bool = false

## The clock whose watch_gate_active this skill writes (the SimClock autoload in play, a fresh
## clock or a stand-in in tests). Any Object with that bool property.
var _gate: Object


func _init(p_gate: Object = null) -> void:
	phase = SimPhase.TIMERS
	_gate = p_gate


## D-S54-11: every fight entry (intro, retry, debug jump) releases Watch; a held R is re-read on the
## next poll, so it never carries into the fight from before the entry.
func reset_for_fight(p_unlocked: bool) -> void:
	_stop(&"reset")
	_set_gate(false)
	unlocked = p_unlocked
	in_fight = true


func end_fight() -> void:
	_stop(&"fight left")
	_set_gate(false)
	in_fight = false
	unlocked = false


func is_active() -> bool:
	return held


func is_unlocked() -> bool:
	return unlocked


func cooldown_left_frames() -> int:
	return 0


## Every polled frame, before the gates: held = the raw R of this frame while in a fight and
## unlocked; the gate follows it; the edges emit watch_started / watch_ended once.
func poll(_presses: Array[StringName], ctx: SimContext) -> void:
	var want: bool = in_fight and unlocked and ctx != null and ctx.watch_input
	if want == held:
		_set_gate(held) # belt and braces: the gate always mirrors the held state
		return
	if want:
		held = true
		_set_gate(true)
		Log.debug(&"sim", "watch started at poll %d" % ctx.poll_frame)
		EventBus.watch_started.emit()
	else:
		_stop(&"released")


## Releases a held Watch: clears the gate and emits watch_ended once. No-op when not held.
func _stop(reason: StringName) -> void:
	if not held:
		return
	held = false
	_set_gate(false)
	Log.debug(&"sim", "watch ended (%s)" % reason)
	EventBus.watch_ended.emit()


func _set_gate(on: bool) -> void:
	if _gate != null:
		_gate.set(&"watch_gate_active", on)

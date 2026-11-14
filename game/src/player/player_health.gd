class_name PlayerHealth
extends SimSystem
## The player's HP and post-hit invulnerability (Story 2.9, FR2, D-011, D-S29-1). A sim system in
## the COMBAT phase, registered after CombatResolver. The single writer of `hp`, `invuln_left` and
## `dead`. Presentation (the debug damage key) and, from Epic 3, boss attacks and contact only call
## queue_hit(): a request consumed on the next tick. Death is raised by Game (D-S29-2): this system
## emits EventBus.player_damaged(hp) and Game records the death at 0.

## Frames per blink block while invulnerable (D-S29-6): the `@` is hidden on alternate blocks.
const BLINK_BLOCK := 4
## Story 7.4 (FR60, D-S74-5): max HP under the "debug build" assist, scaled at read time (the
## PlayerDef .tres keeps its value).
const ASSIST_MAX_HP := 8

var def: PlayerDef
var hp: int = 0
## Story 7.4 (AC 5): the live max HP of this fight attempt (def.max_hp, or ASSIST_MAX_HP under
## assist). Set by _init and reset_for_fight; the HUD readout reads it.
var max_hp: int = 0
## Post-hit invulnerability frames still to run (counts down on sim frames, frozen by hit-stop).
var invuln_left: int = 0
## True from the lethal hit until the next fight start: no hit applies while dead.
var dead: bool = false
## Ticks only in FIGHT (Arena.enter_fight / leave_fight).
var active: bool = false

## One-slot hit request (queue_hit), consumed by the next tick.
var _pending: bool = false
## Dash invulnerability source (AC 2). Null in tests that do not need it.
var _actions: ActionStateMachine


func _init(p_def: PlayerDef = null, p_actions: ActionStateMachine = null) -> void:
	phase = SimPhase.COMBAT
	def = p_def
	_actions = p_actions
	max_hp = max_hp_for(def, false)
	hp = max_hp


func tick(_ctx: SimContext) -> void:
	if not active:
		return
	if invuln_left > 0:
		invuln_left -= 1
	if _pending:
		_pending = false
		apply_hit()


## Resolves one hit: ignored while dead, inside post-hit invulnerability or on a dash's
## invulnerable frame. Otherwise 1 HP (D-011), 60 frames of invulnerability and 4 of hit-stop.
## True when the hit landed.
func apply_hit() -> bool:
	if dead or invuln_left > 0:
		return false
	if _actions != null and _actions.invulnerable():
		# Story 5.5 (D-S55-4): a hit passing through an arms_clean_catch action (Null Dodge, live or
		# echoed: `action` is the running def either way) arms Clean Catch. Dash does not arm.
		if _actions.action != null and _actions.action.arms_clean_catch:
			_actions.arm_clean_catch()
		return false
	hp = maxi(hp - 1, 0)
	invuln_left = def.invuln_frames if def != null else 0
	if hp == 0:
		dead = true # no second hit resolves before Game raises the death
	SimClock.request_hitstop(HitFeedback.PLAYER_HITSTOP)
	Log.debug(&"combat", "player hit hp=%d" % hp)
	EventBus.player_damaged.emit(hp)
	return true


## Requests one hit on the next tick (the only entry point from outside the sim).
func queue_hit() -> void:
	_pending = true


## Fight start and retry (D-049 b): full HP, no invulnerability, alive, no pending hit.
## Story 7.4 (AC 5, 9, 12): `assist` is the attempt's injected flag (never read from SaveService).
func reset_for_fight(assist: bool = false) -> void:
	max_hp = max_hp_for(def, assist)
	hp = max_hp
	invuln_left = 0
	dead = false
	_pending = false


func set_active(on: bool) -> void:
	active = on
	if not on:
		_pending = false


## Story 7.4 (D-S74-5): the max HP for a fight attempt: ASSIST_MAX_HP under assist, else
## def.max_hp (0 without a def). Pure.
static func max_hp_for(p_def: PlayerDef, assist: bool) -> int:
	if p_def == null:
		return 0
	return ASSIST_MAX_HP if assist else p_def.max_hp


## The HP readout (GDD: `hp: 0b11111`): `max_hp` bits, the low `hp` bits set. Pure.
static func hp_text(p_hp: int, max_hp: int) -> String:
	var bits: String = ""
	for i: int in range(max_hp - 1, -1, -1):
		bits += "1" if i < p_hp else "0"
	return "hp: 0b" + bits


## True when the `@` is hidden on this frame of invulnerability (alternate 4-frame blocks, the
## first block hidden so the hit reads at once). Pure.
static func blink_hidden(p_invuln_left: int) -> bool:
	if p_invuln_left <= 0:
		return false
	@warning_ignore("integer_division")
	return ((p_invuln_left - 1) / BLINK_BLOCK) % 2 == 0

class_name BossController
extends SimSystem
## The reusable boss FSM (Story 3.1, AD-06, FR29-FR32): GAP -> TELL -> ACTIVE -> RECOVERY -> GAP,
## a 60-frame ROAR on each phase change, DEFEATED at 0 HP. Enum + match with int counters, ticked
## by SimClock in BOSS_HAZARDS. The single writer of the boss's HP, phase and state (AC 10);
## BossView, the HUD header and AudioManager read them or listen to EventBus. All randomness comes
## from SimContext.rng. Concrete bosses subclass this (speed ramp via _on_phase_reset) and put
## their attacks in src/bosses/<boss>/attacks/.
## Story 3.2: owns the WeakWindowTracker (`weak_window`, Patched), ticked here once per live tick;
## CombatResolver applies Patched and calls take_hit / mark_hit (NP-4, D-S32-3).

enum BossState { GAP, TELL, ACTIVE, RECOVERY, ROAR, DEFEATED }

## ROAR length in frames (FR30, D-S31-8).
const ROAR_FRAMES := 60
## Jitter steps (D-S31-9): level 1 at or below 66% HP, level 2 at or below 33%.
const JITTER_STEP_1_PERCENT := 66
const JITTER_STEP_2_PERCENT := 33
## Story 3.8 (D-S38-1): hit-stop requested on the defeat, then DEFEAT_FRAMES world ticks of
## reassembly counted in sim state (defeat_frames_elapsed) before presentation may leave FIGHT.
const DEFEAT_HITSTOP_FRAMES := 20
const DEFEAT_FRAMES := 60

var def: BossDef
## Arena-local centre of the body hurtbox (D-S31-12). Set by the arena or the boss's body.
var body_center_px: Vector2 = Vector2.ZERO
var hp: int = 0
var phase_index: int = 0
var state: BossState = BossState.GAP
## Ticks left in the current state (D-S31-5: a state entered with N lasts exactly N ticks).
var frames_left: int = 0
## The attack in TELL / ACTIVE / RECOVERY; null otherwise.
var current: AttackDef = null
## Ticks only while true (fight with a live boss).
var active: bool = false
## The last two picks as indices into the attack cache (-1 = none), most recent first (D-S31-6).
var last_pick: int = -1
var second_last_pick: int = -1
## Patched state (Story 3.2, D-S32-3). Only CombatResolver applies it; ticked here.
var weak_window: WeakWindowTracker = WeakWindowTracker.new()
## ActionStateMachine.action_serial of the last action that hit the boss; -1 = none (D-S32-10).
var last_hit_serial: int = -1
## Story 3.8 (A1, D-S38-1, D-S38-8): world ticks since the defeat, 0..DEFEAT_FRAMES. Counted in
## tick() while DEFEATED even though `active` is false; reset in reset_for_fight. Sim state only.
var defeat_frames_elapsed: int = 0

var _health: PlayerHealth
var _arena: ArenaContext
## Every distinct AttackDef of the boss and its script instance, parallel (built once in setup).
var _defs: Array[AttackDef] = []
var _attacks: Array[BossAttack] = []
## Per phase: the cache index of each pool entry.
var _pools: Array[PackedInt32Array] = []
var _current_index: int = -1
var _body_radius_px: float = 0.0
var _defeat_emitted: bool = false


func _init() -> void:
	phase = SimPhase.BOSS_HAZARDS


## Binds the def, the player's health and the arena context, builds the attack cache. A def that
## fails validate() logs an error and leaves the boss unusable (inactive). True on success.
func setup(p_def: BossDef, p_health: PlayerHealth, p_arena: ArenaContext) -> bool:
	_health = p_health
	_arena = p_arena
	def = null
	_defs.clear()
	_attacks.clear()
	_pools.clear()
	active = false
	if p_def == null:
		Log.error(&"boss", "BossController.setup: no BossDef")
		return false
	var problems: PackedStringArray = p_def.validate()
	if not problems.is_empty():
		Log.error(&"boss", "invalid BossDef %s: %s" % [p_def.boss_id, ", ".join(problems)])
		return false
	def = p_def
	_body_radius_px = HitShape.tiles_to_px(def.body_radius_tiles)
	for phase_def: PhaseDef in def.phases:
		var pool := PackedInt32Array()
		for attack_def: AttackDef in phase_def.attack_pool:
			var at: int = _defs.find(attack_def)
			if at < 0:
				at = _defs.size()
				_defs.append(attack_def)
				var attack: BossAttack = attack_def.attack_script.new()
				attack.bind_boss(self) # Story 3.4 (D-S34-11): weak back-reference, no cycle
				_attacks.append(attack)
			pool.append(at)
		_pools.append(pool)
	return true


## Fight start and retry (AC 8): full HP, phase 0, GAP for the first phase's gap, empty pick
## history, live. Cached attack scripts are reset, never rebuilt.
func reset_for_fight() -> void:
	last_hit_serial = -1
	weak_window.clear()
	if def == null:
		active = false
		return
	hp = def.max_hp
	phase_index = 0
	current = null
	_current_index = -1
	last_pick = -1
	second_last_pick = -1
	_defeat_emitted = false
	defeat_frames_elapsed = 0
	last_hit_serial = -1
	weak_window.clear()
	for attack: BossAttack in _attacks:
		attack.reset()
	if _arena != null:
		_arena.player_effects.clear()
	_enter(BossState.GAP, def.phases[0].gap_frames)
	active = true
	EventBus.boss_hp_changed.emit(hp, def.max_hp)


func set_active(on: bool) -> void:
	active = on and def != null and state != BossState.DEFEATED


func tick(ctx: SimContext) -> void:
	if state == BossState.DEFEATED and def != null:
		# Story 3.8 (A1): the reassembly counter runs on its own; the body and the FSM stay stopped.
		if defeat_frames_elapsed < DEFEAT_FRAMES:
			defeat_frames_elapsed += 1
		return
	if not active:
		return
	weak_window.tick() # D-S32-22: Patched counts live sim frames, ROAR included
	_tick_body(ctx) # Story 3.3 (D-S33-14): the boss body moves before the FSM step
	if state == BossState.ACTIVE and _current_index >= 0:
		_attacks[_current_index].on_active(_arena)
	frames_left -= 1
	if frames_left <= 0:
		_advance(ctx.rng)
	_check_contact()


## The state change when the counter runs out (D-S31-5).
func _advance(rng: RandomNumberGenerator) -> void:
	match state:
		BossState.GAP:
			# D-S33-9: no attacks yet; Story 3.4 (D-S34-23): or the body holds its attacks (the loop has
			# not started). Stay in GAP: no pick, no RNG.
			# Story 3.5 (B1): the candidate list (default: the phase pool) decides; empty keeps GAP.
			if _pick_candidates(phase_index).is_empty() or not _attacks_allowed():
				_enter(BossState.GAP, def.phases[phase_index].gap_frames)
				return
			_current_index = pick_next(rng)
			current = _defs[_current_index]
			_enter(BossState.TELL, current.tell)
			_on_attack_started()
			_attacks[_current_index].on_tell(_arena)
			EventBus.boss_tell_started.emit(current.id, current.tell_sfx)
		BossState.TELL:
			_enter(BossState.ACTIVE, current.active)
		BossState.ACTIVE:
			if current.recovery > 0:
				_enter(BossState.RECOVERY, current.recovery)
				_attacks[_current_index].on_recovery(_arena)
			else:
				_attacks[_current_index].on_recovery(_arena)
				_end_attack()
		BossState.RECOVERY:
			_end_attack()
		BossState.ROAR:
			_end_attack()
		BossState.DEFEATED:
			pass


## Drops a running attack (phase change or defeat): on_cancel lets it clear hazards; no on_recovery.
func _cancel_attack() -> void:
	if _current_index >= 0 and _arena != null:
		_attacks[_current_index].on_cancel(_arena)
	var had_attack: bool = _current_index >= 0
	current = null
	_current_index = -1
	if had_attack:
		_on_attack_cancelled() # Story 3.4 (D-S34-15): the body restores its own state


func _end_attack() -> void:
	current = null
	_current_index = -1
	_enter(BossState.GAP, def.phases[phase_index].gap_frames)


func _enter(next: BossState, frames: int) -> void:
	state = next
	frames_left = frames
	if next != BossState.GAP and Debug.enabled:
		Log.debug(&"boss", "state %s (%d)" % [BossState.keys()[next], frames])


## Draws the next attack's cache index from the current phase's pool (D-S31-6): uniform, and when
## the draw would make three in a row, redrawn from the pool minus that attack. Records the pick.
## Story 3.4 (D-S34-3): a one-attack pool has nothing to redraw from, so it repeats its attack.
## Story 3.5 (B1, D-S35-3): draws from _pick_candidates(phase_index) (default: the pool); the same
## one-candidate and no-triple rules apply to that list. -1 (no draw) when it is empty.
func pick_next(rng: RandomNumberGenerator) -> int:
	var pool: PackedInt32Array = _pick_candidates(phase_index)
	if pool.is_empty():
		return -1
	if pool.size() == 1: # nothing to choose: no RNG draw, by construction (review 3.4)
		second_last_pick = last_pick
		last_pick = pool[0]
		return last_pick
	var slot: int = rng.randi_range(0, pool.size() - 1)
	var pick: int = pool[slot]
	if pool.size() > 1 and pick == last_pick and pick == second_last_pick:
		var other: int = rng.randi_range(0, pool.size() - 2)
		if other >= slot:
			other += 1
		pick = pool[other]
	second_last_pick = last_pick
	last_pick = pick
	return pick


## Body contact (AC 6, D-S31-12): the player's centre inside the body circle queues one hit;
## PlayerHealth decides invulnerability. Live in every state but DEFEATED, ROAR included.
func _check_contact() -> void:
	if _health == null or _arena == null or state == BossState.DEFEATED:
		return
	if touches_player(_arena.body_contact_position()):
		_health.queue_hit()


## Lowers HP by `damage` (CombatResolver, debug keys), emits boss_hp_changed, then defeats the
## boss at 0 or enters the phase the HP now falls in. Story 3.2 (AC 8): ignored before
## reset_for_fight, while inactive and after defeat; HP unchanged, no signal.
func take_hit(damage: int) -> void:
	if not active or def == null or state == BossState.DEFEATED or damage <= 0:
		return
	hp = maxi(hp - damage, 0)
	EventBus.boss_hp_changed.emit(hp, def.max_hp)
	if hp == 0:
		_defeat()
		return
	var next: int = phase_for_hp(hp, def.max_hp, def.phases)
	if next > phase_index:
		_change_phase(next)


## Phase change (D-S31-8): the current attack is dropped (no on_recovery), ROAR for 60 ticks, the
## speed-ramp hook runs, then boss_roar_started and boss_phase_changed.
func _change_phase(next: int) -> void:
	phase_index = next
	last_pick = -1 # the no-three-in-a-row history is per phase (review 3.4)
	second_last_pick = -1
	_cancel_attack()
	_enter(BossState.ROAR, ROAR_FRAMES)
	_on_phase_reset()
	if Debug.enabled:
		var weak: Vector2i = current_weak_window()
		Log.debug(&"boss", "phase %d weak %s>%s" % [phase_index, Register.glyph_of(weak.x), Register.glyph_of(weak.y)])
	EventBus.boss_roar_started.emit(phase_index)
	EventBus.boss_phase_changed.emit(phase_index)


func _defeat() -> void:
	_cancel_attack()
	_enter(BossState.DEFEATED, 0)
	active = false
	weak_window.clear()
	_on_defeated()
	if not _defeat_emitted:
		_defeat_emitted = true
		defeat_frames_elapsed = 0
		SimClock.request_hitstop(DEFEAT_HITSTOP_FRAMES) # Story 3.8 (A2, AC 1)
		if Debug.enabled:
			Log.debug(&"boss", "defeated %s" % def.boss_id)
		EventBus.boss_defeated.emit(def.boss_id)


## Story 3.8 (A3): true once the defeat animation is over (DEFEATED and DEFEAT_FRAMES world ticks
## counted). A pure read for presentation, which then asks Game.finish_defeat.
func defeat_finished() -> bool:
	return def != null and state == BossState.DEFEATED and defeat_frames_elapsed >= DEFEAT_FRAMES


## True while a player hit can affect the boss (D-S32-9): live, in GAP, TELL, ACTIVE or RECOVERY.
## Not in ROAR, DEFEATED or while inactive.
func is_hittable() -> bool:
	if not active or def == null:
		return false
	return state == BossState.GAP or state == BossState.TELL or state == BossState.ACTIVE or state == BossState.RECOVERY


## The current phase's weak window (first, second) (D-019, AD-06); ZERO without a def.
func current_weak_window() -> Vector2i:
	if def == null or phase_index < 0 or phase_index >= def.phases.size():
		return Vector2i.ZERO
	return def.phases[phase_index].weak_window


## True when the action with `serial` already hit the boss (D-S32-10, like PracticeTarget).
func was_hit_by(serial: int) -> bool:
	return last_hit_serial == serial


func mark_hit(serial: int) -> void:
	last_hit_serial = serial


## Radius of the body hurtbox circle in px (D-S31-12); the boss's player-hit hurtbox too.
func body_radius_px() -> float:
	return _body_radius_px


## The id EventBus.hit_landed carries for a boss hit (D-S32-11).
func hit_target_id() -> StringName:
	return &"boss"


## Speed-ramp reset hook (FR30), called on every phase change. The framework does nothing.
func _on_phase_reset() -> void:
	pass


## Story 3.3 (D-S33-14) virtual hooks. The defaults are the 3.1/3.2 single body circle; a boss body
## (InfiniteLoopBody) overrides them. CombatResolver and body contact call only these.

## True when a player hit shape placed at `origin`, turned to `facing`, touches the boss's hurtbox.
func overlaps_shape(shape: HitShape, origin: Vector2, facing: Vector2) -> bool:
	return shape != null and shape.overlaps(origin, facing, body_center_px, _body_radius_px)


## Where a boss hit lands (EventBus.hit_landed position, particles, number).
func hit_position() -> Vector2:
	return body_center_px


## True when the player's centre `p` is inside the boss's contact area (D-S31-25: no player radius).
func touches_player(p: Vector2) -> bool:
	return body_center_px.distance_to(p) <= _body_radius_px


## Per-live-tick body motion, after the Patched tick and before the FSM step. Default: nothing.
func _tick_body(_ctx: SimContext) -> void:
	pass


## Story 3.4 virtual hooks (D-S34-15, D-S34-22, D-S34-23). Defaults do nothing / allow attacks.

## Story 3.5 (B1, D-S35-3): the cache indices pick_next may draw from in `phase`. Default: the
## phase's pool. A body narrows it (Nested Loop once per fight). Never allocates in the default.
func _pick_candidates(phase: int) -> PackedInt32Array:
	return _pools[phase]


## Story 3.5 (P9): the boss was defeated (after the running attack was cut). Default: nothing.
func _on_defeated() -> void:
	pass


## False holds the FSM in GAP at the end of each gap (no pick, no RNG). Default: true.
func _attacks_allowed() -> bool:
	return true


## Right after TELL entry, before the attack's on_tell.
func _on_attack_started() -> void:
	pass


## After a running attack was cut (phase change or defeat) and its on_cancel ran.
func _on_attack_cancelled() -> void:
	pass


## Debug F6 (AC 7): HP to 0 through take_hit.
func debug_kill() -> void:
	take_hit(hp)


## Debug Shift+F6 (AC 7): HP down to the next phase's threshold. False when already in the last
## phase (or defeated).
func debug_skip_phase() -> bool:
	if def == null or state == BossState.DEFEATED or phase_index + 1 >= def.phases.size():
		return false
	var target: int = maxi(1, hp_at_threshold(def.phases[phase_index + 1].hp_threshold, def.max_hp))
	var before: int = phase_index
	take_hit(hp - target)
	return phase_index != before


func jitter_level() -> int:
	return jitter_for_hp(hp, def.max_hp) if def != null else 0


## The running attack's script instance (TELL, ACTIVE, RECOVERY), or null (Story 3.4, D-S34-11).
func current_attack() -> BossAttack:
	return _attacks[_current_index] if _current_index >= 0 else null


## True when the boss's own contact area should include the live attack's hazard: the attack's
## hazard_hit while ACTIVE (Story 3.4, D-S34-9). Bodies call it from touches_player.
func attack_hazard_hit(p: Vector2) -> bool:
	var attack: BossAttack = current_attack()
	return attack != null and state == BossState.ACTIVE and attack.hazard_hit(p)


## The script instance cached for `attack_def`, or null (tests, BossView).
func attack_for(attack_def: AttackDef) -> BossAttack:
	var at: int = _defs.find(attack_def)
	return _attacks[at] if at >= 0 else null


## The arena context the attacks get.
func arena() -> ArenaContext:
	return _arena


## The 0-based phase `hp` falls in (D-S31-4): the latest phase whose start
## (hp * 100 <= hp_threshold * max_hp) is reached. Integer math, no float drift. Pure.
static func phase_for_hp(p_hp: int, max_hp: int, phases: Array[PhaseDef]) -> int:
	var out: int = 0
	for i: int in phases.size():
		if p_hp * 100 <= phases[i].hp_threshold * max_hp:
			out = i
	return out


## The largest HP inside the phase that starts at `threshold` percent. Pure.
static func hp_at_threshold(threshold: int, max_hp: int) -> int:
	@warning_ignore("integer_division")
	return threshold * max_hp / 100


## Glyph jitter level for the HP (D-S31-9): 0 above 66%, 1 at or below 66%, 2 at or below 33%. Pure.
static func jitter_for_hp(p_hp: int, max_hp: int) -> int:
	if p_hp * 100 <= JITTER_STEP_2_PERCENT * max_hp:
		return 2
	if p_hp * 100 <= JITTER_STEP_1_PERCENT * max_hp:
		return 1
	return 0

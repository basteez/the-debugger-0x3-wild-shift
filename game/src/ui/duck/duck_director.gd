class_name DuckDirector
extends Node
## The duck's director: tutorial beats T1 to T4 of the Infinite Loop (Story 3.6, FR45, D-040) and
## the hint template (Story 4.4, FR46). Each presentation frame poll() reads the flow state, the
## arena's boss and register and requests at most one line through VoiceService.say.
## Beats (D-S44-3): each fires on its own trigger once per run; an unfired earlier beat never blocks
## a later one, and is skipped for good once a later beat fired (D-S44-10). `requested` (a bitmask)
## resets only when the flow returns to TITLE (a retry keeps it, D-S36-8).
## Hints (D-S44-5, D-S44-6): EventBus.breakpoint_started queues the current weak window once per
## (boss, phase) per fight attempt (never while the boss is DEFEATED); every third death on a boss
## captures the window at the death and queues it when the retry starts (DEAD to FIGHT).
## Queue (D-S44-4): nothing is requested while `bubble` has no room; a due line stays due.
## Pause (D-S44-9): nothing is requested while SimClock.paused.
## Reads only: it never writes the arena, boss, register or player (AD-05). Main attaches it (the
## JuiceDirector pattern) and hands it the arena and the HUD's bubble.

const INFINITE_LOOP_ID := &"infinite_loop"
const DUCK_IDS: Array[StringName] = [&"t1_shift", &"t2_semicolon", &"t3_dash_strike", &"t4_phase_two"]
## poll() return value when a hint was requested (beats return their index).
const HINT_REQUESTED := 100
## D-S44-6: the death hint fires on every multiple of this many deaths on the same boss.
const DEATHS_PER_HINT := 3

var arena: Arena = null
## The HUD's bubble (D-S44-4); null (tests, no HUD) means always room.
var bubble: DuckBubble = null
## Beats requested this run, one bit per DUCK_IDS index.
var requested: int = 0
## Hint windows waiting for the bubble, oldest first (D-S44-4).
var pending_hints: Array[Vector2i] = []
## (boss id, phase index) keys hinted by Breakpoint in this fight attempt (D-S44-5).
var hinted: Dictionary[String, bool] = {}
## D-S44-6: the window captured at a third death, said when the retry starts (valid while
## has_death_hint).
var death_hint: Vector2i = Vector2i.ZERO
var has_death_hint: bool = false
## The boss the death hint was captured on (review: never said in another boss's fight).
var death_hint_boss: StringName = &""


func _enter_tree() -> void:
	if not EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.connect(_on_flow_state_changed)
	if not EventBus.breakpoint_started.is_connected(_on_breakpoint_started):
		EventBus.breakpoint_started.connect(_on_breakpoint_started)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)


func _exit_tree() -> void:
	if EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.disconnect(_on_flow_state_changed)
	if EventBus.breakpoint_started.is_connected(_on_breakpoint_started):
		EventBus.breakpoint_started.disconnect(_on_breakpoint_started)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


func _process(_delta: float) -> void:
	poll()


## Reads the fight once and requests one due line: the oldest pending hint, else the lowest due
## beat. Returns the beat index, HINT_REQUESTED, or -1 (nothing due, paused, no room, not in FIGHT).
func poll() -> int:
	if arena == null or SimClock.paused:
		return -1
	if Game.flow_state != Game.FlowState.FIGHT:
		return -1
	if bubble != null and not bubble.has_room():
		return -1
	if not pending_hints.is_empty():
		var w: Vector2i = pending_hints.pop_front()
		var line_id: StringName = DuckHint.line_id_for(w)
		Log.debug(&"duck", "hint %s" % line_id)
		VoiceService.say(String(line_id) if VoiceService.LINES.find(line_id) != null else DuckHint.window_text(w))
		return HINT_REQUESTED
	var boss: BossController = arena.boss
	var boss_id: StringName = boss.def.boss_id if boss != null and boss.def != null else &""
	var loop := boss as InfiniteLoopBody
	var iteration: int = loop.iteration if loop != null else 0
	var phase_index: int = boss.phase_index if boss != null else 0
	var dash_strike: bool = window_is_dash_strike(arena.register.active_window()) if arena.register != null else false
	var beat: int = due_beat(requested, true, boss_id, iteration, dash_strike, phase_index)
	if beat < 0:
		return -1
	requested |= 1 << beat
	Log.debug(&"duck", "beat %s" % DUCK_IDS[beat])
	VoiceService.say(String(DUCK_IDS[beat]))
	return beat


func _on_flow_state_changed(from: int, to: int) -> void:
	if to == Game.FlowState.TITLE:
		requested = 0
	if to != Game.FlowState.FIGHT:
		pending_hints.clear() # the bubble clears on leaving FIGHT too
	if to == Game.FlowState.FIGHT:
		hinted.clear() # D-S44-5: a new attempt may hint every phase again
		if from == Game.FlowState.DEAD and has_death_hint and _current_boss_id() == death_hint_boss:
			pending_hints.append(death_hint) # D-S44-6: said at the start of the retry
		has_death_hint = false
	elif to != Game.FlowState.DEAD:
		has_death_hint = false # AC 7: left the fight without a retry


## D-S44-5 (AC 3, 4): the current window, once per (boss, phase) per attempt; never while DEFEATED.
func _on_breakpoint_started() -> void:
	if arena == null or Game.flow_state != Game.FlowState.FIGHT:
		return
	var boss: BossController = arena.boss
	if boss == null or boss.def == null or boss.state == BossController.BossState.DEFEATED:
		return
	var key: String = hint_key(boss.def.boss_id, boss.phase_index)
	if hinted.has(key):
		return
	var w: Vector2i = boss.current_weak_window()
	if w == Vector2i.ZERO:
		return # no real window (malformed def): never say "?->?"
	hinted[key] = true
	pending_hints.append(w)


## D-S44-6 (AC 5): every third death captures the window now (the boss is still in its death phase).
func _on_player_died(_boss: StringName, deaths_on_boss: int) -> void:
	if not is_death_hint_due(deaths_on_boss) or arena == null:
		return
	var boss: BossController = arena.boss
	if boss == null or boss.def == null:
		return
	var w: Vector2i = boss.current_weak_window()
	if w == Vector2i.ZERO:
		return
	death_hint = w
	death_hint_boss = boss.def.boss_id
	has_death_hint = true


func _current_boss_id() -> StringName:
	var boss: BossController = arena.boss if arena != null else null
	return boss.def.boss_id if boss != null and boss.def != null else &""


## True on every DEATHS_PER_HINT-th death on a boss (3, 6, 9...). Pure.
static func is_death_hint_due(deaths_on_boss: int) -> bool:
	return deaths_on_boss > 0 and deaths_on_boss % DEATHS_PER_HINT == 0


## The per-attempt record key of a boss phase. Pure.
static func hint_key(boss_id: StringName, phase_index: int) -> String:
	return "%s:%d" % [boss_id, phase_index]


## True when the active window `w` (first, second) fires Dash Strike. Pure (reads the combo table).
static func window_is_dash_strike(w: Vector2i) -> bool:
	var combo: ComboDef = Defs.COMBOS.get_combo(w.x, w.y)
	return combo != null and combo.action == Defs.DASH_STRIKE


## True when beat `index`'s trigger holds (D-S36-7 triggers): T1 at once; T2 when `iteration` >= 1
## (the first `;` opened); T3 when the window is Dash Strike; T4 at `phase_index` >= 1. Pure.
static func beat_trigger(index: int, iteration: int, p_window_is_dash_strike: bool, phase_index: int) -> bool:
	match index:
		0:
			return true
		1:
			return iteration >= 1
		2:
			return p_window_is_dash_strike
		3:
			return phase_index >= 1
	return false


## The lowest beat that is due, or -1 (D-S44-3, D-S44-10). `p_requested` is the bitmask of beats
## already requested. Every beat needs a FIGHT of the Infinite Loop (the test boss, practice and
## bosses 1-2 have another id or none). A beat is due when its bit is clear, no later beat was
## requested (an earlier beat that missed its moment is skipped for good) and its trigger holds.
## Pure.
static func due_beat(p_requested: int, in_fight: bool, boss_id: StringName, iteration: int, p_window_is_dash_strike: bool, phase_index: int) -> int:
	if p_requested < 0 or not in_fight or boss_id != INFINITE_LOOP_ID:
		return -1
	for i: int in DUCK_IDS.size():
		if p_requested & (1 << i) != 0:
			continue
		if p_requested >> (i + 1) != 0:
			continue # a later beat already fired: this one is skipped for good
		if beat_trigger(i, iteration, p_window_is_dash_strike, phase_index):
			return i
	return -1

class_name DuckDirector
extends Node
## Tutorial beats T1 to T4 of the Infinite Loop (Story 3.6, FR45, D-040, D-S36-7). Each
## presentation frame it reads the flow state, the arena's boss and register, asks the pure
## due_beat() for the next beat and requests it through VoiceService.say. Beats fire strictly in
## order, at most once per run; `requested` resets only when the flow returns to TITLE (a retry
## keeps it, D-S36-8). Reads only: it never writes the arena, boss, register or player (AD-05).
## Main attaches it (the JuiceDirector pattern) and hands it the arena.

const INFINITE_LOOP_ID := &"infinite_loop"
const DUCK_IDS: Array[StringName] = [&"t1_shift", &"t2_semicolon", &"t3_dash_strike", &"t4_phase_two"]

var arena: Arena = null
## Beats requested this run (the index of the next beat); DUCK_IDS.size() when all are done.
var requested: int = 0


func _enter_tree() -> void:
	if not EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.connect(_on_flow_state_changed)


func _exit_tree() -> void:
	if EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.disconnect(_on_flow_state_changed)


func _process(_delta: float) -> void:
	poll()


## Reads the fight once and requests the next beat when it is due. Returns the beat index
## requested, or -1.
func poll() -> int:
	if arena == null:
		return -1
	var in_fight: bool = Game.flow_state == Game.FlowState.FIGHT
	var boss: BossController = arena.boss
	var boss_id: StringName = boss.def.boss_id if boss != null and boss.def != null else &""
	var loop := boss as InfiniteLoopBody
	var iteration: int = loop.iteration if loop != null else 0
	var phase_index: int = boss.phase_index if boss != null else 0
	var dash_strike: bool = window_is_dash_strike(arena.register.active_window()) if arena.register != null else false
	var beat: int = due_beat(requested, in_fight, boss_id, iteration, dash_strike, phase_index)
	if beat < 0:
		return -1
	requested = beat + 1
	VoiceService.say(String(DUCK_IDS[beat]))
	return beat


func _on_flow_state_changed(_from: int, to: int) -> void:
	if to == Game.FlowState.TITLE:
		requested = 0


## True when the active window `w` (first, second) fires Dash Strike. Pure (reads the combo table).
static func window_is_dash_strike(w: Vector2i) -> bool:
	var combo: ComboDef = Defs.COMBOS.get_combo(w.x, w.y)
	return combo != null and combo.action == Defs.DASH_STRIKE


## The index of the next beat (`requested`) when its trigger holds, else -1 (D-S36-7). Every beat
## needs a FIGHT of the Infinite Loop (the test boss, practice and bosses 1-2 have another id or
## none). T1 at once; T2 when `iteration` >= 1 (the first `;` opened); T3 when the window is Dash
## Strike; T4 at `phase_index` >= 1. Strict order: only the beat at `requested` is checked. Pure.
static func due_beat(p_requested: int, in_fight: bool, boss_id: StringName, iteration: int, p_window_is_dash_strike: bool, phase_index: int) -> int:
	if p_requested < 0 or p_requested >= DUCK_IDS.size():
		return -1
	if not in_fight or boss_id != INFINITE_LOOP_ID:
		return -1
	var due: bool = false
	match p_requested:
		0:
			due = true
		1:
			due = iteration >= 1
		2:
			due = p_window_is_dash_strike
		3:
			due = phase_index >= 1
	return p_requested if due else -1

class_name Arena
extends Node2D
## The Clearing (Story 1.5, FR56): a fixed 32x18 glyph layout drawn at 2x on 16-px tiles,
## plus the bounds clamp (scenery has no collision; walls are a position clamp).
## Placed by Main at HUD cell ORIGIN_CELL, i.e. pixel ORIGIN_CELL * 8 on the 640x360 base.

const TILES := Const.ARENA_TILES
const TILE_PX := Const.TILE_PX
## Top-left HUD cell of the arena: cells (16,2)-(79,37) at 8 px (D-047).
const ORIGIN_CELL := Vector2i(16, 2)
const GLYPH_SCALE := 2
const TREE := "♣"
const GRASS := "\""
const ROCK := "o"
const WATER := "~"
const LABEL := "stack frame 0x03"
const LABEL_COL := 2
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
## Player spawn (D-S22-6): centre of the play area, arena-local pixels.
const SPAWN_PX := Vector2(TILES * TILE_PX) / 2.0
## Practice target centre (Story 2.7, D-S27-2): 4 tiles right of spawn.
const PRACTICE_TARGET_PX := SPAWN_PX + Vector2(4 * TILE_PX, 0)
## The framework test boss (Story 3.1, D-S31-3, D-S31-17): debug Shift+F3 only. Loaded lazily so
## a fight without it never touches the data. Body centre 5 tiles above spawn.
const TEST_BOSS_DEF_PATH := "res://data/bosses/test_boss/boss_def.tres"
const TEST_BOSS_PX := SPAWN_PX + Vector2(0, -5 * TILE_PX)
## Boss 1 (Story 3.3, D-S33-11, D-S33-13): the Infinite Loop, the boss of FIGHT boss 0. Its def
## path picks the InfiniteLoopBody class; any other path gets a plain BossController.
const INFINITE_LOOP_DEF_PATH := "res://data/bosses/infinite_loop/boss_def.tres"
## Story 5.1 (AC 3): Boss 2, the Null Pointer, the boss of FIGHT boss 1 (NullPointerBody).
const NULL_POINTER_DEF_PATH := "res://data/bosses/null_pointer/boss_def.tres"
## Story 6.3 (AC 1, AD-12, D-S63-4): Boss 3, the Segfault, the boss of FIGHT boss 2. A cut-ladder
## leaf (FeatureFlags.segfault): its body class is loaded by path, never named here.
const SEGFAULT_DEF_PATH := "res://data/bosses/segfault/boss_def.tres"
const SEGFAULT_BODY_PATH := "res://src/bosses/segfault/segfault_body.gd"
## Story 6.6 (AC 3, cut #1): the AttackDef id of Reserved Write, dropped from the pools when its flag
## is off (by id, never by class).
const RESERVED_WRITE_ID := &"reserved_write"
## Story 4.3 (AD-12, D-S43-2): the Breakpoint leaf module, loaded by path only when its flag is on,
## so the arena never names its class (held as a FightSkill).
const BREAKPOINT_SKILL_PATH := "res://src/skills/breakpoint/breakpoint_skill.gd"
## Story 5.4 (AD-12, D-S54-3): the Watch leaf module, loaded by path only when its flag is on.
const WATCH_SKILL_PATH := "res://src/skills/watch/watch_skill.gd"
## Inset of the player's glyph centre from the play-area edge: half a tile, so the whole `@` cell
## stays inside the 32x18 play area (D-S22-2). One more tile inward makes the tree ring a wall.
const PLAYER_EDGE_INSET_PX := TILE_PX / 2.0
## 18 rows x 32 glyphs (DC5): tree ring, grass, a connected stream, rocks, the label on row 0.
const LAYOUT: PackedStringArray = [
	'♣♣stack frame 0x03♣♣♣♣♣♣♣♣♣♣♣♣♣♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "    "   ♣',
	'♣  o    "    "    "   o"    "  ♣',
	'♣   "    o    "    "    "    " ♣',
	'♣    "    " o  "    "    o    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "   ~~~~~♣',
	'♣~~~~~~ "    "    "   ~~~~~ "  ♣',
	'♣   " ~~~~~~~ "  ~~~~~~ "    " ♣',
	'♣    "    " ~~~~~~  "    "    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "    "   ♣',
	'♣  "    "    " o  "    "   o"  ♣',
	'♣   "o   "    "    "    "    " ♣',
	'♣    "    "    "   o"    "    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣',
]

## The player movement system (Story 2.2). Owned here; ticked by SimClock while in the tree.
var player: Player = Player.new(PLAYER_DEF, player_bounds())
## The bit register (Story 2.3, D-S23-4). Owned here, reads SimClock's shared buffer; ticked by
## SimClock in the SHIFTS phase while in the tree. Drawn by the HUD's RegisterPanel (Main injects).
var register: Register = Register.new(SimClock.buffer)
## The player's action state machine (Story 2.5). Declared after player and register, so both
## exist when it is built (members initialise in declaration order). Ticked in the ACTIONS phase.
var actions: ActionStateMachine = ActionStateMachine.new(SimClock.buffer, player, register)
## Hit resolution (Story 2.7, AD-04): shape math in the COMBAT phase, after ACTIONS and PLAYER.
var combat: CombatResolver = CombatResolver.new(actions, player)
## Player HP and post-hit invulnerability (Story 2.9): COMBAT phase, registered after `combat`.
var health: PlayerHealth = PlayerHealth.new(PLAYER_DEF, actions)
## Story 6.1 (D-S61-3): the Ghost Echo decoy's owner (BOSS_HAZARDS, registered before any boss).
## Its decoy is handed to CombatResolver (DECOY_STRUCK) and read by the aim source below.
var ghost_echo: GhostEchoSystem = _make_ghost_echo()
## The `/* test */` dummy (Story 2.7): null unless a fight was entered with_practice (debug only).
var practice_target: PracticeTarget = null
## What bosses read from the arena (Story 3.1, D-S31-10): aim at the live Ghost Echo decoy, else at
## the player (Story 6.1, D-S61-7), the player's own position for body contact, and the
## PlayerEffects queue (NP-3), ticked in PLAYER_EFFECTS while the arena is in the tree.
var arena_context: ArenaContext = _make_arena_context()
## The boss of the fight (Story 3.1; Story 3.3 loader, D-S33-13): null unless the fight was
## entered with a boss def path. Registered with SimClock (BOSS_HAZARDS) only while it exists and
## the arena is in the tree.
var boss: BossController = null
## The def path `boss` was built from ("" = none), so a retry reuses the controller.
var boss_def_path: String = ""
## Story 4.3 (D-S43-1, D-S43-11): FeatureFlags.breakpoint, read once here at construction (Main or a
## test may override it with set_breakpoint_enabled before the first fight). Bosses get it injected.
var breakpoint_enabled: bool = Defs.FEATURE_FLAGS.breakpoint_enabled
## The Breakpoint module (cut #3), null when the flag is off. TIMERS phase; registered with SimClock
## while the arena is in the tree.
var breakpoint_skill: FightSkill = make_breakpoint_skill(breakpoint_enabled)
## Story 5.4 (D-S54-3, D-S54-9): FeatureFlags.watch, read once here at construction (Main or a test
## may override it with set_watch_enabled before the first fight). Off: the Null Pointer gets the
## flicker fallback injected (watch_fallback), never the flag itself.
var watch_enabled: bool = Defs.FEATURE_FLAGS.watch
## The Watch module (cut #2), null when the flag is off. TIMERS phase; registered with SimClock while
## the arena is in the tree.
var watch_skill: FightSkill = make_watch_skill(watch_enabled)
## Story 6.6 (AC 3, AD-12, cut #1): FeatureFlags.reserved_write, read once here at construction
## (Main or a test may override it with set_reserved_write_enabled before the fight). Off: the boss
## gets the attack id injected as excluded, so the Reserved Write script is never built.
var reserved_write_enabled: bool = Defs.FEATURE_FLAGS.reserved_write


func _enter_tree() -> void:
	SimClock.register_system(register)
	SimClock.register_system(actions)
	SimClock.register_system(player)
	SimClock.register_system(combat)
	SimClock.register_system(health)
	SimClock.register_system(arena_context.player_effects)
	SimClock.register_system(ghost_echo) # before the boss: same phase, registration order
	if boss != null:
		SimClock.register_system(boss)
	if breakpoint_skill != null:
		SimClock.register_system(breakpoint_skill)
	if watch_skill != null:
		SimClock.register_system(watch_skill)


## Detach from the autoload clock so re-instancing Main (tests) never double-ticks (D-S22-10).
func _exit_tree() -> void:
	SimClock.unregister_system(register)
	SimClock.unregister_system(actions)
	SimClock.unregister_system(player)
	SimClock.unregister_system(combat)
	SimClock.unregister_system(health)
	SimClock.unregister_system(arena_context.player_effects)
	SimClock.unregister_system(ghost_echo)
	ghost_echo.clear() # a decoy never outlives the arena's presence in the tree (review 6.1)
	if boss != null:
		SimClock.unregister_system(boss)
	if breakpoint_skill != null:
		breakpoint_skill.end_fight() # never leave the autoload clock frozen (AC 12)
		SimClock.unregister_system(breakpoint_skill)
	if watch_skill != null:
		watch_skill.end_fight() # never leave the autoload clock's Watch gate on
		SimClock.unregister_system(watch_skill)


## Every route into FIGHT (D-S22-5, Story 2.3 AC9): reset the player to spawn and the register to
## `fight_start`, then start ticking both. `with_practice` (Story 2.7, debug Shift+F2 only) places
## the practice target, reset; without it the fight has no target. Story 2.9: the caller passes the
## RunState snapshot ring (a retry restores it), and the player is back to full HP. Story 4.1: the
## Echo memory clear lives in ActionStateMachine.reset_for_fight (called below). Story 3.1/3.3: `p_boss_def_path` places
## that boss (Main.boss_def_path_for: the Infinite Loop for boss 0, the test boss on Shift+F3),
## reset to full HP, phase 1, GAP (AC 8); an empty path means the fight has no boss.
## Story 4.3 (AC 3, AC 12, D-S43-6): `breakpoint_unlocked` (Fight 2 or later, computed by Main from
## RunState) resets the Breakpoint module: gate off, cooldown 0, not active.
## Story 5.4 (D-S54-4, D-S54-11): `watch_unlocked` (Boss 2 or later, computed by Main) resets the
## Watch module: released, gate off.
func enter_fight(fight_start: PackedInt32Array, with_practice: bool = false, p_boss_def_path: String = "", breakpoint_unlocked: bool = false, watch_unlocked: bool = false) -> void:
	player.reset_for_fight(SPAWN_PX)
	player.set_active(true)
	arena_context.player_effects.clear() # before the ring is replaced, so a live `?` is removed cleanly
	if not register.set_fight_start(fight_start):
		register.set_fight_start(Register.fight_start_for_boss(0))
	SimClock.buffer.clear() # stale Q/E presses never carry into a fight (D-S23-11 belt and braces)
	register.set_active(true)
	actions.reset_for_fight()
	actions.set_active(true)
	health.reset_for_fight()
	health.set_active(true)
	_set_practice(with_practice)
	arena_context.player_effects.clear()
	ghost_echo.clear() # Story 6.1 (D-S61-6): fight start and retry
	_set_boss(p_boss_def_path)
	if breakpoint_skill != null:
		breakpoint_skill.reset_for_fight(breakpoint_unlocked)
	if watch_skill != null:
		watch_skill.reset_for_fight(watch_unlocked)
	_redraw_player_view()


## Places (reset) or removes the practice target and hands the resolver its target list.
func _set_practice(on: bool) -> void:
	if on:
		if practice_target == null:
			practice_target = PracticeTarget.new()
		practice_target.position_px = PRACTICE_TARGET_PX
		practice_target.reset()
		combat.targets = [practice_target]
	else:
		practice_target = null
		combat.targets = []


func leave_fight() -> void:
	arena_context.player_effects.clear() # a live `?` never outlives the fight
	player.set_active(false)
	register.set_active(false)
	actions.set_active(false)
	health.set_active(false)
	_set_practice(false) # a stale target never outlives its fight (review 2.7)
	ghost_echo.clear() # Story 6.1 (D-S61-6): death, harvest (defeat) and any other exit
	combat.boss = null # D-S32-23
	if boss != null:
		boss.set_active(false)
	if breakpoint_skill != null:
		breakpoint_skill.end_fight() # clears the gate, emits breakpoint_ended if running (AC 12)
	if watch_skill != null:
		watch_skill.end_fight() # Story 5.4 (D-S54-11): released, gate off, watch_ended if held


## Places (reset) or removes the fight's boss (D-S33-13). The controller and its attack scripts
## are built once per def path and kept across retries (no allocation per fight, D-S31-18); a
## different path replaces it. An empty path, or a def that fails to load or validate, leaves the
## fight without a boss.
func _set_boss(path: String) -> void:
	if path == "":
		_remove_boss()
		return
	if boss == null or boss_def_path != path:
		_remove_boss()
		var def := load(path) as BossDef
		var controller: BossController = boss_class_for(path).new()
		controller.excluded_attack_ids = excluded_attack_ids(reserved_write_enabled)
		if not controller.setup(def, health, arena_context):
			return
		boss = controller
		boss_def_path = path
		boss.body_center_px = TEST_BOSS_PX # the Infinite Loop, the Null Pointer and the Segfault place themselves in reset (D-S33-18)
		if is_inside_tree():
			SimClock.register_system(boss)
	boss.breakpoint_on = breakpoint_enabled # D-S43-11: the SIGSEGV fallback reads the flag
	_inject_watch_fallback()
	boss.reset_for_fight() # also clears Patched (D-S32-23)
	combat.boss = boss


## Builds the Breakpoint module when `enabled` (AD-12): loaded by path, bound to the SimClock
## autoload's gate. Null when off, so nothing under src/skills/breakpoint/ is instantiated.
static func make_breakpoint_skill(enabled: bool) -> FightSkill:
	if not enabled:
		return null
	var script := load(BREAKPOINT_SKILL_PATH) as GDScript
	return script.new(SimClock) as FightSkill if script != null else null


## Turns the Breakpoint module on or off (Main's startup wiring, flag-off tests). Off ends a running
## Breakpoint and drops the module; on builds it. Bosses pick the flag up on the next fight entry.
func set_breakpoint_enabled(on: bool) -> void:
	breakpoint_enabled = on
	if on and breakpoint_skill == null:
		breakpoint_skill = make_breakpoint_skill(true)
		if is_inside_tree() and breakpoint_skill != null:
			SimClock.register_system(breakpoint_skill)
	elif not on and breakpoint_skill != null:
		breakpoint_skill.end_fight()
		SimClock.unregister_system(breakpoint_skill)
		breakpoint_skill = null
	if boss != null:
		boss.breakpoint_on = on


## Story 6.6 (AC 3, AD-12): the attack ids the cut ladder removes from boss pools. Pure.
static func excluded_attack_ids(p_reserved_write: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if not p_reserved_write:
		out.append(RESERVED_WRITE_ID)
	return out


## Turns Reserved Write on or off (Main's startup wiring, flag-off tests). The boss is rebuilt on
## the next fight entry, so the attack script exists only when the flag is on.
func set_reserved_write_enabled(on: bool) -> void:
	if on == reserved_write_enabled:
		return
	reserved_write_enabled = on
	if boss != null:
		boss_def_path = "" # forces _set_boss to rebuild the controller and its attack cache


## Builds the Watch module when `enabled` (Story 5.4, AD-12): loaded by path, bound to the SimClock
## autoload's gate. Null when off, so nothing under src/skills/watch/ is instantiated.
static func make_watch_skill(enabled: bool) -> FightSkill:
	if not enabled:
		return null
	var script := load(WATCH_SKILL_PATH) as GDScript
	return script.new(SimClock) as FightSkill if script != null else null


## Turns the Watch module on or off (Main's startup wiring, flag-off tests). Off releases a held
## Watch and drops the module; on builds it. The boss's flicker fallback follows at once.
func set_watch_enabled(on: bool) -> void:
	watch_enabled = on
	if on and watch_skill == null:
		watch_skill = make_watch_skill(true)
		if is_inside_tree() and watch_skill != null:
			SimClock.register_system(watch_skill)
	elif not on and watch_skill != null:
		watch_skill.end_fight()
		SimClock.unregister_system(watch_skill)
		watch_skill = null
	_inject_watch_fallback()


## Story 5.4 (AC 13, D-S54-9): the Null Pointer's ghost flicker runs only when Watch is cut. The
## boss reads the injected bool, never the flag. Bosses without the property ignore it.
func _inject_watch_fallback() -> void:
	if boss != null and &"watch_fallback" in boss:
		boss.set(&"watch_fallback", not watch_enabled)


## The controller class for a boss def path (D-S33-13). Pure.
static func boss_class_for(path: String) -> GDScript:
	if path == INFINITE_LOOP_DEF_PATH:
		return InfiniteLoopBody
	if path == NULL_POINTER_DEF_PATH:
		return NullPointerBody
	if path == SEGFAULT_DEF_PATH: # Story 6.3 (AD-12): by path, the leaf's class is never named
		var script := load(SEGFAULT_BODY_PATH) as GDScript
		if script == null:
			Log.warn("arena", "Segfault body script missing, falling back to a plain controller")
			return BossController
		return script
	return BossController


func _remove_boss() -> void:
	combat.boss = null
	boss_def_path = ""
	if boss == null:
		return
	boss.set_active(false)
	SimClock.unregister_system(boss)
	boss = null


## Builds the Ghost Echo owner and hands its decoy to the resolver (Story 6.1, D-S61-3).
func _make_ghost_echo() -> GhostEchoSystem:
	var system := GhostEchoSystem.new(actions)
	combat.ghost = system.decoy
	return system


## The default arena context: aim at the live Ghost Echo decoy, else the player (Story 6.1,
## D-S61-7); contact and facing always follow the player; the boss reads the register's shift count
## (Story 3.3).
func _make_arena_context() -> ArenaContext:
	var ctx := ArenaContext.new()
	ctx.target_source = func() -> Vector2: return aim_point()
	ctx.contact_source = func() -> Vector2: return player.position_px
	ctx.shift_count = func() -> int: return register.shift_serial # read-only (D-S33-6, NP-3)
	ctx.facing_source = func() -> Vector2i: return player.facing # Story 5.2 (D-S52-2), read-only
	# Story 6.5 (NP-3, D-S65-3): boss effects (SIGSEGV's rotation) act on the fight's register and link.
	ctx.player_effects.bind(register, actions.link)
	return ctx


## The bosses' aim point (Story 6.1, D-S61-7): the live Ghost Echo decoy, else the player.
func aim_point() -> Vector2:
	var decoy: GhostDecoy = ghost_echo.decoy if ghost_echo != null else null
	if decoy != null and decoy.is_live():
		return decoy.position_px
	return player.position_px


## Drops the previous fight's cached frame so the view never shows the old position for a frame.
func _redraw_player_view() -> void:
	var view: Node = get_node_or_null(^"PlayerView")
	if view != null:
		view.queue_redraw()


func _ready() -> void:
	position = Vector2(ORIGIN_CELL * GlyphFont.CELL)
	queue_redraw()


func _draw() -> void:
	for row: int in LAYOUT.size():
		var line: String = LAYOUT[row]
		for col: int in line.length():
			var ch: String = line[col]
			if ch != " ":
				GlyphFont.draw_cell(self, Vector2i(col, row), ch, Palette.INK, GLYPH_SCALE)


## Play area in arena-local pixels: 512x288, max edge inclusive (DC4).
static func play_area() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(TILES * TILE_PX))


## Nearest point inside the play area (DC4). Pure: no node, no scene tree.
static func clamp_to_play_area(p: Vector2) -> Vector2:
	var area: Rect2 = play_area()
	return p.clamp(area.position, area.end)


## Rect the player's glyph centre may occupy (Story 2.2 C3): the play area shrunk by half a tile,
## i.e. centre in [8, 504] x [8, 280]. Handed to Player at construction.
static func player_bounds() -> Rect2:
	return play_area().grow(-PLAYER_EDGE_INSET_PX)

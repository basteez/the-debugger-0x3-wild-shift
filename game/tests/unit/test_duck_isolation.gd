extends GutTest
## Story 3.6 AC 10-11 (H7, NP-3, AD-05): no sim folder names the duck layer, and the duck layer
## never ticks the sim, draws RNG, or writes the register, the player, the boss or the arena.
## Textual scan, comments stripped (the 3.4 attack-isolation pattern).

const IsolationScript := preload("res://tests/unit/test_attack_isolation.gd")
const SIM_DIRS: Array[String] = ["input", "register", "player", "combat", "bosses", "skills", "arena"]
const DUCK_DIR := "res://src/ui/duck"
## Duck names that sim code must never mention.
const SIM_FORBIDDEN: Array[String] = [
	"\\bDuckBubble\\b",
	"\\bDuckDirector\\b",
	"\\bDuckLines(Def)?\\b",
	"\\bDuckLineDef\\b",
	"\\bduck_line",
	"\\bVoiceService\\b",
	"\\bAudioManager\\b",
	"\\bplay_squeak\\b",
	"\\bTypewriterReveal\\b",
]
## Sim writes the duck layer must never make: ticking, SimContext, RNG, any register / player /
## health / boss / arena method call but the reads it needs, and any assignment through them.
const DUCK_FORBIDDEN: Array[String] = [
	"\\btick\\s*\\(",
	"\\bSimContext\\b",
	"\\.rng\\b",
	"\\brand(i|f|i_range|f_range|fn|omize)?\\s*\\(",
	"\\bregister\\.(?!active_window\\b)\\w+\\s*\\(",
	"\\b(player|health|actions|combat)\\.\\w+\\s*\\(",
	"\\bboss\\.\\w+\\s*\\(",
	"\\barena\\.\\w+\\s*\\(",
	"\\b(arena|register|player|health|boss|loop)\\.[\\w.]+\\s*([-+*/]?=[^=])",
	"\\bSimClock\\.(?!paused\\b)\\w+",
	"\\bSimClock\\.paused\\s*=[^=]",
]


static func gd_files_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(gd_files_under(dir.path_join(sub)))
	return out


static func violations(code: String, patterns: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	for pattern: String in patterns:
		if RegEx.create_from_string(pattern).search(code) != null:
			out.append(pattern)
	return out


func test_the_scans_find_their_files() -> void:
	var duck: PackedStringArray = gd_files_under(DUCK_DIR)
	for name: String in ["duck_bubble.gd", "duck_director.gd", "duck_line_def.gd", "duck_lines_def.gd", "typewriter_reveal.gd"]:
		assert_true(duck.has(DUCK_DIR.path_join(name)), name)
	var sim := PackedStringArray()
	for d: String in SIM_DIRS:
		sim.append_array(gd_files_under("res://src".path_join(d)))
	assert_gt(sim.size(), 10, "sim files found")


func test_sim_folders_never_name_the_duck_layer() -> void:
	for d: String in SIM_DIRS:
		for path: String in gd_files_under("res://src".path_join(d)):
			assert_eq(violations(IsolationScript.code_of(path), SIM_FORBIDDEN), PackedStringArray(), path)


func test_the_duck_layer_never_writes_sim_state() -> void:
	for path: String in gd_files_under(DUCK_DIR):
		assert_eq(violations(IsolationScript.code_of(path), DUCK_FORBIDDEN), PackedStringArray(), path)


func test_voice_service_never_touches_the_sim() -> void:
	var code: String = IsolationScript.code_of("res://src/autoloads/voice_service.gd")
	assert_eq(violations(code, DUCK_FORBIDDEN), PackedStringArray())


func test_the_guards_catch_violations() -> void:
	assert_gt(violations("VoiceService.say(\"x\")", SIM_FORBIDDEN).size(), 0)
	assert_gt(violations("EventBus.duck_line_requested.emit(&\"\", \"\")", SIM_FORBIDDEN).size(), 0)
	assert_gt(violations("AudioManager.play_squeak()", SIM_FORBIDDEN).size(), 0)
	assert_gt(violations("SimClock.tick()", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("boss.tick(ctx)", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("var r = ctx.rng", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("arena.register.shift(-1)", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("arena.player.reset_for_fight(p)", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("boss.take_hit(3)", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("boss.phase_index = 2", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("loop.iteration += 1", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("SimClock.paused = true", DUCK_FORBIDDEN).size(), 0)
	assert_gt(violations("SimClock.request_hitstop(2)", DUCK_FORBIDDEN).size(), 0)
	assert_eq(violations("var w: Vector2i = arena.register.active_window()", DUCK_FORBIDDEN).size(), 0)
	assert_eq(violations("var p: int = boss.phase_index if boss != null else 0", DUCK_FORBIDDEN).size(), 0)
	assert_eq(violations("if SimClock.paused:", DUCK_FORBIDDEN).size(), 0)
	assert_eq(violations("if boss.phase_index == 1:", DUCK_FORBIDDEN).size(), 0)

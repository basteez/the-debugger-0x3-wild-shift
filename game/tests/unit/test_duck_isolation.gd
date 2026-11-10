extends GutTest
## Story 3.6 AC 10-11 (H7, NP-3, AD-05): no sim folder names the duck layer, and the duck layer
## never ticks the sim, draws RNG, or writes the register, the player, the boss or the arena.
## Textual scan, comments stripped (the 3.4 attack-isolation pattern).
## Story 3.7 AC 10 (G4): the mumble-speech names appear only in voice_service.gd and the duck voice
## data, and the voice signals only in the duck layer and the autoloads.

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
	"\\bduck_character_spoken\\b",
	"\\bDuckClips?Def\\b",
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
	"\\bboss\\.(?!current_weak_window\\b)\\w+\\s*\\(", # Story 4.4: the hint reads the window
	"\\barena\\.\\w+\\s*\\(",
	"\\b(arena|register|player|health|boss|loop)\\.[\\w.]+\\s*([-+*/]?=[^=])",
	"\\bSimClock\\.(?!paused\\b)\\w+",
	"\\bSimClock\\.paused\\s*=[^=]",
]


## The addon's names (D-S37-3): only VOICE_ALLOWED may mention them (tools/ and the addon itself
## are outside the scanned folders).
const MUMBLE_PATTERN := "MumbleSpeaker|MumbleVoice|MumbleTypewriter|\\bMumble\\.|mumble_speech"
const VOICE_ALLOWED: Array[String] = [
	"res://src/autoloads/voice_service.gd",
	"res://data/duck/duck_voice.tres",
	"res://data/duck/duck_clips.tres",
]
## The voice signals: only the duck layer and the autoloads (EventBus, VoiceService) may name them.
const VOICE_SIGNAL_PATTERN := "\\bduck_character_spoken\\b|\\bduck_line_finished\\b"


## Every file under `dir` whose name ends with one of `suffixes`, recursively.
static func files_under(dir: String, suffixes: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		for suffix: String in suffixes:
			if f.ends_with(suffix):
				out.append(dir.path_join(f))
				break
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(files_under(dir.path_join(sub), suffixes))
	return out


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
	for name: String in ["duck_bubble.gd", "duck_director.gd", "duck_hint.gd", "duck_line_def.gd", "duck_lines_def.gd", "typewriter_reveal.gd"]:
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
	assert_eq(violations("var w: Vector2i = boss.current_weak_window()", DUCK_FORBIDDEN).size(), 0)


func test_mumble_names_only_in_the_voice_files() -> void:
	var paths := PackedStringArray()
	paths.append_array(files_under("res://src", [".gd", ".tscn", ".tres"]))
	paths.append_array(files_under("res://data", [".tres"]))
	assert_gt(paths.size(), 20, "files found")
	var re := RegEx.create_from_string(MUMBLE_PATTERN)
	var found_in_voice_service: bool = false
	for path: String in paths:
		var code: String = IsolationScript.code_of(path) if path.ends_with(".gd") else FileAccess.get_file_as_string(path)
		var hit: bool = re.search(code) != null
		if path == VOICE_ALLOWED[0]:
			found_in_voice_service = hit
		if hit:
			assert_true(VOICE_ALLOWED.has(path), "%s names the mumble-speech addon" % path)
	assert_true(found_in_voice_service, "the scan sees voice_service.gd use the addon")


func test_voice_signals_only_in_the_duck_layer_and_autoloads() -> void:
	var re := RegEx.create_from_string(VOICE_SIGNAL_PATTERN)
	for path: String in files_under("res://src", [".gd"]):
		if path.begins_with(DUCK_DIR + "/") or path.begins_with("res://src/autoloads/") or path.begins_with("res://src/debug/smoke_voice/"):
			continue
		assert_null(re.search(IsolationScript.code_of(path)), "%s names a duck voice signal" % path)


func test_the_mumble_guard_catches_names() -> void:
	var re := RegEx.create_from_string(MUMBLE_PATTERN)
	assert_not_null(re.search("ClassDB.instantiate(&\"MumbleSpeaker\")"))
	assert_not_null(re.search("var v := MumbleVoice.new()"))
	assert_not_null(re.search("Mumble.render(t, v, 48000)"))
	assert_not_null(re.search("res://addons/mumble_speech/bin"))
	assert_null(re.search("var mumbled := 1"))

extends GutTest
## Story 3.4 AC 12 (C2, NP-3, D-S34-10, D-S34-14): attack scripts aim through
## ArenaContext.target_position() only. Every src/bosses/*/attacks/*.gd is read as text (comments
## stripped) and must not name the player, the register, PlayerHealth, SimClock, the body-contact
## read, or any Arena member but play_area / clamp_to_play_area, and must draw no RNG (only
## BossController.pick_next draws from ctx.rng).

const BOSSES_DIR := "res://src/bosses"
const FORBIDDEN: Array[String] = [
	"\\bbody_contact_position\\b",
	"\\bplayer_position\\b",
	"\\bcontact_source\\b",
	"\\bPlayer\\b",
	"\\bRegister\\b",
	"\\bPlayerHealth\\b",
	"\\bSimClock\\b",
	"\\bArena\\.(?!play_area\\b|clamp_to_play_area\\b)",
	"\\brng\\b",
	"\\brand(i|f|i_range|f_range|fn)?\\s*\\(",
]


## Every attack script under src/bosses/<boss>/attacks/.
static func attack_files() -> PackedStringArray:
	var out := PackedStringArray()
	for boss: String in DirAccess.get_directories_at(BOSSES_DIR):
		var dir: String = "%s/%s/attacks" % [BOSSES_DIR, boss]
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				out.append("%s/%s" % [dir, f])
	return out


## The source of `path` with `#` comments removed.
static func code_of(path: String) -> String:
	return strip_comments(FileAccess.get_file_as_string(path))


## `text` with `#` comments removed (no attack uses `#` inside a string).
static func strip_comments(text: String) -> String:
	var lines := PackedStringArray()
	for line: String in text.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at < 0 else line.substr(0, at))
	return "\n".join(lines)


## The forbidden patterns `code` matches.
static func violations(code: String) -> PackedStringArray:
	var out := PackedStringArray()
	for pattern: String in FORBIDDEN:
		var re := RegEx.create_from_string(pattern)
		if re.search(code) != null:
			out.append(pattern)
	return out


func test_the_infinite_loop_attacks_are_found() -> void:
	var files: PackedStringArray = attack_files()
	assert_true(files.has("res://src/bosses/infinite_loop/attacks/head_rush.gd"))
	assert_true(files.has("res://src/bosses/infinite_loop/attacks/constrict.gd"))


func test_attack_scripts_read_only_the_aim() -> void:
	for path: String in attack_files():
		assert_eq(violations(code_of(path)), PackedStringArray(), path)


func test_the_guard_catches_forbidden_reads() -> void:
	assert_gt(violations("var p: Vector2 = ctx.body_contact_position()").size(), 0)
	assert_gt(violations("var p: Vector2 = ctx.player_position()").size(), 0)
	assert_gt(violations("var r: int = Register.glyph_of(1)").size(), 0)
	assert_gt(violations("SimClock.request_hitstop(3)").size(), 0)
	assert_gt(violations("var x: Vector2 = Arena.SPAWN_PX").size(), 0)
	assert_gt(violations("var n: int = ctx_rng.randi()").size(), 0)
	assert_gt(violations("var n: int = rng.randi_range(0, 1)").size(), 0)
	assert_eq(violations("var a: Vector2 = Arena.clamp_to_play_area(ctx.target_position())").size(), 0)
	assert_eq(violations("var r: Rect2 = Arena.play_area()").size(), 0)
	assert_eq(violations(strip_comments("pass # Player and Register in a comment")).size(), 0, "comments are stripped")

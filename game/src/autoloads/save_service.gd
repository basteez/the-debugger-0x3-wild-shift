extends Node
## Persistence to user://save.cfg with silent fallback (AD-10, Story 7.3, FR53, NFR12).
## One ConfigFile, section `save`: version (1), highest_boss (1..3), assist (bool), muted (bool)
## (D-S73-1). Read once at boot; written on a non-retry, non-debug FIGHT entry (Game._set_flow_state),
## on the title's [N] new run, on set_assist (7.4) and on set_muted (the pause screen's [M] toggle).
## Any storage failure keeps the in-memory values and logs one warn per session (D-S73-6).
## Presentation-side only: nothing in the sim tick calls this (AC 12).

const PATH := "user://save.cfg"
const VERSION := 1
const SECTION := "save"
const MIN_BOSS := 1
## Game.LAST_BOSS_INDEX + 1 (literal: test_save_service checks the two stay in step).
const MAX_BOSS := 3

var highest_boss: int = MIN_BOSS
var assist: bool = false
var muted: bool = false
## True once a storage failure has been logged this session (AC 5).
var storage_warned: bool = false
## The file this service reads and writes. Test seam: empty means in-memory only (no I/O at all).
## Under GUT it starts empty, so no test ever reads or writes the real user://save.cfg (Task 4.5);
## tests that exercise the I/O set a scratch path under user:// and delete it afterwards.
var path: String = PATH
## Test seam: false makes note_fight_start a no-op. Under GUT the autoload starts with it off, so a
## test that plays a fight never leaves a raised highest_boss behind for a later title (which would
## then resume instead of playing the Intro); tests of the write rules turn it on and restore it.
var track_fights: bool = true


func _ready() -> void:
	if running_under_gut():
		path = ""
		track_fights = false
	load_save()
	# AudioManager is registered before SaveService in project.godot, so it exists here (Task 1.4).
	AudioManager.set_master_muted(muted)


## True when the process is a GUT test run (the command-line runner or the editor's GUT runner scene).
## Fail-safe: an export template build (desktop or web) has no "editor" feature, so this is always
## false there and saving can never be silently disabled in a shipped build.
static func running_under_gut() -> bool:
	if not OS.has_feature("editor"):
		return false
	var tree := Engine.get_main_loop()
	if tree != null:
		var script := tree.get_script() as Script
		if script != null and script.resource_path.contains("/gut/"):
			return true
	for arg: String in OS.get_cmdline_args():
		if arg.contains("addons/gut/"):
			return true
	return false


## Pure: an int in MIN_BOSS..MAX_BOSS from any stored value; a non-number is MIN_BOSS.
static func clamp_highest(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return MIN_BOSS
	return clampi(int(v), MIN_BOSS, MAX_BOSS)


## Pure: the fresh-save values.
static func defaults() -> Dictionary:
	return {"highest_boss": MIN_BOSS, "assist": false, "muted": false, "valid": true}


## Pure: the values held by `cfg`. A version other than VERSION, or a value of the wrong type,
## gives the defaults with "valid" false (D-S73-8); the caller logs it once.
static func parse(cfg: ConfigFile) -> Dictionary:
	var out := defaults()
	if not cfg.has_section_key(SECTION, "version"):
		out["valid"] = false
		return out
	var version: Variant = cfg.get_value(SECTION, "version", 0)
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		out["valid"] = false
		return out
	var hb: Variant = cfg.get_value(SECTION, "highest_boss", MIN_BOSS)
	var a: Variant = cfg.get_value(SECTION, "assist", false)
	var m: Variant = cfg.get_value(SECTION, "muted", false)
	if (typeof(hb) != TYPE_INT and typeof(hb) != TYPE_FLOAT) or typeof(a) != TYPE_BOOL or typeof(m) != TYPE_BOOL:
		out["valid"] = false
		return out
	out["highest_boss"] = clamp_highest(hb)
	out["assist"] = a
	out["muted"] = m
	return out


## Pure: a ConfigFile holding these values (no I/O).
static func to_config(p_highest_boss: int, p_assist: bool, p_muted: bool) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "version", VERSION)
	cfg.set_value(SECTION, "highest_boss", clamp_highest(p_highest_boss))
	cfg.set_value(SECTION, "assist", p_assist)
	cfg.set_value(SECTION, "muted", p_muted)
	return cfg


## Reads `path` into memory. A missing file is a fresh save, silently; any other failure, a bad
## version or a bad value is a fresh save with one warn (AC 1, AC 5).
func load_save() -> void:
	_apply(defaults())
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(path)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		_warn_once("load failed (%s), using a fresh save" % error_string(err))
		return
	var values: Dictionary = parse(cfg)
	if not values["valid"]:
		_warn_once("save version or values not recognised, using a fresh save")
		return
	_apply(values)


## Writes the in-memory values to `path`. True on success; false (one warn per session) when
## storage refuses it, or when the service is in-memory only (empty path, no warn). Never raises.
func save() -> bool:
	if path.is_empty():
		return false
	var err: Error = to_config(highest_boss, assist, muted).save(path)
	if err != OK:
		_warn_once("write failed (%s), progress kept in memory only" % error_string(err))
		return false
	return true


## A fight began (non-retry, non-debug FIGHT entry): the save only ever moves forward (AC 2, D-S73-9).
func note_fight_start(boss_index: int) -> void:
	if not track_fights:
		return
	var raised: int = maxi(highest_boss, clamp_highest(boss_index + 1))
	if raised == highest_boss:
		return # unchanged (a resume or a replayed boss): skip a pointless web storage write
	highest_boss = raised
	save()


## The title's [N] new run (AC 9): the only path that lowers highest_boss.
func reset_run_progress() -> void:
	highest_boss = MIN_BOSS
	save()


## Story 7.4 hook (AC 3): the assist toggle writes through here; 7.4 never writes the file itself.
func set_assist(on: bool) -> void:
	assist = on
	save()


## The pause screen's [M] toggle (D-S73-7 overturned by the coordinator): the mute is kept.
func set_muted(on: bool) -> void:
	muted = on
	save()


## True when a run can resume past the first boss (the title shows [N] new run, AC 8).
func has_progress() -> bool:
	return highest_boss > MIN_BOSS


func _apply(values: Dictionary) -> void:
	highest_boss = clamp_highest(values["highest_boss"])
	assist = values["assist"]
	muted = values["muted"]


func _warn_once(msg: String) -> void:
	if storage_warned:
		return
	storage_warned = true
	Log.warn(&"save", msg)

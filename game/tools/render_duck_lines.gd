extends SceneTree
## Pre-render contingency (Story 3.7, AD-14, F1, D-S37-14): renders every DuckLinesDef line with
## the duck voice into assets/audio/duck/<id>.wav and writes data/duck/duck_clips.tres with the
## per-character reveal times from the render events. Tools only (excluded from export by tools/*).
## Tools code outside src/, so it prints directly (no autoloads in -s scripts).
## Run twice from the repo root, with an import in between (the .tres needs the imported clips):
##   godot --headless --path game -s res://tools/render_duck_lines.gd -- wav
##   godot --headless --path game --import
##   godot --headless --path game -s res://tools/render_duck_lines.gd -- tres

const LINES_PATH := "res://data/duck/duck_lines.tres"
const VOICE_PATH := "res://data/duck/duck_voice.tres"
const CLIPS_PATH := "res://data/duck/duck_clips.tres"
const WAV_DIR := "res://assets/audio/duck"
const SAMPLE_RATE := 48000


func _initialize() -> void:
	var mode: String = "wav" if not OS.get_cmdline_user_args().has("tres") else "tres"
	var code: int = _render(mode == "tres")
	quit(code)


func _render(write_tres: bool) -> int:
	if not ClassDB.class_exists(&"Mumble"):
		printerr("render_duck_lines: the mumble_speech addon is not loaded (run an import first)")
		return 1
	var lines := load(LINES_PATH) as DuckLinesDef
	var voice: Resource = load(VOICE_PATH)
	if lines == null or voice == null:
		printerr("render_duck_lines: cannot load %s or %s" % [LINES_PATH, VOICE_PATH])
		return 1
	var clips := DuckClipsDef.new()
	for line: DuckLineDef in lines.entries:
		# The bubble reveals the joined wrapped text (D-S36-16): the words joined by single spaces
		# (DuckBubble.wrap is not usable here, it needs the autoloads), so that is what is spoken.
		var text: String = " ".join(line.text.split(" ", false))
		var result: Dictionary = ClassDB.class_call_static(&"Mumble", &"render", text, voice, SAMPLE_RATE)
		if result.has("error"):
			printerr("render_duck_lines: %s: %s" % [line.id, result["error"]])
			return 1
		var wav_path: String = "%s/%s.wav" % [WAV_DIR, line.id]
		if not write_tres:
			var bytes: PackedByteArray = ClassDB.class_call_static(&"Mumble", &"encode_wav", result["samples"], SAMPLE_RATE)
			var f := FileAccess.open(wav_path, FileAccess.WRITE)
			if f == null:
				printerr("render_duck_lines: cannot write %s" % wav_path)
				return 1
			f.store_buffer(bytes)
			f.close()
			print("render_duck_lines: %s %.3f s, %d bytes" % [wav_path, float(result["duration"]), bytes.size()])
			continue
		var clip := DuckClipDef.new()
		clip.id = line.id
		clip.stream = load(wav_path) as AudioStreamWAV
		if clip.stream == null:
			printerr("render_duck_lines: %s is not imported yet (run --import)" % wav_path)
			return 1
		clip.char_times = DuckClipDef.char_times_from_events(text.length(), result["events"], float(result["duration"]))
		clips.entries.append(clip)
	if write_tres:
		var problems: PackedStringArray = clips.validate()
		if not problems.is_empty():
			printerr("render_duck_lines: %s" % ", ".join(problems))
			return 1
		var err: Error = ResourceSaver.save(clips, CLIPS_PATH)
		if err != OK:
			printerr("render_duck_lines: save %s failed (%d)" % [CLIPS_PATH, err])
			return 1
		print("render_duck_lines: wrote %s (%d clips)" % [CLIPS_PATH, clips.entries.size()])
	return 0

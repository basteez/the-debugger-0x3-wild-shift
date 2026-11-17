extends GutTest
## Hotfix (tutorial checklist invisible on web): an `@export var x: Packed*Array = [...]` default
## (an Array literal) makes the editor's export drop the value the .tres holds when it converts the
## resource to binary, so the shipped build reads an empty array. The tutorial's test names and
## prompts (TextScreenText) were lost this way and its checklist drew nothing. Packed array exports
## take a `PackedXArray()` default instead. A source scan: the bug only shows in an exported build.

const SCAN_DIRS: Array[String] = ["res://src", "res://data"]


## Pure: true when `line` declares an exported Packed*Array whose default is an Array literal.
static func is_packed_array_literal_export(line: String) -> bool:
	var re := RegEx.create_from_string("^\\s*@export\\w*.*:\\s*Packed\\w+Array\\s*=\\s*\\[")
	return re.search(line) != null


static func _scripts(dir: String, out: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))


func test_detector_flags_the_shipped_bug_and_passes_the_fix() -> void:
	assert_true(is_packed_array_literal_export("@export var tutorial_tests: PackedStringArray = []"))
	assert_true(is_packed_array_literal_export("@export var xs: PackedInt32Array = [1, 2]"))
	assert_true(is_packed_array_literal_export("@export_multiline var rows: PackedStringArray = []"))
	assert_false(is_packed_array_literal_export("@export var tutorial_tests: PackedStringArray = PackedStringArray()"))
	assert_false(is_packed_array_literal_export("var lines: PackedStringArray = []"), "not exported: never serialized")
	assert_false(is_packed_array_literal_export("@export var panels: Array[PackedStringArray] = []"), "a typed Array survives export")


func test_no_exported_packed_array_has_an_array_literal_default() -> void:
	var files := PackedStringArray()
	for dir: String in SCAN_DIRS:
		_scripts(dir, files)
	assert_gt(files.size(), 50, "the scan sees the source scripts")
	var bad := PackedStringArray()
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if is_packed_array_literal_export(lines[i]):
				bad.append("%s:%d" % [path, i + 1])
	assert_eq(bad, PackedStringArray(), "use a PackedXArray() default, never [] (export drops the value)")


## Sanity check only: the editor/headless load of the .tres does not reproduce the export bug (the
## text -> binary conversion does), so this passes either way; the source scan above is the guard.
func test_tutorial_text_rows_are_present() -> void:
	var text: TextScreenText = load("res://data/text/screen_text.tres")
	assert_eq(text.tutorial_tests.size(), TextScreenText.TUTORIAL_STEP_COUNT)
	assert_eq(text.tutorial_prompts.size(), TextScreenText.TUTORIAL_STEP_COUNT)
	assert_eq(text.tutorial_prompts_2.size(), TextScreenText.TUTORIAL_STEP_COUNT)

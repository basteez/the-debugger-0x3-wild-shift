class_name ComboTable
extends Def
## Every combo, looked up by ORDERED pair (Story 2.6, AD-02): get_combo(A, D) is Dash Strike,
## get_combo(D, A) is null (no combo: J then K performs both solo actions). Never sorted.
## Read-only at runtime; the index is built once on the first lookup and never changed afterwards.

@export var combos: Array[ComboDef] = []

var _index: Dictionary[int, ComboDef] = {}
var _indexed: bool = false


## The combo fired by K on the window (first, second), or null for no combo.
func get_combo(first: int, second: int) -> ComboDef:
	if not _indexed:
		_build_index()
	return _index.get(key(first, second), null)


## The ordered key of a pair: (first, second) and (second, first) differ. Pure.
static func key(first: int, second: int) -> int:
	return first * 256 + second


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary[int, bool] = {}
	for i: int in combos.size():
		var combo: ComboDef = combos[i]
		if combo == null:
			out.append("combos[%d] is null" % i)
			continue
		for message: String in combo.validate():
			out.append("combos[%d]: %s" % [i, message])
		var k: int = key(combo.first, combo.second)
		if seen.has(k):
			out.append("combos[%d]: duplicate ordered pair %d->%d" % [i, combo.first, combo.second])
		seen[k] = true
	return out


func _build_index() -> void:
	_indexed = true
	for combo: ComboDef in combos:
		if combo == null:
			continue
		var k: int = key(combo.first, combo.second)
		if _index.has(k):
			Log.error(&"combo", "duplicate ordered pair %d->%d, keeping the first" % [combo.first, combo.second])
			continue
		_index[k] = combo

extends BossAttack
## Null Pointer, Dangling Pointers (Story 5.3, FR39, D-S53-1, D-S53-9): phase 2 only. TELL (30
## frames): two `null` flickers mark the decoy spots the body planned on the first TELL tick (the
## body draws them from SimContext; this script draws nothing random and reads no player). ACTIVE
## (60 frames): on its first tick the body spawns the planned decoys and arms its 15-second re-cast.
## RECOVERY (30 frames): nothing; the ghost is visible (Story 5.1). No hazard of its own: hazard_hit
## stays false. A phase change or defeat cancels the plan (on_cancel, D-S53-7).

## The glyph drawn at each tell mark: a `null` flicker, not `!` (D-S53-9).
const TELL_GLYPH := "null"


## TELL entry: ask the body to plan the spots on its next tick (AC 8).
func on_tell(_ctx: ArenaContext) -> void:
	var b: NullPointerBody = _body()
	if b != null:
		b.request_decoy_plan()


## Every ACTIVE tick: the first one spawns the planned decoys and arms the re-cast (AC 2).
func on_active(_ctx: ArenaContext) -> void:
	var b: NullPointerBody = _body()
	if b != null:
		b.spawn_planned()


func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	var b: NullPointerBody = _body()
	if b != null:
		b.clear_planned()


## TELL: the planned spots (presentation draws the `null` flicker there).
func tell_marks() -> PackedVector2Array:
	var b: NullPointerBody = _body()
	if b != null and b.state == BossController.BossState.TELL and b.current_attack() == self:
		return b.planned_positions()
	return PackedVector2Array()


func tell_glyph() -> String:
	return TELL_GLYPH


## AC 18 (Pillar 2): the planned spots when there are any, plus the corners of the inset rectangle
## every spot is drawn from (the bound of any spot, whatever the aim).
func declared_positions(_ctx: ArenaContext) -> PackedVector2Array:
	var out := PackedVector2Array()
	var b: NullPointerBody = _body()
	if b != null:
		out.append_array(b.planned_positions())
	var inset: float = NullPointerBody.mtiles_to_px(NullPointerBody.SPOT_INSET_MTILES)
	var r: Rect2 = Arena.play_area().grow(-inset)
	out.append_array(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]))
	return out


func _body() -> NullPointerBody:
	return boss() as NullPointerBody

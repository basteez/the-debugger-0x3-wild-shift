extends GutTest
## Story 8.1 (AC 1, 3-8, D-E8-1..3, D-S81-1..8): the Infinite Loop's `;` readability. The 1.0-tile
## hurt circle, the ring body query used by the miss feedback (BossController.body_touch_px /
## body_overlaps_shape, D-S81-3), the open `;` cue and its countdown (BossView, presentation only)
## and the miss listeners (LogPanel, ParticlePool, AudioManager). The resolver side of the miss is
## covered in test_combat_resolver.gd, Echo Dash in test_echo_dash.gd.

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")
const TILE := Const.TILE_PX

var _shifts: int = 0
var _arena: ArenaContext


func before_each() -> void:
	_shifts = 0
	_arena = ArenaContext.new()
	_arena.shift_count = func() -> int: return _shifts


## A reset Infinite Loop whose player stands on the ring centre (no drift).
func _body() -> InfiniteLoopBody:
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(IL_DEF, null, _arena))
	b.reset_for_fight()
	var centre: Vector2 = b.body_center_px
	_arena.contact_source = func() -> Vector2: return centre
	return b


## The first shift, then the tick that sees it: the `;` opens.
func _start(b: InfiniteLoopBody) -> void:
	_shifts += 1
	b.tick(SimContext.new())


func _circle(r_tiles: float) -> HitCircle:
	var c := HitCircle.new()
	c.radius_tiles = r_tiles
	return c


# --- AC 1: the hurt circle is 1.0 tile, contact stays 0.5 ---

func test_hurt_radius_is_one_tile_in_data_and_script_default() -> void:
	var ring: RingDef = load("res://data/bosses/infinite_loop/ring_def.tres")
	assert_eq(ring.hurt_radius_tiles, 1.0)
	assert_eq(ring.contact_radius_tiles, 0.5)
	assert_eq(RingDef.new().hurt_radius_tiles, 1.0, "the script default matches the data")
	assert_eq(ring.validate(), PackedStringArray())


func test_a_hit_within_one_tile_of_the_open_semicolon_counts() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var point: HitCircle = _circle(0.01)
	var outward: Vector2 = (b.semicolon_px() - b.body_center_px).normalized()
	assert_true(b.overlaps_shape(point, b.semicolon_px() + outward * 15.9, Vector2.RIGHT), "outside the ring, < 1 tile")
	assert_true(b.overlaps_shape(point, b.semicolon_px() - outward * 15.9, Vector2.RIGHT), "from the inside, < 1 tile")
	assert_false(b.overlaps_shape(point, b.semicolon_px() + outward * 16.5, Vector2.RIGHT), "> 1 tile")


# --- AC 5, 7, 8: the ring body query (D-S81-3, D-S81-8) ---

func test_base_boss_has_no_ring_body() -> void:
	var c := BossController.new()
	assert_false(c.body_overlaps_shape(_circle(4.0), Vector2.ZERO, Vector2.RIGHT))
	assert_false(c.body_touch_px(_circle(4.0), Vector2.ZERO, Vector2.RIGHT).is_finite())
	assert_false(c.weak_point_open())


func test_every_outer_segment_is_body_and_the_centre_is_not() -> void:
	var b: InfiniteLoopBody = _body()
	var small: HitCircle = _circle(0.25)
	for k: int in b.outer_segments():
		assert_true(b.body_overlaps_shape(small, b.segment_px(k), Vector2.RIGHT), "segment %d" % k)
	assert_eq(b.body_touch_px(small, b.segment_px(5), Vector2.RIGHT), b.segment_px(5), "the touched segment's centre")
	assert_false(b.body_overlaps_shape(small, b.body_center_px, Vector2.RIGHT), "the hollow centre")
	assert_false(b.body_overlaps_shape(null, b.segment_px(3), Vector2.RIGHT))
	# Contact circle 0.5 tile + shape 0.25 tile = 12 px from a segment centre, outward.
	var outward: Vector2 = (b.segment_px(12) - b.body_center_px).normalized()
	assert_true(b.body_overlaps_shape(small, b.segment_px(12) + outward * 11.9, Vector2.RIGHT))
	assert_false(b.body_overlaps_shape(small, b.segment_px(12) + outward * 12.5, Vector2.RIGHT))


func test_the_closed_semicolon_is_body() -> void:
	var b: InfiniteLoopBody = _body()
	var small: HitCircle = _circle(0.25)
	assert_false(b.is_open())
	assert_false(b.weak_point_open())
	assert_true(b.body_overlaps_shape(small, b.semicolon_px(), Vector2.RIGHT), "the junction is a segment")
	assert_false(b.overlaps_shape(small, b.semicolon_px(), Vector2.RIGHT), "but no hit while closed")
	_start(b)
	assert_true(b.weak_point_open())


func test_inner_ring_segments_are_body_after_the_split() -> void:
	var b: InfiniteLoopBody = _body()
	var small: HitCircle = _circle(0.25)
	assert_eq(b.inner_segment_count(), 0)
	b.split_rings()
	assert_eq(b.inner_segment_count(), 8)
	for k: int in b.inner_segment_count():
		assert_true(b.body_overlaps_shape(small, b.inner_segment_px(k), Vector2.RIGHT), "inner segment %d" % k)
	for k: int in b.outer_segments():
		assert_true(b.body_overlaps_shape(small, b.segment_px(k), Vector2.RIGHT), "outer segment %d" % k)


func test_no_body_while_roaring_or_defeated() -> void:
	var b: InfiniteLoopBody = _body()
	var small: HitCircle = _circle(0.25)
	b.debug_skip_phase()
	assert_eq(b.state, BossController.BossState.ROAR)
	assert_false(b.body_overlaps_shape(small, b.segment_px(4), Vector2.RIGHT), "ROAR")
	b.debug_kill()
	assert_eq(b.state, BossController.BossState.DEFEATED)
	assert_false(b.body_overlaps_shape(small, b.segment_px(4), Vector2.RIGHT), "DEFEATED")


## Story 9.2 (AC 1, 3, D-S92-1): the sim-side blink predicate equals the drawn blink for every
## frames_left in a Nested Loop TELL, is off outside it, and hides the ring body while on.
func test_ring_blinked_out_matches_the_drawn_blink() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	assert_true(b.debug_skip_phase())
	assert_true(b.debug_skip_phase())
	assert_eq(b.phase_index, InfiniteLoopBody.PHASE_3)
	var guard: int = 0
	while b.state != BossController.BossState.TELL and guard < 3000:
		b.tick(SimContext.new())
		guard += 1
	assert_eq(b.state, BossController.BossState.TELL)
	assert_eq(b.current.id, InfiniteLoopBody.NESTED_LOOP_ID, "the first phase-3 pick is the Nested Loop")
	assert_true(BossView.nested_telling(b))
	var hidden: int = 0
	for f: int in range(0, 61):
		b.frames_left = f
		var drawn: bool = BossView.nested_flash_hidden(BossView.nested_telling(b), f)
		assert_eq(b.ring_blinked_out(), drawn, "frames_left %d" % f)
		# Independent expectation (the delegation above would make the parity alone tautological).
		assert_eq(drawn, (f / 6) % 2 == 1, "blink arithmetic at frames_left %d" % f)
		if drawn:
			hidden += 1
	assert_gt(hidden, 0)
	assert_lt(hidden, 61, "a blink, not a blank")
	assert_eq(BossView.FLASH_BLOCK, InfiniteLoopBody.FLASH_BLOCK)
	var small: HitCircle = _circle(0.25)
	b.frames_left = InfiniteLoopBody.FLASH_BLOCK # a hidden block
	assert_true(b.ring_blinked_out())
	assert_false(b.body_touch_px(small, b.segment_px(4), Vector2.RIGHT).is_finite(), "no body while blinked out")
	b.frames_left = 0 # a drawn block
	assert_false(b.ring_blinked_out())
	assert_true(b.body_touch_px(small, b.segment_px(4), Vector2.RIGHT).is_finite(), "body while drawn")
	b.state = BossController.BossState.GAP
	b.frames_left = InfiniteLoopBody.FLASH_BLOCK
	assert_false(b.ring_blinked_out(), "no blink outside TELL")


# --- AC 3, 4: the open cue (presentation) ---

func test_open_bar_fraction_edges() -> void:
	assert_eq(BossView.open_bar_fraction(90, 90), 1.0)
	assert_eq(BossView.open_bar_fraction(45, 90), 0.5)
	assert_eq(BossView.open_bar_fraction(0, 90), 0.0)
	assert_eq(BossView.open_bar_fraction(120, 90), 1.0, "clamped")
	assert_eq(BossView.open_bar_fraction(-5, 90), 0.0, "clamped")
	assert_eq(BossView.open_bar_fraction(10, 0), 0.0, "no open window")


func test_cue_is_on_only_while_the_semicolon_is_hittable() -> void:
	var b: InfiniteLoopBody = _body()
	assert_false(BossView.semicolon_cue_on(null))
	assert_false(BossView.semicolon_cue_on(b), "closed: plain glyph, no marker, no bar")
	_start(b)
	assert_true(BossView.semicolon_cue_on(b), "open")
	for i: int in b.ring.open_frames:
		b.tick(SimContext.new())
	assert_false(b.is_open())
	assert_false(BossView.semicolon_cue_on(b), "closed again")
	b.open_semicolon(30)
	assert_true(BossView.semicolon_cue_on(b))
	b.debug_skip_phase()
	assert_false(BossView.semicolon_cue_on(b), "ROAR")
	b.debug_kill()
	assert_false(BossView.semicolon_cue_on(b), "DEFEATED")


## D-S81-1 (coordinator): the marker and the bar sit on the inner side of the ring, inside its
## footprint, for every junction angle and for both ring sizes, so the drift clamp needs no change.
func test_cue_geometry_stays_on_the_inner_side_inside_the_footprint() -> void:
	var centre := Vector2(200, 120)
	var outer_r: float = HitShape.tiles_to_px(RingDef.new().radius_tiles())
	var inner_r: float = HitShape.tiles_to_px(RingDef.split_radius_tiles(8))
	for r: float in [outer_r, inner_r]:
		for step: int in 16:
			var semicolon: Vector2 = centre + Vector2.from_angle(TAU * step / 16.0) * r
			var marker: PackedVector2Array = BossView.open_cue_marker(centre, semicolon)
			var bar: PackedVector2Array = BossView.open_cue_bar(centre, semicolon)
			assert_eq(marker.size(), 3, "a triangle")
			assert_eq(bar.size(), 2, "the bar's two ends")
			for p: Vector2 in marker + bar:
				assert_lte(p.distance_to(centre), r + 0.01, "inner side (r %.1f, step %d)" % [r, step])
			var tip: Vector2 = marker[0]
			assert_lt(tip.distance_to(semicolon), marker[1].distance_to(semicolon), "the tip points at the `;`")
			assert_gte(bar[0].distance_to(semicolon), GlyphFont.CELL * BossView.GLYPH_SCALE * 0.5, "clear of the `;` cell")


## Review fix: on the small phase-3 inner ring the marker keeps a real area (not collapsed on the centre).
func test_cue_marker_keeps_area_on_the_inner_ring() -> void:
	var centre := Vector2(200, 120)
	var inner_r: float = HitShape.tiles_to_px(RingDef.split_radius_tiles(8))
	var m: PackedVector2Array = BossView.open_cue_marker(centre, centre + Vector2(0, -inner_r))
	assert_gt(absf((m[1] - m[0]).cross(m[2] - m[0])) / 2.0, 4.0, "triangle area in px^2")
	assert_gt(m[0].distance_to(centre), 2.0, "the tip is clear of the centre")


# --- AC 5, 6: the miss listeners ---

func test_line_for_miss_wording_ascii_and_width() -> void:
	assert_eq(LogPanel.line_for_miss(true), "// miss: \";\" is closed")
	assert_eq(LogPanel.line_for_miss(false), "// miss: aim for the \";\"")
	for closed: bool in [true, false]:
		var line: String = LogPanel.line_for_miss(closed)
		for i: int in line.length():
			assert_lt(line.unicode_at(i), 128, "ASCII only")
		assert_lte(line.length(), Hud.LOG.size.x, "fits the log width")


func test_miss_signal_appends_one_dithered_line() -> void:
	var panel := LogPanel.new()
	add_child_autofree(panel)
	EventBus.hit_missed.emit(&"boss", true, Vector2.ZERO)
	EventBus.hit_missed.emit(&"boss", false, Vector2.ZERO)
	assert_eq(panel.lines(), PackedStringArray([LogPanel.line_for_miss(true), LogPanel.line_for_miss(false)]))
	assert_eq(panel.dithered_lines(), [true, true] as Array[bool], "dithered like the resisted line")
	remove_child(panel)
	assert_false(EventBus.hit_missed.is_connected(panel._on_hit_missed), "disconnected on exit")
	add_child(panel)
	assert_true(EventBus.hit_missed.is_connected(panel._on_hit_missed))


func test_miss_signal_spawns_a_three_particle_deflect() -> void:
	var pool := ParticlePool.new()
	pool.rng.seed = 1234
	add_child_autofree(pool)
	EventBus.hit_missed.emit(&"boss", true, Vector2(50, 60))
	assert_eq(pool.live_count(), ParticlePool.DEFLECT_BURST)
	assert_eq(ParticlePool.DEFLECT_BURST, 3)
	assert_lt(ParticlePool.DEFLECT_BURST, ParticlePool.burst_for(false), "smaller than any hit burst")
	assert_eq(pool.position_of(0), Vector2(50, 60), "at the contact point")


func test_miss_signal_plays_the_resisted_cue_and_no_new_asset() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	EventBus.hit_missed.emit(&"boss", true, Vector2.ZERO)
	assert_ne(am.last_cue, &"hit_resisted", "locked audio stays silent")
	am.unlock()
	EventBus.hit_missed.emit(&"boss", false, Vector2.ZERO)
	assert_eq(am.last_cue, &"hit_resisted")

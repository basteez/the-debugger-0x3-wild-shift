extends GutTest
## Story 7.8 (AC 5-7, 9-11): RunStats' playtest metric record. Pure, no randomness (no seed needed):
## first-only shift and FIGHT-entry rules, retries keep the boss clock, per-boss deaths, clear frames,
## seconds() edge cases, the ENDING summary line format and an unchanged snapshot() shape.


func test_a_new_record_is_empty() -> void:
	var s := RunStats.new()
	assert_eq(s.first_shift_frame, -1)
	assert_eq(s.boss_start_frames, {})
	assert_eq(s.boss_clear_frames, {})
	assert_eq(s.boss_deaths, {})
	assert_eq(s.deaths_on(0), 0)


func test_first_shift_is_recorded_only_once() -> void:
	var s := RunStats.new()
	assert_true(s.note_first_shift(300))
	assert_false(s.note_first_shift(400), "only the first shift of a run")
	assert_eq(s.first_shift_frame, 300)


func test_fight_entry_is_first_only_per_boss() -> void:
	var s := RunStats.new()
	s.note_fight_entry(0, 100)
	s.note_fight_entry(0, 900) # a later entry of the same boss (e.g. a debug jump) keeps the clock
	s.note_fight_entry(1, 2000)
	s.note_fight_entry(-1, 5) # outside the boss range: ignored
	assert_eq(s.boss_start_frames, {0: 100, 1: 2000})


func test_clear_frames_span_every_retry_and_need_a_start() -> void:
	var s := RunStats.new()
	assert_eq(s.note_boss_cleared(0, 500), -1, "no recorded start: -1")
	assert_false(s.boss_clear_frames.has(0))
	s.note_fight_entry(0, 100)
	s.note_death(0)
	s.note_death(0)
	assert_eq(s.note_boss_cleared(0, 5340), 5240, "from the first entry, retries included")
	assert_eq(s.boss_clear_frames[0], 5240)
	assert_eq(s.deaths_on(0), 2)
	assert_eq(s.deaths_on(1), 0)


func test_deaths_are_counted_per_boss() -> void:
	var s := RunStats.new()
	s.note_death(0)
	s.note_death(1)
	s.note_death(1)
	s.note_death(-1)
	assert_eq(s.boss_deaths, {0: 1, 1: 2})


func test_seconds() -> void:
	assert_eq(RunStats.seconds(0), 0.0)
	assert_eq(RunStats.seconds(60), 1.0)
	assert_almost_eq(RunStats.seconds(744), 12.4, 0.0001)
	assert_eq(RunStats.seconds(-1), -1.0, "not recorded")


func test_summary_line_format() -> void:
	var s := RunStats.new()
	s.hits = 31
	s.note_fight_entry(0, 600)
	s.note_fight_entry(1, 7000)
	s.note_fight_entry(2, 16000)
	s.note_death(0)
	s.note_death(0)
	s.note_death(1)
	s.note_death(2)
	s.note_death(2)
	s.note_death(2)
	s.note_boss_cleared(0, 600 + 5238) # 87.3 s
	s.note_boss_cleared(1, 7000 + 7860) # 131.0 s
	s.note_boss_cleared(2, 16000 + 10572) # 176.2 s
	assert_eq(s.metrics_summary(100, 100 + 44574, false, false),
		"run full_run_s=742.9 hits=31 assist=false debug_jumped=false bosses=[1:87.3/2, 2:131.0/1, 3:176.2/3]")


func test_summary_omits_bosses_not_cleared_and_flags_the_run() -> void:
	var s := RunStats.new()
	s.note_fight_entry(1, 0)
	s.note_boss_cleared(1, 600)
	s.note_fight_entry(0, 0) # entered, never cleared: omitted
	assert_eq(s.metrics_summary(-1, 900, true, true),
		"run full_run_s=-1.0 hits=0 assist=true debug_jumped=true bosses=[2:10.0/0]")


func test_summary_with_no_boss() -> void:
	assert_eq(RunStats.new().metrics_summary(0, 60, false, false),
		"run full_run_s=1.0 hits=0 assist=false debug_jumped=false bosses=[]")


func test_snapshot_shape_is_unchanged() -> void:
	var s := RunStats.new()
	s.note_fight_entry(0, 10)
	s.note_first_shift(20)
	var snap: Dictionary = s.snapshot(100)
	assert_eq(snap.keys().size(), 3)
	assert_true(snap.has(&"clear_frames") and snap.has(&"hits") and snap.has(&"debug_jumped"))

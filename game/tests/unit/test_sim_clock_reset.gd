extends GutTest
## Story 9.5 (item 299, D-S95-2): SimClock.reset_for_tests() clears the hit-stop and swallow state
## that no public call can clear, and the central reset restores the shared autoload state.


func test_reset_for_tests_clears_the_hitstop_state() -> void:
	SimClock.request_hitstop(6)
	SimClock.hitstop_frames = 3
	SimClock.swallow_presses_next_poll()
	SimClock.reset_for_tests()
	assert_eq(SimClock.get(&"_pending_hitstop"), 0, "pending hit-stop cleared")
	assert_eq(SimClock.hitstop_frames, 0, "running hit-stop cleared")
	assert_false(SimClock.get(&"_swallow_presses"), "swallow flag cleared")


## Without the hook (an editor run without pre_run_script) these are pending; CI fails on pending.
func test_the_hook_took_the_boot_snapshot_and_reset_this_suite() -> void:
	if not TestIsolation.has_boot_snapshot():
		pending("needs the pre-run hook (game/.gutconfig.json pre_run_script)")
		return
	assert_gt(TestIsolation.reset_count, 0, "at least one suite start was reset")


func test_reset_shared_state_restores_the_boot_values() -> void:
	if not TestIsolation.has_boot_snapshot():
		pending("needs the pre-run hook's boot snapshot")
		return
	var run: RunState = Game.run
	Game.title_entry_frame = 123
	Game.run.assist = true
	SaveService.assist = true
	Debug.enabled = not Debug.enabled
	var debug_after: bool = Debug.enabled
	Fullscreen.set_mode_fn = func(_m: DisplayServer.WindowMode) -> void: pass
	SimClock.request_hitstop(4)
	TestIsolation.reset_shared_state()
	assert_eq(Game.title_entry_frame, -1, "boot title entry")
	assert_ne(Game.run, run, "a fresh RunState")
	assert_false(Game.run.assist)
	assert_false(SaveService.assist)
	assert_ne(Debug.enabled, debug_after, "Debug.enabled back to boot")
	assert_eq(SimClock.get(&"_pending_hitstop"), 0)
	assert_eq(SaveService.path, "", "GUT boot: no save file")

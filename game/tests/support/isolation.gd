class_name TestIsolation
extends RefCounted
## Story 9.5 (D-S95-1, D-S95-4): the central reset of the shared autoload state for GUT runs.
## The pre-run hook (gut_isolation_hook.gd) calls take_boot_snapshot() once, before any suite runs,
## and reset_shared_state() at the start of every suite (gut.start_script). Suites keep their own
## before_each / after_each for state they change inside a suite. Test-only: tests/ is never exported.

## Primitive autoload fields restored from the boot snapshot: {autoload name: [field, ...]}.
const SNAPSHOT_FIELDS := {
	&"Game": [
		&"flow_state", &"first_input_frame", &"title_entry_frame", &"intro_start_frame",
		&"death_frame", &"harvest_start_frame", &"ending_start_frame", &"practice_run",
		&"practice_loadout_index", &"practice_start_frame", &"tutorial_routing_enabled",
		&"tutorial_replay", &"segfault_enabled", &"_retrying", &"_paused_at_msec",
	],
	&"SaveService": [
		&"highest_boss", &"assist", &"muted", &"tutorial_done", &"completed", &"storage_warned",
		&"track_fights", &"path",
	],
	&"AudioManager": [&"_unlocked", &"_warned_locked", &"locked_warn_count"],
	&"SimClock": [
		&"sim_frame", &"poll_frame", &"paused", &"breakpoint_gate_active", &"watch_gate_active",
		&"input_source",
	],
	&"Debug": [&"enabled"],
}

static var _boot: Dictionary = {}
static var _boot_get_mode_fn: Callable
static var _boot_set_mode_fn: Callable
static var reset_count: int = 0


## Records the boot values. Called once by the hook, after the autoloads exist and before any suite.
static func take_boot_snapshot() -> void:
	_boot.clear()
	for autoload_name: StringName in SNAPSHOT_FIELDS:
		var node: Node = _autoload(autoload_name)
		var values: Dictionary = {}
		for field: StringName in SNAPSHOT_FIELDS[autoload_name]:
			values[field] = node.get(field)
		_boot[autoload_name] = values
	_boot_get_mode_fn = Fullscreen.get_mode_fn
	_boot_set_mode_fn = Fullscreen.set_mode_fn


static func has_boot_snapshot() -> bool:
	return not _boot.is_empty()


## Restores every autoload global in the reset list to its boot value (objects as fresh instances).
static func reset_shared_state() -> void:
	if _boot.is_empty():
		take_boot_snapshot()
	for autoload_name: StringName in _boot:
		var node: Node = _autoload(autoload_name)
		var values: Dictionary = _boot[autoload_name]
		for field: StringName in values:
			node.set(field, values[field])
	var game: Node = _autoload(&"Game")
	game.set(&"run", RunState.new())
	game.set(&"stats", RunStats.new())
	game.set(&"ending_summary", {})
	game.set(&"practice_loadouts_offered", [] as Array[int])
	var sim_clock: Node = _autoload(&"SimClock")
	sim_clock.set(&"recorder", null)
	clear_hitstop()
	Fullscreen.get_mode_fn = _boot_get_mode_fn
	Fullscreen.set_mode_fn = _boot_set_mode_fn
	AudioManager.set_master_muted(SaveService.muted)
	reset_count += 1


## Clears the pending and running hit-stop and the swallowed-press flag through SimClock's own seam
## (item 299: no test writes SimClock's private fields).
static func clear_hitstop() -> void:
	SimClock.reset_for_tests()


static func _autoload(autoload_name: StringName) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(NodePath(String(autoload_name)))


## Story 9.5 (item 108): connects `callable` to an EventBus signal and records the link in `links`
## (a suite member), so the suite's after_each can drop it with disconnect_bus even when the test
## stopped early on a script error.
static func connect_bus(links: Array, sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	links.append([sig, callable])


## Disconnects every link recorded by connect_bus that is still connected, then clears the list.
static func disconnect_bus(links: Array) -> void:
	for link: Array in links:
		var sig: Signal = link[0]
		if sig.is_connected(link[1]):
			sig.disconnect(link[1])
	links.clear()

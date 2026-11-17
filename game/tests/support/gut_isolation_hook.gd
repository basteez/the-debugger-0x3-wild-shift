extends GutHookScript
## Story 9.5 (D-S95-3): GUT pre-run hook, wired by game/.gutconfig.json (pre_run_script).
## 1. Takes the boot snapshot of the shared autoload state before any suite runs.
## 2. Resets that state at the start of every suite (gut.start_script). Coordinator call: the reset
##    is per suite only, never per test, so state a suite sets up in before_all survives its tests.
## 3. Optional order for isolation checks, from the WILDSHIFT_GUT_ORDER environment variable:
##    unset / "ci" = collection order (CI), "reverse", or "shuffle:<int seed>" (seed printed).

const ORDER_ENV := "WILDSHIFT_GUT_ORDER"


func run() -> void:
	TestIsolation.take_boot_snapshot()
	gut.start_script.connect(func(_collected_script: Variant) -> void: TestIsolation.reset_shared_state())
	var order: String = OS.get_environment(ORDER_ENV).strip_edges()
	var scripts: Array = gut.get_test_collector().scripts
	if order == "" or order == "ci":
		order = "ci"
	elif order == "reverse":
		scripts.reverse()
	elif order.begins_with("shuffle:") and order.trim_prefix("shuffle:").is_valid_int():
		var seed_value: int = order.trim_prefix("shuffle:").to_int()
		seed(seed_value)
		scripts.shuffle()
		randomize() # the seed only orders the suites; do not make global RNG order-correlated
		order = "shuffle seed %d" % seed_value
	else:
		gut.logger.error("%s=%s is not ci, reverse or shuffle:<int>" % [ORDER_ENV, order])
		abort()
		return
	gut.logger.log("Wild Shift isolation hook: per-suite reset on, GUT order: %s (%d scripts)" % [order, scripts.size()])

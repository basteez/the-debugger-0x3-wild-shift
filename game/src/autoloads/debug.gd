extends Node
## Debug tooling switch (Story 1.6 DC3): the single gate for F1-F5, the F9 grid and the smoke gates.
## On in debug builds, or in any build whose URL query has a `debug` key that is not off.

## Debug builds start open; _ready widens it with the URL query once the JS bridge is up.
var enabled: bool = OS.is_debug_build()


func _ready() -> void:
	# Read once, after the JavaScript bridge is up (not as a field initialiser).
	enabled = gate_enabled(OS.is_debug_build(), UrlQuery.web_search())


## Pure gate: debug builds, or a `?debug` query (UrlQuery.has_debug rules).
static func gate_enabled(is_debug_build: bool, search: String) -> bool:
	return is_debug_build or UrlQuery.has_debug(search)

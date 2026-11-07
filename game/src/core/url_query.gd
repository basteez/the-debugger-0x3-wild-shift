class_name UrlQuery
extends RefCounted
## Pure helpers for the web page's query string (`location.search`). Story 1.5 shares them
## between Main's smoke gates and the HUD's F9 debug gate; the 1.6 Debug helper can reuse them.


## True when the query has a bare or valued `debug` key that is not `0` or `false`.
static func has_debug(search: String) -> bool:
	var found: bool = false
	for pair: String in _pairs(search):
		if pair.get_slice("=", 0) == "debug":
			var val: String = pair.get_slice("=", 1) if pair.contains("=") else ""
			found = val != "0" and val != "false"
	return found


## True when the query has exactly `smoke=<value>`.
static func has_smoke(search: String, value: String) -> bool:
	for pair: String in _pairs(search):
		if pair.get_slice("=", 0) == "smoke" and pair.get_slice_count("=") == 2 and pair.get_slice("=", 1) == value:
			return true
	return false


## location.search on web, "" anywhere else or if the bridge returns nothing usable.
static func web_search() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval("window.location.search", true)
	return value if value is String else ""


static func _pairs(search: String) -> PackedStringArray:
	return search.trim_prefix("?").split("&", false)

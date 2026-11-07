class_name UrlQuery
extends RefCounted
## Pure helpers for the web page's query string (`location.search`). Story 1.5 shares them
## between Main's smoke gates and the HUD's F9 debug gate; the 1.6 Debug helper can reuse them.


## True when the query has a bare or valued `debug` key that is not off (`0`, `false`, `off`, `no`,
## empty value, any case, percent-decoded). Duplicate keys: the last one wins.
static func has_debug(search: String) -> bool:
	var found: bool = false
	for pair: String in _pairs(search):
		var parts: PackedStringArray = pair.split("=", true, 1)
		if parts[0].uri_decode() == "debug":
			var val: String = parts[1].uri_decode().to_lower() if parts.size() > 1 else ""
			found = not (parts.size() > 1 and val in ["", "0", "false", "off", "no"])
	return found


## True when the query has exactly `smoke=<value>` (percent-decoded; the last `smoke` key wins).
static func has_smoke(search: String, value: String) -> bool:
	var found: bool = false
	for pair: String in _pairs(search):
		var parts: PackedStringArray = pair.split("=", true, 1)
		if parts[0].uri_decode() == "smoke":
			found = parts.size() == 2 and parts[1].uri_decode() == value
	return found


## location.search on web. Off the web, debug builds read the user args after `--` instead
## (`godot -- debug smoke=arena` gives `?debug&smoke=arena`), so the debug views open on desktop.
static func web_search() -> String:
	if not OS.has_feature("web"):
		if OS.is_debug_build():
			var args: PackedStringArray = OS.get_cmdline_user_args()
			return "?" + "&".join(args) if not args.is_empty() else ""
		return ""
	var value: Variant = JavaScriptBridge.eval("window.location.search", true)
	return value if value is String else ""


static func _pairs(search: String) -> PackedStringArray:
	return search.trim_prefix("?").split("&", false)

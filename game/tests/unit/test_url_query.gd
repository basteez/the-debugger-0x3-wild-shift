extends GutTest


func test_debug_values() -> void:
	assert_true(UrlQuery.has_debug("?debug"))
	assert_true(UrlQuery.has_debug("?debug=1"))
	assert_false(UrlQuery.has_debug("?debug="))
	assert_false(UrlQuery.has_debug("?debug=0"))
	assert_false(UrlQuery.has_debug("?debug=FALSE"))
	assert_false(UrlQuery.has_debug("?debug=Off"))
	assert_false(UrlQuery.has_debug("?debug=%30"))
	assert_false(UrlQuery.has_debug(""))


func test_duplicate_keys_last_wins() -> void:
	assert_false(UrlQuery.has_debug("?debug&debug=0"))
	assert_true(UrlQuery.has_debug("?debug=0&debug"))
	assert_true(UrlQuery.has_smoke("?smoke=x&smoke=arena", "arena"))
	assert_false(UrlQuery.has_smoke("?smoke=arena&smoke=x", "arena"))


func test_smoke_exact() -> void:
	assert_true(UrlQuery.has_smoke("?smoke=arena", "arena"))
	assert_false(UrlQuery.has_smoke("?smoke=arena=1", "arena"))
	assert_false(UrlQuery.has_smoke("?smoke", "arena"))

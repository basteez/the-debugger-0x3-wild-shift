extends GutTest
## Story 4.1 (F1, AC2, D-S41-1): EchoMemory storage rules. Pure.

var _mem: EchoMemory


func before_each() -> void:
	_mem = EchoMemory.new()


func test_starts_empty() -> void:
	assert_false(_mem.has_last())
	assert_null(_mem.last)


func test_solo_actions_are_stored_by_reference() -> void:
	_mem.remember(Defs.SLASH_1)
	assert_true(_mem.has_last())
	assert_same(_mem.last, Defs.SLASH_1, "the exact def, not a copy")
	_mem.remember(Defs.DASH)
	assert_same(_mem.last, Defs.DASH, "the last one wins")


func test_chain_hits_are_stored() -> void:
	_mem.remember(Defs.SLASH_2)
	assert_same(_mem.last, Defs.SLASH_2)
	_mem.remember(Defs.SLASH_3)
	assert_same(_mem.last, Defs.SLASH_3)


func test_echo_and_nop_and_null_never_change_memory() -> void:
	_mem.remember(Defs.SLASH_3)
	_mem.remember(Defs.ECHO)
	assert_same(_mem.last, Defs.SLASH_3, "Echo is never stored")
	_mem.remember(Defs.NOP)
	assert_same(_mem.last, Defs.SLASH_3, "NOP (echoable = false) is never stored")
	_mem.remember(null)
	assert_same(_mem.last, Defs.SLASH_3)


func test_an_echo_def_is_never_stored_even_if_marked_echoable() -> void:
	var odd := ActionDef.new()
	odd.echo_action = true
	odd.echoable = true
	_mem.remember(odd)
	assert_false(_mem.has_last())


func test_clear_empties_memory() -> void:
	_mem.remember(Defs.SLASH_1)
	_mem.clear()
	assert_false(_mem.has_last())
	assert_null(_mem.last)

extends GutTest
## Story 2.1 AC3: 8-frame lifetime (inclusive), single consumption, oldest first, silent expiry.

var _buf: InputBuffer


func before_each() -> void:
	_buf = InputBuffer.new()


func test_lifetime_is_eight_frames() -> void:
	assert_eq(InputBuffer.PRESS_LIFETIME_FRAMES, 8)


func test_press_available_at_f_plus_8() -> void:
	_buf.push(&"action_1", 10)
	assert_true(_buf.consume(&"action_1", 18))


func test_press_expired_at_f_plus_9() -> void:
	_buf.push(&"action_1", 10)
	assert_false(_buf.consume(&"action_1", 19))


func test_press_available_on_its_own_frame() -> void:
	_buf.push(&"action_1", 10)
	assert_true(_buf.consume(&"action_1", 10))


func test_press_not_available_before_its_frame() -> void:
	_buf.push(&"action_1", 10)
	assert_false(_buf.consume(&"action_1", 9))


func test_press_consumed_at_most_once() -> void:
	_buf.push(&"action_1", 10)
	assert_true(_buf.consume(&"action_1", 11))
	assert_false(_buf.consume(&"action_1", 11))
	assert_false(_buf.consume(&"action_1", 12))


func test_other_action_not_consumed() -> void:
	_buf.push(&"action_1", 10)
	assert_false(_buf.consume(&"action_2", 10))
	assert_true(_buf.consume(&"action_1", 10))


func test_two_presses_consumed_oldest_first() -> void:
	_buf.push(&"action_1", 10)
	_buf.push(&"action_1", 14)
	assert_true(_buf.consume(&"action_1", 15)) # takes the f=10 press
	# f=10 would be expired at 19, but the f=14 press is still live through 22.
	assert_true(_buf.consume(&"action_1", 22))
	assert_false(_buf.consume(&"action_1", 22))


func test_oldest_first_leaves_newest_live() -> void:
	_buf.push(&"shift_left", 0)
	_buf.push(&"shift_left", 5)
	assert_true(_buf.consume(&"shift_left", 8))
	# If the newest had been taken, the f=0 press would be expired at 13 and nothing left.
	assert_true(_buf.consume(&"shift_left", 13))


func test_expired_press_skipped_for_live_one() -> void:
	_buf.push(&"action_2", 0)
	_buf.push(&"action_2", 6)
	assert_true(_buf.consume(&"action_2", 12)) # f=0 expired, f=6 live
	assert_false(_buf.consume(&"action_2", 12))


func test_clear_drops_everything() -> void:
	_buf.push(&"action_1", 0)
	_buf.push(&"action_2", 0)
	_buf.clear()
	assert_eq(_buf.size(), 0)
	assert_false(_buf.consume(&"action_1", 0))


func test_push_prunes_expired_and_consumed() -> void:
	_buf.push(&"action_1", 0)
	_buf.push(&"action_2", 5)
	assert_true(_buf.consume(&"action_2", 5))
	_buf.push(&"watch", 9) # f=0 expired (9 > 8), f=5 consumed: both pruned
	assert_eq(_buf.size(), 1)
	assert_true(_buf.consume(&"watch", 9))


func test_same_frame_presses_keep_push_order() -> void:
	_buf.push(&"action_1", 3)
	_buf.push(&"action_1", 3)
	assert_true(_buf.consume(&"action_1", 3))
	assert_true(_buf.consume(&"action_1", 3))
	assert_false(_buf.consume(&"action_1", 3))

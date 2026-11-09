class_name CameraShake
extends RefCounted
## Screen shake schedules (Story 2.8 AC4, Story 2.9 AC1, GDD "Hit Feedback"). Pure and static: the
## offset for the frames left in a shake, alternating on the x axis. The combo hit is 2 px for 6
## frames (the defaults); the player hit is 3 px for 4 frames (D-S29-6).

const SHAKE_PX := 2
const SHAKE_FRAMES := 6
const PLAYER_HIT_PX := 3
const PLAYER_HIT_FRAMES := 4


## Camera offset with `frames_left` frames of shake still to show: +px on even counts, -px on odd
## ones, for 1..frames; zero otherwise. Defaults are the combo schedule.
static func offset_for(frames_left: int, px: int = SHAKE_PX, frames: int = SHAKE_FRAMES) -> Vector2:
	if frames_left < 1 or frames_left > frames:
		return Vector2.ZERO
	return Vector2(px if frames_left % 2 == 0 else -px, 0)

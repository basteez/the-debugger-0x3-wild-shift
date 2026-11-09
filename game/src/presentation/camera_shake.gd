class_name CameraShake
extends RefCounted
## Combo-hit screen shake schedule (Story 2.8 AC4, GDD "Hit Feedback": 2 px for 6 frames). Pure and
## static: the offset for the frames left in the shake, alternating on the x axis.

const SHAKE_PX := 2
const SHAKE_FRAMES := 6


## Camera offset with `frames_left` frames of shake still to show: +SHAKE_PX on even counts,
## -SHAKE_PX on odd ones, for 1..SHAKE_FRAMES; zero otherwise.
static func offset_for(frames_left: int) -> Vector2:
	if frames_left < 1 or frames_left > SHAKE_FRAMES:
		return Vector2.ZERO
	return Vector2(SHAKE_PX if frames_left % 2 == 0 else -SHAKE_PX, 0)

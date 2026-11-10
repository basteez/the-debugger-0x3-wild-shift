class_name TypewriterReveal
extends RefCounted
## The duck bubble's typewriter reveal (Story 3.6, D-S36-5, D-S36-11): the only holder of the
## revealed character count. In 3.6 a timer drives it through advance(); Story 3.7 calls
## set_revealed() from the voice and the timer stops driving it. Presentation only, no RNG.

const CHARS_PER_S := 30.0
const EPSILON := 1e-6

var length: int = 0
var chars_per_second: float = CHARS_PER_S
var elapsed_s: float = 0.0
var revealed: int = 0
## True once set_revealed() took over (the voice drives the count, the timer no longer does).
var driven_externally: bool = false


## Starts a new line of `p_length` characters, nothing revealed.
func set_line(p_length: int) -> void:
	length = maxi(p_length, 0)
	elapsed_s = 0.0
	revealed = 0
	driven_externally = false


## Advances the timer by `delta_s` seconds (ignored once driven externally).
func advance(delta_s: float) -> void:
	if driven_externally:
		return
	elapsed_s += maxf(delta_s, 0.0)
	revealed = visible_chars(elapsed_s, chars_per_second, length)


## The 3.7 seam: the voice sets the count directly; clamped to [0, length].
func set_revealed(n: int) -> void:
	driven_externally = true
	revealed = clampi(n, 0, length)


## Hands the count back to the timer from where it is (Story 3.7: a voice line was cut, D-S37-7).
func release() -> void:
	driven_externally = false
	elapsed_s = float(revealed) / chars_per_second if chars_per_second > 0.0 else 0.0


func is_done() -> bool:
	return revealed >= length


## min(length, floor(elapsed_s * cps)), never negative. A 1e-6 epsilon absorbs float error so a
## line is fully shown at exactly length / cps seconds. Pure.
static func visible_chars(p_elapsed_s: float, cps: float, p_length: int) -> int:
	return clampi(floori(p_elapsed_s * cps + EPSILON), 0, maxi(p_length, 0))

class_name BreakpointReadout
extends Node2D
## The Breakpoint cooldown readout (Story 4.3, AC 10, D-S43-13): `brk READY` at cooldown 0, else
## `brk <s>s` with s = ceil(frames / 60), in ink, on the last interior row of the REGISTER box (the
## GDD HUD Layout puts `brk` under the cooldown rows, D-047). Empty when the module is off (no skill
## injected) or the fight is not unlocked. Presentation only (AD-05): reads the skill through the
## generic FightSkill face, never writes it. Main injects `skill`.

const SCALE := 1
const COL := 1
const ROW := 20
const LABEL := "brk"
const READY := "READY"

## Injected by Main (read only). Null = Breakpoint is cut, nothing is drawn.
var skill: FightSkill
## The text drawn last; redraws only when it changes.
var _shown: String = ""


func _process(_delta: float) -> void:
	var text: String = current_text()
	if text != _shown:
		_shown = text
		queue_redraw()


## The readout for the injected skill; empty without one or while locked.
func current_text() -> String:
	if skill == null or not skill.is_unlocked():
		return ""
	return text_for(skill.cooldown_left_frames())


## `brk READY` at 0 frames, else `brk <ceil(frames / 60)>s`. Pure.
static func text_for(cooldown_frames: int) -> String:
	if cooldown_frames <= 0:
		return "%s %s" % [LABEL, READY]
	return "%s %ds" % [LABEL, ceili(float(cooldown_frames) / float(Const.SIM_HZ))]


func _draw() -> void:
	var text: String = current_text()
	if text != "":
		GlyphFont.draw_cell(self, Vector2i(COL, ROW), text, Palette.INK, SCALE)

extends Node
## Game flow state machine. Only Game changes flow_state.

enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }

var flow_state: FlowState = FlowState.TITLE
## Sim frame of the first title input: start of the 30-s first-shift clock. -1 before it.
var first_input_frame: int = -1


## Title press-to-start (FR47). Valid only from TITLE.
func start_run_from_title(frame: int) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "start_run_from_title ignored outside TITLE")
		return
	first_input_frame = frame
	Log.info(&"flow", "title -> intro at f=%d" % frame)
	_set_flow_state(FlowState.INTRO)


## The title input never counts as an Intro skip (D-040, D-048). Story 1.6 uses this.
func can_skip_intro(frame: int) -> bool:
	return first_input_frame >= 0 and frame > first_input_frame


func _set_flow_state(to: FlowState) -> void:
	var from: FlowState = flow_state
	flow_state = to
	EventBus.flow_state_changed.emit(from, to)

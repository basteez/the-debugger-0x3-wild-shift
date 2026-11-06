extends Node
## Game flow state machine. Only Game changes flow_state.

enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }

var flow_state: FlowState = FlowState.TITLE

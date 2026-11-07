extends Node
## Fixed 60 Hz simulation clock. While paused, the world does not advance.

var sim_frame: int = 0
var paused: bool = false


func _physics_process(_delta: float) -> void:
	if paused:
		return
	sim_frame += 1

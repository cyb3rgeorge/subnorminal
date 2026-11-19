extends Node2D

var audioPlaying: bool = false

func _ready():
	Global.anomaly = "Unknown"
	$Control/Counter.text = ("Norminals: " + str(Global.norminals) + "\nSubnorminals: " +str(Global.subnorminals))
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(Global.SIMULATOR)
	

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not audioPlaying:
			$raptorRoar.play()
			audioPlaying = true
		elif audioPlaying:
			$raptorRoar.stop()
			audioPlaying = false

func _on_raptor_roar_finished() -> void:
	audioPlaying = false

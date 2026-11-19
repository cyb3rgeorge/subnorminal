extends Node2D

var audioPlaying: bool = false

func _ready():
	Global.anomaly = "Unknown"
	$Control/Counter.text = ("Norminals: " + str(Global.norminals) + "\nSubnorminals: " +str(Global.subnorminals))
	
	if Global.audio:
		$menuMusic.play()
	else:
		$menuMusic.stop()
		$raptorRoar.stop()
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(Global.SIMULATOR)
	

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not audioPlaying and Global.audio:
			$raptorRoar.play()
			audioPlaying = true
		elif audioPlaying:
			$raptorRoar.stop()
			audioPlaying = false

func _on_raptor_roar_finished() -> void:
	audioPlaying = false


func _on_mute_pressed() -> void:
	if Global.audio:
		Global.audio = false
		$Control/Mute.text = "Unmute All Audio"
		_ready()
	else:
		Global.audio = true
		$Control/Mute.text = "Mute All Sound"
		_ready()

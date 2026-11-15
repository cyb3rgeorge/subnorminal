extends Node2D

func _ready():
	$CanvasLayer/Label.text = "Failures: " + str(Global.failures)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://physics.tscn")

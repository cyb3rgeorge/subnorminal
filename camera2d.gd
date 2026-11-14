extends Camera2D

@export var zoom_speed : float = 0.1
@export var max_zoom : float = 3.0
@export var min_zoom : float = 0.1

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_speed, zoom_speed)
			zoom.x = clamp(zoom.x, min_zoom, max_zoom)
			zoom.y = clamp(zoom.y, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_speed, zoom_speed)
			zoom.x = clamp(zoom.x, min_zoom, max_zoom)
			zoom.y = clamp(zoom.y, min_zoom, max_zoom)

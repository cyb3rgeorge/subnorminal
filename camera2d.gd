
extends Camera2D

# Zoom Settings
@export var zoom_speed: float = 0.1
@export var keyboard_zoom_speed: float = 1.0
@export var trackpad_zoom_speed: float = 0.05
@export var zoom_smoothing: float = 10.0
@export var max_zoom: float = 3.0
@export var min_zoom: float = 0.1

var target_zoom: float


func _ready() -> void:
	target_zoom = clampf(zoom.x, min_zoom, max_zoom)


func _unhandled_input(event: InputEvent) -> void:
	# Trackpad Two-Finger Scroll
	if event is InputEventPanGesture:
		change_zoom(-event.delta.y * trackpad_zoom_speed)

	# Mouse Wheel
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				change_zoom(zoom_speed * event.factor)
			MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-zoom_speed * event.factor)


func _process(delta: float) -> void:
	# Keyboard Zoom
	var direction = Input.get_axis("zoomOut", "zoomIn")

	if direction != 0.0:
		change_zoom(direction * keyboard_zoom_speed * delta)

	# Smooth Zoom
	var smoothing = 1.0 - exp(-zoom_smoothing * delta)
	zoom = zoom.lerp(Vector2.ONE * target_zoom, smoothing)


func change_zoom(amount: float) -> void:
	target_zoom = clampf(
		target_zoom + amount,
		min_zoom,
		max_zoom
	)

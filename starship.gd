
extends RigidBody2D
class_name Starship

# Signals
signal propTelemetry
signal throttleTelemetry

# Ship configuration
@export var maxProp: int = 2000
@export var throttle: int = 0
@export var engines: int = 0
@export var dryMass: float = 1000.0

# Constants
const ALTITUDE_CORRECTION := 1014.0
const TARGET_OFFSET_CORRECTION := 1014.0
const DRAG_COEFFICIENT := 441.0
const FUEL_BURN_RATE := 0.6
const TELEMETRY_INTERVAL := 0.1

const FAILURE_SCENE := "res://failure.tscn"
const SUCCESS_SCENE := "res://success.tscn"

# Failure thresholds, indexed by failure count ranges
const FAILURE_STAGES := [3, 5, 8, 11, 13, 16]

# Physics
var power: float = 30000.0
var angularPower: float = 500.0

var prop: float = 0.0
var thrust: Vector2 = Vector2.ZERO
var rotationalDirection: float = 0.0

# Internal state
var rng := RandomNumberGenerator.new()
var _finished: bool = false
var _last_engines: int = -1
var _last_flame_state: int = -1
var _telemetry_elapsed: float = 0.0

# Cached nodes
@onready var failure_start_timer: Timer = $"../FailureStartTimer"
@onready var failure_timer: Timer = $"../FailureTimer"
@onready var end_timer: Timer = $"../EndTimer"
@onready var win_end_timer: Timer = $"../WinEndTimer"

@onready var raptor_roar = $"../raptorRoar"
@onready var flame_low: CanvasItem = $RaptorThrottle1
@onready var flame_high: CanvasItem = $RaptorThrottle2

@onready var engine_indicators := [
	$"../Telemetry/0Engines",
	$"../Telemetry/1Engines",
	$"../Telemetry/2Engines",
	$"../Telemetry/3Engines"
]

@onready var altitude_label = $"../Telemetry/Control/Altimeter"
@onready var offset_label = $"../Telemetry/Control/TargetOffset"
@onready var velocity_label = $"../Telemetry/Control/Velocity"
@onready var speed_label = $"../Telemetry/Control/Speed"
@onready var drag_label = $"../Telemetry/Control/DragForce"


func _ready() -> void:
	throttle = 0
	prop = float(maxi(maxProp, 0))
	mass = dryMass

	failure_start_timer.one_shot = true
	failure_timer.one_shot = true

	_update_engine_indicators()
	_update_effects(false)
	_update_telemetry(0.0)

	failure_start_timer.start()


# --------------------------------------------------
# INPUT
# --------------------------------------------------

func get_input() -> void:
	rotationalDirection = Input.get_axis(
		"rotateLeft", "rotateRight"
	)

	# Engine selection
	if Input.is_action_pressed("EngineCutoff"):
		engines = 0
	if Input.is_action_pressed("1Engine"):
		engines = 1
	if Input.is_action_pressed("2Engines"):
		engines = 2
	if Input.is_action_pressed("3Engines"):
		engines = 3

	# Only update engine UI when the count changes
	if engines != _last_engines:
		_update_engine_indicators()

	# Throttle input
	var throttle_change := 0

	if Input.is_action_pressed("throttleUp"):
		throttle_change += 1
	if Input.is_action_pressed("throttleDown"):
		throttle_change -= 1

	var new_throttle := clampi(
		throttle + throttle_change, 0, 100
	)

	if new_throttle != throttle:
		throttle = new_throttle
		throttleTelemetry.emit()


# --------------------------------------------------
# PHYSICS
# --------------------------------------------------

func _physics_process(delta: float) -> void:
	if _finished:
		return

	get_input()

	# Calculate engine thrust
	var engine_power := engines * throttle
	var burning := engine_power > 0 and prop > 0.0

	thrust = Vector2.ZERO

	if burning:
		thrust = -global_transform.y * engine_power * power

		# Fuel consumption, independent of physics tick rate
		prop = maxf(
			0.0,
			prop - engine_power * FUEL_BURN_RATE * delta
		)

		propTelemetry.emit()

	# Vertical aerodynamic drag
	var vertical_speed := linear_velocity.y
	var drag_y := (
		-DRAG_COEFFICIENT
		* absf(cos(global_rotation))
		* vertical_speed
		* absf(vertical_speed)
	)

	# Combine thrust and drag into one force
	constant_force = thrust + Vector2(0.0, drag_y)

	# Rotation
	constant_torque = (
		rotationalDirection
		* angularPower
		* (engines + 1)
	)

	# Engine effects
	_update_effects(burning and prop > 0.0)

	# Update telemetry at 10 Hz instead of every physics tick
	_telemetry_elapsed += delta

	if _telemetry_elapsed >= TELEMETRY_INTERVAL:
		_telemetry_elapsed = 0.0
		_update_telemetry(absf(drag_y))


# --------------------------------------------------
# ENGINE VISUALS AND AUDIO
# --------------------------------------------------

func _update_engine_indicators() -> void:
	for i in range(engine_indicators.size()):
		engine_indicators[i].visible = (engines == i)

	_last_engines = engines


func _update_effects(burning: bool) -> void:
	var flame_state := 0

	if burning:
		flame_state = 2 if throttle > 50 else 1

	# Only change visibility when necessary
	if flame_state != _last_flame_state:
		flame_low.visible = (flame_state == 1)
		flame_high.visible = (flame_state == 2)
		_last_flame_state = flame_state

	# Audio
	if burning:
		if not raptor_roar.is_playing():
			raptor_roar.play()
	elif raptor_roar.is_playing():
		raptor_roar.stop()


# --------------------------------------------------
# TELEMETRY
# --------------------------------------------------

func _update_telemetry(drag_magnitude: float) -> void:
	var pos := global_position
	var vel := linear_velocity

	altitude_label.text = "Altitude: %d" % roundi(
		(ALTITUDE_CORRECTION - pos.y) / 3.0
	)

	offset_label.text = "Target Offset: %d" % roundi(
		(pos.x - TARGET_OFFSET_CORRECTION) / 3.0
	)

	velocity_label.text = "Velocity: %s" % str(
		(vel / 3.0).round()
	)

	speed_label.text = "Speed: %d" % roundi(
		vel.length() / 3.0
	)

	drag_label.text = "Drag Force: %d" % roundi(
		drag_magnitude / 4.0
	)


# --------------------------------------------------
# RANDOM FAILURES
# --------------------------------------------------

func _on_failure_start_timer_timeout() -> void:
	if not _finished:
		failure_timer.start()


func _on_failure_timer_timeout() -> void:
	if _finished:
		return

	# Increase threshold as failures accumulate
	var threshold := 21.0

	for stage in FAILURE_STAGES:
		if Global.failures >= stage:
			threshold += 3.0
		else:
			break

	var failure_number := rng.randf_range(0.0, 42.0)

	if failure_number > threshold:
		_finished = true
		Global.failures += 1
		get_tree().change_scene_to_file(FAILURE_SCENE)
	else:
		failure_timer.start()


# --------------------------------------------------
# COLLISIONS AND LANDING
# --------------------------------------------------

func _finish(won: bool) -> void:
	# Prevent multiple collision signals triggering
	if _finished:
		return

	_finished = true

	# Stop propulsion and freeze the ship
	thrust = Vector2.ZERO
	constant_force = Vector2.ZERO
	constant_torque = 0.0

	_update_effects(false)
	failure_timer.stop()

	set_deferred("freeze", true)

	# Preserve original counter behavior
	Global.failures += 1

	if won:
		win_end_timer.start()
	else:
		end_timer.start()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false)


func _on_tower_area_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false)


func _on_chopsticks_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("fwd"):
		_finish(true)


# --------------------------------------------------
# SCENE TRANSITIONS
# --------------------------------------------------

func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file(FAILURE_SCENE)


func _on_win_end_timer_timeout() -> void:
	get_tree().change_scene_to_file(SUCCESS_SCENE)

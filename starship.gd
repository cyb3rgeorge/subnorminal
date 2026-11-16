extends RigidBody2D
class_name Starship

# SIGNALS
signal propTelemetry
signal throttleTelemetry

# SHIP CONFIGURATION
@export var maxProp: int = 2000
@export var throttle: int = 0
@export var engines: int = 0
@export var dryMass: float = 1000.0

# Print the runtime setting and the cause of each win/loss.
@export var debugFailures: bool = true

# false = no random failures. Collisions can still cause a loss.
@export var enableRandomFailures: bool = false:
	set(value):
		if enableRandomFailures == value:
			return

		enableRandomFailures = value

		# @onready references are unavailable during initialization.
		if not is_node_ready() or _finished:
			return

		failure_start_timer.stop()
		failure_timer.stop()

		# Enabling during flight starts a fresh cooldown.
		if enableRandomFailures:
			failure_start_timer.start()

# CONSTANTS
const DRAG_COEFFICIENT: float = 441.0
const TELEMETRY_INTERVAL: float = 0.1
const FAILURE_CHECK_INTERVAL: float = 5.0

# Percentage points per second; matches the old rate at 60 ticks/s.
const THROTTLE_CHANGE_RATE: float = 60.0

# Propellant units per second, per engine, at 100% throttle.
const FUEL_BURN_RATE: float = 60.0

const FAILURE_SCENE: String = "res://failure.tscn"
const SUCCESS_SCENE: String = "res://success.tscn"
const FAILURE_STAGES := [3, 5, 8, 11, 13, 16]

# WORLD SCALE
const METERS_PER_PIXEL: float = 60.0 / 158.0
const SHIP_HALF_HEIGHT: float = 79.0
const GROUND_Y: float = 1059.0
const TARGET_X: float = 1014.0

# PHYSICS
var power: float = 30000.0
var angularPower: float = 500.0
var prop: float = 0.0
var thrust: Vector2 = Vector2.ZERO
var rotationalDirection: float = 0.0

# INTERNAL STATE
var rng := RandomNumberGenerator.new()
var _finished: bool = false
var _won: bool = false
var _changing_scene: bool = false
var _throttle_value: float = 0.0
var _last_engines: int = -1
var _last_flame_state: int = -1
var _telemetry_elapsed: float = 0.0

# TIMERS - these names must match your scene tree exactly.
@onready var failure_start_timer: Timer = $"../FailureStartTimer"
@onready var failure_timer: Timer = $"../FailureTimer"
@onready var end_timer: Timer = $"../EndTimer"
@onready var win_end_timer: Timer = $"../WinEndTimer"

# EFFECTS
@onready var raptor_roar = $"../raptorRoar"
@onready var flame_low: CanvasItem = $RaptorThrottle1
@onready var flame_high: CanvasItem = $RaptorThrottle2

# TELEMETRY NODES
@onready var engine_indicators: Array[CanvasItem] = [
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


# INITIALIZATION
func _ready() -> void:
	throttle = 0
	_throttle_value = 0.0
	engines = clampi(engines, 0, 3)
	prop = float(maxi(maxProp, 0))
	mass = maxf(dryMass, 0.001)

	_setup_timers()
	_update_engine_indicators()
	_update_effects(false)
	_update_telemetry(0.0)

	if enableRandomFailures:
		failure_start_timer.start()

	if debugFailures:
		print(
			"Starship: ", get_path(),
			" | enableRandomFailures=", enableRandomFailures
		)


# TIMER CONFIGURATION
func _setup_timers() -> void:
	var timers: Array[Timer] = [
		failure_start_timer, failure_timer, end_timer, win_end_timer
	]

	for timer in timers:
		timer.autostart = false
		timer.stop()
		timer.paused = false

	# Keep the cooldown duration configured in the Inspector.
	failure_start_timer.one_shot = true

	# Repeat every five seconds after the cooldown.
	failure_timer.wait_time = FAILURE_CHECK_INTERVAL
	failure_timer.one_shot = false

	# Keep both end-screen delays configured in the Inspector.
	end_timer.one_shot = true
	win_end_timer.one_shot = true

	# Add missing connections without duplicating existing ones.
	_connect_timer(failure_start_timer, _on_failure_start_timer_timeout)
	_connect_timer(failure_timer, _on_failure_timer_timeout)
	_connect_timer(end_timer, _on_end_timer_timeout)
	_connect_timer(win_end_timer, _on_win_end_timer_timeout)


func _connect_timer(timer: Timer, callback: Callable) -> void:
	if not timer.timeout.is_connected(callback):
		timer.timeout.connect(callback)


# INPUT
func get_input(delta: float) -> void:
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")

	# Preserve the original priority when multiple keys are held.
	if Input.is_action_pressed("EngineCutoff"):
		engines = 0
	if Input.is_action_pressed("1Engine"):
		engines = 1
	if Input.is_action_pressed("2Engines"):
		engines = 2
	if Input.is_action_pressed("3Engines"):
		engines = 3

	engines = clampi(engines, 0, 3)

	if engines != _last_engines:
		_update_engine_indicators()

	# Respect throttle changes made by another script.
	if roundi(_throttle_value) != throttle:
		_throttle_value = float(clampi(throttle, 0, 100))

	var throttle_input: float = 0.0
	if Input.is_action_pressed("throttleUp"):
		throttle_input += 1.0
	if Input.is_action_pressed("throttleDown"):
		throttle_input -= 1.0

	_throttle_value = clampf(
		_throttle_value + throttle_input * THROTTLE_CHANGE_RATE * delta,
		0.0,
		100.0
	)

	var new_throttle := roundi(_throttle_value)
	if new_throttle != throttle:
		throttle = new_throttle
		throttleTelemetry.emit()


# PHYSICS

func _physics_process(delta: float) -> void:
	if _finished:
		return

	get_input(delta)

	# Original engine thrust calculation
	var engine_power := engines * throttle
	var burning := engine_power > 0 and prop > 0.0

	thrust = Vector2.ZERO

	if burning:
		# Restore original thrust behavior
		thrust -= engines * throttle * transform.x * power

		# Fuel consumption based on throttle percentage
		var throttle_fraction := throttle / 100.0

		prop = maxf(
			0.0,
			prop - engines * throttle_fraction * FUEL_BURN_RATE * delta
		)

		propTelemetry.emit()

	# Original aerodynamic drag calculation
	var vertical_speed := linear_velocity.y

	var drag_force := (
		absf(cos(rotation))
		* DRAG_COEFFICIENT
		* vertical_speed ** 2
	)

	var drag_direction := -signf(vertical_speed)

	# Apply thrust and drag
	constant_force = thrust
	apply_central_force(
		Vector2(0.0, drag_force * drag_direction)
	)

	# Original rotational torque
	constant_torque = (
		rotationalDirection
		* angularPower
		* (engines + 1)
	)

	# Engine effects
	_update_effects(burning and prop > 0.0)

	# Telemetry
	_telemetry_elapsed += delta

	if _telemetry_elapsed >= TELEMETRY_INTERVAL:
		_telemetry_elapsed = 0.0
		_update_telemetry(drag_force)



# ENGINE VISUALS AND AUDIO
func _update_engine_indicators() -> void:
	for i in range(engine_indicators.size()):
		engine_indicators[i].visible = engines == i

	_last_engines = engines


func _update_effects(burning: bool) -> void:
	var flame_state := 0
	if burning:
		flame_state = 2 if throttle > 50 else 1

	if flame_state != _last_flame_state:
		flame_low.visible = flame_state == 1
		flame_high.visible = flame_state == 2
		_last_flame_state = flame_state

	if burning:
		if not raptor_roar.is_playing():
			raptor_roar.play()
	elif raptor_roar.is_playing():
		raptor_roar.stop()


# TELEMETRY
func _update_telemetry(drag_magnitude: float) -> void:
	var pos := global_position
	var velocity_mps := linear_velocity * METERS_PER_PIXEL

	# Assumes a centred, upright ship, 158 world units tall.
	# This remains an approximation when the ship rotates.
	var ship_bottom_y := pos.y + SHIP_HALF_HEIGHT
	var altitude_m := maxf(
		0.0,
		(GROUND_Y - ship_bottom_y) * METERS_PER_PIXEL
	)

	var offset_m := (pos.x - TARGET_X) * METERS_PER_PIXEL
	var speed_mps := velocity_mps.length()

	# Assumes body mass is in kg and time is in seconds.
	# Unit conversion does not calibrate the aerodynamic model.
	var drag_kn := drag_magnitude * METERS_PER_PIXEL / 1000.0

	altitude_label.text = "Altitude: %.1f m" % altitude_m
	offset_label.text = "Target Offset: %+.1f m" % offset_m
	velocity_label.text = "Velocity: (%.1f, %.1f) m/s" % [
		velocity_mps.x, -velocity_mps.y
	]
	speed_label.text = "Speed: %.1f m/s" % speed_mps
	drag_label.text = "Drag Force: %.1f kN" % drag_kn


# RANDOM FAILURES
func _on_failure_start_timer_timeout() -> void:
	if _finished or not enableRandomFailures:
		return

	# The first check occurs five seconds after the cooldown ends.
	if failure_timer.is_stopped():
		failure_timer.start()


func _on_failure_timer_timeout() -> void:
	if _finished or not enableRandomFailures:
		failure_timer.stop()
		return

	var threshold := 21.0
	for stage in FAILURE_STAGES:
		if Global.failures >= stage:
			threshold += 3.0
		else:
			break

	var failure_number := rng.randf_range(0.0, 42.0)
	if failure_number > threshold:
		_finish(
			false,
			"Random check: roll %.2f > threshold %.2f" % [
				failure_number, threshold
			]
		)

	# No manual restart: FailureTimer repeats automatically.


# FINISH FLIGHT
func _finish(won: bool, reason: String = "Unspecified") -> void:
	if _finished:
		return

	_finished = true
	_won = won

	failure_start_timer.stop()
	failure_timer.stop()
	end_timer.stop()
	win_end_timer.stop()

	thrust = Vector2.ZERO
	constant_force = Vector2.ZERO
	constant_torque = 0.0
	rotationalDirection = 0.0
	_update_effects(false)

	# Freeze only the ship, not the scene tree or its timers.
	set_deferred("freeze", true)

	if debugFailures:
		var result := "WIN" if won else "FAILURE"
		print(result, " SOURCE: ", reason, " | ship=", get_path())

	if won:
		win_end_timer.start()
	else:
		# Count losses only; successful landings do not add failures.
		Global.failures += 1
		end_timer.start()


# COLLISION DETECTION
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false, "Ground collision")


func _on_tower_area_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false, "Tower collision")


func _on_chopsticks_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("fwd"):
		_finish(true, "Chopsticks catch")


# SCENE TRANSITIONS
func _on_end_timer_timeout() -> void:
	if not _finished or _won:
		push_warning("Ignored EndTimer callback: no loss was recorded.")
		return

	# A one-shot timer stops before emitting its timeout signal.
	# Reject accidental calls while the real delay is still running.
	if not end_timer.is_stopped():
		push_warning("Ignored EndTimer callback: delay is still running.")
		return

	_change_scene(FAILURE_SCENE)


func _on_win_end_timer_timeout() -> void:
	if not _finished or not _won:
		push_warning("Ignored WinEndTimer callback: no win was recorded.")
		return

	if not win_end_timer.is_stopped():
		push_warning("Ignored WinEndTimer callback: delay is still running.")
		return

	_change_scene(SUCCESS_SCENE)


func _change_scene(scene_path: String) -> void:
	if _changing_scene:
		return

	_changing_scene = true
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_changing_scene = false
		push_error(
			"Could not load %s: %s" % [scene_path, error_string(error)]
		)

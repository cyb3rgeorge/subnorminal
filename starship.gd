extends RigidBody2D

class_name Starship

# Signals
signal propTelemetry
signal throttleTelemetry

# Ship Configurations
@export var maxProp : int = 3000
@export var throttle : float = 0.0
@export var engines : int = 0
@export var dryMass : float = 150000.0

# Failures
@export var enableRandomFailures : bool = false
const FAILURE_STAGES := [3, 5, 8, 11, 13, 16]
var failureThreshold := 21.0

# CONSTANTS
const GRAVITY : float = 9.81 # / m s^-2
const AIR_DENSITY : float = 1.2250 # At sea level and assume air density is constant /kg m^-3
const STARSHIP_HEIGHT : float = 52.0 # /m
const STARSHIP_DIAMETER : float = 9.0 # /m
const STARSHIP_BELLY_DRAG_AREA : float = STARSHIP_HEIGHT * STARSHIP_DIAMETER # Assume Starship is a 2-D rectangle /m^2
const STARSHIP_BELLY_DRAG_COEFFICIENT : float = 1.2 # Assume Starship is a perfect cylinder
const STARSHIP_CROSS_SECTIONAL_DRAG_AREA : float = PI * (STARSHIP_DIAMETER/2) ** 2
const STARSHIP_CROSS_SECTIONAL_DRAG_CEFFICIENT : float = 0.82

const TELEMETRY_INTERVAL : float = 0.1

const THROTTLE_CHANGE_RATE: float = 60.0
const FUEL_BURN_RATE: float = 60.0

const MAX_CATCH_SPEED_MPS: float = 5.0

# Simulation Scale
const METERS_PER_PIXEL: float = 54.0 / 158.0
const TARGET_X: float = 1012.0
const GROUND_Y: float = 1015.0

# Physics
var power : float = 800000.0
var angularPower : float = 500.0
var prop: float = 0.0
var thrust = Vector2.ZERO
var rotationalDirection : float = 0.0

# Internal State
var randomNumberGenerator = RandomNumberGenerator.new()
var _finished : bool = false
var _won: bool = false
var _telemetryElapsed : float = 0.0
var _wasBurning : bool = false

# Timers
@onready var FailureStartTimer : Timer = $"../FailureStartTimer"
@onready var FailureTimer : Timer = $"../FailureTimer"
@onready var EndTimer : Timer = $"../EndTimer"
@onready var WinEndTimer : Timer = $"../WinEndTimer"

# Effects
@onready var raptorRoar = $"../raptorRoar"
@onready var flameLow: CanvasItem = $RaptorThrottle1
@onready var flameHigh: CanvasItem = $RaptorThrottle2

# Telemetry Nodes
@onready var EngineIndicators: Array[CanvasItem] = [
	$"../Telemetry/0Engines",
	$"../Telemetry/1Engines",
	$"../Telemetry/2Engines",
	$"../Telemetry/3Engines"
]
@onready var AltitudeReadOut = $"../Telemetry/Control/Altimeter"
@onready var TargetOffsetReadOut = $"../Telemetry/Control/TargetOffset"
@onready var VelocityReadOut = $"../Telemetry/Control/Velocity"
@onready var SpeedReadOut = $"../Telemetry/Control/Speed"
@onready var DragForceReadOut = $"../Telemetry/Control/DragForce"


# Initialization

func _ready() -> void:
	gravity_scale = 9.81 / (980.0 * METERS_PER_PIXEL)
	
	throttle = 0.0
	engines = clampi(engines, 0, 3)
	
	prop = float(maxi(maxProp, 0))
	mass = dryMass
	
	_update_engine_indicators()
	
	if enableRandomFailures:
		FailureStartTimer.start()


# Input

func get_input(delta : float) -> void:
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")
	
	# Engine Control
	if Input.is_action_pressed("EngineCutoff"):
		engines = 0
		_update_engine_indicators()
	if Input.is_action_pressed("1Engine"):
		engines = 1
		_update_engine_indicators()
	if Input.is_action_pressed("2Engines"):
		engines = 2
		_update_engine_indicators()
	if Input.is_action_pressed("3Engines"):
		engines = 3
		_update_engine_indicators()
	
	# Throttle Control
	var throttleInput : float = 0.0
	if Input.is_action_pressed("throttleUp"):
		throttleInput += 1.0
		throttle = clampf(throttle + throttleInput * THROTTLE_CHANGE_RATE * delta, 0.0, 100.0)
		throttleTelemetry.emit()
	if Input.is_action_pressed("throttleDown"):
		throttleInput -= 1.0
		throttle = clampf(throttle + throttleInput * THROTTLE_CHANGE_RATE * delta, 0.0, 100.0)
		throttleTelemetry.emit()


func _physics_process (delta):
	get_input(delta)
	
	# Propulsion
	var enginePower := engines * throttle/100
	var burning := enginePower > 0 and prop >0
	
	thrust = Vector2.ZERO
	
	if burning:
		thrust -= engines * throttle/100 * transform.x * power
		prop = maxf(0.0, prop - engines * throttle/100 * FUEL_BURN_RATE *delta)
		propTelemetry.emit()
	constant_force = thrust / METERS_PER_PIXEL
	
	#Drag Froce
	var orientation = Vector2(cos(rotation), sin(rotation)) 
	
	# Drag X
	var dragForceX = ((
		0.5 * STARSHIP_BELLY_DRAG_COEFFICIENT * AIR_DENSITY * STARSHIP_BELLY_DRAG_AREA * 
		(linear_velocity.x*METERS_PER_PIXEL) ** 2
		) * abs(orientation.y) 
		+ (
		0.5 * STARSHIP_CROSS_SECTIONAL_DRAG_CEFFICIENT * AIR_DENSITY * STARSHIP_CROSS_SECTIONAL_DRAG_AREA * 
		(linear_velocity.x*METERS_PER_PIXEL) ** 2
		) * abs(orientation.x) 
		)
	var dragDirectionX = -sign(linear_velocity.x)
	
	# Drag Y
	var dragForceY = ((
		0.5 * STARSHIP_BELLY_DRAG_COEFFICIENT * AIR_DENSITY * STARSHIP_BELLY_DRAG_AREA * 
		(linear_velocity.y*METERS_PER_PIXEL) ** 2
		) * abs(orientation.x) 
		+ (
		0.5 * STARSHIP_CROSS_SECTIONAL_DRAG_CEFFICIENT * AIR_DENSITY * STARSHIP_CROSS_SECTIONAL_DRAG_AREA * 
		(linear_velocity.y*METERS_PER_PIXEL) ** 2
		) * abs(orientation.y) 
		)
	var dragDirectionY = -sign(linear_velocity.y)
	
	var dragForce: Vector2 = Vector2(dragForceX * dragDirectionX, dragForceY * dragDirectionY)
	apply_central_force(dragForce / METERS_PER_PIXEL)
	
	
	# Rotation
	constant_torque = rotationalDirection * angularPower * (engines + 1)
	
	# Engine Effects
	_update_effects(burning and prop > 0.0)
	
	# Telemetry
	_telemetryElapsed += delta
	if _telemetryElapsed >= TELEMETRY_INTERVAL:
		_telemetryElapsed = 0.0
		_update_telemetry(dragForce)

	
# Update Engine Indicators
func _update_engine_indicators() -> void:
	for i in range(EngineIndicators.size()):
		EngineIndicators[i].visible = engines == i


func _update_effects(burning: bool) -> void:
	flameLow.visible = burning and throttle <= 50.0
	flameHigh.visible = burning and throttle > 50.0
	
	if burning and not _wasBurning:
		raptorRoar.play()
	elif not burning and _wasBurning:
		raptorRoar.stop()
		
	_wasBurning = burning
	
	
# Telemetry
func _update_telemetry(dragForce: Vector2) -> void:
	var altitude_m := maxf(0.0, (GROUND_Y - global_position.y) * METERS_PER_PIXEL)
	var targetOffset_m := (global_position.x - TARGET_X) * METERS_PER_PIXEL
	var velocity_mps := linear_velocity * METERS_PER_PIXEL
	var speed_mps := velocity_mps.length()
	var dragForce_kn = dragForce/1000.0
	
	AltitudeReadOut.text = "Altitude: %.1f m" % altitude_m
	TargetOffsetReadOut.text = "Target Offset: %+.1f m" % targetOffset_m
	VelocityReadOut.text = "Velocity: (%.1f, %.1f) m/s" % [velocity_mps.x, -velocity_mps.y]
	SpeedReadOut.text = "Speed: %.1f m/s" % speed_mps
	DragForceReadOut.text = "Drag Force: (%.1f, %.1f) kN" % [dragForce_kn.x, -dragForce_kn.y]
	
# Random Failures

func _on_failure_start_timer_timeout() -> void:
	FailureTimer.start()

func _on_failure_timer_timeout() -> void:
	failureThreshold = 21.0
	
	for stage in FAILURE_STAGES:
		if Global.failures >= stage:
			failureThreshold += 3.0
		else:
			break
	
	var failureNumber = randomNumberGenerator.randf_range(0.0, 42.0)
	
	if failureNumber > failureThreshold:
		Global.failures += 1
		get_tree().change_scene_to_file(Global.FAILURE_SCENE)


func _finish(won: bool, reason: String = "Unknown") -> void:
	if _finished:
		return
	
	_finished = true
	_won = won

	set_deferred("freeze", true)
	
	if won:
		WinEndTimer.start()
	else:
		Global.failures += 1
		EndTimer.start()
	
	
# Collision Detection
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false, "Ground collision")

func _on_tower_area_body_entered(body: Node2D) -> void:
	if body == self:
		_finish(false, "Tower collision")
	
func _on_chopsticks_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("fwd"):
		var speed_mps := linear_velocity.length() * METERS_PER_PIXEL
		if speed_mps < MAX_CATCH_SPEED_MPS:
			_finish(true, "Chopsticks catch")
		else:
			_finish(false, "Chopsticks collision")


# Scene Transitions

func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file(Global.FAILURE_SCENE)

func _on_win_end_timer_timeout() -> void:
	get_tree().change_scene_to_file(Global.SUCCESS_SCENE)

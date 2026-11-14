extends RigidBody2D

class_name Starship

# Telemetry
signal failsTelemetry
signal propTelemetry
signal throttleTelemetry
signal enginesTelemetry
signal xTelemetry
signal yTelemetry

@export var fails = 0
@export var maxProp = 1000
@export var prop = maxProp
@export var throttle = 0
@export var engines = 0

# Corrections
const altitudeCorrection = 964
const targetOffsetCorrection = 960

# Specs
var power = 100
var angularPower = 100

var thrust = Vector2.ZERO
var rotationalDirection = 0

# Atmospheric Conditions
const drag = 100

# Telemetry (Velocity and Speed)
var previous_position: Vector2
func _ready() -> void:
	previous_position = global_position


func get_input():
	thrust = Vector2.ZERO
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")
	
	if Input.is_action_pressed("EngineCutoff"):
		engines = 0
		enginesTelemetry.emit()
	if Input.is_action_pressed("1Engine"):
		engines = 1
		enginesTelemetry.emit()
	if Input.is_action_pressed("2Engines"):
		engines = 2
		enginesTelemetry.emit()
	if Input.is_action_pressed("3Engines"):
		engines = 3
		enginesTelemetry.emit()
		
	if Input.is_action_pressed("throttleUp"):
		throttle = throttle + 1
		throttleTelemetry.emit()
	if Input.is_action_pressed("throttleDown"):
		throttle = throttle -1
		throttleTelemetry.emit()
		
	if throttle > 0 and engines > 0 and prop > 0:
		thrust = engines * throttle * -transform.y * power
		prop = prop - (engines * throttle/100)
		propTelemetry.emit()
		
	if throttle < 0:
		throttle = 0
	if throttle > 100:
		throttle = 100
	
	for i in range(4):
		$"../Telemetry".get_node(str(i) + "Engines").visible = (engines == i)

func _physics_process (delta):
	get_input()
	
	constant_force = thrust
	constant_torque = rotationalDirection * angularPower * (engines + 1)
	
	var targetOffset : int = self.global_position.x
	var altitude : int = self.global_position.y
	
	var velocityComplete = (global_position - previous_position) / delta
	var velocity = round(velocityComplete)
	var speed = round(velocityComplete.length()) # units per second
	previous_position = global_position
	
	$"../Telemetry/Control/Altimeter".text = "Altitude: " + str(-altitude + altitudeCorrection)
	$"../Telemetry/Control/TargetOffset".text = "Target Offset: " + str(targetOffset - targetOffsetCorrection)
	$"../Telemetry/Control/Velocity".text = "Velocity: " + str(velocity)
	$"../Telemetry/Control/Speed".text = "Speed: " + str(speed)
	
	print("Rotation: ", rotationalDirection)
	print("Throttle: ", throttle)
	print(engines, " Engines")
	print("Prop: ", prop)
	print("x: ", targetOffset)
	print("y: ", altitude)
	print("Velocity: ", velocity)
	print("Speed: ", speed)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		set_deferred("freeze", true)
		fails = fails + 1
		failsTelemetry.emit()

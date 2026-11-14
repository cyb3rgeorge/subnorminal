extends RigidBody2D

class_name Starship

# Telemetry
signal propTelemetry
signal throttleTelemetry

@export var maxProp = 2000
@export var prop = maxProp
@export var throttle = 0
@export var engines = 0
@export var dryMass = 100000

# Corrections
const altitudeCorrection = 964
const targetOffsetCorrection = 960

# Specs
var power = 330000
var angularPower = 500

var thrust = Vector2.ZERO
var rotationalDirection = 0

# Drag
const dragSkirtC : float = 1.2
const dragBellyC : float = 1.2
const dragNoseC : float = 0.5
const skirtArea = 64
const bellyArea = 500
const noseArea = 50
const rho = 1.2250

const CQ12 = (1 * dragSkirtC + 4 * dragBellyC)/5
const CQ34 = (1 * dragNoseC + 4 * dragBellyC)/5
const AQ12 = (1 * skirtArea + 4 * bellyArea)/5
const AQ34 = (1 * noseArea + 4 * bellyArea)/5

# Telemetry (Velocity and Speed)
var previous_position: Vector2
func _ready() -> void:
	mass = dryMass
	previous_position = global_position

func get_input():
	thrust = Vector2.ZERO
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")
	
	if Input.is_action_pressed("EngineCutoff"):
		engines = 0
	if Input.is_action_pressed("1Engine"):
		engines = 1
	if Input.is_action_pressed("2Engines"):
		engines = 2
	if Input.is_action_pressed("3Engines"):
		engines = 3
	
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
	
	var orientation = Vector2(cos(rotation), sin(rotation)) 
	# print(orientation)
	if orientation.x >= 0:
		var dragCoefficent = CQ12
		var dragArea = AQ12
	else:
		var dragCoefficent = CQ34
		var dragArea = AQ34
		
	var dragForce = 0.5 * CQ12 * rho * AQ12 * linear_velocity.y ** 2
	var dragDirection = -sign(linear_velocity.y)
	apply_central_force(Vector2(0, dragForce * dragDirection))
	
	# print(dragForce)
	# print("Rotation: ", rotationalDirection)
	# print("Throttle: ", throttle)
	# print(engines, " Engines")
	# print("Prop: ", prop)
	# print("x: ", targetOffset)
	# print("y: ", altitude)
	# print("Velocity: ", velocity)
	# print("Speed: ", speed)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		set_deferred("freeze", true)
		Global.failures = Global.failures + 1
		$"../EndTimer".start()
		
func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

extends RigidBody2D

class_name Starship

# Telemetry
signal propTelemetry
signal throttleTelemetry

@export var maxProp: int = 2000
var prop: float = 0.0
@export var throttle: int = 0
@export var engines : int = 0
@export var dryMass = 1000

# Corrections
const altitudeCorrection = 1014
const targetOffsetCorrection = 1014

# Specs
var power = 30000
var angularPower = 500

var thrust = Vector2.ZERO
var rotationalDirection = 0



# Telemetry (Velocity and Speed) & Failure Modes
var previous_position: Vector2

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	throttle = 0
	prop = float(maxProp)	
	mass = dryMass
	previous_position = global_position

	$"../FailureStartTimer".start()

func _on_failure_start_timer_timeout() -> void:
	$"../FailureTimer".start()

func _on_failure_timer_timeout() -> void:
	var failureNumber = rng.randf_range(0.0, 42.0)
	print(failureNumber)
	if Global.failures < 3:
		if failureNumber > 21.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 3 and Global.failures < 5:
		if failureNumber > 24.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 5 and Global.failures < 8:
		if failureNumber > 27.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 8 and Global.failures < 11:
		if failureNumber > 30.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 11 and Global.failures < 13:
		if failureNumber > 33.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 13 and Global.failures < 16:
		if failureNumber > 36.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()
	if Global.failures > 16 and Global.failures < 20:
		if failureNumber > 39.0:
			Global.failures = Global.failures + 1
			get_tree().change_scene_to_file("res://failure.tscn")
		else:
			$"../FailureTimer".start()

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
	
	# print("Throttle: ", throttle)
	# print("Engines: ", engines)
	# print("Prop: ", prop)

	if throttle > 0 and engines > 0 and prop > 0:
		thrust = engines * throttle * -transform.y * power
		prop -= engines * throttle / 100.0
		propTelemetry.emit()
		
		
	if throttle < 0:
		throttle = 0
	if throttle > 100:
		throttle = 100
		
	var raptorRoar = 0
	if throttle > 50 and engines > 0:
		$RaptorThrottle1.visible = false
		$RaptorThrottle2.visible = true
	elif throttle <= 50 and throttle > 0 and engines > 0:
		$RaptorThrottle1.visible = true
		$RaptorThrottle2.visible = false
	else:
		$RaptorThrottle1.visible = false
		$RaptorThrottle2.visible = false
	
	if throttle > 0 and engines > 0 and prop > 0:
		if not $"../raptorRoar".is_playing():
			$"../raptorRoar".play()
	else:
		$"../raptorRoar".stop()
	
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
	
	var orientation = Vector2(cos(rotation), sin(rotation)) 
	# print(orientation)

	var dragForce = abs(orientation.x) * 441 * linear_velocity.y ** 2
	var dragDirection = -sign(linear_velocity.y)
	apply_central_force(Vector2(0, dragForce * dragDirection))
	
	$"../Telemetry/Control/Altimeter".text = "Altitude: " + str(round((-altitude + altitudeCorrection)/3))
	$"../Telemetry/Control/TargetOffset".text = "Target Offset: " + str(round((targetOffset - targetOffsetCorrection)/3))
	$"../Telemetry/Control/Velocity".text = "Velocity: " + str(round(velocity/3))
	$"../Telemetry/Control/Speed".text = "Speed: " + str(round(speed/3))
	$"../Telemetry/Control/DragForce".text = "Drag Force: " +str(round(dragForce/4))
	
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
		print("failure")
		set_deferred("freeze", true)
		Global.failures = Global.failures + 1
		$"../EndTimer".start()

func _on_tower_area_body_entered(body: Node2D) -> void:
	if body == self:
		print("failure")
		set_deferred("freeze", true)
		Global.failures = Global.failures + 1
		$"../EndTimer".start()
	
func _on_chopsticks_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("fwd"):
		print("success")
		set_deferred("freeze", true)
		Global.failures = Global.failures + 1
		$"../WinEndTimer".start()

func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://failure.tscn")

func _on_win_end_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://success.tscn")

extends RigidBody2D

var power = 1000
var angularPower = 1000

var throttle = 0

var engines = 0

var thrust = Vector2.ZERO
var rotationalDirection = 0
	
func get_input():
	thrust = Vector2.ZERO
	
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
	if Input.is_action_pressed("throttleDown"):
		throttle = throttle -1
		
	if throttle > 0:
		thrust = engines * throttle* -transform.y * power
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")
	
	if throttle < 0:
		throttle = 0
	if throttle > 100:
		throttle = 100

func _physics_process (delta):
	get_input()
	constant_force = thrust
	constant_torque = rotationalDirection * angularPower
	print(rotationalDirection)
	print("Throttle: ", throttle)
	print(engines, " Engines")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		set_deferred("freeze", true)

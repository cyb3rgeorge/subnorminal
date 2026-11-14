extends RigidBody2D

@export var power = 3000
@export var angularPower = 10000

var thrust = Vector2.ZERO
var rotationalDirection = 0

func _ready():
	gravity_scale = 1
	freeze = false
	lock_rotation = false
	can_sleep = false
	custom_integrator = false
	inertia = 1000
	angular_damp_mode = DAMP_MODE_REPLACE
	angular_damp = 0
	
func get_input():
	thrust = Vector2.ZERO
	if Input.is_action_pressed("throttleUp"):
		thrust = -transform.y * power
	rotationalDirection = Input.get_axis("rotateLeft", "rotateRight")

func _physics_process (delta):
	get_input()
	#print(rotationalDirection)
	constant_force = thrust
	constant_torque = rotationalDirection * angularPower
	

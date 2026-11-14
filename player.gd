extends CharacterBody2D

var moveSpeed = 250
const gravity = 200

var vel : Vector2 = Vector2()
var facingDir : Vector2 = Vector2()
var heading = [1, 0]

func _physics_process(delta):
	velocity = Vector2()
	velocity.y = gravity * delta
	
	if Input.is_action_pressed("ui_up"):
		velocity.y -= moveSpeed
		facingDir = Vector2(0,-1)
	if Input.is_action_pressed("ui_down"):
		velocity.y += moveSpeed
		facingDir = Vector2(0,1)
	if Input.is_action_pressed("ui_left"):
		velocity.x -= moveSpeed
		facingDir = Vector2(-1,0)
	if Input.is_action_pressed("ui_right"):
		velocity.x += moveSpeed
		facingDir = Vector2(1,0)
		
	velocity = velocity.normalized() * moveSpeed
	move_and_slide()

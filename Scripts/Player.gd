extends CharacterBody3D


const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 1
const HOLD_TIME = 1.50
var speed = WALK_SPEED
var SENSITIVITY = 0.001
var is_sprinting = false
var is_moving = false
var sprint_hold = 0
#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 85
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
# Earth Gravity is about 9.8m/s^2
var gravity = 10

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var body = $Body
@onready var mouse_sens = %mouse_sensitivity

#helper variables
var col_angle = 0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		SENSITIVITY = mouse_sens.value
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(60))
		body.rotate_y(-event.relative.x * SENSITIVITY)


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += JUMP_VELOCITY + (speed - 2)
	
	# Handle Sprint.
	if Input.is_action_just_pressed("sprint") and is_on_floor():
		is_sprinting = not is_sprinting
	
	if Input.is_action_pressed("sprint") and is_on_floor():
		sprint_hold += delta
		if sprint_hold > HOLD_TIME:
			sprint_hold = HOLD_TIME + delta
	
	if Input.is_action_just_released("sprint") and is_on_floor():
		if sprint_hold > HOLD_TIME:
			is_sprinting = false
		sprint_hold = 0
	
	if is_sprinting and is_moving:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			is_moving = true
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
		
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 4.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 4.0)
	
	if (abs(velocity.x) < 0.07 and abs(velocity.z) < 0.07) or (
		is_on_wall() and is_on_floor()):
		is_moving = false
		is_sprinting = false
	
	
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor()) * float(is_moving)
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped * float(is_moving)
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()
	
	
	if get_last_slide_collision():
		col_angle = get_last_slide_collision().get_angle()
	
	# debugging stats
	%velocity_label.text = str(
		is_sprinting, " is_sprinting, ",
		sprint_hold, "hold, ",
		velocity.x, "x, ",
		velocity.y, "y, ",
		velocity.z, "z, ",
		camera.fov, "fov, ",
		get_position_delta(), "posΔ, ",
		col_angle, "col-angle")

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

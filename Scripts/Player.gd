extends CharacterBody3D

const VELOCITY_SCALAR = 10
const WALK_SPEED = 5.0 * VELOCITY_SCALAR
const SPRINT_SPEED = 8.0 * VELOCITY_SCALAR
const JUMP_VELOCITY = 1 * VELOCITY_SCALAR
const HOLD_TIME = 1.50
var speed = WALK_SPEED
var SENSITIVITY = 0.001
var is_sprinting = false
var is_moving = false
var is_falling = false
var sprint_hold = 0
var is_grappling = false
const DYNAMIC_SPRINT = 0
const TOGGLE_SPRINT = 1
const HOLD_SPRINT = 2

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 85
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
# Earth Gravity is about 9.8m/s^2 but it feels floaty in Godot
var gravity = 12 * VELOCITY_SCALAR

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var body = %Player_Animations
@onready var body_model = $Head/Player_Model
@onready var mouse_sens = %mouse_sensitivity
@onready var sprint_mode = %sprint_mode
@onready var grapple = $Head/Grapple_Detector
@onready var midgrapple = $Head/Grapple_Detector_Mid
@onready var botgrapple = $Head/Grapple_Detector_Bottom

#helper variables
var col_angle = 0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		SENSITIVITY = mouse_sens.value
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		is_moving = true
		velocity.y -= gravity * delta
		if velocity.y < 0:
			body.play("Falling", 0.2)
			is_falling = true
			is_grappling = false

	# Handle Jump and grapple.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_moving = true
		body.play("Jump", 0, 0.5)
		velocity.y += JUMP_VELOCITY + (speed - 2)
	elif Input.is_action_just_pressed("jump") and not is_on_floor():
		if midgrapple.is_colliding() and not grapple.is_colliding() and not is_grappling:
				velocity.y = JUMP_VELOCITY * 10
				is_grappling = true
				is_falling = false
	if not botgrapple.is_colliding() and not midgrapple.is_colliding() and is_grappling and not is_falling:
		velocity.y = 1
		is_grappling = false
	
	# Handle Sprint.
	if Input.is_action_just_pressed("sprint") and is_on_floor():
		is_sprinting = not is_sprinting
	
	if Input.is_action_pressed("sprint") and is_on_floor():
		sprint_hold += delta
		if sprint_mode.get_selected_id() == HOLD_SPRINT:
			sprint_hold = HOLD_TIME + delta
		if sprint_hold > HOLD_TIME:
			sprint_hold = HOLD_TIME + delta
	
	if Input.is_action_just_released("sprint") and is_on_floor():
		if sprint_hold > HOLD_TIME and sprint_mode.get_selected_id() != TOGGLE_SPRINT:
			is_sprinting = false
		sprint_hold = 0
	
	if is_sprinting and (is_moving or sprint_mode.get_selected_id() == TOGGLE_SPRINT):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		is_falling = false
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
	
	#detect if moving or if should force stop sprinting
	if (abs(velocity.x) < 0.07 and abs(velocity.z) < 0.07) or (
		is_on_wall() and is_on_floor()):
		is_moving = false
		if sprint_mode.get_selected_id() != TOGGLE_SPRINT:
			is_sprinting = false
	if (abs(velocity.x) < 0.001 and abs(velocity.z) < 0.001):
		velocity.x = 0
		velocity.z = 0
	
	# Head bob
	t_bob += delta * velocity.length()/VELOCITY_SCALAR * float(is_on_floor()) * float(is_moving)
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length()/VELOCITY_SCALAR, 0.5, SPRINT_SPEED/VELOCITY_SCALAR * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped * float(is_moving)
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	#animation
	if is_moving and is_on_floor():
		if Input.is_action_pressed("up"):
			if is_sprinting:
				body.play("Run")
			else:
				body.play("Walk")
		elif Input.is_action_pressed("down"):
			if is_sprinting:
				body.play_backwards("Run")
			else:
				body.play_backwards("Walk")
	else:
		body.play("Iddle", 0.2)
	
	move_and_slide()
	
	
	if get_last_slide_collision():
		col_angle = get_last_slide_collision().get_angle()
	
	# debugging stats
	%velocity_label.text = str(
		is_on_floor(), " is_on_floor, ",
		sprint_hold, " hold, ",
		#velocity.x, "x, ",
		#velocity.y, "y, ",
		#velocity.z, "z, ",
		camera.fov, "fov, ",
		#get_position_delta(), "posΔ, ",
		is_grappling, " grappling")

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

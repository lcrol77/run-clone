class_name Runner
extends CharacterBody3D

@export var lane_accel := 25.0
@export var ground_damping := 12.0
@export var move_speed := 3.0
@export var forward_speed := 5.0
@export var jump_velocity := 4.5
@export var max_tilt_deg := 30.0
@export var tilt_speed := 8.0

@onready var skin: SkinController = $Skin
@onready var right_ray: RayCast3D = $RightRay
@onready var left_ray: RayCast3D = $LeftRay


@export var rotate_cooldown := 0.15
var rotate_lock := 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity_vector := Vector3(0,-1,0)
var jump_buffered := false

var just_transitioned: bool = false

func _ready() -> void:
	skin.set_animation("walk")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"reset_position"):
		global_position = Vector3(0, 1, 0)
		velocity = Vector3.ZERO
		reset_physics_interpolation()

	if Input.is_action_just_pressed(&"jump"):
		jump_buffered = true

func _physics_process(delta: float) -> void:
	rotate_lock = max(0.0, rotate_lock - delta)
	# Gravity
	if not is_on_floor():
		velocity += (-up_direction) * gravity * delta
	# Jump (buffered)
	if jump_buffered and is_on_floor():
		velocity.y = jump_velocity
	jump_buffered = false

	# Horizontal control (x)
	var axis := Input.get_axis(&"move_left", &"move_right")
	var target_x := axis * move_speed
	velocity.x += target_x
	velocity.x *= exp(-ground_damping * delta)
	# Constant forward
	velocity.z = -forward_speed
	
	# skin rotation stuff
	var target_yaw := -deg_to_rad(axis * max_tilt_deg)
	skin.rotation.y = lerp_angle(
		skin.rotation.y,
		target_yaw,
		tilt_speed * delta
	)
	if rotate_lock <= 0.0:
		if axis > 0.0 and right_ray.is_colliding():
			_rotate_90(-1) # right turn
			rotate_lock = rotate_cooldown
		elif axis < 0.0 and left_ray.is_colliding():
			_rotate_90(1)  # left turn
			rotate_lock = rotate_cooldown
		
	move_and_slide()

func _rotate_90(sign: int) -> void:
	var angle := deg_to_rad(90.0 * sign)

	# Use the runner's forward axis in WORLD space.
	# If you move forward with velocity.z = -forward_speed,
	# then "forward" is -basis.z.
	var axis_world := (-global_transform.basis.z).normalized()

	# Compute the new up BEFORE rotating the transform
	var new_up := up_direction.rotated(axis_world, angle).normalized()

	# Rotate the body around the lane axis (world-space)
	global_rotate(axis_world, angle)

	# Rotate velocity to match the new orientation (important!)
	velocity = velocity.rotated(axis_world, angle)

	# Update up + gravity
	up_direction = new_up
	gravity_vector = -up_direction

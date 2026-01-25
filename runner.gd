class_name Runner
extends CharacterBody3D

@export var lane_accel := 25.0
@export var ground_damping := 12.0
@export var move_speed := 3.0
@export var forward_speed := 5.0
@export var jump_velocity := 4.5
@export var max_tilt_deg := 30.0
@export var tilt_speed := 8.0
@export var rotate_cooldown := 0.15

@onready var skin: SkinController = $Skin
@onready var right_ray: RayCast3D = $RightRay
@onready var left_ray: RayCast3D = $LeftRay

enum AxisIndex { X, Y }

var rotate_lock := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var jump_buffered := false

func _ready() -> void:
	skin.set_animation("walk")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"reset_position"):
		_reset_runner()

	if Input.is_action_just_pressed(&"jump"):
		jump_buffered = true


func _physics_process(delta: float) -> void:
	rotate_lock = maxf(0.0, rotate_lock - delta)

	_apply_gravity(delta)
	_handle_jump()

	var input_axis := Input.get_axis(&"move_left", &"move_right")
	_apply_lateral(input_axis, delta)
	_apply_skin_tilt(input_axis, delta)
	_try_wall_rotate(input_axis)

	move_and_slide()


# ----------------------------
# Movement pieces
# ----------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		# same as your original: velocity += (-up_direction) * gravity * delta
		velocity += (-up_direction) * gravity * delta


func _handle_jump() -> void:
	if jump_buffered and is_on_floor():
		velocity.y = jump_velocity
	jump_buffered = false


func _apply_forward() -> void:
	velocity.z = -forward_speed


func _apply_lateral(input_axis: float, delta: float) -> void:
	var cfg := _lateral_config()
	var target : float = input_axis * move_speed * cfg.sign

	# mutate the correct component
	match cfg.axis:
		AxisIndex.X:
			velocity.x += target
			velocity.x *= exp(-ground_damping * delta)
		AxisIndex.Y:
			velocity.y += target
			velocity.y *= exp(-ground_damping * delta)

	_apply_forward()


func _apply_skin_tilt(input_axis: float, delta: float) -> void:
	var target_yaw := -deg_to_rad(input_axis * max_tilt_deg)
	skin.rotation.y = lerp_angle(skin.rotation.y, target_yaw, tilt_speed * delta)


# ----------------------------
# Rotation pieces
# ----------------------------

func _try_wall_rotate(input_axis: float) -> void:
	if rotate_lock > 0.0:
		return

	if input_axis > 0.0 and right_ray.is_colliding():
		_rotate_90(-1) # right
		rotate_lock = rotate_cooldown
	elif input_axis < 0.0 and left_ray.is_colliding():
		_rotate_90(1)  # left
		rotate_lock = rotate_cooldown


func _rotate_90(s: int) -> void:
	var angle := deg_to_rad(90.0 * s)
	var axis_world := (-global_transform.basis.z).normalized()

	var new_up := up_direction.rotated(axis_world, angle).normalized()
	global_rotate(axis_world, angle)

	velocity = velocity.rotated(axis_world, angle)
	up_direction = new_up


# ----------------------------
# Orientation logic (centralized)
# ----------------------------

# Returns:
# - axis: which velocity component we treat as "lateral"
# - sign: multiplier for inversion
func _lateral_config() -> Dictionary:
	# Use dot checks instead of exact float equality.
	# "Up is mostly X" means we are on a wall where up_direction points ±X.
	var up_x := up_direction.dot(Vector3.RIGHT)  # +1 if (1,0,0), -1 if (-1,0,0)
	var up_y := up_direction.dot(Vector3.UP)     # +1 if (0,1,0), -1 if (0,-1,0)

	var axis := AxisIndex.X
	if absf(up_x) > 0.5:
		axis = AxisIndex.Y
	else:
		axis = AxisIndex.X

	# Preserve your intent: sometimes left/right should invert depending on orientation.
	# Your original condition was: if up_direction.x == 1 or up_direction.y == -1 => -1 else +1.
	# We'll express the same idea with dot products.
	var s := 1
	if up_x > 0.5 or up_y < -0.5:
		s = -1

	return { "axis": axis, "sign": s }


# ----------------------------
# Misc
# ----------------------------

func _reset_runner() -> void:
	global_position = Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	reset_physics_interpolation()

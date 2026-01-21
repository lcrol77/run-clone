class_name Runner
extends CharacterBody3D

@export var lane_accel := 25.0
@export var ground_damping := 12.0
@export var move_speed := 3.0
@export var forward_speed := 5.0
@export var jump_velocity := 4.5
@onready var skin: SkinController = $Skin

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var jump_buffered := false

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
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

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

	move_and_slide()

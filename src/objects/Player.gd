extends KinematicBody


const MOUSE_SENS = Vector2(0.0025, 0.0025)
const GRAVITY = 30.0
const MOVE_SPEED = 10.0
const JUMP_POWER = 12.0

var velocity := Vector3.ZERO

onready var camera := $"%Camera" as Camera
onready var hitscan := $"%Hitscan" as RayCast


func should_control() -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if get_tree().network_peer == null:
		return true
	return is_network_master()


func _unhandled_input(event: InputEvent) -> void:
	if not should_control():
		return
	if event is InputEventMouseMotion:
		var mm_event := event as InputEventMouseMotion
		rotation.y = wrapf(rotation.y - mm_event.relative.x * MOUSE_SENS.x, 0, TAU)
		camera.rotation.x = clamp(camera.rotation.x - mm_event.relative.y * MOUSE_SENS.y, -PI / 2, PI / 2)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("shoot"):
		shoot()
		get_tree().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var wishdir := Vector2.ZERO
	var jump_pressed := false
	if should_control():
		wishdir = Input.get_vector("move_left", "move_right", "move_backwards", "move_forwards")
		jump_pressed = Input.is_action_just_pressed("jump")

	var forward_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y - PI / 2)

	var move_vector := wishdir.x * right_vector + wishdir.y * forward_vector

	velocity.x = move_vector.x * MOVE_SPEED
	velocity.z = move_vector.z * MOVE_SPEED

	var jumping = false

	if is_on_floor() and jump_pressed:
		jumping = true
		velocity.y = JUMP_POWER

	velocity.y -= delta * GRAVITY
	velocity = move_and_slide_with_snap(velocity, Vector3.ZERO if jumping else Vector3.DOWN, Vector3.UP, true)

	if get_tree().network_peer != null:
		rpc_unreliable("set_network_transform", translation, rotation)


remote func set_network_transform(new_translation: Vector3, new_rotation: Vector3):
	translation = new_translation
	rotation = new_rotation


func shoot():
	hitscan.set_enabled(true)
	hitscan.force_raycast_update()
	if hitscan.is_colliding():
		var hit = hitscan.get_collider()
		if hit.has_method("on_raycast_hit"):
			hit.on_raycast_hit()
	hitscan.set_enabled(false)

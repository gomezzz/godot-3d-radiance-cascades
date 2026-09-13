class_name MetroWalker
extends CharacterBody3D
## Physics-grounded exploration. Camera pitch never changes walking speed or height.

const EYE_HEIGHT := 1.65
const SPEED := 4.3
const JUMP_SPEED := 6.0
var active := false
var jump_requested := false
var camera: Camera3D
var muted := false
var walking_enabled := true
var steps := AudioStreamPlayer.new()
var distance_since_step := 0.0
var step_count := 0


func _ready() -> void:
	collision_mask = 17
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	floor_snap_length = 0.25
	steps.stream = load("res://assets/audio/footstep.wav")
	add_child(steps)


func enter(view: Camera3D) -> void:
	camera = view
	position = Vector3(-5.6, 0.05, 14.0)
	velocity = Vector3.ZERO
	active = true
	distance_since_step = 0.0
	jump_requested = false
	camera.position = position + Vector3.UP * EYE_HEIGHT


func _physics_process(delta: float) -> void:
	if not active or not walking_enabled:
		steps.stream_paused = true
		return
	steps.stream_paused = false
	steps.volume_db = -80.0 if muted else -15.0
	var axis := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		axis = (
			Vector2(
				(
					float(Input.is_physical_key_pressed(KEY_D))
					- float(Input.is_physical_key_pressed(KEY_A))
				),
				(
					float(Input.is_physical_key_pressed(KEY_S))
					- float(Input.is_physical_key_pressed(KEY_W))
				)
			)
			. limit_length()
		)
	var direction := Basis(Vector3.UP, camera.rotation.y) * Vector3(axis.x, 0, axis.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if not is_on_floor():
		velocity.y -= 13.0 * delta
	elif jump_requested:
		velocity.y = JUMP_SPEED
	jump_requested = false
	var was_grounded := is_on_floor()
	var previous := position
	move_and_slide()
	if is_on_floor():
		distance_since_step += Vector2(position.x - previous.x, position.z - previous.z).length()
		if distance_since_step >= 1.45 or not was_grounded:
			distance_since_step = 0.0
			step_count += 1
			steps.pitch_scale = 0.94 if step_count % 2 == 0 else 1.06
			steps.play()
	if position.y < -3.0:
		enter(camera)
	camera.position = position + Vector3.UP * EYE_HEIGHT


func stop() -> void:
	active = false
	steps.stop()

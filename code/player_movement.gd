extends CharacterBody3D

@export var min_flight_speed = 0.0
@export var max_flight_speed = 300.0
@export var turn_speed_up = 0.75
@export var turn_speed_forward = 1.0
@export var pitch_speed = 0.5
@export var level_speed = 3.0
@export var throttle_delta = 30.0
@export var accel = 50.0

var forward_speed = 0.0
var target_speed = 0.0

var turn_input = 0.0
var pitch_input = 0.0

func get_input(delta):
	if (Input.is_action_pressed("throttle_up")):
		target_speed = min(forward_speed + throttle_delta * delta, max_flight_speed)
	if (Input.is_action_pressed("throttle_down")):
		target_speed = max(forward_speed - throttle_delta * delta, min_flight_speed)
	turn_input = Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right")
	pitch_input = Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down")

func _physics_process(delta):
	get_input(delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, turn_input * turn_speed_up * delta)
	transform.basis = transform.basis.rotated(transform.basis.z, -turn_input * turn_speed_forward * delta)
	forward_speed = lerp(forward_speed, target_speed, accel * delta)
	velocity = transform.basis.z * forward_speed
	move_and_slide()

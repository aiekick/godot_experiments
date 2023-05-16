extends Camera3D

# Paramètres de la caméra
@export var anchor_point := Vector3.ZERO
@export var distance := 1300.0
@export var rotation_speed := 0.01
@export var mouse_sensitivity := 0.01
@export var mouse_wheel_zoom_speed := 0.05
@export var mouse_drag_zoom_speed := 0.01
@export var min_distance := 650
@export var inertia_factor = 2.0

# Variables internes
var angle_x := 0.0
var angle_y := 0.0
var is_mouse_active := false
var is_mouse_right_active := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_mouse_active:
			var motion_event = event as InputEventMouseMotion
			angle_x -= motion_event.relative.y * -mouse_sensitivity
			angle_y -= motion_event.relative.x * mouse_sensitivity
			# not 0.5 for avoid a break of the look_at
			angle_x = clamp(angle_x, -PI * 0.49, PI * 0.49)
		elif is_mouse_right_active:
			var motion_event = event as InputEventMouseMotion
			distance += motion_event.relative.y * mouse_drag_zoom_speed * (distance - min_distance)
			distance = max(distance, min_distance)
			
	if event is InputEventMouseButton:
		var mouse_button_event = event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_active = mouse_button_event.pressed
		elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			is_mouse_right_active = mouse_button_event.pressed
		elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= mouse_wheel_zoom_speed * (distance - min_distance)
			distance = max(distance, min_distance)
		elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += mouse_wheel_zoom_speed * (distance - min_distance)
			distance = max(distance, min_distance)

	if event is InputEventKey:
		# Rotation de la caméra avec les touches de direction
		var key_event = event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_LEFT:
				angle_y += rotation_speed
			elif key_event.keycode == KEY_RIGHT:
				angle_y -= rotation_speed
			elif key_event.keycode == KEY_UP:
				angle_x += rotation_speed
			elif key_event.keycode == KEY_DOWN:
				angle_x -= rotation_speed

func _process(delta: float) -> void:
	var new_position = anchor_point + distance * Vector3(
		cos(angle_x) * sin(angle_y),
		sin(angle_x),
		cos(angle_x) * cos(angle_y))
	#position = new_position
	#look_at(anchor_point, Vector3.UP)
	
	var tf = Transform3D().translated(new_position).looking_at(anchor_point, Vector3.UP)
	global_transform = tf
	#global_transform = global_transform.interpolate_with(tf, inertia_factor * delta)


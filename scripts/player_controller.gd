extends CharacterBody2D

## Arcade-style movement for placeholder maps: accel toward target speed, friction when idle.

@export var move_speed: float = 200.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0


func _movement_input() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed(&"ui_left"):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed(&"ui_right"):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up"):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down"):
		y += 1.0
	if x != 0.0 and y != 0.0:
		return Vector2(x, y).normalized()
	return Vector2(x, y)


func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = _movement_input()
	var target: Vector2 = input_vec * move_speed
	if input_vec != Vector2.ZERO:
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

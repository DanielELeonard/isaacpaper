extends Node

var enemy: CharacterBody2D = null

func setup(enemy_ref: CharacterBody2D) -> void:
	enemy = enemy_ref

func update_movement(delta: float) -> void:
	if not enemy:
		return

	# Apply knockback if present
	if enemy.knockback_velocity.length() > 0:
		enemy.velocity += enemy.knockback_velocity
		enemy.knockback_velocity = enemy.knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)

	# Move and slide
	enemy.move_and_slide()

func choose_new_wander_target() -> Vector2:
	var angle = randf() * TAU
	var distance = randf() * enemy.wander_range
	return enemy.spawn_position + Vector2.from_angle(angle) * distance

func get_next_patrol_target() -> Vector2:
	if enemy.patrol_points.size() == 0:
		return enemy.spawn_position
	var current_target = enemy.patrol_points[enemy.current_patrol_index]
	var distance = enemy.global_position.distance_to(current_target)
	if distance < 50.0:
		enemy.current_patrol_index = (enemy.current_patrol_index + 1) % enemy.patrol_points.size()
	return enemy.patrol_points[enemy.current_patrol_index]

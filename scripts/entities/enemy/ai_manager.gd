extends Node

var enemy: CharacterBody2D = null

func setup(enemy_ref: CharacterBody2D) -> void:
	enemy = enemy_ref

func process_ai(delta: float) -> void:
	if not enemy:
		return

	# Lose target if too far
	if enemy.is_player_detected and enemy.target:
		var distance = enemy.global_position.distance_to(enemy.target.global_position)
		if distance > enemy.lose_target_distance:
			enemy.is_player_detected = false
			enemy.target = null
			if enemy.debug_mode:
				print("Player lost (too far away)")

	# Skip logic if dead
	if enemy.current_health <= 0:
		return

	# State machine
	match enemy.current_state:
		enemy.State.IDLE:
			enemy.handle_idle_state(delta)
		enemy.State.MOVING:
			enemy.handle_moving_state(delta)
		enemy.State.TELEGRAPH:
			enemy.handle_telegraph_state(delta)
		enemy.State.ATTACKING:
			enemy.handle_attack_state(delta)
		enemy.State.STUNNED:
			enemy.handle_stunned_state(delta)
		enemy.State.DYING:
			enemy.handle_dying_state(delta)

	# Handle movement and knockback
	enemy.movement_manager.update_movement(delta)

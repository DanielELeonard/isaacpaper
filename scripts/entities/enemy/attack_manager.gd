extends Node

var enemy: CharacterBody2D = null
var attack_area: Area2D = null
var stop_distance: float = 120.0
var attack_damage: int = 10
var debug_mode: bool = false

func setup(enemy_ref: CharacterBody2D, attack_area_ref: Area2D, stop_distance_val: float, attack_damage_val: int, debug: bool) -> void:
	enemy = enemy_ref
	attack_area = attack_area_ref
	stop_distance = stop_distance_val
	attack_damage = attack_damage_val
	debug_mode = debug

	# Connect signals
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
		attack_area.body_exited.connect(_on_attack_area_exited)
		# Scale attack area based on stop distance
		var collision_shape = attack_area.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = stop_distance * 0.8
			if debug_mode:
				print("Attack area radius set to: ", collision_shape.shape.radius)
	else:
		push_error("AttackArea node not found! Please add an Area2D named 'AttackArea' to the enemy scene.")

func _on_attack_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		enemy.target_in_attack_range = true
		if debug_mode:
			print("Player entered attack range")

func _on_attack_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		enemy.target_in_attack_range = false
		if debug_mode:
			print("Player left attack range")

func execute_attack() -> void:
	if enemy.attacked_this_turn:
		if debug_mode:
			print("Already attacked this turn, skipping")
		return

	if enemy.target and enemy.target.is_in_group("player") and enemy.target_in_attack_range:
		if debug_mode:
			print("Executing attack on player")
		if enemy.target.has_method("take_damage"):
			enemy.target.take_damage(attack_damage)
		enemy.enemy_attacked.emit(attack_damage, enemy.global_position)
	else:
		if debug_mode:
			print("Attack missed or player not in range")

	enemy.attacked_this_turn = true
	enemy.telegraph_started = false
	if enemy.telegraph_visual:
		enemy.telegraph_visual.hide()
		enemy.telegraph_visual.scale = Vector2.ONE

	enemy.cooldown_timer.start()
	enemy.change_state(enemy.State.MOVING)

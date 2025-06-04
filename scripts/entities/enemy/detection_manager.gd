extends Node

var enemy: CharacterBody2D = null
var detection_area: Area2D = null
var detection_range: float = 300.0
var lose_target_distance: float = 500.0
var debug_mode: bool = false

func setup(enemy_ref: CharacterBody2D, detection_area_ref: Area2D, detection_range_val: float, lose_target_distance_val: float, debug: bool) -> void:
	enemy = enemy_ref
	detection_area = detection_area_ref
	detection_range = detection_range_val
	lose_target_distance = lose_target_distance_val
	debug_mode = debug

	# Connect signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
		# Scale detection area based on detection range
		var collision_shape = detection_area.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = detection_range
			if debug_mode:
				print("Detection area radius set to: ", detection_range)

func _on_detection_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		enemy.is_player_detected = true
		enemy.target = body
		if debug_mode:
			print("Player detected!")
		if enemy.current_state == enemy.State.IDLE or enemy.current_state == enemy.State.MOVING:
			enemy.change_state(enemy.State.MOVING)

func _on_detection_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		enemy.is_player_detected = false
		enemy.target = null
		if debug_mode:
			print("Player lost (left detection area)")

func _process(_delta: float) -> void:
	if not enemy.is_player_detected or enemy.target == null:
		if detection_area:
			for body in detection_area.get_overlapping_bodies():
				if body.is_in_group("player"):
					enemy.is_player_detected = true
					enemy.target = body
					
					break

func _ready() -> void:
	set_process(true)

# PlayerMovementComponent.gd
class_name PlayerMovementComponent
extends Node

@export var move_speed: float = 200.0
var character_body: CharacterBody2D
var can_move: bool = true

func _ready() -> void:
	character_body = get_parent() as CharacterBody2D
	if not character_body:
		push_error("PlayerMovementComponent must be attached to a CharacterBody2D")

func _physics_process(_delta: float) -> void:
	if not can_move:
		character_body.velocity = Vector2.ZERO
		character_body.move_and_slide()
		return
	
	var input_vector = get_movement_input()
	character_body.velocity = input_vector * move_speed
	character_body.move_and_slide()

func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

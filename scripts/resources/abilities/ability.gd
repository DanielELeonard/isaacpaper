extends Resource
class_name Ability

@export var ability_name: String = "Base Ability"
@export var cooldown: float = 1.0
@export var can_use_in_enemy_turn: bool = false
@export var description: String = "Base ability description"
@export var icon: Texture2D

var is_on_cooldown: bool = false
var current_cooldown: float = 0.0

func can_use(_player: Node2D) -> bool:
	return not is_on_cooldown

func use(_player: Node2D) -> void:
	if can_use(_player):
		is_on_cooldown = true
		current_cooldown = cooldown
		_execute(_player)

func _execute(_player: Node2D) -> void:
	# Override this in child classes
	pass

func update_cooldown(delta: float) -> void:
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0:
			is_on_cooldown = false
			current_cooldown = 0.0

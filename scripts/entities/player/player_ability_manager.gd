class_name PlayerAbilityManager
extends Node

signal ability_used(ability: Ability)
signal ability_cooldown_updated(ability: Ability, progress: float)
signal ability_ready(ability: Ability)

@export var starting_abilities: Array[Ability] = []
@export var max_abilities: int = 3

var active_abilities: Array[Ability] = []
var current_ability_index: int = 0
var player: Node2D
var combat_manager: Node

func _ready() -> void:
	player = get_parent()
	combat_manager = get_tree().get_first_node_in_group("combat_manager")
	
	# Add starting abilities
	for ability in starting_abilities:
		add_ability(ability)
	
	# Setup input handling
	if not InputMap.has_action("cycle_ability"):
		var event = InputEventKey.new()
		event.keycode = KEY_Q
		InputMap.add_action("cycle_ability")
		InputMap.action_add_event("cycle_ability", event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_ability"):
		cycle_active_ability()
	elif event.is_action_pressed("use_active_ability"):
		use_current_ability()

func _process(delta: float) -> void:
	# Update cooldowns
	for ability in active_abilities:
		if ability.is_on_cooldown:
			ability.update_cooldown(delta)
			emit_signal("ability_cooldown_updated", ability, get_cooldown_progress(ability))
			
			if not ability.is_on_cooldown:
				emit_signal("ability_ready", ability)

func add_ability(ability: Ability) -> bool:
	if active_abilities.size() >= max_abilities:
		return false
		
	if ability not in active_abilities:
		active_abilities.append(ability)
		return true
	return false

func remove_ability(ability: Ability) -> void:
	var index = active_abilities.find(ability)
	if index >= 0:
		active_abilities.remove_at(index)
		if current_ability_index >= active_abilities.size():
			current_ability_index = max(0, active_abilities.size() - 1)

func use_current_ability() -> void:
	if active_abilities.is_empty():
		return
		
	var ability = active_abilities[current_ability_index]
	use_ability(ability)

func use_ability(ability: Ability) -> bool:
	if not can_use_ability(ability):
		return false
		
	if ability.can_use(player):
		ability.use(player)
		emit_signal("ability_used", ability)
		return true
	return false

func can_use_ability(ability: Ability) -> bool:
	if not ability:
		return false
		
	# Check if we're in enemy turn and ability is allowed then
	if combat_manager and combat_manager.current_state == combat_manager.CombatState.ENEMY_TURN:
		return ability.can_use_in_enemy_turn
		
	return true

func cycle_active_ability() -> void:
	if active_abilities.is_empty():
		return
		
	current_ability_index = (current_ability_index + 1) % active_abilities.size()

func get_current_ability() -> Ability:
	if active_abilities.is_empty():
		return null
	return active_abilities[current_ability_index]

func get_cooldown_progress(ability: Ability) -> float:
	if not ability.is_on_cooldown:
		return 1.0
	return 1.0 - (ability.current_cooldown / ability.cooldown)

func clear_abilities() -> void:
	active_abilities.clear()
	current_ability_index = 0

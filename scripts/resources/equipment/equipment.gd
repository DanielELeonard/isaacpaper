extends Resource
class_name Equipment

@export var equipment_name: String
@export var description: String  # Helpful for UI tooltips
@export var slot_type: String
@export var icon: Texture2D  # For inventory display

# Separate different types of effects for clarity
@export var stats_modifier: Dictionary = {}
@export var combat_actions: Array[Resource] = []  # Active abilities
@export var passive_effects: Array[Resource] = []  # Ongoing effects like "heal over time"
@export var on_hit_effects: Array[Resource] = []
@export var on_death_effects: Array[Resource] = []  # When enemy dies
@export var room_effects: Array[Resource] = []     # When entering rooms

# Stacking behavior - important for Isaac-like mechanics
@export var max_stack: int = 1
@export var current_stack: int = 1

# Equipment rarity/quality system
@export var rarity: String = "common"
@export var unlock_condition: String = ""  # For progression tracking

func apply_effects(player: Node2D) -> void:
	apply_stats(player)
	apply_combat_actions(player)
	apply_passive_effects(player)
	# Register this equipment for event callbacks
	player.register_equipment_events(self)

func remove_effects(player: Node2D) -> void:
	remove_stats(player)
	remove_combat_actions(player)
	remove_passive_effects(player)
	player.unregister_equipment_events(self)

# Keep your existing stat methods but add validation
func apply_stats(player: Node2D) -> void:
	for stat in stats_modifier:
		var modifier_value = stats_modifier[stat] * current_stack
		if player.has_method("modify_stat"):
			player.modify_stat(stat, modifier_value)
		else:
			push_warning("Player doesn't have modify_stat method")

func remove_stats(player: Node2D) -> void:
	for stat in stats_modifier:
		var modifier_value = stats_modifier[stat] * current_stack
		if player.has_method("modify_stat"):
			player.modify_stat(stat, -modifier_value)

# New methods for handling different effect types
func apply_combat_actions(player: Node2D) -> void:
	for action in combat_actions:
		if action and action.has_method("grant_to_player"):
			action.grant_to_player(player)

func remove_combat_actions(player: Node2D) -> void:
	for action in combat_actions:
		if action and action.has_method("remove_from_player"):
			action.remove_from_player(player)

func apply_passive_effects(player: Node2D) -> void:
	for effect in passive_effects:
		if effect and effect.has_method("activate"):
			effect.activate(player)

func remove_passive_effects(player: Node2D) -> void:
	for effect in passive_effects:
		if effect and effect.has_method("deactivate"):
			effect.deactivate(player)

# Event handlers that the player can call
func on_player_hit_enemy(enemy: Node2D, damage: float) -> void:
	for effect in on_hit_effects:
		if effect and effect.has_method("trigger"):
			effect.trigger(enemy, damage, current_stack)

func on_enemy_death(enemy: Node2D) -> void:
	for effect in on_death_effects:
		if effect and effect.has_method("trigger"):
			effect.trigger(enemy, current_stack)

# Utility methods
func can_stack_with(other_equipment: Equipment) -> bool:
	return equipment_name == other_equipment.equipment_name and current_stack < max_stack

func try_stack(other_equipment: Equipment) -> bool:
	if can_stack_with(other_equipment):
		current_stack += other_equipment.current_stack
		current_stack = min(current_stack, max_stack)
		return true
	return false

func get_total_stat_bonus(stat_name: String) -> float:
	return stats_modifier.get(stat_name, 0.0) * current_stack

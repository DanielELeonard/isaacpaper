extends Equipment
class_name SpeedBoots

func _init() -> void:
	equipment_name = "Speed Boots"
	description = "Swift leather boots that increase movement speed."
	slot_type = "feet"
	stats_modifier = {
		"speed": 25.0
	}
	max_stack = 1
	current_stack = 1
	rarity = "common"

	# Create and add the dash action
	var dash = DashAction.new()
	combat_actions.append(dash)

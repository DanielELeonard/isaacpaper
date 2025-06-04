extends Control
class_name AbilityIndicator

@onready var cooldown_arc: TextureProgressBar = $CooldownArc
@onready var ability_icon: TextureRect = $AbilityIcon
@onready var key_label: Label = $KeyLabel

func _ready() -> void:
	# Initialize progress bar
	if cooldown_arc:
		cooldown_arc.min_value = 0
		cooldown_arc.max_value = 1
		cooldown_arc.value = 1

func setup_ability(ability: Ability) -> void:
	if ability.icon:
		ability_icon.texture = ability.icon
	
	# Set key hint
	key_label.text = "SPACE"
	
	# Reset cooldown display
	cooldown_arc.value = 1
	
func update_cooldown(progress: float) -> void:
	cooldown_arc.value = progress
	
	# Visual feedback
	if progress >= 1.0:
		cooldown_arc.modulate = Color(0.2, 1.0, 0.2) # Green when ready
	else:
		cooldown_arc.modulate = Color(0.7, 0.7, 0.7) # Gray during cooldown

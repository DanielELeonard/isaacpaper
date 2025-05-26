extends CombatAction
class_name BasicAttack

func _init() -> void:
	action_name = "Attack"
	description = "Basic melee attack"
	is_default = true

func _perform_action(actor: Node2D, target: Node2D) -> void:
	if target.has_method("take_damage"):
		var damage = actor.base_attack_damage
		target.take_damage(damage)

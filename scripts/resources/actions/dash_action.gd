extends CombatAction
class_name DashAction

@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.3
@export var cooldown: float = 1.5

func _init() -> void:
    action_name = "Dash"
    description = "Quickly dash forward"
    is_default = false
    animation_name = "dash"

func can_use(actor: Node2D, _target: Node2D) -> bool:
    return not actor.is_dashing if "is_dashing" in actor else true

func grant_to_player(player: Node2D) -> void:
    if player.has_node("CombatActionManager"):
        player.get_node("CombatActionManager").add_action(self)

func remove_from_player(player: Node2D) -> void:
    if player.has_node("CombatActionManager"):
        player.get_node("CombatActionManager").remove_action(self)
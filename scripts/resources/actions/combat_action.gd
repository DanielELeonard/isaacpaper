extends Resource
class_name CombatAction

@export var action_name: String = "Base Action"
@export var description: String = "Base action description"
@export var icon: Texture2D
@export var is_default: bool = false  # For basic actions like Attack/Defend
@export var action_cost: int = 0      # For future action point system

# Visual feedback
@export var animation_name: String = ""
@export var sfx_path: String = ""

func can_use(_actor: Node2D, _target: Node2D) -> bool:
    return true

func execute(_actor: Node2D, target: Node2D) -> void:
    _perform_action(_actor, target)
    _play_feedback(_actor)

func _perform_action(_actor: Node2D, _target: Node2D) -> void:
    # Override in child classes
    pass

func _play_feedback(_actor: Node2D) -> void:
    if animation_name:
        if _actor.has_node("AnimationPlayer"):
            _actor.get_node("AnimationPlayer").play(animation_name)
    
    if sfx_path:
        if _actor.has_node("AudioStreamPlayer"):
            _actor.get_node("AudioStreamPlayer").stream = load(sfx_path)
            _actor.get_node("AudioStreamPlayer").play()
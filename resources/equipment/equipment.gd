extends Resource
class_name Equipment

@export var equipment_name: String
@export var slot_type: String  # weapon, armor, active_item
@export var stats_modifier: Dictionary = {}
@export var on_hit_effects: Array[Resource] = []

func apply_stats(player: Node2D) -> void:
    for stat in stats_modifier:
        player.modify_stat(stat, stats_modifier[stat])

func remove_stats(player: Node2D) -> void:
    for stat in stats_modifier:
        player.modify_stat(stat, -stats_modifier[stat])
extends CharacterBody2D

enum State {IDLE, MOVING, TELEGRAPH, ATTACKING, STUNNED, DYING}
enum EnemyType {MELEE, RANGED, HEAVY, ASSASSIN}

signal enemy_died(enemy)
signal enemy_attacked(damage, position)
signal health_changed(current, maximum)

@export_group("Enemy Type")
@export var enemy_type: EnemyType = EnemyType.MELEE


@onready var ai_manager = $ai_manager
@onready var detection_manager = $detection_manager
@onready var attack_manager = $attack_manager
@onready var movement_manager = $movement_manager



@export_group("Combat Properties")
@export var speed: float = 100.0
@export var stop_distance: float = 120.0  # Adjusted for better combat feel
@export var attack_damage: int = 10
@export var attack_windup_time: float = 0.8  # Slightly faster telegraph
@export var max_health: int = 100
@export var idle_cooldown: float = 1.5  # More frequent attacks
@export var knockback_resistance: float = 0.5 # 0 = no resistance, 1 = immune

@export_group("AI Behavior")
@export var detection_range: float = 300.0
@export var lose_target_distance: float = 500.0
@export var wander_enabled: bool = true
@export var wander_range: float = 150.0
@export var patrol_points: Array[Vector2] = [] # Optional patrol route

@export_group("Visual Feedback")
@export var hit_flash_duration: float = 0.1
@export var death_animation_time: float = 0.5

@export_group("Debug")
@export var debug_mode: bool = true

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var player: Node2D = null
var target: Node2D = null # More flexible targeting system
var attacked_this_turn: bool = false
var telegraph_started: bool = false
var current_health: int
var is_player_detected: bool = false
var spawn_position: Vector2
var current_patrol_index: int = 0
var wander_target: Vector2
var last_known_player_position: Vector2

# Timers and components
var attack_timer: Timer
var cooldown_timer: Timer
var stun_timer: Timer
var wander_timer: Timer
var combat_manager: Node2D

# Visual components
@onready var telegraph_visual: Node2D = $TelegraphVisual
@onready var attack_area: Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $Healthbar

# Status effects
var status_effects: Array[String] = []
var knockback_velocity: Vector2 = Vector2.ZERO
var target_in_attack_range: bool = false

func _ready() -> void:
	setup_references()
	setup_timers()
	setup_visual_components()
	initialize_enemy_type()
	attack_manager.setup(self, attack_area, stop_distance, attack_damage, debug_mode)
	detection_manager.setup(self, detection_area, detection_range, lose_target_distance, debug_mode)
	ai_manager.setup(self)
	movement_manager.setup(self)

	spawn_position = global_position
	current_health = max_health
	wander_target = spawn_position
	
	add_to_group("enemy")
	enemy_died.connect(_on_enemy_died)
	
	if debug_mode:
		print("Enemy initialized - Type: ", EnemyType.keys()[enemy_type])

func setup_references() -> void:
	player = get_tree().get_first_node_in_group("player")
	combat_manager = get_tree().get_first_node_in_group("combat_manager")


func setup_timers() -> void:
	# Attack timer for telegraph duration
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = attack_windup_time
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Cooldown between attacks
	cooldown_timer = Timer.new()
	add_child(cooldown_timer)
	cooldown_timer.name = "CooldownTimer"
	cooldown_timer.wait_time = idle_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	
	# Stun duration timer
	stun_timer = Timer.new()
	add_child(stun_timer)
	stun_timer.name = "StunTimer"
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timeout)
	
	# Wander behavior timer
	wander_timer = Timer.new()
	add_child(wander_timer)
	wander_timer.name = "WanderTimer"
	wander_timer.wait_time = randf_range(2.0, 5.0)
	wander_timer.timeout.connect(_choose_new_wander_target)
	if wander_enabled:
		wander_timer.start()

func setup_visual_components() -> void:
	if telegraph_visual:
		telegraph_visual.hide()
	else:
		push_warning("TelegraphVisual node not found - creating basic indicator")
		create_basic_telegraph()
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_changed.connect(_on_health_changed)

func initialize_enemy_type() -> void:
	# Adjust stats based on enemy type for variety
	match enemy_type:
		EnemyType.MELEE:
			speed = 120.0
			attack_damage = 15
			stop_distance = 80.0
		EnemyType.RANGED:
			speed = 80.0
			attack_damage = 12
			stop_distance = 250.0
		EnemyType.HEAVY:
			speed = 60.0
			attack_damage = 25
			max_health = 150
			knockback_resistance = 0.8
		EnemyType.ASSASSIN:
			speed = 150.0
			attack_damage = 20
			attack_windup_time = 0.5
			stop_distance = 60.0

func _physics_process(delta: float) -> void:
	ai_manager.process_ai(delta)

func handle_idle_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	if is_player_detected and target:
		change_state(State.MOVING)
	elif wander_enabled and not attacked_this_turn:
		# Wander around spawn point when not engaged
		var distance_to_wander = global_position.distance_to(wander_target)
		if distance_to_wander > 20.0:
			change_state(State.MOVING)

func handle_moving_state(_delta: float) -> void:
	var move_target = determine_move_target()
	if not move_target:
		change_state(State.IDLE)
		return
	
	var direction := global_position.direction_to(move_target)
	var distance := global_position.distance_to(move_target)
	
	if target and target.is_in_group("player"):
		if target_in_attack_range:
			velocity = Vector2.ZERO
			if not attacked_this_turn and cooldown_timer.is_stopped():
				if debug_mode:
					print("In attack range, starting telegraph")
				change_state(State.TELEGRAPH)
				return
		else:
			velocity = direction * speed
			
				
	else:
		velocity = direction * speed
	
	# Update facing direction
	if velocity.length() > 0 and sprite:
		sprite.flip_h = direction.x < 0

func handle_telegraph_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	if target:
		var direction = global_position.direction_to(target.global_position)
		# Flip the sprite to face the player
		if sprite:
			sprite.flip_h = direction.x < 0
		# Rotate the telegraph visual to point at the player
		if telegraph_visual:
			telegraph_visual.rotation = direction.angle()
	
	if not telegraph_started:
		if debug_mode:
			print("Starting telegraph animation")
		start_telegraph()

func handle_attack_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	if target:
		var direction = global_position.direction_to(target.global_position)
		if sprite:
			sprite.flip_h = direction.x < 0
		if telegraph_visual:
			telegraph_visual.rotation = direction.angle()
	attack_manager.execute_attack()

func handle_stunned_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	# Visual indication of stun could be added here

func handle_dying_state(delta: float) -> void:
	velocity = Vector2.ZERO
	# Handle death animation and cleanup

func determine_move_target() -> Vector2:
	# Priority: Player > Patrol > Wander
	if is_player_detected and target:
		last_known_player_position = target.global_position
		return target.global_position
	elif last_known_player_position != Vector2.ZERO:
		# Move to last known position to investigate
		var distance_to_last_known = global_position.distance_to(last_known_player_position)
		if distance_to_last_known > 50.0:
			return last_known_player_position
		else:
			last_known_player_position = Vector2.ZERO # Clear investigation target
	elif patrol_points.size() > 0:
		return get_current_patrol_target()
	elif wander_enabled:
		return wander_target
	
	return Vector2.ZERO

func get_current_patrol_target() -> Vector2:
	if patrol_points.size() == 0:
		return spawn_position
	
	var current_target = patrol_points[current_patrol_index]
	var distance = global_position.distance_to(current_target)
	
	if distance < 50.0: # Reached patrol point
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	
	return current_target

func start_telegraph() -> void:
	telegraph_started = true
	if telegraph_visual:
		telegraph_visual.show()
		# Add visual scaling or rotation animation here
		var tween = create_tween()
		tween.tween_property(telegraph_visual, "scale", Vector2(1.5, 1.5), attack_windup_time)
	attack_timer.start()
	
	if debug_mode:
		print("Telegraph started for ", attack_windup_time, " seconds")

func change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if current_state == State.DYING:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	# Apply knockback if not resistant
	if knockback_force > 0 and knockback_resistance < 1.0:
		var effective_force = knockback_force * (1.0 - knockback_resistance)
		knockback_velocity = knockback_direction.normalized() * effective_force
	
	# Visual feedback
	show_damage_flash()
	
	if current_health <= 0:
		die()
	else:
		# Interrupt current action when hurt
		if current_state == State.TELEGRAPH:
			if telegraph_visual:
				telegraph_visual.hide()
				telegraph_visual.scale = Vector2.ONE
			telegraph_started = false
			attack_timer.stop()
		
		# Brief stun on damage
		stun(0.2)
	
	if debug_mode:
		print("Enemy took ", amount, " damage. Health: ", current_health, "/", max_health)

func stun(duration: float) -> void:
	change_state(State.STUNNED)
	stun_timer.wait_time = duration
	stun_timer.start()

func show_damage_flash() -> void:
	if sprite:
		# Create a simple damage flash effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, hit_flash_duration / 2)
		tween.tween_property(sprite, "modulate", Color.WHITE, hit_flash_duration / 2)

func die() -> void:
	change_state(State.DYING)
	enemy_died.emit(self)
	
	# Create death effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, death_animation_time)
	tween.tween_callback(queue_free)

func create_basic_telegraph() -> void:
	# Create a simple telegraph visual if none exists
	telegraph_visual = Node2D.new()
	add_child(telegraph_visual)
	telegraph_visual.name = "TelegraphVisual"
	
	var indicator = ColorRect.new()
	indicator.size = Vector2(40, 40)
	indicator.position = Vector2(-20, -20)
	indicator.color = Color.RED
	indicator.color.a = 0.7
	telegraph_visual.add_child(indicator)

func _choose_new_wander_target() -> void:
	if not wander_enabled:
		return
	
	# Choose random point within wander range of spawn
	var angle = randf() * TAU
	var distance = randf() * wander_range
	wander_target = spawn_position + Vector2.from_angle(angle) * distance
	
	wander_timer.wait_time = randf_range(3.0, 8.0)
	wander_timer.start()

# Signal callbacks
func _on_attack_timer_timeout() -> void:
	if debug_mode:
		print("Attack timer timeout - executing attack")
	change_state(State.ATTACKING)

func _on_cooldown_timeout() -> void:
	attacked_this_turn = false
	if debug_mode:
		print("Cooldown finished, can attack again")
	
	if is_player_detected and target:
		change_state(State.MOVING)
	else:
		change_state(State.IDLE)

func _on_stun_timeout() -> void:
	if current_health > 0:
		change_state(State.IDLE)

func _on_health_changed(current: int, maximum: int) -> void:
	if health_bar:
		health_bar.value = current

func _on_enemy_died(enemy: Node2D) -> void:
	if debug_mode:
		print("Enemy died: ", enemy.name)

# Turn-based combat integration with bullet-time support
func on_player_turn_start() -> void:
	# Enemies continue acting normally - time scale handles the slowdown
	# No special behavior needed since Engine.time_scale affects everything
	pass

func on_enemy_turn_start() -> void:
	# When switching back to normal time, enemies resume full speed
	# Reset any turn-specific flags or behaviors
	if current_state == State.IDLE and not attacked_this_turn:
		change_state(State.MOVING)
	self.wander_target = movement_manager.choose_new_wander_target()

extends Control

var enemy: BattleEnemyData_1
var current_player_health = 0
var current_enemy_health = 0
var is_defending = false
var is_busy := false

@onready var attack_button = $Control/CommandButtons/Attack
@onready var guard_button = $Control/CommandButtons/Guard

func initialize_battle(enemy_data: BattleEnemyData_1):
	enemy = enemy_data
	print("Battle initialized with enemy: ", enemy.enemy_name)
	
	if enemy:
		current_player_health = State.current_health
		current_enemy_health = enemy.current_health
		
		set_health($HP/ProgressBar, current_enemy_health, enemy.max_health)
		set_health($HP2/ProgressBar, current_player_health, State.max_health)

func _ready():
	randomize()
	print("Fight scene ready")
	
	set_buttons_enabled(false)

	var stored_state = GameManager.get_battle_state()
	if stored_state and stored_state.has("enemy_data"):
		initialize_battle(stored_state["enemy_data"])
	
	await show_enemy_turn()
	await get_tree().create_timer(0.5).timeout
	enemy_turn()

func set_health(progress_bar, health, max_health):
	if progress_bar and progress_bar.has_node("Label"):
		progress_bar.value = health
		progress_bar.max_value = max_health
		progress_bar.get_node("Label").text = "%d/%d" % [health, max_health]

func set_buttons_enabled(enabled: bool):
	if is_instance_valid(attack_button):
		attack_button.disabled = not enabled
	if is_instance_valid(guard_button):
		guard_button.disabled = not enabled

func enemy_turn():
	set_buttons_enabled(false)

	if current_player_health <= 0:
		if $AnimationPlayer.has_animation("player_died"):
			$AnimationPlayer.play("player_died")
			await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		end_fight("player_died")
		return
	
	var move_power = enemy.damage
	var attacker_stat = 4
	var defender_stat = 4
	
	var result = DamageCalculator.calculate_damage(move_power, attacker_stat, defender_stat)
	var damage = result["damage"]

	show_damage_number(damage, true)

	if is_defending:
		damage /= 2
		is_defending = false
		if $AnimationPlayer.has_animation("mini_shake"):
			$AnimationPlayer.play("mini_shake")
	else:
		if $AnimationPlayer.has_animation("shake"):
			$AnimationPlayer.play("shake")

	current_player_health -= damage
	set_health($HP2/ProgressBar, current_player_health, State.max_health)
	await $AnimationPlayer.animation_finished

	await get_tree().create_timer(1.0).timeout
	await show_player_turn()

func _on_attack_pressed():
	if is_busy:
		return
	is_busy = true
	set_buttons_enabled(false)

	if $UIAnimationPlayer.has_animation("fade_out_ui"):
		$UIAnimationPlayer.play("fade_out_ui")
		await $UIAnimationPlayer.animation_finished
	
	var result = DamageCalculator.calculate_damage(State.damage, 4, 3)
	var damage = result.damage
	show_damage_number(damage, false)
	current_enemy_health = max(0, current_enemy_health - damage)
	set_health($HP/ProgressBar, current_enemy_health, enemy.max_health)

	if $AnimationPlayer.has_animation("enemy_damaged"):
		$AnimationPlayer.play("enemy_damaged")
		await $AnimationPlayer.animation_finished
	
	if current_enemy_health <= 0:
		if $AnimationPlayer.has_animation("enemy_died"):
			$AnimationPlayer.play("enemy_died")
			await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		end_fight("enemy_died")
	else:
		end_fight("round_ended")

	is_busy = false

func end_fight(result: String):
	print("Fight ended with result: ", result)
	
	match result:
		"enemy_died":
			print("Player won the fight!")
			enemy.is_defeated = true
			EnemyManager.update_enemy_health(enemy.enemy_name, 0)
		"player_died":
			print("Player lost the fight!")
			current_player_health = max(1, current_player_health)
		"error":
			print("Fight ended due to error")
	
	State.current_health = current_player_health
	
	if result != "enemy_died":
		EnemyManager.update_enemy_health(enemy.enemy_name, current_enemy_health)
	
	var stored_state = GameManager.get_battle_state()
	var battle_scene_path = "res://battle_2.tscn"
	
	if stored_state and stored_state.has("scene_path"):
		battle_scene_path = stored_state["scene_path"]
	
	print("Returning to battle scene: ", battle_scene_path)
	
	var result_code = get_tree().change_scene_to_file(battle_scene_path)
	if result_code != OK:
		push_error("Failed to return to battle scene: " + str(result_code))
		get_tree().change_scene_to_file("res://battle_2.tscn")

func show_enemy_turn():
	if is_instance_valid($TurnMessage):
		await $TurnMessage.show_message("🔴 ENEMY TURN")

func show_player_turn():
	if is_instance_valid($TurnMessage):
		await $TurnMessage.show_message("🔵 PLAYER TURN")
	
	set_buttons_enabled(true)

func show_damage_number(amount: int, is_player: bool):
	var damage_label = preload("res://Scenes/Game/damage_label.tscn").instantiate()
	damage_label.text = "-" + str(amount)

	if is_player:
		if is_instance_valid($HP2):
			$HP2.add_child(damage_label)
			damage_label.position = Vector2(100, -30)
	else:
		if is_instance_valid($HP):
			$HP.add_child(damage_label)
			damage_label.position = Vector2(100, -30)
	
	if damage_label.has_node("AnimationPlayer"):
		var ap = damage_label.get_node("AnimationPlayer")
		if ap.has_animation("popup"):
			ap.play("popup")

func _on_guard_pressed() -> void:
	if is_busy:
		return
	is_busy = true
	set_buttons_enabled(false)

	is_defending = true

	if $UIAnimationPlayer.has_animation("fade_out_ui"):
		$UIAnimationPlayer.play("fade_out_ui")
		await $UIAnimationPlayer.animation_finished

	await show_enemy_turn()

	if $UIAnimationPlayer.has_animation("fade_in_ui"):
		$UIAnimationPlayer.play("fade_in_ui")
		await $UIAnimationPlayer.animation_finished

	enemy_turn()
	is_busy = false

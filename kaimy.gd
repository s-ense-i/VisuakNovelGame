extends Control

# Remove the signal - we don't need it with proper scene switching
# signal fight_ended

var enemy: BattleEnemyData_1
var current_player_health = 0
var current_enemy_health = 0
var is_defending = false
var extra_turn: bool = false
var round_count := 0

func initialize_battle(enemy_data: BattleEnemyData_1):
	enemy = enemy_data
	print("Battle initialized with enemy: ", enemy.enemy_name)
	
	if enemy:
		current_player_health = Statekame.current_health
		current_enemy_health = enemy.health
		
		set_health($HP/ProgressBar, current_enemy_health, enemy.health)
		set_health($HP2/ProgressBar, current_player_health, Statekame.max_health)

func _ready():
	randomize()
	print("Fight scene ready")
	
	# Get enemy data from GameManager if available
	var stored_state = GameManager.get_battle_state()
	if stored_state and stored_state.has("enemy_data"):
		initialize_battle(stored_state["enemy_data"])
	
	await show_enemy_turn()
	#$UIAnimationPlayer.play("fade_out_ui")
	#await $UIAnimationPlayer.animation_finished
	await get_tree().create_timer(0.5).timeout  # تأخير بسيط علشان شكل لطيف
	enemy_turn()
	
func set_health(progress_bar, health, max_health):
	if progress_bar and progress_bar.get_node("Label"):
		progress_bar.value = health
		progress_bar.max_value = max_health
		progress_bar.get_node("Label").text = "%d/%d" % [health, max_health]

func enemy_turn():
	if current_player_health <= 0:
		$AnimationPlayer.play("player_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		end_fight("player_died")
		return
	
	var move_power = enemy.damage
	var attacker_stat = 4
	var defender_stat = 4
	
	var enemy_extra_turn_range = Vector2(20, 30)
	var result = DamageCalculator.calculate_damage(move_power, attacker_stat, defender_stat, enemy_extra_turn_range)
	
	var damage = result["damage"]
	var is_crit = result["is_crit"]
	show_damage_number(damage, true)

	if is_crit:
		await show_enemy_crit()

	if is_defending:
		damage /= 2
		is_defending = false
		$AnimationPlayer.play("mini_shake")
	else:
		$AnimationPlayer.play("shake")

	current_player_health -= damage
	set_health($HP2/ProgressBar, current_player_health, State.max_health)
	await $AnimationPlayer.animation_finished

	await get_tree().create_timer(1.0).timeout
	await show_player_turn()

		
func _on_attack_pressed() -> void:
	$UIAnimationPlayer.play("fade_out_ui")
	await $UIAnimationPlayer.animation_finished
	
	var result = DamageCalculator.calculate_damage(State.damage, 4, 3)
	var damage = result.damage
	show_damage_number(damage, false)
	current_enemy_health = max(0, current_enemy_health - damage)
	set_health($HP/ProgressBar, current_enemy_health, enemy.health)
	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished
	
	if current_enemy_health <= 0:
		$AnimationPlayer.play("enemy_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		end_fight("enemy_died")
	else:
		end_fight("round_ended")  # نهاية الفايت بعد الضربتين


# FIXED: Proper fight ending that returns to battle scene
func end_fight(result: String):
	print("Fight ended with result: ", result)
	
	# Update Statekame based on result
	match result:
		"enemy_died":
			print("Player won the fight!")
		"player_died":
			print("Player lost the fight!")
			current_player_health = max(1, current_player_health)
		"error":
			print("Fight ended due to error")
	
	# Save current health back to Statekame
	Statekame.current_health = current_player_health
	
	# Get the battle scene path from stored state
	var stored_state = GameManager.get_battle_state()
	var battle_scene_path = "res://battle_2.tscn"  # Default fallback
	
	if stored_state and stored_state.has("scene_path"):
		battle_scene_path = stored_state["scene_path"]
	
	# Return to battle scene using proper scene switching
	print("Returning to battle scene: ", battle_scene_path)
	
	# Use get_tree().change_scene_to_file() - the proper way
	var result_code = get_tree().change_scene_to_file(battle_scene_path)
	if result_code != OK:
		push_error("Failed to return to battle scene: " + str(result_code))
		# Fallback - try default scene
		get_tree().change_scene_to_file("res://battle_2.tscn")

func show_extra_turn():
	await $TurnMessage.show_message("🎁 EXTRA TURN!")
	$UIAnimationPlayer.play("fade_in_ui")
	await $UIAnimationPlayer.animation_finished

func show_enemy_turn():
	await $TurnMessage.show_message("🔴 ENEMY TURN")

func show_player_turn():
	await $TurnMessage.show_message("🔵 PLAYER TURN")

func show_enemy_crit():
	await $TurnMessage.show_message("💥 CRITICAL HIT!")

func show_damage_number(amount: int, is_player: bool):
	var damage_label = preload("res://damage_label.tscn").instantiate()
	damage_label.text = "-" + str(amount)
	if is_player:
		$HP2.add_child(damage_label)
		damage_label.position = Vector2(100, -30)
	else:
		$HP.add_child(damage_label)
		damage_label.position = Vector2(100, -30)
	damage_label.get_node("AnimationPlayer").play("popup")

func _on_guard_pressed() -> void:
	is_defending = true
	$UIAnimationPlayer.play("fade_out_ui")
	await $UIAnimationPlayer.animation_finished
	
	await show_enemy_turn()
	$UIAnimationPlayer.play("fade_in_ui")
	await $UIAnimationPlayer.animation_finished
	enemy_turn()

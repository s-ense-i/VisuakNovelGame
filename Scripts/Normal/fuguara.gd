extends Control

var enemy: BattleEnemyData_1
var current_player_health = 0
var current_enemy_health = 0
var is_defending = false
var attack_count := 0  # عدد مرات الهجوم

func initialize_battle(enemy_data: BattleEnemyData_1):
	enemy = enemy_data
	print("Battle initialized with enemy: ", enemy.enemy_name)
	
	if enemy:
		current_player_health = Statefge.current_health
		current_enemy_health = enemy.current_health
		
		set_health($HP/ProgressBar, current_enemy_health, enemy.max_health)
		set_health($HP2/ProgressBar, current_player_health, Statefge.max_health)

func _ready():
	randomize()
	print("Fight scene ready")
	
	var stored_state = GameManager.get_battle_state()
	if stored_state and stored_state.has("enemy_data"):
		initialize_battle(stored_state["enemy_data"])
	
	await show_enemy_turn()
	await get_tree().create_timer(0.5).timeout
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
	var result = damageccfge.calculate_damage(move_power, attacker_stat, defender_stat)
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
	set_health($HP2/ProgressBar, current_player_health, Statefge.max_health)
	await $AnimationPlayer.animation_finished
	
	if current_player_health <= 0:
		$AnimationPlayer.play("player_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		end_fight("player_died")
	else:
		await get_tree().create_timer(1.0).timeout
		await show_player_turn()

func _on_attack_pressed() -> void:
	$UIAnimationPlayer.play("fade_out_ui")
	await $UIAnimationPlayer.animation_finished
	
	var result = damageccfge.calculate_damage(Statefge.damage, 4, 3)
	var damage = result.damage
	show_damage_number(damage, false)
	current_enemy_health = max(0, current_enemy_health - damage)
	set_health($HP/ProgressBar, current_enemy_health, enemy.max_health)
	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished
	
	attack_count += 1

	if attack_count == 1:
		print("🎁 First attack → Extra Turn")
		await show_extra_turn()
		return
	elif attack_count == 2:
		print("✅ Second attack → Ending fight regardless of result")
		end_fight("round_finished")
		return

func _on_guard_pressed() -> void:
	is_defending = true
	$UIAnimationPlayer.play("fade_out_ui")
	await $UIAnimationPlayer.animation_finished
	
	await show_enemy_turn()
	$UIAnimationPlayer.play("fade_in_ui")
	await $UIAnimationPlayer.animation_finished
	enemy_turn()

func end_fight(result: String):
	print("Fight ended with result: ", result)
	
	match result:
		"enemy_died":
			print("Player won the fight!")
			EnemyManager.update_enemy_health(enemy.enemy_name, 0)
		"player_died":
			print("Player lost the fight!")
			current_player_health = max(1, current_player_health)
		"round_finished":
			print("Fight ended after 1 enemy turn + 2 player turns")
		"error":
			print("Fight ended due to error")
	
	Statefge.current_health = current_player_health
	
	if result != "enemy_died":
		EnemyManager.update_enemy_health(enemy.enemy_name, current_enemy_health)
		
	var stored_state = GameManager.get_battle_state()
	var battle_scene_path = "res://battle_2.tscn"
	
	if stored_state and stored_state.has("scene_path"):
		battle_scene_path = stored_state["scene_path"]
	
	var result_code = get_tree().change_scene_to_file(battle_scene_path)
	if result_code != OK:
		push_error("Failed to return to battle scene: " + str(result_code))
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
	var damage_label = preload("res://Scenes/Game/damage_label.tscn").instantiate()
	damage_label.text = "-" + str(amount)
	if is_player:
		$HP2.add_child(damage_label)
		damage_label.position = Vector2(100, -30)
	else:
		$HP.add_child(damage_label)
		damage_label.position = Vector2(100, -30)
	damage_label.get_node("AnimationPlayer").play("popup")

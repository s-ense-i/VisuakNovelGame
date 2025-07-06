extends Control
@export var enemy: EnemyData

var current_player_health = 0
var current_enemy_health = 0
var is_defending = false
var extra_turn: bool = false

func _ready():
	randomize()
	set_health($HP/ProgressBar, enemy.health, enemy.health)
	set_health($HP2/ProgressBar, State.current_health, State.max_health)
	current_player_health = State.current_health
	current_enemy_health = enemy.health

func set_health(progress_bar, health, max_health):
	progress_bar.value = health
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "%d/%d" % [health, max_health]

func _enemy_turn():


	if current_player_health <= 0:
		$AnimationPlayer.play("player_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		get_tree().quit()
		return

	var move_power = enemy.damage
	var attacker_stat = 4  # قوة العدو
	var defender_stat = 4  # دفاع اللاعب

	var result = DamageCalculator.calculate_damage(move_power, attacker_stat, defender_stat)
	var damage = result["damage"]
	var is_crit = result["is_crit"]
	show_damage_number(damage, true)  # player اتضرب

	if is_crit:
		await show_enemy_crit()

	if is_defending:
		damage /= 2
		is_defending = false
		$AnimationPlayer.play("mini_shake")
	else:
		$AnimationPlayer.play("shake")

	damage = result["damage"]
	current_player_health -= damage
	set_health($HP2/ProgressBar, current_player_health, State.max_health)

	await $AnimationPlayer.animation_finished

	if current_player_health <= 0:
		$AnimationPlayer.play("player_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		get_tree().quit()
	else:
		await get_tree().create_timer(1.0).timeout  # ⏳ فاصل بين الأدوار
		await show_player_turn()
		


func _on_attack_pressed() -> void:

	$UIAnimationPlayer.play("fade_out_ui")
	await $UIAnimationPlayer.animation_finished
	
	# الحسابات والضرب
	var result = DamageCalculator.calculate_damage(State.damage, 4, 3)
	var damage = result.damage
	var is_extra_turn = result.is_extra_turn
	show_damage_number(damage, false)

	current_enemy_health = max(0, current_enemy_health - damage)
	set_health($HP/ProgressBar, current_enemy_health, enemy.health)

	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished

	if current_enemy_health <= 0:
		$AnimationPlayer.play("enemy_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(0.25).timeout
		get_tree().quit()
		return

	if is_extra_turn:
		print("🎁 Extra Turn - damage =", damage)
		show_extra_turn()
		return

	await show_enemy_turn()


	$UIAnimationPlayer.play("fade_in_ui")
	await $UIAnimationPlayer.animation_finished

	_enemy_turn()



	


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

	# أضف العنصر داخل شريط الصحة المناسب
	if is_player:
		$HP2.add_child(damage_label)
		damage_label.position = Vector2(100, -30)  # يمين فوق شريط اللاعب
	else:
		$HP.add_child(damage_label)
		damage_label.position = Vector2(100, -30)  # يمين فوق شريط العدو

	# شغل الأنيميشن
	damage_label.get_node("AnimationPlayer").play("popup")


#func _on_guard_pressed() -> void:
	#is_defending = true
	#_enemy_turn()

extends Node
class_name DamageCalculator

static func calculate_damage(
	move_power: int,
	attacker_stat: int,
	defender_stat: int,
	extra_turn_range: Vector2 = Vector2(18, 22)
) -> Dictionary:
	var base_damage = move_power * (attacker_stat / float(defender_stat)) * 0.85

	var is_crit = randi() % 100 < 8
	if is_crit:
		base_damage *= 1.8

	var rng = randf_range(0.85, 1.15)
	var final_damage = base_damage * rng
	var damage = round(final_damage)

	var in_extra_range = damage >= extra_turn_range.x and damage <= extra_turn_range.y

	return {
		"damage": damage,
		"is_extra_turn": in_extra_range,
		"is_crit": is_crit  # ✅ أضفنا ده
	}

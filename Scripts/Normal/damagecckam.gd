extends Node
class_name damagecckam

static func calculate_damage(
	move_power: int,
	attacker_stat: int,
	defender_stat: int
) -> Dictionary:
	var base_damage = move_power * (attacker_stat / float(defender_stat)) * 0.85
	var rng = randf_range(0.85, 1.15)
	var final_damage = base_damage * rng
	var damage = round(final_damage)

	return {
		"damage": damage
	}

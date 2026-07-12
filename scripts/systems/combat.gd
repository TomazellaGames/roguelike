class_name Combat
extends RefCounted

## Resolves one melee attack: rolls for a player crit, applies damage, wears down
## attacker/defender equipment (breaking and unequipping at 0 durability), and
## awards gold if the defender dies to the player. Returns a log message.
static func resolve_attack(attacker: Entity, defender: Entity) -> String:
	var is_crit := false
	if attacker.is_player:
		var crit_mult: float = attacker.weapon["crit_mult"] if (attacker.weapon != null and attacker.weapon.has("crit_mult")) else 1.0
		is_crit = randf() < attacker.crit_chance * crit_mult

	var dmg: int
	if is_crit:
		dmg = max(1, attacker.atk * 2)
	else:
		dmg = max(1, attacker.atk - defender.defense)
	defender.hp -= dmg
	var hit_verb := "hit" if attacker.is_player else "hits"
	var msg := "%s %s %s for %d damage." % [attacker.display_name.capitalize(), hit_verb, defender.display_name, dmg]
	if is_crit:
		msg += " Critical hit!"

	if attacker.weapon != null:
		attacker.weapon["durability"] -= 1
		if attacker.weapon["durability"] <= 0:
			msg += " Your %s breaks!" % attacker.weapon["name"]
			attacker.unequip_weapon()

	if defender.armor != null:
		defender.armor["durability"] -= 1
		if defender.armor["durability"] <= 0:
			msg += " Your %s breaks!" % defender.armor["name"]
			defender.unequip_armor()

	if defender.hp <= 0:
		var die_verb := "die" if defender.is_player else "dies"
		msg += " %s %s!" % [defender.display_name.capitalize(), die_verb]
		if attacker.is_player and not defender.is_player:
			var gold := randi_range(defender.gold_min, defender.gold_max)
			attacker.gold += gold
			msg += " You find %d gold." % gold
	return msg

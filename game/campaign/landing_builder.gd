class_name LandingBuilder
extends RefCounted
## Turns a LandingPlan into the LandingModifiers a mission starts with (ADR 0012):
## the campaign's start locks, then every owned tech's effects, the loadout's, and
## those of discoveries made on earlier landings (carryovers), in that order.


## The modifiers for landing `plan` of campaign `def`.
static func build(def: CampaignDef, plan: LandingPlan) -> LandingModifiers:
	var modifiers: LandingModifiers = LandingModifiers.new()
	modifiers.difficulty = Difficulty.sanitize(plan.difficulty)
	for id: StringName in def.locked_at_start:
		modifiers.perks.lock(id)
	for tech_id: StringName in plan.techs:
		var tech: TechDef = def.tech(tech_id)
		if tech != null:
			for effect: PerkEffect in tech.effects:
				apply(effect, modifiers, tech.title)
	for slot_id: StringName in plan.loadout:
		var slot: LoadoutSlotDef = def.slot(slot_id)
		var option: LoadoutOptionDef = slot.option(plan.loadout[slot_id]) if slot != null else null
		if option != null:
			for effect: PerkEffect in option.effects:
				apply(effect, modifiers, option.title)
	for carry: CarryoverDef in def.carryovers:
		if carry != null and plan.discoveries.has(carry.discovery):
			for effect: PerkEffect in carry.effects:
				apply(effect, modifiers, carry.description)
	return modifiers


## Adds `effect` to `modifiers`; `source` names it in the briefing notes.
static func apply(effect: PerkEffect, modifiers: LandingModifiers, source: String) -> void:
	if effect == null:
		return
	match effect.kind:
		PerkEffect.KIND_UNLOCK:
			modifiers.perks.unlock(effect.target)
		PerkEffect.KIND_SCALE:
			modifiers.perks.add_scale(effect.target, effect.stat, effect.factor)
		PerkEffect.KIND_UNITS:
			if effect.unit != null:
				for i: int in effect.count:
					modifiers.extra_roster.append(effect.unit)
		PerkEffect.KIND_RESOURCES:
			modifiers.bonus_alloy += effect.alloy
			modifiers.bonus_flux += effect.flux
			modifiers.bonus_intel += effect.intel
		PerkEffect.KIND_UNLOCK_OPTION:
			if not modifiers.unlocked_options.has(effect.target):
				modifiers.unlocked_options.append(effect.target)
		PerkEffect.KIND_CHARGE_OPTION:
			var held: int = modifiers.option_charges.get(effect.target, 0)
			modifiers.option_charges[effect.target] = held + effect.count
		PerkEffect.KIND_CHART_SITE:
			if not modifiers.charted_sites.has(effect.target):
				modifiers.charted_sites.append(effect.target)
	var line: String = describe(effect)
	if line != "":
		modifiers.notes.append("%s: %s" % [source, line] if source != "" else line)


## One line for `effect`: its own note, or one made from its data.
static func describe(effect: PerkEffect) -> String:
	if effect.note != "":
		return effect.note
	var line: String = ""
	match effect.kind:
		PerkEffect.KIND_UNLOCK:
			line = "%s available" % pretty(effect.target)
		PerkEffect.KIND_SCALE:
			var percent: int = roundi((effect.factor - 1.0) * 100.0)
			var who: String = pretty(effect.target) + " " if effect.target != &"" else ""
			line = "%s%s %+d%%" % [who, pretty(effect.stat).to_lower(), percent]
		PerkEffect.KIND_UNITS:
			var unit_name: String = effect.unit.display_name if effect.unit != null else "?"
			line = "+%d %s" % [effect.count, unit_name]
		PerkEffect.KIND_RESOURCES:
			var parts: PackedStringArray = []
			if effect.alloy != 0:
				parts.append("%+d Alloy" % effect.alloy)
			if effect.flux != 0:
				parts.append("%+d Flux" % effect.flux)
			if effect.intel != 0:
				parts.append("%+d Intel" % effect.intel)
			line = ", ".join(parts)
		PerkEffect.KIND_UNLOCK_OPTION:
			line = "%s ready from the start" % pretty(effect.target)
		PerkEffect.KIND_CHARGE_OPTION:
			line = "%d free %s" % [effect.count, pretty(effect.target)]
		PerkEffect.KIND_CHART_SITE:
			line = "%s charted" % pretty(effect.target)
	return line


## "concord_survey_lab" -> "Survey Lab".
static func pretty(id: StringName) -> String:
	var text: String = String(id)
	for prefix: String in ["concord_", "kessel_", "thalassa_"]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	return text.replace("_", " ").capitalize()

class_name LandingModifiers
extends RefCounted
## What the player brings into one landing from outside it (ADR 0012): the perks the
## sim applies (locked entity types, stat scales), extra starting units and
## resources, field options unlocked or charged in advance, and discovery sites the
## orbital scan already charted from an earlier landing. The campaign builds it from
## its tech web, loadout and codex; a mission without one plays its MissionDef as is.

## Locks and stat scales for the player's faction.
var perks: FactionPerks = FactionPerks.new()
## Units that land with the player's starting crew.
var extra_roster: Array[UnitDef] = []
var bonus_alloy: int = 0
var bonus_flux: int = 0
var bonus_intel: int = 0
## Field option ids unlocked from the start (as if their discovery had been made).
var unlocked_options: Array[StringName] = []
## Field option id -> free uses (no Intel, no cooldown).
var option_charges: Dictionary[StringName, int] = {}
## Discovery ids whose sites start charted even when a chain would hide them.
var charted_sites: Array[StringName] = []
## The difficulty the player chose (Difficulty.LEVELS), or &"" to play the mission
## as designed. It shifts the enemy commander's level (Difficulty.effective).
var difficulty: StringName = &""
## One line per effect, for the briefing ("+2 Rangers", "Hauler carry +25%").
var notes: PackedStringArray = PackedStringArray()


## True if the site of discovery `id` starts charted.
func charts(id: StringName) -> bool:
	return charted_sites.has(id)


## Applies what belongs to the world before anything spawns (`faction` is the
## player's): perks, resources, field options.
func apply_to_world(world: SimWorld, faction: int) -> void:
	world.perks[faction] = perks
	if bonus_alloy != 0 or bonus_flux != 0:
		world.economy.add(faction, bonus_alloy, bonus_flux)
	if bonus_intel > 0:
		world.economy.add_intel(faction, bonus_intel)
	var options: FieldOptions = world.discovery.field_options if world.discovery != null else null
	if options == null:
		return
	for id: StringName in unlocked_options:
		options.unlock(faction, id)
	for id: StringName in option_charges:
		options.add_charges(faction, id, option_charges[id])

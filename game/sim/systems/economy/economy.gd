class_name Economy
extends RefCounted
## Every faction's Stockpile for one mission, plus the rules that govern them.
## Announces changes on `Events` (resources_changed, power_changed, intel_changed)
## and raises
## Advisor alerts for the player's faction only. Registered on the MissionContext
## as `SERVICE_KEY` by SimWorld.

const SERVICE_KEY: StringName = &"economy"
const SAVE_VERSION: int = 1

var rules: EconomyRules
var player_faction: int = 0
## Share of their power output buildings that are not Antecedent machines give (a
## planet rule may cut it: Hollow Meridian, ADR 0017).
var power_scale: float = 1.0

var _stockpiles: Dictionary[int, Stockpile] = {}


func _init(p_rules: EconomyRules = null, p_player_faction: int = 0) -> void:
	rules = p_rules if p_rules != null else EconomyRules.new()
	player_faction = p_player_faction


## The faction's stockpile, created with the starting resources on first use.
func stockpile(faction: int) -> Stockpile:
	if not _stockpiles.has(faction):
		_stockpiles[faction] = Stockpile.new(rules.start_alloy, rules.start_flux)
	return _stockpiles[faction]


func can_afford(faction: int, def: EntityDef) -> bool:
	return stockpile(faction).can_afford(def.cost_alloy, def.cost_flux)


## Pays for `def`. On failure nothing is taken and, for the player, the Advisor
## says so. Returns true when paid.
func pay(faction: int, def: EntityDef) -> bool:
	if not stockpile(faction).spend(def.cost_alloy, def.cost_flux):
		if faction == player_faction:
			Events.advisor_alert.emit(&"insufficient_resources")
		return false
	_announce_resources(faction)
	return true


## Returns `share` of the cost of `def` (rounded down).
func refund(faction: int, def: EntityDef, share: float = 1.0) -> void:
	add(faction, floori(def.cost_alloy * share), floori(def.cost_flux * share))


func add(faction: int, alloy: int, flux: int) -> void:
	if alloy == 0 and flux == 0:
		return
	stockpile(faction).add(alloy, flux)
	_announce_resources(faction)


## A hauler unloaded `amount` Alloy at a drop-off.
func deliver(hauler: Unit, amount: int) -> void:
	if amount <= 0:
		return
	add(hauler.faction, amount, 0)
	Events.harvest_delivered.emit(hauler, amount)


## Adds Intel (discoveries) and announces the new total.
func add_intel(faction: int, amount: int) -> void:
	if amount == 0:
		return
	stockpile(faction).add_intel(amount)
	Events.intel_changed.emit(faction, stockpile(faction).intel)


## Pays `amount` Intel. On failure nothing is taken. Returns true when paid.
func spend_intel(faction: int, amount: int) -> bool:
	if not stockpile(faction).spend_intel(amount):
		return false
	Events.intel_changed.emit(faction, stockpile(faction).intel)
	return true


## Speed factor for the faction's construction, production and tapping.
func work_rate(faction: int) -> float:
	return stockpile(faction).work_rate(rules.low_power_rate)


## Sets the faction's power balance; announces it when it changed and alerts the
## player when power runs short or is restored.
func set_power(faction: int, produced: int, used: int) -> void:
	var pile: Stockpile = stockpile(faction)
	if pile.power_produced == produced and pile.power_used == used:
		return
	var was_low: bool = pile.is_low_power()
	pile.power_produced = produced
	pile.power_used = used
	Events.power_changed.emit(faction, produced, used)
	if faction != player_faction or was_low == pile.is_low_power():
		return
	Events.advisor_alert.emit(&"low_power" if pile.is_low_power() else &"power_restored")


## Recomputes every faction's power from its operational buildings. Factions
## that lost their last building drop to zero.
func update_power(buildings: Array[Building]) -> void:
	var totals: Dictionary[int, Vector2i] = {}
	for faction: int in _stockpiles:
		totals[faction] = Vector2i.ZERO
	for building: Building in buildings:
		if building.def == null or not building.is_operational() or building.is_dead:
			continue
		var total: Vector2i = totals.get(building.faction, Vector2i.ZERO)
		var output: int = building.def.power_output
		if not building.def.machine:
			output = roundi(output * power_scale)
		total += Vector2i(output, building.def.power_use)
		totals[building.faction] = total
	for faction: int in totals:
		set_power(faction, totals[faction].x, totals[faction].y)


func to_dict() -> Dictionary:
	var piles: Dictionary = {}
	for faction: int in _stockpiles:
		piles[str(faction)] = _stockpiles[faction].to_dict()
	return {"version": SAVE_VERSION, "stockpiles": piles}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version == SAVE_VERSION, "Unsupported Economy save version")
	_stockpiles.clear()
	var piles: Dictionary = data.get("stockpiles", {})
	for key: Variant in piles:
		var faction_text: String = key
		var pile_data: Dictionary = piles[key]
		var pile: Stockpile = Stockpile.new()
		pile.from_dict(pile_data)
		_stockpiles[faction_text.to_int()] = pile
		_announce_resources(faction_text.to_int())
		Events.intel_changed.emit(faction_text.to_int(), pile.intel)


func _announce_resources(faction: int) -> void:
	var pile: Stockpile = stockpile(faction)
	Events.resources_changed.emit(faction, pile.alloy, pile.flux)

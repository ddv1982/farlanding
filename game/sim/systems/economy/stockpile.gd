class_name Stockpile
extends RefCounted
## One faction's resources: the Alloy, Flux and Intel stockpiles and the Power balance.
## Pure arithmetic; Economy wraps it and announces changes.

const SAVE_VERSION: int = 2

var alloy: int = 0
var flux: int = 0
## Earned only by discovery (PLAN 1); spent on field options.
var intel: int = 0
## Power capacity from operational producers (Lander, Reactors).
var power_produced: int = 0
## Power drawn by operational consumers.
var power_used: int = 0


func _init(p_alloy: int = 0, p_flux: int = 0) -> void:
	alloy = p_alloy
	flux = p_flux


func can_afford(cost_alloy: int, cost_flux: int) -> bool:
	return alloy >= cost_alloy and flux >= cost_flux


## Takes the cost if it can be paid in full. Returns false (and takes nothing) if not.
func spend(cost_alloy: int, cost_flux: int) -> bool:
	if not can_afford(cost_alloy, cost_flux):
		return false
	alloy -= cost_alloy
	flux -= cost_flux
	return true


func add(p_alloy: int, p_flux: int) -> void:
	alloy = maxi(alloy + p_alloy, 0)
	flux = maxi(flux + p_flux, 0)


## Adds (or with a negative amount takes) Intel; never below zero.
func add_intel(amount: int) -> void:
	intel = maxi(intel + amount, 0)


## Takes `amount` Intel if there is that much. Returns false (and takes nothing) if not.
func spend_intel(amount: int) -> bool:
	if amount > intel:
		return false
	intel -= amount
	return true


## True while more power is drawn than produced.
func is_low_power() -> bool:
	return power_used > power_produced


## Speed factor for construction, production and tapping: 1, or `low_rate` on low power.
func work_rate(low_rate: float) -> float:
	return low_rate if is_low_power() else 1.0


## What is missing to pay a cost, e.g. "Need 40 more Alloy"; "" if affordable.
func shortfall_text(cost_alloy: int, cost_flux: int) -> String:
	var parts: PackedStringArray = []
	if alloy < cost_alloy:
		parts.append("%d more Alloy" % (cost_alloy - alloy))
	if flux < cost_flux:
		parts.append("%d more Flux" % (cost_flux - flux))
	if parts.is_empty():
		return ""
	return "Need " + " and ".join(parts)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"alloy": alloy,
		"flux": flux,
		"intel": intel,
		"power_produced": power_produced,
		"power_used": power_used,
	}


func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported Stockpile save version")
	alloy = data.get("alloy", 0)
	flux = data.get("flux", 0)
	intel = data.get("intel", 0)
	power_produced = data.get("power_produced", 0)
	power_used = data.get("power_used", 0)

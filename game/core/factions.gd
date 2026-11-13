class_name Factions
extends RefCounted
## Fixed faction numbers. Missions choose the player's and the Combine's numbers in
## data; the Custodians (PLAN 2.1) are always this one neutral faction: no base, no
## economy, and never counted by win/lose rules or by an enemy commander.

const CUSTODIANS: int = 2


## True for the neutral Custodians.
static func is_custodian(faction: int) -> bool:
	return faction == CUSTODIANS

class_name CampaignDef
extends Resource
## A whole campaign as data (ADR 0012): the route of landings, the tech web, the
## loadout slots, what starts locked, and what discoveries carry over.

@export var id: StringName = &""
@export var title: String = ""
@export var nodes: Array[RouteNodeDef] = []
## The node open at the start.
@export var start_node: StringName = &""
@export var techs: Array[TechDef] = []
@export var loadout_slots: Array[LoadoutSlotDef] = []
@export var carryovers: Array[CarryoverDef] = []
## Entity types and field options the player cannot field until a tech unlocks them.
@export var locked_at_start: Array[StringName] = []
## Share of the stockpiled Intel a lost landing still banks (0 = none).
@export_range(0.0, 1.0, 0.05) var lost_landing_share: float = 0.0
## The landing that ends the campaign once won (the Beacon Core, ADR 0017); &"" = none.
@export var final_node: StringName = &""


func node(node_id: StringName) -> RouteNodeDef:
	for found: RouteNodeDef in nodes:
		if found != null and found.id == node_id:
			return found
	return null


func tech(tech_id: StringName) -> TechDef:
	for found: TechDef in techs:
		if found != null and found.id == tech_id:
			return found
	return null


func slot(slot_id: StringName) -> LoadoutSlotDef:
	for found: LoadoutSlotDef in loadout_slots:
		if found != null and found.id == slot_id:
			return found
	return null

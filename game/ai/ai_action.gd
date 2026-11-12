class_name AiAction
extends RefCounted
## One thing the commander's brain decided to do. The Commander turns each into
## Commands on the CommandQueue (or into a unit behaviour that issues them), so the
## brain stays a pure function of a CommanderView.

const PRODUCE: StringName = &"produce"
const BUILD: StringName = &"build"
const HARVEST: StringName = &"harvest"
const ASSIST: StringName = &"assist"
const SCOUT: StringName = &"scout"
const ATTACK: StringName = &"attack"
const DEFEND: StringName = &"defend"
const RECALL: StringName = &"recall"

var kind: StringName = &""
## The unit or building type to produce or build.
var def: EntityDef = null
## A producer (PRODUCE) or a site to help build (ASSIST).
var building: Building = null
var units: Array[Unit] = []
## Where to go (ATTACK, DEFEND) or near where to build (BUILD).
var position: Vector3 = Vector3.ZERO
## Alloy and Flux this action spends.
var cost_alloy: int = 0
var cost_flux: int = 0
## Why, for logs and tests (e.g. &"opening", &"economy", &"defence").
var reason: StringName = &""


func _init(p_kind: StringName = &"", p_reason: StringName = &"") -> void:
	kind = p_kind
	reason = p_reason


func _to_string() -> String:
	var what: String = String(def.id) if def != null else ""
	return "%s(%s %s, %d units)" % [kind, reason, what, units.size()]

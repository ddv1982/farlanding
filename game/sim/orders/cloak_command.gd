class_name CloakCommand
extends Command
## Switches stealth mode of cloak-capable units (Wisps) on (creep and cloak) or off
## (full speed, no cloak). Other receivers ignore it.

const KIND: StringName = &"cloak"

## Stealth mode wanted.
var enabled: bool = true


func _init(
	p_issuer_faction: int = 0, p_entities: Array[Node3D] = [], p_enabled: bool = true
) -> void:
	super(KIND, p_issuer_faction, p_entities)
	enabled = p_enabled


func execute() -> void:
	for entity: Node3D in entities:
		var unit: Unit = entity as Unit
		if unit != null and unit.faction == issuer_faction and unit.cloak != null:
			unit.cloak.set_stealth_mode(enabled)

class_name FieldOptionCommand
extends Command
## Use a Survey Lab field option (`option`) at `target_position`. The receiver is the
## lab (an operational building of the issuing faction that offers the option); the
## Intel is paid when the command runs. `refused` tells why nothing happened.

const KIND: StringName = &"field_option"

var option: FieldOptionDef
## Why the option was not used: a FieldOptions reason, or empty once used (or not run).
var refused: StringName = &""


func _init(
	p_issuer_faction: int = 0,
	p_lab: Node3D = null,
	p_option: FieldOptionDef = null,
	p_point: Vector3 = Vector3.ZERO,
) -> void:
	var receivers: Array[Node3D] = []
	if p_lab != null:
		receivers.append(p_lab)
	super(KIND, p_issuer_faction, receivers)
	option = p_option
	target_position = p_point


func execute() -> void:
	var lab: Building = entities[0] as Building if not entities.is_empty() else null
	if (
		lab == null
		or lab.faction != issuer_faction
		or not lab.is_operational()
		or lab.is_dead
		or option == null
		or not lab.def.field_options.has(option)
		or lab.world == null
	):
		refused = FieldOptions.NO_LAB
	else:
		refused = lab.world.discovery.field_options.use(issuer_faction, option, target_position)
	if refused != FieldOptions.OK and lab != null and issuer_faction == _player_of(lab):
		Events.ui_feedback.emit(&"invalid")


static func _player_of(lab: Building) -> int:
	return lab.world.player_faction if lab.world != null else -1

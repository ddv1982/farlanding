class_name VentCommand
extends Command
## Vents the Flux Taps' vents on purpose (Emberfall, ADR 0015): a small controlled
## burst that empties the pressure, hurts only the Tap a little and starts a cooldown.
## Receivers that are not the issuer's Taps on an erupting vent, or that the planet's
## EruptionSystem refuses (pressure too low, cooling down, a surge running), are
## skipped. The player hears `ui_feedback` &"vent_release" when one vented and
## &"vent_denied" when none could.

const KIND: StringName = &"vent"

## Taps that vented when the command ran.
var vented: Array[Building] = []
## The EruptionSystem's reason for the last refusal (EruptionSystem.OK if none).
var refused: StringName = EruptionSystem.OK


func _init(p_issuer_faction: int = 0, p_entities: Array[Node3D] = []) -> void:
	super(KIND, p_issuer_faction, p_entities)


func execute() -> void:
	var player: bool = false
	for entity: Node3D in entities:
		var tap: Building = entity as Building
		if tap == null or tap.faction != issuer_faction or tap.world == null:
			refused = EruptionSystem.NOT_A_TAP
			continue
		player = player or tap.faction == tap.world.player_faction
		var eruptions: EruptionSystem = tap.world.planet as EruptionSystem
		if eruptions == null:
			refused = EruptionSystem.NOT_A_TAP
			continue
		var reason: StringName = eruptions.can_vent(tap)
		if reason == EruptionSystem.OK and eruptions.vent(tap):
			vented.append(tap)
		else:
			refused = reason
	if not player:
		return
	Events.ui_feedback.emit(&"vent_release" if not vented.is_empty() else &"vent_denied")

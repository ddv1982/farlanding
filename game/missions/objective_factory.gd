class_name ObjectiveFactory
extends RefCounted
## Turns an ObjectiveDef into the Objective class its `type` names.


static func create(def: ObjectiveDef) -> Objective:
	var objective: Objective = null
	match def.type:
		ObjectiveDef.TYPE_DESTROY_ALL:
			objective = DestroyAllObjective.new()
		ObjectiveDef.TYPE_DESTROY_COUNT:
			objective = DestroyCountObjective.new()
		ObjectiveDef.TYPE_KEEP_ALIVE:
			objective = KeepAliveObjective.new()
		ObjectiveDef.TYPE_REACH_AREA:
			objective = ReachAreaObjective.new()
		ObjectiveDef.TYPE_GATHER_INTEL:
			objective = GatherIntelObjective.new()
		ObjectiveDef.TYPE_SURVIVE:
			objective = SurviveObjective.new()
		ObjectiveDef.TYPE_STAY_UNDETECTED:
			objective = StayUndetectedObjective.new()
		ObjectiveDef.TYPE_SCAN_SITES:
			objective = ScanSitesObjective.new()
		ObjectiveDef.TYPE_SABOTAGE:
			objective = SabotageObjective.new()
		ObjectiveDef.TYPE_RIVAL_INTEL:
			objective = RivalIntelObjective.new()
		ObjectiveDef.TYPE_CARRY_TO:
			objective = CarryToObjective.new()
		ObjectiveDef.TYPE_KEEP_FROM_ENEMY:
			objective = KeepFromEnemyObjective.new()
		_:
			push_error("ObjectiveFactory: unknown objective type '%s'" % def.type)
			return null
	objective.configure(def)
	return objective

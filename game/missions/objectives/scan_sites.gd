class_name ScanSitesObjective
extends Objective
## Achieved when the player has resolved the listed discovery sites (every one of
## `site_ids`), or any `amount` sites when none are listed.


func _evaluate() -> void:
	var resolved: int = 0
	var needed: int = def.site_ids.size() if not def.site_ids.is_empty() else def.amount
	for site: DiscoverySite in mission.world.discovery.sites:
		if not is_instance_valid(site) or site.resolved_by != mission.player_faction:
			continue
		if def.site_ids.is_empty() or def.site_ids.has(site.def.id):
			resolved += 1
	set_progress("%d / %d scanned" % [mini(resolved, needed), needed])
	if resolved >= needed:
		complete()

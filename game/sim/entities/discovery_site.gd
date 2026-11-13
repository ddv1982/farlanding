class_name DiscoverySite
extends Node3D
## A discovery site on the map (PLAN 2.4): first an unresolved signal the orbital scan
## charted (a "?" the player sees even under fog), resolved when a Surveyor has
## scanned it for its DiscoveryDef's scan time. Neutral: it belongs to no faction.
## Sites in a chain start uncharted (hidden, not scannable) until the site leading to
## them is resolved. Spawned by SimWorld; scanning is driven by Scanner components and
## resolving by the Discovery system. The scene's Visual (a SiteVisual) follows the
## signals below.

## Scan progress changed, in [0, 1] (0 = nobody scanning).
signal scan_progress_changed(progress: float)
## The site was resolved (or restored resolved).
signal resolved_changed(resolved: bool)
## Colour of the discovery type, for the visual.
signal discovery_color_changed(color: Color)

## 2: scan progress saved (a scan in progress survives a load).
const SAVE_VERSION: int = 2
const GROUP: StringName = &"discovery_sites"

var def: DiscoveryDef
## Save id, unique within the mission; -1 until spawned.
var entity_id: int = -1
## Share of the scan done, in [0, 1].
var scan_progress: float = 0.0
## The faction that resolved it, or -1.
var resolved_by: int = -1
## The orbital scan charted its signal (false for a chain site not yet led to).
var charted: bool = true
## False while the player cannot see the site's ground now. Read by audio and UI.
var is_visible_to_player: bool = true

## Read by audio and UI.
var is_resolved: bool:
	get:
		return resolved_by >= 0
var is_being_scanned: bool:
	get:
		return not _scanners.is_empty() and not is_resolved
var discovery_type: StringName:
	get:
		return def.discovery_type if def != null else &""
## The player knows a signal is here (it was charted), resolved or not.
var is_signal_known_to_player: bool:
	get:
		return charted

## Units scanning it now.
var _scanners: Array[Unit] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(p_def: DiscoveryDef, p_charted: bool) -> void:
	def = p_def
	charted = p_charted
	visible = charted


func _ready() -> void:
	if def != null:
		discovery_color_changed.emit(def.color)
	resolved_changed.emit(is_resolved)


## True if `faction` may scan it now: charted and not resolved.
func can_be_scanned() -> bool:
	return charted and not is_resolved and def != null


## Ground area blocked for movement and kept free of buildings (world X/Z).
func blocked_area() -> Rect2:
	var half: float = def.radius * 0.6
	return Rect2(position.x - half, position.z - half, half * 2.0, half * 2.0)


## `scanner` started scanning. Returns true if it is the first one.
func add_scanner(scanner: Unit) -> bool:
	if _scanners.has(scanner):
		return false
	_scanners.append(scanner)
	return _scanners.size() == 1


## `scanner` stopped. When the last one leaves before the scan is done, the progress
## is lost. Returns true if that happened (the scan was interrupted).
func remove_scanner(scanner: Unit) -> bool:
	if not _scanners.has(scanner):
		return false
	_scanners.erase(scanner)
	if not _scanners.is_empty() or is_resolved:
		return false
	set_scan_progress(0.0)
	return true


## Units scanning it now.
func scanners() -> Array[Unit]:
	return _scanners.duplicate()


func set_scan_progress(progress: float) -> void:
	scan_progress = clampf(progress, 0.0, 1.0)
	scan_progress_changed.emit(scan_progress)


## Charts the signal (a chain led here): it shows and can be scanned.
func chart() -> void:
	charted = true
	visible = true


## Marks it resolved by `faction`.
func resolve(faction: int) -> void:
	resolved_by = faction
	scan_progress = 1.0
	_scanners.clear()
	resolved_changed.emit(true)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"def": def.resource_path if def != null else "",
		"entity_id": entity_id,
		"position": var_to_str(position),
		"charted": charted,
		"resolved_by": resolved_by,
		"progress": scan_progress,
	}


## Restores the state; a scan in progress is not saved (it starts over).
func from_dict(data: Dictionary) -> void:
	var version: int = data.get("version", 0)
	assert(version >= 1 and version <= SAVE_VERSION, "Unsupported DiscoverySite save version")
	entity_id = data.get("entity_id", entity_id)
	charted = data.get("charted", charted)
	visible = charted
	resolved_by = data.get("resolved_by", -1)
	var progress: float = data.get("progress", 0.0)
	scan_progress = 1.0 if is_resolved else clampf(progress, 0.0, 1.0)
	resolved_changed.emit(is_resolved)
	scan_progress_changed.emit(scan_progress)

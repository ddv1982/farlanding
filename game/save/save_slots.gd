class_name SaveSlots
extends RefCounted
## Where saved landings live (ADR 0013): `user://saves/`, one file per slot — the
## quicksave (F5 / F9), the autosave made when a landing starts, and three manual
## slots. A file is a short header (magic, format version, SHA-256 of the payload)
## and the payload (`var_to_str` of `SaveGame.to_dict()`, so ints stay ints). It is
## written to a temporary file and renamed over the slot, so a crash mid-write
## leaves the old save intact. Reading checks the header and the hash before the
## payload is parsed: a damaged or truncated file is refused with a message, never
## half-read. `last_error` says why the last read or write failed.

const DIR: String = "user://saves/"
const EXTENSION: String = ".save"
const MAGIC: String = "FARLANDING_SAVE"
const QUICKSAVE: StringName = &"quicksave"
## The autosave made as a landing starts (not the campaign's own autosave).
const AUTOSAVE: StringName = &"autosave_landing"
const MANUAL: Array[StringName] = [&"manual_1", &"manual_2", &"manual_3"]

## Where saves go (tests point it elsewhere, like `CampaignSession.default_path`).
static var default_dir: String = DIR
## Why the last `read()` or `write()` failed ("" after a success).
static var last_error: String = ""


## Every slot, in the order the slot list shows them.
static func slots() -> Array[StringName]:
	var all: Array[StringName] = [QUICKSAVE, AUTOSAVE]
	all.append_array(MANUAL)
	return all


## Slots a player may save into from the menu (the autosave is written by the game).
static func writable_slots() -> Array[StringName]:
	var all: Array[StringName] = [QUICKSAVE]
	all.append_array(MANUAL)
	return all


static func path_of(slot: StringName) -> String:
	return default_dir.path_join(String(slot) + EXTENSION)


static func exists(slot: StringName) -> bool:
	return FileAccess.file_exists(path_of(slot))


## The slot's name for the menu.
static func label_of(slot: StringName) -> String:
	match slot:
		QUICKSAVE:
			return "Quicksave"
		AUTOSAVE:
			return "Landing autosave"
	var index: int = MANUAL.find(slot)
	return "Slot %d" % (index + 1) if index >= 0 else String(slot)


## Writes `game` into `slot`. Returns "" or why it failed (also in `last_error`).
static func write(slot: StringName, game: SaveGame) -> String:
	last_error = ""
	var made: Error = DirAccess.make_dir_recursive_absolute(default_dir)
	if made != OK and not DirAccess.dir_exists_absolute(default_dir):
		return _fail("Cannot create the save folder (%s)." % error_string(made))
	var payload: String = var_to_str(game.to_dict())
	var text: String = (
		"%s %d\n%s\n%s" % [MAGIC, SaveGame.FORMAT_VERSION, payload.sha256_text(), payload]
	)
	var path: String = path_of(slot)
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write the save (%s)." % error_string(FileAccess.get_open_error()))
	file.store_string(text)
	file.close()
	var renamed: Error = DirAccess.rename_absolute(temporary, path)
	if renamed != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Cannot write the save (%s)." % error_string(renamed))
	return ""


## The save in `slot`, or null (with `last_error`) when there is none or it cannot be
## used: damaged, from a newer game, or naming something this build does not have.
static func read(slot: StringName) -> SaveGame:
	var data: Dictionary = read_data(slot)
	if data.is_empty():
		return null
	var problem: String = SaveGame.check(data)
	if problem != "":
		_fail(problem)
		return null
	return SaveGame.from_dict(data)


## The raw dictionary saved in `slot` (empty, with `last_error`, when it cannot be read).
static func read_data(slot: StringName) -> Dictionary:
	last_error = ""
	var path: String = path_of(slot)
	if not FileAccess.file_exists(path):
		_fail("There is no save in %s." % label_of(slot))
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	return parse(text)


## The dictionary in the text of a save file (empty, with `last_error`, if damaged).
static func parse(text: String) -> Dictionary:
	var first: int = text.find("\n")
	var second: int = text.find("\n", first + 1) if first >= 0 else -1
	if first < 0 or second < 0:
		_fail("The save is damaged.")
		return {}
	var header: PackedStringArray = text.substr(0, first).split(" ")
	if header.size() != 2 or header[0] != MAGIC or not header[1].is_valid_int():
		_fail("This is not a Farlanding save.")
		return {}
	var version: int = header[1].to_int()
	if version > SaveGame.FORMAT_VERSION:
		_fail("This save is from a newer version of the game (format %d)." % version)
		return {}
	var digest: String = text.substr(first + 1, second - first - 1)
	var payload: String = text.substr(second + 1)
	if payload.sha256_text() != digest:
		_fail("The save is damaged.")
		return {}
	var value: Variant = str_to_var(payload)
	if not value is Dictionary:
		_fail("The save is damaged.")
		return {}
	var data: Dictionary = value
	return data


## The newest readable save and its slot (`[slot, game]`), or an empty array.
static func newest() -> Array:
	var best: Array = []
	var best_time: int = -1
	for slot: StringName in slots():
		if not exists(slot):
			continue
		var game: SaveGame = read(slot)
		if game != null and game.saved_at > best_time:
			best = [slot, game]
			best_time = game.saved_at
	last_error = ""
	return best


static func remove(slot: StringName) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path_of(slot))


static func _fail(message: String) -> String:
	last_error = message
	return message

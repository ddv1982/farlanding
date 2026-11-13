class_name CarryoverDef
extends Resource
## What a discovery made on one landing changes on the landings after it (ADR 0012):
## the codex remembers it, and every later landing starts with `effects`.

@export var id: StringName = &""
## The discovery id that must be in the campaign's codex.
@export var discovery: StringName = &""
## One line for the briefing and the Meridian.
@export var description: String = ""
@export var effects: Array[PerkEffect] = []

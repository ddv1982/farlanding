class_name TeamColors
extends RefCounted
## Team colour per faction, applied to unit visuals and their selection rings.

const COLORS: Array[Color] = [
	Color(0.25, 0.55, 1.0),  # 0: player (Concord expedition)
	Color(0.1, 0.85, 0.72),  # 1: Halcyon Combine
	Color(0.85, 0.75, 0.45),  # 2: Custodians
]


static func for_faction(faction: int) -> Color:
	if faction >= 0 and faction < COLORS.size():
		return COLORS[faction]
	return Color.WHITE

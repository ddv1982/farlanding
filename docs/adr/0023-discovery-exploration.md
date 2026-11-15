# 0023 — Find discoveries through exploration

- Status: accepted
- Date: 2026-11-15

Discovery sites previously showed floating question marks and minimap markers even
under unexplored fog. Those location spoilers undermined the expedition's exploration.

Unresolved sites now read through their physical models after their ground is explored.
There are no floating question marks and no unresolved-site minimap icons. Completed
player surveys leave coloured minimap records; enemy surveys do not reveal locations.
Scan rings, progress beams, resolved glows, Intel and Survey Log rewards remain.
Orbital campaign previews provide context without revealing the unknown site count.
Survey objectives retain their text and progress, but have no location ring or beacon,
including when an older save carries the former area marker.

`charted` continues to gate discovery chains and simulation scanning availability.
It no longer means the player receives a free location marker. World visibility comes
from the existing persisted VisionGrid, so no new save schema is required. Audio still
uses current sight rather than the explored-ground memory.

Proof: unknown/explored/remembered site visibility, player versus enemy map records,
restored vision and scan-feedback tests, followed by real-map/browser qualification.

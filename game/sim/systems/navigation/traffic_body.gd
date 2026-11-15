class_name TrafficBody
extends RefCounted
## One ground unit as Traffic sees it. Locomotion fills in the first block after every
## tick; Traffic fills in the second at the start of the next.

## Where the unit stands (the height is ignored).
var position: Vector3 = Vector3.ZERO
## The velocity it means to move with this tick; zero while standing.
var velocity: Vector3 = Vector3.ZERO
## The velocity it would move with if nothing were in the way (straight along its
## path); zero while standing. Traffic judges what is in the way by this, so that
## bending away does not make the reason for bending disappear.
var wish: Vector3 = Vector3.ZERO
var radius: float = 0.5
var max_speed: float = 1.0
var acceleration: float = 1.0
var faction: int = 0
## True while it follows a path (an order's, or a step aside).
var moving: bool = false
## True while it moves on an order: only then do standing friends step aside for it. A
## unit that is itself stepping aside (or walking back) drives around them instead, so
## two units never keep making room for each other.
var asks_way: bool = false
## True when it would step aside for a friend coming through: standing with nothing
## to do.
var gives_way: bool = false

## Sideways pull on the travel direction, to pass what is ahead (length 0..MAX_STEER).
var steer: Vector3 = Vector3.ZERO
## Top speed for now, so it does not drive into what is ahead; INF = no limit.
var speed_cap: float = INF
## Shift that takes it out of a body it overlaps.
var push: Vector3 = Vector3.ZERO
## Where to step aside to for a friend coming through; INF = stay.
var give_way_to: Vector3 = Vector3.INF
## True while something drives close by: no time to walk back to its post.
var crowded: bool = false

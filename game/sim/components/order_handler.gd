class_name OrderHandler
extends Node
## A unit component that carries out order kinds UnitOrders cannot do on its own
## (harvesting, building). UnitOrders hands it every order of a kind it `handles()`:
## `begin()` when the order starts, `step()` every sim tick until it returns true
## (done), and `end()` when the order finishes or is replaced. After a saved game is
## loaded, `resume()` reconnects the restored state to the restored order (ADR 0013).

var unit: Unit = null


## Called by the unit once its components are ready.
func setup(p_unit: Unit) -> void:
	unit = p_unit


## Order kinds this handler carries out.
func handles() -> Array[StringName]:
	return []


## Starts `order`. Return false if it cannot be carried out (the order is dropped).
func begin(_order: Order) -> bool:
	return false


## One sim tick of work on `order`. Return true when the order is done.
func step(_order: Order, _dt: float) -> bool:
	return true


## The order finished or was replaced: stop whatever it was doing.
func end(_order: Order) -> void:
	pass


## A saved game was loaded and `order` (restored, its target already resolved) is
## the unit's current order of a kind this handler does: reconnect the state that
## `from_dict()` restored (saved entity ids) to live entities, so the work goes on.
func resume(_order: Order) -> void:
	pass


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass

class_name EventTrigger
extends Trigger
## Fires on the next sim tick after `source` (any signal, usually one on `Events`) is
## emitted with arguments that pass `filter` (`func(args: Array) -> bool`; none =
## every emission).

var source: Signal
var filter: Callable = Callable()
## The arguments of the emission that fired it.
var last_args: Array = []

var _pending: bool = false
var _relay: Callable = Callable()


func _init(
	p_source: Signal, p_filter: Callable = Callable(), p_action: Callable = Callable()
) -> void:
	source = p_source
	filter = p_filter
	action = p_action


func start(_mission: Mission) -> void:
	_relay = _on_emitted
	if not source.is_null() and not source.is_connected(_relay):
		source.connect(_relay)


func stop() -> void:
	if _relay.is_valid() and not source.is_null() and source.is_connected(_relay):
		source.disconnect(_relay)


func update(_mission: Mission) -> void:
	if not _pending:
		return
	_pending = false
	if has_fired() and not repeat:
		return
	fired_count += 1
	if action.is_valid():
		action.call()


# Signals pass up to four arguments here; unused ones stay null.
func _on_emitted(
	a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null
) -> void:
	var args: Array = [a, b, c, d]
	if filter.is_valid() and not filter.call(args):
		return
	last_args = args
	_pending = true

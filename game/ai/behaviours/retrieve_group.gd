class_name RetrieveGroup
extends AiGroup
## A squad the commander sends to take a carriable prop (an artefact) home (ADR 0014,
## the Recovery mission's rival). States:
##
##   fetch -> bring -> fetch ... -> done
##
## *fetch* goes for the prop: lying somewhere (known from orbit) it walks there and
## lifts it (CarryCommand: the member nearest lifts, the rest escort); carried by an
## enemy it can see, it attacks the carrier; carried out of sight, it walks to where it
## last saw it. *bring* walks home with it; if the carrier falls the squad fetches
## again. Done when the prop is gone or the squad is.

const FETCH: StringName = &"fetch"
const BRING: StringName = &"bring"
const DONE: StringName = &"done"
## A member this close to a lying prop gets the order to lift it.
const LIFT_REACH: float = 10.0
## Home counts as reached within this distance.
const HOME_RADIUS: float = 10.0

var cargo: Prop = null
var home: Vector3 = Vector3.ZERO
## Where the prop was last known to be.
var last_known: Vector3 = Vector3.INF


func _init(
	p_port: AiPort, p_profile: CommanderProfile, p_members: Array[Unit], p_cargo: Prop
) -> void:
	super(p_port, p_profile, p_members)
	cargo = p_cargo
	if p_cargo != null:
		last_known = p_cargo.sim_position()
	var me: WeakRef = weakref(self)
	machine.add_state(FETCH, FetchState.new(me))
	machine.add_state(BRING, BringState.new(me))
	machine.add_state(DONE, DoneState.new(me))


func start() -> void:
	machine.start(FETCH)


## True if the faction knows where the prop is now; updates `last_known`.
func cargo_known() -> bool:
	if not is_instance_valid(cargo):
		return false
	if port.known_cargo().has(cargo):
		last_known = cargo.sim_position()
		return true
	return false


## True while one of the squad (or any unit of the faction) carries the prop.
func holding() -> bool:
	return is_instance_valid(cargo) and cargo.carrier_faction() == port.faction


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["cargo"] = Order.entity_id_of(cargo)
	data["home"] = var_to_str(home)
	data["last_known"] = var_to_str(last_known)
	return data


func from_dict(data: Dictionary) -> void:
	var home_text: String = data.get("home", var_to_str(home))
	home = str_to_var(home_text)
	var known_text: String = data.get("last_known", var_to_str(last_known))
	last_known = str_to_var(known_text)
	super(data)


class GroupState:
	extends State

	var _group: WeakRef

	func _init(group: WeakRef) -> void:
		_group = group

	func group() -> RetrieveGroup:
		var value: Variant = _group.get_ref()
		if value == null:
			return null
		var found: RetrieveGroup = value
		return found


class FetchState:
	extends GroupState

	func enter(_previous: StringName) -> void:
		var g: RetrieveGroup = group()
		g.cargo_known()
		if g.last_known != Vector3.INF:
			g.order_move(g.last_known)

	func tick(_sim_tick: int) -> StringName:
		var g: RetrieveGroup = group()
		if not is_instance_valid(g.cargo) or not g.cargo.is_carriable():
			return DONE
		if g.holding():
			return BRING
		var known: bool = g.cargo_known()
		if known and g.cargo.is_carried():
			# An enemy carries it and is in sight: bring the carrier down.
			if g.may_reorder():
				g.order_attack(g.cargo.carrier)
			return &""
		if known and _someone_near(g):
			if g.may_reorder():
				g.port.push(CarryCommand.new(g.port.faction, AiGroup._as_nodes(g.members), g.cargo))
				g.last_order_tick = g.port.now()
			return &""
		if g.idle_share() >= 0.5 and g.may_reorder() and g.last_known != Vector3.INF:
			g.order_move(g.last_known)
		return &""

	func _someone_near(g: RetrieveGroup) -> bool:
		var at: Vector3 = g.cargo.sim_position()
		for unit: Unit in g.members:
			if AiGroup.flat_distance(unit.sim_position(), at) <= LIFT_REACH:
				return true
		return false


class BringState:
	extends GroupState

	func enter(_previous: StringName) -> void:
		group().order_move(group().home)

	func tick(_sim_tick: int) -> StringName:
		var g: RetrieveGroup = group()
		if not is_instance_valid(g.cargo):
			return DONE
		if not g.holding():
			return FETCH
		var carrier: Unit = g.cargo.carrier
		if AiGroup.flat_distance(carrier.sim_position(), g.home) <= HOME_RADIUS:
			return &""
		if (carrier.orders == null or carrier.orders.is_idle()) and g.may_reorder():
			if not g.members.has(carrier):
				g.members.append(carrier)
			g.order_move(g.home)
		return &""


class DoneState:
	extends GroupState

	func enter(_previous: StringName) -> void:
		group().finish()

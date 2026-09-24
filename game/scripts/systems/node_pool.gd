class_name NodePool
extends RefCounted

## **A node that will be needed again is kept, not freed** (2026-09-24).
##
## GDScript has no garbage collector - a `queue_free` is a free at the end of
## the frame - so what a pool saves is not collection pauses but the cost of
## standing a thing up: the allocation, the children, the material, the
## `_ready`. Traced on Act X, the two things this game still stood up and
## tore down by the hundred a second were the loot piece (each death threw
## twenty to fifty nodes on the ground) and the two projectile kinds (two
## nodes a shot, thirty to a hundred shots a second), and the death frames
## in the ledger read +27..+48 nodes each. Everything else a fight throws was
## already a record on a canvas.
##
## **The rule is that a pooled node resets itself.** The park calls
## `reset_for_pool()` on the node as it leaves the field, and every field the
## node carries between uses is that function's responsibility - a stale target, a
## stale trail, a stale "taken" flag is exactly the fault pooling invites, and
## it is invisible to a gate that only counts nodes. `node_pool_check` takes a
## released node back and reads its state, which is the only way to see one.
##
## **Parked in a lot under the root, hidden and not processing** - never left
## in the field, and never left as an orphan. In the field it would keep its
## groups, its process and its draw; as an orphan it would be a leaked
## instance at exit, which every gate's quit reads as a red line, and clearing
## the pool by hand from every gate that ever fires a shot is a list nobody
## would keep. The lot is a child of the root, so the tree frees it at quit
## with everything else. A parked node is out of every group it was in
## (`reset_for_pool` takes it out) and `visible` is off, so nothing that walks
## a group or draws the field can find it.
##
## **A node is parked on a deferred call.** A release happens inside the
## node's own `_process`, inside a tween callback, or inside a signal, and
## `remove_child` from some of those is refused; one rule is easier to hold
## than three. `take` only hands out a node that has actually reached the
## lot, so a node released and asked for again on the same frame is not
## handed back mid-flight. The free list is capped per key, and past the cap
## a node is freed as it always was - a wave wipe must not turn into a
## permanent thousand-node reserve.

## The free list per key.
static var _free: Dictionary = {}
## Allocations and reuses per key, for the gate.
static var _made: Dictionary = {}
static var _reused: Dictionary = {}
## Where parked nodes wait: hidden, not processing, under the root.
static var _lot: Node2D = null


## A node for `key`: a parked one when there is one, else `maker.call()`.
## A reused node has `request_ready()` called, so the next `add_child` runs
## its `_ready` exactly as the first one did.
static func take(key: StringName, maker: Callable) -> Node:
	var lot: Node2D = _parking_lot()
	if _free.has(key):
		var list: Array = _free[key]
		for index: int in range(list.size() - 1, -1, -1):
			var node: Node = list[index] as Node
			if node == null or not is_instance_valid(node):
				list.remove_at(index)
				continue
			if node.get_parent() != lot:
				# Released this frame and not yet parked: it is still in the
				# field, in play as far as the tree is concerned.
				continue
			list.remove_at(index)
			lot.remove_child(node)
			node.set_meta(&"pooled", false)
			node.request_ready()
			_reused[key] = int(_reused.get(key, 0)) + 1
			return node
	var fresh: Node = maker.call() as Node
	_made[key] = int(_made.get(key, 0)) + 1
	return fresh


## Parks `node` for `key`, or frees it when the list is full. The node is
## moved to the lot and reset (`reset_for_pool()`, when it has one) on a
## deferred call, so a release from inside the node's own process is safe
## and the node's last frame is drawn as it was.
static func give(key: StringName, node: Node, cap: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta(&"pooled") and bool(node.get_meta(&"pooled")):
		return
	if not _free.has(key):
		_free[key] = []
	var list: Array = _free[key]
	if list.size() >= cap:
		node.queue_free()
		return
	node.set_meta(&"pooled", true)
	list.append(node)
	_park.call_deferred(node)


## The deferred half of `give`. Untyped on purpose: a node freed between the
## call and the flush arrives as a freed object, and a typed parameter would
## refuse it with an error rather than let the check below skip it.
static func _park(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var child := node as Node
	if child == null or not child.has_meta(&"pooled") or not bool(child.get_meta(&"pooled")):
		return
	var lot: Node2D = _parking_lot()
	var parent: Node = child.get_parent()
	if parent == lot:
		return
	if parent != null:
		parent.remove_child(child)
	# **Reset after leaving, not on release.** A released node keeps its
	# state for the rest of its frame exactly as a freed node kept it until
	# the free - so the last draw is of the shot where it landed, and a
	# harness that reads a shot on `tree_exiting` still reads the flight
	# (`tower_juice_check` reads a lob's peak there). The reset is what the
	# lot receives.
	if child.has_method(&"reset_for_pool"):
		child.call(&"reset_for_pool")
	lot.add_child(child)


static func _parking_lot() -> Node2D:
	if _lot != null and is_instance_valid(_lot):
		return _lot
	_lot = Node2D.new()
	_lot.name = "NodePool"
	_lot.visible = false
	_lot.process_mode = Node.PROCESS_MODE_DISABLED
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_lot)
	return _lot


## Frees every parked node and forgets the counts. For the gates.
static func clear() -> void:
	for key: Variant in _free.keys():
		for node: Variant in _free[key]:
			if node != null and is_instance_valid(node):
				(node as Node).queue_free()
	_free.clear()
	_made.clear()
	_reused.clear()


## How many nodes are parked for `key` right now, counting only those that
## have reached the lot.
static func pooled(key: StringName) -> int:
	var count: int = 0
	var lot: Node2D = _parking_lot()
	for node: Variant in _free.get(key, []):
		if node != null and is_instance_valid(node) and (node as Node).get_parent() == lot:
			count += 1
	return count


static func made(key: StringName) -> int:
	return int(_made.get(key, 0))


static func reused(key: StringName) -> int:
	return int(_reused.get(key, 0))


## The lot itself, for the gate to read a parked node's parent against.
static func lot() -> Node:
	return _parking_lot()

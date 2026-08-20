extends Node

## Snuff a torch, walk the hero to it, and see whether it comes back.
##
## The relight half of this mechanic has never been exercised by anything. The
## snuff half was silently dead twice while reading perfectly correctly, so
## "the code looks right" is not evidence about the other half either.

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	for _f: int in 4:
		await get_tree().process_frame
	var run: Run = _find_run()
	if run != null:
		run._preparation_left = 0.0
		run._on_ride_on_requested()
		run._on_ride_on_requested()
		await get_tree().process_frame

	if not _check_layout():
		_bail(1)
		return

	var torch: Torch = get_tree().get_first_node_in_group(&"torches") as Torch
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if torch == null:
		push_error("no torches in the field")
		_bail(1)
		return
	print("[torch] hero in group=%s" % str(hero != null))
	if hero == null:
		push_error("nothing is in the \"hero\" group - relight can never fire")
		_bail(1)
		return

	# Pressure is gradual and reversible, and the hero can brace a dying flame.
	# Exercise those rules directly so a future refactor cannot quietly turn the
	# mechanic back into an instant proximity switch.
	torch.set_process(false)
	hero.global_position = torch.global_position + Vector2(5000.0, 5000.0)
	torch._strength = 1.0
	torch._pressure = 2.0
	torch._tick_strength(1.0)
	var dimmed: float = torch.light_strength()
	print("[torch] pressure dimmed strength to %.2f" % dimmed)
	if dimmed <= 0.0 or dimmed >= 1.0:
		push_error("torch pressure must weaken a flame gradually")
		_bail(1)
		return
	torch._pressure = 0.0
	torch._tick_strength(1.0)
	if torch.light_strength() <= dimmed:
		push_error("a surviving torch did not recover after pressure cleared")
		_bail(1)
		return

	hero.global_position = torch.global_position
	torch._strength = 0.2
	torch._pressure = Balance.TORCH_PRESSURE_MAX_WEIGHT
	torch._tick_strength(10.0)
	print("[torch] hero brace floor=%.2f lit=%s"
		% [torch.light_strength(), str(torch.is_lit())])
	if not torch.is_lit() or torch.light_strength() < Balance.TORCH_HERO_MIN_STRENGTH:
		push_error("hero presence did not protect the torch's minimum flame")
		_bail(1)
		return

	hero.global_position = torch.global_position + Vector2(5000.0, 5000.0)
	torch._tick_strength(10.0)
	if torch.is_lit():
		push_error("unprotected maximum pressure did not finish snuffing the torch")
		_bail(1)
		return
	torch.set_process(true)

	torch.extinguish()
	await get_tree().process_frame
	print("[torch] snuffed, lit=%s" % str(torch.is_lit()))

	# Stand on it. This is the most generous case there is: if it does not
	# relight here it cannot relight anywhere.
	hero.global_position = torch.global_position
	var distance: float = hero.global_position.distance_to(torch.global_position)
	print("[torch] hero placed at distance %.1f (range %.0f)"
		% [distance, Balance.TORCH_RELIGHT_RANGE])
	print("[torch] torch processing=%s" % str(torch.is_processing()))

	var waited: float = 0.0
	while waited < Balance.TORCH_RELIGHT_TIME * 3.0 and not torch.is_lit():
		await get_tree().process_frame
		waited += get_process_delta_time()
		# Held every frame: the hero is a CharacterBody2D that its own script
		# moves, so placing it once is not enough to keep it there.
		hero.global_position = torch.global_position

	print("[torch] relit=%s after %.2fs (needs %.2fs)"
		% [str(torch.is_lit()), waited, Balance.TORCH_RELIGHT_TIME])
	if not torch.is_lit():
		push_error("a torch the hero is standing on top of did not relight")
		_bail(1)
		return
	_bail(0)


## The field's torches must be spread, symmetric, and off the road.
##
## Placement is three rules interacting - stops along a straight, a corner post
## on the outside of each bend, and a minimum-gap filter over the result - and
## each is correct on its own while the set is what has to come out right. That
## is only checkable by looking at every torch at once, which is what this does.
func _check_layout() -> bool:
	var torches: Array[Node] = get_tree().get_nodes_in_group(&"torches")
	# Every torch lights, checked as an actual PointLight2D rather than as the
	# flag that is supposed to produce one.
	#
	# The flag alone would have passed the whole time the bug existed: torches
	# were built with `carries_light` set from an every-Nth rule, so most of them
	# honestly reported that they did not light, and a check reading the flag
	# would have agreed with them and gone green. What the player sees is whether
	# a light exists and is on.
	for node: Node in torches:
		var torch := node as Torch
		if not _has_live_light(torch):
			push_error("the torch at %s is lit but emits no light"
				% torch.global_position)
			return false

	if torches.size() < Balance.LANE_COUNT * 4:
		push_error("only %d torches in the field - the roads cannot be lit" % torches.size())
		return false

	var points: Array[Vector2] = []
	for node: Node in torches:
		points.append((node as Node2D).global_position)

	var closest: float = INF
	for i: int in points.size():
		for j: int in range(i + 1, points.size()):
			closest = minf(closest, points[i].distance_to(points[j]))
	if closest < Balance.TORCH_MIN_GAP - 1.0:
		for i: int in points.size():
			for j: int in range(i + 1, points.size()):
				if points[i].distance_to(points[j]) <= closest + 0.5:
					print("[torch] crowded pair: road %d at %s and road %d at %s, %.0f apart, %.0f and %.0f from the gate"
						% [(torches[i] as Torch).lane, points[i], (torches[j] as Torch).lane,
						points[j], closest, points[i].length(), points[j].length()])
		push_error("two torches stand %.0f apart, under the %.0f minimum"
			% [closest, Balance.TORCH_MIN_GAP])
		return false

	# The field must map onto itself under a quarter turn.
	#
	# Asserted over the *whole set* rather than per lane. Torches now belong to
	# corridors, and a corridor between two junctions does not belong to any one
	# road - the lane recorded on a torch is only for snuff bookkeeping, and
	# counting torches per lane made the check fail on a field that was in fact
	# perfectly symmetric. What has to hold is that turning the map ninety degrees
	# leaves it looking the same, which is this.
	for at: Vector2 in points:
		var want: Vector2 = at.rotated(TAU * 0.25)
		var near: float = INF
		for other: Vector2 in points:
			near = minf(near, want.distance_to(other))
		if near > 2.0:
			push_error("no torch a quarter turn from %s - the field is lopsided" % at)
			return false

	# Off the carriageway, not on it. A torch on the road is the complaint this
	# placement was rewritten to fix, and it reads as a bug even when it is lit.
	var field: Battlefield = _find_run().battlefield
	if field != null and field.grid != null:
		for at: Vector2 in points:
			if field.grid.cell_at(BattleGrid.world_to_tile(at)) == BattleGrid.Cell.ROAD:
				push_error("a torch at %s stands on the road" % at)
				return false

	print("[torch] layout: %d torches, closest pair %.0f apart, four roads symmetric"
		% [points.size(), closest])
	return true


## Whether this torch actually has an enabled light with a real radius.
func _has_live_light(from: Node) -> bool:
	for child: Node in from.get_children():
		var light := child as PointLight2D
		if light != null and light.enabled and light.energy > 0.0 				and light.texture_scale > 0.0:
			return true
		if _has_live_light(child):
			return true
	return false


func _bail(code: int) -> void:
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 30:
		await get_tree().process_frame
	get_tree().quit(code)


func _find_run() -> Run:
	for child: Node in get_children():
		if child is Run:
			return child as Run
	return null

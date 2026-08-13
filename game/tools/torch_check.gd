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

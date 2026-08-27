extends Node

## Anything that means "a person is standing here" must see all four of them.
##
## `Hero.GROUP` is the *player's* hero and `Hero.GROUP_ANY` is everyone on the
## field. The distinction is documented on the constants themselves, and it is
## still the easiest mistake in this codebase to make: both answer correctly with
## one player, and the wrong one keeps answering correctly right up until somebody
## joins. Then a guest walks over a raid key and it ignores them, stands under a
## torch that will not relight, and fights behind scenery that never fades -
## none of which errors, and none of which a solo test can see.
##
## Two halves. The source scan is the one that generalises: it fails the moment a
## new site asks the singular question. The behavioural half proves the helper
## those sites now share actually finds a hero who is not the player's.

## Files that legitimately want *the player's* hero, with why.
##
## `run.gd` drives the damage vignette, which follows the person holding the
## controller and would be wrong to average across a party. `hero.gd` defines
## both groups. Tools are not shipped.
const SINGULAR_IS_CORRECT: Array[String] = [
	"res://scenes/run/run.gd",
	"res://scenes/hero/hero.gd",
]

const SINGULAR: String = "get_first_node_in_group(&\"hero\")"

const HERO_SCENE: String = "res://scenes/hero/hero.tscn"

var _failures: int = 0


func _ready() -> void:
	_scan("res://scenes")
	_scan("res://scripts")
	_scan("res://autoload")
	_test_helper_finds_a_partner()
	if _failures == 0:
		print("[party-reach] PASS - nothing asks for one hero where it means any")
	else:
		printerr("[party-reach] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _scan(root: String) -> void:
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while name != "":
		var path: String = root.path_join(name)
		if directory.current_is_dir():
			if not name.begins_with("."):
				_scan(path)
		elif name.ends_with(".gd") and not SINGULAR_IS_CORRECT.has(path):
			if FileAccess.get_file_as_string(path).contains(SINGULAR):
				_failures += 1
				printerr("[party-reach] FAIL: %s asks for the player's hero. "
					% path + "If it means whoever is standing there, it wants "
					+ "Hero.nearest_on_field or Hero.GROUP_ANY.")
		name = directory.get_next()
	directory.list_dir_end()


## And the helper has to actually find somebody who is not the player.
func _test_helper_finds_a_partner() -> void:
	# The scene, not the class. A bare `Hero.new()` has none of its exported
	# children, so `_ready` never reaches the group join and the test would be
	# measuring its own construction rather than the game's.
	var scene: PackedScene = load(HERO_SCENE)
	if scene == null:
		_failures += 1
		printerr("[party-reach] FAIL: %s must exist" % HERO_SCENE)
		return
	var partner := scene.instantiate() as Hero
	add_child(partner)
	partner.global_position = Vector2(500.0, 0.0)
	# A partner is in GROUP_ANY from `_ready` and never in GROUP - which is
	# exactly the case every site above used to miss.
	_check(partner.is_in_group(Hero.GROUP_ANY),
		"a hero must join the party group on entering the tree")
	_check(not partner.is_in_group(Hero.GROUP),
		"and must not claim to be the player's hero")
	_check(get_tree().get_first_node_in_group(Hero.GROUP) == null,
		"the singular lookup must find nobody here, which is the whole point")
	_check(Hero.nearest_on_field(get_tree(), Vector2(510.0, 0.0), 60.0) == partner,
		"the helper must find a partner the singular lookup cannot")
	_check(Hero.nearest_on_field(get_tree(), Vector2(2000.0, 0.0), 60.0) == null,
		"and must respect the reach it was given")
	partner.queue_free()


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[party-reach] FAIL: %s" % why)

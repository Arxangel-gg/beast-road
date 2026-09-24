class_name InteractBadge
extends Node2D

## The symbol over the Warden's head that says what they can do right here.
##
## Owner brief, 2026-09-16: "All interactions in the game need symbol icons that
## appear over the player's head when they're in position to do an interaction
## that is available for them."
##
## **It is a reader, not a second opinion.** Eight systems already decide whether
## the hero is in reach of something - the pond, the seam, the timber, the plot,
## the gate, the nest, the chest and the tower - and they say so through
## `EventBus.claim_prompt`, which since 2026-09-16 also carries *what kind of
## thing* is offering. This node listens to that one line and draws the matching
## symbol. It never asks the world a question of its own, so it cannot be right
## when the prompt is wrong, or offer something the systems would refuse.
##
## That matters more than it sounds: the prompt line went through a whole repair
## in this project because seven systems each kept their own idea of what was on
## screen and a clear from one wiped a live prompt from another. A ninth opinion
## on the same question would have been a ninth way to disagree.
##
## **The bound is the fog's:** it draws and is read by nothing. No interaction
## waits on it, no range is measured from it, and turning it off changes no
## number.

## Where the symbol sits over the hero, and how big.
const LIFT: float = 96.0

var _icon: Sprite2D = null
var _ring: Sprite2D = null
var _kind: StringName = &""
var _clock: float = 0.0
var _showing: bool = false
## How far in it is, 0 gone and 1 fully out. Eased rather than switched so a
## player walking along a line of seams sees the symbol *travel* rather than
## flicker between two of them.
var _out: float = 0.0


func _ready() -> void:
	name = "InteractBadge"
	y_sort_enabled = false
	z_as_relative = true
	z_index = Balance.INTERACT_BADGE_Z
	_ring = Sprite2D.new()
	_ring.name = "Halo"
	_ring.texture = LightKit.falloff_texture()
	_ring.modulate = Balance.INTERACT_BADGE_HALO
	_ring.z_index = -1
	var additive: CanvasItemMaterial = LightKit.additive_material()
	_ring.material = additive
	add_child(_ring)
	_icon = Sprite2D.new()
	_icon.name = "Symbol"
	_icon.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_icon.add_to_group(Graphics.FILTER_GROUP)
	add_child(_icon)
	visible = false
	EventBus.interact_prompt.connect(_on_prompt)
	EventBus.fishing_prompt.connect(_on_prompt)


func _on_prompt(text: String, _button: String) -> void:
	if text.is_empty():
		_showing = false
		return
	var kind: StringName = EventBus.prompt_kind()
	if kind != _kind:
		_kind = kind
		var art: String = Balance.INTERACT_BADGE_ART % String(kind)
		# **A kind with no symbol shows nothing rather than a placeholder.** A
		# question mark over the head for every interaction somebody forgot to
		# draw is worse than the label that is already on screen saying what to
		# press.
		_icon.texture = load(art) as Texture2D if ResourceLoader.exists(art) else null
		if _icon.texture != null:
			_icon.scale = Vector2.ONE * (Balance.INTERACT_BADGE_SIZE
				/ maxf(float(_icon.texture.get_width()), 1.0))
	_showing = _icon.texture != null


func _process_measured(delta: float) -> void:
	_clock += delta
	var want: float = 1.0 if _showing else 0.0
	_out = move_toward(_out, want, delta / maxf(Balance.INTERACT_BADGE_FADE, 0.01))
	visible = _out > 0.01
	if not visible:
		return
	# **Out with an overshoot, back without one.** Something arriving is allowed
	# to bounce; something leaving that bounced would read as a second event.
	var eased: float = _out
	if _showing:
		eased = 1.0 + Balance.INTERACT_BADGE_OVERSHOOT * sin(_out * PI) * (1.0 - _out)
		eased *= _out
	# The badge fades *out* after its symbol is taken away - a prompt with no
	# button, such as a seam mid-swing, leaves it showing nothing - so the
	# texture may be null for the length of the fade. Found by the gathering
	# gate swinging eight hundred times (2026-09-21).
	var width: float = float(_icon.texture.get_width()) if _icon.texture != null else 1.0
	_icon.scale = Vector2.ONE * (Balance.INTERACT_BADGE_SIZE / maxf(width, 1.0)) * eased
	# A slow bob, so the symbol is alive without being an animation anybody has
	# to watch.
	var bob: float = sin(_clock * Balance.INTERACT_BADGE_BOB_RATE) * Balance.INTERACT_BADGE_BOB
	_icon.position = Vector2(0.0, -LIFT + bob)
	_ring.position = _icon.position
	_ring.scale = Vector2.ONE * (Balance.INTERACT_BADGE_HALO_SIZE
		/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) * _out
	_ring.modulate.a = Balance.INTERACT_BADGE_HALO.a * _out \
		* (0.75 + 0.25 * sin(_clock * Balance.INTERACT_BADGE_BOB_RATE * 1.7))
	modulate.a = clampf(_out, 0.0, 1.0)


## For the gate: what is being offered right now, or "" for nothing.
func showing() -> StringName:
	return _kind if _showing else &""


## `FrameProfile` bucket "p_interact_badge": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_interact_badge", started)

extends Node

## Makes the interface audible.
##
## `sfx_ui_click`, `sfx_ui_hover`, `sfx_ui_confirm` and `sfx_ui_deny` were
## converted, mixed, levelled and shipped inside the .pck — and nothing in the
## game ever played one of them. Every button in Beast Road was mute.
##
## The obvious fix is to connect a sound in each button's constructor, and it is
## the wrong one: the HUD alone builds buttons in eight different places, the
## build panel rebuilds its own on every click, and the next screen anyone adds
## starts out silent again. A button that has to be *remembered* about is a
## button that will be forgotten.
##
## So this hooks the tree instead. Every BaseButton that enters the scene gets
## its hover and press wired up once, wherever it came from and whoever built it.

## Hover is deliberately well below the click. It fires whenever the cursor
## crosses anything, so at click volume a row of buttons becomes a machine gun.
const HOVER_DB: float = -17.0
const CLICK_DB: float = -5.0

## Marks a button as already wired, so a node re-entering the tree - which the
## HUD's panels do constantly - cannot stack a second connection on it.
const HOOKED: StringName = &"ui_sound_hooked"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Anything already present when this autoload readies. In practice that is
	# nothing, but it costs one walk and removes an ordering assumption.
	_hook_tree(get_tree().root)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		hook(button)


func _hook_tree(from: Node) -> void:
	var button := from as BaseButton
	if button != null:
		hook(button)
	for child: Node in from.get_children():
		_hook_tree(child)


## Idempotent. Safe to call on anything.
func hook(button: BaseButton) -> void:
	if button == null or button.has_meta(HOOKED):
		return
	button.set_meta(HOOKED, true)

	button.mouse_entered.connect(func() -> void:
		# A disabled button is not offering anything, so it should not answer the
		# cursor. Silence there is information.
		if not button.disabled:
			Sfx.play("sfx_ui_hover", HOVER_DB))

	button.pressed.connect(func() -> void: Sfx.play("sfx_ui_click", CLICK_DB))


## For the two cases a plain press sound gets wrong: something committed, or
## something refused. Called explicitly, because only the caller knows which.
func confirm() -> void:
	Sfx.play("sfx_ui_confirm", -3.0)


func deny() -> void:
	Sfx.play("sfx_ui_deny", -4.0)

class_name TextFocus
extends RefCounted

## **Whether the player is typing** (2026-10-01).
##
## A text field with focus takes the key *events* - nothing that listens for an
## unhandled key hears a letter typed into it - but it does not take the key's
## *state*. `Input.is_action_pressed` and `Input.get_vector` read whether the
## key is down, whoever handled it, so a Warden whose player was typing "wave"
## into the chat walked north, swung and sprinted while the words were written.
## Everything that polls the keyboard for a hand on the world asks this first.

static func typing(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var view: Viewport = node.get_viewport()
	if view == null:
		return false
	var owner: Control = view.gui_get_focus_owner()
	if owner == null or not owner.is_visible_in_tree():
		return false
	return owner is LineEdit or owner is TextEdit

class_name ParallaxScatter
extends Node2D

## A band of scattered sprites that slides past the beast: trees on a far
## ridge, brush in the near ground, the things a sidescroller's parallax is
## made of (owner brief, 2026-09-12: "sidescroller games with parallax assets
## in the BG and foreground ... Sonic, Super Mario").
##
## **Seamless by construction.** Every prop is placed inside one period of
## `band_width`, and each is drawn twice - at its place and one period on - so
## sliding the band by any amount inside a period leaves the view covered and
## the wrap invisible. The same rule `ParallaxBand` uses for its silhouette,
## applied to sprites.
##
## **Procedural from the region's own art.** The props are the act's trees and
## plants - the same textures the battlefield grows - so the road the beast
## walks through is visibly the road the player just defended. Nothing is
## painted for this layer; a region that gains a tree gains it here too.
##
## Depth is sold three ways: scale, haze toward the sky colour, and the scroll
## rate the scope hands `scroll_to`. A far layer is small, pale and slow; a near
## one large, dark and fast.

var band_width: float = 1920.0
## Where the props stand, in this node's own space.
var baseline: float = 0.0
## How many props to a period.
var count: int = 24
var scale_range: Vector2 = Vector2(0.9, 1.4)
## Vertical jitter around the baseline, so a line of trees is a wood.
var depth_jitter: float = 18.0
## The colour every prop is pulled toward, and how far. Haze for a far band,
## shade for a near one.
var tint: Color = Color.WHITE
var tint_strength: float = 0.0
var shape_seed: int = 0
## A group the sprites join, so a global filter setting reaches them.
var filter_group: StringName = &""

var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	y_sort_enabled = false


## Lays the band out from a set of textures. Cheap, and called when the act
## changes rather than every frame.
func rebuild(art: Array[Texture2D]) -> void:
	for sprite: Sprite2D in _sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_sprites.clear()
	if art.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	for index: int in count:
		var texture: Texture2D = art[rng.randi_range(0, art.size() - 1)]
		var x: float = rng.randf_range(0.0, band_width)
		var y: float = baseline + rng.randf_range(-depth_jitter, depth_jitter)
		var size: float = rng.randf_range(scale_range.x, scale_range.y)
		var flip: bool = rng.randf() < 0.5
		var shade: float = rng.randf_range(0.9, 1.06)
		for period: int in 2:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = true
			# Sorted by the foot: the node sits where the trunk meets the ground.
			sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
			sprite.position = Vector2(x + float(period) * band_width, y)
			sprite.scale = Vector2.ONE * size
			sprite.flip_h = flip
			sprite.modulate = Color(shade, shade, shade).lerp(tint, tint_strength)
			sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
			if filter_group != &"":
				sprite.add_to_group(filter_group)
			add_child(sprite)
			_sprites.append(sprite)


## Slides the band for a distance travelled, wrapped by one period so the
## number stays small however long the run gets.
func scroll_to(distance: float, rate: float) -> void:
	position.x = -fmod(distance * rate, band_width)


func sprite_count() -> int:
	return _sprites.size()

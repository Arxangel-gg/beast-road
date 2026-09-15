class_name ParallaxScatter
extends Node2D

## A band of scattered sprites that slides past the beast: trees on a far
## ridge, brush in the near ground, the things a sidescroller's parallax is
## made of (owner brief, 2026-09-12: "sidescroller games with parallax assets
## in the BG and foreground ... Sonic, Super Mario").
##
## **Seamless by construction.** Every prop is placed inside one period of
## `band_width` and laid down once per period `ParallaxBand.periods_for` asks
## for - enough of them either side of this node's origin to cover the view - so
## sliding the band by any amount inside a period leaves the view covered and the
## wrap invisible. The same rule `ParallaxBand` uses for its silhouette, applied
## to sprites, and it borrows that helper rather than keeping its own count: both
## layers had the same off-by-one-period hole and fixing one of them would not
## have fixed the other.
##
## **Procedural from the region's own art.** The props are the act's trees and
## plants - the same textures the battlefield grows - so the road the beast
## walks through is visibly the road the player just defended. Nothing is
## painted for this layer; a region that gains a tree gains it here too.
##
## Depth is sold three ways: scale, haze toward the sky colour, and the scroll
## rate the scope hands `scroll_to`. A far layer is small, pale and slow; a near
## one large, dark and fast.

## One period, in world units.
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

## What every scattered piece is drawn through.
##
## **The walk had no wind in it** (owner, 2026-09-15). The battlefield's plants
## have swayed in a shader since they were painted, and the beast scope built
## its woods and its brush from the same art as plain sprites - so the one view
## whose whole subject is travelling through weather was the only still thing in
## the game. Assigning the foliage's own shared material gives every scattered
## plant the same sway, follows the live wind for free, and costs one material
## rather than one per sprite.
var sway_material: ShaderMaterial = null

var _sprites: Array[Sprite2D] = []
## What it was last laid out from, so a resize can lay it out again.
var _art: Array[Texture2D] = []


func _ready() -> void:
	y_sort_enabled = false
	# How many copies of each prop are needed depends on how wide the window is,
	# so a resize is a relayout rather than a redraw.
	get_viewport().size_changed.connect(func() -> void: rebuild(_art))


## Lays the band out from a set of textures. Cheap, and called when the act
## changes rather than every frame.
func rebuild(art: Array[Texture2D]) -> void:
	_art = art
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
		for period: int in ParallaxBand.periods_for(band_width,
				ParallaxBand.half_view(self)):
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
			sprite.material = sway_material
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

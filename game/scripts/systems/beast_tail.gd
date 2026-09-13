class_name BeastTail
extends RefCounted

## Where the beast's tail joins its body, per frame.
##
## The generated beast frames carry the first stretch of the tail and lose
## the rest off the left edge of their canvas; the tail is drawn separately.
## Every frame's stub leaves the edge at a slightly different row - the
## haunches rise and fall with the gait - so one authored anchor sat the tail
## a few pixels off the body on most frames and visibly apart on some. The
## row is read off the frame's own pixels instead, once per texture, and the
## tail's root is put exactly there (owner brief, 2026-09-12).

static var _cache: Dictionary = {}


## The point on the frame's left edge where the stub crosses it, in the
## sprite's centred local coordinates (pixels, before scale), or ZERO for a
## frame with no stub.
static func root_of(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var key: int = texture.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var image: Image = texture.get_image()
	var found := Vector2.ZERO
	if image != null and not image.is_empty():
		var width: int = image.get_width()
		var height: int = image.get_height()
		var rows: Array[int] = []
		for x: int in mini(3, width):
			for y: int in height:
				if image.get_pixel(x, y).a > 0.16:
					rows.append(y)
		if not rows.is_empty():
			var low: int = rows.min()
			var high: int = rows.max()
			found = Vector2(-float(width) * 0.5 + 1.0,
				float(low + high) * 0.5 - float(height) * 0.5)
	_cache[key] = found
	return found

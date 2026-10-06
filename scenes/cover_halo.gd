extends Node2D

var half_size = Vector2.ZERO
var feather = 0.0
var color = Color.BLACK

static func fade_quads(half: Vector2, width: float) -> Array:
	var corners = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var quads = []
	for i in range(4):
		var a = corners[i] * half
		var b = corners[(i + 1) % 4] * half
		var out = (corners[i] + corners[(i + 1) % 4]) / 2.0 * width
		quads.append({"points": [a, b, b + out, a + out], "corner": false})
		var c = corners[i] * width
		quads.append({"points": [a, a + Vector2(c.x, 0), a + c, a + Vector2(0, c.y)], "corner": true})
	return quads

func _draw():
	if half_size == Vector2.ZERO:
		return
	draw_rect(Rect2(-half_size, half_size * 2.0), color)
	var clear = Color(color, 0.0)
	for quad in fade_quads(half_size, feather):
		var colors = [color, clear, clear, clear] if quad.corner else [color, color, clear, clear]
		draw_polygon(PackedVector2Array(quad.points), PackedColorArray(colors))

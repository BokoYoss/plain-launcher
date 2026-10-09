class_name FavoriteStar extends Control

const INNER_RATIO = 0.45

static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(10):
		var angle = -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if i % 2 == 0 else radius * INNER_RATIO))
	return points

func _draw():
	var star = star_points(size / 2.0, minf(size.x, size.y) / 2.0 - 0.5)
	draw_colored_polygon(star, Color.WHITE)
	draw_polyline(star + PackedVector2Array([star[0]]), Color.WHITE, 1.0, true)

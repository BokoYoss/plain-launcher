extends Node2D

const DIM_ALPHA = 0.6

var hidden_row = -1

static func cropped_to(rect: Rect2, bottom: float) -> float:
	return clampf(bottom - rect.position.y, 0.0, rect.size.y)

static func fit_rect(texture_size: Vector2, box: Rect2) -> Rect2:
	var ratio = minf(box.size.x / texture_size.x, box.size.y / texture_size.y)
	var size = texture_size * ratio
	return Rect2(box.position + (box.size - size) / 2.0, size)

func _draw():
	if not Global.inline_covers():
		return
	for i in range(Global.visible_slots.size()):
		var row = Global.shown_offset + i
		if row >= Global.option_list.size() or row == hidden_row:
			continue
		var path = Global.get_image_path(Global.option_list[row])
		var texture = Global.cached_art(path) if path != "" else null
		if texture == null:
			continue
		var box = Global.inline_box_rect(i)
		box.position -= global_position
		var target = fit_rect(texture.get_size(), box)
		var shown = cropped_to(target, Global.list_bottom() - global_position.y)
		if shown <= 0.0:
			continue
		var source = Rect2(Vector2.ZERO, Vector2(texture.get_size().x, texture.get_size().y * shown / target.size.y))
		draw_texture_rect_region(texture, Rect2(target.position, Vector2(target.size.x, shown)), source, Color(1, 1, 1, 1.0 if row == Global.option_selection else DIM_ALPHA))

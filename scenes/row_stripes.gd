extends Node2D

const STRIPE_ALPHA = 0.07

static func stripe_rect(text_middle: float, row_height: float, left: float, right: float) -> Rect2:
	return Rect2(left, text_middle - row_height / 2.0, right - left, row_height)

static func striped(row: int, count: int) -> bool:
	return row % 2 == 1 and row < count

static func color() -> Color:
	return Color(Settings.get_setting(Settings.CFG_FG_COLOR), STRIPE_ALPHA)

func rects(left: float, right: float) -> Array:
	var result = []
	if not Settings.get_setting(Settings.CFG_ROW_STRIPES):
		return result
	var row_height = Global.row_step()
	for i in range(Global.visible_slots.size()):
		if not striped(Global.shown_offset + i, Global.option_list.size()):
			continue
		var slot: Label = Global.visible_slots[i]
		var rect = stripe_rect(slot.global_position.y + Global.slot_text_middle(slot), row_height, left, right)
		rect.size.y = minf(rect.size.y, Global.list_bottom() - rect.position.y)
		if rect.size.y > 0.0:
			result.append(rect)
	return result

static func left_edge(list_shift: float, left_bound: float, gap: float, inline: bool) -> float:
	if inline or list_shift <= 0.0:
		return 0.0 if inline else list_shift
	return left_bound + list_shift - gap / 2.0

func _draw():
	var right = Global.text_limit_x() + Global.scaled_text_height * 0.15 if Global.text_to_cover() else Global.window_width
	for rect in rects(left_edge(Global.list_shift, Global.left_bound, Global.scaled_text_height * 0.3, Global.inline_covers()), right):
		draw_rect(Rect2(rect.position - global_position, rect.size), color())

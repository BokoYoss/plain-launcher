class_name ListView extends Control

var items: Array = []
var selection = 0
var scroll_offset = 0
var font: Font = null
var font_size = 24
var row_height = 36.0
var color = Color.WHITE
var dim_alpha = 0.35
var static_rows = false
const VALUE_SHARE = 0.6
var _labels: Array = []
var _values: Array = []
var _checks: Array = []
var _arrows: Array = []
var _cut_off = {}
var choice_rows = false
var stripes = true
var stripe_margin = 0.0
const STRIPE_ALPHA = 0.12

func set_items(list: Array, keep_selection: bool = false):
	items = list
	if not keep_selection:
		selection = 0
		scroll_offset = 0
	selection = clampi(selection, 0, maxi(0, items.size() - 1))
	_clamp_scroll()
	refresh()

func visible_rows() -> int:
	return maxi(1, int(size.y / row_height))

func move(delta: int):
	if items.is_empty():
		return
	selection = posmod(selection + delta, items.size())
	_clamp_scroll()
	refresh()

func index_at(local_y: float) -> int:
	var index = scroll_offset + int(floor(local_y / row_height))
	return index if local_y >= 0 and index < mini(items.size(), scroll_offset + visible_rows()) else -1

func select(index: int):
	selection = clampi(index, 0, maxi(0, items.size() - 1))
	_clamp_scroll()
	refresh()

func selected():
	return items[selection] if selection < items.size() else null

func _clamp_scroll():
	var rows = visible_rows()
	if selection < scroll_offset:
		scroll_offset = selection
	elif selection >= scroll_offset + rows:
		scroll_offset = selection - rows + 1
	scroll_offset = clampi(scroll_offset, 0, maxi(0, items.size() - rows))

func refresh():
	var rows = visible_rows()
	while _labels.size() < rows:
		_labels.append(_new_label(HORIZONTAL_ALIGNMENT_LEFT))
		_values.append(_new_label(HORIZONTAL_ALIGNMENT_RIGHT))
	_checks = []
	_arrows = []
	_cut_off = {}
	for i in range(_labels.size()):
		var label: Label = _labels[i]
		var value_label: Label = _values[i]
		var index = scroll_offset + i
		label.visible = i < rows and index < items.size()
		value_label.visible = label.visible
		if not label.visible:
			continue
		var item = items[index]
		var item_font = item.get_meta("font") if item.has_meta("font") else font
		var highlighted = not item.has_meta("heading") if static_rows else index == selection
		var row_color = Color(color, 1.0 if highlighted else dim_alpha)
		var y = i * row_height
		for l in [label, value_label]:
			l.add_theme_font_size_override("font_size", font_size)
			if item_font != null:
				l.add_theme_font_override("font", item_font)
			l.modulate = row_color
		label.text = item.clean
		label.position = Vector2(0, y)
		var used = 0.0
		value_label.text = ""
		var plain_action = is_plain_action(item, static_rows)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if plain_action and choice_rows else HORIZONTAL_ALIGNMENT_LEFT
		if plain_action and not choice_rows:
			used = font_size * 0.8
			_arrows.append([Rect2(size.x - font_size * 0.35, y + (row_height - font_size * 0.6) / 2.0, font_size * 0.3, font_size * 0.6), row_color])
		if item.has_meta("checked"):
			used = font_size * 1.2
			_checks.append([Rect2(size.x - font_size * 0.8, y + (row_height - font_size * 0.8) / 2.0, font_size * 0.8, font_size * 0.8), item.get_meta("checked"), row_color])
		elif item.has_meta("value"):
			var label_font = item_font if item_font != null else get_theme_default_font()
			var label_width = label_font.get_string_size(item.clean, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var gap = font_size
			value_label.text = str(item.get_meta("value"))
			var value_width = label_font.get_string_size(value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2
			used = minf(value_width, maxf(size.x - label_width - gap, size.x * VALUE_SHARE)) + gap
			value_label.position = Vector2(size.x - used + gap, y)
			value_label.size = Vector2(used - gap, row_height)
		label.size = Vector2(size.x - used, row_height)
		var measure_font = item_font if item_font != null else get_theme_default_font()
		var cut = measure_font.get_string_size(item.clean, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x + 1
		if value_label.text != "":
			cut = cut or measure_font.get_string_size(value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > value_label.size.x + 1
		_cut_off[index] = cut
	queue_redraw()

func is_cut_off(index: int) -> bool:
	return _cut_off.get(index, false)

static func is_plain_action(item, static_list: bool) -> bool:
	return not static_list and not item.has_meta("checked") and not item.has_meta("value") and item.handles(Actions.CONFIRM)

func _new_label(alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = alignment
	label.clip_text = true
	add_child(label)
	return label

func _draw():
	if static_rows and selection >= scroll_offset and selection < mini(items.size(), scroll_offset + visible_rows()):
		draw_rect(Rect2(-stripe_margin, (selection - scroll_offset) * row_height, size.x + stripe_margin * 2.0, row_height), Color(color, 0.15))
	if stripes:
		for i in range(visible_rows()):
			if (scroll_offset + i) % 2 == 1 and scroll_offset + i < items.size():
				draw_rect(Rect2(-stripe_margin, i * row_height, size.x + stripe_margin * 2.0, row_height), Color(0, 0, 0, STRIPE_ALPHA))
	for arrow in _arrows:
		var box: Rect2 = arrow[0]
		var points = PackedVector2Array([box.position, Vector2(box.end.x, box.get_center().y), Vector2(box.position.x, box.end.y)])
		draw_polyline(points, arrow[1], maxf(2.0, box.size.x * 0.3), true)
	for check in _checks:
		var box: Rect2 = check[0]
		var tint: Color = check[2]
		var line = maxf(2.0, box.size.x * 0.1)
		draw_rect(box.grow(-line / 2.0), tint, false, line)
		if check[1]:
			draw_rect(box.grow(-line * 2.0), tint)

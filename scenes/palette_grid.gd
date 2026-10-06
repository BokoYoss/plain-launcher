class_name PaletteGrid extends Control

const PALETTE_PATH = "res://sprites/duel_palette.png"
const MIN_BAND = 4

var colors: Array = []
var index = 0
var on_change: Callable = Callable()

static func swatches(image: Image) -> Array:
	var bands = []
	var start = 0
	var last = null
	for y in range(image.get_height()):
		var color = image.get_pixel(0, y)
		if last != null and color != last:
			if y - start >= MIN_BAND:
				bands.append((start + y - 1) / 2)
			start = y
		last = color
	if image.get_height() - start >= MIN_BAND:
		bands.append((start + image.get_height() - 1) / 2)
	var result = []
	for y in bands:
		var previous = null
		for x in range(image.get_width()):
			var color = image.get_pixel(x, y)
			if color != previous:
				result.append(color)
				previous = color
	return result

static func load_palette() -> Array:
	var texture: Texture2D = load(PALETTE_PATH)
	return swatches(texture.get_image()) if texture != null else []

static func columns_for(count: int, area: Vector2) -> int:
	if count == 0 or area.x <= 0 or area.y <= 0:
		return maxi(1, count)
	var ideal = sqrt(count * area.x / area.y)
	var best = count
	for columns in range(1, count + 1):
		if count % columns == 0 and absf(columns - ideal) < absf(best - ideal):
			best = columns
	return best

func columns() -> int:
	return columns_for(colors.size(), size)

func select_color(color: Color):
	var found = colors.find(color)
	if found >= 0:
		index = found
		queue_redraw()

func selected_color() -> Color:
	return colors[index] if not colors.is_empty() else Color.BLACK

func cell_size() -> float:
	var cols = columns()
	return minf(size.x / cols, size.y / ceili(colors.size() / float(cols)))

func index_at(local: Vector2) -> int:
	var cell = cell_size()
	var cols = columns()
	if cell <= 0 or local.x < 0 or local.y < 0 or local.x >= cols * cell:
		return -1
	var found = int(local.y / cell) * cols + int(local.x / cell)
	return found if found < colors.size() else -1

func pick(found: int):
	index = found
	queue_redraw()
	if on_change.is_valid():
		on_change.call(selected_color())

func move(dx: int, dy: int):
	if colors.is_empty():
		return
	var cols = columns()
	var row = index / cols
	var col = index % cols
	var rows = ceili(colors.size() / float(cols))
	if dy != 0:
		row = clampi(row + dy, 0, rows - 1)
	if dx != 0:
		var width = mini(cols, colors.size() - row * cols)
		col = posmod(col + dx, width)
	index = mini(row * cols + col, colors.size() - 1)
	queue_redraw()
	if on_change.is_valid():
		on_change.call(selected_color())

func _draw():
	if colors.is_empty():
		return
	var cols = columns()
	var rows = ceili(colors.size() / float(cols))
	var cell = minf(size.x / cols, size.y / rows)
	for i in range(colors.size()):
		draw_rect(Rect2(Vector2(i % cols, i / cols) * cell, Vector2(cell, cell)), colors[i])
	var highlight = Rect2(Vector2(index % cols, index / cols) * cell, Vector2(cell, cell))
	draw_rect(highlight.grow(2), Settings.get_setting(Settings.CFG_FG_COLOR), false, 4.0)
	draw_rect(highlight.grow(-2), Color.BLACK, false, 2.0)

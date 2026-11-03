extends CanvasLayer
## The tutorial's words (levels/tutorial/tutorial.gd): a line in each half of the mirrored screen,
## each for its player, over the picture (a text in the world would read upside down in the shadow
## half). The light half's at its top, under the HUD; the shadow half's at its bottom, and none
## while the halves are merged (MirrorView: nobody's down there then). Under each, how far that
## player has got; at the bottom right, how to skip a step.

const FONT_SIZE = 20
const SMALL_SIZE = 14
const TOP = 58.0  # px from the top: under the HUD's meters
const BOTTOM = 92.0  # px from the bottom, the shadow half's
const WIDTH = 900.0
const COLOR = Color(1.0, 1.0, 1.0)
const AGAIN_COLOR = Color(1.0, 0.45, 0.4)

var _lines = {}  # player_id -> {"text": Label, "progress": Label}
var _hint: Label


func _ready():
	layer = 2  # over the mirrored screen (1), with the HUD
	for id in [1, 2]:
		var text = _label(FONT_SIZE)
		var progress = _label(SMALL_SIZE)
		progress.modulate = Color(1.0, 1.0, 1.0, 0.75)
		_lines[id] = {"text": text, "progress": progress}
	_hint = _label(SMALL_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.5)


func _label(font_size: int) -> Label:
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(WIDTH, 0.0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


# What each player reads ({player_id: text}), and how far each has got ({player_id: text}).
func show_lines(texts: Dictionary, progress: Dictionary, again = false):
	for id in _lines:
		_lines[id].text.text = texts.get(id, "")
		_lines[id].text.add_theme_color_override("font_color", AGAIN_COLOR if again else COLOR)
		_lines[id].progress.text = progress.get(id, "")


func show_hint(text: String):
	_hint.text = text


# What a player is shown (for the tests).
func line_of(id: int) -> String:
	return _lines[id].text.text


func _process(_delta):
	var screen = get_viewport().get_visible_rect().size
	var view = get_tree().get_first_node_in_group("mirror_view")
	var split = MirrorView.is_split() or view == null
	var x = (screen.x - WIDTH) / 2.0
	_lines[1].text.position = Vector2(x, TOP)
	_lines[1].progress.position = Vector2(x, TOP + FONT_SIZE * 1.6 * _rows(_lines[1].text))
	_lines[2].text.visible = split
	_lines[2].progress.visible = split
	_lines[2].text.position = Vector2(x, screen.y - BOTTOM)
	_lines[2].progress.position = Vector2(x, screen.y - BOTTOM + FONT_SIZE * 1.6 * _rows(_lines[2].text))
	_hint.position = Vector2(screen.x - WIDTH - 16.0, screen.y - 26.0)


func _rows(label: Label) -> int:
	return maxi(label.get_line_count(), 1)

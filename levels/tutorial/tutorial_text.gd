extends CanvasLayer
## The tutorial's words (levels/tutorial/tutorial.gd): a line in each half of the mirrored screen,
## over the picture (a text in the world would read upside down in the shadow half). The light
## half's at its top, under the HUD; the shadow half's at its bottom. While the halves are merged
## (MirrorView: nobody's down there then), the shadow half's words go on in the light half. Under
## each, how far that player has got; at the bottom right, how to skip a step.

const FONT_SIZE = 20
const SMALL_SIZE = 14
const TOP = 100.0  # px from the top: under the HUD (its meters, posture bars and state line)
const BOTTOM = 34.0  # px from the bottom to the shadow half's last line (over the skip hint)
const WIDTH = 900.0
const COLOR = Color(1.0, 1.0, 1.0)

var _lines = {}  # player_id -> {"text": Label, "progress": Label}
var _hint: Label
var _texts = {1: "", 2: ""}  # what's to be read in each half (show_lines())...
var _progress = {1: "", 2: ""}  # ...and how far each has got


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


# What's to be read in each half ({player_id: text}), and how far each has got there.
func show_lines(texts: Dictionary, progress: Dictionary):
	for id in _lines:
		_texts[id] = texts.get(id, "")
		_progress[id] = progress.get(id, "")
	_place_words()


func show_hint(text: String):
	_hint.text = text


# What a half shows (for the tests).
func line_of(id: int) -> String:
	return _lines[id].text.text


# Each half's words in it; merged, all of them above.
func _place_words():
	var split = MirrorView.is_split() or get_tree().get_first_node_in_group("mirror_view") == null
	_lines[1].text.text = _texts[1] if split else _joined(_texts[1], _texts[2], "\n")
	_lines[1].progress.text = _progress[1] if split else _joined(_progress[1], _progress[2], "   ")
	_lines[2].text.text = _texts[2]
	_lines[2].progress.text = _progress[2]
	for id in _lines:
		_lines[id].text.add_theme_color_override("font_color", COLOR)
		_lines[id].text.visible = split or id == 1
		_lines[id].progress.visible = split or id == 1


static func _joined(a: String, b: String, between: String) -> String:
	if a == "" or b == "":
		return a + b
	return a + between + b


func _process(_delta):
	var screen = get_viewport().get_visible_rect().size
	_place_words()  # (merging or apart again: where they're read changes)
	var x = (screen.x - WIDTH) / 2.0
	for id in _lines:
		for label in _lines[id].values():
			label.size = Vector2(WIDTH, 0.0)  # its height as its lines need
	var top = _lines[1]
	top.text.position = Vector2(x, TOP)
	top.progress.position = Vector2(x, TOP + top.text.size.y)
	var bottom = _lines[2]  # its last line BOTTOM over the screen's edge, however many lines
	var under = screen.y - BOTTOM - bottom.progress.size.y
	bottom.progress.position = Vector2(x, under)
	bottom.text.position = Vector2(x, under - bottom.text.size.y)
	_hint.position = Vector2(screen.x - WIDTH - 16.0, screen.y - 26.0)

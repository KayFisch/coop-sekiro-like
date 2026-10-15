class_name BeatDisplay
extends Control
## Shows the Beat clock: four dots, one per count of the bar, the current one lit and the 1
## larger, with the tempo beside them. Put it on a CanvasLayer anywhere; it sizes itself.

const DOT_RADIUS = 6.0
const DOWNBEAT_RADIUS = 9.0
const SPACING = 26.0  # px between the dots' centers
const LIT_FADE = 0.3  # s a lit dot takes to dim back to the next beat's glow
const COLOR_DIM = Color(1, 1, 1, 0.22)
const COLOR_LIT = Color(1, 0.92, 0.6)
const COLOR_TEXT = Color(1, 1, 1, 0.7)
const FONT_SIZE = 14


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SPACING * Beat.BEATS_PER_BAR + 120.0, DOWNBEAT_RADIUS * 2.0 + 4.0)
	size = custom_minimum_size


func _process(_delta):
	queue_redraw()


func _draw():
	var y = DOWNBEAT_RADIUS + 2.0
	var lit = Beat.beat_in_bar() if Beat.running and Beat.current_beat() >= 0 else 0
	# Lit right on the beat, fading to a steady glow over LIT_FADE.
	var flash = 1.0 - minf(Beat.phase() * Beat.beat_length() / LIT_FADE, 1.0)
	for i in Beat.BEATS_PER_BAR:
		var center = Vector2(DOWNBEAT_RADIUS + i * SPACING, y)
		var radius = DOWNBEAT_RADIUS if i == 0 else DOT_RADIUS
		var color = COLOR_DIM
		if i + 1 == lit:
			color = COLOR_LIT.lerp(Color.WHITE, flash * 0.6)
			radius += flash * 2.0
		draw_circle(center, radius, color)
	var text = "%d BPM" % roundi(Beat.bpm)
	if not Beat.click_on:
		text += "  (click off: M)"
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(DOWNBEAT_RADIUS + Beat.BEATS_PER_BAR * SPACING, y + FONT_SIZE * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)

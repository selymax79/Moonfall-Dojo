## Fixed 640x52 status panel. Data stays in Main; this owns only presentation and text fitting.
extends Control

func fit_values() -> void:
	for child in get_children():
		if child is Label:
			var preferred: int = 8 if child.name == "HighScoreLabel" else 16
			var font: Font = child.get_theme_font("font")
			# Full integer values remain visible; switch to the native 8 px font only when required.
			var width: float = font.get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, preferred).x
			child.add_theme_font_size_override("font_size", 8 if width > child.size.x else preferred)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 52), Color("090e19"))
	draw_rect(Rect2(0, 0, 640, 2), Color("7e6841"))
	draw_rect(Rect2(0, 3, 640, 1), Color("283040"))
	draw_rect(Rect2(0, 49, 640, 3), Color("03070e"))
	for x in [268, 458]:
		draw_rect(Rect2(x, 9, 1, 33), Color("313443"))
		draw_rect(Rect2(x + 1, 12, 1, 27), Color("090b13"))
	for x in [6, 632]:
		draw_rect(Rect2(x, 9, 2, 33), Color("463d30"))
		draw_rect(Rect2(x, 9, 5, 1), Color("8d774e"))
		draw_rect(Rect2(x, 41, 5, 1), Color("655339"))

## Offline preparation only: nearest-neighbour game plate and an original 5x7 bitmap alphabet.
## Run with Godot --headless --path . --script res://tools/build_presentation.gd.
extends SceneTree

const GLYPHS = {
	"A": [14,17,17,31,17,17,17], "B": [30,17,17,30,17,17,30],
	"C": [14,17,16,16,16,17,14], "D": [30,17,17,17,17,17,30],
	"E": [31,16,16,30,16,16,31], "F": [31,16,16,30,16,16,16],
	"G": [14,17,16,23,17,17,15], "H": [17,17,17,31,17,17,17],
	"I": [14,4,4,4,4,4,14], "J": [7,2,2,2,18,18,12],
	"K": [17,18,20,24,20,18,17], "L": [16,16,16,16,16,16,31],
	"M": [17,27,21,21,17,17,17], "N": [17,25,25,21,19,19,17],
	"O": [14,17,17,17,17,17,14], "P": [30,17,17,30,16,16,16],
	"Q": [14,17,17,17,21,18,13], "R": [30,17,17,30,20,18,17],
	"S": [15,16,16,14,1,1,30], "T": [31,4,4,4,4,4,4],
	"U": [17,17,17,17,17,17,14], "V": [17,17,17,17,17,10,4],
	"W": [17,17,17,21,21,27,17], "X": [17,17,10,4,10,17,17],
	"Y": [17,17,10,4,4,4,4], "Z": [31,1,2,4,8,16,31],
	"0": [14,17,19,21,25,17,14], "1": [4,12,4,4,4,4,14],
	"2": [14,17,1,2,4,8,31], "3": [30,1,1,14,1,1,30],
	"4": [2,6,10,18,31,2,2], "5": [31,16,16,30,1,1,30],
	"6": [14,16,16,30,17,17,14], "7": [31,1,2,4,8,8,8],
	"8": [14,17,17,14,17,17,14], "9": [14,17,17,15,1,1,14],
	" ": [0,0,0,0,0,0,0], ".": [0,0,0,0,0,12,12],
	"-": [0,0,0,31,0,0,0], ":": [0,12,12,0,12,12,0],
	"/": [1,1,2,4,8,16,16], ">": [16,8,4,2,4,8,16],
	"<": [1,2,4,8,4,2,1], "x": [0,0,17,10,4,10,17]
}

func _init() -> void:
	var plate := Image.load_from_file("res://art/background/dojo_source.png")
	# Bottom 10 px sit behind the HUD. This puts the visible platform under the fixed y=300 feet.
	plate.resize(640, 318, Image.INTERPOLATE_NEAREST)
	assert(plate.save_png("res://art/background/dojo.png") == OK)
	build_ambience(plate)
	build_font()
	quit()

func build_font() -> void:
	var atlas := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var description := "info face=\"Dojo Five\" size=8 bold=0 italic=0 unicode=1\n"
	description += "common lineHeight=8 base=7 scaleW=128 scaleH=32 pages=1 packed=0\n"
	description += "page id=0 file=\"dojo_font.png\"\nchars count=%d\n" % GLYPHS.size()
	var index: int = 0
	for character in GLYPHS:
		var origin := Vector2i((index % 16) * 8, floori(index / 16.0) * 8)
		for y in range(7):
			for x in range(5):
				if GLYPHS[character][y] & (1 << (4 - x)):
					atlas.set_pixel(origin.x + x, origin.y + y, Color.WHITE)
		description += "char id=%d x=%d y=%d width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15\n" % [character.unicode_at(0), origin.x, origin.y]
		index += 1
	assert(atlas.save_png("res://art/ui/dojo_font.png") == OK)
	var source := FileAccess.open("res://art/ui/dojo_font.fnt", FileAccess.WRITE)
	source.store_string(description)
	source.close()
	# Store the font with its atlas embedded so scene loading needs no external font installation.
	var font := FontFile.new()
	assert(font.load_bitmap_font("res://art/ui/dojo_font.fnt") == OK)
	font.multichannel_signed_distance_field = false
	# Bitmap fonts default to their native size; allow exact 2x/3x glyph scaling for HUD/overlays.
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	assert(ResourceSaver.save(font, "res://art/ui/dojo_font.tres") == OK)
	print("Prepared 640x318 dojo plate and original 44-glyph bitmap font.")

## Small code-authored masks/sprites accompany the generated architectural plate.
func build_ambience(plate: Image) -> void:
	var mask := Image.create(640, 318, false, Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	for y in range(112):
		for x in range(110, 530):
			var pixel := plate.get_pixel(x, y)
			var moon: bool = Vector2(x - 320, y - 63).length() < 32.0
			if moon or (pixel.b > 0.13 and pixel.b > pixel.g * 1.25 and pixel.r < 0.09):
				mask.set_pixel(x, y, Color.WHITE)
	assert(mask.save_png("res://art/background/sky_mask.png") == OK)
	for variant in range(2):
		var cloud := Image.create(192, 32, false, Image.FORMAT_RGBA8)
		cloud.fill(Color.TRANSPARENT)
		# Stepped banks and wisps, drawn on a 2 px grid rather than soft alpha gradients.
		for bank in [Rect2i(8,18,178,6), Rect2i(28,14,144,4), Rect2i(52,10,94,4),
				Rect2i(74,6,44,4), Rect2i(0,22,146,4), Rect2i(35,26,109,2)]:
			cloud.fill_rect(bank, Color("122743") if variant == 0 else Color("12233b"))
		cloud.fill_rect(Rect2i(31,14,42,2), Color("1b3350"))
		cloud.fill_rect(Rect2i(98,10,32,2), Color("203950"))
		cloud.fill_rect(Rect2i(10,23,56,1), Color("091c33"))
		assert(cloud.save_png("res://art/background/cloud_%d.png" % variant) == OK)
	# Dark, small background figures. The runtime clips them to individual paper panes.
	for frame in range(2):
		var person := Image.create(16, 30, false, Image.FORMAT_RGBA8)
		person.fill(Color.TRANSPARENT)
		for rect in [Rect2i(5,1,5,6), Rect2i(4,7,7,10), Rect2i(3,15,9,7),
				Rect2i(2,9,2,9), Rect2i(11,9,2,8), Rect2i(4-frame,21,3,8), Rect2i(9+frame,21,3,8)]:
			person.fill_rect(rect, Color.WHITE)
		assert(person.save_png("res://art/background/person_%d.png" % frame) == OK)
		var dog := Image.create(23, 14, false, Image.FORMAT_RGBA8)
		dog.fill(Color.TRANSPARENT)
		for rect in [Rect2i(3,5,13,5), Rect2i(15,2,5,7), Rect2i(18,5,5,3),
				Rect2i(15,0,2,4), Rect2i(2,2,2,5), Rect2i(4+frame,9,2,5), Rect2i(13-frame,9,2,5)]:
			dog.fill_rect(rect, Color.WHITE)
		assert(dog.save_png("res://art/background/dog_%d.png" % frame) == OK)

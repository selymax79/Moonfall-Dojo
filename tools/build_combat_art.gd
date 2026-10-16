## Offline, original pixel authoring. Coordinates are deliberately fitted to the existing combat geometry.
## No runtime skeleton, interpolation, random generation or external artwork is used.
extends SceneTree

const CELL = Vector2i(96, 56)
const ORIGIN = Vector2i(40, 48)
var canvas: Image
var origin := Vector2i.ZERO
var ramp: Array[Color]
const INK = Color("080e1c")
const SKIN = Color("c29b78")
const LIGHT = Color("efd2a0")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://art/combat")
	for kind in range(3):
		ramp = palettes(kind)
		canvas = Image.create(CELL.x * 8, CELL.y * 4, false, Image.FORMAT_RGBA8)
		for frame in range(32):
			origin = Vector2i(frame % 8 * CELL.x, floori(frame / 8.0) * CELL.y) + ORIGIN
			ninja(frame, kind)
		canvas.save_png("res://art/combat/" + ["player", "red", "blue"][kind] + ".png")
	build_hazards()
	build_background()
	print("Combat atlases: 32 poses per ninja; 8 barrel/4 star frames; 5 adult and 4 dog poses; 3 cast-shadow states.")
	quit()

func palettes(kind: int) -> Array[Color]:
	match kind:
		1: return [Color("301827"), Color("742a3b"), Color("bb4050"), Color("ed785d"), Color("cca66b")]
		2: return [Color("101f3c"), Color("204977"), Color("367daf"), Color("76b8c8"), Color("c1c6ad")]
	return [Color("141d2d"), Color("28394c"), Color("496579"), Color("8b9c9e"), Color("b18d58")]

func pixel(x: int, y: int, colour: Color) -> void:
	var p := origin + Vector2i(x,y)
	if p.x >= 0 and p.y >= 0 and p.x < canvas.get_width() and p.y < canvas.get_height(): canvas.set_pixelv(p,colour)

func box(x: int, y: int, width: int, height: int, colour: Color) -> void:
	for row in range(y,y+height):
		for column in range(x,x+width): pixel(column,row,colour)

func poly(points: Array, colour: Color) -> void:
	var vertices := PackedVector2Array()
	for point in points: vertices.append(point)
	var bounds := Rect2(vertices[0],Vector2.ZERO)
	for point in vertices: bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y),ceili(bounds.end.y)+1):
		for x in range(floori(bounds.position.x),ceili(bounds.end.x)+1):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),vertices): pixel(x,y,colour)

func stroke(a: Vector2, b: Vector2, width: int, colour: Color) -> void:
	var count: int = maxi(1,ceili(a.distance_to(b)))
	for step in range(count+1):
		var at := a.lerp(b,float(step)/count).round()
		box(int(at.x)-floori(width/2.0),int(at.y)-floori(width/2.0),width,width,colour)

## Tapered cloth masses replace constant-width sticks. These are offline raster shapes only.
func segment(a: Vector2, b: Vector2, start_width: float, end_width: float, colour: Color) -> void:
	var normal := (b-a).normalized().orthogonal()
	poly([a+normal*start_width/2, b+normal*end_width/2,
		b-normal*end_width/2, a-normal*start_width/2], colour)

func limb(a: Vector2, joint: Vector2, end: Vector2, width: int, front: bool) -> void:
	var leg: bool = width == 4
	var upper: float = 6.0 if leg else 4.5
	var lower: float = 4.5 if leg else 3.5
	segment(a,joint,upper+2,lower+2,INK)
	segment(joint,end,lower+2,4 if leg else 3.5,INK)
	box(int(joint.x)-2,int(joint.y)-2,4,4,INK)
	segment(a,joint,upper,lower,ramp[1] if front else ramp[0])
	segment(joint,end,lower,2.5,ramp[1] if front else ramp[0])
	box(int(joint.x)-1,int(joint.y)-1,3,3,ramp[1] if front else ramp[0])
	# Short folds describe volume; continuous bright joint-to-joint lines read as metal rods.
	if front:
		segment(a.lerp(joint,0.20)+Vector2(-1,0),a.lerp(joint,0.65)+Vector2(-1,0),2,1,ramp[2])
		stroke(joint.lerp(end,0.35),joint.lerp(end,0.65),1,ramp[2])
		pixel(int(joint.x)-1,int(joint.y)-1,ramp[3])
	if leg:
		# Split-toe shoe stays grounded; the active kick has its own explicitly fitted sole below.
		box(int(end.x)-2,int(end.y)-1,5,3,INK)
		box(int(end.x)-1,int(end.y)-1,3,2,ramp[0])
		pixel(int(end.x)+2,int(end.y)-1,ramp[2])
	else:
		box(int(end.x)-2,int(end.y)-2,4,4,INK)
		box(int(end.x)-1,int(end.y)-1,3,2,SKIN if front else ramp[1])

## Each entry is a held key pose, not a skeleton played at runtime. Feet end at local y=-1.
func ninja(frame: int, kind: int) -> void:
	var hip := Vector2(-1,-17)
	var shoulder := Vector2(0,-28)
	var head := Vector2(1,-35)
	var knee_back := Vector2(-6,-9)
	var foot_back := Vector2(-8,-2)
	var knee_front := Vector2(6,-10)
	var foot_front := Vector2(8,-2)
	var elbow_back := Vector2(-7,-22)
	var hand_back := Vector2(-2,-24)
	var elbow_front := Vector2(6,-23)
	var hand_front := Vector2(8,-29)
	if frame == 1:
		elbow_front += Vector2(-1,1)
		hand_front += Vector2(-1,1)
	if frame == 2: # narrow three-quarter turn, without scaling the sprite
		shoulder.x = -1; head.x = -1; hand_front = Vector2(3,-28)
		elbow_front = Vector2(4,-22); foot_front.x = 4; knee_front.x = 3
		elbow_back.x = -4; hand_back = Vector2(-3,-27)
	if frame >= 3 and frame <= 6:
		# A low straight punch rotates the chest over a stable, bent-knee base.
		shoulder = Vector2(3,-28); head = Vector2(4,-34)
		knee_front = Vector2(7,-9); foot_front = Vector2(9,-2)
		elbow_back = Vector2(-5,-23); hand_back = Vector2(0,-28)
		match frame:
			3: shoulder.x = 0; head.x = 1; elbow_front = Vector2(4,-21); hand_front = Vector2(1,-25)
			4: elbow_front = Vector2(10,-24); hand_front = Vector2(16,-23)
			5: shoulder.x = 5; head.x = 5; elbow_front = Vector2(14,-23); hand_front = Vector2(23,-23)
			6: shoulder.x = 2; head.x = 2; elbow_front = Vector2(7,-21); hand_front = Vector2(10,-26)
	if frame >= 7 and frame <= 10:
		# Turn the hip into the high side kick. The support leg stays under the leaning trunk,
		# rather than hinging an impossibly long shin off the standing pelvis.
		shoulder = Vector2(-3,-29); head = Vector2(-4,-35); hip = Vector2(3,-19)
		knee_back = Vector2(-3,-10); foot_back = Vector2(-7,-2)
		elbow_back = Vector2(-10,-23); hand_back = Vector2(-7,-27)
		elbow_front = Vector2(4,-25); hand_front = Vector2(5,-30)
		match frame:
			7: knee_front = Vector2(10,-23); foot_front = Vector2(6,-12)
			8: hip = Vector2(5,-21); knee_front = Vector2(17,-28); foot_front = Vector2(24,-29)
			9: hip = Vector2(7,-21); knee_front = Vector2(20,-29); foot_front = Vector2(33,-30)
			10: shoulder.x = -1; head.x = 0; hip = Vector2(1,-17); knee_front = Vector2(9,-15); foot_front = Vector2(8,-5)
	if frame >= 11 and frame <= 14:
		elbow_back = Vector2(-8,-26); hand_back = Vector2(-7,-31)
		elbow_front = Vector2(8,-28); hand_front = Vector2(10,-33)
		if frame == 12:
			knee_back = Vector2(-8,-12); foot_back = Vector2(-4,-6)
			knee_front = Vector2(9,-17); foot_front = Vector2(5,-8)
		elif frame == 13:
			knee_back = Vector2(-5,-10); foot_back = Vector2(-4,-3)
			knee_front = Vector2(7,-11); foot_front = Vector2(8,-2)
		elif frame == 11 or frame == 14:
			shoulder.y += 2; head.y += 2; hip.y += 2
			knee_front = Vector2(8,-7); knee_back = Vector2(-7,-7)
	if frame >= 15 and frame <= 17 or frame == 25 or frame == 26:
		var low: bool = frame == 16 or frame == 25 or frame == 26
		var top: float = -18 if frame == 16 else (-24 if low else -29)
		head = Vector2(2,top+5); shoulder = Vector2(0,top+10); hip = Vector2(-3,-7)
		knee_back = Vector2(-7,-4); foot_back = Vector2(-5,-2)
		knee_front = Vector2(7,-6); foot_front = Vector2(9,-2)
		elbow_back = Vector2(-7,top+13); hand_back = Vector2(-4,top+16)
		elbow_front = Vector2(8,top+12); hand_front = Vector2(8,top+8)
		if frame == 26: shoulder.x = 2; head.x = 4; elbow_front = Vector2(6,-13); hand_front = Vector2(9,-12)
	if frame >= 18 and frame <= 21:
		var step: int = frame-18
		shoulder = Vector2(2,-28); head = Vector2(3,-34)
		hip.y = -17 + step%2
		knee_front = [Vector2(6,-11),Vector2(3,-10),Vector2(-5,-9),Vector2(0,-7)][step]
		foot_front = [Vector2(8,-2),Vector2(-2,-3),Vector2(-7,-4),Vector2(5,-2)][step]
		knee_back = [Vector2(-5,-9),Vector2(0,-7),Vector2(6,-11),Vector2(3,-10)][step]
		foot_back = [Vector2(-7,-4),Vector2(5,-2),Vector2(8,-2),Vector2(-2,-3)][step]
		elbow_front = Vector2(7,-23+step%2); hand_front = Vector2(9,-28+step%2)
		elbow_back = Vector2(-6,-23); hand_back = Vector2(-4,-28+step%2)
		if kind == 2: head.y += 2; shoulder.y += 2; hip.y += 1
	if frame >= 22 and frame <= 24:
		elbow_front = Vector2(6,-25); hand_front = Vector2(9,-23)
		if frame == 22: shoulder.x = -2; head.x = -2; elbow_front = Vector2(-6,-19); hand_front = Vector2(-10,-23)
		if frame == 23: shoulder.x = 4; head.x = 4; knee_front.x = 8; foot_front.x = 10
	if frame >= 27:
		match frame:
			27:
				shoulder = Vector2(-5,-28); head = Vector2(-6,-34)
				elbow_front = Vector2(6,-27); hand_front = Vector2(10,-30)
			28:
				hip = Vector2(-3,-9); shoulder = Vector2(-8,-21); head = Vector2(-10,-27)
				knee_front = Vector2(6,-4); foot_front = Vector2(9,-2)
				elbow_front = Vector2(0,-17); hand_front = Vector2(4,-12)
				elbow_back = Vector2(-13,-17); hand_back = Vector2(-15,-10)
			29:
				hip = Vector2(-4,-7); shoulder = Vector2(-15,-11); head = Vector2(-19,-15)
				knee_front = Vector2(6,-6); foot_front = Vector2(13,-2)
				knee_back = Vector2(2,-3); foot_back = Vector2(9,-2)
				elbow_front = Vector2(-13,-5); hand_front = Vector2(-21,-3)
				elbow_back = Vector2(-17,-8); hand_back = Vector2(-24,-4)
			_:
				hip = Vector2(-2,-4); shoulder = Vector2(-15,-5); head = Vector2(-23,-6)
				knee_front = Vector2(8,-4); foot_front = Vector2(17,-2)
				knee_back = Vector2(5,-3); foot_back = Vector2(12,-2)
				elbow_front = Vector2(-13,-2); hand_front = Vector2(-21,-2)
				elbow_back = Vector2(-11,-6); hand_back = Vector2(-18,-5)
		if kind == 2:
			# Blue is already crouched when hit: never pop upright to borrow Red's stagger.
			if frame == 27:
				head = Vector2(-3,-19); shoulder = Vector2(-2,-13); hip = Vector2(-3,-7)
				elbow_front = Vector2(5,-14); hand_front = Vector2(8,-17)
				elbow_back = Vector2(-7,-12); hand_back = Vector2(-8,-8)
				knee_front = Vector2(6,-5); foot_front = Vector2(8,-2)
				knee_back = Vector2(-6,-4); foot_back = Vector2(-4,-2)
			elif frame == 28:
				head = Vector2(-6,-15); shoulder = Vector2(-5,-10); hip = Vector2(-2,-6)
				elbow_front = Vector2(0,-8); hand_front = Vector2(4,-3)
				elbow_back = Vector2(-10,-8); hand_back = Vector2(-13,-3)
				knee_front = Vector2(5,-4); foot_front = Vector2(8,-2)
			elif frame == 29:
				head = Vector2(-13,-9); shoulder = Vector2(-9,-6)
			else:
				head = Vector2(-19,-5); shoulder = Vector2(-11,-5)
				knee_front = Vector2(5,-6); foot_front = Vector2(9,-2)
				elbow_front = Vector2(-10,-2); hand_front = Vector2(-17,-2)
		if frame == 31: hand_front.x -= 1 # Last held frame relaxes the bracing hand.
	# Back limbs, belted tunic, then foreground limbs give useful negative space and depth.
	limb(hip+Vector2(-2,0),knee_back,foot_back,4,false)
	limb(shoulder+Vector2(-2,0),elbow_back,hand_back,3,false)
	var waist := shoulder.lerp(hip,0.72)
	poly([shoulder+Vector2(-5,-2),shoulder+Vector2(5,-2),waist+Vector2(4,0),hip+Vector2(6,3),hip+Vector2(-5,3),waist+Vector2(-4,0)],INK)
	poly([shoulder+Vector2(-3,-1),shoulder+Vector2(4,-1),waist+Vector2(3,0),hip+Vector2(4,1),hip+Vector2(-3,1)],ramp[1])
	poly([shoulder+Vector2(-3,0),shoulder+Vector2(1,1),waist+Vector2(0,-2),waist+Vector2(-3,0)],ramp[2])
	stroke(shoulder+Vector2(3,1),waist+Vector2(-1,-2),1,ramp[0])
	stroke(hip+Vector2(-4,-2),hip+Vector2(4,-2),2,ramp[0])
	box(int(hip.x)-1,int(hip.y)-3,3,2,ramp[4])
	stroke(hip+Vector2(1,-1),hip+Vector2(3,3),2,ramp[1])
	limb(hip+Vector2(2,0),knee_front,foot_front,4,true)
	var dynamic_hand: bool = (kind == 1 and frame in [18,19,20,21,22,23,24]) or (kind == 2 and frame in [15,25,26])
	if not dynamic_hand: limb(shoulder+Vector2(2,0),elbow_front,hand_front,3,true)
	# Red's weapon hand and Blue's striking fist are rendered from their real transforms.
	if not dynamic_hand:
		box(int(hand_front.x)-1,int(hand_front.y)-1,3,2,SKIN)
		pixel(int(hand_front.x)+1,int(hand_front.y)-1,LIGHT)
	# Hood: stepped crown, brow, eye slit, mask and three deliberate cloth highlight clusters.
	var hx: int = int(head.x); var hy: int = int(head.y)
	poly([Vector2(hx-5,hy-3),Vector2(hx-3,hy-5),Vector2(hx+3,hy-5),Vector2(hx+5,hy-2),Vector2(hx+5,hy+4),Vector2(hx-4,hy+5)],INK)
	box(hx-3,hy-4,6,2,ramp[1]); box(hx-4,hy-2,8,6,ramp[1])
	box(hx-3,hy-3,2,2,ramp[2]); box(hx-4,hy-1,8,1,ramp[4])
	box(hx+1,hy,4,2,SKIN); pixel(hx+3,hy,LIGHT); pixel(hx+2,hy+1,INK)
	box(hx,hy+2,4,2,ramp[0]); box(hx-3,hy+2,2,1,ramp[2])
	if frame < 27:
		stroke(Vector2(hx-4,hy),Vector2(hx-10,hy+2+(frame%2)),2,ramp[4])
		pixel(hx-11,hy+3,ramp[1])
	if frame == 9: # The high-kick shoe lies wholly inside x=14..36, y=-33..-27.
		box(30,-33,6,6,INK); box(30,-32,5,4,ramp[2]); box(32,-32,3,1,ramp[3])
	if frame == 5: # Knuckle edge stays inside the existing x=6..25.5, y=-25..-21 punch region.
		box(21,-25,4,4,INK); box(22,-24,3,2,SKIN); box(23,-24,2,1,LIGHT)

func build_hazards() -> void:
	# An 18 px drawn circle matches radius 9; one transparent pixel pads each 20 px cell.
	canvas = Image.create(160,20,false,Image.FORMAT_RGBA8)
	for frame in range(8):
		origin = Vector2i(frame*20+10,10)
		var angle: float = frame*PI/4.0
		for y in range(-9,9):
			for x in range(-9,9):
				var radius: float = Vector2(x+0.5,y+0.5).length()
				if radius > 9: continue
				var colour := Color("271c20")
				if radius < 8:
					# Inverse lookup rotates the drawn end-face clockwise as the frame increases.
					# Eight frames cover a whole revolution, avoiding a half-turn reset.
					var rotated := Vector2(x+0.5,y+0.5).rotated(-angle)
					colour = Color("8e542e") if posmod(int(rotated.x),4) < 3 else Color("462d25")
					if x+y < -2: colour = colour.lightened(0.16)
					if absf(rotated.y) > 4 and absf(rotated.y) < 7: colour = Color("829395") if x+y < 0 else Color("354657")
					# A plug away from the axle makes travel direction visible throughout the roll.
					if rotated.distance_to(Vector2(0,-4)) < 1.5: colour = Color("e4b571")
				pixel(x,y,colour)
		box(-1,-1,2,2,Color("2a2225"))
	canvas.save_png("res://art/combat/barrel.png")
	canvas = Image.create(32,8,false,Image.FORMAT_RGBA8)
	for frame in range(4):
		origin = Vector2i(frame*8+4,4)
		var points := []
		for point in range(8):
			var angle: float = point*PI/4+frame*PI/8
			points.append(Vector2(cos(angle),sin(angle))*(4.0 if point%2 == 0 else 1.7))
		poly(points,Color("728f9f"))
		stroke(Vector2(-1,0),Vector2(2,-2).rotated(frame*PI/8),1,Color("eff4df"))
		box(-1,-1,2,2,INK)
	canvas.save_png("res://art/combat/shuriken.png")

func build_background() -> void:
	for frame in range(5):
		canvas = Image.create(24,32,false,Image.FORMAT_RGBA8); origin = Vector2i(12,31)
		var ink := Color.WHITE
		var paused: bool = frame == 4
		var stride: int = [4,1,-4,-1,0][frame]
		poly([Vector2(-3,-28),Vector2(-1,-31),Vector2(3,-30),Vector2(4,-26),Vector2(2,-24),Vector2(-2,-24)],ink)
		poly([Vector2(-2,-24),Vector2(3,-24),Vector2(5,-14),Vector2(4,-9),Vector2(-5,-9),Vector2(-4,-19)],ink)
		stroke(Vector2(-2,-11),Vector2(-stride,-2),3,ink)
		stroke(Vector2(2,-11),Vector2(stride,-1),3,ink)
		stroke(Vector2(-4,-21),Vector2(-5-int(stride/2.0),-12),2,ink)
		stroke(Vector2(4,-21),Vector2(6+int(stride/2.0),-13),2,ink)
		if paused: stroke(Vector2(5,-17),Vector2(1,-14),2,ink)
		canvas.save_png("res://art/combat/adult_%d.png"%frame)
	for frame in range(4):
		canvas = Image.create(28,18,false,Image.FORMAT_RGBA8); origin = Vector2i(13,17)
		poly([Vector2(-9,-9),Vector2(-5,-12),Vector2(5,-11),Vector2(7,-15),Vector2(9,-17),Vector2(10,-13),Vector2(14,-10),Vector2(11,-8),Vector2(6,-8),Vector2(4,-5),Vector2(-7,-5)],Color.WHITE)
		var step: int = [2,0,-2,0][frame]
		stroke(Vector2(-6,-6),Vector2(-6+step,-1),2,Color.WHITE)
		stroke(Vector2(4,-6),Vector2(4-step,-1),2,Color.WHITE)
		stroke(Vector2(-8,-8),Vector2(-11,-13),2,Color.WHITE)
		pixel(10,-12,Color.TRANSPARENT)
		canvas.save_png("res://art/combat/dog_%d.png"%frame)
	for frame in range(3):
		canvas = Image.create(64,84,false,Image.FORMAT_RGBA8); origin = Vector2i(26,0)
		var shadow := Color("111527")
		# Lantern cage, bracket and a stepped door-timber projection, all hard pixel edges.
		poly([Vector2(-3,14),Vector2(4,14),Vector2(9+frame,46),Vector2(5,51),Vector2(-8-frame,49)],shadow)
		box(-6,27,13+frame,2,shadow); box(-7,35,15+frame,2,shadow)
		poly([Vector2(20,0),Vector2(23,0),Vector2(34,71),Vector2(30-frame,71)],shadow)
		for row in range(4): box(-18+row*4,73+row*3,34-row*7,1,Color("754a2f"))
		canvas.save_png("res://art/combat/lamp_shadow_%d.png"%frame)

extends RefCounted
class_name WorldHeroSheetBuilder
## Procedural placeholder: one hero, 8 directions, stand (1×8) + walk (4×8) cells, real RGBA (no matte).

const FRAME_W := 56
const FRAME_H := 64
const WALK_FRAME_COUNT := 4
const DIR_COUNT := 8

## 1/sqrt(2); must not use `.normalized()` here (not a constant expression for const arrays).
const _INV_SQRT2 := 0.7071067811865476

## Clockwise from screen-down (south), matching typical top-down / oblique navigation.
const FACING_ORDER: Array[Vector2] = [
	Vector2.DOWN,
	Vector2(_INV_SQRT2, _INV_SQRT2),
	Vector2.RIGHT,
	Vector2(_INV_SQRT2, -_INV_SQRT2),
	Vector2.UP,
	Vector2(-_INV_SQRT2, -_INV_SQRT2),
	Vector2.LEFT,
	Vector2(-_INV_SQRT2, _INV_SQRT2),
]

const _C_SHADOW := Color(0.1, 0.12, 0.2, 0.42)
const _C_CLOAK := Color(0.36, 0.58, 0.9)
const _C_CLOAK_DARK := Color(0.2, 0.34, 0.62)
const _C_HOOD := Color(0.24, 0.38, 0.68)
const _C_SKIN := Color(0.93, 0.76, 0.6)
const _C_SASH := Color(0.82, 0.32, 0.45)
const _C_BOOT := Color(0.28, 0.2, 0.16)

static var _cached_frames: SpriteFrames = null


static func get_sprite_frames() -> SpriteFrames:
	if _cached_frames != null:
		return _cached_frames
	_cached_frames = _build_sprite_frames()
	return _cached_frames


static func direction_index_for_velocity(v: Vector2) -> int:
	var best_i := 0
	var best_dot := -10.0
	var n := v.normalized()
	for i in DIR_COUNT:
		var d: float = n.dot(FACING_ORDER[i])
		if d > best_dot:
			best_dot = d
			best_i = i
	return best_i


static func _build_sprite_frames() -> SpriteFrames:
	var stand_tex := ImageTexture.create_from_image(_raster_stand_sheet())
	var walk_tex := ImageTexture.create_from_image(_raster_walk_sheet())
	var sf := SpriteFrames.new()
	var anim_stand := &"stand"
	var anim_walk := &"walk"
	sf.add_animation(anim_stand)
	sf.set_animation_loop(anim_stand, true)
	sf.set_animation_speed(anim_stand, 1.0)
	for d in range(DIR_COUNT):
		var at := AtlasTexture.new()
		at.atlas = stand_tex
		at.region = Rect2(d * FRAME_W, 0, FRAME_W, FRAME_H)
		sf.add_frame(anim_stand, at)
	sf.add_animation(anim_walk)
	sf.set_animation_loop(anim_walk, true)
	sf.set_animation_speed(anim_walk, 1.0)
	for d in range(DIR_COUNT):
		for f in range(WALK_FRAME_COUNT):
			var aw := AtlasTexture.new()
			aw.atlas = walk_tex
			aw.region = Rect2(f * FRAME_W, d * FRAME_H, FRAME_W, FRAME_H)
			sf.add_frame(anim_walk, aw)
	return sf


static func _raster_stand_sheet() -> Image:
	var img := Image.create(FRAME_W * DIR_COUNT, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for d in range(DIR_COUNT):
		_blit_frame(img, d * FRAME_W, 0, FACING_ORDER[d], 0)
	return img


static func _raster_walk_sheet() -> Image:
	var img := Image.create(
		FRAME_W * WALK_FRAME_COUNT, FRAME_H * DIR_COUNT, false, Image.FORMAT_RGBA8
	)
	img.fill(Color(0, 0, 0, 0))
	for d in range(DIR_COUNT):
		for f in range(WALK_FRAME_COUNT):
			_blit_frame(img, f * FRAME_W, d * FRAME_H, FACING_ORDER[d], f)
	return img


static func _blit_frame(img: Image, ox: int, oy: int, fwd: Vector2, walk_frame: int) -> void:
	var stride: float = 0.0
	if walk_frame >= 0:
		match walk_frame % WALK_FRAME_COUNT:
			0:
				stride = 0.0
			1:
				stride = 2.6
			2:
				stride = 0.0
			3:
				stride = -2.6
	var right := Vector2(-fwd.y, fwd.x)
	for y in range(FRAME_H):
		for x in range(FRAME_W):
			var c: Color = _sample_pixel(
				Vector2(float(x) + 0.5, float(y) + 0.5), fwd, right, stride
			)
			img.set_pixel(ox + x, oy + y, c)


static func _sample_pixel(p: Vector2, fwd: Vector2, right: Vector2, stride: float) -> Color:
	var feet := Vector2(float(FRAME_W) * 0.5, float(FRAME_H) - 10.0)
	var rel := p - feet
	var lf: float = rel.dot(fwd)
	var lr: float = rel.dot(right)
	var leg_stride: float = stride if lf > -8.0 else stride * 0.35
	lr += leg_stride

	## Screen-up stack + small forward lean so every facing reads as "feet bottom / head top".
	var head_c: Vector2 = feet + Vector2.UP * (-29.0) + fwd * 4.2 + right * (stride * 0.12)
	var dh: float = p.distance_to(head_c)
	if dh < 7.2:
		return _C_SKIN
	if dh < 10.5:
		return _C_HOOD

	var core: Vector2 = feet + Vector2.UP * (-14.5) + fwd * 2.4
	var u: float = (p - core).dot(fwd)
	var v: float = (p - core).dot(right)
	var au: float = (u + 1.5) / 20.5
	var av: float = v / 13.5
	if au * au + av * av <= 1.0:
		if u >= -6.0 and u <= -1.5 and absf(v) < 11.0:
			return _C_SASH
		return _C_CLOAK if v < 0.5 else _C_CLOAK.lerp(_C_CLOAK_DARK, 0.38)

	## Boots (small caps straddling feet).
	var bl: Vector2 = feet + right * (-4.5) + fwd * 1.2
	var br: Vector2 = feet + right * (4.5) + fwd * 1.2
	if (
		p.distance_to(bl + right * (stride * 0.4)) < 3.4
		or p.distance_to(br - right * (stride * 0.4)) < 3.4
	):
		return _C_BOOT

	var sh := p - (feet + fwd * 3.0 + Vector2(0, 3.0))
	if sh.length() < 13.0 and p.y > float(FRAME_H) - 14.0:
		return _C_SHADOW

	return Color(0, 0, 0, 0)

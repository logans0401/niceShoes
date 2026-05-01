extends RefCounted
class_name WorldHeroSheetBuilder
## 8-dir stand + walk from authored PNG atlases (`assets/sprites/world/`).
## Applies matte/checker nuking plus nearest-neighbour resize so stand row matches walk grid cell size.

const PATH_STAND := "res://assets/sprites/world/world_hero_stand.png"
const PATH_WALK := "res://assets/sprites/world/world_hero_walk.png"
const DIR_COUNT := 8
const WALK_FRAME_COUNT := 4

## Canonical cell after normalization (readable on screen with world_actor BODY_VISUAL_HEIGHT_PX).
const TARGET_CELL_WIDTH := 96
const TARGET_CELL_HEIGHT := 96

## 1/sqrt(2); constant expressions only (GDScript parser).
const _INV_SQRT2 := 0.7071067811865476

## Clockwise from screen-down — must match atlas row/frame order baked into PNGs.
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

static var _cached_frames: SpriteFrames = null
static var _native_cell: Vector2i = Vector2i(TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT)


static func get_native_frame_size() -> Vector2i:
	if _cached_frames == null:
		get_sprite_frames()
	return _native_cell


static func get_sprite_frames() -> SpriteFrames:
	if _cached_frames != null:
		return _cached_frames
	if not ResourceLoader.exists(PATH_STAND) or not ResourceLoader.exists(PATH_WALK):
		return null
	var raw_st := load(PATH_STAND) as Texture2D
	var raw_wk := load(PATH_WALK) as Texture2D
	if raw_st == null or raw_wk == null:
		return null
	var im_st := _prepared_stand_image(raw_st)
	var im_wk := _prepared_walk_image(raw_wk)
	if im_st == null or im_wk == null:
		return null
	var tex_stand := ImageTexture.create_from_image(im_st)
	var tex_walk := ImageTexture.create_from_image(im_wk)
	_cached_frames = _build_sprite_frames(tex_stand, tex_walk)
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


static func _prepared_stand_image(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	var dup: Image = img.duplicate() as Image
	_scrub_sprite_matte(dup)
	dup.resize(TARGET_CELL_WIDTH * DIR_COUNT, TARGET_CELL_HEIGHT, Image.INTERPOLATE_NEAREST)
	return dup


static func _prepared_walk_image(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	var dup: Image = img.duplicate() as Image
	_scrub_sprite_matte(dup)
	dup.resize(
		TARGET_CELL_WIDTH * WALK_FRAME_COUNT,
		TARGET_CELL_HEIGHT * DIR_COUNT,
		Image.INTERPOLATE_NEAREST
	)
	return dup


static func _scrub_sprite_matte(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y_i in range(h):
		for x_i in range(w):
			var c: Color = img.get_pixel(x_i, y_i)
			var lum: float = c.get_luminance()
			var dv: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
			var kill := false
			if lum >= 0.93 and dv <= 0.12:
				kill = true
			elif lum >= 0.68 and dv <= 0.045:
				kill = true
			elif lum >= 0.34 and lum <= 0.72 and dv <= 0.022:
				kill = true
			if kill:
				img.set_pixel(x_i, y_i, Color(0.0, 0.0, 0.0, 0.0))


static func _build_sprite_frames(stand_tex: Texture2D, walk_tex: Texture2D) -> SpriteFrames:
	_native_cell = Vector2i(TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT)
	var sf := SpriteFrames.new()
	var anim_stand := &"stand"
	var anim_walk := &"walk"
	sf.add_animation(anim_stand)
	sf.set_animation_loop(anim_stand, true)
	for d in range(DIR_COUNT):
		var at := AtlasTexture.new()
		at.atlas = stand_tex
		at.region = Rect2(d * TARGET_CELL_WIDTH, 0, TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT)
		sf.add_frame(anim_stand, at)
	sf.add_animation(anim_walk)
	sf.set_animation_loop(anim_walk, true)
	for d in range(DIR_COUNT):
		for f in range(WALK_FRAME_COUNT):
			var aw := AtlasTexture.new()
			aw.atlas = walk_tex
			aw.region = Rect2(
				f * TARGET_CELL_WIDTH, d * TARGET_CELL_HEIGHT, TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT
			)
			sf.add_frame(anim_walk, aw)
	return sf

extends RefCounted
class_name WorldHeroSheetBuilder
## 8-dir stand + walk from authored PNG atlases (`assets/sprites/world/`).
## Author sheets are often non-square cells (e.g. wide×short); each cell is cropped to a centered
## square before downscaling so nearest-neighbour resize does not smear into flat “pancake” bands.

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

## Bump when atlas load/normalisation changes so static cache cannot serve stale visuals (editor hot reload).
const _PIPELINE_VERSION := 2

static var _cached_pipeline_version: int = -1
static var _cached_frames: SpriteFrames = null
static var _native_cell: Vector2i = Vector2i(TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT)


static func get_native_frame_size() -> Vector2i:
	if _cached_frames == null:
		get_sprite_frames()
	return _native_cell


static func get_sprite_frames() -> SpriteFrames:
	if _cached_frames != null and _cached_pipeline_version == _PIPELINE_VERSION:
		return _cached_frames
	if not ResourceLoader.exists(PATH_STAND) or not ResourceLoader.exists(PATH_WALK):
		return null
	var raw_st := load(PATH_STAND) as Texture2D
	var raw_wk := load(PATH_WALK) as Texture2D
	if raw_st == null or raw_wk == null:
		return null
	var im_st := _normalize_stand_atlas(raw_st)
	var im_wk := _normalize_walk_atlas(raw_wk)
	if im_st == null or im_wk == null:
		return null
	var tex_stand := ImageTexture.create_from_image(im_st)
	var tex_walk := ImageTexture.create_from_image(im_wk)
	_cached_frames = _build_sprite_frames(tex_stand, tex_walk)
	_cached_pipeline_version = _PIPELINE_VERSION
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


static func _normalize_stand_atlas(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cell_w: int = int(w / DIR_COUNT)
	if cell_w <= 1 or h <= 1:
		return null
	var side: int = mini(cell_w, h)
	var y0: int = int(maxi(0, (h - side) / 2))
	var out := Image.create(side * DIR_COUNT, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in range(DIR_COUNT):
		var rx := int(i * cell_w + (cell_w - side) / 2)
		out.blit_rect(img, Rect2i(rx, y0, side, side), Vector2i(i * side, 0))
	out.resize(TARGET_CELL_WIDTH * DIR_COUNT, TARGET_CELL_HEIGHT, Image.INTERPOLATE_NEAREST)
	return out


static func _normalize_walk_atlas(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cw: int = int(w / WALK_FRAME_COUNT)
	var ch: int = int(h / DIR_COUNT)
	if cw <= 1 or ch <= 1:
		return null
	var side: int = mini(cw, ch)
	var out := Image.create(side * WALK_FRAME_COUNT, side * DIR_COUNT, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for d in range(DIR_COUNT):
		for f in range(WALK_FRAME_COUNT):
			var rx := int(f * cw + (cw - side) / 2)
			var ry := int(d * ch + (ch - side) / 2)
			out.blit_rect(img, Rect2i(rx, ry, side, side), Vector2i(f * side, d * side))
	out.resize(
		TARGET_CELL_WIDTH * WALK_FRAME_COUNT,
		TARGET_CELL_HEIGHT * DIR_COUNT,
		Image.INTERPOLATE_NEAREST
	)
	return out


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

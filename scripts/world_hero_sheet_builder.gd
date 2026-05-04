extends RefCounted
class_name WorldHeroSheetBuilder
## 8-dir stand + walk from PNG atlases. Grid dividers rarely match opaque pixels; we matte-scrub
## the sheet, tighten each cell with an alpha bounding box, center the patch in a square, then resize.

const PATH_STAND := "res://assets/sprites/world/world_hero_stand.png"
const PATH_WALK := "res://assets/sprites/world/world_hero_walk.png"
const DIR_COUNT := 8
const WALK_FRAME_COUNT := 4

## Canonical atlas cell after normalization.
const TARGET_CELL_WIDTH := 96
const TARGET_CELL_HEIGHT := 96

const _ALPHA_CUTOFF := 0.085

## 1/sqrt(2); constant expressions only (GDScript parser).
const _INV_SQRT2 := 0.7071067811865476

## Clockwise from screen-down — must match logical facing vectors.
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

## Idle and walk atlases share the same column order left-to-right: S, SE, E, NE, N, NW, W, SW
## (`FACING_ORDER` / `direction_index_for_velocity`).
const _SOURCE_DIRECTION_INDEX := [0, 1, 2, 3, 4, 5, 6, 7]

const _PIPELINE_VERSION := 10

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
	## Explicit octants match Godot coords (+x right, +y down) and idle/walk atlas column ordering (S clockwise).
	if v.length_squared() < 1e-8:
		return 0
	var n := v.normalized()
	var x := float(n.x)
	var y := float(n.y)
	const D := 0.38
	var ax := absf(x)
	var ay := absf(y)
	if ax > D and ay > D:
		if x > 0.0:
			return 1 if y > 0.0 else 3  ## SE vs NE (down/right vs up/right)
		return 7 if y > 0.0 else 5  ## SW vs NW (down/left vs up/left)
	if ax >= ay:
		return 2 if x > 0.0 else 6
	return 0 if y > 0.0 else 4


static func _normalize_stand_atlas(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	_scrub_import_matte(img)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cell_w: int = int(w / DIR_COUNT)
	if cell_w <= 1 or h <= 1:
		return null
	var out := Image.create(
		TARGET_CELL_WIDTH * DIR_COUNT, TARGET_CELL_HEIGHT, false, Image.FORMAT_RGBA8
	)
	out.fill(Color(0, 0, 0, 0))
	for logical_i in range(DIR_COUNT):
		var src_ix: int = int(_SOURCE_DIRECTION_INDEX[logical_i])
		var cell := Rect2i(src_ix * cell_w, 0, cell_w, h)
		var bbox := _opaque_bbox_within(img, cell)
		var min_w := maxi(mini(32, cell_w / 6), 14)
		if bbox.size.x < min_w or bbox.size.y < 14:
			bbox = _fallback_bottom_square(cell)
		else:
			bbox = _clip_bbox_to_cell(bbox, cell)
		bbox = _clamp_rect_to_image(bbox, w, h)
		var patch: Image = img.get_region(bbox)
		var cell_img := _square_pack_resize(patch)
		out.blit_rect(
			cell_img,
			Rect2i(0, 0, TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT),
			Vector2i(logical_i * TARGET_CELL_WIDTH, 0)
		)
	return out


static func _normalize_walk_atlas(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	_scrub_import_matte(img)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var col_w: int = int(w / DIR_COUNT)
	var row_h: int = int(h / WALK_FRAME_COUNT)
	if col_w <= 1 or row_h <= 1:
		return null
	var out := Image.create(
		TARGET_CELL_WIDTH * WALK_FRAME_COUNT,
		TARGET_CELL_HEIGHT * DIR_COUNT,
		false,
		Image.FORMAT_RGBA8
	)
	out.fill(Color(0, 0, 0, 0))
	for logical_dir in range(DIR_COUNT):
		var src_col: int = int(_SOURCE_DIRECTION_INDEX[logical_dir])
		for f in range(WALK_FRAME_COUNT):
			var cell := Rect2i(src_col * col_w, f * row_h, col_w, row_h)
			var bbox := _opaque_bbox_within(img, cell)
			var min_w := maxi(mini(32, col_w / 6), 14)
			if bbox.size.x < min_w or bbox.size.y < 14:
				bbox = _fallback_bottom_square(cell)
			else:
				bbox = _clip_bbox_to_cell(bbox, cell)
			bbox = _clamp_rect_to_image(bbox, w, h)
			var patch: Image = img.get_region(bbox)
			var cell_img := _square_pack_resize(patch)
			out.blit_rect(
				cell_img,
				Rect2i(0, 0, TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT),
				Vector2i(f * TARGET_CELL_WIDTH, logical_dir * TARGET_CELL_HEIGHT)
			)
	return out


static func _opaque_bbox_within(img: Image, bounds: Rect2i) -> Rect2i:
	var xa := bounds.position.x
	var ya := bounds.position.y
	var xb := bounds.position.x + bounds.size.x
	var yb := bounds.position.y + bounds.size.y
	var min_x := xb
	var min_y := yb
	var max_x := xa
	var max_y := ya
	var any := false
	for y_i in range(ya, yb):
		if y_i < 0 or y_i >= img.get_height():
			continue
		for x_i in range(xa, xb):
			if x_i < 0 or x_i >= img.get_width():
				continue
			if img.get_pixel(x_i, y_i).a <= _ALPHA_CUTOFF:
				continue
			any = true
			min_x = mini(min_x, x_i)
			min_y = mini(min_y, y_i)
			max_x = maxi(max_x, x_i)
			max_y = maxi(max_y, y_i)
	if not any:
		return Rect2i(xa, ya, mini(4, bounds.size.x), mini(4, bounds.size.y))
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _clip_bbox_to_cell(bbox: Rect2i, cell: Rect2i) -> Rect2i:
	var x0 := maxi(bbox.position.x, cell.position.x)
	var y0 := maxi(bbox.position.y, cell.position.y)
	var x1 := mini(bbox.position.x + bbox.size.x, cell.position.x + cell.size.x)
	var y1 := mini(bbox.position.y + bbox.size.y, cell.position.y + cell.size.y)
	if x1 <= x0 or y1 <= y0:
		return _fallback_bottom_square(cell)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


static func _fallback_bottom_square(cell: Rect2i) -> Rect2i:
	var s := mini(cell.size.x, cell.size.y)
	s = maxi(s, 2)
	var ox := cell.position.x + int((cell.size.x - s) / 2)
	var oy := cell.position.y + int(maxi(0, cell.size.y - s))
	return Rect2i(ox, oy, s, s)


static func _clamp_rect_to_image(r: Rect2i, iw: int, ih: int) -> Rect2i:
	if iw < 1 or ih < 1:
		return r
	var ax := clampi(r.position.x, 0, iw - 1)
	var ay := clampi(r.position.y, 0, ih - 1)
	var bx := clampi(r.position.x + r.size.x - 1, ax, iw - 1)
	var by := clampi(r.position.y + r.size.y - 1, ay, ih - 1)
	return Rect2i(ax, ay, bx - ax + 1, by - ay + 1)


static func _square_pack_resize(patch: Image) -> Image:
	var pw: int = patch.get_width()
	var ph: int = patch.get_height()
	if pw <= 1 or ph <= 1:
		var empty := Image.create(TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT, false, Image.FORMAT_RGBA8)
		empty.fill(Color(0, 0, 0, 0))
		return empty
	var s: int = maxi(pw, ph)
	var canvas := Image.create(s, s, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var ox: int = int((s - pw) / 2)
	var oy: int = int((s - ph) / 2)
	canvas.blit_rect(patch, Rect2i(0, 0, pw, ph), Vector2i(ox, oy))
	canvas.resize(TARGET_CELL_WIDTH, TARGET_CELL_HEIGHT, Image.INTERPOLATE_NEAREST)
	return canvas


static func _scrub_import_matte(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y_i in range(h):
		for x_i in range(w):
			var c: Color = img.get_pixel(x_i, y_i)
			var lum: float = c.get_luminance()
			var dv: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
			var wipe := false
			## Matte / faux-transparency filler (checker or white glue).
			if c.a >= 0.94 and lum >= 0.90 and dv <= 0.10:
				wipe = true
			elif c.a >= 0.94 and lum >= 0.75 and lum <= 0.99 and dv <= 0.048:
				wipe = true
			elif c.a >= 0.94 and lum >= 0.33 and lum <= 0.75 and dv <= 0.028:
				wipe = true
			if wipe:
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

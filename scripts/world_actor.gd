extends "res://scripts/player_controller.gd"
## In-world body for a logged-in character; only one actor receives movement input at a time.
## Placeholder silhouette strips (four archetypes × 4 walk frames); tinted from party card portrait color.

signal meditation_resource_tick(character_id: StringName, kind: StringName, amount: float)

const ARCHETYPE_STRIPS: Array[String] = [
	"res://assets/sprites/world/world_archetype_scholar_strip.png",
	"res://assets/sprites/world/world_archetype_scout_strip.png",
	"res://assets/sprites/world/world_archetype_knight_strip.png",
	"res://assets/sprites/world/world_archetype_cleric_strip.png",
]

const STRIP_COLUMNS := 4
const MOVE_THRESH_SPEED := 34.0
const WALK_FPS := 9.5
const BODY_VISUAL_HEIGHT_PX := 46.0

var character_id: StringName = &""
var is_controlled: bool = false
var is_meditating: bool = false
var _automation_velocity: Vector2 = Vector2.ZERO
var _hunt_nav_active: bool = false
var _med_hp_t: float = 0.0
var _med_st_t: float = 0.0
var _using_polygon_fallback: bool = false

@onready var _cam: Camera2D = $Camera2D
@onready var _glyph: Polygon2D = $Glyph
@onready var _body_sprite: AnimatedSprite2D = $BodySprite
@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group(&"world_party_actors")
	if _cam != null:
		_cam.enabled = false
	if _nav_agent != null:
		_nav_agent.path_desired_distance = 8.0
		_nav_agent.target_desired_distance = 22.0
	call_deferred(&"_ensure_placeholder_sprite")


func _process(_delta: float) -> void:
	_update_sprite_from_velocity()


func set_actor_id(id: StringName) -> void:
	character_id = id
	call_deferred(&"_ensure_placeholder_sprite")


func set_glyph_color(col: Color) -> void:
	col.a = 1.0
	if _using_polygon_fallback and _glyph != null:
		_glyph.color = col
	else:
		## Tint greyscale sprites with card color (readable identity on the placeholder art).
		_body_sprite.modulate = col.lightened(0.12)


func set_meditating(on: bool) -> void:
	is_meditating = on
	if on:
		set_hunt_navigation_active(false)
		_automation_velocity = Vector2.ZERO
		_med_hp_t = 0.0
		_med_st_t = 0.0
	else:
		_med_hp_t = 0.0
		_med_st_t = 0.0


func set_controlled(on: bool) -> void:
	is_controlled = on
	if _cam != null:
		_cam.enabled = on
		if on:
			call_deferred(&"_apply_default_play_zoom")


func adjust_camera_zoom_wheel(zoom_in: bool) -> void:
	if _cam == null:
		return
	var f: float = GameConstants.CAMERA_ZOOM_WHEEL_FACTOR
	var z: float = _cam.zoom.x
	if zoom_in:
		z *= f
	else:
		z /= f
	z = clampf(z, GameConstants.CAMERA_ZOOM_MIN, GameConstants.CAMERA_ZOOM_MAX)
	_cam.zoom = Vector2(z, z)


func _apply_default_play_zoom() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		var sv := get_viewport() as SubViewport
		vp = Vector2(sv.size) if sv != null else Vector2(960, 540)
	var z: float = GameConstants.default_camera_zoom_for_viewport(vp)
	if z > 0.0:
		z = clampf(z, GameConstants.CAMERA_ZOOM_MIN, GameConstants.CAMERA_ZOOM_MAX)
		_cam.zoom = Vector2(z, z)


func set_automation_velocity(v: Vector2) -> void:
	_automation_velocity = v


func set_hunt_navigation_active(on: bool) -> void:
	_hunt_nav_active = on
	if not on and _nav_agent != null:
		_nav_agent.target_position = global_position


func update_hunt_navigation_goal(world_pos: Vector2) -> void:
	if _nav_agent == null:
		return
	_nav_agent.target_position = world_pos


func _unhandled_input(event: InputEvent) -> void:
	if not is_meditating:
		return
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed:
			set_meditating(false)


func _hunt_ally_separation_velocity() -> Vector2:
	var min_d: float = float(GameConstants.HUNT_PARTY_SEPARATION_PX)
	var acc := Vector2.ZERO
	var self_p: Vector2 = global_position
	for n in get_tree().get_nodes_in_group(&"world_party_actors"):
		if n == self or not (n is Node2D):
			continue
		var op: Vector2 = (n as Node2D).global_position
		var d: Vector2 = self_p - op
		var dist: float = d.length()
		if dist >= min_d or dist < 0.001:
			continue
		var push: float = (min_d - dist) / min_d
		acc += d.normalized() * push
	if acc.length_squared() < 1e-8:
		return Vector2.ZERO
	return acc.normalized() * move_speed


func _apply_meditation_ticks(delta: float) -> void:
	set_hunt_navigation_active(false)
	_automation_velocity = Vector2.ZERO
	_med_hp_t += delta
	while _med_hp_t >= GameConstants.MEDITATION_HEALTH_INTERVAL_SEC:
		_med_hp_t -= GameConstants.MEDITATION_HEALTH_INTERVAL_SEC
		meditation_resource_tick.emit(
			character_id, &"health", GameConstants.MEDITATION_HEALTH_AMOUNT
		)
	_med_st_t += delta
	while _med_st_t >= GameConstants.MEDITATION_STAMINA_INTERVAL_SEC:
		_med_st_t -= GameConstants.MEDITATION_STAMINA_INTERVAL_SEC
		meditation_resource_tick.emit(
			character_id, &"stamina", GameConstants.MEDITATION_STAMINA_AMOUNT
		)
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func _physics_process(delta: float) -> void:
	if is_meditating:
		if is_controlled and _movement_input() != Vector2.ZERO:
			set_meditating(false)
		else:
			_apply_meditation_ticks(delta)
			return
	## Hunt pathing overrides manual control while the shell is steering toward a target.
	if _hunt_nav_active and _nav_agent != null:
		if _nav_agent.is_navigation_finished():
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			var next_pos: Vector2 = _nav_agent.get_next_path_position()
			var to_next: Vector2 = next_pos - global_position
			if to_next.length_squared() < 0.25:
				velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			else:
				var nav_vel: Vector2 = to_next.normalized() * move_speed
				var sep_vel: Vector2 = _hunt_ally_separation_velocity()
				var blend: float = float(GameConstants.HUNT_PARTY_SEPARATION_BLEND)
				var combined: Vector2 = nav_vel * (1.0 - blend) + sep_vel * blend
				if combined.length() > move_speed:
					combined = combined.normalized() * move_speed
				velocity = combined
		move_and_slide()
		return
	if is_controlled:
		_automation_velocity = Vector2.ZERO
		super._physics_process(delta)
		return
	if _automation_velocity.length_squared() > 4.0:
		velocity = _automation_velocity
		move_and_slide()
		return
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func _ensure_placeholder_sprite() -> void:
	if _body_sprite == null:
		return
	if character_id == &"":
		return
	var idx: int = abs(String(character_id).hash()) % ARCHETYPE_STRIPS.size()
	var path: String = ARCHETYPE_STRIPS[idx]
	if not ResourceLoader.exists(path):
		_use_polygon_fallback_texture_missing()
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_use_polygon_fallback_texture_missing()
		return
	_using_polygon_fallback = false
	_glyph.visible = false
	_body_sprite.visible = true
	_body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sf := _build_horizontal_strip_sprite_frames(tex, STRIP_COLUMNS)
	if sf == null:
		_use_polygon_fallback_texture_missing()
		return
	_body_sprite.sprite_frames = sf
	var fh: float = float(tex.get_height())
	if fh >= 8.0:
		var px: float = BODY_VISUAL_HEIGHT_PX / fh
		_body_sprite.scale = Vector2(px, px)
	_body_sprite.sprite_frames.set_animation_speed(&"walk", WALK_FPS)
	_body_sprite.play(&"walk")
	_body_sprite.playing = false
	_body_sprite.frame = 0


func _use_polygon_fallback_texture_missing() -> void:
	_using_polygon_fallback = true
	if _glyph != null:
		_glyph.visible = true
	if _body_sprite != null:
		_body_sprite.visible = false
		_body_sprite.sprite_frames = null


func _build_horizontal_strip_sprite_frames(tex: Texture2D, columns: int) -> SpriteFrames:
	if tex == null or columns < 1:
		return null
	var iw: int = tex.get_width()
	var ih: int = tex.get_height()
	var cw: int = int(floor(float(iw) / float(columns)))
	if cw <= 0 or ih <= 0:
		return null
	var sf := SpriteFrames.new()
	var anim := &"walk"
	sf.add_animation(anim)
	sf.set_animation_speed(anim, WALK_FPS)
	sf.set_animation_loop(anim, true)
	for col in range(columns):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(col * cw, 0, cw, ih)
		sf.add_frame(anim, at)
	return sf


func _update_sprite_from_velocity() -> void:
	if _using_polygon_fallback or _body_sprite == null or _body_sprite.sprite_frames == null:
		return
	var speed: float = velocity.length()
	if speed >= MOVE_THRESH_SPEED:
		_body_sprite.flip_h = velocity.x < -2.0
		if not _body_sprite.playing:
			_body_sprite.play(&"walk")
		_body_sprite.playing = true
	else:
		_body_sprite.playing = false
		_body_sprite.frame = 0

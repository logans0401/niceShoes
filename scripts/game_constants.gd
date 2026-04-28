extends RefCounted
class_name GameConstants

## One tile = 32×32 px for terrain, walls, props, and collision. Keep world positions on pixel boundaries for future pixel art.
const PLACEHOLDER_MAP := "res://maps/placeholder_map.tscn"
## Physics layer/mask bits (assign matching names in Project Settings → Layer Names → 2D Physics).
## World / static: layer 1. Party CharacterBody2D: layer 2 (no character–character contact). Enemies: layer 4.
const PHY_LAYER_WORLD := 1
const PHY_LAYER_CHARACTER := 2
const PHY_LAYER_ENEMY := 4
## World / automation grid unit (pixels).
const TILE_SIZE_PX := 32
## Default on-screen framing: about this many tiles visible in the world viewport (see `default_camera_zoom_for_viewport`).
const VISIBLE_PLAY_AREA_TILES_X := 20
const VISIBLE_PLAY_AREA_TILES_Y := 12
## Main exploration zone (tiles). Pixel size = × TILE_SIZE_PX. Placeholder map uses these; larger zones can be added later.
const MAP_MAIN_TILES_X := 80
const MAP_MAIN_TILES_Y := 60
## Interior / single-objective room template (tiles).
const MAP_SMALL_TILES_X := 40
const MAP_SMALL_TILES_Y := 30
## Follow: never move closer than this many tiles (reduces CharacterBody2D pile-ups on the leader).
const FOLLOW_MIN_SEPARATION_TILES := 1
## Follow: after catching up, resume chasing only when the leader is at least this many tiles away (hysteresis).
const FOLLOW_RESUME_CHASE_TILES := 3

## Hunt / assist: navigation targets sit on a ring around the enemy (fraction of melee reach) when multiple party members want the same target.
const HUNT_ENGAGEMENT_RING_FRACTION := 0.82
## While hunt-navigation is active, steer away from other party actors closer than this (pixels).
const HUNT_PARTY_SEPARATION_PX := 30.0
## How much hunt velocity can bend toward separation (0 = ignore, 1 = full sidestep strength).
const HUNT_PARTY_SEPARATION_BLEND := 0.62


## Uniform zoom for `Camera2D` so the viewport shows at least `VISIBLE_PLAY_AREA_TILES_*` tiles (fits the tighter axis, shows slightly more on the other).
static func default_camera_zoom_for_viewport(viewport_size: Vector2) -> float:
	var target_w: float = float(VISIBLE_PLAY_AREA_TILES_X * TILE_SIZE_PX)
	var target_h: float = float(VISIBLE_PLAY_AREA_TILES_Y * TILE_SIZE_PX)
	if target_w < 1.0 or target_h < 1.0 or viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return 1.0
	return minf(viewport_size.x / target_w, viewport_size.y / target_h)


static func main_map_size_px() -> Vector2:
	return Vector2(float(MAP_MAIN_TILES_X * TILE_SIZE_PX), float(MAP_MAIN_TILES_Y * TILE_SIZE_PX))


static func small_map_size_px() -> Vector2:
	return Vector2(float(MAP_SMALL_TILES_X * TILE_SIZE_PX), float(MAP_SMALL_TILES_Y * TILE_SIZE_PX))


## --- Camera (scroll zoom on world view) ---
## Minimum zoom = most zoomed **out** (see the largest area). Maximum = most zoomed **in**.
const CAMERA_ZOOM_MIN := 0.42
const CAMERA_ZOOM_MAX := 2.55
const CAMERA_ZOOM_WHEEL_FACTOR := 1.09

## --- Passive mana (out of combat baseline; Mind/Wisdom accelerate regen) ---
## At Mind `MANA_REGEN_REF_STAT` and Wisdom `MANA_REGEN_REF_STAT`, restore 1 mana every `MANA_REGEN_BASE_INTERVAL_SEC`.
## Interval = BASE / (1 + MANA_REGEN_PER_STAT_ABOVE_REF * (max(0, mind-ref) + max(0, wisdom-ref))).
const MANA_REGEN_BASE_INTERVAL_SEC := 10.0
const MANA_REGEN_REF_STAT := 10.0
const MANA_REGEN_PER_STAT_ABOVE_REF := 0.05


static func mana_regen_interval_sec(mind_attr: float, wisdom_attr: float) -> float:
	var bonus: float = MANA_REGEN_PER_STAT_ABOVE_REF * maxf(0.0, mind_attr - MANA_REGEN_REF_STAT)
	bonus += MANA_REGEN_PER_STAT_ABOVE_REF * maxf(0.0, wisdom_attr - MANA_REGEN_REF_STAT)
	return MANA_REGEN_BASE_INTERVAL_SEC / (1.0 + bonus)


## Meditation: HP and stamina pulses (mana uses passive formula above).
const MEDITATION_HEALTH_INTERVAL_SEC := 3.0
const MEDITATION_HEALTH_AMOUNT := 1.0
const MEDITATION_STAMINA_INTERVAL_SEC := 5.0
const MEDITATION_STAMINA_AMOUNT := 3.0

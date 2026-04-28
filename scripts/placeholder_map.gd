extends Node2D

## Root of placeholder maps; spawned world actors live under `Actors`.
## Bounds follow `GameConstants.MAP_MAIN_*` (default 80×60 tiles at 32 px).

const _EnemyScene := preload("res://maps/combat_test_enemy.tscn")
const RESPAWN_INTERVAL_SEC := 40.0

var _respawn_accum: float = 0.0


func _ready() -> void:
	_apply_main_map_floor_polygon()
	_ensure_navigation_region()
	_spawn_combat_test_enemies()


func _process(delta: float) -> void:
	_respawn_accum += delta
	if _respawn_accum >= RESPAWN_INTERVAL_SEC:
		_respawn_accum = 0.0
		_spawn_combat_test_enemies()


func get_actors_root() -> Node2D:
	return $Actors as Node2D


func _main_map_half_size() -> Vector2:
	return Vector2(
		float(GameConstants.MAP_MAIN_TILES_X * GameConstants.TILE_SIZE_PX) * 0.5,
		float(GameConstants.MAP_MAIN_TILES_Y * GameConstants.TILE_SIZE_PX) * 0.5,
	)


func _apply_main_map_floor_polygon() -> void:
	var floor_node: Polygon2D = get_node_or_null("Floor") as Polygon2D
	if floor_node == null:
		return
	var h: Vector2 = _main_map_half_size()
	floor_node.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y),
		Vector2(h.x, -h.y),
		Vector2(h.x, h.y),
		Vector2(-h.x, h.y),
	])


func _ensure_navigation_region() -> void:
	if get_node_or_null("NavigationRegion2D") != null:
		return
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var poly := NavigationPolygon.new()
	var h: Vector2 = _main_map_half_size()
	## Half-tile inset from the floor so paths stay inside walkable art.
	var inset: float = float(GameConstants.TILE_SIZE_PX) * 0.5
	var outline := PackedVector2Array([
		Vector2(-h.x + inset, -h.y + inset),
		Vector2(h.x - inset, -h.y + inset),
		Vector2(h.x - inset, h.y - inset),
		Vector2(-h.x + inset, h.y - inset),
	])
	poly.add_outline(outline)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	add_child(region)
	move_child(region, 0)


func _enemy_spawn_positions() -> Array:
	var h: Vector2 = _main_map_half_size()
	return [
		Vector2(h.x * 0.55, -h.y * 0.45),
		Vector2(-h.x * 0.5, h.y * 0.35),
		Vector2(h.x * 0.25, h.y * 0.55),
		Vector2(-h.x * 0.35, -h.y * 0.5),
		Vector2(h.x * 0.1, h.y * 0.1),
	]


func _spawn_combat_test_enemies() -> void:
	var old: Node = get_node_or_null("Enemies")
	if old != null:
		old.free()
	var host := Node2D.new()
	host.name = "Enemies"
	add_child(host)
	var spots: Array = _enemy_spawn_positions()
	for i in range(spots.size()):
		var e: Node = _EnemyScene.instantiate()
		e.position = spots[i]
		e.name = "target_%d" % (i + 1)
		host.add_child(e)

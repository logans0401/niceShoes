extends SceneTree
## One-off export: procedural world hero atlases as PNG files (see assets/sprites/world/).
## Usage: Godot --headless --path <project> -s res://tests/export_world_hero_atlases.gd

const _Builder := preload("res://scripts/world_hero_sheet_builder.gd")


func _init() -> void:
	var folder := ProjectSettings.globalize_path("res://assets/sprites/world/")
	DirAccess.make_dir_recursive_absolute(folder)
	var path_stand := folder.path_join("world_hero_stand_atlas.png")
	var path_walk := folder.path_join("world_hero_walk_atlas.png")
	var err_s := _Builder._raster_stand_sheet().save_png(path_stand)
	var err_w := _Builder._raster_walk_sheet().save_png(path_walk)
	if err_s != OK or err_w != OK:
		push_error(
			"export_world_hero_atlases: save failed stand=%s walk=%s" % [str(err_s), str(err_w)]
		)
		quit(1)
		print("FAILED")
	else:
		print("OK:", path_stand, " ", path_walk)
	quit(0)

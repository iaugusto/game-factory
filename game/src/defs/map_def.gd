class_name MapDef
extends Resource
## A battlefield, and a level: its paths from the portals to the gate, its build plots (some
## unlocking later), where the barricade may stand, its terrain, and its waves
## (docs/2026-09-26-maps-from-paths/). content_test.gd checks plots are inside the field and off
## every path, and that waves only use paths open by then.

@export var id: StringName
@export var display_name: String = ""
@export var paths: Array[PathDef] = []
## Plot centres in field units (x across, y down toward the wall).
@export var plots: PackedVector2Array = PackedVector2Array()
## Per plot (same order), the wave (1-based) from which it can be built on; missing or <= 1 =
## from the start.
@export var plot_unlock_waves: PackedInt32Array = PackedInt32Array()
## Where the one barricade may stand, on a path in front of the wall: it blocks every path
## passing through the slot.
@export var barricade_slots: PackedVector2Array = PackedVector2Array()
@export var zones: Array[ZoneDef] = []
## The look of its ground (the art generator's palette, tools/src/gf_tools/art/terrain.py
## BIOMES): "desert", "canyon", "tundra"; unknown or empty paints the neutral dusk look.
## Only the generator reads it; the game shows whatever ground was painted.
@export var biome: StringName = &""
## This map's waves (a run on it plays these; RunConfig.for_map).
@export var waves: Array[WaveDef] = []


## The wave (1-based) from which plot `i` can be built on.
func plot_unlock_wave(i: int) -> int:
	return maxi(1, plot_unlock_waves[i]) if i < plot_unlock_waves.size() else 1

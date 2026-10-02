extends GdUnitTestSuite
## Toolchain guard (B0): fails loudly if the project is opened with an engine other than the
## pinned 4.7.x, or if the portrait base resolution the layout assumes has drifted.


func test_engine_is_pinned_minor() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_int(info["major"]).is_equal(4)
	assert_int(info["minor"]).is_equal(7)


## E9: the design is the tall 19.5:9 shape (540×1170); 16:9 screens get extra width (expand).
func test_base_resolution_is_portrait_540x1170() -> void:
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_width")).is_equal(540)
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_height")).is_equal(1170)

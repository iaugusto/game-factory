extends Node
## Autoload "Services": picks the PlatformServices provider named by the project setting
## `game/platform/provider` (default "stub"). Gameplay calls Services.api.<method>(); it never
## names a platform itself.

const SETTING: String = "game/platform/provider"

## Provider factories by name. Real providers (steam, play, apple) register here as they land.
var factories: Dictionary[String, Callable] = {
	"stub": func() -> PlatformServices: return StubServices.new(),
}
var api: PlatformServices


func _init() -> void:
	api = create(ProjectSettings.get_setting(SETTING, "stub"))


## A provider by name; unknown names fall back to the stub with an error.
func create(provider: String) -> PlatformServices:
	if not factories.has(provider):
		push_error("Services: unknown provider '%s', using stub" % provider)
		provider = "stub"
	return factories[provider].call()

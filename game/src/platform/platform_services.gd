class_name PlatformServices
extends RefCounted
## The one door gameplay code uses for store/platform features: rewarded ads, purchases,
## achievements, analytics. Each platform (Play, App Store, Steam) gets a provider that
## extends this class; StubServices is the default and the only one used by tests.
##
## Results are delivered through callbacks rather than awaited signals, so a provider can
## answer synchronously (stub) or later (real SDK) behind the same call.
##
## Base methods fail safe: nothing is available, nothing succeeds.


func provider_name() -> String:
	return "none"


func is_rewarded_ad_ready(_placement: StringName) -> bool:
	return false


## Show a rewarded ad; `on_done(rewarded: bool)` is called once.
func show_rewarded_ad(_placement: StringName, on_done: Callable) -> void:
	on_done.call(false)


## Buy `sku`; `on_done(success: bool)` is called once.
func purchase(_sku: StringName, on_done: Callable) -> void:
	on_done.call(false)


func owns(_sku: StringName) -> bool:
	return false


func unlock_achievement(_id: StringName) -> void:
	pass


func log_event(_name: StringName, _params: Dictionary = {}) -> void:
	pass

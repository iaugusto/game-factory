class_name StubServices
extends PlatformServices
## Offline stand-in for every platform service. Ads always reward, purchases always succeed,
## and every call is recorded in `calls`, so tests and desktop builds exercise the real
## gameplay flows without any SDK, account or network.

## Each call as [method: StringName, args: Array], in order.
var calls: Array[Array] = []
var owned: Dictionary[StringName, bool] = {}
var achievements: Dictionary[StringName, bool] = {}
## Flip to simulate a failure path (declined ad, failed purchase).
var succeed: bool = true


func provider_name() -> String:
	return "stub"


func is_rewarded_ad_ready(placement: StringName) -> bool:
	calls.append([&"is_rewarded_ad_ready", [placement]])
	return true


func show_rewarded_ad(placement: StringName, on_done: Callable) -> void:
	calls.append([&"show_rewarded_ad", [placement]])
	on_done.call(succeed)


func purchase(sku: StringName, on_done: Callable) -> void:
	calls.append([&"purchase", [sku]])
	if succeed:
		owned[sku] = true
	on_done.call(succeed)


func owns(sku: StringName) -> bool:
	return owned.get(sku, false)


func unlock_achievement(id: StringName) -> void:
	calls.append([&"unlock_achievement", [id]])
	achievements[id] = true


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	calls.append([&"log_event", [event_name, params]])

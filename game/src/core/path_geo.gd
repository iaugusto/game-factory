class_name PathGeo
extends RefCounted
## A PathDef's geometry, precomputed: distance along the centre line ("d", from the portal) to
## position, direction and back. Pure maths; CombatSim moves enemies and crates by d.

var points: PackedVector2Array
## Distance from the start to each point.
var cumulative: PackedFloat32Array = PackedFloat32Array()
## Per segment: its unit normal (right of the direction of travel).
var normals: PackedVector2Array = PackedVector2Array()
var length: float = 0.0


func _init(pts: PackedVector2Array) -> void:
	points = pts
	cumulative.resize(pts.size())
	var total: float = 0.0
	for i: int in pts.size():
		if i > 0:
			total += pts[i - 1].distance_to(pts[i])
		cumulative[i] = total
	length = total
	for i: int in maxi(0, pts.size() - 1):
		var t: Vector2 = (pts[i + 1] - pts[i]).normalized()
		normals.append(Vector2(-t.y, t.x))


## The segment holding `d`, searching forward from `hint` (a walker's last segment: d only
## grows, so this is O(1) amortised, unlike _segment's binary search).
func segment_from(hint: int, d: float) -> int:
	var i: int = clampi(hint, 0, maxi(0, points.size() - 2))
	if d < cumulative[i]:
		i = _segment(d)  # moved back (only tests and resets do this)
	while i < points.size() - 2 and cumulative[i + 1] <= d:
		i += 1
	return i


## The point `offset` to the side of the centre line at `d`, on segment `seg` (from
## segment_from).
func point_on(seg: int, d: float, offset: float) -> Vector2:
	var s: float = cumulative[seg + 1] - cumulative[seg]
	var k: float = clampf((d - cumulative[seg]) / s, 0.0, 1.0) if s > 0.0 else 0.0
	return points[seg].lerp(points[seg + 1], k) + normals[seg] * offset


## The segment index holding distance `d` (clamped to the path).
func _segment(d: float) -> int:
	var lo: int = 0
	var hi: int = points.size() - 2
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if cumulative[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return maxi(0, lo)


func point_at(d: float) -> Vector2:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector2.ZERO
	var dd: float = clampf(d, 0.0, length)
	var i: int = _segment(dd)
	var seg: float = cumulative[i + 1] - cumulative[i]
	var k: float = (dd - cumulative[i]) / seg if seg > 0.0 else 0.0
	return points[i].lerp(points[i + 1], k)


## Unit direction of travel at `d`.
func direction_at(d: float) -> Vector2:
	if points.size() < 2:
		return Vector2.DOWN
	var i: int = _segment(clampf(d, 0.0, length))
	return (points[i + 1] - points[i]).normalized()


## Unit normal at `d` (to the right of the direction of travel, seen from above).
func normal_at(d: float) -> Vector2:
	var t: Vector2 = direction_at(d)
	return Vector2(-t.y, t.x)


## The distance along the path where the centre line reaches height `y` (clamped). Valid
## because y strictly increases along a path.
func d_at_y(y: float) -> float:
	if points.size() < 2 or y <= points[0].y:
		return 0.0
	if y >= points[points.size() - 1].y:
		return length
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if y <= b.y:
			var k: float = (y - a.y) / (b.y - a.y) if b.y > a.y else 0.0
			return cumulative[i] + k * (cumulative[i + 1] - cumulative[i])
	return length


## The distance along the path of the centre-line point nearest `p`, and that distance to
## `p` (as Vector2(d, distance)).
func nearest(p: Vector2) -> Vector2:
	var best := Vector2(0.0, INF)
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var ab: Vector2 = points[i + 1] - a
		var len2: float = ab.length_squared()
		var k: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var q: Vector2 = a + ab * k
		var dist: float = q.distance_to(p)
		if dist < best.y:
			best = Vector2(cumulative[i] + k * sqrt(len2), dist)
	return best

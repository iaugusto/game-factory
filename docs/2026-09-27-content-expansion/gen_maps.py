"""Stage 4 maps (Mire Crossing, Ashfall, The Hive) -> game/data/maps/*.tres, with a check of the
content test's geometry rules first."""
import math, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2] / "game" / "data"

MAPS = {
 "mire": dict(name="Mire Crossing", biome="swamp",
   paths=[  # (points, spread, opens)
     ([(70,-10),(70,180),(140,400),(140,860)], 20, 1),
     ([(220,-10),(220,180),(140,400),(140,860)], 20, 3),
     ([(320,-10),(320,180),(400,400),(400,860)], 20, 6),
     ([(470,-10),(470,180),(400,400),(400,860)], 20, 1)],
   plots=[((145,90),1),((395,90),1),((30,300),1),((510,300),1),((270,330),1),((270,480),1),
          ((30,540),1),((510,540),1),((270,640),1),((30,720),4),((510,720),7),((270,780),1),
          ((140,876),1),((270,876),1),((400,876),1)],
   slots=[(140,770),(400,770)],
   zones=[(0,(140,560),52,0.55),(0,(400,600),52,0.55),(0,(70,110),38,0.6),(0,(470,110),38,0.6)]),
 "ashfall": dict(name="Ashfall", biome="ash",
   paths=[
     ([(110,-10),(110,260),(200,480),(200,860)], 30, 1),
     ([(430,-10),(430,260),(340,480),(340,860)], 30, 1),
     ([(480,440),(480,690),(340,800),(340,860)], 30, 4),
     ([(60,380),(60,680),(200,790),(200,860)], 30, 7)],
   plots=[((30,150),1),((190,150),1),((350,150),1),((510,150),1),((270,250),1),((270,400),1),
          ((130,500),1),((130,620),7),((410,500),1),((410,620),4),((270,600),1),((270,720),1),
          ((200,876),1),((270,876),1),((340,876),1)],
   slots=[(200,815),(340,815)],
   zones=[(1,(270,250),34,0.25),(1,(270,600),34,0.25)]),
 "hive": dict(name="The Hive", biome="infested",
   paths=[
     ([(270,-10),(270,200),(120,400),(120,560),(270,720),(270,860)], 30, 1),
     ([(270,-10),(270,200),(420,400),(420,560),(270,720),(270,860)], 30, 1),
     ([(-10,180),(50,300),(50,700),(120,860)], 30, 3),
     ([(550,180),(490,300),(490,700),(420,860)], 30, 6)],
   plots=[((150,120),1),((390,120),1),((120,250),1),((420,250),1),((270,330),1),((190,470),1),
          ((270,470),1),((350,470),1),((270,600),1),((190,780),3),((350,780),6),
          ((120,876),1),((270,876),1),((420,876),1)],
   slots=[(270,780),(98,810),(442,810)],
   zones=[(1,(270,470),40,0.3),(0,(120,480),45,0.6),(0,(420,480),45,0.6)]),
}

def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx-ax, by-ay; L = dx*dx+dy*dy
    t = max(0, min(1, ((px-ax)*dx+(py-ay)*dy)/L)) if L else 0
    return math.hypot(px-(ax+t*dx), py-(ay+t*dy))

def path_dist(p, pts):
    return min(seg_dist(p, pts[i], pts[i+1]) for i in range(len(pts)-1))

def check(mid, m):
    ok = True
    for pts, sp, op in m["paths"]:
        assert all(pts[k][1] > pts[k-1][1] for k in range(1, len(pts))), (mid, pts)
        assert pts[-1][1] == 860
    for (p, _) in m["plots"]:
        if p[1] > 860: continue
        for pts, sp, _ in m["paths"]:
            need = sp + 12 + 22  # max(jitter + radius) = spread + 12, + PLOT_RADIUS
            d = path_dist(p, pts)
            if d < need: print(f"  {mid}: plot {p} {d:.0f} < {need} from {pts[0]}"); ok = False
    for pts, _, _ in m["paths"]:
        end = pts[-1]
        if min(math.dist(end, p) for p, _ in m["plots"] if p[1] > 860) >= 60: print("no wall spot", mid, end); ok = False
    for s in m["slots"]:
        if min(path_dist(s, pts) for pts, _, _ in m["paths"]) > 40 or not 710 <= s[1] <= 820: print("slot", mid, s); ok = False
    n = sum(1 for i,(a,_) in enumerate(m["plots"]) for (b,_) in m["plots"][i+1:] if math.dist(a,b) <= 200)
    print(f"{mid}: {len(m['plots'])} plots, {n} linkable pairs, ok={ok}")
    return ok

def v2(pts): return ", ".join(f"{x:g}, {y:g}" for x, y in pts)

def write(mid, m, prefix):
    L = ['[gd_resource type="Resource" script_class="MapDef" format=3]', "",
         '[ext_resource type="Script" path="res://src/defs/map_def.gd" id="1_s"]',
         '[ext_resource type="Script" path="res://src/defs/path_def.gd" id="path_s"]',
         '[ext_resource type="Script" path="res://src/defs/zone_def.gd" id="zone_s"]',
         '[ext_resource type="Script" path="res://src/defs/wave_def.gd" id="t_w"]']
    for i in range(1, 11):
        L.append(f'[ext_resource type="Resource" path="res://data/waves/{prefix}_{i:02d}.tres" id="w{i}"]')
    for i, (pts, sp, op) in enumerate(m["paths"]):
        L += ["", f'[sub_resource type="Resource" id="path_{i}"]', 'script = ExtResource("path_s")',
              f"points = PackedVector2Array({v2(pts)})", f"spread = {sp:.1f}", f"opens_at_wave = {op}"]
    for i, (k, c, r, v) in enumerate(m["zones"]):
        L += ["", f'[sub_resource type="Resource" id="zone_{i}"]', 'script = ExtResource("zone_s")',
              f"kind = {k}", f"center = Vector2({c[0]}, {c[1]})", f"radius = {r:.1f}", f"value = {v}"]
    L += ["", "[resource]", 'script = ExtResource("1_s")', f'id = &"{mid}"', f'biome = &"{m["biome"]}"',
          f'display_name = "{m["name"]}"',
          "paths = Array[ExtResource(\"path_s\")]([" + ", ".join(f'SubResource("path_{i}")' for i in range(len(m["paths"]))) + "])",
          f"plots = PackedVector2Array({v2([p for p, _ in m['plots']])})",
          "plot_unlock_waves = PackedInt32Array(" + ", ".join(str(u) for _, u in m["plots"]) + ")",
          f"barricade_slots = PackedVector2Array({v2(m['slots'])})",
          "zones = Array[ExtResource(\"zone_s\")]([" + ", ".join(f'SubResource("zone_{i}")' for i in range(len(m["zones"]))) + "])",
          "waves = Array[ExtResource(\"t_w\")]([" + ", ".join(f'ExtResource("w{i}")' for i in range(1, 11)) + "])", ""]
    (ROOT / "maps" / f"{mid}.tres").write_text("\n".join(L))

if __name__ == "__main__":
    import sys
    good = all(check(k, m) for k, m in MAPS.items())
    if good and "--write" in sys.argv:
        for k, m in MAPS.items():
            write(k, m, k)
        print("written")

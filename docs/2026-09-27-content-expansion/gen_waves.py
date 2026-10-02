# Authoring aid for E8 Stage 4 (kept with the work item as the record of how sectors 4-6 were
# built). The .tres files it wrote are the source of truth; edit them, or re-run this with the
# knobs logged in implementation.md.
"""Stage 4 waves: sectors 4-6 from Switchback's waves (the template) + each sector's new
enemies. Checks the content test's wave rules, then writes game/data/waves/<map>_NN.tres."""
import re, sys, pathlib, math
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from waves_summary import parse, root
from gen_maps import MAPS

THREAT_OVERRIDE = {}  # enemy id -> threat, for trying recalibrations
THREAT = {}
for f in (root / "enemies").glob("*.tres"):
    s = f.read_text()
    THREAT[f.stem] = float(re.search(r"^threat = ([\d.]+)", s, re.M).group(1))


TEMPLATE = [parse(root / "waves" / f"switchback_{i:02d}.tres") for i in range(1, 11)]
SB_THREAT = [sum(c * THREAT[e] for e, c, *_ in sp) * hp for sp, _, hp, _ in TEMPLATE]

# Per sector: template count and hp multipliers, and the added groups per wave (1-based):
# (enemy, count, start, interval, path or -1).
SECTORS = {
 "mire": dict(count=0.7, hp=1.0, addk=0.8, speed=0.0, boss="broodmother", add={
   2: [("wasp", 2, 8, 2, -1)],
   3: [("wasp", 6, 6, 0.8, -1)],
   4: [("wasp", 8, 5, 0.7, -1), ("warden", 1, 9, 1, 0)],
   5: [("wasp", 10, 4, 0.6, -1), ("warden", 2, 8, 6, -1)],
   6: [("wasp", 12, 6, 0.5, -1), ("warden", 2, 5, 5, -1)],
   7: [("wasp", 14, 5, 0.5, -1), ("warden", 3, 6, 5, -1)],
   8: [("wasp", 20, 8, 0.4, -1), ("warden", 4, 4, 4, -1)],
   9: [("wasp", 16, 6, 0.4, -1), ("warden", 4, 5, 5, -1)],
   10: [("wasp", 16, 6, 0.4, -1), ("warden", 3, 5, 6, -1)]}),
 "ashfall": dict(count=0.7, hp=1.0, addk=0.8, speed=0.02, boss="titan", add={
   2: [("burrower", 2, 8, 3, -1)],
   3: [("burrower", 5, 6, 1.5, -1), ("wasp", 2, 12, 2, -1)],
   4: [("burrower", 6, 5, 1.2, -1), ("wasp", 6, 8, 0.8, -1), ("bombardier", 2, 10, 4, 1)],
   5: [("burrower", 8, 4, 1.0, -1), ("wasp", 8, 6, 0.6, -1), ("bombardier", 3, 8, 4, -1),
       ("warden", 1, 9, 1, 0)],
   6: [("burrower", 10, 4, 0.9, -1), ("wasp", 10, 6, 0.5, -1), ("bombardier", 3, 6, 4, -1),
       ("warden", 2, 7, 5, -1)],
   7: [("burrower", 12, 3, 0.8, -1), ("wasp", 12, 5, 0.5, -1), ("bombardier", 4, 6, 4, -1),
       ("warden", 2, 6, 5, -1)],
   8: [("burrower", 16, 3, 0.7, -1), ("wasp", 16, 8, 0.4, -1), ("bombardier", 5, 5, 4, -1),
       ("warden", 3, 4, 5, -1)],
   9: [("burrower", 14, 3, 0.7, -1), ("wasp", 14, 6, 0.4, -1), ("bombardier", 5, 5, 4, -1),
       ("warden", 3, 5, 5, -1)],
   10: [("burrower", 12, 3, 0.8, -1), ("wasp", 12, 6, 0.4, -1), ("bombardier", 4, 6, 5, -1),
        ("warden", 2, 5, 6, -1)]}),
 "hive": dict(count=0.7, hp=1.0, addk=0.8, speed=0.03, boss="overmind", add={
   2: [("wasp", 2, 8, 2, -1), ("burrower", 2, 12, 3, -1)],
   3: [("wasp", 6, 6, 0.8, -1), ("burrower", 5, 8, 1.5, -1)],
   4: [("wasp", 8, 5, 0.7, -1), ("burrower", 6, 6, 1.2, -1), ("warden", 2, 9, 4, 0),
       ("bombardier", 2, 12, 4, 1)],
   5: [("wasp", 10, 4, 0.6, -1), ("burrower", 8, 4, 1.0, -1), ("warden", 2, 8, 5, -1),
       ("bombardier", 3, 8, 4, -1)],
   6: [("wasp", 12, 6, 0.5, -1), ("burrower", 10, 4, 0.9, -1), ("warden", 3, 5, 5, -1),
       ("bombardier", 3, 6, 4, -1)],
   7: [("wasp", 14, 5, 0.5, -1), ("burrower", 12, 3, 0.8, -1), ("warden", 3, 6, 5, -1),
       ("bombardier", 4, 6, 4, -1)],
   8: [("wasp", 18, 8, 0.4, -1), ("burrower", 16, 3, 0.7, -1), ("warden", 4, 4, 4, -1),
       ("bombardier", 5, 5, 4, -1)],
   9: [("wasp", 16, 6, 0.4, -1), ("burrower", 14, 3, 0.7, -1), ("warden", 4, 5, 5, -1),
       ("bombardier", 5, 5, 4, -1)],
   10: [("wasp", 16, 6, 0.4, -1), ("burrower", 12, 3, 0.8, -1), ("warden", 3, 5, 6, -1),
        ("bombardier", 4, 6, 5, -1)]}),
}

def open_paths(mid, wave):
    return [i for i, (_, _, op) in enumerate(MAPS[mid]["paths"]) if op <= wave]

def remap(mid, wave, sb_path, k):
    """A template's fixed path -> an open path of this map. The path that opens this very wave
    gets the group that used Switchback's newest path, so a breach carries traffic."""
    if sb_path < 0: return -1
    op = open_paths(mid, wave)
    fresh = [i for i in op if MAPS[mid]["paths"][i][2] == wave]
    if fresh and sb_path == max(p for (_, _, _, _, p, _) in TEMPLATE[wave - 1][0]):
        return fresh[0]
    return op[(sb_path + k) % len(op)]

def build(mid):
    sec = SECTORS[mid]
    waves = []
    for w in range(1, 11):
        sp, crates, hp, spd = TEMPLATE[w - 1]
        groups = []
        for k, (e, c, st, iv, p, el) in enumerate(sp):
            if e == "boss": e = sec["boss"]; c = 1
            else:
                # Early waves keep the template's full count (they are easy anyway); from
                # wave 4 on the template thins to the sector's `count`, making room for its
                # new enemies.
                k_count = 1.0 + (sec["count"] - 1.0) * min(1.0, max(0.0, (w - 1) / 3.0))
                c = max(1, round(c * k_count))
            groups.append((e, c, st, iv, remap(mid, w, p, k), el))
        for (e, c, st, iv, p) in sec["add"].get(w, []):
            op = open_paths(mid, w)
            c = min(c, 2) if c <= 2 else max(2, round(c * sec["addk"]))
            groups.append((e, c, st, iv, p if p < 0 else op[p % len(op)], ""))
        waves.append(dict(spawns=groups, crates=crates, hp=round(hp * sec["hp"], 4),
                          speed=round(spd + sec["speed"], 3)))
    return waves

def threat(wv): return sum(c * THREAT[e] for e, c, *_ in wv["spawns"]) * wv["hp"]

def check(all_w):
    ok = True
    prev_sector = SB_THREAT
    for mid in SECTORS:
        ws = all_w[mid]; seen = set(); prev = 0
        for i, wv in enumerate(ws):
            t = threat(wv)
            if t <= prev: print(f"{mid} w{i+1} threat {t:.0f} <= {prev:.0f}"); ok = False
            if i == 9 and t <= prev_sector[i]: print(f"{mid} boss wave {t:.0f} not > previous {prev_sector[i]:.0f}"); ok = False
            prev = t
            counts = {}
            for e, c, *_ in wv["spawns"]: counts[e] = counts.get(e, 0) + c
            for e, c in counts.items():
                if e in seen: continue
                seen.add(e)
                if i > 0 and e != "runner" and c > 2: print(f"{mid} w{i+1}: {c} new {e}"); ok = False
                if e in ("ravager", "splitter", "mender") and i < 3: print(f"{mid}: {e} early"); ok = False
            for e, c, st, iv, p, el in wv["spawns"]:
                if p >= 0 and MAPS[mid]["paths"][p][2] > i + 1: print(f"{mid} w{i+1} path {p} closed"); ok = False
        tot = sum(threat(w) for w in ws)
        if tot <= sum(prev_sector): print(f"{mid} total {tot:.0f} not > previous {sum(prev_sector):.0f}"); ok = False
        print(mid, " ".join(f"{threat(w):.0f}" for w in ws), "| total", round(tot))
        prev_sector = [threat(w) for w in ws]
    print("switchback", " ".join(f"{t:.0f}" for t in SB_THREAT))
    return ok

CRATE_IDS = {"supply", "cache", "overdrive"}

def write(mid, i, wv):
    ext = {}
    def ref(kind, name):
        key = f"{kind[0]}_{name}"
        ext[key] = f'[ext_resource type="Resource" path="res://data/{kind}/{name}.tres" id="{key}"]'
        return key
    subs = []
    for k, (e, c, st, iv, p, el) in enumerate(wv["spawns"]):
        L = [f'[sub_resource type="Resource" id="s{k}"]', 'script = ExtResource("se")',
             f'enemy = ExtResource("{ref("enemies", e)}")', f"count = {c}", f"start = {float(st)}",
             f"interval = {float(iv)}", f"path = {p}"]
        if el: L.append(f'elite = ExtResource("{ref("elites", el)}")')
        subs.append("\n".join(L))
    for k, (cr, t) in enumerate(wv["crates"]):
        subs.append("\n".join([f'[sub_resource type="Resource" id="c{k}"]', 'script = ExtResource("cs")',
                               f'crate = ExtResource("{ref("crates", cr)}")', f"time = {t}", "path = -1"]))
    head = ['[gd_resource type="Resource" script_class="WaveDef" format=3]', "",
            '[ext_resource type="Script" path="res://src/defs/wave_def.gd" id="w"]',
            '[ext_resource type="Script" path="res://src/defs/spawn_entry.gd" id="se"]',
            '[ext_resource type="Script" path="res://src/defs/crate_spawn.gd" id="cs"]'] + list(ext.values())
    tail = ["[resource]", 'script = ExtResource("w")',
            "spawns = Array[ExtResource(\"se\")]([" + ", ".join(f'SubResource("s{k}")' for k in range(len(wv["spawns"]))) + "])",
            "crates = Array[ExtResource(\"cs\")]([" + ", ".join(f'SubResource("c{k}")' for k in range(len(wv["crates"]))) + "])",
            f"hp_scale = {wv['hp']}", f"speed_scale = {wv['speed']}", ""]
    (root / "waves" / f"{mid}_{i:02d}.tres").write_text("\n".join(head) + "\n\n" + "\n\n".join(subs) + "\n\n" + "\n".join(tail))

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        if "=" in arg and "." in arg.split("=")[0] and not arg.startswith("threat."):
            k, v = arg.split("="); m, key = k.split(".")
            SECTORS[m][key] = float(v)
    for arg in sys.argv[1:]:
        if arg.startswith("threat."):
            k, v = arg.split("="); THREAT[k.split(".")[1]] = float(v)
    all_w = {m: build(m) for m in SECTORS}
    good = check(all_w)
    if (good or "--force" in sys.argv) and "--write" in sys.argv:
        for m, ws in all_w.items():
            for i, wv in enumerate(ws, 1):
                write(m, i, wv)
        print("written")

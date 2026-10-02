import re,sys,pathlib
root = pathlib.Path(__file__).resolve().parents[2] / "game" / "data"
def parse(f):
    s=f.read_text()
    ext=dict(re.findall(r'path="res://data/\w+/(\w+)\.tres" id="(\w+)"',s))
    ext={v:k for k,v in ext.items()}
    subs=re.split(r'\n\[sub_resource[^\]]*\]\n',s)[1:]
    spawns=[];crates=[]
    for b in subs:
        b=b.split("\n[resource]")[0]
        d=dict(re.findall(r'^(\w+) = (.*)$',b,re.M))
        if "enemy" in d:
            eid=ext[re.search(r'"(\w+)"',d["enemy"]).group(1)]
            el=ext[re.search(r'"(\w+)"',d["elite"]).group(1)] if "elite" in d else ""
            spawns.append((eid,int(d["count"]),float(d.get("start",0)),float(d.get("interval",1)),int(d.get("path",-1)),el))
        elif "crate" in d:
            crates.append((ext[re.search(r'"(\w+)"',d["crate"]).group(1)],float(d["time"])))
    hp=re.search(r'hp_scale = ([\d.]+)',s); sp=re.search(r'speed_scale = ([\d.]+)',s)
    return spawns,crates,float(hp.group(1)) if hp else 1,float(sp.group(1)) if sp else 1
if __name__=="__main__":
    for m,pre in (("outpost","wave_"),("canyon","canyon_"),("switchback","switchback_")):
        print("==",m)
        for i in range(1,11):
            sp,cr,hp,spd=parse(root/"waves"/f"{pre}{i:02d}.tres")
            print(f"{i:2d} hp{hp:6.2f} sp{spd:.2f} crates {len(cr)} ({','.join(c[0][:3] for c in cr)}) | "+", ".join(f"{e}x{c}@{s:g}/{iv:g}p{p}{'*'+el if el else ''}" for e,c,s,iv,p,el in sp))

"""The art direction's palette: "frontier outpost vs alien swarm" at dusk.

Warm, aggressive hues belong to the swarm; cool steel with teal accents to the defenders;
amber to loot. Light comes from the upper left, so highlights sit up-left and shadows fall
down-right. Each enemy archetype owns one hue family so it reads at a glance:
skitter = acid green (fast, fragile), drone = ember orange (the line), carapace = violet
(slow, armoured), hive queen = magenta.
"""

INK = "#120c10"          # outline for everything organic
STEEL_INK = "#0c1116"    # outline for machines

# Ground and field
DIRT_LIGHT = "#6b5541"
DIRT = "#4d3c2e"
DIRT_DARK = "#33281f"
VERGE = "#221f1d"
VERGE_LIGHT = "#2f2a26"
ROCK = "#4a4540"
ROCK_LIGHT = "#6c655c"
HAZE = "#2a1733"
HIVE_GLOW = "#b0306a"
CRYSTAL = "#3de0c8"
CRYSTAL_DEEP = "#157a74"

# Defenders
STEEL = "#56626e"
STEEL_LIGHT = "#8d9aa6"
STEEL_DARK = "#2c343c"
GUNMETAL = "#262b31"
OLIVE = "#5b6b3a"
OLIVE_LIGHT = "#86985a"
OLIVE_DARK = "#39432a"
SAND = "#a88f62"
SAND_LIGHT = "#cbb482"
SAND_DARK = "#7a6544"
SKIN = "#c89a78"
TEAL = "#3de0c8"
HAZARD = "#e8b030"
CRYO = "#8fe8ff"
CRYO_DEEP = "#2a86b8"
RAIL = "#b08cff"
RAIL_DEEP = "#5a3cc0"
FLAME = "#ffb347"

# Damage types (the counter chart), shared by the ui/dmg_* icons and each unit's accent, so a
# unit's colour says what it counters.
KINETIC = "#c9a24a"
EXPLOSIVE = "#e8742e"
PIERCING = "#b08cff"
CRYO_TYPE = "#8fe8ff"

# Swarm: (dark, mid, light, glow) per archetype
DRONE = ("#7a2a0e", "#e8742e", "#ffc070", "#ffe066")
SKITTER = ("#3a5212", "#9cc432", "#e2ff7a", "#ffffff")
CARAPACE = ("#2c1650", "#6c44b4", "#b595ff", "#e07bff")
QUEEN = ("#4a0c28", "#b52a64", "#ff7ab0", "#ffd0e8")
SPITTER = ("#0c3a34", "#2fae8e", "#8ef5c8", "#d4ff5a")
RAVAGER = ("#3a0610", "#b01e36", "#ff6a78", "#ffd24a")
SPLITTER = ("#4a3a08", "#c9b43a", "#fff09a", "#ff9a3a")
MENDER = ("#4a4238", "#c9bfa8", "#fff8e8", "#7dffb0")
# Content expansion, Stage 2: four new hues (amber-and-black, steel blue, earth, olive/bile).
WASP = ("#5a3a04", "#ffc428", "#fff0a0", "#ffffff")
WASP_STRIPE = "#1e1408"
WARDEN = ("#122a4a", "#4a86c8", "#a8d4ff", "#7fe0ff")
BURROWER = ("#3a2410", "#9a6a3a", "#d9aa70", "#ffb04a")
BOMBARDIER = ("#26300a", "#6a7a22", "#b8c860", "#c8ff3a")

# Loot
WOOD = "#9a6a3a"
WOOD_LIGHT = "#c9955a"
WOOD_DARK = "#5a3a1e"
AMMO = "#4f5a36"
GOLD = "#ffcf4a"
GOLD_DEEP = "#b8860b"
CORE = "#4ae0d0"

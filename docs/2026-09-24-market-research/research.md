# Research — market scan and concept selection

**Question:** which 2D game can a solo dev build well and monetize fast on Google Play, the App
Store and possibly Steam, among the genres the user enjoys: platformers (Mario, Celeste), horde
/ gate shooters (shoot items to upgrade firepower or the number of shooters), and Command &
Conquer-like RTS?

**Method:** three parallel research passes (one per genre family, the third also covering
business realities), a verification pass, and a base-defense pass (§4b). 71 web searches in total, against a budget of 80.
Figures marked *(est.)* are tracker estimates (AppMagic, Sensor Tower, Gamalytic, Boxleiter),
not reported numbers.

---

## 1. Baselines everyone faces

- **Steam:** ~20k releases in 2025. The median game grossed **~$249**, 66% earned under $1k, and
  ~8.5% reached $100k. Demos plus Next Fest are still the main wishlist engine. "Roguelite" is
  table stakes, so the pitch has to be "a roguelite where X".
  [game-developers.org](https://game-developers.org/2025-steam-game-revenue-distribution),
  [GameDiscoverCo](https://newsletter.gamediscover.co/p/who-won-february-2026s-steam-next)
- **Mobile without a publisher:** organic installs rarely exceed 200–500/day. The ratio of paid
  to organic installs rose from 2.07 to 3.33. Premium mobile is effectively dead for unknown
  devs. [cas.ai](https://cas.ai/blog/the-mobile-game-publishing-reality-why-most-indies-fail-and-what-actually-works/)
- **Hybrid-casual benchmarks:**
  - D7 retention: 15–22% (paid user acquisition pays back at ~18%).
  - Revenue per daily active user per day: $0.15–0.50.
  - Revenue mix: 40–80% in-app purchases, the rest rewarded ads.
  - Cost per install: iOS shooters ~$7.47, Android US $1.50–3.50.
  - [gamegrowthadvisor](https://gamegrowthadvisor.com/blog/2026-03-17-mobile-game-kpis-benchmarks-2026/),
    [megadigital](https://megadigital.ai/en/blog/cpi-mobile-game-guide/)
- **The pattern that works for indies:** prove the game as a premium release on Steam, then port
  to mobile.
  - Vampire Survivors: free on mobile, 3M+ downloads in weeks.
  - Balatro: 2M+ copies before its port.
  - Brotato: 10M+ copies across platforms.
  - Thronefall: free-to-try on iOS, in Google Play Pass on Android.
  - [gameworldobserver](https://gameworldobserver.com/2023/01/17/vampire-survivors-mobile-3-million-downloads-appmagic)
- **Store fees:**
  - Apple/Google: 15% under their small-business programs.
  - Steam: 30%, plus a $100 fee per game that is recouped at $1k gross.
  - US web-shop links: allowed on Google (fees ≤20% under the Epic settlement). On Apple, a
    court allowed a "reasonable" commission, amount not yet set.
  - EU Apple, from 2026-10-01: 15%/10% for small businesses.
  - [techcrunch](https://techcrunch.com/2026/08/18/apple-overhauls-its-eu-app-store-fees-loosens-rules-for-alternative-app-stores/)

## 2. Horde / gate shooters and survivor-likes

**The gate mechanic is proven demand, but mostly as bait.**
- **Last War:** ~$1.65B in 2025 *(est.)*. The gate-shooter minigame appears in more than 50% of
  its ad impressions and fills the first 4–5 minutes of play, but the real game is a 4X
  base-builder. Revenue fell from ~$130–150M/month in March 2026 to $56.7M in August 2026.
  [naavik](https://naavik.co/digest/how-last-war-is-winning-the-4x-game/),
  [insidepulse](https://insidepulse.com/2026/09/23/last-wars-monthly-revenue-has-more-than-halved-since-march-appmagic-estimates-show/)

**Genuine gate games are a volume business.**
- **Mob Control (Voodoo):** 302M downloads and $77.5M lifetime *(est.)*, about half from ads.
  [udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/mob-control)
- **Voodoo's pipeline:** ~1,500–2,000 prototypes a year for ~4 launches. The CEO says older
  titles lose up to 40% of revenue a year. A pure gate runner is saturated and only works with a
  publisher's user-acquisition budget.
  [nextbiggames](https://nextbiggames.com/2026/01/19/hybrid-casual-publisher-analysis-december-2025/)

**Survivor-likes are where solo devs win big on Steam.**
- Megabonk: solo dev, ~5.1M copies, ~$38.5M gross *(est.)*.
- Brotato: solo at launch, 10M+ copies.
- Vampire Survivors: 8M paid copies.
- Halls of Torment: ~$7M gross *(est.)*.
- Steam added a formal "Bullet Heaven" tag in May 2026, and reskins now launch weekly. Winners
  have one clearly new twist, are cheap ($3–10), and have a hook that works as a clip.
- [gamerevenuedata](https://gamerevenuedata.com/games/megabonk/),
  [gamedeveloper](https://www.gamedeveloper.com/business/indie-hit-megabonk-moves-over-a-million-copies-in-two-weeks)

**"The fake ad, made real" has proven attention but no premium winner.**
- **Real War: Not Fake** (Android, November 2025) went viral in the press:
  - ~960k downloads *(est.)*.
  - Initially rejected by the stores for resembling misleading ads.
  - Reviewers call it ad-heavy.
  - [80.lv](https://80.lv/articles/game-developer-turned-fake-mobile-game-ad-into-real-game),
    [notebookcheck](https://www.notebookcheck.net/Someone-actually-made-one-of-those-fake-ad-games-and-it-s-pretty-good.1188256.0.html)
- The verification pass found **no Steam hit built on the gate mechanic**. That is an open slot.

## 3. 2D platformers

**Pure platformers are among Steam's weakest genres for indies.**
- In 2025, only 3 of 1,658 2D platformers reached 1,000+ reviews (0.18%).
- The platformers among top sellers are hybrids (e.g. Rogue Legacy 2, Infernax).
- Platformers get the fewest YouTube views of any genre.
- They need more than the usual ~10k wishlists at launch.
- [howtomarketagame](https://howtomarketagame.com/2026/01/27/what-the-hell-happened-in-2025/)

**Breakouts sell spectacle for streamers:**
- Peak: ~10M copies.
- Chained Together: 85k concurrent players.
- A Difficult Game About Climbing: solo dev, ~$1.7M gross *(est.)*.
- Jump King: ~$2.8M *(est.)*.

**Mobile:**
- Super Mario Run converted only 3–5% of 90M downloads to its paid unlock.
- Virtual D-pads are the top complaint in mobile platformers. Only one-touch designs are native
  to phones (Geometry Dash: $21M by 2018, its longevity driven by user-made levels).
- [gamedeveloper](https://www.gamedeveloper.com/business/report-i-super-mario-run-i-racks-up-3m-sales-from-90m-downloads),
  [sensortower](https://sensortower.com/blog/geometry-dash-revenue)

## 4. RTS / Command & Conquer-likes

**Classic RTS is shrinking.**
- It has dropped 17 places in Steam genre rankings since 2021.
- Stormgate raised ~$40M and collapsed to ~200 daily players.
- Tempest Rising (C&C-like, AA budget) sold ~240–420k copies *(est.)*: solid, not a breakout.
- Many units pathing around each other and deterministic lockstep multiplayer are
  large engineering burdens for one person.
- [GameDiscoverCo](https://newsletter.gamediscover.co/p/how-have-the-genres-of-hit-pc-games),
  [gamedeveloper](https://www.gamedeveloper.com/business/frost-giant-ceo-tim-morten-says-layoffs-are-possible-after-stormgate-underperforms)

**The minimal cousins win.**
- **Thronefall:** 2 developers, 1M+ copies in its first year, on iOS and Google Play Pass.
- **Rogue Tower:** solo, ~$1.6–3M gross *(est.)*, from one mechanic (an ever-growing path).
- **Tower defense** is the most touch-native strategy genre (Kingdom Rush).
- [GameDiscoverCo](https://newsletter.gamediscover.co/p/deep-dive-how-thronefall-went-minimal)

## 4b. Base defense: fixed base, incoming waves, upgrades between them

_Added 2026-09-24 at the user's request; 10 more searches (71 of 80 in total)._

**The strongest small-team evidence in the whole study.**

- **The Tower – Idle Tower Defense** (Tech Tree Games, mobile F2P, 2021):
  - Started as a solo project. It is now 4 full-time staff plus 25 contractors.
  - $50M+ lifetime. Up to $80k/day three years after launch, ~$2M/month, plus a FastSpring web
    shop on top.
  - Still ~$1M/month and 70–86k downloads/month in 2026 *(est.)*; 7.1M downloads in total.
  - One tower in the centre, waves from every side, deep upgrade trees. "Zero art", with a UI
    like a spreadsheet: the upgrade design and the community carried it.
  - [gamigion](https://www.gamigion.com/ultimate-underdog-success-story-the-tower-by-tech-tree/),
    [sensortower](https://sensortower.com/blog/2024-q3-unified-top-5-idler%20games-revenue-us-602ae7fb241bc16eb874f8e1)
- **Dome Keeper** (Bippinbits, a two-person team, Steam, 2022):
  - Mine between waves, defend the dome during waves.
  - $1M in the first week; ~$10.7M gross / ~$3.2M net *(est.)*.
  - 1M players by September 2024. A mobile port opened pre-registration in September 2026.
  - [gameworldobserver](https://gameworldobserver.com/2022/10/17/dome-keeper-1-million-revenue-wishlists-success-raw-fury),
    [steam-revenue-calculator](https://steam-revenue-calculator.com/app/1637320/dome-keeper)
- **Ball x Pit** (Kenny Sun, Devolver, 2025):
  - Hordes, plus a base-building meta between runs.
  - 1M copies in about two months, 2M+ by 2026.
  - [vgchartz](https://www.vgchartz.com/article/468682/ball-x-pit-sales-top-2-million-units-free-update-out-now/)
- **Kingdom Two Crowns:**
  - Build by day, defend at night.
  - ~761k copies / ~$9.1M on Steam alone *(est.)*, plus iOS and Android.
- **They Are Billions:**
  - An RTS colony defending against zombie hordes.
  - ~2.3M copies / ~$44M *(est.)*.
  - The closest thing to C&C that still wins, but full RTS scope: many units, pathfinding.
  - [raijin](https://raijin.gg/app/644930/They_Are_Billions/sales-revenue)
- **Thronefall:** 1M+ copies (see §4). It is the same "build, then defend" loop.

**Caution:**

- **Grow Castle** (Raon Games) is an old mobile castle-defense title: still ~200k
  downloads/month, but only ~$40k/month *(est.)*. A defense game that is shallow or doesn't get
  updated decays into ad-only revenue.
- The genre is crowded: Steam's Tower Defense Fest (March 2026) had 1,500+ discounted items.
- **Money is in depth, not ads.** In hybrid-casual action/strategy games, revenue is 81.9%
  in-app purchases vs 18.1% ads (Sensor Tower, State of Gaming 2026). The upgrade tree is the
  business model.
  [gamegrowthadvisor](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/)

**Why it suits this project better than a moving gate runner:**

- **Controls:** the base doesn't move, so there are no movement controls. It is fully
  touch-native, and it can play idle.
- **Scope:** straight-line enemies, fixed build slots, no scrolling levels. It is the smallest
  engineering scope of every option.
- **Two storefronts:** it is the only concept here with proof both on Steam as premium (Dome
  Keeper, Thronefall, Ball x Pit) and on mobile as free-to-play (The Tower).
- **All three of the user's genres fit in one loop:** hordes (waves), the gate fantasy
  (shootable multipliers in the lanes), and C&C (placing turrets and units; base building as the
  long-term progression).

## 5. Engine

- **Godot 4.6:**
  - MIT licence, no royalties.
  - Now ships Google Play Billing, Play Games Services and StoreKit 2 integrations.
  - Shipped games: Brotato, Slay the Spire II.
  - Its scenes are text files, which diff cleanly in git and are easy for Claude to edit.
  - Best fit for a 2D solo dev targeting Steam and mobile.
- **Unity 6:**
  - Free up to $200k revenue; the runtime fee has been dropped.
  - Best ads/analytics SDK ecosystem.
  - Expected by hybrid-casual publishers.
- **Defold:** light, but a weak Steam story.
- [rocketbrush](https://rocketbrush.com/blog/godot-vs-unity)

## 6. Conclusions

| Concept | Market | Solo scope | Mobile fit | Verdict |
| --- | --- | --- | --- | --- |
| **Base defense + gate upgrades ("Hold the Gate")** | Proven on both storefronts: The Tower ($50M+, F2P mobile), Dome Keeper and Thronefall (premium Steam), Ball x Pit (2M+) | Smallest: fixed base, straight-line waves, build slots, content is data | Best (no movement; idle-capable) | **Recommended (updated 2026-09-24)** |
| Gate/horde shooter roguelite, "the fake ad, made real" | Proven demand (Last War ads, Mob Control, survivor-likes). No premium Steam winner yet. | Small: lane-based enemies, no pathfinding | Native (one-thumb drag) | Folded into the pick above as its in-run mechanic |
| Minimal strategy / TD roguelite (Thronefall, Rogue Tower) | Proven solo/duo hits, lower ceiling | Medium | Good | Runner-up; the pick above borrows its build slots |
| Full C&C-style RTS | Declining genre, AAA failures | Large (pathfinding, AI, multiplayer) | Poor | Avoid for a first game |
| Pure 2D platformer | 0.18% hit rate on Steam | Medium, content-heavy (hand-built levels) | Poor unless one-touch | Avoid, unless it is a streamer-bait hybrid |

## 7. Open questions (the user's call)

1. Concept: base defense with gate upgrades (recommended), or one of the others?
2. Business route: one core game, two storefronts.
   - **Steam:** premium, $5–7, a demo in Next Fest.
   - **Mobile:** F2P with in-app-purchase upgrades and rewarded ads, soft-launched on Android in
     a cheap market to measure D1/D7 before spending on ads.
   - Optionally, pitch the mobile build to a hybrid-casual publisher for a cost-per-install test.
     That may push the engine choice to Unity.
3. Engine: Godot 4.6 (recommended) unless the publisher route wins out.

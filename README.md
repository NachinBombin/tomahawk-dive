# tomahawk-dive

Garry's Mod addon — **Tomahawk Loitering-Mode Missile**.

Part of the **Bombin Support** family. The big one — fastest terminal velocity, largest warhead, full-lifetime smoke trail + afterburner effects from the moment it spawns.

## Visuals

- **Persistent white smoke plume** — active for the entire missile lifetime, never fades
- **Orange afterburner flame core** — 7 particles/tick, 1.5× larger than base
- **Fuchsia flame layer** — 5 particles/tick, swells during boost
- **Sparks** — 6 per tick, high velocity (300–700 HU/s)
- **Stabilizer thrusters** — 4-nozzle RCS, drift-compensated, scaled up
- **Dynamic light** — size 280–380, brightness 4 (vs 180–260 on base)

## Flight personality

| Property | Tomahawk | TB-2 | Shahed-136 | Lancet-3 | Molniya-1 |
|---|---|---|---|---|---|
| **Damage** | **1200** | 350 | 700 | 150 | 80 |
| **Blast radius** | **1200 HU** | 600 HU | 900 HU | 300 HU | 200 HU |
| **Dive speed** | **2200 HU/s** | 1800 | 1800 | 1400 | 1400 |
| **Track interval** | 0.1 s | 0.1 s | 0.1 s | 0.1 s | 0.5 s |
| **Aim error** | ±400 HU | ±400 HU | ±400 HU | ±400 HU | ±700 HU |
| **Blast effects** | **5 layers** | 3 | 4 | 2 | 1 |
| **Smoke** | **full lifetime** | none | none | none | none |

## Required files

```
models/GMissiles/bgm-109_tomahawk.mdl
sound/tomahawk/high.wav
```

## ConVars

| ConVar | Default | Description |
|---|---|---|
| `npc_bombintomahawk_enabled` | 1 | Enable NPC calls |
| `npc_bombintomahawk_chance` | 0.12 | Probability per check |
| `npc_bombintomahawk_interval` | 12 | Seconds between checks |
| `npc_bombintomahawk_cooldown` | 50 | Per-NPC cooldown |
| `npc_bombintomahawk_min_dist` | 400 | Min call distance |
| `npc_bombintomahawk_max_dist` | 3000 | Max call distance |
| `npc_bombintomahawk_delay` | 5 | Flare → arrival delay |
| `npc_bombintomahawk_lifetime` | 40 | Munition lifetime (s) |
| `npc_bombintomahawk_speed` | 250 | Orbit speed HU/s |
| `npc_bombintomahawk_radius` | 2500 | Orbit radius HU |
| `npc_bombintomahawk_height` | 2500 | Altitude HU |
| `npc_bombintomahawk_dive_damage` | **1200** | Explosion damage |
| `npc_bombintomahawk_dive_radius` | **1200** | Explosion radius HU |
| `npc_bombintomahawk_announce` | 0 | Debug prints |

## Menu

Spawnmenu → **Bombin Support** → **Tomahawk**

Or run `bombin_spawntomahawk` in console for a manual test spawn.

## Credits

NachinBombin

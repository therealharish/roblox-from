# Hollow Signal

An original cooperative survival-horror vertical slice for Roblox. The town, lore, creatures, and terminology are original and should remain independent of any television property.

## Run it

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/).
2. Open a new Baseplate in Roblox Studio and install the Rojo Studio plugin.
3. From this directory run `rojo serve`.
4. Connect the plugin to `localhost:34872`, sync, and press **Start Server** with 1–8 players.

The server generates the graybox town automatically. For quicker testing, reduce phase lengths in `src/shared/Config.lua`. DataStore calls gracefully fall back to session-only profiles when Studio API access is disabled.

Studio automatically runs the cycle at 10% duration, so the first warning begins after one minute and creatures enter town shortly afterward. Published servers retain the full cycle.

## Add the original soundtrack

1. Upload `outputs/hollow_signal_ambient.wav` through Roblox Creator Hub as an audio asset owned by the same account or group as the experience.
2. Copy its numeric asset ID.
3. In `src/shared/Config.lua`, set `AmbientMusicId` to `rbxassetid://YOUR_ID`.
4. Stop and restart the Studio play session after Rojo syncs.

## Controls

- Interact: Roblox proximity prompt controls
- Crafting: `C`, controller `Y`, or the touch button
- Rescue nearby downed player: `R`, controller `X`, or the touch button
- Use a flare against the creature in the crosshair: `F` (desktop graybox control)

## Implemented vertical slice

- Runtime-generated town, six houses, shelter, clinic, workshop, diner, forest ring, caches, and mystery hatch
- Day → warning → siege → dawn cycle
- Server-authoritative inventory, crafting, wards, condition, downing, rescue, loot, quest, and journal state
- Persistent profiles with autosave and shutdown save
- Four unkillable pathfinding creatures with patrol, pursuit, attack, ward avoidance, and flare stagger
- Shared objective tracking and a persistent personal clue
- Keyboard, gamepad, and touch HUD/actions
- Remote validation and basic rate limiting

## Production follow-ups

The graybox deliberately omits final art, animation, audio, commerce product IDs, and licensed assets. Before public beta, replace runtime primitives with an optimized Studio map, add animation/audio authored for this project, run multi-client playtests, enable Studio API access in a test universe, and validate current Roblox policy and age-rating requirements.

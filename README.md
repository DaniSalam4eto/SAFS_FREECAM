# Freecam Presets (FiveM, Lua)

Lightweight freecam with **per-player**, **per-vehicle** camera presets. Vehicles-only, and a lock mode that follows the aircraft/vehicle position **and rotation** (yaw/pitch/bank). 

## Features
- **Delete** to toggle freecam (vehicles only).
- **Alt + [0–9]** → save preset to slot.
- **Ctrl + [0–9]** → load **lock mode** from slot; press the same combo again to exit.
- **Autosave** on toggle-off, vehicle exit, and resource stop:
- **Per-player storage** (by `license:` → `steam:` → `discord:` → `src:`).
- **Per-vehicle name** storage (uses GTA display name/label, e.g. “Jet”).
- **Horizontal mouse look** (Q/E vertical; wheel = FOV).

## Install
1. Drop the folder into `resources/` (e.g. `resources/freecam_presets`).
2. In `server.cfg`:
   ```cfg
   ensure the_name_of_the_folder_you_made
   ```
3. (Optional) Tweak movement/FOV defaults in `config.lua`.

## Files
- `fxmanifest.lua`, `client.lua`, `server.lua`, `config.lua`, `presets.json`

## Notes
- Made for SAFS
- By Dani — free and open source.
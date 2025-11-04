# Scene Setup Required for Phase 12.3a

## Missing Spawn Points

The death respawn system (Phase 12.3a) requires `sp_default` spawn points in gameplay scenes.

### Action Required

Open the following scenes in Godot editor and add `sp_default` spawn points:

#### 1. `scenes/gameplay/exterior.tscn`
- Add a Node3D under `SP_SpawnPoints`
- Name it: `sp_default`
- Position: Near the starting area (e.g., `Vector3(0, 0, 0)`)

#### 2. `scenes/gameplay/interior_house.tscn`
- Add a Node3D under `SP_SpawnPoints`
- Name it: `sp_default`
- Position: Near the entrance (e.g., `Vector3(0, 0, 0)`)

### Why sp_default?

`sp_default` is the fallback spawn point used when:
- Player first loads into a scene (no previous door transition)
- Player dies and no `target_spawn_point` is set
- Any spawn failure scenario

### Current Spawn Points

**exterior.tscn**:
- `sp_exit_from_house` (door spawn)
- **Missing**: `sp_default`

**interior_house.tscn**:
- `sp_entrance_from_exterior` (door spawn)
- **Missing**: `sp_default`

### After Adding Spawn Points

Once added, run the death respawn tests:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/spawn_system -gprefix=test_death -gexit
```

Expected result: All 5 tests passing

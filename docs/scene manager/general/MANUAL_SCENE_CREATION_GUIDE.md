# Manual Scene Creation Guide for Area Transitions

## Why Manual Scene Creation?

We tried programmatic scene generation (`U_SceneBuilder`) but it was **overengineered**:
- 420 lines of scene builder code
- 60+ lines of dynamic injection in M_SceneManager
- Node name conflicts and regeneration cycles
- Hard to maintain

**Manual duplication is simpler:** Use Godot's built-in scene duplication and editing.

---

## Step-by-Step: Create Exterior Scene

### 1. Duplicate gameplay_base.tscn

1. In Godot FileSystem panel, find `scenes/gameplay/gameplay_base.tscn`
2. Right-click → **Duplicate**
3. Name it `exterior.tscn`
4. Open `exterior.tscn` in the scene editor

### 2. Change Floor Color (Green Grass)

1. In Scene tree, navigate to: `Main > SceneObjects > SO_Floor`
2. In Inspector, find **Material Override**
3. Click on the material → Edit
4. Change **Albedo Color** to green: `RGB(0.3, 0.6, 0.3)`
5. Save the scene (Ctrl/Cmd + S)

### 3. Add Door Trigger

1. In Scene tree, right-click `Main > Entities`
2. **Add Child Node** → Select `Node3D`
3. Name it `E_DoorTrigger`
4. Set Transform Position: `x=5, y=0, z=0`

5. Right-click `E_DoorTrigger` → **Add Child Node** → Select `Node`
6. Attach script: `res://scripts/ecs/components/c_scene_trigger_component.gd`
7. In Inspector, set:
   - `door_id`: "door_to_house"
   - `target_scene_id`: "interior_house"
   - `target_spawn_point`: "sp_entrance_from_exterior"
   - `trigger_mode`: AUTO
   - `cooldown_duration`: 1.0

8. **(Optional)** Add visual indicator:
   - Right-click `E_DoorTrigger` → Add Child Node → `CSGBox3D`
   - Name it `DoorVisual`
   - Set Size: `x=2, y=3, z=0.2`
   - Add new StandardMaterial3D:
     - Shading Mode: Unshaded
     - Albedo Color: Bright Green `RGB(0.2, 1.0, 0.2)`

### 4. Add Spawn Point Marker

1. Navigate to `Main > SP_SpawnPoints`
2. Right-click → **Add Child Node** → Select `Node3D`
3. Name it `sp_exit_from_house`
4. Set Position: `x=0, y=0, z=0` (or wherever you want players to spawn when exiting interior)

5. **(Optional)** Add visual marker:
  - Right-click `sp_exit_from_house` → Add Child Node → `CSGCylinder3D`
   - Set Radius: 0.5, Height: 0.1
   - Add material with cyan color `RGB(0.0, 1.0, 1.0, 0.5)` (semi-transparent)

### 5. Save Scene

- Save: Ctrl/Cmd + S
- **Done!** `exterior.tscn` is ready

---

## Step-by-Step: Create Interior Scene

### 1. Duplicate gameplay_base.tscn Again

1. Right-click `gameplay_base.tscn` → **Duplicate**
2. Name it `interior_house.tscn`
3. Open `interior_house.tscn`

### 2. Change Floor Color (Brown Wood)

1. Navigate to `SO_Floor` material
2. Change **Albedo Color** to brown: `RGB(0.6, 0.4, 0.2)`
3. Save

### 3. Add Door Trigger (Exit Door)

Same as exterior, but:
- `door_id`: "door_to_exterior"
- `target_scene_id`: "exterior"
- `target_spawn_point`: "sp_exit_from_house"
- Position: `x=5, y=0, z=0` (or wherever makes sense)

### 4. Add Spawn Point Marker

1. Add `Node3D` to `SP_SpawnPoints`
2. Name it `sp_entrance_from_exterior`
3. Position: `x=0, y=0, z=0` (where players spawn when entering from exterior)

### 5. Save Scene

- Save: Ctrl/Cmd + S
- **Done!** `interior_house.tscn` is ready

---

## Testing

1. (Optional for manual testing only) Temporarily set `main.tscn` M_SceneManager `initial_scene_id = &"exterior"`. For normal gameplay and automated tests, keep `initial_scene_id = &"main_menu"`.
2. Run the game
3. Walk to the green door (x=5)
4. Should transition to interior (brown floor)
5. Walk to interior's door
6. Should transition back to exterior at spawn point

---

## Scene Registry

Both scenes should already be registered in `u_scene_registry.gd`:

```gdscript
_register_scene(
    StringName("exterior"),
    "res://scenes/gameplay/exterior.tscn",
    SceneType.GAMEPLAY,
    "fade",
    6
)

_register_scene(
    StringName("interior_house"),
    "res://scenes/gameplay/interior_house.tscn",
    SceneType.GAMEPLAY,
    "fade",
    6
)
```

And door pairings:

```gdscript
_register_door_exit(
    StringName("exterior"),
    StringName("door_to_house"),
    StringName("interior_house"),
    StringName("sp_entrance_from_exterior"),
    "fade"
)

_register_door_exit(
    StringName("interior_house"),
    StringName("door_to_exterior"),
    StringName("exterior"),
    StringName("sp_exit_from_house"),
    "fade"
)
```

---

## Benefits of Manual Approach

✅ **Simple:** Standard Godot workflow
✅ **No conflicts:** Proper scene instancing
✅ **Easy to modify:** Just open and edit in editor
✅ **Visual:** Can see what you're building
✅ **Maintainable:** No complex generation code

**No more 500+ lines of scene builder code!**

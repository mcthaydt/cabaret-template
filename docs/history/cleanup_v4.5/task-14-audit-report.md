# Task 14: Component Attachment Audit Report

**Date**: 2026-01-24
**Status**: COMPLETE

## Summary

Audited 3 gameplay scenes for component scripts directly attached to non-Node/Node3D types.

**Total Violations Found**: 3 (all in gameplay_exterior.tscn)

---

## Violations by Scene

### gameplay_exterior.tscn: 3 violations

All violations involve `c_surface_type_component.gd` directly attached to `CSGBox3D` nodes.

#### Violation 1: SO_Floor_Grass
- **Line**: 117-124
- **Node Type**: CSGBox3D
- **Script**: c_surface_type_component.gd (ExtResource "54_surface_marker")
- **Export Value**: surface_type = 4
- **Location**: SceneObjects/SO_Floor_Grass

#### Violation 2: SO_Block2_Stone
- **Line**: 126-132
- **Node Type**: CSGBox3D
- **Script**: c_surface_type_component.gd (ExtResource "54_surface_marker")
- **Export Value**: surface_type = 1
- **Location**: SceneObjects/SO_Block2_Stone

#### Violation 3: SO_Block3_Stone
- **Line**: 134-140
- **Node Type**: CSGBox3D
- **Script**: c_surface_type_component.gd (ExtResource "54_surface_marker")
- **Export Value**: surface_type = 1
- **Location**: SceneObjects/SO_Block3_Stone

---

### gameplay_interior_house.tscn: 0 violations

No component scripts found in this scene.

---

### gameplay_base.tscn: 0 violations

No component scripts found in this scene.

---

## Fix Plan for Task 15

For each violation in gameplay_exterior.tscn:

1. Remove `script` property from CSGBox3D node
2. Remove `surface_type` export property
3. Add child Node named `C_SurfaceTypeComponent`
4. Attach `c_surface_type_component.gd` to the child Node
5. Set `surface_type` export value on the child Node

**Example fix pattern:**

**Before:**
```
[node name="SO_Floor_Grass" type="CSGBox3D" parent="SceneObjects"]
script = ExtResource("54_surface_marker")
surface_type = 4
```

**After:**
```
[node name="SO_Floor_Grass" type="CSGBox3D" parent="SceneObjects"]

[node name="C_SurfaceTypeComponent" type="Node" parent="SceneObjects/SO_Floor_Grass"]
script = ExtResource("54_surface_marker")
surface_type = 4
```

---

## Notes

- All violations are the same pattern (CSGBox3D + c_surface_type_component.gd)
- surface_type values: 4 = grass (floor), 1 = stone (blocks)
- No violations in interior_house or base scenes
- The component script itself is correct; only the attachment pattern needs fixing

---

## Next Steps

Proceed to Task 15 to fix these violations in gameplay_exterior.tscn.

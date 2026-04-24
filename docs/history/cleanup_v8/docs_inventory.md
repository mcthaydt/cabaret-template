# Docs Inventory — P3.1

Maps every section of `AGENTS.md` and `DEV_PITFALLS.md` to its proposed destination.
P3.3 migration executes one commit per destination file, using this table as the authoritative sequence.

**Notation**
- **Action**: `move` = full section relocated; `merge` = content folded into an existing file; `collapse` = shrinks to a one-line routing pointer in the AGENTS.md index; `split` = section distributes across multiple destinations (sub-rows); `drop` = content removed (outdated or fully duplicated elsewhere).
- **Existing** = destination file already exists; **New** = file must be created in P3.3.

---

## 1. AGENTS.md — Section Inventory

Source: `AGENTS.md` (~1 460 lines, 19 top-level sections)

| # | Section | Lines | ~LOC | Action | Destination | Status |
|---|---------|-------|------|--------|-------------|--------|
| 1 | Start Here | 3–25 | 23 | split | Commit workflow parts → `docs/guides/COMMIT_WORKFLOW.md` (New); routing stub stays in AGENTS.md index | Complete in P3.3 Commit 27/28 |
| 2 | Repo Map (essentials) | 26–63 | 38 | move | `docs/guides/ARCHITECTURE.md` (New) | Complete in P3.3 Commit 26 |
| 3 | Scene Director / Objectives | 64–92 | 29 | merge | `docs/systems/scene_director/scene-director-overview.md` (Existing) | Complete in P3.3 Commit 18 |
| 4 | ServiceLocator Registration & Test Isolation | 93–100 | 8 | merge | `docs/guides/ARCHITECTURE.md` (New) | Complete in P3.3 Commit 26 |
| 5 | Communication Channel Taxonomy (F5) | 101–111 | 11 | collapse | One-line pointer → `docs/architecture/adr/0001-channel-taxonomy.md` (Existing) | Complete in P3.3 Commit 28 |
| 6 | ECS Guidelines — core components/systems/entities | 112–178 | 67 | move | `docs/systems/ecs/ecs_architecture.md` (Existing) | Complete in P3.3 Commit 13 |
| 6b | ECS Guidelines — game event system + QB rule engine v2 | 128–147 | 20 | move | `docs/systems/qb_rule_manager/qb-v2-overview.md` (Existing) | Complete in P3.3 Commit 14 |
| 6c | ECS Guidelines — AI behavior-tree loop pattern | 148–174 | 27 | merge | `docs/systems/ai_system/ai-system-overview.md` (Existing) | Complete in P3.3 Commit 15 |
| 6d | ECS Guidelines — VFX event requests / tuning / preview | 175–187 | 13 | merge | `docs/systems/vfx_manager/vfx-manager-overview.md` (Existing) | Complete in P3.3 Commit 16 |
| 6e | ECS Guidelines — vCam runtime contracts | 188–249 | 62 | merge | `docs/systems/vcam_manager/vcam-manager-overview.md` (Existing) | Complete in P3.3 Commit 17 |
| 6f | ECS Guidelines — testing with DI | 250–265 | 16 | merge | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 6g | ECS Guidelines — manager / entities | 266–279 | 14 | move | `docs/systems/ecs/ecs_architecture.md` (Existing) | Complete in P3.3 Commit 13 |
| 7 | Scene Organization — root/gameplay scene patterns | 280–304 | 25 | merge | `docs/guides/SCENE_ORGANIZATION_GUIDE.md` (Existing) | Complete in P3.3 Commit 25 |
| 7b | Scene Organization — UI Theme Pipeline | 305–320 | 16 | merge | `docs/systems/ui_manager/ui-manager-overview.md` (New) | Complete in P3.3 Commit 9 |
| 7c | Scene Organization — UI Motion Pipeline | 321–344 | 24 | merge | `docs/systems/ui_manager/ui-manager-overview.md` (New) | Complete in P3.3 Commit 9 |
| 7d | Scene Organization — Interactable Controllers | 345–362 | 18 | merge | `docs/guides/SCENE_ORGANIZATION_GUIDE.md` (Existing) | Complete in P3.3 Commit 25 |
| 7e | Scene Organization — Character Lighting | 363–403 | 41 | merge | `docs/systems/lighting_manager/lighting-manager-overview.md` (New) | Complete in P3.3 Commit 8 |
| 8 | Naming Conventions Quick Reference | 404–452 | 49 | merge | `docs/guides/STYLE_GUIDE.md` (Existing) | Complete in P3.3 Commit 24 |
| 9 | Conventions and Gotchas | 454–518 | 65 | merge | `docs/guides/ARCHITECTURE.md` (New) | Complete in P3.3 Commit 26 |
| 10 | Localization Manager Patterns | 519–557 | 39 | merge | `docs/systems/localization_manager/localization-manager-overview.md` (Existing) | Complete in P3.3 Commit 19 |
| 11 | Time Manager Patterns | 558–588 | 31 | merge | `docs/systems/time_manager/time-manager-overview.md` (Existing) | Complete in P3.3 Commit 20 |
| 12 | Scene Manager Patterns | 589–710 | 122 | merge | `docs/systems/scene_manager/scene-manager-overview.md` (New) | Complete in P3.3 Commit 11 |
| 13 | UI Manager Patterns | 711–838 | 128 | merge | `docs/systems/ui_manager/ui-manager-overview.md` (New) | Complete in P3.3 Commit 9 |
| 14 | Save Manager Patterns | 839–1 032 | 194 | merge | `docs/systems/save_manager/save-manager-overview.md` (Existing) | Complete in P3.3 Commit 21 |
| 15 | Audio Manager Patterns | 1 033–1 221 | 189 | merge | `docs/systems/audio_manager/AUDIO_MANAGER_GUIDE.md` (Existing) | Complete in P3.3 Commit 22 |
| 16 | Display Manager Patterns | 1 222–1 415 | 194 | merge | `docs/systems/display_manager/display-manager-overview.md` (Existing) | Complete in P3.3 Commit 23 |
| 17 | Behavior Tree Patterns | 1 416–1 432 | 17 | merge | `docs/systems/ai_system/ai-system-overview.md` (Existing) | Complete in P3.3 Commit 15 |
| 18 | Test Commands | 1 433–1 441 | 9 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 19 | Quick How-Tos | 1 442–1 460 | 19 | merge | `docs/guides/ARCHITECTURE.md` (New) | Complete in P3.3 Commit 26 |

**Post-migration AGENTS.md target**: routing index only — one-line pointers to each destination, mandatory workflow rules (Start Here), and the `docs/guides/DEV_PITFALLS.md` pointer replaced by per-domain links. Hard cap: 150 lines.

---

## 2. DEV_PITFALLS.md — Section Inventory

Source: `docs/guides/DEV_PITFALLS.md` (~1 703 lines, 40+ sections)

| # | Section | Lines | ~LOC | Action | Destination | Status |
|---|---------|-------|------|--------|-------------|--------|
| 1 | Godot Scene UIDs | 3–31 | 29 | move | `docs/guides/pitfalls/GODOT_ENGINE.md` (New) | — |
| 2 | Godot Physics Pitfalls | 32–36 | 5 | move | `docs/guides/pitfalls/GODOT_ENGINE.md` (New) | — |
| 3 | Godot Script Class Cache | 37–43 | 7 | move | `docs/guides/pitfalls/GODOT_ENGINE.md` (New) | — |
| 4 | Godot UI Pitfalls | 44–108 | 65 | move | `docs/guides/pitfalls/GODOT_ENGINE.md` (New) | — |
| 5 | Godot Audio Pitfalls | 109–126 | 18 | move | `docs/guides/pitfalls/GODOT_ENGINE.md` (New) | — |
| 6 | Room Fade System Pitfalls | 127–134 | 8 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 7 | GDScript Typing Pitfalls | 135–174 | 40 | move | `docs/guides/pitfalls/GDSCRIPT_4_6.md` (New) | — |
| 8 | Asset Import Pitfalls (Headless Tests) | 175–180 | 6 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 9 | Test Execution Pitfalls | 181–205 | 25 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 10 | Scene Director Pitfalls | 206–209 | 4 | merge | `docs/systems/scene_director/scene-director-overview.md` (Existing) | Complete in P3.3 Commit 18 |
| 11 | AI System Pitfalls (first) | 210–222 | 13 | merge | `docs/systems/ai_system/ai-system-overview.md` (Existing) | Complete in P3.3 Commit 15 |
| 12 | QB Rule Engine v2 Pitfalls | 223–230 | 8 | merge | `docs/systems/qb_rule_manager/qb-v2-overview.md` (Existing) | Complete in P3.3 Commit 14 |
| 13 | QB Camera Rule Pitfalls | 231–243 | 13 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 14 | vCam Scene Wiring Pitfalls | 244–250 | 7 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 15 | vCam Orbit Evaluator Pitfalls | 251–255 | 5 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 16 | vCam Orbit Feel Pitfalls | 256–296 | 41 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 17 | vCam Soft-Zone Pitfalls | 297–304 | 8 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 18 | vCam OTS Evaluator Pitfalls | 305–311 | 7 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 19 | vCam OTS Collision Pitfalls | 312–316 | 5 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 20 | vCam Fixed Evaluator Pitfalls | 317–323 | 7 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 21 | Character Lighting Pitfalls | 324–329 | 6 | merge | `docs/systems/lighting_manager/lighting-manager-overview.md` (New) | Complete in P3.3 Commit 8 |
| 22 | UI Navigation Pitfalls (Gamepad/Joystick) | 330–486 | 157 | move | `docs/systems/ui_manager/ui-pitfalls.md` (New) | Complete in P3.3 Commit 10 |
| 23 | State Store Pitfalls | 487–506 | 20 | move | `docs/guides/pitfalls/STATE.md` (New) | — |
| 24 | Save Manager Pitfalls | 507–563 | 57 | merge | `docs/systems/save_manager/save-manager-overview.md` (Existing) | Complete in P3.3 Commit 21 |
| 25 | VFX Gating Pitfalls | 564–572 | 9 | merge | `docs/systems/vfx_manager/vfx-manager-overview.md` (Existing) | Complete in P3.3 Commit 16 |
| 26 | Dependency Lookup Rule | 573–587 | 15 | merge | `docs/guides/ARCHITECTURE.md` (New) | Complete in P3.3 Commit 26 |
| 27 | Scene Transition Pitfalls | 588–604 | 17 | merge | `docs/systems/scene_manager/scene-manager-overview.md` (New) | Complete in P3.3 Commit 11 |
| 28 | GDScript Language Pitfalls | 605–676 | 72 | move | `docs/guides/pitfalls/GDSCRIPT_4_6.md` (New) | — |
| 29 | ECS System Pitfalls | 677–682 | 6 | move | `docs/guides/pitfalls/ECS.md` (New) | — |
| 30 | State Store Integration Pitfalls | 683–697 | 15 | move | `docs/guides/pitfalls/STATE.md` (New) | — |
| 31 | GUT Testing Pitfalls | 698–797 | 100 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 32 | Headless Test Pitfalls | 798–801 | 4 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 33 | Documentation and Planning Pitfalls | 802–816 | 15 | drop | Content fully covered by AGENTS.md "Start Here" workflow rules and CLAUDE.md | Complete in P3.3 Commit 29 |
| 34 | Scene Manager Pitfalls (Phase 2+) incl. Phase 10 sub-section | 817–1 036 | 220 | merge | `docs/systems/scene_manager/scene-manager-overview.md` (New) | Complete in P3.3 Commit 11 |
| 35 | Input System Pitfalls | 1 037–1 085 | 49 | merge | `docs/systems/input_manager/input-manager-overview.md` (New) | Complete in P3.3 Commit 12 |
| 36 | vCam Integration Pitfalls | 1 086–1 116 | 31 | move | `docs/systems/vcam_manager/vcam-pitfalls.md` (New) | Complete in P3.3 Commit 7 |
| 37 | UI Manager / Input Manager Boundary | 1 117–1 277 | 161 | move | `docs/systems/ui_manager/ui-pitfalls.md` (New) | Complete in P3.3 Commit 10 |
| 38 | UI Navigation Pitfalls (second instance) | 1 278–1 351 | 74 | move | `docs/systems/ui_manager/ui-pitfalls.md` (New) | Complete in P3.3 Commit 10 |
| 39 | Test Coverage Status | 1 352–1 403 | 52 | move | `docs/guides/pitfalls/TESTING.md` (New) | Complete in P3.3 Commit 6 |
| 40 | Mobile/Touchscreen Pitfalls | 1 404–1 452 | 49 | move | `docs/guides/pitfalls/MOBILE.md` (New) | — |
| 41 | Unified Settings Panel Pitfalls | 1 453–1 597 | 145 | move | `docs/systems/ui_manager/ui-pitfalls.md` (New) | Complete in P3.3 Commit 10 |
| 42 | Display Manager Pitfalls | 1 598–1 665 | 68 | merge | `docs/systems/display_manager/display-manager-overview.md` (Existing) | Complete in P3.3 Commit 23 |
| 43 | Style & Resource Hygiene | 1 666–1 671 | 6 | merge | `docs/guides/STYLE_GUIDE.md` (Existing) | Complete in P3.3 Commit 24 |
| 44 | AI System Pitfalls (second) | 1 672–1 703 | 32 | merge | `docs/systems/ai_system/ai-system-overview.md` (Existing) | Complete in P3.3 Commit 15 |

---

## 3. Target Files Summary

### New files to create in P3.3

| File | Content sources |
|------|----------------|
| `docs/guides/ARCHITECTURE.md` | AGENTS §2 Repo Map, §4 ServiceLocator, §9 Conventions & Gotchas, §19 Quick How-Tos; DEV_PITFALLS §26 Dependency Lookup Rule |
| `docs/guides/pitfalls/TESTING.md` | AGENTS §6f Testing with DI, §18 Test Commands; DEV_PITFALLS §8 Asset Import, §9 Test Execution, §31 GUT Testing, §32 Headless Tests, §39 Test Coverage Status |
| `docs/guides/COMMIT_WORKFLOW.md` | AGENTS §1 Start Here (workflow rules and update obligations) |
| `docs/guides/pitfalls/GDSCRIPT_4_6.md` | DEV_PITFALLS §7 GDScript Typing, §28 GDScript Language |
| `docs/guides/pitfalls/GODOT_ENGINE.md` | DEV_PITFALLS §1–5 (Godot Scene UIDs, Physics, Script Class Cache, UI, Audio) |
| `docs/guides/pitfalls/ECS.md` | DEV_PITFALLS §29 ECS System Pitfalls |
| `docs/guides/pitfalls/STATE.md` | DEV_PITFALLS §23 State Store Pitfalls, §30 State Store Integration Pitfalls |
| `docs/guides/pitfalls/MOBILE.md` | DEV_PITFALLS §40 Mobile/Touchscreen Pitfalls |
| `docs/systems/vcam_manager/vcam-pitfalls.md` | DEV_PITFALLS §6 Room Fade, §13–20 all vCam pitfall groups, §36 vCam Integration Pitfalls |
| `docs/systems/lighting_manager/lighting-manager-overview.md` | AGENTS §7e Character Lighting; DEV_PITFALLS §21 Character Lighting Pitfalls |
| `docs/systems/lighting_manager/lighting-pitfalls.md` | Consolidated into `lighting-manager-overview.md` above (small enough to keep in one file) |
| `docs/systems/ui_manager/ui-manager-overview.md` | AGENTS §7b UI Theme Pipeline, §7c UI Motion Pipeline, §13 UI Manager Patterns |
| `docs/systems/ui_manager/ui-pitfalls.md` | DEV_PITFALLS §22 UI Nav Pitfalls (Gamepad), §37 UI Manager / Input Manager Boundary, §38 UI Nav Pitfalls (second), §41 Unified Settings Panel Pitfalls |
| `docs/systems/scene_manager/scene-manager-overview.md` | AGENTS §12 Scene Manager Patterns; DEV_PITFALLS §27 Scene Transition Pitfalls, §34 Scene Manager Pitfalls |
| `docs/systems/input_manager/input-manager-overview.md` | DEV_PITFALLS §35 Input System Pitfalls |

### Existing files receiving additional content

| File | Content sources |
|------|----------------|
| `docs/guides/STYLE_GUIDE.md` | AGENTS §8 Naming Conventions; DEV_PITFALLS §43 Style & Resource Hygiene |
| `docs/guides/SCENE_ORGANIZATION_GUIDE.md` | AGENTS §7 Scene Organization (root/gameplay patterns), §7d Interactable Controllers |
| `docs/systems/ecs/ecs_architecture.md` | AGENTS §6 ECS core (components/systems/entities/manager) |
| `docs/systems/qb_rule_manager/qb-v2-overview.md` | AGENTS §6b QB rule engine v2 patterns; DEV_PITFALLS §12 QB Rule Engine v2 Pitfalls |
| `docs/systems/ai_system/ai-system-overview.md` | AGENTS §6c AI BT loop pattern, §17 BT Patterns; DEV_PITFALLS §11 AI Pitfalls (first), §44 AI Pitfalls (second) |
| `docs/systems/vfx_manager/vfx-manager-overview.md` | AGENTS §6d VFX patterns; DEV_PITFALLS §25 VFX Gating Pitfalls |
| `docs/systems/vcam_manager/vcam-manager-overview.md` | AGENTS §6e vCam runtime contracts |
| `docs/systems/localization_manager/localization-manager-overview.md` | AGENTS §10 Localization Manager Patterns |
| `docs/systems/time_manager/time-manager-overview.md` | AGENTS §11 Time Manager Patterns |
| `docs/systems/save_manager/save-manager-overview.md` | AGENTS §14 Save Manager Patterns; DEV_PITFALLS §24 Save Manager Pitfalls |
| `docs/systems/audio_manager/AUDIO_MANAGER_GUIDE.md` | AGENTS §15 Audio Manager Patterns |
| `docs/systems/display_manager/display-manager-overview.md` | AGENTS §16 Display Manager Patterns; DEV_PITFALLS §42 Display Manager Pitfalls |
| `docs/systems/scene_director/scene-director-overview.md` | AGENTS §3 Scene Director / Objectives; DEV_PITFALLS §10 Scene Director Pitfalls |

### Files to delete after migration completes

| File | Condition |
|------|-----------|
| `docs/guides/DEV_PITFALLS.md` | After all 44 sections are moved/merged/dropped (P3.3 final commit) |

AGENTS.md is **not deleted** — it shrinks to a ~100-line routing index.

---

## 4. P3.3 Commit Sequence

One commit per destination file. Suggested order (independent files first, then files that depend on other moves being complete):

1. `docs/guides/pitfalls/GODOT_ENGINE.md` (DEV_PITFALLS §1–5)
2. `docs/guides/pitfalls/GDSCRIPT_4_6.md` (DEV_PITFALLS §7, §28)
3. `docs/guides/pitfalls/ECS.md` (DEV_PITFALLS §29)
4. `docs/guides/pitfalls/STATE.md` (DEV_PITFALLS §23, §30)
5. `docs/guides/pitfalls/MOBILE.md` (DEV_PITFALLS §40)
6. `docs/guides/pitfalls/TESTING.md` (DEV_PITFALLS §8, §9, §31, §32, §39; AGENTS §6f, §18)
7. `docs/systems/vcam_manager/vcam-pitfalls.md` (DEV_PITFALLS §6, §13–20, §36)
8. `docs/systems/lighting_manager/lighting-manager-overview.md` (AGENTS §7e; DEV_PITFALLS §21)
9. `docs/systems/ui_manager/ui-manager-overview.md` (AGENTS §7b, §7c, §13)
10. `docs/systems/ui_manager/ui-pitfalls.md` (DEV_PITFALLS §22, §37, §38, §41)
11. `docs/systems/scene_manager/scene-manager-overview.md` (AGENTS §12; DEV_PITFALLS §27, §34)
12. `docs/systems/input_manager/input-manager-overview.md` (DEV_PITFALLS §35)
13. Merge into `docs/systems/ecs/ecs_architecture.md` (AGENTS §6, §6g)
14. Merge into `docs/systems/qb_rule_manager/qb-v2-overview.md` (AGENTS §6b; DEV_PITFALLS §12)
15. Merge into `docs/systems/ai_system/ai-system-overview.md` (AGENTS §6c, §17; DEV_PITFALLS §11, §44)
16. Merge into `docs/systems/vfx_manager/vfx-manager-overview.md` (AGENTS §6d; DEV_PITFALLS §25)
17. Merge into `docs/systems/vcam_manager/vcam-manager-overview.md` (AGENTS §6e)
18. Merge into `docs/systems/scene_director/scene-director-overview.md` (AGENTS §3; DEV_PITFALLS §10)
19. Merge into `docs/systems/localization_manager/localization-manager-overview.md` (AGENTS §10)
20. Merge into `docs/systems/time_manager/time-manager-overview.md` (AGENTS §11)
21. Merge into `docs/systems/save_manager/save-manager-overview.md` (AGENTS §14; DEV_PITFALLS §24)
22. Merge into `docs/systems/audio_manager/AUDIO_MANAGER_GUIDE.md` (AGENTS §15)
23. Merge into `docs/systems/display_manager/display-manager-overview.md` (AGENTS §16; DEV_PITFALLS §42)
24. Merge into `docs/guides/STYLE_GUIDE.md` (AGENTS §8; DEV_PITFALLS §43)
25. Merge into `docs/guides/SCENE_ORGANIZATION_GUIDE.md` (AGENTS §7, §7d)
26. `docs/guides/ARCHITECTURE.md` (AGENTS §2, §4, §9, §19; DEV_PITFALLS §26)
27. `docs/guides/COMMIT_WORKFLOW.md` (AGENTS §1 workflow rules)
28. Shrink `AGENTS.md` to routing index (collapse §5 to ADR pointer; remove all moved sections; hard cap 150 lines)
29. Delete `docs/guides/DEV_PITFALLS.md`

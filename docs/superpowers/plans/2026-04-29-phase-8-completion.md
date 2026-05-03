# Phase 8 UI Menu Builders — Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 10 failing integration tests and clean up remaining `_apply_theme_tokens()` / `_configure_focus_neighbors()` / `_configure_tooltips()` inline code in 14 partially-migrated UI scripts, achieving full test suite green and Phase 8 completion.

**Architecture:** Builder infrastructure (`U_SettingsTabBuilder`, `U_UIMenuBuilder`, `U_UISettingsCatalog`) is complete and tested. Three settings tabs (display, audio, localization) are fully migrated to builder-created nodes (0 @onready vars). Fourteen menu/overlay scripts use the builder's binding API (`bind_heading`, `bind_row`, `bind_field_control`, etc.) to wire existing `.tscn`-authored nodes. The 10 failing tests look for nodes by old @onready names that don't match builder-created node names.

**Tech Stack:** Godot 4.7 / GDScript / GUT test framework

---

## Task 1: Fix Display Integration Tests (3 failures)

**Files:**
- Modify: `tests/integration/display/test_display_settings.gd`

**Root cause:** The display settings tab was refactored to use builder-created nodes. The integration test looks for `UIScaleValue` (old @onready name) but the builder creates node names differently. The test also expects 9 apply actions but the builder's window confirm dialog flow may emit fewer.

- [ ] **Step 1: Run the failing tests to confirm current state**

Run: `tools/run_gut_suite.sh -gtest=res://tests/integration/display/test_display_settings.gd 2>&1 | tail -50`
Expected: 3 failing tests as reported

- [ ] **Step 2: Inspect what node names the builder actually creates for display tab**

Read `scripts/core/ui/settings/ui_display_settings_tab.gd` and `scripts/core/ui/helpers/u_settings_tab_builder.gd` to find the exact node names used for `UIScaleValue`, `UIScaleSlider`, and confirm dialog flow.

- [ ] **Step 3: Update test node lookups**

In `tests/integration/display/test_display_settings.gd`:
- Replace `_tab.get_node_or_null("UIScaleValue")` with `_tab.find_child("UIScaleValue", true, false)` (the built nodes may be in a different parent path)
- If the name differs from `UIScaleValue`, use the actual builder-created name
- Verify `_tab._window_confirm_active` is still the correct property name for checking confirm state
- Check that the `_preview_window_mode` callback flow works correctly through the builder

```gdscript
# Example fix for line ~350:
# Old:
var ui_scale_label: Label = _tab.get_node_or_null("UIScaleValue") as Label
# New:
var ui_scale_label: Label = _tab.find_child("UIScaleValue", true, false) as Label
# Or if builder uses a different name:
var ui_scale_label: Label = _tab.find_child("UIScaleValueLabel", true, false) as Label
```

- [ ] **Step 4: Fix confirm dialog flow if needed**

The test `test_apply_dispatches_actions_and_updates_state` expects 9 actions with `window_mode` set to "fullscreen". If the builder's confirm dialog requires an extra step, update the test to:
1. Check if `_window_confirm_active` is set
2. If so, call `_confirm_window_change()` or emit `WindowConfirmDialog.confirmed`
3. Then check dispatched actions

```gdscript
# After apply_button.pressed.emit(), if window confirmation needed:
if tab._window_confirm_active:
    tab._confirm_window_change()
    await get_tree().process_frame
```

- [ ] **Step 5: Verify display integration test passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/integration/display/test_display_settings.gd 2>&1 | tail -20`
Expected: 14 or more passing, 0 failing

- [ ] **Step 6: Commit**

```bash
git add tests/integration/display/test_display_settings.gd
git commit -m "test: GREEN fix display integration test node lookups for builder migration"
```

---

## Task 2: Fix Localization Settings Integration Test (7 failures)

**Files:**
- Modify: `tests/integration/localization/test_localization_settings_tab.gd`
- May need to modify: `tests/unit/ui/test_localization_settings_tab_theme.gd`

**Root cause:** The integration test uses `_get_language_option()`, `_get_dyslexia_toggle()`, `_get_apply_button()`, `_get_cancel_button()`, `_get_reset_button()`, `_get_language_confirm_dialog()`, `_get_language_confirm_ok_button()`, `_get_language_confirm_cancel_button()` helper methods that return nodes by old @onready-based names. The builder creates nodes with different names.

- [ ] **Step 1: Run failing localization tests**

Run: `timeout 120 tools/run_gut_suite.sh -gtest=res://tests/integration/localization/test_localization_settings_tab.gd 2>&1 | tail -60`
Expected: 7 failing tests

- [ ] **Step 2: Read localization tab script to find actual builder node names**

Read `scripts/core/ui/settings/ui_localization_settings_tab.gd` — find the `_get_*()` helper methods and what `find_child()` names they use.

- [ ] **Step 3: Update integration test node lookups**

In `tests/integration/localization/test_localization_settings_tab.gd`:

Update `_get_tab()`:
```gdscript
func _get_tab(overlay: Node) -> UI_LocalizationSettingsTab:
    return overlay.get_node_or_null("CenterContainer/Panel/VBox/LocalizationSettingsTab") as UI_LocalizationSettingsTab
```

If the builder changed the node hierarchy, the `_get_tab()` path may need adjustment. Check the overlay's `.tscn` structure.

Update `_await_overlay_ready()` to check for the right node existence:
```gdscript
func _await_overlay_ready(overlay: UI_LocalizationSettingsOverlay, max_frames: int = 60) -> void:
    for _i in range(max_frames):
        await get_tree().process_frame
        var tab := _get_tab(overlay)
        if overlay != null and overlay.get_store() != null and tab != null:
            return
```

The test calls `_get_language_option()`, `_get_dyslexia_toggle()`, etc. — if these are public methods on `UI_LocalizationSettingsTab`, they should still work after migration. If they return null, the method bodies need updating.

- [ ] **Step 4: Update theme test if needed**

In `tests/unit/ui/test_localization_settings_tab_theme.gd`:
- The test looks for `find_child("LanguageOption")` — change to `find_child("LanguageOptionButton")` if builder uses that name
- The test looks for `find_child("Section")` — change to `find_child("LanguageSection")` if builder uses that name
- The test looks for `find_child("SectionHeader")` — adjust if builder uses different name

```gdscript
# Update these lines:
var language_section := _tab.find_child("LanguageSection", true, false) as VBoxContainer  # was "Section"
var language_option := _tab.find_child("LanguageOptionButton", true, false) as OptionButton  # was "LanguageOption"
```

- [ ] **Step 5: Verify localization tests pass**

Run: `tools/run_gut_suite.sh -gtest=res://tests/integration/localization/test_localization_settings_tab.gd,res://tests/unit/ui/test_localization_settings_tab_theme.gd 2>&1 | tail -20`
Expected: All passing

- [ ] **Step 6: Commit**

```bash
git add tests/integration/localization/test_localization_settings_tab.gd tests/unit/ui/test_localization_settings_tab_theme.gd
git commit -m "test: GREEN fix localization integration test node lookups for builder migration"
```

---

## Task 3: Clean Up VFX Settings Overlay Duplicate Theming

**Files:**
- Modify: `scripts/core/ui/settings/ui_vfx_settings_overlay.gd`

**Root cause:** VFX overlay calls `_setup_builder()` (line 84) that binds controls, and calls `builder.apply_theme_tokens()` on line 111. But lines 113-120 still have inline theming code for the background dim color. This is redundant since the builder handles theming.

- [ ] **Step 1: Read full VFX overlay script**

Read `scripts/core/ui/settings/ui_vfx_settings_overlay.gd` lines 109-391 to understand all theming code that should be removed.

- [ ] **Step 2: Remove inline _apply_theme_tokens() logic**

The `_apply_theme_tokens()` method at line 109 should be simplified to only delegate to the builder:

```gdscript
func _apply_theme_tokens() -> void:
    if _builder != null:
        _builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
```

Remove lines 113-120 that manually set `background_color` and handle `OverlayBackground`. The dim color is an overlay concern — keep it but move it to `_on_panel_ready()` or `_setup_background()`:

Actually, the background dim color is overlay-specific, not generic theme token application. Keep it but move to `_setup_background_dim()` called from `_on_panel_ready()`:

```gdscript
func _on_panel_ready() -> void:
    _setup_background_dim()
    _setup_builder()
    _apply_theme_tokens()
    _configure_focus_neighbors()
    _localize_labels()
    _configure_tooltips()
    set_meta(&"settings_builder", true)
    var store := get_store()
    if store != null:
        _on_state_changed({}, store.get_state())
    play_enter_animation()

func _setup_background_dim() -> void:
    var config_resource: Resource = U_UI_THEME_BUILDER.active_config
    if not (config_resource is RS_UI_THEME_CONFIG):
        return
    var config := config_resource as RS_UI_THEME_CONFIG
    var dim_color := config.bg_base
    dim_color.a = 0.5
    background_color = dim_color
    var overlay_bg := get_node_or_null("OverlayBackground") as ColorRect
    if overlay_bg != null:
        overlay_bg.color = dim_color

func _apply_theme_tokens() -> void:
    if _builder != null:
        _builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
```

This keeps the overlay-specific background dimming separate from the builder-managed theme token application.

- [ ] **Step 3: Run VFX-related tests**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_vfx_settings_overlay_localization.gd 2>&1 | tail -20`
Expected: All passing

- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui/settings/ui_vfx_settings_overlay.gd
git commit -m "refactor: GREEN extract background dim from VFX overlay theme method"
```

---

## Task 4: Audit and Clean Up Remaining 13 Scripts

**Files to audit (each may need `_apply_theme_tokens()` cleanup if it still has inline code):**

1. `scripts/core/ui/menus/ui_main_menu.gd`
2. `scripts/core/ui/menus/ui_pause_menu.gd`
3. `scripts/core/ui/menus/ui_language_selector.gd`
4. `scripts/core/ui/menus/ui_credits.gd`
5. `scripts/core/ui/menus/ui_game_over.gd`
6. `scripts/core/ui/menus/ui_victory.gd`
7. `scripts/core/ui/menus/ui_settings_menu.gd`
8. `scripts/core/ui/overlays/ui_gamepad_settings_overlay.gd`
9. `scripts/core/ui/overlays/ui_keyboard_mouse_settings_overlay.gd`
10. `scripts/core/ui/overlays/ui_touchscreen_settings_overlay.gd`
11. `scripts/core/ui/overlays/ui_input_profile_selector.gd`
12. `scripts/core/ui/overlays/ui_save_load_menu.gd`
13. `scripts/core/ui/overlays/ui_input_rebinding_overlay.gd`

**Rule:** Each script that calls `_setup_builder()` or `_setup_menu_builder()` already delegates theming through the builder. If the script also has its own `_apply_theme_tokens()` method with inline `add_theme_*_override()` calls, that code is redundant and should be simplified to delegate to the builder.

- [ ] **Step 1: Check each script for `_apply_theme_tokens()` with inline override code**

For each file above, search for `_apply_theme_tokens` and `add_theme_` in the file.

Run a parallel audit:
```bash
rg -l "_apply_theme_tokens|_configure_focus_neighbors|_configure_tooltips|_localize_labels" scripts/core/ui/menus/ scripts/core/ui/overlays/
```

- [ ] **Step 2: For each script with inline theming code, simplify to builder delegation**

Pattern to apply:
```gdscript
# Before (bad — inline overrides):
func _apply_theme_tokens() -> void:
    var config := _resolve_theme_config()
    if config == null:
        return
    _title_label.add_theme_font_size_override(&"font_size", config.heading)
    _play_button.add_theme_font_size_override(&"font_size", config.section_header)
    # ... many more overrides ...

# After (good — builder delegation):
func _apply_theme_tokens() -> void:
    if _builder != null:
        _builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
```

Apply this simplification to each script. Keep any overlay-specific styling (background dim, motion effects) separate from theme token application.

- [ ] **Step 3: Run affected tests after each script cleanup**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_*_localization.gd,res://tests/unit/ui/test_*_theme.gd 2>&1 | tail -20
```

- [ ] **Step 4: Commit each group**

```bash
git add scripts/core/ui/menus/ui_main_menu.gd scripts/core/ui/menus/ui_pause_menu.gd # etc
git commit -m "refactor: GREEN simplify menu _apply_theme_tokens to builder delegation"
```

---

## Task 5: TSCN Cleanup for Fully Migrated Tabs

**Files:**
- Modify: `scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn`
- Modify: `scenes/core/ui/overlays/settings/ui_audio_settings_tab.tscn`
- Modify: `scenes/core/ui/overlays/settings/ui_localization_settings_tab.tscn`

**Goal:** Since display, audio, and localization tabs construct ALL child controls via the builder, remove any leftover child node declarations from their `.tscn` files that were replaced by builder-created equivalents.

- [ ] **Step 1: Read each .tscn to identify child nodes that are now builder-created**

Read the `.tscn` files and check if there are child nodes (like labels, OptionButtons, CheckBoxes) that are also constructed by the builder. These are duplicates.

- [ ] **Step 2: Remove redundant child nodes from .tscn files**

Only keep the root node and any structural containers that the builder expects to exist (like the VBoxContainer root). Remove child controls that the builder creates at runtime.

Make one atomic commit per `.tscn` so each is independently revertable.

- [ ] **Step 3: Run tests after each .tscn simplification**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_*_builder.gd,res://tests/unit/ui/settings/test_ui_*_migration.gd
```

- [ ] **Step 4: Commit**

```bash
git add scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn
git commit -m "refactor: GREEN simplify display settings tab tscn after builder migration"
```

---

## Task 6: Style Enforcement Updates

**Files:**
- May modify: `tests/unit/style/test_style_enforcement.gd`
- May modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd`
- May modify: `scripts/core/ui/helpers/u_ui_menu_builder.gd`

- [ ] **Step 1: Check LOC caps**

From spec P8.11:
- `u_settings_tab_builder.gd` under 300 lines (currently 315 — needs extraction)
- `u_ui_menu_builder.gd` under 200 lines (currently 158 — OK)
- `u_ui_settings_catalog.gd` under 150 lines (currently 174 — needs extraction)

Run:
```bash
wc -l scripts/core/ui/helpers/u_settings_tab_builder.gd scripts/core/ui/helpers/u_ui_menu_builder.gd scripts/core/ui/helpers/u_ui_settings_catalog.gd
```

- [ ] **Step 2: Extract helpers if LOC caps are exceeded**

If `u_settings_tab_builder.gd` > 300 lines:
- Extract `_apply_theme_tokens()`, `_localize_labels()`, and/or `_configure_focus()` into small helper functions in the same file (they're already private methods)
- Or extract the binding API methods (`bind_heading`, `bind_row`, `bind_field_control`, etc.) into a separate `u_tab_builder_bindings.gd` helper

If `u_ui_settings_catalog.gd` > 150 lines:
- Extract `create_display_builder()` into `u_display_tab_builder.gd`
- Extract `create_audio_builder()` into `u_audio_tab_builder.gd`
- Extract `create_localization_builder()` into `u_localization_tab_builder.gd`
- Keep the catalog as data-only

- [ ] **Step 3: Add style rules**

Add enforcement rule to `tests/unit/style/test_style_enforcement.gd`:
- Settings/menu scripts under `scripts/core/ui/settings/` and `scripts/core/ui/menus/` must not contain private `_apply_theme_tokens()` with `add_theme_*_override()` calls (must delegate to builder)
- Settings scripts must not contain private `_localize_with_fallback()` (already consolidated in `U_LOCALIZATION_UTILS`)

- [ ] **Step 4: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd 2>&1 | tail -20
```
Expected: All passing

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/helpers/ tests/unit/style/test_style_enforcement.gd
git commit -m "style: GREEN enforce LOC caps and builder delegation rules for Phase 8"
```

---

## Task 7: Full Test Suite Green

- [ ] **Step 1: Run full suite**

```bash
tools/run_gut_suite.sh 2>&1 | tail -30
```
Expected: 0 failures (8 pending from pre-existing allowed)

- [ ] **Step 2: Fix any remaining failures**

If tests fail, debug and fix per TDD workflow. Each fix should be its own commit.

- [ ] **Step 3: Run style enforcement one final time**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd 2>&1 | tail -20
```
Expected: All passing

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: GREEN Phase 8 completion — full suite green, all tests passing"
```

---

## Task 8: Update Spec Document

**Files:**
- Modify: `docs/history/cleanup_v8/cleanup-v8-tasks.md`

- [ ] **Step 1: Update P8.3–P8.11 verification checkboxes**

Mark all unchecked verification items as checked. Add completion notes with final test counts and commit hashes.

- [ ] **Step 2: Commit**

```bash
git add docs/history/cleanup_v8/cleanup-v8-tasks.md
git commit -m "docs: GREEN update Phase 8 verification checkboxes after completion"
```

---

## Dependency Order

```
Task 1 (Fix display tests) ──┐
                              ├──> Task 5 (TSCN cleanup) ──┐
Task 2 (Fix localization tests)┘                             │
                                                              ├──> Task 7 (Full suite green)
Task 3 (Clean VFX overlay) ────┐                             │
                                ├──> Task 6 (Style enforcement)┘
Task 4 (Clean 13 remaining) ───┘
                                                              ──> Task 8 (Update spec)
```

Tasks 1–4 are independent and can be done in parallel. Tasks 5 depends on 1+2 completing. Task 6 depends on 3+4 completing. Task 7 depends on 1–6. Task 8 is last.

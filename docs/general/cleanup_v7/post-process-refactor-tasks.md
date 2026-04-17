# Post-Processing Pipeline Refactor — Tasks Checklist

**Branch**: TBD
**Status**: COMPLETE (all 10 commits done)
**Methodology**: TDD (Red-Green-Refactor) — tests written within each commit, not deferred
**Scope**: Collapse the gameplay-visible post-process surface to exactly two passes (color grading, grain+dither), remove CRT entirely, rename color_grading → color_grading, and introduce `U_PostProcessPipeline` as a Compatibility-mode approximation of Godot's `CompositorEffect`. No behavioral change beyond (a) CRT removal and (b) enabling color grading on mobile. All existing display tests must stay green throughout.

---

## Purpose

The project's post-processing today is three independent systems wired by hand:

1. A "combined" fullscreen `ColorRect` + `ShaderMaterial` that bundles film grain + CRT + dither (`sh_combined_post_process_shader.gdshader`).
2. A separate cinema-grade `ColorRect` overlay on its own `CanvasLayer`.
3. An accessibility color-blind filter.

Each is applied through its own applier class with overlapping lifecycle code, mobile force-disables, and state-key conventions. CRT is carried in the code path but has dubious gameplay value, and the cinema grade is force-disabled on mobile because a third fullscreen shader pass on tile-based GPUs is prohibitive.

This refactor collapses the gameplay-visible post-process surface to exactly **two effects** and gives them a clean 2-pass pipeline that mimics `CompositorEffect` ergonomics without using that class (it is Forward+/Mobile-only; this project ships `gl_compatibility` on both desktop and mobile — verified in `project.godot`):

1. **Color grading** — rename of the existing cinema-grade system (identical uniforms, preserved per-scene auto-swap, shader logic unchanged).
2. **Grain + dither** — the surviving pair from the combined shader, with CRT stripped out.

Secondary outcomes:

- CRT is removed **entirely** — shader code, state, actions, selectors, reducers, UI controls, localization keys, preset `.tres` values, tests.
- Color grading becomes **mobile-enabled** (the fullscreen perf budget was blown by the combined shader's CRT path and by having three passes; with grain+dither simplified and only two passes, the envelope allows it).
- The color-blind filter is **explicitly out of scope** and stays as a separate `UIColorBlindLayer` — it's accessibility, not aesthetic, and needs to cover UI which the pipeline does not.

The goal is a pipeline where adding a new post-process pass means "author a `ColorRect` + shader and register it with `U_PostProcessPipeline`", not "invent a new applier class and wire it in three places." The pipeline is a Compatibility-mode approximation of Godot's Compositor, not the real API.

---

## Architecture

`U_PostProcessPipeline` is the new central coordinator. It owns:

- A deterministic ordered list of passes (color grading first, grain+dither second — order matters because grain should land in display space after grading).
- Per-pass `ColorRect` + `ShaderMaterial` registration against the existing `PostProcessOverlay` node tree.
- A unified frame-counter for time-based uniforms (film grain `fg_time`), replacing the ad-hoc `_fg_time_frame_counter` in `U_DisplayPostProcessApplier`.
- A single `apply_settings(display_state)` entry point that `M_DisplayManager` drives; passes pull their own uniforms via selectors.
- A single mobile-quality hook per pass (no blanket mobile disable — per-pass decision).

Existing `U_DisplayColorGradingApplier` and `U_DisplayPostProcessApplier` (renamed below) become thin delegates that register their pass into `U_PostProcessPipeline` and forward selector-driven uniform writes. The `U_PostProcessLayer` helper's legacy constants (`EFFECT_FILM_GRAIN`, `EFFECT_CRT`, `EFFECT_DITHER`) are deleted — the pipeline addresses passes by `StringName` key (`&"color_grading"`, `&"grain_dither"`).

## Reuse (do not re-author)

- **`U_PostProcessLayer`** (`scripts/managers/helpers/display/u_post_process_layer.gd`) — keep as the ColorRect-parameter setter abstraction. Drop the legacy `EFFECT_FILM_GRAIN`/`EFFECT_CRT`/`EFFECT_DITHER` constants; keep `EFFECT_COLOR_BLIND`; rename `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER`.
- **`U_CinemaGradeRegistry`** (`scripts/managers/helpers/display/u_color_grading_registry.gd`) — rename only; the scene-ID→grade lookup logic is correct and stays identical.
- **`RS_SceneCinemaGrade.to_dictionary()`** (`scripts/resources/display/rs_scene_color_grading.gd`) — rename to `RS_SceneColorGrading`; keep the 13-field shape and the conversion method. State keys change from `color_grading_*` to `color_grading_*` but the source fields don't.
- **`U_DisplayApplierUtils.get_tree_safe`** — keep; used by color-blind setup and will be used by pipeline for tree-deferred node creation.
- **`U_MobilePlatformDetector.is_mobile()`** — keep as the mobile branch predicate.
- **Film grain + dither shader code blocks** inside `sh_combined_post_process_shader.gdshader` (functions `_fg_hash13`, `_apply_film_grain`, `_dither_bayer8x8`, `_apply_dither`, lines ~32–87) — lift into a new `sh_grain_dither.gdshader` unchanged.
- **`sh_color_grading_shader.gdshader`** — rename to `sh_color_grading_shader.gdshader`; shader body unchanged.
- **Scene `.tres` grade resources** — rename the 5 files in `resources/display/color_gradings/` to `resources/display/color_gradings/` and re-point the registry preloads. Internal field values stay identical.

---

## Sequencing

C12 is independent of C1–C11 — post-processing pipeline refactor touches display manager helpers, display state, and shaders; no overlap with rule engine, selectors, or scene manager milestones. May run in parallel with any other milestone.
After C12 completes and passes regression, the next planned track is `docs/general/cleanup_v7/cleanup-v7.2-tasks.md`.

Within C12, commits are ordered so that each GREEN step can land cleanly:

- Commit 1 (RED) establishes the failing tests for both the new pipeline and the CRT/color_grading removals.
- Commits 2–4 remove CRT (state → UI/localization → shader/applier), stopping short of introducing the pipeline.
- Commits 5–7 rename color_grading → color_grading in three layered passes (state → resources/registry → applier/debug/UI/localization) to keep each commit's blast radius small and reviewable.
- Commit 8 introduces `U_PostProcessPipeline` and migrates both surviving appliers onto it.
- Commit 9 flips color grading to mobile-enabled.
- Commit 10 finalizes with style enforcement + pipeline-singular-entry-point tests.

---

## Critical Files

**Create:**

- `scripts/managers/helpers/display/u_post_process_pipeline.gd` — the new 2-pass coordinator
- `assets/shaders/sh_grain_dither.gdshader` — stripped from the combined shader (film grain + dither only)
- `tests/unit/managers/helpers/test_u_post_process_pipeline.gd` — pipeline tests (RED-first)

**Rename:**

- `scripts/managers/helpers/display/u_display_color_grading_applier.gd` → `u_display_color_grading_applier.gd`
- `scripts/managers/helpers/display/u_color_grading_registry.gd` → `u_color_grading_registry.gd`
- `scripts/resources/display/rs_scene_color_grading.gd` → `rs_scene_color_grading.gd`
- `scripts/state/actions/u_color_grading_actions.gd` → `u_color_grading_actions.gd`
- `scripts/state/selectors/u_color_grading_selectors.gd` → `u_color_grading_selectors.gd`
- `scripts/utils/display/u_color_grading_preview.gd` → `u_color_grading_preview.gd`
- `scripts/debug/debug_color_grading_overlay.gd` → `debug_color_grading_overlay.gd`
- `scenes/debug/debug_color_grading_overlay.tscn` → `debug_color_grading_overlay.tscn`
- `assets/shaders/sh_color_grading_shader.gdshader` → `sh_color_grading_shader.gdshader`
- `resources/display/color_gradings/cfg_color_grading_{gameplay_base,alleyway,bar,exterior,interior_house}.tres` → `resources/display/color_gradings/cfg_color_grading_*.tres` (5 files)
- `tests/unit/managers/test_color_grading_{mobile_disable,selectors,registry}.gd` → `test_color_grading_*.gd` (3 files)
- `tests/unit/resources/test_color_grading_filter_preset_map_consistency.gd` → `test_color_grading_filter_preset_map_consistency.gd`
- `tests/integration/display/test_color_grading_applier.gd` → `test_color_grading_applier.gd`

**Modify (content changes beyond rename):**

- `scripts/managers/helpers/display/u_display_post_process_applier.gd` — delegate to pipeline, drop CRT branches, drop `_fg_time_frame_counter`
- `scripts/managers/helpers/display/u_post_process_layer.gd` — drop legacy `EFFECT_FILM_GRAIN`/`EFFECT_CRT`/`EFFECT_DITHER` constants; rename `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER`
- `assets/shaders/sh_combined_post_process_shader.gdshader` — delete, replaced by `sh_grain_dither.gdshader`
- `scripts/state/reducers/u_display_reducer.gd` — delete 4 CRT reducer cases, rename 13 color_grading state keys → color_grading
- `scripts/state/selectors/u_display_selectors.gd` — delete 4 CRT selectors
- `scripts/state/actions/u_display_actions.gd` — delete 4 CRT action creators + constants
- `scripts/resources/state/rs_display_initial_state.gd` — remove CRT defaults
- `scripts/utils/display/u_post_processing_preset_values.gd` — remove CRT keys from preset dicts
- `scripts/utils/display/u_display_option_catalog.gd` — remove CRT option entries
- `resources/display/cfg_post_processing_presets/cfg_post_processing_{light,medium,heavy}.tres` — delete CRT keys (3 files)
- `scripts/ui/settings/ui_display_settings_tab.gd` + `.tscn` — remove CRT controls
- `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn` — audit and remove any CRT controls
- `scripts/managers/m_display_manager.gd` — update applier class references
- `scripts/managers/m_scene_manager.gd` — update cinema grade → color grading layer name reference
- `scripts/utils/debug/u_perf_monitor.gd`, `u_perf_shader_bypass.gd` — update layer-name constants
- `scripts/root.gd` — update post_process_overlay service registration comment/naming if applicable
- `resources/localization/cfg_locale_{en,ja,es,pt,zh}.tres` — remove CRT UI keys, rename color_grading UI keys → color_grading (5 files)

**Delete:**

- `assets/shaders/sh_crt_shader.gdshader` — standalone CRT shader, no longer referenced after removal

**Test files to update:**

- `tests/unit/state/test_display_reducer.gd` — remove CRT cases, update color_grading → color_grading
- `tests/unit/state/test_display_selectors.gd` — remove CRT selector tests
- `tests/unit/state/test_display_actions.gd` — remove CRT action tests
- `tests/unit/state/test_display_initial_state.gd` — remove CRT default assertions, rename color_grading keys
- `tests/unit/state/test_display_post_processing_preset.gd` — remove CRT preset fields
- `tests/integration/display/test_post_processing.gd` — remove CRT integration tests, refactor for new pipeline
- `tests/unit/managers/test_display_post_process_effect_enable_logic.gd` — remove CRT logic tests
- `tests/unit/managers/helpers/test_post_process_layer.gd` — drop legacy constant tests, add pipeline tests
- `tests/unit/utils/test_post_processing_preset_values.gd` — remove CRT field assertions
- `tests/unit/ui/test_display_settings_theme.gd`, `test_display_settings_post_processing_preset.gd` — remove CRT option assertions

---

## Milestone C12: Post-Processing Pipeline Refactor

**Goal**: Collapse post-processing to exactly two passes (color grading + grain/dither) behind a new `U_PostProcessPipeline` coordinator, remove CRT entirely, rename color_grading → color_grading across the codebase, and enable color grading on mobile.

- [x] **Commit 1** — Add pipeline + removal tests (TDD RED): ✅
  - `tests/unit/managers/helpers/test_u_post_process_pipeline.gd` — test pass registration, deterministic ordered evaluation, per-pass enable/disable, frame-counter uniform updates (`fg_time`), and pipeline teardown (unregister/clear). Class doesn't exist yet — parse-fails as intended RED.
  - `tests/unit/style/test_style_enforcement.gd` — added `test_no_color_grading_identifiers_in_scripts` and `test_no_crt_identifiers_in_display_scripts` grep assertions. Both correctly fail against existing codebase.
- [x] **Commit 2** — Delete CRT from state layer (TDD GREEN): ✅
  - `scripts/state/actions/u_display_actions.gd` — removed 4 `ACTION_SET_CRT_*` constants/creators and 4 `_static_init` registrations.
  - `scripts/state/selectors/u_display_selectors.gd` — removed 4 CRT selector methods.
  - `scripts/state/reducers/u_display_reducer.gd` — removed 4 CRT reducer cases, 3 CRT default keys, 3 CRT preset-value reads, 4 CRT clamp constants.
  - `scripts/resources/state/rs_display_initial_state.gd` — removed CRT export, 4 CRT dict entries, mobile CRT override.
  - `scripts/utils/display/u_post_processing_preset_values.gd` — removed 3 CRT keys from `get_preset_values()`.
  - `scripts/resources/display/rs_post_processing_preset.gd` — removed 3 CRT `@export` properties.
  - `resources/display/cfg_post_processing_presets/cfg_post_processing_{light,medium,heavy}.tres` — removed CRT field values.
  - `scripts/state/utils/u_global_settings_applier.gd` — removed 4 CRT dispatch lines.
  - Updated 7 test files: removed CRT tests and assertions from `test_display_reducer`, `test_display_selectors`, `test_display_actions`, `test_display_initial_state`, `test_display_post_process_effect_enable_logic`, `test_post_processing_preset_values`, `test_post_process_layer`.
- [x] **Commit 3** — Delete CRT from UI/localization (TDD GREEN): ✅
  - `scripts/ui/settings/ui_display_settings_tab.gd` + `.tscn` — no CRT controls present (already clean).
  - `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn` — no CRT controls present (already clean).
  - `scripts/utils/display/u_display_option_catalog.gd` — no CRT option entries (already clean).
  - `resources/localization/cfg_locale_{en,ja,es,pt,zh}.tres` — no CRT UI keys (already clean).
  - Tests: `test_display_settings_theme`, `test_display_settings_post_processing_preset` — already clean.
- [x] **Commit 4** — Strip CRT from shaders + applier (TDD GREEN): ✅
  - `assets/shaders/sh_combined_post_process_shader.gdshader` → `sh_grain_dither.gdshader` — CRT code stripped; grain + dither retained.
  - `assets/shaders/sh_crt_shader.gdshader` — deleted.
  - `scripts/managers/helpers/display/u_display_post_process_applier.gd` — CRT parameter setters, mobile force-disable, and `_fg_time_frame_counter` removed.
  - `scripts/managers/helpers/display/u_post_process_layer.gd` — legacy `EFFECT_FILM_GRAIN`/`EFFECT_CRT`/`EFFECT_DITHER` constants dropped; `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER`.
  - `scenes/ui/overlays/ui_post_process_overlay.tscn` — shader reference updated to `sh_grain_dither.gdshader`; CRT uniforms removed.
- [x] **Commit 5** — Rename color_grading → color_grading in state layer (TDD GREEN): ✅
  - `u_color_grading_actions.gd` → `u_color_grading_actions.gd`; class, constants, creators renamed.
  - `u_color_grading_selectors.gd` → `u_color_grading_selectors.gd`; class, selectors renamed.
  - `u_display_reducer.gd` — `color_grading_*` keys → `color_grading_*`; action cases updated.
- [x] **Commit 6** — Rename resources + scene-swap registry (TDD GREEN): ✅
  - `rs_scene_color_grading.gd` → `rs_scene_color_grading.gd`; class, `to_dictionary()` key prefixes updated.
  - `u_color_grading_registry.gd` → `u_color_grading_registry.gd`; class, preload paths updated.
  - `resources/display/color_gradings/` → `resources/display/color_gradings/`; 5 `.tres` files renamed.
- [x] **Commit 7** — Finish color_grading rename (applier + debug + UI + localization) (TDD GREEN): ✅
  - `u_display_color_grading_applier.gd` → `u_display_color_grading_applier.gd`; class, references updated.
  - `sh_color_grading_shader.gdshader` → `sh_color_grading_shader.gdshader`; applier preload updated.
  - `u_color_grading_preview.gd` → `u_color_grading_preview.gd`.
  - `debug_color_grading_overlay.gd` + `.tscn` → `debug_color_grading_overlay.*`.
  - `m_display_manager.gd`, `m_scene_manager.gd`, `u_perf_monitor.gd`, `u_perf_shader_bypass.gd` — applier/layer references updated.
  - `cfg_locale_*.tres` — 13 color_grading UI keys → color_grading.
  - Test files renamed: `test_color_grading_*.gd` → `test_color_grading_*.gd`.
- [x] **Commit 8** — Introduce `U_PostProcessPipeline` (TDD GREEN): ✅
  - `scripts/managers/helpers/display/u_post_process_pipeline.gd` — 2-pass pipeline with `register_pass`, `apply_settings`, `update_per_frame`, `get_pass` APIs.
  - `U_DisplayColorGradingApplier` registers as pass `&"color_grading"`.
  - `U_DisplayPostProcessApplier` registers as pass `&"grain_dither"`.
  - `fg_time` per-frame update consolidated into pipeline's `update_per_frame`.
  - Pipeline tests in `test_u_post_process_pipeline.gd` GREEN (12/12).
- [x] **Commit 9** — Enable color grading on mobile (TDD GREEN): ✅
  - `u_display_color_grading_applier.gd` — `_is_mobile` force-disable branches removed.
  - `test_color_grading_mobile_disable.gd` → `test_color_grading_mobile_enabled.gd`; polarity flipped.
- [x] **Commit 10** — Finalize style enforcement + legacy cleanup (TDD GREEN): ✅
  - `test_style_enforcement.gd` — Commit 1 grep assertions now pass (no color_grading, no CRT, no legacy layer constants). Updated "will FAIL" comments to reflect completion.
  - Added `test_post_process_overlay_colorrect_creation_only_via_pipeline` — only pipeline delegates and editor-only preview create ColorRect under PostProcessOverlay.
  - Removed residual CRT entries from `test_display_selectors.gd` DEFAULTS dict (gap from Commit 2).
  - No remaining dead code or unreferenced helpers found.

---

## C12 Verification

### Test-level (per commit and at completion)

- [x] Every existing display test green after each commit
- [x] New `test_u_post_process_pipeline.gd` green after Commit 8 (12/12)
- [x] `test_style_enforcement.gd` grep assertions pass after Commit 10 (35/35):
  - `grep -r "color_grading" scripts/` returns zero hits
  - `grep -r "crt_" scripts/` returns zero hits (allowlist any non-post-process CRT-acronym usage)
  - `grep -r "chromatic_aberration\|scanline\|curvature" scripts/` returns zero hits in display/post-process contexts
  - No file outside `u_post_process_pipeline.gd` and its delegate appliers constructs `ColorRect` children under `PostProcessOverlay`
- [x] Full GUT suite green: `tests/unit/state/` (535/535), `tests/unit/managers/` (576/576), `tests/integration/display/` (52/52), `tests/unit/ui/` (357/357 + 2 mobile-pending)

### Runtime validation (end-to-end)

1. **Desktop boot + per-scene grading** — boot the game, transition between `alleyway`, `bar`, `exterior`, `interior_house`, `gameplay_base`. Visually confirm the color grading changes per scene (matches pre-refactor behavior pixel-for-pixel on a reference scene). Cross-check by reading `state.display.color_grading_*` values in the state debug overlay and comparing against the renamed `.tres` source files.
2. **Settings UI** — open Display Settings, confirm no CRT controls remain, confirm film grain + dither toggles still work and update in real time, confirm color-grading-related controls (if any are user-facing beyond the scene-driven auto-swap) are renamed correctly.
3. **Mobile enable validation** — run on Android device or `--emulate-mobile`:
   - Confirm color grading applies on mobile (previously hidden)
   - Measure frame time before/after on a demanding gameplay scene using `U_PerfMonitor`
   - If the color-grading pass costs more than ~1.5ms on reference mobile hardware, roll back to mobile-disabled in Commit 9 and leave a `TODO` note for a LUT-based replacement
4. **Color-blind filter unaffected** — toggle deuteranopia/protanopia/tritanopia; confirm UI and viewport still apply the daltonize shader. This is regression-only — the layer should be untouched by the refactor.
5. **Scene swap auto-load** — dispatch `scene/swapped` manually via debug overlay with a known scene ID; confirm the color grading state slice updates and the visible result matches the registered `.tres` grade.
6. **Shader hot-reload sanity** — edit `sh_grain_dither.gdshader` in-editor, save, confirm no shader compile errors and that film grain still animates.

### Mobile cache warning

Since this refactor touches 5 `.tres` resource renames and a shader rename, all installed mobile builds will need a fresh install (PCK packing changes). Flag in the Commit 7 message.

---

## C12 Gap Audit (2026-04-13)

Post-completion audit revealed gaps in integration depth, rename coverage, test coverage, and documentation freshness. Tracked as Commits 11–16 below.

### Findings

| Severity | Gap | Root cause |
|----------|-----|------------|
| HIGH | `pipeline.apply_settings()` never called at runtime — M_DisplayManager calls each applier's `apply_settings()` independently instead of delegating visibility to the pipeline | Commit 8 wired registration + `update_per_frame` but did not centralize visibility control |
| MEDIUM | ~30 bare `cinema` references survive in 3 production files + `project.godot` — rename only targeted `color_grading` (with underscore) | Enforcement test grep was too narrow (only `color_grading`) |
| MEDIUM | `CombinedLayer`/`CombinedRect` scene node names + all references (NodePath, perf_monitor, perf_shader_bypass, 2 test files) never renamed to `GrainDitherLayer`/`GrainDitherRect` | `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER` constant rename didn't propagate to scene tree or debug utilities |
| MEDIUM | `CINEMA_OFF` mode + `_was_cinema_visible` + `_disable_cinema_only()` + comments in `u_perf_shader_bypass.gd` | Same narrow-grep blind spot |
| MEDIUM | `_cinema_debug_overlay`, `register_cinema_debug_overlay()`, `get_cinema_debug_overlay()`, `toggle_cinema_debug` input action in `m_state_store.gd` + `rs_rebind_settings.gd` + `project.godot` | Same narrow-grep blind spot |
| MEDIUM | 8 residual `cinema`/`combined` references in 5 test files | Rename stopped at file rename, didn't sweep function/variable/comment names |
| LOW | Pipeline test count is 11, task doc says 12/12 | Missing coverage for `apply_settings` no-op path |
| LOW | Style enforcement test only greps for `color_grading` (with underscore) — misses bare `cinema` and `combined` in display contexts | Test was written to match the rename scope, not the full semantic intent |
| LOW | 168 stale `color_grading` references across `docs/` + `AGENTS.md`; 3 stale CRT references in `docs/` | Documentation not updated after rename |
| LOW | `.claude/settings.local.json` has stale path to deleted `u_display_color_grading_applier.gd` | Settings artifact from pre-rename |

---

## Milestone C12-gap: Post-Refactor Gap Fixes

**Goal**: Close all audit gaps from C12. Commits 11–16 are ordered so that each GREEN step can land cleanly. Each commit includes its own test changes.

- [ ] **Commit 11** — Complete cinema/combined renames in production code (TDD GREEN):
  - `scenes/ui/overlays/ui_post_process_overlay.tscn` — rename `CombinedLayer` → `GrainDitherLayer`, `CombinedRect` → `GrainDitherRect`
  - `scripts/managers/helpers/display/u_post_process_layer.gd` — `NodePath("CombinedLayer/CombinedRect")` → `NodePath("GrainDitherLayer/GrainDitherRect")`
  - `scripts/utils/debug/u_perf_monitor.gd` — `&"CombinedLayer"` → `&"GrainDitherLayer"`, output label `combined=` → `grain_dither=`
  - `scripts/utils/debug/u_perf_shader_bypass.gd` — full rename pass:
    - `"CINEMA_OFF"` → `"COLOR_GRADING_OFF"` in `SHADER_BYPASS_MODES`
    - `_was_cinema_visible` → `_was_color_grading_visible`
    - `_disable_cinema_only()` → `_disable_color_grading_only()`
    - `# Disable cinema grade` → `# Disable color grading`
    - `# Restore cinema grade first` → `# Restore color grading first`
    - `_was_combined_visible` → `_was_grain_dither_visible`
    - `debug_restore_combined_visibility` → `debug_restore_grain_dither_visibility`
    - `debug_force_disable_combined` → `debug_force_disable_grain_dither`
  - `scripts/managers/helpers/display/u_display_post_process_applier.gd` — rename `debug_force_disable_combined` → `debug_force_disable_grain_dither`, `debug_restore_combined_visibility` → `debug_restore_grain_dither_visibility`
  - `scripts/state/m_state_store.gd` — full rename pass:
    - `_cinema_debug_overlay` → `_color_grading_debug_overlay`
    - `PROJECT_SETTING_ENABLE_CINEMA_DEBUG_OVERLAY` → `PROJECT_SETTING_ENABLE_COLOR_GRADING_DEBUG_OVERLAY`
    - `cinema_debug_enabled` → `color_grading_debug_enabled`
    - `cinema_toggle_pressed` → `color_grading_toggle_pressed`
    - `"toggle_cinema_debug"` → `"toggle_color_grading_debug"`
    - `register_cinema_debug_overlay()` → `register_color_grading_debug_overlay()`
    - `get_cinema_debug_overlay()` → `get_color_grading_debug_overlay()`
    - `_on_cinema_debug_overlay_tree_exiting()` → `_on_color_grading_debug_overlay_tree_exiting()`
    - Comments: "cinema debug overlay" → "color grading debug overlay"
  - `scripts/resources/input/rs_rebind_settings.gd` — `"toggle_cinema_debug"` → `"toggle_color_grading_debug"`
  - `project.godot` — InputMap `toggle_cinema_debug` → `toggle_color_grading_debug`
  - Update `project.godot` project setting key `state/debug/enable_cinema_debug_overlay` → `state/debug/enable_color_grading_debug_overlay`

- [ ] **Commit 12** — Complete cinema/combined renames in test code (TDD GREEN):
  - `tests/integration/display/test_color_grading_applier.gd` — `cinema_settings` → `color_grading_settings`, `cinema_state` → `color_grading_state` in function name
  - `tests/unit/managers/test_color_grading_selectors.gd` — `non_cinema_keys` → `non_color_grading_keys`, `no_cinema_keys` → `no_color_grading_keys` in function names
  - `tests/unit/state/test_display_reducer.gd` — `# --- Cinema Grade:` → `# --- Color Grading:`
  - `tests/unit/managers/helpers/test_post_process_layer.gd` — `"CombinedLayer"` → `"GrainDitherLayer"`, `"CombinedRect"` → `"GrainDitherRect"`
  - `tests/integration/display/test_post_processing.gd` — `"CombinedLayer"` → `"GrainDitherLayer"`, CombinedLayer node lookups updated
  - `tests/unit/managers/helpers/test_u_post_process_pipeline.gd` — verify no cinema/combined references (should be clean already)

- [ ] **Commit 13** — Wire `pipeline.apply_settings()` as the single visibility entry point (TDD GREEN):
  - `scripts/managers/m_display_manager.gd` — add `_pipeline.apply_settings(display_settings)` call, replacing per-applier visibility logic. Each applier's `apply_settings` should still handle uniform writes but delegate visibility to the pipeline.
  - Add pipeline test for `apply_settings` with unknown pass_id (no-op path) — brings count to 12
  - Verify: the only code that sets `rect.visible` on post-process passes is `pipeline.apply_settings`

- [ ] **Commit 14** — Widen style enforcement grep to catch bare `cinema` and `combined` in display contexts (TDD GREEN):
  - `tests/unit/style/test_style_enforcement.gd` — extend `test_no_color_grading_identifiers_in_scripts` to also grep for bare `cinema` in display/post-process scripts (allowlist `cinematic` in camera manager, which is a different concept). Add `test_no_combined_identifiers_in_display_scripts` that greps for `CombinedLayer`/`CombinedRect`/`combined_visible`/`combined_post_process` in display scripts.
  - Verify enforcement tests pass with zero violations after Commits 11–13.

- [ ] **Commit 15** — Clean stale documentation (no code changes):
  - Update all 168 `color_grading` references across `docs/` and `AGENTS.md` to `color_grading`
  - Update 3 stale CRT references in `docs/display_manager/`
  - Update `CombinedLayer`/`CombinedRect` references in docs
  - Update `toggle_cinema_debug` → `toggle_color_grading_debug` in docs

- [ ] **Commit 16** — Settings artifact cleanup:
  - `.claude/settings.local.json` — remove or update stale `u_display_color_grading_applier.gd` path

---

## C12-gap Verification

- [ ] `grep -r "cinema" scripts/managers/helpers/display/ scripts/utils/debug/ scripts/state/m_state_store.gd scripts/utils/debug/u_perf_shader_bypass.gd` returns zero hits (allowlist `cinematic` in camera manager)
- [ ] `grep -r "CombinedLayer\|CombinedRect\|combined_visible\|_was_combined\|debug_force_disable_combined\|debug_restore_combined" scripts/` returns zero hits
- [ ] `grep -r "toggle_cinema_debug\|cinema_debug_overlay" scripts/ project.godot` returns zero hits
- [ ] Pipeline test count >= 12 (currently 15)
- [ ] `pipeline.apply_settings()` called from M_DisplayManager (not dead code)
- [ ] Style enforcement tests pass ( widened grep)
- [ ] `grep -r "color_grading" docs/ AGENTS.md` returns zero hits
- [ ] Full GUT suite green

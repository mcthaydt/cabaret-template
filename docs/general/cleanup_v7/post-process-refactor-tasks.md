# Post-Processing Pipeline Refactor — Tasks Checklist

**Branch**: TBD
**Status**: Not started
**Methodology**: TDD (Red-Green-Refactor) — tests written within each commit, not deferred
**Scope**: Collapse the gameplay-visible post-process surface to exactly two passes (color grading, grain+dither), remove CRT entirely, rename cinema_grade → color_grading, and introduce `U_PostProcessPipeline` as a Compatibility-mode approximation of Godot's `CompositorEffect`. No behavioral change beyond (a) CRT removal and (b) enabling color grading on mobile. All existing display tests must stay green throughout.

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
- **`U_CinemaGradeRegistry`** (`scripts/managers/helpers/display/u_cinema_grade_registry.gd`) — rename only; the scene-ID→grade lookup logic is correct and stays identical.
- **`RS_SceneCinemaGrade.to_dictionary()`** (`scripts/resources/display/rs_scene_cinema_grade.gd`) — rename to `RS_SceneColorGrading`; keep the 13-field shape and the conversion method. State keys change from `cinema_grade_*` to `color_grading_*` but the source fields don't.
- **`U_DisplayApplierUtils.get_tree_safe`** — keep; used by color-blind setup and will be used by pipeline for tree-deferred node creation.
- **`U_MobilePlatformDetector.is_mobile()`** — keep as the mobile branch predicate.
- **Film grain + dither shader code blocks** inside `sh_combined_post_process_shader.gdshader` (functions `_fg_hash13`, `_apply_film_grain`, `_dither_bayer8x8`, `_apply_dither`, lines ~32–87) — lift into a new `sh_grain_dither.gdshader` unchanged.
- **`sh_cinema_grade_shader.gdshader`** — rename to `sh_color_grading_shader.gdshader`; shader body unchanged.
- **Scene `.tres` grade resources** — rename the 5 files in `resources/display/cinema_grades/` to `resources/display/color_gradings/` and re-point the registry preloads. Internal field values stay identical.

---

## Sequencing

C12 is independent of C1–C11 — post-processing pipeline refactor touches display manager helpers, display state, and shaders; no overlap with rule engine, selectors, or scene manager milestones. May run in parallel with any other milestone.

Within C12, commits are ordered so that each GREEN step can land cleanly:

- Commit 1 (RED) establishes the failing tests for both the new pipeline and the CRT/cinema_grade removals.
- Commits 2–4 remove CRT (state → UI/localization → shader/applier), stopping short of introducing the pipeline.
- Commits 5–7 rename cinema_grade → color_grading in three layered passes (state → resources/registry → applier/debug/UI/localization) to keep each commit's blast radius small and reviewable.
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

- `scripts/managers/helpers/display/u_display_cinema_grade_applier.gd` → `u_display_color_grading_applier.gd`
- `scripts/managers/helpers/display/u_cinema_grade_registry.gd` → `u_color_grading_registry.gd`
- `scripts/resources/display/rs_scene_cinema_grade.gd` → `rs_scene_color_grading.gd`
- `scripts/state/actions/u_cinema_grade_actions.gd` → `u_color_grading_actions.gd`
- `scripts/state/selectors/u_cinema_grade_selectors.gd` → `u_color_grading_selectors.gd`
- `scripts/utils/display/u_cinema_grade_preview.gd` → `u_color_grading_preview.gd`
- `scripts/debug/debug_cinema_grade_overlay.gd` → `debug_color_grading_overlay.gd`
- `scenes/debug/debug_cinema_grade_overlay.tscn` → `debug_color_grading_overlay.tscn`
- `assets/shaders/sh_cinema_grade_shader.gdshader` → `sh_color_grading_shader.gdshader`
- `resources/display/cinema_grades/cfg_cinema_grade_{gameplay_base,alleyway,bar,exterior,interior_house}.tres` → `resources/display/color_gradings/cfg_color_grading_*.tres` (5 files)
- `tests/unit/managers/test_cinema_grade_{mobile_disable,selectors,registry}.gd` → `test_color_grading_*.gd` (3 files)
- `tests/unit/resources/test_cinema_grade_filter_preset_map_consistency.gd` → `test_color_grading_filter_preset_map_consistency.gd`
- `tests/integration/display/test_cinema_grade_applier.gd` → `test_color_grading_applier.gd`

**Modify (content changes beyond rename):**

- `scripts/managers/helpers/display/u_display_post_process_applier.gd` — delegate to pipeline, drop CRT branches, drop `_fg_time_frame_counter`
- `scripts/managers/helpers/display/u_post_process_layer.gd` — drop legacy `EFFECT_FILM_GRAIN`/`EFFECT_CRT`/`EFFECT_DITHER` constants; rename `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER`
- `assets/shaders/sh_combined_post_process_shader.gdshader` — delete, replaced by `sh_grain_dither.gdshader`
- `scripts/state/reducers/u_display_reducer.gd` — delete 4 CRT reducer cases, rename 13 cinema_grade state keys → color_grading
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
- `resources/localization/cfg_locale_{en,ja,es,pt,zh}.tres` — remove CRT UI keys, rename cinema_grade UI keys → color_grading (5 files)

**Delete:**

- `assets/shaders/sh_crt_shader.gdshader` — standalone CRT shader, no longer referenced after removal

**Test files to update:**

- `tests/unit/state/test_display_reducer.gd` — remove CRT cases, update cinema_grade → color_grading
- `tests/unit/state/test_display_selectors.gd` — remove CRT selector tests
- `tests/unit/state/test_display_actions.gd` — remove CRT action tests
- `tests/unit/state/test_display_initial_state.gd` — remove CRT default assertions, rename cinema_grade keys
- `tests/unit/state/test_display_post_processing_preset.gd` — remove CRT preset fields
- `tests/integration/display/test_post_processing.gd` — remove CRT integration tests, refactor for new pipeline
- `tests/unit/managers/test_display_post_process_effect_enable_logic.gd` — remove CRT logic tests
- `tests/unit/managers/helpers/test_post_process_layer.gd` — drop legacy constant tests, add pipeline tests
- `tests/unit/utils/test_post_processing_preset_values.gd` — remove CRT field assertions
- `tests/unit/ui/test_display_settings_theme.gd`, `test_display_settings_post_processing_preset.gd` — remove CRT option assertions

---

## Milestone C12: Post-Processing Pipeline Refactor

**Goal**: Collapse post-processing to exactly two passes (color grading + grain/dither) behind a new `U_PostProcessPipeline` coordinator, remove CRT entirely, rename cinema_grade → color_grading across the codebase, and enable color grading on mobile.

- [ ] **Commit 1** — Add pipeline + removal tests (TDD RED):
  - `tests/unit/managers/helpers/test_u_post_process_pipeline.gd` — test pass registration, deterministic ordered evaluation, per-pass enable/disable, frame-counter uniform updates (`fg_time`), and pipeline teardown (unregister/clear).
  - `tests/unit/style/test_style_enforcement.gd` — add grep assertions that `scripts/` contains no `cinema_grade`, `CinemaGrade`, `crt_`, `chromatic_aberration`, `scanline`, or `curvature` identifiers in post-processing contexts (allowlist legacy audio/lighting uses if any).
- [ ] **Commit 2** — Delete CRT from state layer (TDD GREEN):
  - `scripts/state/actions/u_display_actions.gd` — remove 4 `ACTION_SET_CRT_*` constants and creators, strip from `_static_init()`.
  - `scripts/state/selectors/u_display_selectors.gd` — remove 4 CRT selectors.
  - `scripts/state/reducers/u_display_reducer.gd` — remove CRT reducer cases, remove CRT keys from `DEFAULT_DISPLAY_STATE`.
  - `scripts/resources/state/rs_display_initial_state.gd` — remove CRT defaults.
  - `scripts/utils/display/u_post_processing_preset_values.gd` — remove CRT keys.
  - `resources/display/cfg_post_processing_presets/cfg_post_processing_{light,medium,heavy}.tres` — delete CRT fields.
  - Update tests: `test_display_reducer`, `test_display_selectors`, `test_display_actions`, `test_display_initial_state`, `test_display_post_processing_preset`, `test_post_processing_preset_values`.
- [ ] **Commit 3** — Delete CRT from UI/localization (TDD GREEN):
  - `scripts/ui/settings/ui_display_settings_tab.gd` + `.tscn` — remove CRT control nodes and handlers.
  - `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn` — audit and remove CRT controls if present.
  - `scripts/utils/display/u_display_option_catalog.gd` — remove CRT option entries.
  - `resources/localization/cfg_locale_{en,ja,es,pt,zh}.tres` — remove CRT UI keys (5 files).
  - Update tests: `test_display_settings_theme`, `test_display_settings_post_processing_preset`.
- [ ] **Commit 4** — Strip CRT from shaders + applier (TDD GREEN):
  - `assets/shaders/sh_combined_post_process_shader.gdshader` — delete ~90 lines of CRT code (`_crt_*` functions, uniforms, fragment branch); keep grain + dither; rename file to `sh_grain_dither.gdshader`.
  - `assets/shaders/sh_crt_shader.gdshader` — delete entirely.
  - `scripts/managers/helpers/display/u_display_post_process_applier.gd` — remove all `crt_*` parameter setters, remove mobile CRT force-disable branch, remove `_fg_time_frame_counter` (moves into pipeline in Commit 8).
  - `scripts/managers/helpers/display/u_post_process_layer.gd` — drop `EFFECT_FILM_GRAIN`/`EFFECT_CRT`/`EFFECT_DITHER` legacy constants; rename `EFFECT_COMBINED` → `EFFECT_GRAIN_DITHER`.
  - `scenes/ui/overlays/ui_post_process_overlay.tscn` — update shader reference, remove CRT uniforms from the saved resource.
  - Update tests: `test_post_processing`, `test_display_post_process_effect_enable_logic`, `test_post_process_layer`.
- [ ] **Commit 5** — Rename cinema_grade → color_grading in state layer (TDD GREEN):
  - Rename `u_cinema_grade_actions.gd` → `u_color_grading_actions.gd`; rename class, action constants, creators.
  - Rename `u_cinema_grade_selectors.gd` → `u_color_grading_selectors.gd`; rename class, selector methods.
  - `scripts/state/reducers/u_display_reducer.gd` — rename all `cinema_grade_*` state keys to `color_grading_*`; update action case matches.
  - Update tests: `test_display_reducer`, related unit tests.
- [ ] **Commit 6** — Rename resources + scene-swap registry (TDD GREEN):
  - Rename `rs_scene_cinema_grade.gd` → `rs_scene_color_grading.gd`; rename class, update `to_dictionary()` key prefixes.
  - Rename `u_cinema_grade_registry.gd` → `u_color_grading_registry.gd`; rename class, update preload paths.
  - Rename `resources/display/cinema_grades/` → `resources/display/color_gradings/`; rename 5 `.tres` files `cfg_cinema_grade_*` → `cfg_color_grading_*`.
  - Update tests: `test_color_grading_registry`, `test_color_grading_filter_preset_map_consistency`.
- [ ] **Commit 7** — Finish cinema_grade rename (applier + debug + UI + localization) (TDD GREEN):
  - Rename `u_display_cinema_grade_applier.gd` → `u_display_color_grading_applier.gd`; rename class, update service references.
  - Rename `sh_cinema_grade_shader.gdshader` → `sh_color_grading_shader.gdshader`; update applier preload.
  - Rename `u_cinema_grade_preview.gd` → `u_color_grading_preview.gd`.
  - Rename `debug_cinema_grade_overlay.gd` + `.tscn` → `debug_color_grading_overlay.*`.
  - `m_display_manager.gd`, `m_scene_manager.gd`, `u_perf_monitor.gd`, `u_perf_shader_bypass.gd` — update applier/layer references.
  - `cfg_locale_{en,ja,es,pt,zh}.tres` — rename 13 cinema_grade UI keys → color_grading.
  - Update tests: rename `test_cinema_grade_*.gd` → `test_color_grading_*.gd` (5 files); update class/var references.
  - **Mobile cache warning**: this commit renames 5 `.tres` resources and a shader; installed mobile builds will need a fresh install (PCK packing changes). Flag in the commit message.
- [ ] **Commit 8** — Introduce `U_PostProcessPipeline` (TDD GREEN):
  - `scripts/managers/helpers/display/u_post_process_pipeline.gd` — implement 2-pass pipeline with `register_pass(id, rect, shader, enable_selector, uniform_updater)`, `apply_settings(state)`, `update_per_frame(state)`, and `get_pass(id)` APIs.
  - Migrate `U_DisplayColorGradingApplier` to register itself as pass `&"color_grading"` with the pipeline.
  - Migrate `U_DisplayPostProcessApplier` (now grain+dither only) to register itself as pass `&"grain_dither"` with the pipeline.
  - Move `fg_time` per-frame update into the pipeline's `update_per_frame` hook so there's one frame counter, not two.
  - `scripts/managers/m_display_manager.gd` — instantiate the pipeline and drive both passes through it.
  - Pipeline tests in `test_u_post_process_pipeline.gd` turn GREEN.
- [ ] **Commit 9** — Enable color grading on mobile (TDD GREEN):
  - `scripts/managers/helpers/display/u_display_color_grading_applier.gd` — delete `_is_mobile` force-disable branches (3 locations); keep sharpness mobile override only if a perf probe confirms it's still expensive.
  - `test_color_grading_mobile_disable.gd` — flip polarity — assert the layer is now active on mobile; rename test to reflect positive behavior (`test_color_grading_mobile_enabled.gd` or similar).
  - Document mobile validation steps in the commit message (reference dashboard + `U_PerfMonitor` measurements).
- [ ] **Commit 10** — Finalize style enforcement + legacy cleanup (TDD GREEN):
  - `test_style_enforcement.gd` — tests added in Commit 1 now pass (no cinema_grade, no CRT, no legacy layer constants).
  - Add pipeline-singular-entry-point test: assert that no file outside `u_post_process_pipeline.gd` creates `ColorRect` children directly under `PostProcessOverlay`.
  - Delete any remaining dead code or unreferenced helpers flagged during the rename passes.

---

## C12 Verification

### Test-level (per commit and at completion)

- [ ] Every existing display test green after each commit
- [ ] New `test_u_post_process_pipeline.gd` green after Commit 8
- [ ] `test_style_enforcement.gd` grep assertions pass after Commit 10:
  - `grep -r "cinema_grade" scripts/` returns zero hits
  - `grep -r "crt_" scripts/` returns zero hits (allowlist any non-post-process CRT-acronym usage)
  - `grep -r "chromatic_aberration\|scanline\|curvature" scripts/` returns zero hits in display/post-process contexts
  - No file outside `u_post_process_pipeline.gd` constructs `ColorRect` children under `PostProcessOverlay`
- [ ] Full GUT suite green: `tests/unit/state/`, `tests/unit/managers/`, `tests/integration/display/`, `tests/unit/ui/`

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

# Input Manager Continuation Prompt

## Current Focus: Phase 6 - Touchscreen Support

- **Branch:** `input-manager`
- **Status:** Tasks 6.0-6.12 complete; Phase 6R QA complete; remaining task 6.13 (performance)
- **Progress:** 77% complete (92/120 tasks); Phase 6 core behavior implemented, migration verified, pending performance validation
- **Documentation:** Comprehensive architecture validation complete (2025-11-16), task audit complete (2025-11-23)

## Phase 6 Status

- ✅ Viewport scaling CORRECT (960x540, no hardcoded dimensions)
- ✅ Redux state READY (touchscreen_settings with all position/size/opacity fields)
- ✅ Device detection WORKING (M_InputDeviceManager handles touch events)
- ✅ MobileControls scene complete (profile-driven buttons, Tween opacity fade, pause/transition hide)
- ✅ TouchscreenSettingsOverlay + EditTouchControlsOverlay implemented
- ✅ Phase 6R manual QA complete (6.9.5-6.9.7)
- ✅ Save file migration complete (6.12.1-6.12.5)
- ⏳ Performance validation pending (6.13)

**See detailed documentation:** `phase-6-touchscreen-architecture.md`, `input-manager-tasks.md`, `DEV_PITFALLS.md`

## Required Readings (Phase 6)

**Project Conventions:**
- `AGENTS.md` - ECS guidelines, naming conventions, testing requirements
- `docs/general/DEV_PITFALLS.md` - **Phase 6 touchscreen pitfalls section**
- `docs/general/STYLE_GUIDE.md` - Code formatting

**Phase 6 Documentation:**
- `docs/input_manager/input-manager-tasks.md` - **Start with Task 6.13 (performance)**
- `docs/input_manager/general/phase-6-touchscreen-architecture.md` - Comprehensive patterns, critical findings
- `docs/input_manager/input-manager-plan.md` - Phase 6 timeline

## Next Steps (Phase 6)

**Continue Here:**
1. **Task 6.13:** Automated performance test (4 sub-tasks)
   - Baseline: < 16670µs average, < 20000µs max (60 FPS)
   - Stress test + memory allocation tracking

**Task 6.7.1 also pending:** Document `--emulate-mobile` in DEV_PITFALLS.md

**See `input-manager-tasks.md` for complete task breakdown and TDD patterns**

## Phase 6 Key Decisions

**Implementation Patterns:**
- **Vector2 Storage:** Hybrid - Vector2 in memory (Redux), {x,y} dict on disk (JSON)
- **Opacity Fade:** Tween (GPU-accelerated), not _process() loop
- **Device Check:** S_TouchscreenSystem validates device type before processing
- **Button Set:** 4 buttons (Jump, Sprint, Interact, Pause)
- **Visibility:** HIDDEN during scene transitions + pause menu
- **Emergency Rollback:** debug.disable_touchscreen flag for production hotfix

**Critical Implementation Notes:**
- **Serialization (Task 6.12):** Complete. `_sanitize_loaded_settings()` merges defaults for missing/partial touchscreen_settings and normalizes button keys (String on save → StringName on load).

**Testing:**
- Physical mobile device for primary verification; desktop `--emulate-mobile` as fallback
- Performance target: < 16.67ms frame time (60 FPS)
- Migration tests: `tests/unit/integration/test_touchscreen_settings_migration.gd`, `tests/unit/input_manager/test_u_input_serialization.gd`

## Style & Organization

Follow project-wide conventions:
- **Style Guide**: `docs/general/STYLE_GUIDE.md` - Code formatting and naming
- **Scene Organization**: `docs/general/SCENE_ORGANIZATION_GUIDE.md` - Scene file structure
- **Cleanup Project**: `docs/general/cleanup/style-scene-cleanup-continuation-prompt.md` - Architectural improvements

## Links

- Plan: [input-manager-plan.md](./input-manager-plan.md)
- Tasks: [input-manager-tasks.md](./input-manager-tasks.md)
- PRD: [input-manager-prd.md](./input-manager-prd.md)

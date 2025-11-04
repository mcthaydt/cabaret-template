# ECS Debugger Plugin PRD

**Owner**: Development Team | **Updated**: 2025-10-23

## Summary

- **Vision**: A real-time debugging tool that provides instant visibility into ECS query performance, event history, and system execution order, enabling developers to identify bottlenecks and debug gameplay issues in seconds instead of hours
- **Problem**: Developers have zero runtime visibility into ECS internals—query performance is a black box, events fire invisibly, system execution order is unclear, and debugging requires manual print statements scattered across dozens of files
- **Success**: Developers can identify slow queries in <30 seconds via cache hit rate metrics, trace event chains through filtered history, temporarily disable systems for isolated testing, and export event logs for bug reproduction
- **Timeline**: 2 weeks for complete implementation across 8 phases (TDD-first data layer, 3 specialized tabs, editor integration, testing, documentation)
- **Progress** (current): Not started—planning complete, architecture documented, implementation plan reviewed and approved. **2025-10-23 status**: First build attempt failed and was rolled back; implementation work must restart from scratch.
- **Decision (2025-10-23)**: Project de-scoped after rollback; this PRD is retained for reference if the effort is revived.

## Requirements

### Users

- **Primary**: Game developers building and debugging the character controller with ECS architecture
- **Pain Points**:
  - **Query Performance Mystery**: "Why is my game stuttering?" → No way to see which queries are slow or thrashing the cache
  - **Event Debugging Blindness**: "Did entity_jumped fire? What was the payload?" → No event history, requires manual print debugging
  - **System Ordering Confusion**: "Is S_InputSystem running before S_MovementSystem?" → Order unclear, timing bugs hard to trace
  - **Runtime State Opacity**: "What components are registered right now?" → No visibility into manager state
  - **Manual Logging Hell**: Adding print statements to 10+ files, restarting editor, searching console output for relevant lines
  - **Bug Reproduction Difficulty**: "It crashed after these events..." → No event export, can't share reproduction steps

### Stories

#### Epic 1: Query Metrics Visualization

**Story**: As a developer, I want to see real-time query metrics so that I can identify performance bottlenecks and optimize slow queries

**Acceptance Criteria**:
- Given M_ECSManager tracking query metrics, when I open the Queries tab, then I see all active queries grouped by complexity (Simple/Moderate/Complex)
- Given a query with poor cache performance, when I view the Tree, then I see cache hit rate % prominently displayed (e.g., "5% hit rate" in red)
- Given switchable column views, when I click "Show Detailed", then I see all 9 metrics (ID, Required, Optional, Calls, Hits, Hit %, Duration, Result Count, Timestamp)
- Given essential mode active, when viewing metrics, then I see only critical columns (ID, Calls, Hit %, Duration) for quick scanning
- Given queries updating at 60fps, when auto-refresh fires (0.5s), then Tree updates without resetting scroll position or expand/collapse state
- Given complex queries (4+ required components), when I expand that group, then I see queries sorted by last execution time (most recent first)

**Priority**: P0 (Must Have - Core Debugging Feature)

**Example Use Case**:
```gdscript
# Developer sees this in Queries tab:

Moderate (2-3) ▼
  └─ req:C_Movement,C_Input|opt: [3600 calls, 97% hit rate, 0.4ms] ← HEALTHY
Complex (4+) ▼
  └─ req:C_Movement,C_Input,C_Jump,C_Floating|opt: [3600 calls, 5% hit rate, 2.5ms] ← PROBLEM!

# Developer realizes: Query called too frequently, cache thrashing
# Fix: Move query outside loop, cache result
# After fix:
  └─ req:C_Movement,C_Input,C_Jump,C_Floating|opt: [60 calls, 95% hit rate, 0.5ms] ← FIXED!
```

---

#### Epic 2: Event History Inspection

**Story**: As a developer, I want to inspect event history with filtering and payload viewing so that I can trace gameplay event chains and debug systemic interactions

**Acceptance Criteria**:
- Given U_ECSEventBus tracking event history (1000 events), when I open the Events tab, then I see chronological list of events with timestamps ("[14:32:15.234] entity_jumped")
- Given substring filter, when I type "jump", then ItemList shows only events containing "jump" (case-insensitive match on event name)
- Given filtered events, when I select an event, then TextEdit displays pretty-printed payload JSON with 2-space indent
- Given event payload with complex data, when displayed, then I can copy specific values for debugging (e.g., velocity, position)
- Given "Export to Clipboard" button, when clicked, then filtered events serialize to JSON and copy to clipboard with confirmation ("Copied!")
- Given "Clear History" button, when clicked, then ConfirmationDialog appears ("Clear all event history? This cannot be undone.")
- Given event history at limit (1000 events), when viewing count label, then I see "Showing 1000 events (oldest truncated)" to indicate rolling buffer behavior

**Priority**: P0 (Must Have - Essential for Event Debugging)

**Example Use Case**:
```gdscript
# Developer debugging: "Jump particles not spawning"

# Opens Events tab, types "jump" in filter
# Sees:
[14:32:15.234] entity_jumped
[14:32:16.102] entity_jumped
[14:32:17.456] entity_jumped

# Clicks first event, sees payload:
{
  "entity": <CharacterBody3D#12345>,
  "velocity": Vector3(0, 5.2, 0),
  "position": Vector3(10, 2, 5),
  "jump_time": 1634567890.123
}

# Clicks "Export to Clipboard", pastes into bug report
# Team can now reproduce exact event sequence
```

---

#### Epic 3: System Execution Control

**Story**: As a developer, I want to view system execution order and temporarily disable systems so that I can isolate bugs and test systems independently

**Acceptance Criteria**:
- Given M_ECSManager with registered systems, when I open System Order tab, then I see Tree with systems sorted by execution_priority (0 → 1000)
- Given system in Tree, when I uncheck the Enabled checkbox, then system.set_debug_disabled(true) is called and system stops ticking
- Given disabled system, when viewing in Tree, then row shows grayed text + `"(disabled) "` prefix to indicate inactive state
- Given system toggle change, when I check/uncheck, then state persists to ProjectSettings (`ecs_debugger/disabled_systems`) and survives editor restart
- Given persisted disabled state, when editor reopens with scene, then disabled systems load from ProjectSettings and remain disabled
- Given system execution, when M_ECSManager._physics_process() runs, then disabled systems are skipped (no process_tick() call)
- Given system script path as identifier, when persisted system no longer exists, then plugin skips gracefully without error

**Priority**: P0 (Must Have - Critical for Isolation Testing)

**Example Use Case**:
```gdscript
# Developer debugging: "Movement works but player falls through floor"

# Opens System Order tab, sees:
S_InputSystem       Priority: 0    [✓] Enabled
S_JumpSystem        Priority: 40   [✓] Enabled
S_MovementSystem    Priority: 50   [✓] Enabled
S_GravitySystem     Priority: 60   [✓] Enabled
S_FloatingSystem    Priority: 70   [✓] Enabled

# Disables S_GravitySystem to test in isolation
# Tree updates:
(disabled) S_GravitySystem     Priority: 60   [✗] Enabled

# Runs scene → Player moves without falling
# Confirms: Movement logic works, gravity system is the issue
# Re-enables S_GravitySystem, fixes bug, re-tests
```

---

#### Epic 4: Auto-Refresh & Manual Control

**Story**: As a developer, I want configurable auto-refresh with manual override so that I can balance real-time updates against performance

**Acceptance Criteria**:
- Given refresh rate slider (0.1s to 5.0s), when I adjust slider, then Timer.wait_time updates and label shows current rate ("0.5s")
- Given default refresh rate of 0.5s, when plugin loads, then timer starts automatically and all tabs refresh every 0.5s
- Given "Refresh Now" button, when clicked, then all tabs refresh immediately regardless of timer state
- Given auto-refresh active, when timer fires, then queries_tab.refresh(manager), events_tab.refresh(), system_order_tab.refresh(manager) are called
- Given no M_ECSManager in scene, when timer fires, then panel shows "No ECS Manager Found" + "Retry" button instead of tabs
- Given "Retry" button visible, when clicked, then find_manager() re-runs and tabs appear if manager now exists
- Given tab refresh, when updating Tree/ItemList widgets, then scroll position and expand/collapse state are preserved

**Priority**: P0 (Must Have - Core UX Feature)

**Example Use Case**:
```gdscript
# Developer profiling query performance:

# Sets refresh rate to 0.1s for near-real-time updates
# Watches cache hit rate drop as query frequency increases
# Identifies exact frame where thrashing begins

# Developer reviewing event log:

# Sets refresh rate to 5.0s to reduce visual noise
# Manually clicks "Refresh Now" when ready to update
# Exports event history before clearing for next test run
```

---

#### Epic 5: Editor Integration & Runtime Capability

**Story**: As a developer, I want the debugger as an editor bottom panel with optional runtime usage so that it's always available during development and can be used for live debugging

**Acceptance Criteria**:
- Given plugin enabled in Project Settings, when editor starts, then "ECS Debug" tab appears in bottom panel dock alongside Output, Debugger, GUT
- Given plugin disabled, when _exit_tree() runs, then panel is removed from dock and all references are cleaned up
- Given plugin as EditorPlugin, when used in editor, then panel works automatically without manual instantiation
- Given runtime debugging need, when I manually instantiate T_ECSDebuggerPanel in game UI, then panel works identically to editor version (finds manager, refreshes tabs)
- Given plugin.cfg manifest, when I open Project Settings → Plugins, then "ECS Debugger" appears with description "Runtime debugger for ECS architecture. Shows query metrics, event history, and system execution order."
- Given plugin enabled, when I open scene with M_ECSManager, then tabs populate immediately with current state
- Given multiple M_ECSManagers in scene (edge case), when plugin runs, then push_warning() fires, first manager is used, others ignored

**Priority**: P0 (Must Have - Deployment Requirement)

**Example Use Case**:
```gdscript
# Editor workflow:
# 1. Developer enables plugin in Project Settings → Plugins
# 2. "ECS Debug" tab appears in bottom panel
# 3. Developer opens player scene, tabs populate automatically
# 4. Developer debugs, fixes issues, disables plugin when done

# Runtime workflow (advanced):
# In DebugOverlay.gd:
func _ready():
    if OS.is_debug_build():
        var debug_panel = preload("res://addons/ecs_debugger/t_ecs_debugger_panel.gd").new()
        add_child(debug_panel)
        # Panel auto-finds manager, refreshes every 0.5s
        # Player can press F3 to toggle visibility
```

---

### Non-Functional Requirements

#### Performance

- **Refresh overhead**: <0.1ms per refresh cycle (queries + events + systems)
- **Memory footprint**: <500KB additional RAM for panel UI + cached metrics
- **Frame impact**: Zero when panel hidden, minimal (<0.05ms) when visible
- **Scalability**: Handle 1000 events + 50 queries + 20 systems without lag

#### Usability

- **Time to value**: <5 seconds from opening panel to seeing first metrics
- **Discoverability**: Plugin visible in Project Settings → Plugins with clear description
- **Visual clarity**: Grayed text + "(disabled)" prefix for disabled systems, color-coded hit rates (red <50%, yellow 50-80%, green >80%)
- **Error recovery**: Graceful handling of missing manager, no crashes on invalid data

#### Maintainability

- **Test coverage**: 90%+ for data layer (U_ECSDebugDataSource), basic instantiation for UI
- **Code organization**: Clear separation between data (U_ECSDebugDataSource) and UI (T_* tabs)
- **Documentation**: Architecture doc, PRD, ELI5 guide, usage guide
- **Conventions**: Follow codebase patterns (U_ prefix, static methods, push_warning(), class_name)

#### Compatibility

- **Godot version**: 4.x (uses EditorPlugin, DisplayServer, ProjectSettings APIs)
- **ECS version**: Compatible with current ECS implementation (M_ECSManager, U_ECSEventBus, ECSSystem)
- **GUT integration**: Tests use existing GUT framework (`-gselect` pattern)
- **No breaking changes**: Plugin is additive, doesn't modify existing ECS code

---

## Technical Approach

### Architecture

**Plugin Structure**:
```
addons/ecs_debugger/
├── plugin.cfg                                # Godot plugin manifest
├── plugin.gd                                 # P_ECSDebuggerPlugin (EditorPlugin)
├── u_ecs_debug_data_source.gd               # Static data formatting utilities
├── t_ecs_debugger_panel.gd                  # Main panel container
└── tabs/
    ├── t_ecs_debugger_queries_tab.gd        # Query metrics Tree
    ├── t_ecs_debugger_events_tab.gd         # Event history ItemList + TextEdit
    └── t_ecs_debugger_system_order_tab.gd   # System priority Tree + toggles
```

**Data Flow**:
1. Plugin enabled → Panel added to bottom dock
2. Timer fires (0.5s) → find_manager()
3. If manager found → refresh all tabs
4. Each tab queries ECS state via existing APIs
5. U_ECSDebugDataSource formats raw data
6. Tabs populate UI widgets (Tree, ItemList, TextEdit)

**Integration Points**:
- `M_ECSManager.get_query_metrics()` → Query performance data
- `M_ECSManager.get_systems()` → System list with priorities
- `U_ECSEventBus.get_event_history()` → Event chronology
- `U_ECSEventBus.clear_history()` → Event log clearing
- `ECSSystem.set_debug_disabled()` → System enable/disable
- `ProjectSettings` → Persist disabled systems

### Runtime Behavior Requirements

**Manager Discovery**:
- The debugger **requires a running scene** (F5/F6) to function
- `M_ECSManager` only adds itself to the `"ecs_manager"` group during `_ready()`
- In the editor (not playing), `find_manager()` returns `null`
- UI shows: "No ECS Manager found. Run the scene (F5/F6) to see data." + Refresh button

**Editor vs Runtime**:

| State | Manager Discovery | Debugger Functionality |
|-------|------------------|----------------------|
| Scene Running (F5/F6) | `find_manager()` succeeds | Full functionality |
| Editor (Not Playing) | `find_manager()` returns null | Error message shown |
| No Manager in Scene | `find_manager()` returns null | Error message shown |

**Implication**: This is intentional and aligns with the core requirement for runtime capability.

### ProjectSettings Persistence Trade-offs

**Key**: `ecs_debugger/disabled_systems` (PackedStringArray of script paths)

**Behavior**:
- Saved to `project.godot` file
- **Committed to version control** by default
- Shared across all team members

**Trade-offs**:

| Advantage | Disadvantage |
|-----------|-------------|
| Persistent across editor sessions | Can accidentally commit debug state |
| Works in runtime builds/exports | All developers inherit disabled systems |
| No external configuration needed | Requires manual re-enable after debugging |

**Best Practice**:
- Use for intentional long-term system disables (e.g., deprecated features)
- **Do NOT use** for temporary debugging (manually re-enable after testing)
- Document disabled systems in commit messages if intentional
- Consider adding `ecs_debugger/disabled_systems` to `.gitignore` if team prefers per-developer state

**Alternative Considered**: EditorSettings (per-developer, not in VCS)
- **Rejected**: Runtime capability is a core requirement; EditorSettings don't persist to builds

### Implementation Phases

**Phase 1: Data Layer (TDD-First)**
- U_ECSDebugDataSource with static methods
- Full test coverage for serialization, formatting, grouping
- Zero UI dependencies

**Phase 2: Main Panel**
- T_ECSDebuggerPanel container
- Manager discovery logic
- Auto-refresh timer + rate slider
- "No Manager Found" state

**Phase 3-5: Specialized Tabs**
- Queries: Tree with hierarchical grouping + column toggle
- Events: Filter + ItemList + payload display + export/clear
- System Order: Priority Tree + checkboxes + persistence

**Phase 6: Editor Integration**
- P_ECSDebuggerPlugin with _enter_tree / _exit_tree
- plugin.cfg manifest
- Manual testing checklist

**Phase 7: Testing**
- ~18 unit tests (data layer + basic UI instantiation)
- Integration verification (no performance regression)
- Manual smoke tests (all tabs, edge cases)

**Phase 8: Documentation**
- Update ecs_refactor_plan.md (mark Step 2.1 complete)
- Add debugger section to ecs_architecture.md
- Create ecs_debugger_usage.md with tab-by-tab guide

---

## Success Metrics

### Developer Productivity

- **Before Plugin**: 30+ minutes to identify slow query (manual print debugging)
- **After Plugin**: <30 seconds (sort by hit rate, find low %)
- **Before Plugin**: 1+ hour to trace event chain (print statements across files)
- **After Plugin**: <2 minutes (filter events, inspect payloads)
- **Before Plugin**: Unknown system execution order (guesswork + trial/error)
- **After Plugin**: <10 seconds (open System Order tab, see priority list)

### Performance Optimization

- **Cache Hit Rate Visibility**: Identify queries with <80% hit rate as optimization targets
- **Query Frequency Analysis**: Detect over-querying (thousands of calls per second)
- **Execution Time Tracking**: Find queries >1ms for refactoring

### Bug Reproduction

- **Event Export**: Share exact event sequence via JSON clipboard export
- **System Isolation**: Disable systems one-by-one to narrow bug scope
- **State Inspection**: View registered component counts, system priorities at crash time

---

## Constraints

### Scope Limitations

**In Scope**:
- Single M_ECSManager support (warn if multiple)
- Editor-only via EditorPlugin (runtime requires manual instantiation)
- Session-only UI state (column toggles, tree expansion)
- Hybrid test coverage (full data, basic UI, skip interactions)

**Out of Scope** (Future Enhancements):
- Multiple manager dropdown selector
- Historical performance graphs (call count over time)
- Per-tab refresh intervals
- Event filtering by payload content (currently name-only)
- System performance profiling (individual tick times)
- Query result preview (entity list for each query)

### Technical Constraints

- **Godot 4.x only**: Uses EditorPlugin, DisplayServer APIs not in 3.x
- **GDScript only**: No C# support (ECS is pure GDScript)
- **Pure code UI**: No .tscn files (programmatic widget creation)
- **Read-only**: Plugin never modifies ECS logic (except set_debug_disabled toggles)

### Resource Constraints

- **Development time**: 2 weeks (80 hours)
- **Team size**: 1 developer
- **Testing resources**: GUT framework + manual testing
- **Documentation**: Architecture, PRD, ELI5, usage guide

---

## Open Questions

### Resolved

**Q: Should plugin work at runtime or editor-only?**
**A**: Editor-only via EditorPlugin (automatic), runtime via manual instantiation (opt-in).

**Q: Where should U_ECSDebugDataSource live?**
**A**: `addons/ecs_debugger/` (plugin-specific, not `scripts/utils/`).

**Q: Should system toggles persist between sessions?**
**A**: Yes, via ProjectSettings (useful for debugging across sessions).

**Q: What happens with multiple M_ECSManagers?**
**A**: Warn via push_warning(), use first found, document limitation.

**Q: Should refresh rate be configurable?**
**A**: Yes, slider from 0.1s to 5.0s (default 0.5s).

### Future Considerations

**Q: Should we add performance graphs?**
**A**: Not in v1.0. Evaluate after initial release based on user feedback.

**Q: Should each tab have independent refresh rates?**
**A**: Not in v1.0. Global rate keeps implementation simple.

**Q: Should we support event filtering by payload?**
**A**: Not in v1.0. Name-only filtering covers 80% of use cases.

---

## Rollout Plan

### Phase 1: Internal Development (Week 1)
- Implement Phases 1-6 (data layer → tabs → integration)
- Run TDD test suite (~18 tests)
- Internal dogfooding with team

### Phase 2: Testing & Refinement (Week 2)
- Phase 7: Complete test suite, integration verification
- Manual testing: all tabs, edge cases, performance
- Phase 8: Documentation (architecture, usage guide)
- Bug fixes from dogfooding

### Phase 3: Release (End of Week 2)
- Mark Story 2.1 complete in ecs_refactor_plan.md
- Update ecs_architecture.md with debugger section
- Announce to team via changelog
- Monitor for issues, gather feedback

### Phase 4: Post-Release Support
- Address bugs within 48 hours
- Evaluate enhancement requests (graphs, multi-manager, etc.)
- Consider backport to Godot 3.x if demand exists

---

## Dependencies

### Existing ECS APIs (Already Implemented)

- ✅ `M_ECSManager.get_query_metrics()` (scripts/managers/m_ecs_manager.gd:109)
- ✅ `ECSSystem.set_debug_disabled()` (scripts/ecs/ecs_system.gd:50)
- ✅ `ECSSystem.is_debug_disabled()` (scripts/ecs/ecs_system.gd:53)
- ✅ `U_ECSEventBus.get_event_history()` (scripts/ecs/u_ecs_event_bus.gd:81)
- ✅ `U_ECSEventBus.clear_history()` (scripts/ecs/u_ecs_event_bus.gd:73)
- ✅ `M_ECSManager.get_systems()` (scripts/managers/m_ecs_manager.gd:86)

### Testing Infrastructure

- ✅ GUT testing framework (addons/gut/)
- ✅ Existing test pattern (`-gselect=test_name -gexit`)
- ✅ BaseTest helper class for test setup

### Godot APIs

- ✅ EditorPlugin (add_control_to_bottom_panel)
- ✅ DisplayServer (clipboard_set)
- ✅ ProjectSettings (get_setting, set_setting, save)
- ✅ Tree, ItemList, TextEdit widgets
- ✅ Timer, HSlider, ConfirmationDialog

---

## Risks & Mitigation

### Risk: Performance Impact

**Description**: Plugin refresh cycle could slow editor/game
**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Configurable refresh rate (users can slow down to 5.0s)
- Read-only operations (no writes to ECS state)
- Minimal data processing (static formatting functions)
- Performance testing during Phase 7

### Risk: UI Complexity

**Description**: Pure code UI could be hard to maintain/extend
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Clear UI hierarchy comments in code
- Consistent widget naming (_tree, _event_list, _filter_input)
- Separate data formatting from UI population
- Comprehensive architecture documentation

### Risk: Test Coverage Gaps

**Description**: Skipping detailed UI interaction tests could miss bugs
**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- Thorough manual testing checklist (Phase 6.3)
- Dogfooding during development
- Quick bug fix SLA (48 hours post-release)
- Consider adding UI tests in future if needed

### Risk: Breaking Changes to ECS APIs

**Description**: Future ECS refactors could break plugin
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Plugin uses stable, public APIs only
- Document API dependencies clearly
- Include plugin in ECS test suite (integration verification)
- Version plugin alongside ECS updates

---

## Future Enhancements (Post-v1.0)

### Enhancement 1: Performance Graphs

**Description**: Line graphs showing query call counts, hit rates over time
**Use Case**: Identify performance regressions during gameplay sessions
**Effort**: Medium (2-3 days)
**Priority**: P2 (Nice to Have)

### Enhancement 2: Multiple Manager Support

**Description**: Dropdown to switch between M_ECSManager instances
**Use Case**: Projects with separate managers for different entity groups
**Effort**: Small (1 day)
**Priority**: P3 (Low - rare use case)

### Enhancement 3: Query Result Preview

**Description**: Show entity list for each query (expand to see which entities matched)
**Use Case**: Verify query logic, understand entity composition
**Effort**: Medium (2 days)
**Priority**: P2 (Nice to Have)

### Enhancement 4: System Performance Profiling

**Description**: Track individual system tick times, identify slow systems
**Use Case**: Optimize system logic, balance execution load
**Effort**: Large (4-5 days)
**Priority**: P2 (Nice to Have)

### Enhancement 5: Event Payload Filtering

**Description**: Filter events by payload content (e.g., "velocity.y > 5")
**Use Case**: Advanced debugging of specific event conditions
**Effort**: Large (5+ days - requires expression parser)
**Priority**: P3 (Low - complex, low ROI)

---

## Appendix: Example Workflows

### Workflow 1: Optimizing Query Performance

```
[Developer notices frame drops]
    ↓
[Opens ECS Debug → Queries tab]
    ↓
[Clicks "Show Detailed" to see all columns]
    ↓
[Expands "Complex (4+)" group]
    ↓
[Sorts by Hit Rate % (mentally - no UI sorting yet)]
    ↓
[Identifies query with 5% hit rate]
req:C_Movement,C_Input,C_Jump,C_Floating|opt:
  - Total Calls: 3600
  - Cache Hits: 180
  - Hit Rate: 5% ← PROBLEM!
  - Last Duration: 2.5ms
    ↓
[Reviews calling code, finds query in tight loop]
    ↓
[Refactors to cache query result]
    ↓
[Next refresh shows improvement]
  - Cache Hits: 3500
  - Hit Rate: 97% ← FIXED!
  - Last Duration: 0.4ms
```

### Workflow 2: Tracing Event Chain

```
[Bug report: "Particles spawn twice on jump"]
    ↓
[Opens ECS Debug → Events tab]
    ↓
[Types "particle" in filter]
    ↓
[Sees two events per jump]
[14:32:15.234] particle_spawn_requested
[14:32:15.235] particle_spawn_requested ← DUPLICATE!
[14:32:15.456] entity_jumped
    ↓
[Selects first event, inspects payload]
{
  "entity": <CharacterBody3D#12345>,
  "position": Vector3(10, 2, 5)
}
    ↓
[Realizes: Two systems subscribed to same event]
    ↓
[Checks S_ParticleSystem, finds duplicate subscribe() call]
    ↓
[Removes duplicate, re-tests]
    ↓
[Event tab now shows single spawn event]
```

### Workflow 3: Isolating System Bug

```
[Bug: "Player moves but camera doesn't follow"]
    ↓
[Opens ECS Debug → System Order tab]
    ↓
[Disables all systems except S_MovementSystem]
    ↓
[Runs scene → Movement works]
    ↓
[Re-enables S_CameraSystem]
    ↓
[Runs scene → Camera still broken]
    ↓
[Conclusion: Camera system has bug, not movement]
    ↓
[Reviews S_CameraSystem code, finds missing camera reference]
    ↓
[Fixes bug, re-enables all systems]
```

---

## Summary

The ECS Debugger Plugin transforms ECS debugging from **hours of print-statement archaeology** to **seconds of visual inspection**. By providing real-time visibility into query performance, event history, and system execution, it empowers developers to:

- **Optimize faster**: Identify slow queries via cache hit rate metrics
- **Debug smarter**: Trace event chains through filtered history
- **Test confidently**: Isolate systems with persistent toggles
- **Reproduce reliably**: Export event logs for bug reports

**Next Steps**:
1. Review and approve this PRD
2. Begin Phase 1 implementation (data layer TDD)
3. Dogfood internally during development
4. Release at end of Week 2

For technical details, see `ecs_plugin_tool_architecture.md`.
For beginner guide, see `ecs_plugin_tool_ELI5.md`.

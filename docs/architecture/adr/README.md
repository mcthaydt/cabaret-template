# Architecture Decision Records

ADRs explain why durable architectural choices were made. Runtime contracts live in the relevant `docs/systems/**` files.

| ADR | Status | Summary |
|---|---|---|
| [0001-channel-taxonomy.md](0001-channel-taxonomy.md) | Accepted | Publisher-based communication channel rule: ECS publishes ECS events, managers dispatch Redux, manager/UI uses signals. |
| [0002-redux-state-management.md](0002-redux-state-management.md) | Accepted | Redux-style state store is the central state mutation path. |
| [0003-ecs-node-based.md](0003-ecs-node-based.md) | Accepted | ECS is implemented with Godot nodes for authoring and scene-tree integration. |
| [0004-event-bus.md](0004-event-bus.md) | Accepted | Separate ECS and state event buses keep domains explicit. |
| [0005-service-locator.md](0005-service-locator.md) | Accepted, amended | Managers register explicitly through ServiceLocator; tests isolate scopes; no manager autoloads. |
| [0006-ai-architecture-utility-bt-with-scoped-planning.md](0006-ai-architecture-utility-bt-with-scoped-planning.md) | Accepted | AI uses utility-scored behavior trees with scoped optional planning. |
| [0007-bt-framework-scope-general-vs-ai-specific.md](0007-bt-framework-scope-general-vs-ai-specific.md) | Accepted | General BT resources stay separate from AI-specific leaves/scorers/planners. |
| [0008-debug-perf-utility-extraction.md](0008-debug-perf-utility-extraction.md) | Accepted | Debug/perf code routes through shared utilities; bare manager/system prints are forbidden. |
| [0009-template-vs-demo-separation.md](0009-template-vs-demo-separation.md) | Accepted | Template-owned code/content separates from demo examples through core/demo ownership. |
| [0010-base-scene-and-demo-entry-split.md](0010-base-scene-and-demo-entry-split.md) | Accepted | `tmpl_base_scene.tscn` is the canonical base; demo entry content stays separate. |


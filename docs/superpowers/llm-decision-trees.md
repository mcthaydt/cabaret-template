# LLM Decision Trees

Quick reference for common "which pattern do I use?" questions.

## Communication Channel Selection

See `docs/architecture/adr/0001-channel-taxonomy.md#decision-rules-for-llms`

## When to Use Redux vs Local State

```
Need to store state X?
├─ Accessed by multiple scenes?
│  └─ Redux (M_StateStore)
│
├─ Persists across scene transitions?
│  └─ Redux (M_StateStore)
│
├─ Debug overlay / dev tools need to inspect it?
│  └─ Redux (M_StateStore)
│
├─ UI needs to react to changes?
│  └─ Redux (M_StateStore)
│
└─ Scene-local, temporary, or performance-critical?
   └─ Local state (component variable)
```

## When to Use ECS vs Scene Nodes

```
Need gameplay logic X?
├─ Runs every frame on many entities?
│  └─ ECS System
│
├─ Data queried/modified by multiple systems?
│  └─ ECS Component
│
├─ Single-entity, scene-specific behavior?
│  └─ Scene node script (not ECS)
│
└─ Visual/audio/particle effect?
   └─ Scene node + Feedback System
```

## Builder Pattern Selection

```
Need to create X programmatically?
├─ Pure data transformation, no state?
│  └─ Static builder (U_FooBuilder.create())
│
├─ Fluent API with optional fields?
│  └─ Declarative builder (.with_x().with_y().build())
│
└─ Procedural orchestration, multiple steps?
   └─ Helper (U_FooHelper.generate()) - NOT a builder
```

# Add <Feature>

**Status**: Active | Proposed | Deprecated

## When To Use This Recipe

Use this recipe when adding:

- <scenario 1>
- <scenario 2>

This recipe does **not** cover:

- <scenario A> (see `other.md`)

## Governing ADR(s)

- [ADR 00XX: <Title>](../adr/00XX-<slug>.md)

## Canonical Example

- <real file path in the repo, e.g. scripts/core/... or resources/demo/...>
- <integration test path, e.g. tests/unit/...>

## Vocabulary (optional)

| Term | Meaning |
|------|---------|
| `<ClassName>` | <role in this subsystem> |

## Recipe

### <Task 1>

1. <step>
2. <step>
3. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/<relevant_test>.gd` and verify red-then-green.
4. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`.

### <Task 2>

<!-- Repeat as needed -->

## Anti-patterns

- **<pattern name>**: <description of what not to do and why>.

## Out Of Scope

- <topic>: see `<other>.md`

## References

- [<System Overview>](../../systems/<system>/<system>-overview.md)
- [ADR 00XX: <Title>](../adr/00XX-<slug>.md)

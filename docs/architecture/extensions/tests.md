# Add Test / Style Guard

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new unit test file
- A new integration test file
- A new style enforcement rule

This recipe does **not** cover:

- Extension recipe authoring (see `TEMPLATE.md` in this directory)
- Doc authoring

## Governing ADR(s)

- Style guide: `docs/guides/STYLE_GUIDE.md`

## Canonical Example

- Unit test base: `tests/base_test.gd` (`BaseTest` extends `GutTest`)
- Unit test: `tests/unit/state/test_audio_reducer.gd`
- Integration test: `tests/integration/audio/test_audio_integration.gd`
- Style enforcement: `tests/unit/style/test_style_enforcement.gd`
- Asset prefixes: `tests/unit/style/test_asset_prefixes.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `BaseTest` | Extends `GutTest`. `before_each()` pushes ServiceLocator scope + clears StateHandoff. `after_each()` pops scope. Provides `autofree()`, `add_child_autofree()`. |
| `GutTest` | GUT framework base. Use directly for file-scanning style tests (no ServiceLocator needed). |
| `test_style_enforcement.gd` | Master style guard (~86 tests). File-scanning, prefix conventions, architecture rails, LOC caps. Extends `GutTest` directly. |
| `SCRIPT_PREFIX_RULES` | Dictionary mapping 50+ directories to allowed filename prefixes. |

Test location mirrors source: `tests/unit/{category}/`, `tests/integration/{system}/`. File naming: `test_{class_name_snake}.gd`. Method naming: `test_{behavior}()`.

## Recipe

### Adding a new unit test

1. Create `tests/unit/{category}/test_{class_name_snake}.gd`. Extend `BaseTest` (gets ServiceLocator scope isolation + autofree).
2. Override `before_each()`/`after_each()` only if additional setup needed; call `super`.
3. Use `add_child_autofree()` for tree-dependent nodes, `autofree()` for non-tree nodes.
4. Write methods as `func test_{behavior}() -> void:`.
5. Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/{category}/test_{class_name_snake}.gd`.

### Adding a new integration test

1. Create `tests/integration/{system}/test_{name}.gd`. Extend `BaseTest`.
2. Create real `M_StateStore` with persistence disabled. Register services.
3. Use `await get_tree().process_frame` after adding nodes.
4. Run: `tools/run_gut_suite.sh -gtest=res://tests/integration/{system}/test_{name}.gd`.

### Adding a new style guard

1. Add test method to `tests/unit/style/test_style_enforcement.gd` (project-wide rule) or create new file under `tests/unit/style/` (distinct domain).
2. Extend `GutTest` directly (not `BaseTest`). Style tests scan files and don't need ServiceLocator.
3. Use built-in helpers: `_collect_gd_literal_occurrences()`, `_collect_gd_filename_substring_violations()`, `_collect_gd_file_line_limit_violations()`, `_collect_gd_forbidden_token_violations()`, `_check_directory_prefixes()`, `_collect_bare_print_calls()`.
4. Provide allowlists for exceptions.
5. Update `STYLE_GUIDE.md` and `SCRIPT_PREFIX_RULES` if adding new prefix or directory rules.
6. Assert with messages referencing the style guide: `assert_eq(violations.size(), 0, "Explanation. See STYLE_GUIDE.md for ...")`.
7. Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`.

## Anti-patterns

- **Style tests extending `BaseTest`**: Style tests don't need ServiceLocator scope isolation. Use `GutTest` directly.
- **Forgetting `add_child_autofree()` for tree-dependent nodes**: Nodes need tree attachment for `_ready()`.
- **Skipping `await get_tree().process_frame` in integration tests**: Async init may not complete.
- **Hardcoding file paths in style tests**: Use directory-scanning helpers.
- **Style guards without allowlists**: Legitimate exceptions need escape hatches.

## Out Of Scope

- Extension recipe authoring: see `TEMPLATE.md`
- Doc authoring: governed by CLAUDE.md standing rule

## References

- [Style Guide](../../guides/STYLE_GUIDE.md)
- [Testing Pitfalls](../../guides/pitfalls/TESTING.md)
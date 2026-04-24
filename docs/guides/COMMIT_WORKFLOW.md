# Commit Workflow

Use this workflow for Cleanup V8 and future story-sized changes.

## Before Editing

- Read `docs/guides/STYLE_GUIDE.md`.
- Read the relevant system overview under `docs/systems/**`.
- For known pitfalls, use the focused files under `docs/guides/pitfalls/` and system-specific pitfall sections.
- Keep project planning docs current whenever a story advances.

## TDD Milestones

For implementation milestones:

1. Write or update the test first.
2. Run the targeted test and verify it fails for the expected reason.
3. Implement the minimum change.
4. Re-run the targeted test.
5. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` after file creation, rename, scene structure changes, or naming/resource changes.
6. Run the broader relevant suite before closing a phase or high-risk milestone.
7. Commit a focused, verified state.

## Documentation Updates

After every completed phase:

1. Update the continuation prompt with current status and next task.
2. Update the task checklist with completion notes.
3. Update `AGENTS.md` only as a routing index when new topic docs are added.
4. Update focused system/pitfall docs when new runtime contracts or pitfalls are discovered.
5. Commit documentation updates separately from implementation where practical.

## Commit Discipline

- Commit at the end of each completed story or logical test-green milestone.
- Keep commits focused by destination or behavior.
- Mark test-first commits with `(RED)` and passing implementation commits with `(GREEN)` when following explicit TDD sequences.
- Use `(DOCS)` for documentation-only migration commits.
- Do not skip required commits for moved-forward features, refactors, or documentation milestones.

## Verification Commands

- Full suite: `tools/run_gut_suite.sh`
- Style guard: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
- Targeted suite: `tools/run_gut_suite.sh -gtest=res://path/to/test.gd`


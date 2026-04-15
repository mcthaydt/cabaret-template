# 05 — Beat Sheet (optional)

Use this doc when your game is **scripted / linear** (horror shorts, interactive comics, narrative demos). Skip it for puzzle-driven or open-ended games — the golden path in doc 01 is enough there.

The beat sheet is the document an implementing AI walks top-to-bottom. Every meaningful moment in the game is one row. Keep rows small and concrete; if a row needs a paragraph, it's two rows.

## How to fill it out

- One row per scripted moment (comic panel, cutscene beat, trigger fire, dialogue line pair).
- Include **connective rows** (walk from A to B, wait for player input) so nothing is implicit.
- Every `flag_id`, `item_id`, `scene_id`, `vcam_id`, `cutscene_id` here must also be defined in docs 02/03/04.
- Aim for 25–50 rows total. Over 60 means you're out of one-shot scope.

## Beat table

```text
| #  | Source ref       | In-game trigger            | What happens (≤12 words)                | Camera/vcam         | Audio                  | Flags set / cleared        | Next-beat gate         |
| -- | ---------------- | -------------------------- | --------------------------------------- | ------------------- | ---------------------- | -------------------------- | ---------------------- |
| 1  | <ref>            | <trigger_id>               | <...>                                   | <vcam_id>           | <sfx/music cue>        | set: <flag>                | <trigger / auto / timer> |
| 2  | <ref>            | <trigger_id>               | <...>                                   | <vcam_id>           | <...>                  | set: <flag>                | <...>                  |
| ...                                                                                                                                                                                    |
```

## Beat ID scheme

Number rows sequentially (`B001`, `B002`, ...). Reference these IDs in the continuation prompt (doc 06) and in commit messages during implementation, so "where we are" is always unambiguous.

## Authoring rules

- No beat gates on an undefined flag. Cross-check against doc 02's flag table.
- Camera/vcam id must correspond to a swap point or rule defined in doc 03.
- Connective beats (walk, wait) still get a row — implementation must know they exist.
- Branching: if a beat has multiple outcomes, split into `B017a` / `B017b` rows and name the fork condition in **Next-beat gate**.
- Rows are immutable once implemented; to change a beat post-merge, add a new row and mark the old one deprecated rather than editing in place — the continuation prompt relies on beat IDs as a stable address.

## Cross-check before submitting

- [ ] Every row's trigger is defined in doc 03 or doc 04
- [ ] Every flag set here appears in doc 02's flag table
- [ ] The rows in sequence reproduce the source (comic / outline / script)
- [ ] Doc 01's golden path is a terse index of these rows — same order, same gates

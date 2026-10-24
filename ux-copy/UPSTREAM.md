# Upstream copy skill

Source: [malinskibeniamin/skills](https://github.com/malinskibeniamin/skills/tree/2c6c9dd7e258358bfc63ca212ddf7d79971cafcf/ux-copy),
main at `2c6c9dd7e258358bfc63ca212ddf7d79971cafcf` (2026-10-24).
Latest copy change: `e75f99a34f66322c1a3af5be986df6067655cab5` (2026-10-23),
clarity guidance adapted from Cursor's technical-writing skill.

`.upstream/` preserves all skill files, the shared hook library and optional typed
protocol helper, file modes, symlinks, and the upstream MIT license. `upstream.json`
records each file's SHA-256 and Git mode. Keep source bytes unchanged; host adaptations
live in `SKILL.md` and `scripts/ux-copy-context.sh`. The public reference, glossary,
and eval paths link to this snapshot. No upstream scripts are activated by this import.
The hidden snapshot stays out of recursive skill discovery.

## Refresh

From the harness root, resolve upstream main to an immutable revision and fetch it:

```sh
revision=2c6c9dd7e258358bfc63ca212ddf7d79971cafcf
git fetch --no-tags https://github.com/malinskibeniamin/skills.git "$revision"
git archive "$revision" ux-copy shared/hook-lib.sh shared/hook-protocol.ts LICENSE \
  | tar -x -C ux-copy/.upstream
```

Compare the complete upstream tree to remove obsolete files on later imports. Rebuild
`upstream.json` from `git ls-tree -r "$revision"` for those paths: hash blob bytes
(the link target for symlinks), retain Git modes, and record the repository and revision.
Update the source links above. Review new helpers before including them.

Run `bash evals/run.sh ux-copy`, `bash evals/run.sh setup-ux-copy`, and the full
`bash evals/run.sh`. Compare each snapshot blob and mode with the pinned Git tree;
a repeat archive must leave no diff. Tone cases are packaged, not independently graded.

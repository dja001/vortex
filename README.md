# vortex

Co-write a LaTeX document with Claude Code from vim.

    vortex start path/to/doc.tex

opens a tmux session (private server `tmux -L vortex`):

- top: vim on the document; bottom third: Claude, or a status line when idle
- window 2: `latexmk -pvc`, which opens okular and keeps the PDF current

Write comments as `%CLAUDE <instruction>`, then `:vb` (short for `:VortexBatch`).
Keep reading and editing while Claude works in its own git worktree. When it
runs `vortex submit`, its commit is merged with your latest edits (saved
automatically the next time vim is in normal mode), your branch is
fast-forwarded, and vim reloads with the cursor on the same text. `u` undoes
the merge. On conflicts Claude resolves them, or asks you in the bottom pane
if your edits contradict its own. Alt-Up/Alt-Down move between panes.

Every step is a commit tagged `Vortex-Batch: N` (`vortex log`, `:VortexLog`).
Snapshots commit the tracked files you changed in the document directory
(plus the `files` listed in `.vortex/config`, even if new); untracked files and
anything outside that directory are never committed.

## Files

- `bin/vortex` (linked from `~/mylib/vortex`), `vim/vortex.vim`, `tmux/vortex.conf`
- `context/*.md`: modules joined into Claude's system prompt; the list per
  project is in `.vortex/config`. `coding.md` is read only before code edits.
- per document, `<docdir>/.vortex/`: `config` and `project.md` (yours, can be
  committed), plus ignored local state: `worktree/`, `state/`, `build/`, `tmp/`.

Commands: `start`, `batch`, `check`, `submit`, `abort`, `status`, `log`
(`vortex -h`).

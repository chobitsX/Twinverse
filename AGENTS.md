# Twinverse · AI Coding instructions

Twinverse is developed entirely through an AI Coding workflow. Contributions
using Codex, Claude Code and other coding agents are welcome. Follow the user's
chosen language; Chinese and English contributions are both welcome.

## Start or resume

1. In a maintainer checkout, if `AGENTS.maintainer.md` exists, read it first and
   follow its state/plan recovery rules. Public checkouts are self-contained and
   do not require that optional file or the maintainer's historical journals.
2. Read [CONTRIBUTING.md](CONTRIBUTING.md),
   [AI collaboration](docs/community/AI_COLLABORATION.md) and
   [development commands](docs/community/DEVELOPMENT.md). Read
   [science boundaries](docs/community/SCIENCE.md) or
   [localization rules](docs/LOCALIZATION.md) when relevant.
3. Check the current branch, Git status and affected implementation before editing.
   Preserve other contributors' work and user saves. Agree on the files owned by
   each concurrent agent; avoid overlapping edits.

## Implementation

- Use typed GDScript and the exact standard Godot build in
  [.godot-version](.godot-version). The current native validation target is
  macOS / Forward+ / Metal. Other platforms need their own evidence.
- Keep one authoritative world time/state and explicit transition/resource
  ownership. Reuse existing systems and make the smallest change that solves
  the requested problem.
- Preserve scientific IDs, units, reference dates and numeric data. Provide
  primary sources for science changes. Distinguish measurements, model limits
  and authored teaching effects; AI output alone is not a scientific source.
- Keep English and Simplified Chinese interfaces readable. Use the existing
  catalog, preserve format placeholders, and wrap/scroll instead of shrinking
  text. macOS HUD scaling must use Godot window-coordinate density on mixed-DPI
  displays; keep 3D pixel budgets separate.
- Keep asset source, credit, license and generation records. Existing content
  runs without generation-service credentials; regenerate assets only when the
  requested change needs it.
- There are no Node dependencies. If authorized work introduces Node tooling,
  prefer yarn.

## Run and verify

- Run one project engine/preview/export/asset job at a time. On macOS use the
  existing guarded helpers; wait for actual exit and never remove the lock to
  bypass it. Keep two worker threads, 30 FPS foreground / 5 FPS background and
  Balanced quality. Use a secondary display when available.
- Follow the documented commands and choose checks relevant to the change.
  Do not invent build commands or install/run heavy tools just for documentation
  edits. Long performance/stress tests require a task that actually requests them.
- For static checks: `python3 tools/check_community.py`,
  `python3 tools/check_localization.py`,
  `python3 tools/sync_export_resources.py --check`.
  On macOS/Linux also run
  `python3 -m unittest discover -s tests/tools -p 'test_*.py'`.
  On Windows use the documented static/snapshot/localization subset; the
  process-guard tests require Unix APIs.
- For application changes also perform an appropriate core or short scene check.
  State exactly what ran, what passed and what remains untested. Visual changes
  need an actual engine view; static CI alone does not prove visual quality.

## Handoff and Git

- Keep task notes short: intent, affected files, checks/results, remaining work
  and a concrete next step. Use existing project state files when present;
  otherwise put that information in the task/PR handoff.
- Continue authorized reversible work without adding step-by-step approvals.
  Respect the user's existing authorization for commits, pushes, releases and
  paid services; do not infer an unrequested publication or expense.
- Keep generated builds, caches, user data, credentials and bulk diagnostic
  media out of Git. Preserve source assets and provenance.
- Submit focused changes with a clear result and verification record. Keep
  public English/Chinese documentation in sync when behavior or setup changes.

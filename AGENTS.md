# AGENTS.md

dbridge.nvim is a Lua Neovim Client with an explorer, SQL editor, and results
panel. It spawns the dbridge Python server and uses stdio JSON-RPC 2.0 with
LSP-style framing. The client is asynchronous; the current server executes
requests synchronously. There is no HTTP listener or port.

## Before starting work

1. Read [CONTEXT.md](CONTEXT.md) for domain terms and
   [current architecture](docs/architecture.md) for implemented behavior.
2. Read the relevant [roadmap](docs/roadmap.md) outcome and
   [backlog record](docs/backlog/README.md), including linked server-hosted items.
3. Inspect active changes, relevant capability specs, source, and tests.
   Use `openspec list --json` for changes and `openspec list --specs` for specs.
4. Distinguish implemented behavior, accepted contracts, proposed work, and
   deferred ideas. Resolve discrepancies explicitly instead of treating a roadmap
   or a test's title as proof that behavior exists.

## Documentation ownership

Update the relevant owners in the same change as the work they describe. Link
to detail owned elsewhere instead of maintaining duplicate descriptions.

| Document | Owns | Update when |
|---|---|---|
| [README.md](README.md) | User setup, configuration, commands, keymaps, completion | Public usage or support changes |
| [CONTEXT.md](CONTEXT.md) | Client vocabulary and references to shared terms | A term is introduced or its meaning changes |
| [docs/architecture.md](docs/architecture.md) | Current modules, boundaries, state, and limits | Implemented architecture changes |
| [docs/roadmap.md](docs/roadmap.md) | Future outcomes, proposed sequence, dependencies | Direction changes or an outcome ships |
| [docs/backlog/](docs/backlog/README.md) | One record per deferred idea, defect, or question | Work is discovered, selected, resolved, or dropped |
| [docs/development.md](docs/development.md) | Tool setup, workflow commands, verification, publication facts | The development process changes |
| [openspec/specs/](openspec/specs/) | Accepted, testable client capability contracts | A verified change is synchronized |
| [openspec/changes/](openspec/changes/) | Proposal, deltas, design, and active tasks | Scope, decisions, implementation, or verification progresses |
| [openspec/config.yaml](openspec/config.yaml) | Concise OpenSpec context and artifact/operation guidance | Project-wide planning conventions change |
| AGENTS.md | Reading order, routing, maintenance rules, guardrails | Ownership or engineering conventions change |

Record enduring client architectural decisions in `docs/adr/NNNN-short-title.md`
when one is accepted, with rationale and supersession links. Create that directory
with its first real decision; do not fabricate historical ADRs or copy server
decisions as client decisions. Migration rationale can live in its change design.

Current architecture describes code as implemented. The roadmap is future intent.
Specs are contracts, not proof of conformance; inspect code/tests and record gaps.
Grow capability specs incrementally as changes touch an area.

## OpenSpec workflow

Use `spec-driven` for features, behavior changes, substantial refactors, and
workflow migrations. Small spelling/link corrections may be direct edits.

- Explore uncertain scope, then propose one coherent outcome. Create change
  scaffolds with the OpenSpec CLI; inspect existing specs before adding deltas.
- Review proposal, requirements/scenarios, design, and tasks. The installed
  propose skill stops at planning; request apply in a subsequent message before
  implementation. Design is conditional under the schema.
- Put testable contracts in delta specs, technical decisions in design, and the
  only implementation checklist in `tasks.md`. Update planning artifacts when
  discoveries change the agreed scope or approach.
- Verify each task before checking it off. Record unrelated findings in the
  owning backlog, not a commit message or another implementation plan.
- Before completion, update every affected document above. Record checks run,
  checks not run, and remaining limitations. Synchronize verified deltas where
  relevant, archive the completed change, and update archive links before its PR.
  Update roadmap outcomes and remaining dependencies without marking a whole
  milestone done for one finished item.

A documentation/tooling change with no product requirement changes declares
`skip_specs: true` in its scaffolded `.openspec.yaml`. Do not invent product specs
just to satisfy validation. Auxiliary skills can assist inside this lifecycle;
do not introduce phase PRDs, skill-specific task trackers, or duplicate plans.

The [backlog guide](docs/backlog/README.md) owns the template and status conventions.
Use stable IDs. Existing server-hosted records retain their current home until an
explicit transfer updates both repositories. New client-only findings belong here.

## Worktrees and delivery

Every OpenSpec apply runs in a separate topic worktree. Before editing, record the
original checkout's absolute path, branch, upstream, HEAD, and status including
staged, unstaged, and untracked files. Preserve that checkout's branch, index,
files, and commits throughout implementation; existing dirt stays with its owner.
Keep the baseline plus the topic branch/worktree path and selected PR target in
the session handoff, not as machine-specific paths committed to project docs.

Fetch the selected PR target (default `origin/dbridge-2.0`) and create the topic
branch from that remote tip with `--no-track`, not from the original HEAD. Use an
external `.worktrees/<change>/<repo>` directory, or resume a matching worktree
after inspecting its branch, history, and status. Transfer only the selected local
plan and necessary dependent edits; leave their original copies and unrelated
local history intact. Run edits, OpenSpec, verification, and Git publication
from the worktree. Follow [the development guide](docs/development.md#worktree-delivery)
for commands and edge cases.

Requesting apply authorizes staging and committing scoped changes, pushing the
topic branch, and creating/updating its GitHub PR after verification; no second
publication prompt is needed. Complete verified synchronization and archive before
the PR. Merging a PR, tagging, publishing packages, and releasing still require a
separate user request. Explicit user constraints override these defaults.

After GitHub confirms the PR merged, fetch in the original checkout. Refresh it
only if its recorded branch, upstream, and HEAD still match, its branch/upstream
are the PR target, it is clean including untracked files, and there are no local-only
commits. Use a fast-forward-only pull. Otherwise preserve it and report the
blocker; do not switch branches, merge, rebase, reset, or stash to force an update.
Clean up only the confirmed-merged topic worktree when it is clean and its HEAD
matches the published head of that merged PR, with no later or unpublished work.
Use non-force removal. Never delete unmerged work.

## Client/server ownership

This repository owns editor interactions, UI state, and presentation. The
[server repository](https://github.com/realEbi/dbridge/tree/dbridge-2.0) owns database
behavior and the shared DSP contract. Use the server's glossary for shared terms;
do not duplicate its complete protocol specification in client specs.

For cross-repository work, name each owner, link the corresponding changes, define
compatibility, and verify the shared flow with the owning repository's tooling.
Use paired `.worktrees/<change>/dbridge` and `.worktrees/<change>/dbridge.nvim`
directories, separate topic branches/commits/PRs, and explicitly select the server
worktree for client integration checks. Refresh each original checkout separately.

A session may be rooted above both repositories and may edit either one. Editing a
repository requires its own linked OpenSpec change in its own `openspec/`, and that
repository's AGENTS.md governs every file under it — reading order, guardrails,
verification commands, and coverage gates. OpenSpec resolves by nearest root, so run
its commands from inside the repository they target, and keep each repository's
planning artifacts, backlog records, and commits in that repository. Naming a server
backlog item still does not by itself authorize modifying that repository; the linked
change does.

Future concurrency, cancellation, or streaming requires agreed server contracts;
asynchronous Lua requests alone do not supply them.

## Engineering guardrails

- Manage Profiles through RPCs; never read/write the server's TOML from Lua.
  A Profile is configuration, a Session is live server state identified by ID.
- Route server calls through `client.request`; schedule UI operations that need
  the main loop. Keep the blocking `request_sync` wrapper in test helpers.
- Preserve UTF-8 byte lengths/offsets, object-shaped empty params, and frame
  reassembly across arbitrary stdout chunks. Do not assume one callback is a frame.
- Keep server executable checks and actionable startup failures. UI teardown must
  not rebuild inside an unload handler or re-enter itself; stop the child on exit.
- Preserve server column order, positional rows, duplicate column names, explicit
  NULL rendering, and truncation warnings. Local pages are not additional fetches.
- Modules return tables; do not revive global `DbExplorer`, `QueryEditor`, or
  `Config` objects. The source map lives in the architecture document.
- Keep blocking integration waits inside child Neovim instances, not mini.test's
  parent scheduler. Prefer real-server coverage for protocol/UI boundary changes.
  Use isolated temporary Profile/data locations and clean up subprocesses.
- Match checks to risk. Prose-only work needs documentation checks, not invented
  runtime tests. Follow [development instructions](docs/development.md) for test
  commands, server overrides, and platform-isolation limits.

Preserve unrelated user changes and generated tool integrations. Project policy
belongs in the owning docs/configuration, not generated skills. Apply requests
authorize scoped Git commits and PR publication as described above; other
publication, merges, tags, and releases require separate user authorization.

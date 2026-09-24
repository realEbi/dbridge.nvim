# Development

Read [AGENTS.md](../AGENTS.md) for ownership and workflow rules and the
[architecture](architecture.md) for implemented boundaries. User setup and keymaps
belong in the [README](../README.md).

## Local setup

Use Neovim 0.10 or newer, Git, and make. nui.nvim is the runtime UI dependency;
nvim-cmp is optional for completion integration. The test runner also uses mini.test
from mini.nvim. Completion UI tests require nvim-cmp. The [Makefile](../Makefile)
clones mini.nvim, nui.nvim, and nvim-cmp into
gitignored `deps/` on first use, requiring network access. Those clones currently
have no pinned revision in the Makefile.

The default test command expects the Python server in a sibling `../dbridge`
checkout and invokes it through uv. Prepare that environment following the
[server development guide](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/development.md).
From the client repository root:

```console
uv sync --directory ../dbridge
make test
FILE=tests/test_transport.lua make test_file
```

To use a different installed server, supply its argv through the test override:

```console
DBRIDGE_SERVER_CMD="/path/to/dbridge/.venv/bin/python -m dbridge.server" make test
```

Use a real executable path and an environment with dbridge installed. The helper
splits `DBRIDGE_SERVER_CMD` on whitespace; it does not parse shell quoting, expand
shell variables inside the value, or support arguments containing spaces. This
limitation differs from the plugin's `setup({ server_cmd = { ... } })` argv list.

## Verification

Tests run headless using [scripts/minimal_init.lua](../scripts/minimal_init.lua).
The parent drives a **child Neovim** through [tests/helpers.lua](../tests/helpers.lua);
[tests/child_env.lua](../tests/child_env.lua) performs blocking waits inside the
child. Keeping `vim.wait` there avoids re-entering mini.test's parent scheduler
while an asynchronous request is pending. UI tests mount the real nui panels. Direct source checks allow an end-of-line
cursor byte position with `virtualedit=onemore`, matching Insert mode instead of
silently clamping the requested offset in Normal mode.

Each test child starts the real server and receives a temporary `XDG_CONFIG_HOME`
for Profile files. On Unix-like systems this isolates the server configuration
from the developer's Profiles. The helper does not set Windows `APPDATA`; if
running there, provide a separate temporary `APPDATA` before Profile tests and
verify isolation. Use disposable databases for any added persistence checks and
always stop child processes through the test hooks.

| Test file | Existing coverage |
|---|---|
| [test_cancel_control.lua](../tests/test_cancel_control.lua) | Deterministic request IDs, notification framing, callback correlation, latest-query targeting, cancellation feedback, and process cleanup |
| [test_cancellation.lua](../tests/test_cancellation.lua) | Real SQLite/DuckDB cancellation through the command, Session reuse, result preservation, and completion overtaking a DuckDB query |
| [test_table_queries.lua](../tests/test_table_queries.lua) | Real Enter mapping against SQLite/DuckDB, literal names and duplicate scopes, metadata failures/retry, missing-identifier rejection, captured Session and late replies |
| [test_scope_browsing.lua](../tests/test_scope_browsing.lua) | Declared SQLite/DuckDB tiers, internal markers, literal attached paths, scoped completion and real nvim-cmp acceptance/execution, independent buffers, refresh attach/detach selection |
| [test_transport.lua](../tests/test_transport.lua) | Large/chunked responses, empty params, introspection, DSP errors, disconnect |
| [test_profiles.lua](../tests/test_profiles.lua) | Profile CRUD, saved file contents, connect by name and inline configuration |
| [test_completion.lua](../tests/test_completion.lua) | Cursor-aware completion, keyword fallback, item mapping, menu formatting |
| [test_cmp.lua](../tests/test_cmp.lua) | Real nvim-cmp automatic dot triggering, filtering, and Insert confirmation with SQLite/DuckDB, including qualified/unqualified SELECT targets, midword replacement, Unicode identifiers, multi-line UTF-8 offsets, and the bare-SELECT keyword menu |
| [test_results.lua](../tests/test_results.lua) | Column order, truncation, pagination, empty results, NULL, duplicate names |
| [test_sessions.lua](../tests/test_sessions.lua) | SQLite/DuckDB Session-preserving refresh, errors and stale replies, multi-Profile targeting and editor indicator |
| [test_lifecycle.lua](../tests/test_lifecycle.lua) | Mount, panel teardown/rebuild, reloading saved Profiles, server shutdown |
| [test_daily_workflow.lua](../tests/test_daily_workflow.lua) | Real live-Profile refresh and statement selection across SQLite/DuckDB lexical differences |
| [test_statements.lua](../tests/test_statements.lua) | Statement boundaries, quoted/commented semicolons, UTF-8 and trigger bodies, plus real SQLite/DuckDB command and mapping execution |

For behavior changes, run the affected test file while iterating, then `make test`
for changes spanning transport, lifecycle, or shared UI state. Add real-server
integration coverage where the boundary matters instead of replacing requests
with stubs. The harness currently establishes most query fixtures with SQLite;
do not claim all-adapter, reconnect, or edge-case coverage from a test's name alone.
Coordinate checks in both repositories when changing shared DSP behavior. The
query-cancellation checks require the linked server async orchestration change;
explicitly select that implementation with `DBRIDGE_SERVER_CMD`.
The explicit Scope Path client requires its linked server migration; the old fixed
scope/fqn protocol is unsupported. `tests/test_scope_browsing.lua` verifies the
shared attached-catalog/namespace flow against the selected real server.

For prose-only changes, check links/anchors, examples, retired references, and
whitespace, including **new untracked files**. Do not add runtime tests just to
test prose. These commands provide part of that verification:

```console
make -n test
git diff --check
openspec validate --all --strict --no-interactive
```

The dry run checks test-command wiring without cloning dependencies or running
tests. `git diff --check` does not inspect untracked files, so check those too.
OpenSpec validation checks artifacts, not runtime conformance. Report checks run,
checks not run, and known failures separately; unrelated findings go to the
[backlog](backlog/README.md).

## OpenSpec setup

This integration uses OpenSpec 1.13.0 and the standard `spec-driven` schema.
Keep project policy in [openspec/config.yaml](../openspec/config.yaml) and its
owning documents, not in generated skills or commands.

```console
openspec --version
openspec context --json
openspec list --json
openspec list --specs
```

The two lists serve different purposes: active changes versus accepted capability
specs. An initially empty capability inventory is expected; grow specs as verified
behavior changes touch an area rather than converting all historical prose.

Generated Codex skills under `.agents/skills/` and Claude skills/commands under
`.claude/` are shared workflow assets. Include generated updates only in an
intentional integration upgrade; exclude personal settings, caches, and `deps/`.
Refresh integrations with `openspec update` only as an intentional upgrade, review
the generated diff, and record the version here. See the
[OpenSpec project](https://github.com/Fission-AI/OpenSpec) for installation.

## Working on a change

Workflow skills run in the assistant's chat, not in the shell. In Codex:

```text
$openspec-explore <topic>
$openspec-propose <change>
$openspec-apply-change <change>
$openspec-update-change <change>
$openspec-sync-specs <change>
$openspec-archive-change <change>
```

Claude command counterparts are `/opsx:explore`, `/opsx:propose`, `/opsx:apply`,
`/opsx:update`, `/opsx:sync`, and `/opsx:archive`. The `openspec ...` commands shown
elsewhere in this guide are terminal commands. Plain-language requests can select
the corresponding skill too.

Start from an outcome or [backlog item](backlog/README.md), inspect relevant specs
and code, and explore any uncertain scope. Propose a focused change, review the
artifacts, then explicitly request apply in a new message: the installed propose
skill stops after planning. Keep requirements/scenarios in delta specs, technical
choices in design, and the only implementation checklist in `tasks.md`.

During apply, mark tasks complete only after their verification. Revise the plan
when discoveries affect the agreed scope; do not silently absorb unrelated work.
Use the [ownership table](../AGENTS.md#documentation-ownership) to update usage,
vocabulary, current architecture, roadmap, and deferred records in the same change.

For documentation/tooling-only changes with no product requirement changes, set
`skip_specs: true` in the CLI-scaffolded change's `.openspec.yaml`. Create design
only when the schema's conditions apply. Follow the current CLI instructions
rather than creating placeholder specs to fill a progress counter.

## Worktree delivery

Every apply uses a separate topic worktree. The original checkout stays on its
current branch with its index, files, and commits preserved. An apply request also
authorizes scoped commits, pushing the topic branch, and creating/updating its
GitHub PR after verification. Explicit user constraints take precedence. Merge,
tags, package publication, and releases need a separate request.

### Prepare the worktree

Before edits, record the original absolute path, branch, upstream, HEAD, and
status including staged, unstaged, and untracked files in the change's existing
session handoff, together with the selected PR target and topic branch/worktree
path. These are local session details, not machine-specific paths to commit to
project documents. If it is already dirty, preserve that state; do
not stash, reset, or commit unrelated work to obtain a clean checkout. Example
inspection from the original checkout:

```sh
primary_dir=$(git rev-parse --show-toplevel)
git branch --show-current
git rev-parse --abbrev-ref '@{upstream}'
git rev-parse HEAD
git status --porcelain=v1 --untracked-files=all
git worktree list
```

A detached HEAD or missing upstream must be recorded explicitly; it prevents
automatic post-merge refresh. Select the user's explicit PR target, defaulting
to `origin/dbridge-2.0`. Fetch it and base new work on that remote tip, even when
the original branch contains local-only commits. Example setup, adjusting the
change, branch, target, and paths to the selected work:

```sh
change_name=example-change
pr_remote=origin
pr_base=dbridge-2.0
topic_branch="work/$change_name"
worktree_dir="$(dirname "$primary_dir")/.worktrees/$change_name/dbridge.nvim"
git -C "$primary_dir" fetch "$pr_remote"
git -C "$primary_dir" worktree add --no-track -b "$topic_branch" "$worktree_dir" "$pr_remote/$pr_base"
cd "$worktree_dir"
```

`--no-track` prevents the topic from inheriting the integration branch as its
upstream. Use a new path/branch or resume the existing worktree for this change
after inspecting its branch, status, history, and PR. Do not overwrite another
worktree or force a branch checkout.

If the selected plan is absent from the target, transfer only its OpenSpec
artifacts and necessary dependent edits into the worktree. Inspect local commits,
staged/unstaged diffs, and untracked files by selected path; do not copy the whole
checkout, blindly cherry-pick mixed commits, or treat unrelated plans as
dependencies. Preserve the original copies and index. Include transferred
artifacts in the scoped worktree commit. If a required dependency cannot be
separated safely, report it before changing scope. Existing local changes can
leave the original dirty or ahead after merge; the refresh rules below preserve
them rather than silently cleaning them up.

Run all implementation, document edits, OpenSpec commands, checks, and publication
from this worktree. For cross-repository work, use paired paths
`.worktrees/<change>/dbridge` and `.worktrees/<change>/dbridge.nvim`, each with its
own linked change, topic branch, verification, commit, and PR. Client integration
checks must explicitly select the paired server worktree:

```sh
uv sync --directory ../dbridge
DBRIDGE_SERVER_CMD="$(cd ../dbridge && pwd)/.venv/bin/python -m dbridge.server" make test
```

This uses the harness override described under [local setup](#local-setup),
including its restriction on paths containing spaces. Record the server revision
used; do not assume a neighboring primary checkout contains the companion change.

### Prepare the GitHub PR

Verify the change with the owning repository's tooling, update affected docs,
synchronize verified deltas, and archive the completed change. Inspect the full
diff against the PR target, including transferred planning content. Stage only
the selected paths and commit scoped changes in the worktree; never include
unrelated user changes or generated caches. Push the topic with an explicit
upstream:

```sh
git push -u "$pr_remote" "$topic_branch"
```

Create or update a GitHub PR with explicit base/head branches. Describe the
problem, resulting change, checks run, and material limitations; link the
companion PR for cross-repository work. When using `gh pr create`, pass the body
through `--body-file` to preserve its text. Report PR and check status. An apply
request authorizes this publication; it does not authorize merging the PR.

### Refresh after merge

Confirm GitHub reports the PR as merged into its intended target. Fetch and
reinspect the original checkout before updating it. For example, use
`gh pr view <number> --json state,baseRefName,headRefName,headRefOid,mergeCommit`
from the topic worktree to inspect the PR; then run:

```sh
git -C "$primary_dir" fetch "$pr_remote"
git -C "$primary_dir" branch --show-current
git -C "$primary_dir" rev-parse --abbrev-ref '@{upstream}'
git -C "$primary_dir" rev-parse HEAD
git -C "$primary_dir" status --porcelain=v1 --untracked-files=all
git -C "$primary_dir" rev-list --left-right --count "HEAD...$pr_remote/$pr_base"
```

Compare branch, upstream, and HEAD to the recorded baseline. Continue only when
they still match, the original branch/upstream are the selected PR target, status is
empty, and the first count (local-only commits) is zero. If the second count is
also zero, no update is needed. Otherwise use:

```sh
git -C "$primary_dir" pull --ff-only "$pr_remote" "$pr_base"
```

Recheck branch, status, and HEAD afterward. Never switch the original branch to
absorb the PR. If its branch/upstream/HEAD changed, it is dirty, it has no matching
upstream, or it is ahead/diverged, leave it intact and report the fetched target
and why refresh was skipped. Do not merge, rebase, reset, or stash to make the
pull succeed. An ahead-only branch may say "already up to date" on a
fast-forward-only pull, so the explicit local-only count is required.

For linked PRs, confirm each merge and refresh each original independently. Once
the topic's PR is confirmed merged, its worktree is clean, and its HEAD matches
the merged PR's published `headRefOid` with no later or unpublished changes,
remove only that worktree with `git worktree remove` without `--force`.
Do not delete unmerged work or other worktrees. Optional branch cleanup must also
be non-force; retain the branch if Git refuses, including after a squash merge.

## Completion and publication

Record verification and remaining limitations with the change. Apply includes
synchronizing verified delta specs where applicable and archiving the completed
change before its PR; update backlog links to the archive location and roadmap
outcomes without treating a partial milestone as complete. A docs-only change
can finish without new capability specs.

There is currently no repository CI workflow or automated release pipeline, nor a
Makefile lint/format target. Do not copy the server's PyPI/tag process into this
plugin. Checks are run locally until an explicit change adds automation. Archiving
does not itself commit or publish anything; the apply delivery workflow prepares
the scoped commit and PR afterward under the authorization described above.

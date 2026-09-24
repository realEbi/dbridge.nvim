## Context

See [the proposal](proposal.md) for the motivation. The client currently requires
separate apply and archive requests and additional authorization to publish.
Both repositories already use sibling `.worktrees/<change>/<repo>` directories.
The server primary checkout has unrelated local-only planning history, so copying
its HEAD as a new branch base would contaminate a workflow PR.

The client has no applicable runtime ADR for this process change. Client
asynchronous execution, synchronous server execution, and their ownership remain
unchanged. The [linked server change](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-24-adopt-worktree-change-delivery)
owns the corresponding server documentation and must use the same delivery rules.

## Goals / Non-Goals

**Goals:** isolate every apply in a reviewable topic worktree, preserve the
primary checkout, make publication authority explicit, and safely refresh only
the matching primary branch after GitHub merge.

**Non-Goals:** runtime changes, new capability contracts, CI or wrapper scripts,
rewriting existing local history, or automatic merge/release authority.

## Decisions

### Put policy in its existing owners

`AGENTS.md` establishes the mandatory lifecycle and authorization; the development
guide owns commands and edge cases; OpenSpec configuration provides short apply
reminders. Generated skills remain unchanged. Editing generated apply skills
would lose policy during refresh and would not cover ordinary-language requests.

### Base isolated work on the fetched PR target

Record the original path, branch, upstream, HEAD, and full status before apply in
the session handoff, together with the PR target and topic branch/worktree path.
Create the topic worktree from the fetched explicit target, defaulting to
`origin/dbridge-2.0`, with `--no-track` so the topic cannot accidentally push to
the target. Resume a matching existing worktree only after inspecting its status
and history. Transfer only the selected local change artifacts and required
dependent edits; keep original files and history intact. Neither copying the
whole primary tree nor resetting it meets the preservation requirement.

Use paired repository directories for cross-repository changes. Server-dependent
client checks explicitly select the server worktree executable/environment;
implicit sibling discovery alone is insufficient evidence of the tested revision.

### Apply includes verified delivery; merge remains separate

An apply request authorizes staging and committing scoped work, pushing its topic
branch, and opening/updating a GitHub PR after verification. Complete verified
spec synchronization and archive before the PR. This intentionally replaces the
client's old separate archive-request step and aligns with the server workflow.
Show checks and limitations in the PR; stop short of merging, tagging, or releases
until separately requested. Explicit user constraints override these defaults.

### Refresh only the unchanged primary checkout by fast-forward

Confirm GitHub merged the PR, fetch, and recheck the recorded branch, upstream,
HEAD, and status including untracked files. The branch/upstream must be the PR target,
the tree must be clean, and local-only commit count must be zero. Use an explicit
fast-forward-only pull. An ahead-only checkout can produce a successful "already
up to date" response, so `pull --ff-only` alone does not enforce this condition.
If any condition fails, leave the primary intact and report the fetched target
and blocker. Never switch its branch or run merge/rebase/reset/stash to make it fit.

Remove a worktree only after confirmed merge and checking it is clean with its
HEAD matching the merged PR's published head and no later or unpublished changes.
Use non-force removal; retain branches whose merge is not
established and do not clean up other worktrees.

## Risks / Trade-offs

- Primary has a locally edited or untracked plan → transfer selected content;
  preserve the existing primary state and report that it remains dirty.
- Primary changes during implementation → compare recorded HEAD, branch,
  upstream, and status before refresh; leave it alone on any mismatch.
- Squash/rebase merge hides topic ancestry → verify GitHub's merged PR and its
  delivered head; do not use a force branch deletion as a shortcut.
- Companion PR is not merged yet → link both PRs and report their states
  separately; runtime compatibility checks remain the responsibility of each
  selected change, and this docs migration has no protocol dependency.

## Migration Plan

Implement the policy in both topic worktrees, validate the artifacts and document
links/examples, archive verified changes, and publish separate linked PRs.
Existing worktrees and local-only primary history are left intact. Rollback is a
reviewed documentation change; no runtime or data migration is involved.

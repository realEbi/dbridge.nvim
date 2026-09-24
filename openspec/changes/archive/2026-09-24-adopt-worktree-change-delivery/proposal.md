## Why

Applying a plan in the primary checkout can move its branch, mix unrelated local
commits into a PR, and require a later merge just to refresh local development.
The normal workflow should isolate implementation and deliver it through GitHub
while preserving the primary checkout for the user.

## What Changes

- Require a separate topic worktree for each applied OpenSpec change, based on
  the fetched PR target rather than the primary checkout's HEAD.
- Preserve the primary branch, index, files, and commits; transfer only the
  selected plan and its necessary dependencies into the worktree.
- Make an apply request authorize scoped commits, a push, and a GitHub PR after
  verification. Merging, tagging, and releases still need a separate request.
- Complete verified OpenSpec synchronization and archive before preparing the
  PR, replacing the client's previous separate archive-request step.
- After confirmed GitHub merge, refresh the primary checkout only when its
  recorded branch, upstream, and HEAD still match, it is clean, and the update
  to the matching PR target is a fast-forward without local-only commits.
- Document paired server/client worktrees and cautious cleanup.

## Capabilities

### New Capabilities

None. This documentation-only workflow migration uses `skip_specs: true`.

### Modified Capabilities

None. Client behavior and the DSP contract remain unchanged.

## Impact

This repository owns its `AGENTS.md`, development guide, and OpenSpec guidance.
The linked [server change](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-24-adopt-worktree-change-delivery)
owns the corresponding server policy. Each repository has its own worktree,
verification, commit, and PR. No source, generated integration, product spec,
runtime architecture, dependency, or protocol compatibility changes are needed.

This extends the roadmap's documentation and workflow foundation; no existing
backlog item or product milestone is selected. The roadmap will link the verified
workflow migration without changing the product sequence.

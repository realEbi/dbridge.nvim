## 1. Client delivery policy

- [x] 1.1 Update client AGENTS.md with worktree isolation, preservation, publication authorization, archive timing, and guarded refresh/cleanup; review against the approved design and check for contradictory old rules.
- [x] 1.2 Update the development guide with base selection, selected plan transfer, paired worktree integration, PR preparation, and post-merge commands; check examples and links against local tool help and repository layout.
- [x] 1.3 Add concise OpenSpec apply guidance and link the workflow foundation from the roadmap; verify YAML via OpenSpec context/instructions and check documentation ownership.

## 2. Verification and closure

- [x] 2.1 Compare client/server policy, validate documentation links/anchors and examples, run strict OpenSpec validation and whitespace checks including untracked files, and record checks run/not run.
- [x] 2.2 Verify the original client checkout still matches its recorded session baseline, confirm no product spec/source/generated integration changes, and confirm archive eligibility and the linked server archive location.

## Verification record

- Strict OpenSpec validation: 6 items passed (5 accepted capability specs and
  this docs-only change); the existing long-requirement informational notice is
  unchanged. No delta specs are required.
- OpenSpec context and apply instructions resolved this worktree and returned the
  updated YAML guidance correctly.
- Reviewed client/server policy together: matching isolation, publication,
  baseline preservation, archive timing, refresh gates, and non-force cleanup.
- Checked 8 changed/new files for whitespace and final newlines, 55 local
  links/anchors, and syntax of 6 shell examples. Archive links were checked against their actual paths after CLI archive.
- Reviewed local Git worktree/pull help, GitHub PR create/view help, and OpenSpec
  archive help; examples use supported flags and fields. `make -n test` passed
  without cloning dependencies or running tests.
- Original client branch, upstream, HEAD, index, tracked files, and untracked
  status remain equal to the session baseline. Only owned documentation/config
  and this OpenSpec change differ in the topic worktree; source, accepted specs,
  and generated integrations are untouched.
- Runtime tests, lint/format checks, and client/server runtime integration were
  not run: this change edits prose/configuration only and adds no runtime behavior.
- Linked server archive path matches the paired change; its canonical GitHub
  link becomes available on `dbridge-2.0` when the companion PR merges.
- PR publication and post-merge refresh are later delivery actions; the primary
  checkout is not updated or cleaned up before merge.

Archive: `openspec archive adopt-worktree-change-delivery --yes --json` completed
on 2026-09-24 with no spec updates. All five tasks are complete.

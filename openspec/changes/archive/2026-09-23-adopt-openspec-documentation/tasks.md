## 1. Establish current-state documentation

- [x] 1.1 Add `CONTEXT.md` and `docs/architecture.md` with shared vocabulary references, client-specific terms, the eight-module map, state ownership, and implemented limits. Verify descriptions against `lua/dbridge/`, `plugin/dbridge.lua`, and relevant tests, explicitly distinguishing async client requests, the blocking test wrapper, and synchronous server execution.
- [x] 1.2 Add `docs/development.md` covering prerequisites, the current child-Neovim real-server harness, temporary Profile isolation, OpenSpec skill/CLI commands, proposal review before apply, verification expectations, and current CI/release facts. Verify examples against the Makefile/helpers, confirm `make -n test` resolves correctly, and document the whitespace-split server-command override and sibling-checkout default.

## 2. Preserve deferred work and separate future direction

- [x] 2.1 Create `docs/backlog/README.md` with the server-compatible template and lifecycle conventions, and `docs/backlog/001-saved-queries.md` with deferred status and source provenance. Compare against `git show 1cea404:TODO.md` to verify every useful behavior/storage/filename note survives as historical intent, mark obsolete symbol suggestions accordingly, link the index and server provenance, then delete `TODO.md` and remove its live routing references.
- [x] 2.2 Add `docs/roadmap.md` with explicitly proposed client outcomes, dependency links, and completion criteria separate from current architecture and OpenSpec task lists. Verify each product outcome traces to the migrated idea or an identified server-hosted record, ownership is explicit, and no deferred feature or future server architecture is described as implemented.

## 3. Connect the workflow and document ownership

- [x] 3.1 Rewrite `AGENTS.md` with reading order, the document-owner/update-trigger table, engineering guardrails, backlog routing, cross-repository rules, and the propose/review/apply/verify/sync/archive lifecycle. Update README navigation and move detailed developer guidance to its owner. Verify all eight former module entries and useful test conventions remain discoverable, new links resolve, and no live guidance points to the retired server phase plan or a parallel TODO/task tracker.
- [x] 3.2 Replace the template context/rules in `openspec/config.yaml` with concise client-specific context and artifact/operation guidance using `spec-driven`. Verify the CLI resolves this repository and loads the configuration, keep this migration's `skip_specs: true`, and compare generated integration files against their pre-apply state to confirm they were not customized or regenerated; do not stage or commit them.

## 4. Verify the migration as a whole

- [x] 4.1 Check local Markdown links/anchors, portable server references, backlog metadata/index consistency, TODO migration coverage, and stale references across all affected documents, including new untracked files. Verify whitespace with tracked-diff and new-file checks, and require `openspec validate --all --strict --no-interactive` to pass without inventing product specs.
- [x] 4.2 Record verification results and checks not run in this change, updating the roadmap foundation outcome only after the document/configuration work is verified. Confirm the final diff contains only the agreed client documentation/configuration changes and TODO retirement, with Lua, tests, Makefile, dependencies, generated integrations, and the sibling server unchanged; report that commit/push and final archive remain separately authorized steps.

## Verification record

Applied and verified on 2026-09-11. No product requirement deltas were created;
`skip_specs: true` remains intentional.

Checks completed:

- Strict OpenSpec validation: `openspec validate --all --strict --no-interactive`
  passed (one change, zero failures; docs-only skip reported as informational).
- CLI instructions resolved the client root and returned its new context,
  proposal rules, and apply guidance, confirming configuration loading.
- Reviewed the architecture against all eight Lua modules, the plugin entry
  point, and the five integration test files; retained their source/test maps.
- `make -n test` and `make -n test_file FILE=tests/test_transport.lua` resolved the
  documented headless test commands without executing tests or cloning dependencies.
- Checked all 11 project/change Markdown files, including untracked additions:
  local link targets/anchors, 28 repository references against their Git revisions,
  whitespace, and stale live routing passed. Other external HTTP links were not
  fetched. The saved-query index/metadata and ten concrete legacy notes were
  checked, alongside a content review of `1cea404:TODO.md`.
- `git diff --check` passed; the new-file checks also covered the YAML files.
  SHA-256 snapshots confirmed Lua, plugin code, tests, scripts, vendored dependencies,
  assets, Makefile, ignore rules, and generated Codex/Claude integrations unchanged.
- Reviewed the final file scope: root documentation, new docs, OpenSpec configuration,
  and this change's task progress only. `TODO.md` was deleted after preservation;
  it remains recoverable at `1cea404`. Nothing was staged or committed.

Not run: the runtime integration suite, interactive UI checks, dependency upgrades,
or external HTTP availability checks. They are not claimed as passing; this
documentation/workflow change does not establish full runtime readiness.

The sibling server was not edited. A separate, concurrent untracked
`openspec/changes/raise-test-coverage/` was observed there and left untouched;
its tracked diff was clean during this verification.

Implementation is complete locally. Request the archive workflow to finalize this
change and update its links. Client commit/push remains separately authorized;
include the preserved shared OpenSpec integrations when that commit is requested,
without including personal tool state or vendored dependencies.

## Archive closeout

Archived on 2026-09-23 during the approved daily-use work. The original migration
was already committed; its verified documentation-only scope and historical
checks above remain unchanged. Current product changes have their own linked
changes and capability specs.

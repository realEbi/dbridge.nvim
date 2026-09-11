## Context

See [proposal.md](proposal.md) for motivation and scope. The client was inspected
at revision `1cea404`; the server documentation standard is at `e16c443`.

- Root documentation consists of README, AGENTS, and TODO; there is no `docs/`
  tree or client glossary. AGENTS points to the server's now-retired phase plan.
- `openspec/config.yaml` selects `spec-driven` but has no project context or
  rules. There are no capability specs. Existing Codex/Claude integrations and
  OpenSpec initialization files were untracked before this change.
- `client.lua` uses `jobstart`, a framed receive buffer, and callbacks.
  `request_sync` uses `vim.wait` for test helpers. The server's current stdio
  dispatcher and adapters remain synchronous.
- The real-server mini.test suite covers transport, profiles, completion,
  results, and lifecycle. `Makefile` clones mini.nvim and nui.nvim when missing;
  `tests/helpers.lua` defaults to a sibling server checkout via uv. This inspection
  does not establish that tests pass or that every documented case is covered.

Design is included because the migration changes ownership across multiple
documents and must preserve deferred work while avoiding competing client/server
contracts.

## Goals / Non-Goals

**Goals:** make ownership discoverable from a fresh checkout; separate current
implementation, proposed direction, accepted contracts, and active tasks; preserve
enough client-specific context to prevent incorrect server-derived assumptions.

**Non-goals:** no wholesale specification of the existing codebase, runtime
architecture changes, test-harness changes, CI installation, dependency upgrades,
or automatic commits. Do not invent historical ADRs or import the server's entire
backlog.

## Decisions

### 1. Match document roles, not server implementation details

Use the same role names as the server so an agent knows where to look in either
repository. Keep each document concise and link to detail owned elsewhere.

| Owner | Client responsibility |
|---|---|
| `README.md` | User installation, setup options, commands, keymaps, completion, navigation |
| `CONTEXT.md` | Client terms and shared-vocabulary references |
| `docs/architecture.md` | Implemented modules, state ownership, data flow, and known limits |
| `docs/roadmap.md` | Proposed client outcomes and server dependencies; no implied delivery dates |
| `docs/backlog/README.md` | Item conventions, template, index, and cross-repository references |
| `docs/backlog/NNN-slug.md` | One deferred idea, defect, or question and its resolution |
| `docs/development.md` | Tool setup, OpenSpec commands, tests, verification, and current CI/release facts |
| `AGENTS.md` | Reading order, maintenance triggers, workflow routing, engineering guardrails |
| `openspec/config.yaml` | Concise shared context and artifact/operation guidance |
| `openspec/specs/` | Accepted, testable client behavior contracts as future changes establish them |
| `openspec/changes/` | Proposal, deltas, design, and the sole active implementation checklist |

Move the existing module map into architecture and detailed test-harness guidance
into development. Define future ADR use in AGENTS, but create no empty ADR
document or fabricated runtime decision for this migration. This change's design
records the workflow decisions.

Keeping everything in AGENTS was considered, but would continue mixing routing,
runtime descriptions, and operational detail. Copying the server documents was
rejected because their runtime, test tools, and release process do not apply here.

### 2. Make the asynchronous-client/synchronous-server boundary explicit

Document one spawned stdio server process, asynchronous callback-based client
requests, and the blocking test wrapper separately. Multiple outstanding client
requests do not establish concurrent database execution in the current server.

Ground architecture in the eight client modules and their tests. Describe Profile
CRUD through RPCs, explorer-owned Session selection, query execution and UI
lifecycle, pagination over already-returned rows, completion's whole-buffer UTF-8
byte offsets, and its latest-request guard. Distinguish intended behavior from
known limitations; do not silently present a desired fix as implemented behavior.

The server owns shared DSP method/response semantics and database behavior. Client
specs own editor interaction and presentation. Future cross-repository changes
must identify owners, link the related changes, address compatibility, and verify
the combined flow; they do not duplicate the server's entire protocol spec here.
Use working repository links for shared references so documentation remains
navigable without a sibling checkout. Document the sibling layout only where the
current test runner actually depends on it.

The alternative of describing the whole system as simply sync or async was
rejected because it hides a boundary relevant to cancellation and concurrency.

### 3. Preserve deferred intent without prescribing obsolete code

Create `docs/backlog/001-saved-queries.md` from TODO before deleting the old file.
Retain the useful create/open/delete behavior, client-local storage idea, legacy
filename convention, and provenance `1cea404:TODO.md`. Mark legacy implementation
notes as historical: the current explorer does not define the suggested old
`NodeType` constants. Profile rename/delete behavior remains a question for a
future saved-query proposal, not a decision in this migration.

Use the server's item conventions: stable numeric IDs; Repo, Status, Change, and
Origin metadata; problem/opportunity, desired outcome, and references sections;
statuses `deferred`, `planned`, `done`, and `dropped`. The index links items without
repeating their status. Selected work links an OpenSpec change; resolved items
retain a brief outcome and archive link.

Link server item 007 as historical provenance for saved queries. Other relevant
server-hosted client/shared findings remain references, with their current home
explicit; do not create duplicate local status records for them. Any later
ownership transfer needs a redirect in the old home and its own confirmed scope.
Roadmap outcomes are proposed and backed by these records, not a second task list.

Keeping TODO alongside the backlog was rejected because it leaves two intake
locations. Removing it without a mapped replacement would lose useful context.

### 4. Keep the standard OpenSpec lifecycle and generated integrations

Retain `spec-driven` and explicitly skip product specs for this docs-only change.
Future behavior changes add the relevant testable capability contracts as work
touches them; this migration does not require an exhaustive baseline.

Project rules route proposals to backlog/roadmap context, distinguish client and
server owners, and require affected-document updates and appropriate verification.
They belong in project configuration and owning documents, not generated skills.
Document the proposal review and separate apply authorization required by the
installed skill, then verification, spec synchronization where relevant, and
archival. Small prose/link corrections may remain direct edits.

Preserve existing generated Codex and Claude files byte-for-byte. Document their
role in a reproducible checkout and include them only when a later commit is
authorized; exclude personal tool state and vendored test dependencies. Do not
regenerate integrations, create a custom schema, or commit as part of this task.

A custom workflow or a parallel skill-specific tracker would add maintenance
without solving a client-specific need.

### 5. Verify documentation proportionally and report limits

Check Markdown links and anchors, new untracked documents as well as tracked
diffs, migration coverage of TODO, stale plan references, whitespace, and strict
OpenSpec validation. Review examples against the current Makefile and test helpers;
`make -n test` checks command wiring without cloning dependencies or running tests.
Document that `DBRIDGE_SERVER_CMD` is whitespace-split by the helper, not parsed as
a shell command, and that the default expects a sibling server checkout.

The development guide retains real-server child-Neovim coverage and temporary
Profile isolation, states the currently absent repository CI/release automation,
and explains when to run focused/full integration checks. Runtime tests are not a
gate for prose-only changes; explicitly report whether they ran. Validation of
OpenSpec structure alone is not evidence of implementation readiness.

## Risks / Trade-offs

- More documents can drift -> keep one owner per concern and require its update
  in the same change; use links instead of duplicated module maps or task lists.
- Historical TODO advice can be mistaken for an approved implementation -> retain
  provenance and mark old paths/symbols as historical suggestions.
- An empty spec inventory can look incomplete -> explain incremental capability
  coverage and distinguish workflow preparation from product verification.
- Server backlog references can change -> identify their repository and stable ID;
  do not silently transfer status ownership in this client-only migration.
- Generated integrations are currently untracked -> preserve them and report
  pending version-control work without claiming a fresh clone already has them.
- Existing code/test discrepancies may surface -> document evidence and defer
  unrelated runtime fixes instead of expanding this migration.

## Migration Plan

After proposal review and explicit apply authorization, create the owning
documents and saved-query item, update routing/configuration and README, then
remove TODO after coverage checks. Keep the new roadmap's migration outcome
pending until verification is complete. Record results with this change; synchronize
no product specs because none change. Final archival requires the archive workflow
and its authorization, and should update links to the archived change.

Rollback has no data or protocol component: restore the retired root documents
from revision `1cea404`, revert this change's documentation/configuration edits,
and preserve pre-existing generated integrations and unrelated work. After a
commit exists, a normal revert is preferable to destructive history changes.

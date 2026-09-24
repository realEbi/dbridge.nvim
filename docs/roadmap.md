# Roadmap

This document describes proposed direction, not the current implementation or a
delivery schedule. See [architecture](architecture.md) for current behavior,
[backlog](backlog/README.md) for individual records, and [OpenSpec changes](../openspec/changes/)
for selected work and its implementation tasks. Future capability specs become
accepted contracts through verified changes; roadmap prose alone does not approve
them.

## Documentation and workflow foundation

Status: implemented, verified, and archived.

The [documentation migration](../openspec/changes/archive/2026-09-23-adopt-openspec-documentation/proposal.md)
establishes separate current architecture, future direction, a file-per-item
backlog, and agent maintenance rules using the same document roles as the server.
Completion requires verified navigation, preserved deferred intent, project-specific
OpenSpec guidance, and a recorded verification result. It does not implement the
product outcomes below. Publication and later product changes remain separate work.

See the [verification record](../openspec/changes/archive/2026-09-23-adopt-openspec-documentation/tasks.md#verification-record)
for checks completed and checks not run.

## Proposed sequence

The ordering below is a suggested dependency-aware progression, not an approved
queue. A user-selected OpenSpec change determines the actual scope and priority.

### 1. Make everyday database targeting and browsing predictable

Outcome: users can see which Session will execute SQL, refresh metadata without
losing that Session, and manage Profiles and table selection without ambiguous
names or misleading hierarchy.

Existing records: [Profile rename](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/001-profile-rename.md),
[active Session indicator](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/028-active-session-indicator.md),
[Session-preserving refresh](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/029-client-schema-refresh.md),
[qualified SQL identifiers](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/002-qualified-identifiers.md),
and [database hierarchy](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/003-database-hierarchy.md).

Ownership: Profile/Session interactions are client work. Identifier and hierarchy
contracts may require linked server/client changes; do not invent dialect behavior
in the UI without agreeing on that boundary.

Implemented in [preserve-and-display-active-session](../openspec/changes/archive/2026-09-23-preserve-and-display-active-session/):
refresh preserves the live Session and its data, and the query editor displays the
same Profile/Session target used by execution and completion. Table activation
consumes server-generated quoted identifiers through
[use-server-table-identifiers](../openspec/changes/archive/2026-09-23-use-server-table-identifiers/),
with real SQLite/DuckDB coverage of duplicate scopes and unusual names. Profile
rename remains a separate dependency. Declared hierarchy and explicit scope
selection are implemented in [adopt-explicit-scope-paths](../openspec/changes/archive/2026-09-24-adopt-explicit-scope-paths/),
with one-tier SQLite browsing, attached DuckDB catalogs, buffer-owned completion
scopes, and executable qualified insertion verified against the linked server
change. That migration retires the identifier change's old-server fallback.
These slices do not complete the whole outcome.

Completion evidence: real-server client checks for correct query targeting,
rename/failure cases, Session preservation on refresh, and unambiguous browsing;
server contract checks where shared behavior changes. A single shipped item does
not complete the whole outcome.

### 2. Support reusable and precisely selected SQL

Outcome: users can create/open/delete Profile-associated SQL files and execute the
statement containing the cursor with defined boundaries.

Existing records: [saved queries](backlog/001-saved-queries.md) and
[statement under the cursor](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/006-statement-under-cursor.md).
Both are client-owned and need not wait for a new server execution model. Resolve
storage, Profile rename/delete interactions, and SQL selection semantics in their
own changes; historical implementation suggestions are not settled designs.

Statement-under-cursor execution is implemented by
[`execute-statement-under-cursor`](../openspec/changes/archive/2026-09-23-execute-statement-under-cursor/),
with explicit lexical boundaries, a new command/mapping, and real SQLite/DuckDB
execution checks. Whole-buffer and visual execution remain available. Saved-query
management and its Profile naming/storage decisions remain open.

Completion evidence: isolated file-management checks and editor cases covering
the agreed statement/selection behavior, including strings, comments, and delimiters.
The documentation migration alone did not restore either feature.

### 3. Integrate server-supported long-running and large-result workflows

Outcome: users can manage long-running queries and retrieve large results with
explicit progress, interruption, and resource-lifetime behavior.

Existing records: [cancellation](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/009-query-cancellation.md),
[notifications](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/010-server-notifications.md),
[server concurrency](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/012-concurrent-execution.md),
and [large results](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/013-large-results.md).

Ownership: the server owns execution, interruption, and fetching contracts; this
client owns their controls and presentation. Its current asynchronous requests
and local result pages do not provide server concurrency, cancellation, or
streaming. Agree on compatibility, ordering, error handling, and cleanup before
implementing client controls against new methods.

Completion evidence: linked changes and real end-to-end tests for the selected
contract, including compatibility with the supported server behavior. Asyncio,
worker isolation, cursors, or streaming are design choices to resolve, not promises
made by this roadmap.

## Maintaining progress

Qualified-column interaction is implemented in
[`trigger-qualified-column-completion`](../openspec/changes/archive/2026-09-23-trigger-qualified-column-completion/):
typing a dot triggers suggestions, and accepting a column preserves its qualifier
and replaces the whole identifier. Real nvim-cmp tests exercise this against the
companion server's alias-resolution fix, linked from server backlog
[015](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/015-alias-completion.md).
CTE/derived and correlated source inference remain server work; this fix does not
complete the broader roadmap outcomes above.

Unqualified SELECT completion now has the same whole-identifier replacement in
[`replace-unqualified-column-completions`](../openspec/changes/archive/2026-09-23-replace-unqualified-column-completions/).
Real nvim-cmp checks cover comma targets, prefixes, Unicode and midword acceptance,
and the bare-SELECT keyword menu against the companion server's
[SELECT target change](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-23-complete-unqualified-select-targets).
Source inference remains server-owned; this does not finish the broader outcomes.

When selecting work, link its OpenSpec change from the owning backlog record.
Update the current architecture and user docs as behavior ships; update roadmap
outcomes and remaining dependencies after verification. Keep detailed tasks only
in OpenSpec. Use [AGENTS.md](../AGENTS.md#documentation-ownership) to identify the
documents affected by each change.

Server evolution remains in the [server roadmap](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/roadmap.md).
This repository does not own its adapter rollout or replace its architectural
decisions. Shared records currently hosted there remain at that home until an
explicit ownership transfer updates both repositories.

# Backlog

One file per deferred client idea, defect, or open decision. The
[roadmap](../roadmap.md) groups future outcomes; an [OpenSpec change](../../openspec/changes/)
owns the implementation checklist once work is selected. An item records intent,
not permission to implement it.

## Conventions

- Name items `NNN-descriptive-slug.md`, using the next unused number. IDs are
  stable and must not be reused.
- Each item owns its Repo, Status, Change, Origin, problem, desired outcome, and
  references. This index links titles without duplicating their status.
- Use `deferred`, `planned`, `done`, or `dropped`. New ideas are deferred.
- When selected, mark planned and link the OpenSpec change. Keep detailed tasks
  and testable scenarios in that change, with a backlink to the item.
- After verified completion and archive, mark done, link the archived change,
  and keep a brief resolution. Explain dropped work; return abandoned plans to
  deferred with context. Preserve links to stable item IDs.
- New client-only findings belong here. For a finding already tracked elsewhere,
  link its current home rather than creating a second status record. Work across
  repositories names each owner, links the related changes, and verifies the
  shared flow. Moving ownership later includes a redirect from the old home.

## Item template

```markdown
# NNN - Short outcome

- Repo: dbridge.nvim (name other owners when applicable)
- Status: deferred
- Change: none
- Origin: report, historical document, or observed evidence

## Problem / opportunity

What is missing or wrong, why it matters, and what is known versus assumed.

## Desired outcome

The behavior or decision needed; leave detailed implementation tasks to OpenSpec.

## Notes and references

Relevant source/tests, related records, dependencies, and unresolved questions.
```

## Client items

- [001 - Save and browse reusable SQL queries](001-saved-queries.md)
- [002 - Session lifetime across UI rebuild](002-ui-rebuild-session-lifetime.md)

## Server-hosted records

These existing records live in the server repository, even when their implementation
owner is the client. Read status at the linked home and recheck historical claims
against code before acting. This migration does not move or update those records.
The saved-query item above preserves the local legacy document; its reference to
server item 007 is provenance, not another local implementation checklist.

| Existing record | Implementation owner |
|---|---|
| [001 - Profile rename](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/001-profile-rename.md) | dbridge.nvim |
| [002 - Qualified SQL identifiers](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/002-qualified-identifiers.md) | dbridge and dbridge.nvim |
| [003 - Database browsing hierarchy](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/003-database-hierarchy.md) | dbridge and dbridge.nvim |
| [006 - Statement under the cursor](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/006-statement-under-cursor.md) | dbridge.nvim |
| [028 - Visible active Session](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/028-active-session-indicator.md) | dbridge.nvim |
| [029 - Refresh without replacing the Session](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/029-client-schema-refresh.md) | dbridge.nvim |
| [009 - Query cancellation](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/009-query-cancellation.md) | dbridge and affected clients |
| [010 - Server notifications](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/010-server-notifications.md) | dbridge and affected clients |
| [012 - Concurrent execution](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/012-concurrent-execution.md) | dbridge; client compatibility must be checked |
| [013 - Bounded large results](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/013-large-results.md) | dbridge and affected clients |

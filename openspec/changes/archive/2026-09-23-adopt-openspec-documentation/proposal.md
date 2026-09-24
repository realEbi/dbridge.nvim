## Why

dbridge.nvim has locally generated OpenSpec integrations but still routes agents
through a retired server plan and a standalone TODO document. Aligning its
documentation with the server's new ownership model will give future changes one
planning workflow without confusing asynchronous client behavior with synchronous
server execution.

## What Changes

- Rewrite `AGENTS.md` around reading order, document ownership, OpenSpec lifecycle,
  verification, and client/server boundaries; preserve useful engineering guidance
  in its owning document.
- Add a concise `CONTEXT.md` for client vocabulary, referencing the server's shared
  Profile, Session, and DSP definitions rather than maintaining competing ones.
- Add `docs/architecture.md` for implemented client behavior, `docs/roadmap.md`
  for explicitly proposed future outcomes, and `docs/development.md` for setup,
  workflow commands, and verification.
- Migrate the saved-query idea from `TODO.md` to
  `docs/backlog/001-saved-queries.md`, add an index and item template, and delete
  `TODO.md` only after preserving its useful content and provenance. Link relevant
  server backlog records without copying their task lists or claiming they shipped.
- Update README navigation and replace the placeholder OpenSpec context/rules
  with client-specific guidance consistent with the server's standard.
- Preserve the existing generated integrations for version control; do not
  customize generated skills, introduce another tracker, or create a custom schema.

## Capabilities

### New Capabilities

None. This change prepares documentation and workflow only.

### Modified Capabilities

None. No product requirements or protocol behavior change. This change declares
`skip_specs: true`; capability specs will grow with future behavior changes.

## Impact

- Owning repository: `dbridge.nvim`. The sibling `dbridge` repository is a
  read-only reference for shared vocabulary, current protocol behavior, and future
  dependencies; this change does not edit it.
- Affected files: root documentation, new `docs/` documents, and
  `openspec/config.yaml`, tracked by this change's planning artifacts.
- No Lua, tests, test runner, dependency, CI, database, or RPC changes; no runtime
  compatibility impact. The existing integration suite remains the verification
  foundation for future behavior changes.
- Related deferred work: the existing saved-query TODO and server backlog item
  `007-saved-queries`; migration records the idea without implementing it. No
  client roadmap exists yet; this change establishes the documentation/workflow
  foundation and separates later product outcomes from it.
- Documentation links, examples, stale-reference checks, whitespace, and strict
  OpenSpec validation provide completion evidence. Committing, pushing, or
  releasing the client requires separate authorization.

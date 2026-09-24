# dbridge.nvim domain language

This document owns client terminology. See [current architecture](docs/architecture.md)
for implemented behavior and the [roadmap](docs/roadmap.md) for proposed direction.

## Shared vocabulary

Use the server's [domain glossary](https://github.com/realEbi/dbridge/blob/dbridge-2.0/CONTEXT.md)
for **Profile**, **Session**, **Adapter**, **Transport**, **Core Engine**, **DSP**, **Scope Path**, and **Scope Level**.
Those definitions are shared; this repository does not establish a second protocol
or database model.

In client work, distinguish the saved Profile from its live server-side Session.
Lua holds the returned `session_id`, not an Adapter or database connection. Manage
Profiles through DSP methods, never by accessing the server's configuration file.
Prefer Profile or Session over the ambiguous word "connection" in new prose.
The explorer's internal `connection` node type is a legacy code label for a
Profile node, not a different domain object.

## Client terms

| Term | Meaning |
|---|---|
| Neovim Client | This Lua plugin, which owns editor interaction and presentation and spawns the server |
| Explorer | The tree panel for Profiles, server-declared scope containers, tables, and columns |
| Active Session | The live Session selected as the target for query execution and completion; the Client carries a separate Scope Path on metadata and completion requests |
| Query buffer | A SQL buffer retaining its per-Session completion Scope Path; the query editor's execution input can be its contents or a visual selection |
| Selected scope | The Client-owned Scope Path used for metadata and completion; initialized from the Session declaration and updated through explorer selection |
| Results panel | The presentation of the most recently rendered query response, including warnings |
| Results page | A client-side slice of rows already received, not a database cursor or another server fetch |
| Completion source | The optional nvim-cmp integration that translates DSP completion items into editor suggestions |
| Layout | The explorer, editor, and results panels managed together by nui.nvim |

## Boundaries

Asynchronous client requests and synchronous server execution are compatible
descriptions of different layers. A responsive editor or multiple live Sessions
does not imply concurrent query execution in one server process.

Keep editor behavior and presentation contracts here; database semantics and shared
DSP contracts belong to the server. For work spanning both repositories, follow
the ownership and compatibility rules in [AGENTS.md](AGENTS.md).

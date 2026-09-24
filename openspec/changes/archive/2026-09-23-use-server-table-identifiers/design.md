## Context

A table node keeps a bare name and legacy three-part metadata fqn. getTableSchema already loads columns asynchronously on expansion, but Enter currently generates a query immediately before that metadata arrives.

## Goals / Non-Goals

Execute the explicitly selected table through the server-provided identifier. Preserve display labels and older-server support. Do not infer database quoting in Lua, change query selection, or redesign Session state.

## Decisions

Retain `_table_ref = {name, database, schema}` on each node and send it with legacy fqn on getTableSchema. Store `_sql_identifier` when metadata succeeds. Extend handle_enter with an optional ready callback for table activation; init.lua generates SELECT only through that callback. The first expansion and execution share one metadata request; loading/error state must permit a later retry. Repeated activation while loading must not duplicate metadata or queries. Before invoking the callback, ensure the node still belongs to the current tree and use its captured Session for the generated query.

The linked server change [qualify-generated-table-identifiers](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-23-qualify-generated-table-identifiers) owns the wire fields. A successful old response with no sql_identifier permits legacy bare-name generation; explicit null, an empty identifier, or metadata error blocks query execution and reports an actionable error. Tests drive the real Enter mapping, inspect generated SQL and server rows, and exercise fallback/error behavior with controlled responses.

## Risks / Trade-offs

Initial activation waits for metadata. A fast second activation must not start a second query while that request is pending. Old servers retain bare-name ambiguity and unusual-name limitations, which the README documents. Late replies after teardown/refresh must not mutate a replaced node or query a different Session.

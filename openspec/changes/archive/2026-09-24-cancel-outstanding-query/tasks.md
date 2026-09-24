## 1. Request lifecycle

- [x] 1.1 Return request IDs, add notification and pending-only cancellation helpers, and clear pending transport state on stop/exit; verify deterministic transport tests for framing, out-of-order replies, stopped requests, and stale exits after restart.

## 2. Query control

- [x] 2.1 Add `:DbridgeCancel` and track outstanding UI executions by returned ID; verify newest-pending selection, older-pending fallback, Session changes, completed requests, and stopped-process cleanup in deterministic child-Neovim tests.
- [x] 2.2 Show confirmed cancellation at INFO level without replacing results, retain callbacks while cancellation is pending, and keep normal/error responses truthful; verify response-presentation tests.

## 3. Paired server integration

- [x] 3.1 Verify real SQLite and DuckDB cancellation through the command and subsequent execution on the same Session; use the linked server change explicitly and bounded child-Neovim waits.
- [x] 3.2 Verify completion appears during an outstanding DuckDB query, reply correlation survives overtaking, and the query then cancels; run the full client `make test` suite against the same server.

## 4. Documentation and completion

- [x] 4.1 Update README, CONTEXT, current architecture, roadmap outcome 3, development test map, AGENTS/config runtime facts, and the server-hosted backlog reference; verify links, examples, and no current synchronous-server claims remain for the supported paired version.
- [x] 4.2 Record scenario-to-test verification and remaining limitations, run strict OpenSpec validation and whitespace/link checks, synchronize verified client requirements, and coordinate archive links with the server owner.

# Verification

- `make test`: 80 cases passed, including 24 new table activation cases.
- `tests/test_table_queries.lua` uses the real Enter mapping, real stdio server and in-memory SQLite/DuckDB. Assertions inspect generated SQL, request Session and rendered result rows.
- Verified names with spaces, keywords, embedded double/single quotes and dots; duplicate SQLite namespaces and DuckDB catalogs/schemas; error/retry and null handling; older-server fallback; duplicate Enter suppression; captured Session despite selection changes; late metadata after node removal or UI teardown.
- Shared server `make test-cov`: 280 passed, 98.49% total coverage; changed-source type check and scoped Ruff passed. Existing full-check failures are recorded in the server companion verification.
- Strict OpenSpec validation passes; synchronized specs pass `openspec validate --all --strict --no-interactive`; changed/new-file whitespace and 52 relative documentation links pass.

Both repositories are isolated worktrees. The server is imported from this worktree's own uv environment. Existing unrelated adopt-openspec-documentation remains unarchived. No personal Neovim configuration changed and no commit/push was performed.

## Final combined client gate

After integrating all daily-use changes on 2026-09-23, `make test` passed all
152 cases against the sibling integrated server. This includes the Session,
generated-identifier, nvim-cmp, statement-selection, and shared live-target
checks. The server passed 350 tests with 98.71% coverage, mypy, and Ruff.
Earlier counts above describe isolated feature runs.

## 1. Scope-aware client

- [x] 1.1 Capture declarations and dialect, render declared tiers with literal paths/internal markers, and verify real-server SQLite/DuckDB tree and table activation tests.
- [x] 1.2 Send explicit table metadata paths, remove legacy fallback, and verify missing/null/error/retry and stale metadata tests.
- [x] 1.3 Retain per-buffer completion scope and reported dialect, and verify attached-scope completion/execution plus existing column/statement tests.
- [x] 1.4 Refresh declaration/tree atomically, retaining surviving scope and resetting removed paths, and verify real attach/detach plus existing failure/stale-refresh tests.

## 2. Integration and documentation

- [x] 2.1 Migrate all affected test requests and verify the full real-server client suite with make test, including attached DuckDB catalog insertion and SQLite single-tier browsing.
- [x] 2.2 Update README, CONTEXT, architecture, roadmap, and development ownership docs; verify links and whitespace and record any unrelated findings in the owning backlog.
- [x] 2.3 Validate this linked change strictly and record checks/limitations before coordinating spec synchronization and archive with the server owner.

## Verification record

- `FILE=tests/test_transport.lua make test_file`: 12 cases passed against the sibling server.
- `FILE=tests/test_scope_browsing.lua make test_file`: 12 cases passed, including both adapters and actual nvim-cmp acceptance/execution in the attached scope. Table-focused refresh explicitly exercises CursorMoved, surviving focus/scope, attached completion execution, and default reset after detachment.
- `make test`: 164 cases passed, zero failures/notes, across 11 files. Includes existing column completion, statement selection, Session preservation, transport, metadata error/retry/stale callbacks, and table activation.
- `openspec validate --all --strict --no-interactive`: all 5 items passed; existing statement requirement length advisory only.
- `git diff --check`, changed/new-file trailing-whitespace check, and relative Markdown link existence check passed.
- No unrelated defects found. Initial test failures were regressions in the migration or new test helper and were corrected before the successful complete run. Peer review found and reproduced a table-focused refresh scope regression; restoring focused identity before target updates fixes it, with dedicated real-server regressions added before the final 164-case run.
- The server owner coordinates its own lint/type/coverage gates and synchronization/archive. Both repositories must deploy together; no old-server fallback. Only declared one/two-level shipped adapters were exercised; future adapters are not claimed as verified.
- No staging, commits, push, publication, or release performed.

# Verification

- `DBRIDGE_SERVER_CMD='/Users/ebi/Projects/dbms/dbridge/.venv/bin/python -m dbridge.server' FILE=tests/test_sessions.lua make test_file`: 13 passed.
- The same server override with `make test`: all 69 client tests passed, zero notes or failures.
- New tests use real child Neovim panels and real server Sessions, with temporary Profile configuration removed by teardown. SQLite and DuckDB checks preserve the Session ID, persisted in-memory rows, and TEMP table rows across repeated refreshes. RPC recording verifies no connect/disconnect during refresh.
- Controlled errors at refreshSchema/listDatabases/listSchemas/listTables preserve displayed metadata and target. Delayed real listing replies exercise superseded refresh and deletion guards.
- Multi-Profile checks execute through the normal editor keymap and request completion from each selected Session. Additional checks cover focus priority, deletion fallback, failed connect/delete, literal percent/control display, live adapter identity after Profile edits, and known server-stop invalidation.
- An early test wait compared NuiTree's deterministic IDs instead of replacement node identity; it was corrected before the passing full run. An early display check was truncated by the test window width; explicit evaluation width now checks the literal label.
- `openspec validate preserve-and-display-active-session --strict` and `git diff --check` passed before sync/archive; final `openspec validate --all --strict` passed (3 items), 56 local documentation links resolved, and new-file whitespace checks passed.

No interactive GUI review or Windows run was performed. This is client-only runtime work compatible with the current DSP. Server tests are owned by the integrating server changes; no server runtime was edited here.

UI-only teardown/rebuild Session lifetime remains deferred in client backlog 002. Profile rename, identifier generation, automatic restart recovery, and broader server lifecycle redesign are not claimed by this change. Server-hosted backlog 028/029 resolution is delegated to the integrating parent agent; the proposal records the corrected refresh leak evidence.

Integration adds pending-connect and pending-refresh teardown regressions. The combined client passes all 15 Session cases and all 24 generated-table-query cases against the integration server. Nui clears panel buffer IDs on unmount, so validity guards explicitly check for a remaining buffer ID before calling the Neovim API.

The original isolated Session lane also passes all 15 focused cases with its documented `DBRIDGE_SERVER_CMD` override. The earlier whole-suite count of 69 above remains the original pre-integration run; it is not a claim about the final combined suite.

## Final combined client gate

After integrating all daily-use changes on 2026-09-23, `make test` passed all
152 cases against the sibling integrated server. This includes the Session,
generated-identifier, nvim-cmp, statement-selection, and shared live-target
checks. The server passed 350 tests with 98.71% coverage, mypy, and Ruff.
Earlier counts above describe isolated feature runs.

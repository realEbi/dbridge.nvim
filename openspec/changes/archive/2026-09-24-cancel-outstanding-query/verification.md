# Verification

Verified on 2026-09-24 with Neovim 0.12.5 and Python 3.11.16 against the linked
server's applied `adopt-async-orchestration` change. The server executable was
selected explicitly through `DBRIDGE_SERVER_CMD`; no globally installed server
was used. Checkout baselines and local worktree paths are recorded in the session
handoff. The feature changes were uncommitted during verification.

Checks passed:

- `FILE=tests/test_cancel_control.lua make test_file`: the initial 8 deterministic
  child-Neovim cases passed, including a rerun after guarding stale stdout. The
  final full suite also includes the ninth immediate-restart regression below.
- `FILE=tests/test_cancellation.lua make test_file` with the server override:
  3 real-server cases, covering SQLite and DuckDB cancellation through the command,
  Session reuse, displayed-result preservation, and completion during DuckDB work.
- `make test` with the same server override: all 176 cases passed, zero notes.
- `openspec validate --all --strict --no-interactive`: change and all 6 capability
  specs valid after synchronizing the 4 verified query-cancellation requirements.
- `git diff --check`, plus explicit whitespace and local Markdown-link checks
  including new files.

## Scenario coverage

| Client scenario | Passing evidence |
|---|---|
| Two executions outstanding; active Session changes | `test_cancel_control.lua`: command targets latest pending query despite active Session change |
| Latest execution has replied | Same test: normal reply removes the newer ID and cancellation targets the older pending query |
| Nothing outstanding | `test_cancel_control.lua`: confirmed cancellation is informational and preserves results; subsequent cancel sends nothing |
| Cancellation confirmed; Session reusable | `test_cancellation.lua`: cancel command preserves results and the live Session, for both shipped Adapters |
| Normal result after requesting cancellation | `test_cancel_control.lua`: normal results after cancellation requests still render and other errors remain errors |
| Process stops with a pending query | `test_cancel_control.lua`: stopped UI query is forgotten after restart; transport stop/natural-exit/stale-process cases |
| Completion overtakes DuckDB query | `test_cancellation.lua`: completion overtakes a query which can then be cancelled |

The tests drive a real command and completion source in child Neovim with mounted
UI panels. Completion insertion itself remains covered by the existing nvim-cmp
suite. A prior synchronous server was not launched for this change; deterministic
normal-response-after-cancel coverage verifies the client does not manufacture a
cancellation result. Windows and other Neovim versions were not run. Streaming,
progress notifications, and the existing UI-only rebuild lifetime backlog remain
outside this change. Publication follows the repository's worktree delivery process.

A separate read-only review found that a queued stop event could clear the next
process's newly submitted execution. Cleanup now prunes only IDs the transport has
retired. `queued stop event preserves a query submitted immediately after restart`
reproduces stop/start/submit without an intermediate scheduler drain and verifies
the live request remains cancellable. The full suite above includes this fix.

Completion: all 7 tasks are verified, the 4 requirements match the synchronized
main spec, and the change was archived on 2026-09-24 with reciprocal links to the
server archive. Final strict validation passed all 6 main capability specs;
the active-change list is empty. Final local link/anchor and whitespace checks
include the moved artifacts and new files. The primary checkout remains unchanged.

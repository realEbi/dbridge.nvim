# Development

Read [AGENTS.md](../AGENTS.md) for ownership and workflow rules and the
[architecture](architecture.md) for implemented boundaries. User setup and keymaps
belong in the [README](../README.md).

## Local setup

Use Neovim 0.10 or newer, Git, and make. nui.nvim is the runtime UI dependency;
nvim-cmp is optional for completion integration. The test runner also uses mini.test
from mini.nvim. Completion UI tests require nvim-cmp. The [Makefile](../Makefile)
clones mini.nvim, nui.nvim, and nvim-cmp into
gitignored `deps/` on first use, requiring network access. Those clones currently
have no pinned revision in the Makefile.

The default test command expects the Python server in a sibling `../dbridge`
checkout and invokes it through uv. Prepare that environment following the
[server development guide](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/development.md).
From the client repository root:

```console
uv sync --directory ../dbridge
make test
FILE=tests/test_transport.lua make test_file
```

To use a different installed server, supply its argv through the test override:

```console
DBRIDGE_SERVER_CMD="/path/to/dbridge/.venv/bin/python -m dbridge.server" make test
```

Use a real executable path and an environment with dbridge installed. The helper
splits `DBRIDGE_SERVER_CMD` on whitespace; it does not parse shell quoting, expand
shell variables inside the value, or support arguments containing spaces. This
limitation differs from the plugin's `setup({ server_cmd = { ... } })` argv list.

## Verification

Tests run headless using [scripts/minimal_init.lua](../scripts/minimal_init.lua).
The parent drives a **child Neovim** through [tests/helpers.lua](../tests/helpers.lua);
[tests/child_env.lua](../tests/child_env.lua) performs blocking waits inside the
child. Keeping `vim.wait` there avoids re-entering mini.test's parent scheduler
while an asynchronous request is pending. UI tests mount the real nui panels.

Each test child starts the real server and receives a temporary `XDG_CONFIG_HOME`
for Profile files. On Unix-like systems this isolates the server configuration
from the developer's Profiles. The helper does not set Windows `APPDATA`; if
running there, provide a separate temporary `APPDATA` before Profile tests and
verify isolation. Use disposable databases for any added persistence checks and
always stop child processes through the test hooks.

| Test file | Existing coverage |
|---|---|
| [test_transport.lua](../tests/test_transport.lua) | Large/chunked responses, empty params, introspection, DSP errors, disconnect |
| [test_profiles.lua](../tests/test_profiles.lua) | Profile CRUD, saved file contents, connect by name and inline configuration |
| [test_completion.lua](../tests/test_completion.lua) | Cursor-aware completion, keyword fallback, item mapping, menu formatting |
| [test_cmp.lua](../tests/test_cmp.lua) | Real nvim-cmp automatic dot triggering, filtering, and Insert confirmation with SQLite/DuckDB, including midword replacement, Unicode identifiers, and multi-line UTF-8 offsets |
| [test_results.lua](../tests/test_results.lua) | Column order, truncation, pagination, empty results, NULL, duplicate names |
| [test_lifecycle.lua](../tests/test_lifecycle.lua) | Mount, panel teardown/rebuild, reloading saved Profiles, server shutdown |

For behavior changes, run the affected test file while iterating, then `make test`
for changes spanning transport, lifecycle, or shared UI state. Add real-server
integration coverage where the boundary matters instead of replacing requests
with stubs. The harness currently establishes most query fixtures with SQLite;
do not claim all-adapter, reconnect, or edge-case coverage from a test's name alone.
Coordinate checks in both repositories when changing shared DSP behavior.

For prose-only changes, check links/anchors, examples, retired references, and
whitespace, including **new untracked files**. Do not add runtime tests just to
test prose. These commands provide part of that verification:

```console
make -n test
git diff --check
openspec validate --all --strict --no-interactive
```

The dry run checks test-command wiring without cloning dependencies or running
tests. `git diff --check` does not inspect untracked files, so check those too.
OpenSpec validation checks artifacts, not runtime conformance. Report checks run,
checks not run, and known failures separately; unrelated findings go to the
[backlog](backlog/README.md).

## OpenSpec setup

This integration uses OpenSpec 1.13.0 and the standard `spec-driven` schema.
Keep project policy in [openspec/config.yaml](../openspec/config.yaml) and its
owning documents, not in generated skills or commands.

```console
openspec --version
openspec context --json
openspec list --json
openspec list --specs
```

The two lists serve different purposes: active changes versus accepted capability
specs. An initially empty capability inventory is expected; grow specs as verified
behavior changes touch an area rather than converting all historical prose.

Generated Codex skills under `.agents/skills/` and Claude skills/commands under
`.claude/` are shared workflow assets. Include them and `openspec/` when committing
the migration is authorized; exclude personal settings, caches, and `deps/`.
Refresh integrations with `openspec update` only as an intentional upgrade, review
the generated diff, and record the version here. See the
[OpenSpec project](https://github.com/Fission-AI/OpenSpec) for installation.

## Working on a change

Workflow skills run in the assistant's chat, not in the shell. In Codex:

```text
$openspec-explore <topic>
$openspec-propose <change>
$openspec-apply-change <change>
$openspec-update-change <change>
$openspec-sync-specs <change>
$openspec-archive-change <change>
```

Claude command counterparts are `/opsx:explore`, `/opsx:propose`, `/opsx:apply`,
`/opsx:update`, `/opsx:sync`, and `/opsx:archive`. The `openspec ...` commands shown
elsewhere in this guide are terminal commands. Plain-language requests can select
the corresponding skill too.

Start from an outcome or [backlog item](backlog/README.md), inspect relevant specs
and code, and explore any uncertain scope. Propose a focused change, review the
artifacts, then explicitly request apply in a new message: the installed propose
skill stops after planning. Keep requirements/scenarios in delta specs, technical
choices in design, and the only implementation checklist in `tasks.md`.

During apply, mark tasks complete only after their verification. Revise the plan
when discoveries affect the agreed scope; do not silently absorb unrelated work.
Use the [ownership table](../AGENTS.md#documentation-ownership) to update usage,
vocabulary, current architecture, roadmap, and deferred records in the same change.

For documentation/tooling-only changes with no product requirement changes, set
`skip_specs: true` in the CLI-scaffolded change's `.openspec.yaml`. Create design
only when the schema's conditions apply. Follow the current CLI instructions
rather than creating placeholder specs to fill a progress counter.

## Completion and publication

Record verification and remaining limitations with the change. After implementation
is complete, request the archive workflow; synchronize verified delta specs where
applicable, update backlog links to the archive location, and update roadmap
outcomes without treating a partial milestone as complete. A docs-only change
can finish without new capability specs.

There is currently no repository CI workflow or automated release pipeline, nor a
Makefile lint/format target. Do not copy the server's PyPI/tag process into this
plugin. Checks are run locally until an explicit change adds automation. Archiving
does not commit or publish anything; staging, committing, pushing, tags, and
releases require the user's authorization.

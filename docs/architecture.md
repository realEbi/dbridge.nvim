# Current architecture

This describes the implemented Neovim Client, not its future design. Read the
[glossary](../CONTEXT.md) for terms, [README](../README.md) for usage, and
[roadmap](roadmap.md) for proposed changes.

## Execution model and boundaries

The client is asynchronous. It spawns one dbridge child process per running
client instance using `jobstart` and communicates over stdin/stdout with JSON-RPC
2.0 and LSP-style `Content-Length` framing. It does not start an HTTP listener or
configure a port. DSP is the dbridge method contract, not the full LSP API.

`client.request(method, params, cb)` returns without waiting for a response. A
request-ID map routes later replies to callbacks; the receive buffer reassembles
arbitrarily split stdout chunks and can consume multiple complete frames. Empty
params are encoded as an object, and frame lengths count UTF-8 bytes. UI operations
that require the main loop are scheduled with `vim.schedule`.

`client.request_sync` is a blocking wrapper using `vim.wait`, used by the test
helpers. Its existence does not make normal UI requests synchronous. Conversely,
the [current Python server](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/architecture.md)
handles requests sequentially with blocking adapters. A long query delays later
requests to that process, including completion; multiple pending client requests
are not concurrent database execution.

The client owns presentation and editor state. The server owns Profile persistence,
live Adapters, query execution, schema metadata, and SQL completion semantics.

## Source map

| Module | Implemented responsibility |
|---|---|
| [init.lua](../lua/dbridge/init.lua) | Configuration, three-panel layout, keymaps, commands, query dispatch, lifecycle |
| [client.lua](../lua/dbridge/client.lua) | Child process, framed transport, pending callbacks, async requests and sync wrapper |
| [profiles.lua](../lua/dbridge/profiles.lua) | Profile RPC wrappers and interactive name/adapter/JSON prompts |
| [explorer.lua](../lua/dbridge/explorer.lua) | NuiTree, Profile nodes, schema browsing, Session bindings and active target selection |
| [editor.lua](../lua/dbridge/editor.lua) | SQL buffer and whole-buffer/visual-selection execution input |
| [results.lua](../lua/dbridge/results.lua) | Ordered results, warning display, NULL rendering, local pagination |
| [cmp.lua](../lua/dbridge/cmp.lua) | DSP-backed nvim-cmp source and cursor offsets |
| [cmp_format.lua](../lua/dbridge/cmp_format.lua) | Optional dbridge-specific menu kinds/icons and label |

[plugin/dbridge.lua](../plugin/dbridge.lua) registers the completion source when
nvim-cmp is available. Loading `lua/dbridge/init.lua`, typically through `setup`,
registers the user commands. Modules return tables rather than creating global
`DbExplorer`, `QueryEditor`, or `Config` objects; the UI lifecycle still uses the
`vim.g.dbridge_loaded` flag.

## Profiles, Sessions, and browsing

Profile CRUD goes through `dbridge/listProfiles`, `dbridge/saveProfile`, and
`dbridge/deleteProfile`. The explorer retains a Profile's name, adapter, and config
for display/editing. Opening a Profile currently sends its inline adapter/config
to `dbridge/connect`; the client stores the returned Session ID by tree node ID.

The tree nests Profile, database, schema, table, and column nodes. Connecting
fetches database/schema/table listings; column details load on first table
expansion. Table nodes keep a legacy three-part metadata name, literal structured identity,
a display name, and the SQL identifier returned by the server. First expansion
shares one metadata request with query activation; failed loading remains retryable.
Late replies for removed/replaced nodes or torn-down panels are ignored.

Active Session selection first considers the explorer cursor when that panel is
focused, then the last-interacted connected Profile, then a connected root node.
Execution, completion, and the query-editor winbar share one target descriptor
containing the Profile name, live Session adapter, and Session ID. The adapter is
captured at connect time rather than inferred from subsequently edited Profile
configuration. The winbar updates on explorer interaction, focus/cursor changes,
metadata rendering, and known server running-state changes; it explicitly shows
no active Session when no live target is available. A known server stop clears
bindings and metadata because Session IDs belong to that process. Profile text
is escaped for statusline rendering. The results statusline retains pages and warnings.

Deleting a Profile through the explorer also requests disconnection of its tracked
Session. Editing a Profile upserts the entered name; it does not remove an old
name when renamed. Schema refresh clears the server cache and obtains database,
schema, and table listings using the existing Session. It gathers a replacement
subtree off-screen and swaps children only after all listings succeed. Errors
retain the previous metadata and Session binding. A generation and captured tree,
node, Session identity, and panel validity reject superseded refreshes and replies
for removed Profiles or torn-down panels. Duplicate pending connect actions are
coalesced; a connect reply for a removed Profile or disposed panel is disconnected. Refresh does not create or disconnect a Session,
so its temporary tables and in-memory data survive.

## Query input, results, and completion

Normal execution sends the query buffer; the editor also has a visual-selection
path. There is no statement-under-cursor extractor. Entering a table waits for getTableSchema and generates
`SELECT * FROM <server-sql-identifier> LIMIT 100` using that node's captured Session.
The server owns quoting and qualification; the client sends literal table identity
alongside legacy fqn and never infers dialect rules. A successful response missing
the identifier field permits legacy bare-name generation for older servers.
Explicit null identifiers and metadata errors prevent execution and notify the user.

The results panel renders positional rows against the server's ordered column
list. Columns are keyed internally by index, preserving duplicate names. JSON
null (`vim.NIL`) renders as `NULL`, distinct from an empty string. Pagination uses
20-row pages over the response already in memory. It does not fetch more rows;
server truncation warnings appear as notifications and in the statusline. An
empty response renders `(no results)`.

The completion source activates in SQL buffers while the server is running and
returns no items without an active Session. It sends the whole buffer joined by
newlines plus the cursor's zero-based UTF-8 byte offset. Per-source sequence
numbers suppress stale replies. DSP labels, insert text, and sort keys are mapped
to nvim-cmp items; the optional formatter exposes table/column/keyword vocabulary.
The source registers `.` as a trigger character, respecting nvim-cmp's automatic
completion configuration. All column items include a UTF-8 text edit covering
the current identifier and its suffix after the cursor. Acceptance preserves any
alias and replaces an existing qualified or unqualified column name completely,
including with nvim-cmp's default Insert confirmation behavior. Table and keyword
items retain their existing insertion mapping.
Completion quality and dialect support remain server responsibilities.

## UI and process lifecycle

`:Dbridge` builds a layout in a new tab, then toggles hide/show while it exists.
Closing a panel schedules one guarded teardown rather than rebuilding inside its
unload handler. A later `:Dbridge` can build a fresh layout. UI teardown alone
does not stop the child process; `:DbridgeClose` and Neovim exit call `client.stop`.

Startup checks the server executable and reports missing commands or failed
`jobstart` calls. JSON-RPC errors reach the request callback; stderr and unexpected
nonzero exits are surfaced as notifications. There is no automatic restart or
query cancellation. UI-only teardown/rebuild Session ownership remains a
[deferred lifecycle issue](backlog/002-ui-rebuild-session-lifetime.md). Do not infer
stronger guarantees from the lifecycle helpers.

## Verification and remaining limits

The [test guide](development.md#verification) maps the real-server integration
suite to these boundaries. Test presence is not evidence that every state or
adapter combination is covered. The current client has no saved-query browser,
streamed results, or server-side paging. Future outcomes and shared protocol
dependencies belong in the roadmap/backlog, not in this current-state description.

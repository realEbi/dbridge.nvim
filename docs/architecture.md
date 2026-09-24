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
| [statements.lua](../lua/dbridge/statements.lua) | Byte-based statement boundaries for cursor execution |
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

Connect returns the Session's declared levels, default Scope Path, and SQL dialect.
The tree nests Profile, those declared containers, table, and column nodes: SQLite
has one namespace tier; DuckDB has catalog and schema tiers. Container nodes retain
literal paths and engine-internal flags, displayed with their level labels. Table
listings supply literal names and executable SQL identifiers; column details load
on first table expansion. Metadata requests send the table node's path and name.
First expansion shares one metadata request with query activation; failed loading
remains retryable.
Late replies for removed/replaced nodes or torn-down panels are ignored.

Active Session selection first considers the explorer cursor when that panel is
focused, then the last-interacted connected Profile, then a connected root node.
Execution, completion, and the query-editor winbar share one target descriptor
containing the Profile name, live Session adapter, SQL dialect, Session ID, and
selected Scope Path. Session metadata is captured at connect time rather than
inferred from subsequently edited Profile configuration. Each live Profile binding
tracks its active path; a selected container's missing suffix uses the declaration's
default components. The query editor records its selected path per Session in a
buffer-local binding; other SQL buffers retain independent per-Session paths.
The winbar includes the active scope and updates on explorer interaction, focus/cursor changes,
metadata rendering, and known server running-state changes; it explicitly shows
no active Session when no live target is available. A known server stop clears
bindings and metadata because Session IDs belong to that process. Profile text
is escaped for statusline rendering. The results statusline retains pages and warnings.

Deleting a Profile through the explorer also requests disconnection of its tracked
Session. Editing a Profile upserts the entered name; it does not remove an old
name when renamed. Schema refresh clears the server cache and obtains declared
container and table listings using the existing Session. It rereads the
hierarchy declaration, gathers a replacement subtree off-screen, and swaps children
and declaration only after all listings succeed. Errors retain the previous
metadata, declaration, and Session binding. A still-listed selected path survives;
a removed path resets to the refreshed default, including paths held by other SQL
buffers when next used. Refresh preserves focus on a surviving table or scope;
a removed scope focuses the Profile, so cursor events cannot select an unrelated
container after replacement. A generation and captured tree,
node, Session identity, and panel validity reject superseded refreshes and replies
for removed Profiles or torn-down panels. Duplicate pending connect actions are
coalesced; a connect reply for a removed Profile or disposed panel is disconnected. Refresh does not create or disconnect a Session,
so its temporary tables and in-memory data survive.

## Query input, results, and completion

`<leader>r` sends the query buffer or a visual selection. `<leader>s` and
`:DbridgeExecuteStatement` select one statement at the query-editor cursor and
use the same execution/Session flow. The lexical scanner preserves semicolons
inside quotes, comments, and SQLite trigger bodies and reports empty or
unterminated input without a request. The live Session's reported SQL dialect
distinguishes SQLite bracket identifiers/non-nested comments from DuckDB
arrays/nested comments.
It does not validate SQL or implement arbitrary procedural dialect grammars.

Entering a table waits for getTableSchema and generates
`SELECT * FROM <server-sql-identifier> LIMIT 100` using that node's captured Session.
The server owns quoting and qualification; the client sends the captured literal
Scope Path and table name. Missing, empty, or null identifiers and metadata errors
prevent execution and notify the user. Client and server must use the explicit-scope
contract together; legacy fqn, fixed database/schema fields, and older-server
identifier fallback are removed.

The results panel renders positional rows against the server's ordered column
list. Columns are keyed internally by index, preserving duplicate names. JSON
null (`vim.NIL`) renders as `NULL`, distinct from an empty string. Pagination uses
20-row pages over the response already in memory. It does not fetch more rows;
server truncation warnings appear as notifications and in the statusline. An
empty response renders `(no results)`.

The completion source activates in SQL buffers while the server is running and
returns no items without an active Session. It sends the query buffer's selected
Scope Path, the whole buffer joined by newlines, and the cursor's zero-based UTF-8
byte offset. Per-source sequence
numbers suppress stale replies. DSP labels, insert text, and sort keys are mapped
to nvim-cmp items; the optional formatter exposes table/column/keyword vocabulary.
The source registers `.` as a trigger character, respecting nvim-cmp's automatic
completion configuration. All column items include a UTF-8 text edit covering
the current identifier and its suffix after the cursor. Acceptance preserves any
alias and replaces an existing qualified or unqualified column name completely,
including with nvim-cmp's default Insert confirmation behavior. Table and keyword
items retain server insertion text; table labels are bare and their insertion
is the server's fully qualified executable identifier. Completion quality and
dialect support remain server responsibilities.

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

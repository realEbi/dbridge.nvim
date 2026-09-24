## Purpose

Render the Session's declared hierarchy and retain explicit scope selections in the Neovim Client.

## ADDED Requirements

### Requirement: Browse the declared hierarchy

The Client SHALL render the Session's declared container levels without inserting undeclared tiers. It SHALL retain literal names, paths, and engine-internal markers and address every metadata operation using its selected node's path.

#### Scenario: SQLite attached namespace
- **WHEN** a SQLite Session exposes main and an attached namespace
- **THEN** each namespace directly contains its tables, without a duplicated main/main tier

#### Scenario: DuckDB attached catalogs
- **WHEN** a DuckDB Session exposes two catalogs containing same-named tables
- **THEN** the explorer distinguishes both catalogs and their schema children and each table opens its own data

### Requirement: Scope selection belongs to the client

The Client SHALL initialize scope from the Session's declared default and retain scope with query buffers and metadata nodes. Selecting a container or table SHALL update the query editor's scope without changing Session identity. Statement selection SHALL use the Session's reported SQL dialect.

#### Scenario: Choose an attached scope
- **WHEN** the user selects a table in an attached catalog and returns to the query editor
- **THEN** completion uses that table's scope and execution retains the selected Session

#### Scenario: Independent SQL buffers
- **WHEN** separate SQL buffers acquire scope selections within the same Session
- **THEN** each buffer retains its own path when requesting completion

### Requirement: Refresh updates the hierarchy atomically

The Client SHALL reread the hierarchy declaration on refresh and replace displayed metadata and declaration together only after the replacement loads successfully. A surviving selected scope SHALL be retained; a removed scope SHALL reset to the refreshed default. Existing Session-preservation and stale-response guarantees SHALL remain in force.

#### Scenario: Attach and refresh
- **WHEN** a namespace is attached after connection and the user refreshes
- **THEN** the existing Session displays the new namespace using the refreshed declaration

#### Scenario: Refresh while focused on a surviving table
- **WHEN** the user refreshes from a table row in an attached scope and that table survives
- **THEN** the replacement tree retains that table's focus and the query buffer's selected scope, including after cursor-change events, so subsequent completion still reads that scope

#### Scenario: Selected namespace is detached
- **WHEN** the selected namespace disappears and a refresh succeeds while its old table row is focused
- **THEN** the Client focuses the Profile and uses the refreshed default for subsequent completion, including after cursor-change events

## MODIFIED Requirements

### Requirement: Execute the selected table using server metadata

Entering an explorer table SHALL generate its sample SELECT from the server-provided SQL identifier after metadata succeeds. The Client SHALL request metadata with the table's literal name and Scope Path. It MUST NOT infer quoting or catalog rules from the adapter name. The generated query SHALL use the table's Session even if the active selection changes before metadata returns.

#### Scenario: Names requiring quoting
- **WHEN** the user enters a SQLite or DuckDB table containing spaces, a keyword, a quote, or a dot
- **THEN** generated SQL uses the server identifier and displays that table's rows

#### Scenario: Duplicate table names
- **WHEN** same-named tables exist in separate scopes and the user enters one
- **THEN** the generated query reads the selected scope only

#### Scenario: Asynchronous activation
- **WHEN** table metadata is loading and the user activates the same table again
- **THEN** the client does not issue duplicate metadata requests or sample queries

## REMOVED Requirements

### Requirement: Fail visibly and preserve older-server compatibility
**Reason**: The explicit-scope migration deliberately removes the legacy protocol fallback.
**Migration**: Upgrade client and server together; metadata requests use literal paths and identifiers are required.

## ADDED Requirements

### Requirement: Fail visibly when metadata lacks an identifier

Metadata errors or absent, empty, or null identifiers SHALL notify the user and prevent generated execution. Failed loading SHALL remain retryable; stale replies for removed nodes SHALL not execute a query.

#### Scenario: Identifier unavailable
- **WHEN** metadata fails or lacks a usable SQL identifier
- **THEN** an error is shown and no sample query is sent

#### Scenario: Stale response
- **WHEN** the table node is removed or its tree is replaced before metadata returns
- **THEN** the response does not execute a sample query or mutate the replacement tree

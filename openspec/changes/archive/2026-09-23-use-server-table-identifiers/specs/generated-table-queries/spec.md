## ADDED Requirements

### Requirement: Execute the selected table using server metadata

Entering an explorer table SHALL generate its sample SELECT from the server-provided SQL identifier after metadata succeeds. The client SHALL retain literal table identity and request metadata for the selected table. It MUST NOT infer quoting or catalog rules from the adapter name. The generated query SHALL use the table's Session even if the active selection changes before metadata returns.

#### Scenario: Names requiring quoting
- **WHEN** the user enters a SQLite or DuckDB table containing spaces, a keyword, a quote, or a dot
- **THEN** generated SQL uses the server identifier and displays that table's rows

#### Scenario: Duplicate table names
- **WHEN** same-named tables exist in separate scopes and the user enters one
- **THEN** the generated query reads the selected scope only

#### Scenario: Asynchronous activation
- **WHEN** table metadata is loading and the user activates the same table again
- **THEN** the client does not issue duplicate metadata requests or sample queries

### Requirement: Fail visibly and preserve older-server compatibility

Metadata errors or explicit unavailable identifiers SHALL notify the user and prevent generated execution. A successful older response lacking the identifier field SHALL retain legacy bare-name generation. Failed metadata loading SHALL remain retryable; stale replies for removed nodes SHALL not execute a query.

#### Scenario: Older server response
- **WHEN** a successful table metadata response has no sql_identifier field
- **THEN** the existing bare-table sample query remains available

#### Scenario: Metadata failure
- **WHEN** the server rejects metadata lookup or returns a null identifier
- **THEN** an error is shown and no sample query is sent

#### Scenario: Stale response
- **WHEN** the table node is removed or its tree is replaced before metadata returns
- **THEN** the response does not execute a sample query or mutate the replacement tree

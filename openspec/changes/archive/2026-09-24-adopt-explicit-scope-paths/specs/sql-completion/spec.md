## ADDED Requirements

### Requirement: Completion uses the query buffer scope

The Client SHALL send the selected query buffer's explicit Scope Path with completion requests and preserve the server's table insertion text independently from the bare display label. Existing full-buffer, UTF-8 byte-position, and column replacement behavior SHALL remain unchanged.

#### Scenario: Complete in attached catalogs
- **WHEN** the user completes a FROM table in each of two attached DuckDB catalogs
- **THEN** each menu contains only that scope's candidates and accepting its server-provided qualified identifier reads the selected table without editing the insertion

#### Scenario: Bare label and qualified insertion
- **WHEN** a table item has a bare display label and an executable qualified insertion
- **THEN** the completion menu shows the label and acceptance inserts the complete identifier

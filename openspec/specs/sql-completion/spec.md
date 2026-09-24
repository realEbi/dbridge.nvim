# sql-completion Specification

## Purpose

Provide Neovim completion interactions that expose server-resolved SQL columns
and insert the selected identifier without damaging the surrounding query.

## Requirements

### Requirement: Qualified column completion triggers automatically

With automatic completion enabled, the dbridge source configured, a SQL buffer,
and an active Session, the Client SHALL request suggestions when the user types
`.` and display the columns returned by a server supporting qualified completion.

#### Scenario: Dot after a physical-table alias
- **WHEN** the user types `.` after `p` in `SELECT p FROM products p LIMIT 100`
- **THEN** the completion menu offers the server's product columns without a manual completion command

#### Scenario: Qualifier after a SELECT comma
- **WHEN** the user types `.` after the second `p` in `SELECT p.name, p FROM products p LIMIT 100`
- **THEN** the completion menu offers the product columns for that qualifier

### Requirement: Acceptance replaces only the column identifier

Accepting a qualified or unqualified column suggestion SHALL replace the current
column identifier, including any identifier suffix to the right of the cursor,
while retaining any qualifier and surrounding SQL. Typed prefixes SHALL filter
suggestions. This SHALL hold with nvim-cmp's default Insert confirmation behavior.

#### Scenario: Empty or partial identifier
- **WHEN** the user accepts `name` after `p.` or `p.na`
- **THEN** the resulting expression is `p.name`, with the qualifier present once

#### Scenario: Cursor inside an existing identifier
- **WHEN** the user accepts `name` with the cursor between `na` and `me` in `p.name`
- **THEN** the resulting expression is `p.name`, with no duplicated suffix

#### Scenario: Multibyte column identifier
- **WHEN** the user accepts `café` with the cursor between `ca` and `fé` in `p.café`
- **THEN** the resulting expression is `p.café`, with no duplicated multibyte suffix

#### Scenario: Identifier on the line after its qualifier
- **WHEN** the user accepts `name` with the cursor inside `name` on the line after `p.`
- **THEN** the complete identifier is replaced and the line break and qualifier are preserved

#### Scenario: Unqualified identifier after a SELECT comma
- **WHEN** the user accepts `name` with the cursor between `na` and `me` in
  `SELECT id, name FROM products`
- **THEN** the query remains `SELECT id, name FROM products` without a duplicate suffix

#### Scenario: Empty or typed unqualified target
- **WHEN** the server offers columns at an empty SELECT target or after its `ca` prefix
- **THEN** accepting `category` inserts that name once and preserves the remaining SQL

#### Scenario: Unqualified multibyte identifier
- **WHEN** the user accepts `café` inside the unqualified identifier after multibyte
  text, with the FROM clause on a later line
- **THEN** the entire identifier is replaced and multibyte text and lines remain intact

### Requirement: Completion preserves full query and byte positions

The Client SHALL preserve the full SQL buffer and UTF-8 cursor byte offset when
requesting suggestions and SHALL apply column edits at the corresponding buffer
position, including when multibyte text precedes the cursor.

#### Scenario: Multibyte prefix and later FROM clause
- **WHEN** the user completes an alias after multibyte text with its FROM clause on a later line
- **THEN** the correct columns are offered and accepting one preserves the multibyte text and remaining query

### Requirement: Completion uses the query buffer scope

The Client SHALL send the selected query buffer's explicit Scope Path with completion requests and preserve the server's table insertion text independently from the bare display label. Existing full-buffer, UTF-8 byte-position, and column replacement behavior SHALL remain unchanged.

#### Scenario: Complete in attached catalogs
- **WHEN** the user completes a FROM table in each of two attached DuckDB catalogs
- **THEN** each menu contains only that scope's candidates and accepting its server-provided qualified identifier reads the selected table without editing the insertion

#### Scenario: Bare label and qualified insertion
- **WHEN** a table item has a bare display label and an executable qualified insertion
- **THEN** the completion menu shows the label and acceptance inserts the complete identifier

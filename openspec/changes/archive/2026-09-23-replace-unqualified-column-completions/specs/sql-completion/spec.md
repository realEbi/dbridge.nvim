## MODIFIED Requirements

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

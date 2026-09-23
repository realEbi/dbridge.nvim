## Purpose

Let users execute the SQL statement at the query-buffer cursor without manually
selecting it or sending neighboring statements to the active Session.

## ADDED Requirements

### Requirement: Execute only the selected statement

The Client SHALL provide `:DbridgeExecuteStatement` and query-editor normal-mode
`<leader>s` to execute the statement containing the cursor against the active
Session. Existing whole-buffer and visual-selection `<leader>r` SHALL remain
available. The new command SHALL send no query outside the query editor.

#### Scenario: Several statements in one buffer
- **WHEN** the cursor is in the second statement and the user invokes the command or mapping
- **THEN** only that statement is sent through the existing execution flow
- **AND** the query buffer remains unchanged

#### Scenario: Existing execution action
- **WHEN** the user invokes normal-mode `<leader>r`
- **THEN** the whole query buffer is still submitted

### Requirement: Respect SQL lexical boundaries

Statement selection SHALL use semicolons outside single-quoted strings,
double-quoted/backtick/bracket identifiers, line comments, DuckDB nested block comments,
and dollar-quoted strings. Doubled quote escapes and DuckDB escape-string
backslashes SHALL be respected. SQLite CREATE TRIGGER bodies SHALL stay together,
including internal statements and CASE expressions, and when prefixed by
`EXPLAIN` or `EXPLAIN QUERY PLAN`. Cursor positions SHALL use
Neovim's UTF-8 byte coordinates. The live Session's Adapter SHALL distinguish
SQLite bracket identifiers and non-nested comments from DuckDB arrays and nested
comments.

#### Scenario: Semicolon inside a string or comment
- **WHEN** the cursor's statement contains quoted or commented semicolons
- **THEN** selection includes the complete statement and excludes neighboring SQL

#### Scenario: Multiline statement with multibyte text
- **WHEN** multibyte text precedes the cursor and the selected statement spans lines
- **THEN** the exact statement is selected with the text preserved

#### Scenario: SQLite trigger definition
- **WHEN** the cursor is inside a CREATE TRIGGER body containing multiple statements
- **THEN** selection includes the entire trigger definition rather than executing a body fragment

#### Scenario: Explain a trigger definition
- **WHEN** the cursor is inside the body of an `EXPLAIN` or `EXPLAIN QUERY PLAN` trigger definition
- **THEN** selection preserves the complete explain statement
- **AND** invoking the command does not execute a body fragment or create the trigger

### Requirement: Define delimiter and incomplete-input behavior

A cursor on a terminating semicolon SHALL select the preceding statement.
Whitespace and comments between statements SHALL belong to the following
statement. Empty/comment-only remaining input SHALL send no request and provide
an informational message. An unterminated quoted string, identifier, block
comment, or trigger body in the selected statement SHALL send no request and
provide an actionable diagnostic; a later malformed statement SHALL NOT prevent
executing an earlier complete statement.

#### Scenario: Cursor between two statements
- **WHEN** the cursor follows the first semicolon in whitespace before another statement
- **THEN** the next statement is selected

#### Scenario: No executable text or incomplete SQL
- **WHEN** the selected range contains only comments or an unterminated quote/comment/trigger body
- **THEN** the Client reports the condition without executing any SQL

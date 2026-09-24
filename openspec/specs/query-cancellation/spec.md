# query-cancellation Specification

## Purpose

Let users request cancellation of an outstanding query and continue working with
truthful feedback from a supporting server, while retaining live Session state.

## Requirements

### Requirement: Cancel the latest outstanding query

The Client SHALL provide `:DbridgeCancel` to request cancellation of the latest
still-outstanding execution submitted through its editor or table execution flow.
It SHALL target that request even if the user has since changed the active Session.
Completed requests SHALL no longer be targets. If no execution is outstanding,
the command SHALL send no cancellation and SHALL report that informationally.

#### Scenario: Two executions are outstanding
- **WHEN** the user submits two queries and invokes `:DbridgeCancel` before either replies
- **THEN** the Client requests cancellation of only the second query

#### Scenario: Latest execution has already replied
- **WHEN** the second query has replied while the first remains outstanding and the user invokes `:DbridgeCancel`
- **THEN** the Client requests cancellation of the first query

#### Scenario: Active Session changes
- **WHEN** the user submits a query, selects another Session, and invokes `:DbridgeCancel`
- **THEN** cancellation still targets the submitted query

#### Scenario: Nothing is outstanding
- **WHEN** no query is outstanding and the user invokes `:DbridgeCancel`
- **THEN** no cancellation is sent and the Client reports that there is no outstanding query

### Requirement: Distinguish requesting cancellation from confirmed cancellation

The Client SHALL report a server-confirmed cancellation informationally, preserve
the existing results display, and allow subsequent execution on the same Session.
Sending a cancel request SHALL NOT itself claim the query was cancelled or discard
its callback. If a normal result arrives, including when cancellation is unsupported
or loses a race, the Client SHALL render that result normally. Other execution
errors SHALL remain errors.

#### Scenario: Query cancellation is confirmed
- **WHEN** a supporting server confirms that an editor query was cancelled
- **THEN** the Client reports cancellation at informational level and preserves displayed results
- **AND** the user can execute another query on the same Session

#### Scenario: Query completes normally after cancellation was requested
- **WHEN** the Client requests cancellation but receives a normal query result
- **THEN** the result is rendered and no confirmed-cancellation message is shown

### Requirement: Forget stopped-process cancellation targets

The Client SHALL remove pending request and execution tracking when its server
process stops. A cancellation action after stop or restart SHALL NOT target a
request from the previous process.

#### Scenario: Server stops with a pending query
- **WHEN** the server stops while a query is pending and the user invokes `:DbridgeCancel`
- **THEN** the Client reports no outstanding query and sends no stale cancellation

### Requirement: Keep completion usable during an outstanding query

The Client SHALL continue submitting and presenting completion while a query is
outstanding. It SHALL route replies to their own callbacks regardless of reply
order. Server execution and metadata concurrency remain server-owned contracts.

#### Scenario: Completion overtakes a DuckDB query
- **WHEN** a query is outstanding on a supporting DuckDB Session and the user requests completion in its SQL buffer
- **THEN** completion suggestions appear before the query replies
- **AND** the user can subsequently cancel that query without losing the Session

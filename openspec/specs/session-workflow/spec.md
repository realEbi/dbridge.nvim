# session-workflow Specification

## Purpose

Make database targeting visible and preserve live Session state while the Neovim Client refreshes schema metadata.

## Requirements

### Requirement: Metadata refresh preserves the live Session

Refreshing a connected Profile or its descendant SHALL refresh metadata using its existing Session without connecting a replacement or disconnecting that Session. The active target and database state SHALL remain available.

#### Scenario: Refresh an in-memory database
- **WHEN** a connected in-memory database contains data and a temporary table and the user refreshes its schema
- **THEN** the same Session ID remains bound, new schema objects appear, and both data and temporary state remain queryable

#### Scenario: Refresh fails
- **WHEN** cache refresh or any required metadata listing fails
- **THEN** the Client reports the failure and retains the Session binding and previous displayed metadata

#### Scenario: Refresh reply arrives after deletion or another refresh
- **WHEN** a pending refresh reply belongs to a removed Profile or an older refresh
- **THEN** it does not restore deleted nodes or replace newer metadata

### Requirement: Query target is visible and truthful

The query editor SHALL identify the active target's Profile name, live Session adapter, and Session ID using the same selection as execution and completion. It SHALL show an explicit no-active-Session state when no target is available and SHALL not display configuration secrets.

#### Scenario: Multiple connected Profiles
- **WHEN** the user interacts with a connected Profile and returns to the query editor
- **THEN** the indicator names the Session receiving execution and completion requests

#### Scenario: Explorer focus changes target
- **WHEN** the explorer cursor is over a connected Profile and focus moves between explorer and query editor
- **THEN** the indicator follows the same target-selection priority as SQL operations in the focused panel

#### Scenario: Active Profile is deleted
- **WHEN** the active Profile is successfully deleted
- **THEN** the indicator shows the remaining selected Session or the explicit no-active-Session state

#### Scenario: Connection or deletion fails
- **WHEN** connecting or deleting a Profile fails
- **THEN** the indicator retains the actual existing target and does not claim the failed operation succeeded

#### Scenario: Server stops
- **WHEN** the Client knows the server process has stopped
- **THEN** it clears invalid Session bindings and metadata and shows no active Session

#### Scenario: Profile display contains formatting characters
- **WHEN** a Profile name contains percent signs or control characters
- **THEN** the indicator treats it as display text without interpreting statusline expressions

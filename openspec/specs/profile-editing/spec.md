# profile-editing Specification

## Purpose

Define how the explorer edits and renames a Profile so that its tree, stored
Profiles, and live Session stay consistent whether the save succeeds or fails.

## Requirements

### Requirement: Rename a Profile without leaving the old one

When the user edits a Profile and changes its name, the Client SHALL ask the server
to save the new definition in place of the edited Profile in one request. After the
server confirms, the explorer SHALL show one node for the Profile under its new name,
and a later listing of Profiles SHALL NOT contain the old name. Editing without a
name change SHALL update that Profile in place.

#### Scenario: Rename a Profile
- **WHEN** the user edits Profile `old`, enters the name `new`, and confirms
- **THEN** the explorer shows `new` and not `old`, and reloading Profiles from the
  server shows only `new`

#### Scenario: Edit config without renaming
- **WHEN** the user edits Profile `a`, keeps the name, and changes its config
- **THEN** the explorer still shows one `a` node, and the server stores the new config

### Requirement: Keep the previous Profile when a rename fails

When the server rejects an edit, the Client SHALL leave the node's name, adapter,
config, and Session binding unchanged and SHALL report the server's error message.
It SHALL NOT remove or overwrite another Profile's node.

#### Scenario: New name already used
- **WHEN** Profiles `old` and `taken` exist and the user renames `old` to `taken`
- **THEN** the Client reports that the Profile already exists, and the explorer
  still shows `old` and `taken` with their previous definitions

#### Scenario: Edited Profile no longer exists on the server
- **WHEN** the edited Profile was removed from the server before the user confirms
- **THEN** the Client reports the failure and does not add a node for the new name

### Requirement: Renaming a connected Profile keeps its Session

Renaming a connected Profile SHALL keep its live Session binding and scope state.
The query-editor indicator SHALL show the new Profile name for that Session, and the
Session SHALL keep executing with the configuration it connected with.

#### Scenario: Rename while connected
- **WHEN** the user renames a connected, active Profile from `old` to `new`
- **THEN** the indicator names `new` with the same Session ID, and executing SQL in
  the query editor still uses that Session

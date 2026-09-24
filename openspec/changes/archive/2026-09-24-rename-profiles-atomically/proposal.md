## Why

Editing a Profile's name in the explorer saves the new name and leaves the old
Profile stored, and renaming onto an existing Profile silently overwrites it. The
linked server change [`rename-profiles-atomically`](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-24-rename-profiles-atomically)
adds `previous_name` to `dbridge/saveProfile`, so a rename is one request that either
fully succeeds or changes nothing. This change uses it. It resolves
[backlog 001](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/001-profile-rename.md)
and completes the Profile part of roadmap outcome 1.

## What Changes

- The explorer's edit flow (`e`) sends the Profile's current name as `previous_name`.
- On success the node shows the new name, keeps its Session binding, and the query
  editor indicator shows the new name for a connected Profile.
- On failure, including a name already used by another Profile, the explorer keeps
  the node's previous name and definition and reports the server's error message.
- Adding a Profile keeps today's upsert behavior.

## Capabilities

### New Capabilities

- `profile-editing`: What the explorer shows and keeps when a user edits or renames
  a Profile, including failure feedback and live-Session preservation.

### Modified Capabilities

None. `session-workflow` keeps its indicator requirements; renaming updates the name
through the existing target descriptor.

## Impact

This repository owns `explorer.lua` and `profiles.lua` edit handling, client tests,
and README keymap text. The server owns `saveProfile`, `previous_name`, and the
`PROFILE_ALREADY_EXISTS` error; this change does not restate that contract.

The client requires the linked server change: an older server ignores
`previous_name` and upserts, which reproduces the duplicate. Merge the server change
first. Verify the pair with a real server, child Neovim, and isolated Profiles.

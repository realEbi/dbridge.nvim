## Context

Profile prompts and persistence wrappers live in `profiles.lua`; the explorer
owns nodes and live Session bindings keyed by node ID. The linked server change
adds the persistence operation described in the [proposal](proposal.md).
The existing successful-save callback already updates a node in place and its
scheduled render refreshes the shared query target descriptor.

## Goals / Non-Goals

Carry the original Profile name through the asynchronous edit request, and retain
the node and Session identity until the server confirms success. Persistence,
collision detection, and atomicity stay on the server. Adding a Profile retains
its existing upsert behavior.

## Decisions

- Add an optional trailing `previous_name` to the save wrapper and interactive
  prompt helper. Existing callback positions remain compatible. The explorer
  supplies the name captured when editing starts, including same-name edits;
  defaults alone do not imply a rename when creating a Profile.
- Keep the successful-save callback as the only node mutation path. A separate
  delete request or optimistic node mutation would create partial local or
  persisted state on failure. Server errors retain their messages and severity.
- Keep the existing node, Session binding, and scope state after a rename. The
  existing render/target selector derives its display name from that same node,
  so no parallel name cache or reconnect operation is needed.

## Risks / Trade-offs

- An older server ignores `previous_name` and reproduces duplicate Profiles →
  document the required linked server version and deploy the server change first.
- UI and persisted state can diverge after failed edits → verify collision and
  missing-source errors against the real server, including the unchanged node.

## Migration Plan

Merge and deploy the linked server change before this client. No Profile file
migration is needed. Reverting the client restores its previous edit behavior;
ordinary save requests remain supported by the updated server.

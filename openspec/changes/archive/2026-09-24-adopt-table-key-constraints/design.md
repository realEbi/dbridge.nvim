## Context

The real-server transport test currently inspects the old table-key field. Client
runtime modules do not consume primary or foreign keys. The linked server change
in the [proposal](proposal.md) owns their new DSP representation.

## Goals / Non-Goals

Verify that the client transport decodes the updated server response, while
leaving editor behavior and the server-owned key contract unchanged here.

## Decisions

- Replace the existing SQLite primary-key assertion with the new object and an
  explicit assertion that the old field is absent. Assert JSON null as `vim.NIL`,
  preserving the transport's decoded value. Accepting either field shape would
  hide whether the selected server actually supplies the updated contract.
- Keep `skip_specs: true`: this changes integration verification, not a client
  capability. Key semantics and adapter coverage remain server responsibilities.
- Select the paired server explicitly for positive integration checks and use
  the pre-change server revision for the negative check. The remaining runtime
  suite verifies that removing unused metadata fields does not disrupt the UI.

## Risks / Trade-offs

- Older servers fail this test → document the required server change and merge
  the server first. No production compatibility adapter or key display is needed.

## Migration Plan

Merge the linked server change first, then this client test update. No user data
or runtime migration is required. Reverting the test requires selecting the older
server schema for its assertions to pass.

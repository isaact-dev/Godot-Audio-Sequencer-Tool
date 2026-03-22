# Design Decisions

This file tracks design decisions for the Godot Audio Sequencer Tool.

---
## 2026-03-18 — Initial focus on UI

### Decision

The focus of the initial development will be on creating the UI.

### Reasoning

This tool is primarily an editor-facing workflow tool, so usability and interface structure are central to the project.
By building the UI first, it is easier to test if the logic and systems work correctly and if the tool is intuitive to use.

A visible interface also makes progress easier to evaluate and helps guide later implementation decisions.

## 2026-03-20 — Clip timing behavior

### Decision

Clips should not be treated as strictly grid-sized blocks.

### Reasoning

Clips will almost never line up with the music timeline. 
The start of a clip should initially snap on the timeline but should also be able to be moved without snapping for micro-adjustments.

The timeline should therefore support:
- musically aligned starting positions
- natural clip durations
- small timing offsets when needed

### Consequences

The fake clip system using dictionaries created on 2026-03-20 should be updated to allow clips that are not the exact length of musical intervals.

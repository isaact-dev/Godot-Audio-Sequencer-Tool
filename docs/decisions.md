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

## 2026-03-20 — Centralize clip rectangle creation in a helper function

### Decision

Clip rectangle creation should be centralized in a helper function.

### Reasoning

Creating a helper function for centralizing clip rectangle creation to simplify future features such as:
- selection
- hover
- dragging
- resizing

All systems that depend on clip geometry will use the same calculation source

## 2026-03-20 — Clicking clips should prioritize selecting the top clip

### Decision

When detecting which clip was clicked, the clip array should be checked in reverse order so that the clip drawn last is prioritized.

### Reasoning

This matches the visual layers of the timeline. The clip that appears on top should be the one that gets selected.
Even if overlapping clips are not intended in the final version, this rule provides behavior for temporary overlaps, test data, or future edge cases.


## 2026-03-21 — Hover state should be tracked separately from selection state

### Decision

Hover state should be tracked separately from selection state so the timeline can distinguish between the currently selected clip and the clip currently under the cursor.
This way a clip can be selected whilst another is hovered over.

## 2026-03-21 — Clip dragging should preserve the mouse’s relative grab offset inside the clip

### Decision

Clip dragging should preserve the mouse’s relative grab offset inside the clip so the clip does not jump when dragging begins.
This is done by adding drag state variables.

## 2026-03-21 — Initially focus on horizontal dragging

### Decision

By focusing on horizontal dragging first, a lot of complications are avoided. 
It is important that the snapping and micro-adjustments in the horizontal direction are as user friendly as possible.
Track switching will be implemented later.

## 2026-03-26 — Dragging should use snap by default but allow a temporary snap override / adjustments should be possible with arrow keys

### Decision
Dragging should use snap by default but allow a temporary snap override so users can make quick off-grid micro-adjustments without changing the global snap setting.
This should be done by using the shift key as a hold hotkey.
Adjustments shoud also be able to be made using the arrow keys.
Microadjustments should also be able to be made with the arrow keys while holding shift.

For this to work, focus should be assigned to the correct control node to override default arrow key behaviour in the editor.

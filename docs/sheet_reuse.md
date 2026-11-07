# Reusing the generic sheets

Status: analysis, 2026-11-07. Nothing below is implemented yet.

In 2.9.15 the macro, spool, printer actions (non-printing), services, job queue and confirmation sheets were redesigned.
They were built as their own widgets on two new shared pieces (`SheetSearchHeader`, `SheetRow` in
`common/lib/ui/components/`) instead of on the two generic sheets the app already had. This document checks, sheet by
sheet, whether the generic sheets could have been used, and what they would need for it.

**Short answer:**

- **Printer actions:** yes, `ActionBottomSheet` is the right sheet. It needs small additions.
- **Spools:** mostly. `SelectionBottomSheet` needs per-option search text, a subtitle widget and filter chips. The QR
  scanner would become its own page.
- **Services, macros, job queue:** no. Their rows have several actions or live state, which neither generic sheet
  supports. They should keep their own widgets but share the header and row with the generic sheets, so there is still
  one look.

## The generic sheets today

### `ActionBottomSheet` (`lib/ui/components/bottomsheet/action_bottom_sheet.dart`)

Menu of actions, e.g. the file menu (`FileInteractionService.showFileActionMenu`), the overview group actions, and the
theme actions.

- **Header:** `ActionBottomSheetArgs.title` / `subtitle` / `leading` / `trailing` (widgets).
  - It has a 10dp gap above the title and a `Divider()` (16dp) below it.
  - The title uses the ListTile default style (≈16sp).
  - When the route was pushed onto another sheet, it shows a back button.
- **Rows:** `BottomSheetAction` (mixin, usually on an enum), with `icon`, `labelTranslationKey` and `enabled`
  (`.enable` / `.disable` helpers).
  - `DividerSheetAction.divider` separates groups.
  - On M3 a row is a ListTile, indented 8dp and rounded on the left.
- **Result:** pops with `BottomSheetResult.confirmed(action)` and the caller handles the action.
- **Chaining:** `onActionSelected` (instead of popping) keeps the sheet open so the caller can stack another sheet on it.
  The group actions use this for actions → selection → confirmation (`group_actions_fab.dart`).

### `SelectionBottomSheet<T>` (`lib/ui/components/bottomsheet/selection_bottom_sheet.dart`)

Pick one (or several) values, e.g. the bed mesh profiles, tool selectors and Spoolman form pickers.

- **Header:** `title` / `subtitle` (widgets) and an optional search field (`showSearch`). The search is debounced
  (400ms) and ranked by `String.searchScore` with a cut-off of 150, best match first. It only searches the **label**.
- **Rows:** `SelectionOption<T>` with `value`, `label`, `subtitle` (String), `leading` / `trailing` (widgets), `enabled`,
  `selected` (tinted), `horizontalTitleGap` and `titleAlignment`.
  - On M3 a row is a ListTile, indented 12dp and rounded on the left; M2 rows are flat.
  - There are no dividers between rows.
- **Options:** a `List` or a `Future<List>`, loaded once. They do not update while the sheet is open.
- **Result:** single select pops with `confirmed(value)`. Multi select adds a Select button. `onConfirmed` replaces the
  pop, for local navigators.
- **Empty state:** an illustration plus "no selections".

## Sheet by sheet

### Printer actions (`non_printing_bottom_sheet.dart`): use `ActionBottomSheet`

This is a menu of actions with a group divider, which is exactly what `ActionBottomSheet` is. The flow it needs
(action → maybe another sheet → confirmation → run) is the same as the group actions.

| Needs | `ActionBottomSheet` today | Change |
|---|---|---|
| Title "Printer Actions" with the printer name below | `title` / `subtitle` | none |
| Group divider (Services/Job Queue, then firmware/host) | `DividerSheetAction.divider` | none |
| Open Manage Services / Job Queue on top | `onActionSelected` + `bottomSheetService.show` | none |
| Confirmation, then run | the caller shows `SheetType.confirm` (like the group actions) | none |
| A description per action | – | add an optional `subtitleTranslationKey` (default `null`) to `BottomSheetAction` |
| Orange/red for restart/shutdown | – | add a `tone` (`normal` / `warning` / `danger`) to `BottomSheetAction`, which the sheet maps to `CustomColors` |
| Chevron on rows that open another sheet | – | add `bool get opensSheet => false` to `BottomSheetAction` |
| Long press skips the confirmation | – | add `onActionLongPressed` to `ActionBottomSheetArgs` (same contract as `onActionSelected`) |
| The "long press to skip" note | – | add an optional `footer` widget to `ActionBottomSheetArgs` |

How it would look:

- A `NonPrintingSheetAction` enum (`manageServices`, `jobQueue`, `firmwareRestart`, `hostRestart`, `hostShutdown`) with
  the new getters.
- The logic in `NonPrintingBottomSheet.onPressButton` moves to whoever opens it today: the dashboard's `_IdleFAB`, or a
  small controller.
- Then `SheetType.nonPrintingMenu` and its route can go. Manage Services becomes a normal sheet opened with
  `bottomSheetService.show` (or stays a nested route reached through `onActionSelected`).

All new getters are optional, so the existing file, group and theme actions keep working unchanged. If they want, they
can gain descriptions or danger tones too (e.g. "Delete" in red).

Effort: small. It is about four getters/args, one enum, and moving roughly 40 lines of action handling.

### Spools (`mobileraker_pro/lib/spoolman/ui/select_spoolman_sheet.dart`): `SelectionBottomSheet`, with additions

Picking the active spool is a single selection. Today the sheet sets the spool itself. With the selection sheet, it
would pop the chosen spool and the caller (card / file details controller) would call `setActiveSpool` and show the
error snackbar. That is arguably cleaner: the sheet only selects.

| Needs | `SelectionBottomSheet` today | Change |
|---|---|---|
| Load all spools | `options: Future<List>` from `spoolListProvider(machineUUID).future` | none |
| Active spool tinted and first | `selected: true`, the caller sorts the options | none |
| Spool icon in its color | `leading: SpoolWidget(...)` | none (set `horizontalTitleGap`) |
| `#id name`, vendor – material · location | `label`, `subtitle` | none |
| Remaining-filament bar and grams | only a String subtitle | add `Widget? subtitleWidget` (or `bottom`) to `SelectionOption` |
| Search vendor, material, location, `#id` | label only | add `String? searchText` to `SelectionOption`, scored like the label (max of both) |
| Material chips | – | add generic filters: `List<SelectionFilter<T>> filters` with a label and a predicate, shown as the chip row |
| QR scanner | – | add `Widget? searchAction` to the args (the header already supports it). It opens a scanner page on top (`onConfirmed` / stacking) that returns the spool id, and the sheet then pops with that spool |
| Spinner on the row while saving | – | no longer needed, saving happens after the pop |

The filters and `searchText` would also help other selections: e.g. the Spoolman form pickers (filament by vendor) and
the tool selectors.

Effort: medium. The changes are three additions to `SelectionOption`/args, a scanner page split out of `_ScanSpoolQr`,
and moving `setActiveSpool` and its error handling to the callers (`SpoolmanCard`, `GCodeFileDetailsController`).

### Manage services (`manage_services_bottom_sheet.dart`): keep it

- **Several actions per row:** each service has start/restart/stop. The generic sheets pop with one value per row.
  - Selecting a service and then opening an action sheet for it would work. It costs one more tap for every restart, and
    restarting Klipper is the most common use.
- **Live state:** after a restart, a row has to change from Running to Stopped and back. `SelectionBottomSheet` options
  are a one-shot `List`/`Future`. Supporting this would mean options from a `Stream` or a provider, which is a larger
  change to the sheet's core.

Keep the widget, but build it from the shared pieces (see below).

### Macros (`macros_bottom_sheet.dart`): keep it

The macro sheet needs:

- inline parameter forms that expand in the list
- sent feedback on the row
- long press to skip the parameters
- group chips plus "Recent"
- search over name and description
- live `canReceive` state

Its rows are a small form, not a selectable option. With `searchText` and filters, `SelectionBottomSheet` could cover the
search and chips, but not the expanding rows without an "expanded builder". That would turn it into a different sheet.

### Job queue (`mobileraker_pro/lib/job_queue/ui/job_queue_sheet.dart`): keep it

The job queue needs drag to reorder, swipe to remove, header actions and live queue state. None of that fits a
selection.

### Confirmation (`common/lib/ui/bottomsheet/confirmation_bottom_sheet.dart`): already the generic one

It is the shared confirmation sheet and is used everywhere. Nothing to do.

## One look: share the pieces, not just copy them

Even for the sheets that keep their own widget, the look should come from one place. Today it comes from three:

| | `SelectionBottomSheet` | `ActionBottomSheet` | `SheetSearchHeader` / `SheetRow` (new sheets) |
|---|---|---|---|
| Header | `_Title`: ListTile + search + `Divider(height: 0)` | ListTile with a 10dp gap above + `Divider()` (16dp) | ListTile + search + chips + `Divider(height: 0)` |
| Title size | ListTile default (≈16sp) | ListTile default (≈16sp) | headlineSmall (24sp) |
| M3 row indent | 12dp | 8dp | 12dp |
| M3 row background | none (tint when selected) | none | faint `onSurface` 4% |
| Back button | ListTile `leading`, default padding | ListTile `leading`, `minLeadingWidth: 42` | `leading`, padding trimmed to line up at 16dp |

Proposal:

1. Make `SheetSearchHeader` the header of both generic sheets: `_Title` and `ActionBottomSheet`'s column become a
   `SheetSearchHeader` call.
2. Make `SheetRow` the row shape of both generic sheets: `_Entry` keeps its ListTile content but wraps it in
   `SheetRow(highlighted: selected)`.
3. Agree on the open details:
   - **Title size:** 16sp everywhere, or 24sp everywhere.
   - **Row indent:** 8dp or 12dp.
   - **Resting background:** whether M3 rows get the faint background everywhere or nowhere.

After that, any change to the look is one change.

## Suggested order

1. **Shared pieces in the generic sheets** (no visible change apart from the decided details). This is the base for the
   rest.
2. **Printer actions → `ActionBottomSheet`**, with the four small additions. This removes a custom sheet, and the file
   and group menus can then use descriptions and danger tones.
3. **`SelectionBottomSheet` additions** (`searchText`, `subtitleWidget`, filters, `searchAction`), then **spools → selection**,
   with the scanner as its own page.
4. **Services, macros, job queue:** stay custom on the shared pieces. Services can be revisited if the selection sheet
   ever gets live options.

## Found while checking (fixed)

All three are fixed. The selection sheet's header now sizes itself, and both generic sheets label the back button
"Back".

- `SelectionBottomSheet` logs on every build (`talker.warning('SelectionBottomSheet: …')`) and for every scored option
  while searching (`talker.warning('Score: …')`). These are debug leftovers at warning level.
- `SelectionBottomSheet._Title.preferredSize` is hard-coded (`kToolbarHeight + 62 + 15`). It breaks with larger fonts or
  a two-line subtitle.
- `ActionBottomSheet`'s back button uses `closeButtonTooltip`, while the new sheets use `backButtonTooltip`.

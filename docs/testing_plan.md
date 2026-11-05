# Testing plan: widget tests for Mobileraker

_Status: proposal 2026-11-04. Phase 0 (harness) and phase 1 (leaf widgets in `common`) done 2026-11-04._

## Where we are

| Package | Tests | What they cover |
|---|---|---|
| `common` | 79 | JSON marshalling (most), utils, five service/notifier tests with mockito (`printer_service`, `klipper_notifier`, …), **one** widget test (`AnimatedLockIcon`) |
| `mobileraker` | 5 | Utils, spectrum analyzer, one overview helper. `test/widget_test.dart` is still the Flutter counter template and fails |
| `mobileraker_pro` | 1–2 | Unit only |

So the data layer is in decent shape and the UI has almost nothing. No CI runs the tests (the only workflow builds Android on tags).

## Is Riverpod 3 making this easy?

Mostly yes. A widget test is "pump the widget inside a `ProviderScope` with overrides" and Riverpod 3 makes the
overrides short (`printerProvider(uuid).overrideWith(...)`, `overrideWithValue`, `ProviderContainer.test()`).
The things that will bite, and how we handle them:

| Problem | Where | Fix |
|---|---|---|
| Card controllers are **private** codegen providers (`_multipliersCardControllerProvider`), so tests can't override them | All dashboard cards | Override the **public** providers they read instead (`printerProvider`, `klipperProvider`, `machineSettingsProvider`, settings). That also tests the controller. For pure rendering, the cards' existing `preview()` widgets already ship fake controllers |
| Settings read `Hive.box('settingsbox')` directly | `setting_service.dart`, `machine_service.dart`, … | Harness opens Hive in a temp dir (`Hive.init(tmp)`) once per test file, or override `settingServiceProvider` with an in-memory fake where possible |
| Riverpod 3 **retries failed providers** with timers → "A Timer is still pending" | Any error-state test | Harness sets `ProviderScope(retry: (_, _) => null)` |
| `.tr()` needs easy_localization | Every page | Harness loads the real `en.json` once, so finders use real strings (`find.text('Print')`) and missing keys show up as failures |
| Riverpod 3 delivers provider changes to widgets **one frame later**, so after `controller.add(...)` / a notifier update one `pump()` still shows the old state | Every test that changes provider state | `await tester.pumpProviders()` (two pumps) |
| Infinite animations (Shimmer skeletons, progress indicators) make `pumpAndSettle` time out | Loading states | Use `pump(duration)` for loading states; `pumpAndSettle` only once data is there |
| Firebase, ads, purchases, notifications are initialised in `main()` | Pages that touch payment / analytics | Never pump `main()`/`MyApp`. Override `paymentServiceProvider` etc. with fakes in page tests |

## The harness (phase 0, prerequisite for everything) ✅

A small local package **`test_support`** (in this repo, `dev_dependency` of `common`, the app and
`mobileraker_pro` via path). A separate package keeps `flutter_test` out of `common`'s real dependencies and lets
all three repos share it.

```dart
await tester.pumpApp(
  const MultipliersCard(machineUUID: 'm1'),
  overrides: [
    printerProvider('m1').overrideWith((_) => Stream.value(PrinterFixtures.printing())),
    klipperProvider('m1').overrideWith((_) => Stream.value(KlipperFixtures.ready())),
  ],
  device: TestDevice.phone,      // phone 411×914, tablet 1280×800, duoInnerLandscape, duoCover, …
  theme: ThemeMode.dark,         // optional
  locale: const Locale('de'),    // optional, for overflow checks with long strings
);
```

It contains:

- **`pumpApp`**: ProviderScope (no retry) → easy_localization (real `en.json`) → `MaterialApp` with our theme →
  `ResponsiveBreakpoints` (same breakpoints as the app) → `FoldBridge`-compatible `MediaQuery`.
  `pumpRouterApp` does the same with a `GoRouter` for shell and page tests.
- **`TestDevice`**: sets `tester.view.physicalSize`/`devicePixelRatio` and `viewPadding`. The Duo poses come from
  `duo_kit`'s `FoldTestPose`, so the strip is real geometry, not hand-written padding.
- **Fixtures** (_started: `Fixtures.machine/klipper/printer/folder/gcode`, `connectedMachineOverrides` (machine, connected client, `FakeKlipper`, `FakePrinter`), `remoteConfigOverrides`; more with phase 2_): `PrinterFixtures`, `KlipperFixtures`, `MachineFixtures`, `GCodeFileFixtures`, `SpoolFixtures`, built
  on the existing DTO constructors / `PrinterBuilder` and the JSON in `common/test_resources`. One place to fix
  when a DTO changes.
- **Fakes/mocks** (_started: `FakeJsonRpcClient` records calls_): mockito stays (already used). Fakes for the services pages call (`PrinterService`,
  `FileService`, `DialogService`, `SnackBarService`, `BottomSheetService`) that record calls, so a test can say
  "tapping +10% sent `M220 S110`".
- The broken counter `test/widget_test.dart` is removed; `test_support/test/pump_app_test.dart` checks the harness.

### How to use it

```dart
void main() {
  setUpWidgetTests(); // logger, translations, in-memory Hive (cleared after each test)

  testWidgets('…', (tester) async {
    await tester.pumpApp(const MyWidget(), device: TestDevice.tablet, overrides: [...]);
    source.add(value);
    await tester.pumpProviders();
    expect(find.text('…'), findsOneWidget);
  });

  // The Duo devices report their strip only on iOS (duo_kit's detection):
  testWidgets('…', (tester) async { ... }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
```

Notes from building it:

- `setUpWidgetTests` loads the bundled NotoSans as "Roboto" (`loadTestFonts`). With the default test font (square
  glyphs, about twice as wide) layouts overflowed that fit on devices.
- Providers using `ref.keepAliveFor()` start a 30 s timer when their last listener goes away, also while the test
  tears the tree down ("A Timer is still pending even after the widget tree was disposed"): end such tests with
  `await tester.unmountApp()`.
- Pages with infinite animations (loading spinners, the Overview cards) never settle: pump a fixed time instead of
  `pumpAndSettle`.
- `isSupporter` is always true in debug builds (tests too): override `isSupporterProvider` for non-supporter UI.
- Scroll things below the fold into view before tapping: `await tester.ensureVisible(finder)`.
- No formatter config in the repo, so `dart format` defaults to 80 columns; the code uses 120:
  `dart format -l 120 <new files>`.

- `tr()` has to run inside a `build` (e.g. a `Builder`), not while creating the widget passed to `pumpApp`, since the
  translations load during the first frames.
- The Pixel Tablet in landscape (1280 wide) is wider than the last breakpoint (1200), so the breakpoint name is
  `null` there (same as in the app); `isLargerThanCompact` is still true.
- Create `StreamController`s etc. inside the test (or a helper it calls), not in `setUp`.
- Riverpod's own `tester.container()` returns the app's container; pages with nested `ProviderScope`s need
  `tester.container(of: find.byType(MaterialApp))`.
- Pages: `connectedMachineOverrides(Fixtures.machine())` (selected machine, connected `FakeJsonRpcClient`) and
  `remoteConfigOverrides()` (no Firebase) cover most of what a page needs; override the data provider of the page
  (e.g. `moonrakerFolderContentProvider.overrideWith((ref, args) => ...)` for a whole family). Pro providers
  (e.g. `jobQueueProvider`) are overridden in the app's tests, `test_support` can't depend on pro.

### Pre-existing failing tests (fix before CI)

- `common`: `historical_print_job_marshalling_test.dart` (HistoricalPrintJob fromJson),
  `printer_service_test.dart` (JRPC timeout during build …).
- App: `spectrum_analyzer_test.dart` calls the real `setupLogger()` (needs path_provider) in `setUpAll`.

### Findings from the tests so far

Open:

- Spoolman list-detail (tablet width, spool in the pane): the side-by-side "Alternative spools" cards
  (`IntrinsicHeight` + `Row(stretch)` in `spool_detail_page.dart`) are measured 56 px tall while their entries need
  68 px, so `SpoolmanStaticPagination`'s column overflows by 12 px (also with short names, not a font artefact).
  Test skipped: `spoolman_page_test.dart` "spool details next to the list on a tablet".
- Dashboard edit mode on tablets (medium layout): pages can't be added, removed or given another icon. The add page
  "+" and the icon editing live in the bottom navigation bar (phones only) and the medium layout ignores `onRemove`
  (no "Remove Page" button). Test skipped: `dashboard_medium_layout_test.dart` "editing: pages can be removed on
  tablets too".
- Spool form (edit): clearing a number field (price, weights) can't remove the value. The empty field becomes `null`,
  which `UpdateSpool` leaves out (`includeIfNull: false`), so an empty update is sent and the old value stays. Text
  fields are fine (sent as ""). Test skipped: `spool_form_page_test.dart` "clearing a number removes it from the
  spool".
- Spool, filament and vendor forms with a decimal-comma locale (e.g. German): numbers are shown as "19,99" but
  validated/parsed with `num.tryParse`, so "The value must be numeric" blocks saving any entry with a decimal value.
  Tests skipped: "with a decimal comma, saving without changes makes no update" (spool, filament and vendor form).
- Filament form: a 6-digit Spoolman color comes back from the color field as 8 digits (with alpha), so saving an
  unchanged filament always sends `colorHex` instead of "No changes made!". Test skipped:
  `filament_vendor_form_page_test.dart` "saving without changes makes no update".
- Filament form: requires a vendor, Spoolman doesn't; filaments without vendor can't be edited. Test skipped: "a
  filament without vendor can be edited".
- Vendor form: there's no external ID field, so vendors with one (SpoolmanDB imports) always count as changed and get an
  empty update. Test skipped: "saving without changes makes no update also for vendors with an external ID".
- Spool details: the filament link uses `goNamed` (vendor and spools push), so back skips the spool page. Test
  skipped: `spoolman_detail_pages_test.dart` "the filament opens its page, back returns to the spool".
- File manager rename: the used names have the extension, the entered name doesn't, so renaming `benchy` to `cube`
  passes validation and moves onto the existing `cube.gcode`. Test skipped: `file_manager_flows_test.dart` "rename
  rejects the name of another file in the folder".
- G-code details: a print state change sets `canStartPrint` without checking Klipper, so Print is enabled e.g. after
  an error while Klipper is shut down. Test skipped: `gcode_file_details_page_test.dart` "print stays disabled when the
  print ends while Klipper can not receive commands".
- Spoolman card (pro): a filament without vendor, material or name shows "null – null" / "#7 null". Test skipped:
  `spoolman_card_test.dart`.
- G-code preview card (pro): without download progress it shows the raw key `components.gcode_preview.loading.progress`
  (missing translation). Test skipped: `gcode_preview_card_test.dart` "shows what it does while the progress is
  unknown".

Fixed (2026-11-04, each with its test unskipped or added):

- `KlippyProviderGuard` "unauthorized": the printer settings button pushed the `machine()` provider function as
  `extra`, the edit route's cast threw.
- Macro params dialog: untouched params without default came back as `null`, the macro card threw on `!`.
- G-code details: Print stayed enabled during a print (`||` instead of `&&`); clearing the active spool threw; the
  nozzle diameter list showed as "[0.4] mm".
- Firmware retraction card: the loading placeholder built the body, which threw once firmware retraction was removed.
- Spoolman list-detail: the embedded details' FAB hero clashed with the Spoolman page's FAB (now `HeroMode` off).
- Control XYZ (8 px) and Z offset (20 px) cards overflowed on 360 wide phones.
- Selection bottom sheet search listed the best match last.
- Number edit dialog keyboard had no decimal separator, also with fraction digits.
- Temperature presets sent the bed temperature on printers without a heater bed.
- `SpoolListEntry` (pro): long names overflowed (name column now `Expanded`, texts ellipsize).
- Fans card: the speed dialog always said "Part Fan".
- Settings: removed the dead "Group Slider Cards" switch (`groupSliders` is read nowhere).
- G-code commands with double spaces (`M220  S`, `SET_FAN_SPEED  FAN=`, `SET_HEATER_TEMPERATURE  HEATER=`) and trailing
  spaces (`G28 `, macros without params).
- `SliderOrTextInput`: tapping edit now focuses the text field.
- `SingleValueSelector(values: [])` failed its own assert.
- Spool, filament and vendor forms: entries with `extra: null` always got an update.

## Phases (bottom up)

### Phase 1: leaf widgets (`common/lib/ui/components`) ✅

Constructor-driven, no or one provider. Quick wins that also prove the harness.

| Widget | What to test |
|---|---|
| `SliderOrTextInput` | slider ↔ text switch, value clamping, `onChange` only on commit, lock state |
| `SingleValueSelector` | selection, disabled state |
| `AsyncButton` / `AsyncGuard` | loading → data → error, button disabled while running, error widget shown |
| `WarningCard`, `ErrorCard`, `SimpleErrorWidget`, `InfoCard` | title/body/action rendering, action callback |
| `SpoolWidget`, `PrintBedPainter` | colour/size props (small paint checks) |
| `ResponsiveLimit` | max width applied per breakpoint |
| `SwitchPrinterAppBar` | _moved to phase 2 (needs machine fixtures)_ |

~10 test files.

### Phase 2: dashboard cards (`lib/ui/screens/dashboard/components`)

Data comes from public providers + fixtures; actions go to fake services.

- **One smoke test for every card** ✅ (`test/widget/ui/components/dashboard_card_test.dart`, 360 wide / phone /
  dark): each card's `preview()` renders without exceptions or overflows at phone and
  tablet widths, light and dark. Cheap and catches most layout regressions (there are ~18 cards).
- **Per card**, the states and the main interaction (_done: Multipliers, Limits, Z offset, Firmware retraction, Machine status, Fans, Pins, Temperature +
  presets, Macro groups, Control XYZ, Control extruder, Bed mesh; open: webcam, grouped sliders, pro cards_):
  - loading (skeleton) → data → error/"not available" (e.g. no fans configured)
  - Multipliers/Limits/Z-offset/Firmware retraction: change a value → correct G-code sent
  - Control XYZ / extruder: buttons disabled while printing or not homed, jog sends the right move
  - Fans/Pins/Temperature: list built from the printer fixture, slider sends `SET_FAN_SPEED`/`SET_PIN`/`M104`
  - Machine status: klippy states (ready, error, shutdown, disconnected) show the right message and actions
  - Macro groups: hidden/visible macros, macros with params open the dialog
- **Connection guards** ✅ (`KlippyProviderGuard`, `PrinterProviderGuard` in common, `MachineConnectionGuard` in the
  app): every websocket / Klippy / provider state shows the right screen, retry/reconnect/restart actions.
- **More cards and their dialogs** ✅: Grouped sliders, Power API (against the real `PowerDevices` notifier), Console
  (history, suggestions, input), number edit dialog, macro params dialog, selection bottom sheet (opened through
  the real `BottomSheetServiceImpl` in the app's sheet shell, see `test/helpers/sheet_router.dart`), text input,
  confirmation and select printer dialogs.

### Phase 3: layout and navigation (the foldable/tablet work) ✅

These are the tests that keep today's Duo/tablet work from regressing.

| Area | Cases |
|---|---|
| `NavigationRailShell` / `RailScaffold` | phone: bottom bar + drawer button, no rail · tablet: rail, no bottom bar · Duo inner landscape: rail **in the strip**, correct width/side, below `topClearance`, app bar not under the strip · Duo cover: rail · RTL: strip stays on its physical side, drawer opens from the strip side · FAB moves into the rail; switching FAB/no-FAB pages doesn't move the menu button |
| Files list-detail | width 719 → single list, 720 → list + placeholder; tapping a G-code fills the pane instead of pushing a route; selection highlight |
| Spoolman list-detail | same breakpoints; same-type entry switches the pane; tab change clears selection; delete clears the pane |
| Overview grid | 1 / 2 / 3 columns by width, capped at 3 |
| Paywall | two columns ≥ 720, single column below, logo present in loading/error states |
| Dialogs/bottom sheets | open in one half on a book-pose fold (phase 2 of the Duo plan, once built) |

### Phase 4: pages

Router-based (`pumpRouterApp`), services faked, a few flows per page instead of every branch.

- **Files**: folder navigation, sort, search, upload/create/delete dialogs → `FileService` calls, job-queue entry
  point (app bar vs FAB by layout).
- **G-code details**: start print / preheat / add to queue enabled states by printer state.
- **Printer add/edit**: form validation (URL, API key, IPv6, the existing validator cases at the widget level), save
  → `MachineService` call.
- **Dashboard**: tab switching, edit mode (reorder/remove cards), FAB speed dial actions.
- **Overview**: one card per machine, status per machine state.
- **Settings**: toggles write the setting.
- **Spoolman (pro)**: list paging, detail, create/edit forms.


_Done: printer edit page (prefill, save, validation, failing save, Klipper/connection states, delete,
supporter theme), the printer add flow (mode, simple/advanced form, connection test results, add, limits) and the
dashboard layouts (compact and medium, normal and edit mode: live cards, previews, delete, add, remove page, reorder)
and the full dashboard page (stored layout, page switching, edit mode, save through the real layout service, empty
layout validation, supporter check, discard dialog, page removal limit). Full pages need `pageExtrasOverrides()` from
`test/helpers/app_overrides.dart` (announcements, ads, consent). G-code details page (meta data, start print,
Klipper state, Spoolman material/filament warnings) and the Spoolman spool form (create with filament picker and
defaults, validation, edit with changed values only, no changes)._

_Blocked: the settings page builds its developer section with `FirebaseCrashlytics.instance` (even off-screen), so it
can't be pumped without Firebase. Reading Crashlytics through a provider would make the page testable (needs a small
app change, not done)._

### Phase 5: later / optional

- **Golden tests** for a handful of key screens (dashboard, overview, Duo layout). Goldens differ between macOS and
  Linux font rendering, so either use `alchemist` (CI-safe goldens) or run them on macOS only. Worth it once
  phases 1–3 exist, not before.
- **`integration_test`** for 1–2 real flows (add printer → dashboard) against a mocked Moonraker websocket.
  Expensive to maintain; only if the widget tests keep missing real bugs.

## Conventions

- Test files mirror `lib/`: `lib/ui/screens/files/file_manager_page.dart` →
  `test/widget/ui/screens/files/file_manager_page_test.dart` (matches the existing `test/unit/...` split).
- Find by **text or semantics** first, `Key` only where text is ambiguous. No `find.byType` on private classes.
- Test public providers, not private controllers. If something can only be reached through a private provider,
  prefer a small `@visibleForTesting` seam over test-only hacks.
- One behaviour per `testWidgets`, named as a sentence: `'tapping +10 sends M220 S110'`.
- New UI features ship with at least the phase-3-style layout test when they touch layout.

## CI

A `test.yml` workflow on pushes/PRs to `dev`: `flutter test` in `common`, `mobileraker_pro` and the app, with
`build_runner` first (generated files aren't committed). Notes:

- The Android workflow pins Flutter **3.44.4**; local is **3.47.9**. Pin the test job to the local version
  (and probably bump the Android one too).
- It needs the existing `PRO_PAT` secret to check out `mobileraker_pro`.

## Suggested order

1. Phase 0 harness + fix `widget_test.dart` + CI workflow.
2. Phase 1 (proves the harness on easy widgets).
3. Phase 3 shell/list-detail tests (protects the fresh foldable work, highest regression risk right now).
4. Phase 2 card smoke test, then per-card tests.
5. Phase 4 pages, one per PR.

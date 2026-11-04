# iPhone Duo support: feasibility & plan

_Status: feasibility checked 2026-11-04, phase 1 implemented 2026-11-04 (spike on the iPhone Duo simulator, iOS 27.1, Xcode 27.1, Flutter 3.47.9)._
_Scope: layout only. Liquid Glass is a separate later change for all iOS 26+ devices (see the end)._

## TL;DR

**It works.** A small spike app using `foldable` (native fold data) + `duo_kit` (geometry helpers) builds with
our setup (CocoaPods, iOS 15.6 deployment target, UIScene lifecycle) with no workarounds. On the inner display it
reports the hinge, the side strip the system reserves for controls, and the camera/status area. A
`NavigationRail` placed in that strip lands where Apple's guidelines want the vertical bar.

Most of the work is in our own nav shell (`NavigationRailShell` / `RailScaffold`), not in the packages.

## What Apple wants (layout parts of the HIG)

| Pose / display | Bars | Notes |
|---|---|---|
| Cover display (closed), portrait + landscape | **Vertical, on the right** | Compact width (~466 pt in portrait) |
| Inner display, portrait (669 × 951 pt) | Horizontal (top/bottom) | Regular width; the only pose that keeps horizontal bars |
| Inner display, landscape (951 × 669 pt) | **Vertical, on the right** | Bar starts below the camera/status area |
| Book pose (half open, vertical fold) | – | Nothing should straddle the fold; split 50/50 at the fold; warnings go to the trailing side |
| Tabletop (half open, horizontal fold) | – | Optional: things you watch from a distance on top (→ **webcam**), controls on the bottom |

- The bar stays on the **same physical side** in RTL languages.
- Vertical-bar order, top to bottom: Back/Close → prominent action (e.g. Done) → spacer → the rest.
- Items need icons to go vertical; text-only items stay horizontal.
- Scrolling content stays put; dialogs, sheets and menus get moved into one half when folded.
- Keep the same hierarchy across cover and inner displays so opening/closing is predictable.

Note: the native vertical bar only appears for UIKit/SwiftUI navigation containers. Flutter draws its own UI,
so **we have to place our rail in the strip ourselves**. That's what the packages make possible.

## Spike results

Spike app: rail-in-strip + a dump of the geometry (`scratchpad/duo_spike`, not in the repo).

Inner display, landscape, fully open:

```
Status: HingeStatus.fullyOpen  angle: 180
Size: 951 × 669   sizeClass: regular
viewPadding: EdgeInsets(0, 0, 84, 34)          ← 84 pt system strip on the right, 34 pt home indicator
Strip: right, Rect(867, 0, 951, 669), topClearance 124
Fold: –                                         ← expected: the fold has zero width when flat
Occlusions: [Rect(867, 0, 951, 124)]            ← status/camera cluster at the top of the strip
```

The rail sat in the right-hand 84 pt strip, centred below the status cluster.

For comparison, the **current Mobileraker build** on the same pose puts the rail on the left, and the status pill
draws on top of the right end of the full-width app bar. So the app already runs on the Duo, it just doesn't follow
the guidelines.

Not checked in the spike (the simulator's hinge and rotation can't be driven from the CLI; they need the
Simulator menu): cover display, inner portrait, book pose and tabletop. These can be covered with `duo_kit`'s
`FoldTestPose` in widget tests, plus a manual pass in the Simulator.

## Package choice

| | Role | Why / why not |
|---|---|---|
| **`foldable` 1.0.5** ✅ | Native bridge: hinge angle, posture, reserved regions → publishes them as `MediaQuery.displayFeatures` (`DisplayFeatureBridgeMode.full`) | Most used Duo package (~12k downloads), verified publisher, does nothing on other devices, falls back gracefully if the OS API is missing. iOS only, which is fine: Flutter already fills `displayFeatures` on Android |
| **`duo_kit` 0.1.2** ✅ | Pure-Dart geometry on top of `MediaQuery`: `FoldGeometry` (strip / fold / occlusions), `FoldSplitView`, `FoldAnchor`, `FoldDebugTools`, `FoldTestPose` | Draws no UI of its own, so it fits our existing shell. Same code drives Android foldables. Published by LeanCode. Only depends on `flutter` |
| `iphone_duo_ui_pro` ❌ (for now) | Own bridge + own scaffold (`DuoAdaptiveScaffold`), glass companion | Built around replacing the scaffold, which clashes with `NavigationRailShell` + go_router `ShellRoute`. Its glass mode is Duo-only, but we want glass on all iOS 26+ |

Root setup (verified in the spike):

```dart
FoldableProvider(
  bridgeMode: DisplayFeatureBridgeMode.full,
  child: ClosedFoldOcclusions( // copied from duo_kit's example (Apache-2.0): foldable publishes nothing while closed
    child: MaterialApp.router(...),
  ),
)
```

## Project prerequisites

| Requirement | Mobileraker | |
|---|---|---|
| Xcode 27.1 / iOS 27.1 SDK (otherwise no strip or regions, compatibility mode) | Xcode 27.1 installed | ✅ (CI/release machine must match) |
| UIScene lifecycle (iOS 27 SDK crashes without it) | `FlutterSceneDelegate` already in `Info.plist` | ✅ |
| Deployment target ≥ 15.0 | 15.6 (Podfile) | ✅ |
| CocoaPods or SPM | CocoaPods (`enable-swift-package-manager: false`) | ✅ built without the `ARCHS=arm64` workaround |
| No `UIRequiresFullScreen` / app-wide orientation lock | Not set. Only the fullscreen cam and graph pages lock orientation, temporarily | ✅ (check those two pages on the Duo: a lock keeps the fold but rotates the UI) |

## Integration plan

### Phase 1: rail in the strip ✅ (done)

- `FoldBridge` (`common/lib/ui/components/fold_bridge.dart`) wraps the app: `foldable` bridge + closed-device
  occlusions, and `context.foldStrip` as our only entry point to the geometry.
- `NavigationRailShell` shows the rail when `isLargerThanCompact || foldStrip != null`, so the cover display gets it
  too. The decision is handed to pages via `_RailScope`; `RailScaffold.showsRailOf(context)` exposes it (e.g. the
  dashboard puts its FAB in the rail instead of docking it to the bottom bar, and drops the bar's notch).
- With a strip: the rail fills it (strip width, below the status cluster, on the strip's physical side); the app bar
  and page take the rest of the window. The drawer belongs to an outer `Scaffold` and opens from the strip's side;
  the rail's footer is the menu button (styled like the bottom bar) instead of the branding icon, so the app bar has
  no drawer button. The drawer itself fills the strip (header background behind the status cluster, entries below).
- Tablets and phones without a strip keep the previous layout.

### Phase 2: folds and dialogs

- **Dashboard and other multi-column pages**: when `geometry.division` is vertical (book pose), split the columns
  at the fold with `FoldSplitView`, so no card straddles it.
- **Dialogs and bottom sheets**: with `bridgeMode.full`, Flutter's `DisplayFeatureSubScreen` already keeps them in
  one half. Pass `FoldAnchor.content` / `.controls` as `anchorPoint` in `DialogService` / `BottomSheetService` to
  choose which half.
- **Per-page bottom bars** (Files, Spoolman: `bottomNavigationBar ... .unless(context.isLargerThanCompact)`): with a
  strip, move these items into the rail or the app bar instead of the bottom.

### Phase 3: tabletop (nice-to-have, very on-brand)

Half open on the desk: **webcam on the top half, jog/temperature/print controls on the bottom half**. Drive it
from `DuoMediaQuery.statusOf(context) == HingeStatus.partiallyOpen` together with a horizontal `geometry.division`.

### Testing

- Widget tests with `FoldTestPose.duoHalfOpenedLandscape.data` etc. for the shell (rail side, padding, app bar width).
- Wrap with `FoldDebugTools` in debug builds: a button that simulates strip, book and laptop poses on any device
  (including Android emulators and the iPad).
- Manual pass on the Duo simulator for every pose via the Simulator menu.

## Risks

- **Young packages**: both are weeks old and only tested on the simulator (by their authors and by us). Keep them
  behind our own thin abstraction (a `foldGeometryProvider` / extension) so either can be swapped.
- **Fold lag**: the fold can take about a second to appear after the device comes to rest half open, and regions lag
  the hinge. Animate layout changes, and decide on the hinge posture rather than region `isActive`.
- **Strip on the left in Split View**: iOS 27.1 reports no strip to Flutter apps on the left side of Split View, so
  there we fall back to the normal layout.
- **Engine support may land**: if Flutter starts filling `displayFeatures` on iOS (flutter/flutter#192515),
  `foldable`'s bridge steps aside automatically and `duo_kit` keeps working unchanged.
- **Release builds need Xcode 27.1+**, otherwise the app silently runs in compatibility mode.

## Later: Liquid Glass (all iOS 26+)

Separate from the Duo work. Candidates: `uikit_tab_bar`, `native_liquid_glass_flutter`, `ios_liquid_glass`,
`cupertino_native_better`, which wrap native `UITabBar` / `UIGlassEffect` in platform views. Notes for the
Duo: these are horizontal tab bars, and the system only makes bars vertical for native navigation containers.
Glass in the Duo strip would mean a vertical native glass container (as `iphone_duo_ui_pro_glass` does via
`adaptive_platform_ui`), or Flutter-drawn glass for the rail. Worth evaluating once Phase 1 is in.

## Sources

- [Designing for iPhone Duo: what moves, splits, and stays](https://blakecrosley.com/de/blog/designing-for-iphone-duo)
- [Apple Tech Talk: iPhone Duo](https://developer.apple.com/la/videos/play/tech-talks/111462/)
- [rar.design: iPhone Duo design guide, tab bar](https://rar.design/posts/iphone-duo-design-guide-hig-tab-bar)
- [Kodeco: Seeing Double with the iPhone Duo](https://www.kodeco.com/54224360-seeing-double-with-the-iphone-duo)
- [foldable](https://pub.dev/packages/foldable) · [duo_kit](https://pub.dev/packages/duo_kit) · [iphone_duo_ui_pro](https://pub.dev/packages/iphone_duo_ui_pro)
- Glass: [uikit_tab_bar](https://pub.dev/packages/uikit_tab_bar) · [native_liquid_glass_flutter](https://pub.dev/packages/native_liquid_glass_flutter) · [ios_liquid_glass](https://pub.dev/packages/ios_liquid_glass) · [cupertino_native_better](https://pub.dev/packages/cupertino_native_better)

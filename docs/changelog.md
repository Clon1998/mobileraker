# Mobileraker - Changelog

## [2.5.4] - 2023-08-

### Major Changes

- Added support for moonraker's Jobqueue API. The jobqueue is available on the files page and on the
  floating action buttons on the dashboard.
- Users are now able to configure an alternative url (Remote URL) that Mobileraker will use to
  connect to the printer. This is useful if you want to connect to your printer from outside your
  local network.

### Changed Features

- Improved printer and config file parsing to ensure the app is more resilient to unexpected
  content in the config section definitions.
- Added the option to configure a custom HTTP/WS Client timeout in the printer edit and add flows.
- The printer's device notification registry can now be cleared in the printer edit flow.

### Bug Fixes

- Resolved an issue where saving webcam and remote settings was not working when the user was
  connected via OE. [#219](https://github.com/Clon1998/mobileraker/issues/219)
- The Manual Offset dialog now only closes if klipper is done with the manual_offset. This ensures
  manual bed leveling is working as
  expected [#214](https://github.com/Clon1998/mobileraker/issues/214)
- The advanced printer add flow now correctly adds the default websocket path if the user does not
  specify a websocket URI.
- It is possible now to start a print, if the machine is in the cancelled
  state. [#224](https://github.com/Clon1998/mobileraker/issues/224)

## [2.5.3] - 2023-08-16

### Bug Fixes

- Fixed missing resource for notification on Android preventing the delivery of push notifications
- Fixed issue on some devices that prevented the app from starting and required a reinstall

## [2.5.2] - 2023-08-14

### Changed Features

- The current app version is now also shown on the changelog page

### Bug Fixes

- Fixed webcams did not render if they used an absolut path with a
  port [#213](https://github.com/Clon1998/mobileraker/issues/213)
- Made klippy connection a little bit more reliable
- Dashboard should refresh more reliably if the printer/klipper restarts

## [2.5.1] - 2023-08-12

### Changed Features

- Reduced the aggressiveness of printer refresh when the app is reopened from the background
  [#184](https://github.com/Clon1998/mobileraker/issues/184)

### Bug Fixes

- Resolved the issue where offerings on the "Support the Dev" page were not appearing as active
  after users purchased promotional offerings.

## [2.5.0] - 2023-08-11

Mobileraker now offers a lifetime Supporter Tier. As part of the new tier launch, I am offering an
introductory promotion with lifetime tier prices discounted up to 35% until the end of August.

### Major Changes

- Reworked the printer setup flow to provide a more user-friendly experience for beginners and offer
  additional
  customization options for advanced
  users. [#153](https://github.com/Clon1998/mobileraker/issues/153) [#134](https://github.com/Clon1998/mobileraker/issues/134) [#182](https://github.com/Clon1998/mobileraker/issues/182) [#193](https://github.com/Clon1998/mobileraker/issues/193)
- Added support for WebRTC, enabling real-time communication between
  devices. [#167](https://github.com/Clon1998/mobileraker/issues/167), [#191](https://github.com/Clon1998/mobileraker/issues/191)
- Introduced the option to directly reprint the last file if the printer is still in a complete
  state.

### Changed Features

- Modified the behavior of the Confirm EMS setting to be an opt-out setting instead of opt-in.
- Improved the accuracy of the current and max layer display by utilizing moonraker's info.layer
  fields. [#138](https://github.com/Clon1998/mobileraker/issues/138)
- Enhanced print progress accuracy by implementing the relative file
  method. [#138](https://github.com/Clon1998/mobileraker/issues/138)
- Improved ETA accuracy and added tooltips to the ETA table cells, displaying Slicer, File, and
  Filament remaining time information. [#138](https://github.com/Clon1998/mobileraker/issues/138)
- Added support for a 12-hour time
  format. [#192](https://github.com/Clon1998/mobileraker/issues/197)
- Updated Mobileraker's notification icon for
  Android. [#194](https://github.com/Clon1998/mobileraker/issues/194)
- Migrated webcams to Moonraker's Webcam API.
- Added a new splash screen during app startup.
- Introduced an error widget in case the initial startup fails.
- Files page now works even if klipper is in an error
  state [#163](https://github.com/Clon1998/mobileraker/issues/163)

### Bug Fixes

- Fixed the QR reader functionality, resolving issues with scanning QR codes.
- Enhanced the reliability of the JRpc client, ensuring smoother communication with the server.
- Addressed several minor errors in the background, improving overall app stability.
- Fixed an issue where Webcam Service type could not be
  edited. [#198](https://github.com/Clon1998/mobileraker/issues/198)
- Resolved potential parsing errors, ensuring proper data
  handling. [#205](https://github.com/Clon1998/mobileraker/issues/205)

## [2.4.3] - 2023-07-27

### Major Changes

- Added Afrikaans translation thanks
  to [DMT07](https://github.com/DMT07) [#201](https://github.com/Clon1998/mobileraker/pull/201)

### Bug Fixes

- Fixed displayStatus being a mandatory
  field [#202](https://github.com/Clon1998/mobileraker/pull/202)

## [2.4.2] - 2023-06-28

### Major Changes

- Added Dutch translation thanks
  to [JMSPI](https://github.com/JMSPI) [#185](https://github.com/Clon1998/mobileraker/pull/185)

### Bug Fixes

- Fixed app not starting on ios [#186](https://github.com/Clon1998/mobileraker/pull/186)
- Fixed printer refresh if klipper is not in ready
  state [#187](https://github.com/Clon1998/mobileraker/pull/187)
- Fixed parsing of print_states [#181](https://github.com/Clon1998/mobileraker/pull/181)
- Fixed QR scanner not populating API key
  field. [#189](https://github.com/Clon1998/mobileraker/pull/181)

## [2.4.1] - 2023-06-25

### Changed Features

- Added changelog directly in the app
- Added Firebase Crashlytics

### Bug Fixes

- Fixed chinese translation [#179](https://github.com/Clon1998/mobileraker/pull/179)
- Fixed Mobileraker breaking existing WebRtc cam settings

## [2.4.0] - 2023-06-20

### Major Changes

- Tapping a notification now brings up the correct printer in a multi-printer
  setup [#128](https://github.com/Clon1998/mobileraker/issues/128)
- Added `[heater_generic]` support [#140](https://github.com/Clon1998/mobileraker/issues/140)
- Revamped the parsing and update mechanism of printer objects for improved efficiency and
  functionality.
- Refactored Handover Mechanism between Local and OctoEverywhere Connection
- Added Calibration actions to **Move Axis** card
- Added Manual Probe and Bed Screw Adjust
  Dialogs [#169](https://github.com/Clon1998/mobileraker/issues/169)
- Added VzBot theme

### Changed Features

- Enhanced the reliability of printer refresh on the dashboard, ensuring it now reliably refreshes
  both the printer and
  klippy.
- Info Snackbars make use of tenary color
- Step selectors should work better on smaller screens
- Move Axis Step selector allows input of real numbers/floating numbers
- Number displays are more i18n aware
- Updated Chinese Translation

### Bug Fixes

- The utilization of the printer port should be avoided for relative path
  webcams ([#168](https://github.com/Clon1998/mobileraker/issues/168))
- Resolved the "Stream has been listened to"
  error ([#174](https://github.com/Clon1998/mobileraker/issues/174))
- Fixed min Ios Version ([#171](https://github.com/Clon1998/mobileraker/issues/171))
- Fixed void in Fans card if cooling fan is not configured

## [2.3.5] - 2023-06-8

### Changed Features

- Corrected tagging of machines

## [2.3.4] - 2023-05-26

### Bug Fixes

- Fixed webcam not working if rotation was missing

## [2.3.3] - 2023-05-25

### Changed Features

- Added Image Notifications for Supporters

### Bug Fixes

- Fixed editing WebCams in Mobileraker disabled cams in Fluidd
- Fixed Octoeverywhere for printers with non default port

## [2.3.2] - 2023-05-22

### Changed Features

- Added restore button for subs
- Added IOS EULA
- WebCam error now shows the Cam's URIs

### Bug Fixes

- Fixed Color in ConfigFile FAB

## [2.3.1] - 2023-05-20

### Bug Fixes

- Hotfixed Webcam card shown if no cam was found
- Hotfixed Webcam card shows error if no cam was found
- Hotfixed Printer edit closes even if a field error was detected

## [2.3.0] - 2023-05-19

This release signifies a significant shift in the philosophy governing the future of Mobileraker,
particularly regarding
its monetization strategy. However, let me begin by addressing the most crucial aspect. Currently,
there are no plans to
restrict major functional features behind paywalls or subscriptions—Mobileraker will remain open
source. Nevertheless,
due to the unsuccessful reliance on donations as the sole funding source and the absence of
long-term sponsorship from
any company or shop, the decision has been made to incorporate monetization directly within
Mobileraker.

With the introduction of this version, users now have the option to support the ongoing development
of Mobileraker
through in-app subscriptions. As a token of appreciation, supporters will gain access to an
exclusive Material 3-based
theme. In the future, additional perks such as UI enhancements or minor functional features may be
introduced.

### Major Changes

- Added a new "Support the Dev!" page to facilitate user contributions
- Improved integration by sharing webcam configuration with Mainsail/Fluidd
- Introduced a setting to automatically switch the fullscreen webcam to landscape
  mode ([#95](https://github.com/Clon1998/mobileraker/issues/95))
- Implemented a "Printer Switch" dialog that opens when users tap the page's titlt (Note: Rapid
  printer switching can be
  done by swiping the title)
- Provided a helpful hint in the app settings
  if [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion) is not detected
- Added Romanian translation, thanks to [@vaxxi](https://github.com/vaxxi)
- Added Italian translation, thanks to [@Livex97](https://github.com/Livex97)

### Changed Features

- Added support for printers that do not utilize a print
  fan ([#158](https://github.com/Clon1998/mobileraker/issues/158))
- Streamlined `Restart MCU`
  to `Restart Firmeware` ([#145](https://github.com/Clon1998/mobileraker/issues/145))
- Enhanced the webcam animation for smoother transitions from loading to normal operation
- Console entries now display the date if they are older than 24 hours
- Tapping a macro/command in the console now moves the cursor to the end of the input field

### Bug Fixes

- Resolved issue where webcams were not functioning on all screens when OctoEverywhere is used
- Fixed ConfigView and GCode preview loading problems when OctoEverywhere is
  used ([#148](https://github.com/Clon1998/mobileraker/issues/148))
- Ensured proper transmission of API Key to
  OctoEverywhere ([#146](https://github.com/Clon1998/mobileraker/issues/146))
- Addressed duplicated notifications caused by duplicate FCM
  entries ([#133](https://github.com/Clon1998/mobileraker/issues/133))
- Fixed the ability to set fans higher than their respective `max_temp`
  value ([#139](https://github.com/Clon1998/mobileraker/issues/139))
- Corrected the behavior of JRPC-Client, ensuring it waits for pending messages to
  complete ([#159](https://github.com/Clon1998/mobileraker/issues/159))
- Fixed `[output_pin]` config not getting parsed, finally making binary pins
  switchable ([#146](https://github.com/Clon1998/mobileraker/issues/70))
- Fixed Importing of settings from other
  printers ([#161](https://github.com/Clon1998/mobileraker/issues/161))
- Fixed NotificationService not registering remote-id for notifications on machines with multiple
  printers managed by
  Mobileraker
- Resolved overflow issue on the `Dashboard` in the `MoveAxis` card
- Fixed changes in the printer edit page not getting reflected on the dashboard!

## [2.2.x]

For a comprehensive list of changes prior to version 2.3.x, please refer to
the [tags](https://github.com/Clon1998/mobileraker/releases) page.

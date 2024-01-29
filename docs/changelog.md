# Mobileraker - Changelog

## [2.6.11] - 2024-01-xx

### Major Updates

- Introduced bed mesh visualization card to the dashboard, empowering users to switch seamlessly between various mesh
  profiles.
  ([#196](https://github.com/Clon1998/mobileraker/issues/196))

### Changed Features

- Webcam paths (URLs) now support relative paths and respect the configured HTTP address port (Printer address),
  addressing
  previous issues of ignoring it. This might require users to reconfigure their webcams.

### Bug Fixes

- Fixed a Belt Tuner display crash caused by insufficient permissions.
- [iOS] Resolved playback interruptions during the app's initial launch.
- Corrected background color display for toggle button cards (Power Panel, Output Pins) in Material 2 themes.


## [2.6.10] - 2024-01-19

### Changed Features

- The printer overview page now displays the webcams corresponding to the selected camera for each printer.

### Bug Fixes

- [IOS] Fixed live activities foreground color on IOS 16.4 [#315](https://github.com/Clon1998/mobileraker/issues/315)
- [IOS] Fixed an issue with the live activities that would reset the entire local storage of the
  app [#315](https://github.com/Clon1998/mobileraker/issues/321)
- Fixed typo on profile page's 'Send Verification Mail' button

## [2.6.9] - 2024-01-10

### Major Updates

- Introduced a new tool page featuring a list of tools and helpful links for 3D printing.
- Added the Belt Tuner tool to enhance user control over belt tension.
- Enabled support for cross-platform and multi-device purchases, ensuring accessibility of purchases across all devices.
  Users need to create a Mobileraker account and log in on all devices for synchronization. Note: An account is only
  required to synchronize purchases. The app and supporter status can still be used without an account.
- [Supporters] Implemented support for go2Rtc-based WebRtc
  webcams. [#304](https://github.com/Clon1998/mobileraker/issues/304)

### Changed Features

- Enhanced the Extruder card, elevating it to a separate, more refined component that empowers users to modify extruder
  velocity. [#268](https://github.com/Clon1998/mobileraker/issues/268)
- [IOS] Revamped the design of live activities, adopting a more compact form with a black theme to align with the system
  UI.

### Bug Fixes

- Resolved the issue with the bed mesh button not entering the correct loading state after being pressed.
- Corrected the ETA Cell, now displaying the ETA label instead of the Filament
  label. [#300](https://github.com/Clon1998/mobileraker/issues/300) [#305](https://github.com/Clon1998/mobileraker/issues/305)
- Resolved a critical issue where the app displayed an error when Moonraker encountered difficulties connecting to the
  Klipper domain. [#308](https://github.com/Clon1998/mobileraker/issues/308)

### Localization

- Added a Turkish translation, courtesy
  of [@larinspub](https://github.com/larinspub). [#297](https://github.com/Clon1998/mobileraker/issues/297)
- Updated the Hungarian translation, thanks
  to [@AntoszHUN](https://github.com/AntoszHUN). [#302](https://github.com/Clon1998/mobileraker/issues/302)

## [2.6.8] - 2023-12-8

### Major Updates

- Added the ability to view `.png`, `.jpg`, and `.jpeg` files in the file browser.
- Users can now select a PEM-Certificate for SSL-Pinning in the printer settings. This option enhances security in
  comparison to trusting all self-signed certificates.
  device. [#193](https://github.com/Clon1998/mobileraker/issues/193) [#280](https://github.com/Clon1998/mobileraker/issues/280)

### Changed Features

- The full-screen webcam can now fill the entire screen if zoomed or panned.
- Non GCode files now display their last modified date in the file browser.
- Replaced the shadow of the console page with a more subtle border among all light mode themes.
- The select printer dialog now displays the printer's http URL under its name.
- Improved the Control Axis card, making it a separate and more polished component.

### Bug Fixes

- Fixed Neopixel parsing error for legacy configs. [#287](https://github.com/Clon1998/mobileraker/issues/287)
- Fixed the file browser not working for Obico connections.
- Resolved an issue where uploading a file with the same name as an existing one wouldn't update the thumbnail,
  resulting in the old image persisting in the application.
- GCode errors are now displayed via the Snackbar again.
- Fixed a parsing error on Creality printer of gCode
  thumbnails. [#288](https://github.com/Clon1998/mobileraker/issues/288)

## [2.6.7] - 2023-11-11

### Major Updates

- You can now organize GCode macros in your printer settings more conveniently. Instead of moving each one separately,
  you can assign them to a new group with just a button click. You can also change the visibility of individual macros.
- The GCode macro card on your dashboard has been improved. It's now a separate, smoother component, and it adds a nice
  animation when you switch between different groups.

### Changed Features

- The internal states that saves your settings for the selected macro group, webcam choice on the dashboard, and file
  sorting preferences on the files
  page are now unique to each of your printers. They won't be mixed up between your different devices.
- When you add a remote connection, the bottom sheet now adjusts itself to your screen, reaching the top instead of
  staying a fixed size. This change makes sure everything fits properly, even if you need to scroll through some
  content.

### Bug Fixes

- Live activities for multiple printers have been improved to ensure that they update correctly without overwriting each
  other.
- While using obico or the manual connection, the app is now able to open Gcode and timelapse files
  again. [#276](https://github.com/Clon1998/mobileraker/issues/276)

## [2.6.6] - 2023-10-25

### Major Changes

- Added Gadget by [OctoEverywhere](https://octoeverywhere.com/), offering free AI-based print monitoring (requires a
  linked OctoEverywhere account). *Note: Not affiliated with Mobileraker.*
- Multipliers, Limits, and FW Retraction cards can now be grouped into a single horizontal scrollable card. This is the
  default setting and can be disabled in the app settings.
- Firmware Retraction settings can now be edited in the app. [#129](https://github.com/Clon1998/mobileraker/issues/129)
- Added [Obico.io](https://www.obico.io/) as a remote access provider.

### Changed Features

- Improved the visibility of the Exclude Object button on the Dashboard for a better user experience.
- Renamed Babystepping to Z-Offset/Microstep Z-Axis to align more closely with Klipper.
- Live activities are now more compact, displaying complete icons and colors. They also update more often.
- All printer JRpc-Clients should now automatically reconnect when the app is opened from the background.

### Bug Fixes

- Fixed an issue that prevented the app from correctly detecting the currently used Moonraker version.
- Resolved parsing errors for `heater_generic`, `extruder`, and `heater_bed` configurations that
  use `temperature_combined` sensor types. [#270](https://github.com/Clon1998/mobileraker/issues/270)

## [2.6.5] - 2023-10-11

### Bug Fixes

- Promotions now show the correct duration on the paywall

## [2.6.4] - 2023-09-30

### Major Changes

- Reintroduced webcam support for users of Moonraker versions prior to
  v0.8.0. [#254](https://github.com/Clon1998/mobileraker/issues/254)
- Added Ukrainian translation, thanks
  to [iZonex](https://github.com/iZonex) [#258](https://github.com/Clon1998/mobileraker/issues/258)
- Added Portuguese translation with Brasil flavor, thanks
  to [@opastorello](https://github.com/opastorello)
- Introduced local Live Activity support for iOS devices. While real-time and remote updates to the live activities are
  currently under development, local activities will now update alongside the app
  itself.  [#238](https://github.com/Clon1998/mobileraker/issues/238)
- Introduced a new OctoEverywhere theme as a heartfelt tribute to the unwavering dedication and support of
  the [OctoEverywhere](https://octoeverywhere.com/) team.

### Changed Features

- In accordance with Moonraker, editing config-file-based webcams within the app is no longer supported.
- Deactivated the capacity to employ a temperature preset during an active print job.

### Bug Fixes

- In scenarios with slower network connections, the app will no longer display the `Klipper-Error, Future did not
  complete in time` message. Instead, it will now seamlessly utilize the timeout configuration specified in the machine
  settings for all JRpc (JSON-RPC) calls, ensuring a more reliable and consistent user experience.

## [2.6.3] - 2023-09-15

### Major Changes

- [Supporters] Introduced printer-specific UI themes, now configurable within the printer editing
  process. [#195](https://github.com/Clon1998/mobileraker/issues/195)

### Bug Fixes

- Fixed an issue where the configuration of `extruder_stepper` was incorrectly recognized as extruder config, causing
  errors for users with multi-extruder setups. [#248](https://github.com/Clon1998/mobileraker/issues/248)
- Addressed a problem where config files were out of sync if user edited them on another
  UI/Filesystem. [#250](https://github.com/Clon1998/mobileraker/issues/250)
- Corrected the display of the First Layer Temperature on the GCode Detail page, which were swapped between extruder and
  bed.
- Fixed an issue with the control tab on the dashboard while changing the printer,
- The webcam now shows the correct remote indicator while using manual mode.

## [2.6.2] - 2023-09-07

### Bug Fixes

- Fixed files view for GCodes [#246](https://github.com/Clon1998/mobileraker/issues/246)

## [2.6.0] - 2023-09-06

### Major Changes

- [Supporters] Added support for moonraker's Jobqueue API. The jobqueue is available on the files page and on the
  floating action buttons on the dashboard.
- Users are now able to configure an alternative url (Remote URL) that Mobileraker will use to
  connect to the printer. This is useful if you want to connect to your printer from outside your
  local network.
- The app now intelligently switches between local and remote connections based on your phone's WiFi network status,
  ensuring seamless connectivity even when you're not connected to a configured WiFi network.
- Made the timelapse folder accessible via the file browser if the timelapse plugin is
  active. [#241]((https://github.com/Clon1998/mobileraker/issues/241)
- [Supporters] Timelapse videos can be shared directly from the app to other apps on your phone.

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
- Fixed parsing of the `heater_generic` config for some edge
  cases. [#242](https://github.com/Clon1998/mobileraker/issues/242)
- Resolved an issue where the app would crash after being in the background for an extended period.

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

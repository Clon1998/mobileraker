# Mobileraker - Changelog

## [2.3.1] - 2023-05-20

### Bug Fixes

- Hotfixed Webcam card shown if no cam was found
- Hotfixed Webcam card shows error if no cam was found
- Hotfixed Printer edit closes even if a field error was detected

## [2.3.0] - 2023-05-19

This release signifies a significant shift in the philosophy governing the future of Mobileraker, particularly regarding
its monetization strategy. However, let me begin by addressing the most crucial aspect. Currently, there are no plans to
restrict major functional features behind paywalls or subscriptions—Mobileraker will remain open source. Nevertheless,
due to the unsuccessful reliance on donations as the sole funding source and the absence of long-term sponsorship from
any company or shop, the decision has been made to incorporate monetization directly within Mobileraker.

With the introduction of this version, users now have the option to support the ongoing development of Mobileraker
through in-app subscriptions. As a token of appreciation, supporters will gain access to an exclusive Material 3-based
theme. In the future, additional perks such as UI enhancements or minor functional features may be introduced.

### Major Changes

- Added a new "Support the Dev!" page to facilitate user contributions
- Improved integration by sharing webcam configuration with Mainsail/Fluidd
- Introduced a setting to automatically switch the fullscreen webcam to landscape
  mode ([#95](https://github.com/Clon1998/mobileraker/issues/95))
- Implemented a "Printer Switch" dialog that opens when users tap the page's titlt (Note: Rapid printer switching can be
  done by swiping the title)
- Provided a helpful hint in the app settings
  if [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion) is not detected
- Added Romanian translation, thanks to [@vaxxi](https://github.com/vaxxi)
- Added Italian translation, thanks to [@Livex97](https://github.com/Livex97)

### Changed Features

- Added support for printers that do not utilize a print
  fan ([#158](https://github.com/Clon1998/mobileraker/issues/158))
- Streamlined `Restart MCU` to `Restart Firmeware` ([#145](https://github.com/Clon1998/mobileraker/issues/145))
- Enhanced the webcam animation for smoother transitions from loading to normal operation
- Console entries now display the date if they are older than 24 hours
- Tapping a macro/command in the console now moves the cursor to the end of the input field

### Bug Fixes

- Resolved issue where webcams were not functioning on all screens when OctoEverywhere is used
- Fixed ConfigView and GCode preview loading problems when OctoEverywhere is
  used ([#148](https://github.com/Clon1998/mobileraker/issues/148))
- Ensured proper transmission of API Key to OctoEverywhere ([#146](https://github.com/Clon1998/mobileraker/issues/146))
- Addressed duplicated notifications caused by duplicate FCM
  entries ([#133](https://github.com/Clon1998/mobileraker/issues/133))
- Fixed the ability to set fans higher than their respective `max_temp`
  value ([#139](https://github.com/Clon1998/mobileraker/issues/139))
- Corrected the behavior of JRPC-Client, ensuring it waits for pending messages to
  complete ([#159](https://github.com/Clon1998/mobileraker/issues/159))
- Fixed `[output_pin]` config not getting parsed, finally making binary pins
  switchable ([#146](https://github.com/Clon1998/mobileraker/issues/70))
- Fixed NotificationService not registering remote-id for notifications on machines with multiple printers managed by
  Mobileraker
- Resolved overflow issue on the `Dashboard` in the `MoveAxis` card
- Fixed changes in the printer edit page not getting reflected on the dashboard!

## [2.2.x]

For a comprehensive list of changes prior to version 2.3.x, please refer to
the [tags](https://github.com/Clon1998/mobileraker/releases) page.

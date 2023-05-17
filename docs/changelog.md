# Mobileraker - Changelog

## [2.3.0] - 2023-05-17

This release signifies a significant shift in the philosophy governing the future of Mobileraker, particularly regarding
its monetization strategy. However, let me begin by addressing the most crucial aspect. Currently, there are no plans to
restrict major functional features behind paywalls or subscriptions—Mobileraker will remain open source. Nevertheless,
due to the unsuccessful reliance on donations as the sole funding source and the absence of long-term sponsorship from
any company or shop, the decision has been made to incorporate monetization directly within Mobileraker.

With the introduction of this version, users now have the option to support the ongoing development of Mobileraker
through in-app subscriptions. As a token of appreciation, supporters will gain access to an exclusive Material 3-based
theme. In the future, additional perks such as UI enhancements or minor functional features may be introduced.

### Major changes

- `Support the Dev!` page was added
- Webcam config is now shared with Mainsail/Fluidd
- Added setting to auto-switch fullscreen webcam to landscape [#95](https://github.com/Clon1998/mobileraker/issues/95)
- Added `Printer Switch` dialog that opens if the user taps the page tilt (Note: you can always rapidly switch between
  printers by swiping the title)
- Added hint in the app settings if no [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion) was
  detected
- Added Romanian translation thanks to [@vaxxi](https://github.com/vaxxi)
- Added Italian translation, thanks to [@Livex97](https://github.com/Livex97)

### Changed features

- WebCam should have a smoother animation when transitioning from loading to normal operation
- Entries in Console now display the Date if they are older than 24hrs
- Tapping a macro/command in the console now moves the cursor to the end of the input field
- Added support for printers that do not use a print fan [#158](https://github.com/Clon1998/mobileraker/issues/158)

### Bug Fixes

- Fixed webcams not working on all screens if OctoEverywhere is used
- Fixed ConfigView and GCode preview not loading if OctoEverywhere is
  used [#148](https://github.com/Clon1998/mobileraker/issues/148)
- Fixed API Key not transmitted to OctoEverywhere [#146](https://github.com/Clon1998/mobileraker/issues/146)
- Fixed duplicated notifications due to duplicate FCM entries [#133](https://github.com/Clon1998/mobileraker/issues/133)
- Fixed Fans could be set higher than their respective `max_temp`
  value [#139](https://github.com/Clon1998/mobileraker/issues/139)
- Fixed JRPC-Client not waiting for pending messages [#159](https://github.com/Clon1998/mobileraker/issues/159)
- Fixed NotificationService not registering remote-id for notifications on the machines if multiple printers are managed
  by Mobileraker
- Fixed overflow issue in on the `Dashboard` in the `MoveAxis card

## [2.2.x]

All changes before 2.3.x can be found directly on the [tags](https://github.com/Clon1998/mobileraker/releases) page.
# Mobileraker - Changelog

## [2.9.6] - 2025-12-xx

### Enhancements

- **Custom Load/Unload Sequences**: Users can now configure custom G-Code sequences in machine settings to execute
  during filament loading and unloading operations, replacing Mobileraker's default sequences with their own
  printer-specific commands when using the filament load/unload wizards.

- **Fab with Keyboard**: The floating action button (FAB) on the dashboard page now hides when the keyboard is open, preventing
  obstruction of input fields and enhancing user experience during text entry.

### Bug Fixes

- **Fans Card**: Fixed an issue where the fans card would not display fans %-speed correctly when `max_power` was set to
  a value other than 1.0.
- **Console History Color**: Fixed an issue where the console history text color for responses was not correctly set in
  light mode, resulting in poor visibility.

## [2.9.5] - 2025-11-22

### Enhancements

- **Customizable Dashboard**: Simplified the operations of the customizable dashboard in terms of layout management.
- **Console Interface**: Enhanced console page with modernized styling and improved visual density for better user
  experience
- **File Management**: Added backup file filtering capabilities for Klipper backup files and improved console settings
  through dedicated bottom sheet
- **Spoolman Integration**: Enhanced spool visualization with improved color mapping and filtering system
- **Markdown Rendering**: Replaced flutter_markdown with flutter_markdown_plus for better functionality and performance
- **User Interface**: Updated console input to support optional empty input suffixes and improved overall page styling
- **Data Import/Export**: Added import/export functionality for app data (Machines & Layouts). Located on the settings
  page.

### Bug Fixes

- **File Sharing**: Fixed broken sharing of files and text in ISO 26 compatibility mode
- **Console Interface**: Resolved console history refresh pull down icon and text display issues
- **File Operations**: Fixed filtering for Klipper backup files to work correctly
- **Build System**: Ensured app can always build successfully with improved build configuration

### Development Improvements

- **Color System**: Introduced general RemappingColorMapper for better color handling across the application
- **Settings Management**: Unified setting bottom sheet design for consistent user experience

## [2.9.4] - 2025-10-07

### Enhancements

- **GCode Console Card**: Added a GCode console card to the dashboard, allowing users to send GCode commands directly
  from the dashboard.
- **Temperature Preset GCode**: Added support for custom GCode execution when temperature presets are
  applied [#530](https://github.com/Clon1998/mobileraker/issues/530)
- **Empty directory indicator**: File selection bottom sheet now consistently displays the empty directory widget,
  matching the behavior of the main file manager.

### Bug Fixes

- **Remote services**: Fixed crash when linking OctoEverywhere or Obico
  accounts. [#533](https://github.com/Clon1998/mobileraker/issues/533)
- **Fullscreen Webcam view**: Resolved temperature display text wrapping issue in fullscreen webcam
  mode. [#536](https://github.com/Clon1998/mobileraker/issues/536)
- **Webcam configuration**: Webcam settings can now be edited regardless of Klippy/MCU connection status.
- **Subfolder navigation**: File selection bottom sheet now properly handles file selection from subfolders.

## [2.9.1] - 2025-08-27

### Localization

- Added the 🇨🇿 czech translation, thanks to [@Marek-Dvorny](https://github.com/Marek-Dvorny).
- Updated the 🇷🇺 russian translation, thanks to DrPerryCoke.

### Enhancements

- **Bed Mesh Visualization**: The bed mesh visualization card has been enhanced to display the bed mesh in a
  more accurate way by using a custom widget instead of a chart to render the mesh. This provides a clearer and more
  precise representation of the bed mesh, making it easier for users to visualize and understand the bed leveling data.
- **Beacon Model Selection**: The beacon model selection is now sorted by name, making it easier to find the
  desired model in the list.
- **Bed-Mesh Selection**: The bed-mesh selection is now sorted by name, improving usability when selecting
  different bed meshes.
- **Non-Motion Setups**: Removed the requirement for `virtual_sdcard`, `extruder` and `motion_report` objects, enabling
  users to
  control non-printer Klipper projects (such as filament driers, pcb-hot plates, or other projects) through Mobileraker.
- **Print Job Bottom Sheet**: A new bottom sheet now allows users to select a print job directly from the overview
  page. This makes it easier for any users running a farm to more quickly select a new print job.
- **Pwm_Tool Object**: Added support for the `pwm_tool` object, allowing users to control PWM tools directly from the
  app.
- **File Selection**: Added a new file selection bottom sheet that makes it easier to browse and select files within the
  app.

### Bug Fixes

- **Printer-Edit Padding**: Added dynamic padding to ensure system UI elements (like the navigation bar) do not
  overlap with the printer edit page content, enhancing usability on devices with varying screen sizes.
- **Bottom Sheet Styling**: Fixed bottom sheet color schemes to match the app's theme consistently.
- **Search Page**: Added proper padding at the bottom of search pages to prevent system UI overlap.
- **Selected Item Highlighting**: Fixed background overflow issues when items are selected in lists.

## [2.9.0] - 2025-05-24

### Enhancements

- **Integrated Notification Management**: You can now configure all companion notification settings directly within the
  app! Navigate to Settings → Notifications to manage both global defaults and printer-specific notification
  preferences. This eliminates the need to manually edit the `mobileraker.conf` file on your printer, making
  notification setup more user-friendly while ensuring consistency across all your devices. Customize notification
  thresholds, print states that trigger alerts, and even configure printer-specific overrides—all from one convenient
  interface.

- **Temperature Graph Legend Improvements**: Exclude entire sensor categories with a single tap on the sensor name,
  rather than toggling individual data points. This streamlined interaction makes graph data interpretation faster
  and more intuitive, especially during complex print jobs with multiple temperature sensors.

- **Redesigned Printer Overview Page**: We've completely revamped the printer overview page with an intuitive layout
  that prioritizes critical information at a glance. The new design features improved information hierarchy and
  content organization, providing exceptional visibility across multiple printers—perfect for print-farm operators
  managing numerous devices simultaneously.

- **Enhanced Machine Monitoring**: Implemented machine last seen tracking service with enhanced Klippy connection
  monitoring capabilities, providing better visibility into printer connectivity status.

- **Spoolman Integration Enhancements**: Added support for extra fields in Spoolman forms, spool detail pages now
  display spool weight and initial weight information, and improved form handling with better parent value inheritance.

### Bug Fixes

- **LED Control System**: Resolved a critical issue that prevented the app from properly updating LED color settings,
  ensuring your visual indicators now work reliably across all compatible printer models.

- **Preheat Dialog Translations**: Fixed broken translations in the preheat dialog when accessed through the file action
  bottom sheet, ensuring a consistent multilingual
  experience. [#510](https://github.com/Clon1998/mobileraker/issues/510)

- **File Manager Indexing**: Resolved an indexing issue that caused certain files to be omitted from the file manager
  view, ensuring complete visibility of all available print
  files. [#504](https://github.com/Clon1998/mobileraker/issues/504)

- **Webcam Management**: Fixed issue preventing webcam snapshot disabling, resolved broken webcam addition due to UID
  changes, and migrated to proper UID field usage for moonraker webcam API.

- **Spoolman Fixes**: Resolved form parsing errors on iOS devices, fixed string field handling when values were empty,
  improved error handling for unchanged form submissions, and fixed field reset issues in subsequent save requests.

- **UI & Layout Improvements**: Fixed notification settings page showing too many device selections, resolved screen
  keep-alive issue, improved color handling for light and dark themes across multiple components, added restart button
  for disconnected Klipper states, fixed console page not showing when Klippy wasn't ready, and wrapped content in
  SafeArea for better layout on various screen sizes.

### Code Improvements

- **Enhanced Logging Framework**: Implemented a more robust logging system with improved performance characteristics,
  enabling more comprehensive diagnostics and faster issue resolution. This foundation will significantly improve our
  ability to identify and address edge cases in future updates.

- **Webcam API Reliability**: Migrated from name-based references to unique identifier (UID) implementation for webcam
  connections, eliminating potential naming conflicts and ensuring consistent webcam access across network changes.

## [2.8.7] - 2025-03-05

### Bug Fixes

- **Keep Screen Awake**: Fixed an issue where the "Keep Screen Awake" setting was not working correctly causing the
  screen to always stay on.

### Enhancements

- **Live Activity - Watch (IOS)**: Added a custom live activity for watchOS that replaces the broken smart stack variant
  which apple automatically generates. This new live activity is more reliable and provides a better user
  experience. [#480](https://github.com/Clon1998/mobileraker/issues/480)

### Bug Fixes

- **Layer Info**: Fixed an issue where the layer info was not displayed correctly for some klipper/slicer combinations.
- **App Start**: Fixed an issue that in some cases made the app startup very slow.

## [2.8.6] - 2025-02-22

### Bug Fixes

- **Missing Translation**: Added the missing translation for the __Job Queue__ button(s) at multiple locations within
  the app.

## [2.8.5] - 2025-02-17

### Enhancements

- **Temperature History Graph Page**: It is now possible to open the temperature history graph page directly from the
  temperature card. Just click on the upper part of the temperature card to open the graph
  page. [#441](https://github.com/Clon1998/mobileraker/issues/441)
- **Beacon Model Selection**: Added a new quick action to the __Move Axis__ card that allows users to select a beacon
  model for the printer.
- **Target File Location Page**: The __Back__ and __Cancel__ buttons on the target file location page now function
  correctly. Users can navigate back to the previous page or cancel the move/copy operation immediately, instead of
  always moving up to the root folder.
- **File Manager Navigation**: The file manager now automatically follows folder operations:
    - When a folder is moved, the view automatically navigates to its new location
    - When a folder is deleted, the view returns to the parent folder
    - These behaviors work correctly for both directly affected folders and their nested children
- **GCode Detail Page**: The GCode detail page now provides the same file management functionality as the normal file
  manager page when a GCode file is selected.
- **Spoolman Page Klipper Offline**: Users can now access the Spoolman page even if Klipper is offline. This allows
  management of spools and filaments even when the Klipper part of the printer is unavailable (e.g., due to a relay
  turning off all components except the host/Raspberry Pi).  [#462](https://github.com/Clon1998/mobileraker/issues/462)
- **Webcam Access When Offline**: The webcam card is now displayed alongside the power panel card even if Klipper is
  offline. This allows users to still access the webcam even if the printer is
  offline. [#221](https://github.com/Clon1998/mobileraker/issues/221)
- **Temperature Slider Increments**: Added 5°C snap points to the temperature slider for easier temperature selection,
  while maintaining precise control via +/- buttons. This improvement reflects user behavior analysis showing that 90%
  of temperature adjustments target multiples of 5°C.

### Bug Fixes

- **User Account**: Fixed an issue that prevented the app from correctly updating the supporter status after logging
  into an account. Previously, an app restart was required to reflect the correct supporter status.

## [2.8.4] - 2025-01-04

-**Macro Param Parsing**: Fixed an issue that prevented the app from parsing macro parameters
correctly. [#448](https://github.com/Clon1998/mobileraker/issues/448)

### Enhancements

- **Keep Screen Awake**: Added a new setting to keep the screen on while the app is open. This feature is especially
  useful
  for users who want to keep their device awake while monitoring a print job or using the app for an extended period. To
  enable this feature, navigate to the app settings and toggle the "Keep Screen Awake"
  option. [#432](https://github.com/Clon1998/mobileraker/issues/432)
- **Button feedback**: Added haptic feedback to the move axis buttons on the move axis card. This feature
  provides users with tactile feedback when pressing the buttons, enhancing the overall user experience.
- **OLED Theme**: Introduced a new OLED theme for users with OLED displays. The OLED theme features a dark background
  with vibrant colors, optimized for OLED screens to reduce power consumption and improve readability in low-light
  environments.

### Bug Fixes

- **Keyboard Input Spoolman**: Fixed an issue that prevented users from entering decimal values on the spool form
  page. [#444](https://github.com/Clon1998/mobileraker/issues/444)

- **Misc Card**: Resolved an issue where the misc card would not be displayed in certain circumstances due to a bug in
  the ordering code of the available misc-items. [#449](https://github.com/Clon1998/mobileraker/issues/449)

## [2.8.3] - 2024-12-08

### General

- **iOS Support**: Due to libraries used in the app, the app now requires iOS 15.5 or newer to run.

### Enhancements

- **Macro Visibility**: Added configurable printer state visibility for macros. Users can now hide macros irrelevant to
  the current printer state by tapping the macro in the group editor on the printer edit page.
- **Remote Services Randomization**: Randomized the order of remote services on the printer add and edit pages to ensure
  a more fair representation.
- **GCode File Sorting**: Added support for sorting GCode files by estimated print time, allowing users to quickly find
  the shortest or longest print jobs.
- **ETA Day Indicator**: Enhanced the ETA cell in the status card to display a `+n` to indicate that the ETA is in n
  days. (e.g., `+1` for tomorrow)
- **Heater Shortcut**: Added a convenient long-press gesture on the "Set" button within the heater card to instantly
  disable the heater, improving user interaction and control.

### Bug Fixes

- **GCode Preview**: Fixed a parser error in the GCode preview when the `SET_RETRACTION` command is used.
- **Object Naming**: Resolved an issue with Klipper objects (Config entries) of the same class and name. The app now
  distinguishes between different object kinds (e.g., `fan_generic` and `temperature_fan`) when preventing naming
  conflicts.
- **WebRTC Camera Streams**: Fixed a stability issue that could cause app crashes by opening too many WebRTC camera
  streams simultaneously.
- **Obico One-Click Setup**: Corrected an HTTP client-related problem preventing single-click Obico connection setup.
- **File Picker on Android**: Fixed an issue that prevented the user from choosing a file to upload on some Android
  versions.

### i18n

- **Hungarian Translation**: Updated the Hungarian translation, thanks to [@AntoszHUN](https://github.com/AntoszHUN).
- **Chinese Taiwan Translation**: Added a Chinese Taiwan translation, thanks to Kayzed.
- **Polish Translation**: Added a Polish translation, thanks to Solargrim.

## [2.8.2] - 2024-10-31

### Enhancements

- **File name Tooltip**: It is now possible to long-press the filename in the file action bottom sheet to see the full
  name of the file.

### Bug Fixes

- **Restart Bottom Sheet**: Fixed broken button behavior in the restart menu where PI restart, shutdown, and firmware
  restart actions only worked with long-press instead of normal taps after confirmation.

- **UI Improvements**: Standardized bottom sheet behavior with consistent animations and layouts across all instances,
  enhancing overall navigation fluidity.

- **Copying of Files**: Copying a file to a different folder than the currently open one, no longer causes the app to
  show
  the loading indicator indefinitely.

## [2.8.1] - 2024-10-23

### Enhancements

- **Spoolman Page Filtering**: Added the ability to filter spools, filaments, and manufacturers on the Spoolman page.
  Users can now filter spools by color, material, location, and more, making it easier to find specific spools.

- **Custom Schema (IOS)**: Added a custom schema registration for IOS, allowing the app to be opened via a custom URL
  scheme. This feature enables users to open the app directly from a web browser or other apps by clicking on a custom
  link. The schema is: `mobileraker://`. In the future this will be expanded to allow opening a specific printer, file,
  spool or more directly from a link.

- **Print Summary**: After a print has finished, a summary of the print will be shown. This summary includes the print
  duration and the amount of filament used. [#421](https://github.com/Clon1998/mobileraker/issues/421)

### Bug Fixes

- **File Picker (IOS)**: Fixed an issue where the file picker on IOS would not allow to pick any file to upload as GCode
  or Config.
- **Exclude Object Map**: Fixed an issue that prevented tapping on an object to select it.

## [2.8.0] - 2024-09-30

### New Features

- **GCode Viewer**: Added a 2D GCode viewer, allowing you to preview GCode files directly within the app. The viewer
  supports layer-by-layer inspection, making it easier to analyze GCode files visually.
  *Note: This feature is available exclusively for "Supporters".*

- **Follow Print GCode**: A new dashboard card has been introduced, enabling you to monitor the print progress of a
  GCode file. The card displays the current layer and overall print progress in real-time.
  *Note: This feature is available exclusively for "Supporters".*

### Enhancements

- **File Download Progress**: Enhanced the file download process to display progress more reliably across various
  scenarios, providing better user feedback.
- **Sliders No Longer Trigger Customization**: Adjusting sliders in the multipliers, limits, and firmware retraction
  cards will no longer accidentally activate dashboard customization mode, ensuring a smoother user experience.

### Bug Fixes

- **Archive File Handling**: Resolved an issue where tapping on archive files (such as zip files) in the file manager
  would attempt to open them instead of downloading.

## [2.7.5] - 2024-09-12

### Bug Fixes

- **Dashboard**: Fixed an issue with the spoolman card that could cause the app to show an empty dashboard.
- **File Manager**: Fixed an issue that prevented the user from accessing the file manager while klipper is in an error
  state.

## [2.7.4] - 2024-09-7

### Enhancements

- **File Operations**: The file manager now supports additional operations:
    - **Zipping**: Easily zip both files and folders.
    - **Batch Operations**: You can now delete, download, or zip selected files directly from the selection screen for
      more efficient management.

- **Printed File Indicator**: A green checkmark indicator has been added to the file browser, making it simpler to
  identify which files have already been printed.

- **Number Input Dialog**: The number input and range dialog has been streamlined for improved usability:
    - **Autofocus**: The input field now autofocuses when opened.
    - **Auto-Selection**: The current value is automatically selected for quicker editing.
    - **Keyboard Submission**: While in text editing mode, you can now submit via the keyboard action.  
      [#406](https://github.com/Clon1998/mobileraker/issues/406)

- **Spool Management**: You can now manage spools, filaments, and manufacturers through the **Spoolman** page:
    - **Add, Edit, Delete**: Easily add, modify, or remove spools and related information.

## [2.7.2] - 2024-08-26

### Enhancements

- **Revamped File Manager**: Redesigned the file manager for a more intuitive and user-friendly experience. Users can
  now easily navigate through files and folders, create new folders, upload files, and delete files or folders. The file
  manager also supports selecting multiple files and moving them to different folders.

- **Collapsible Macros**: The macro group card is now limited to a maximum of 3 rows. If this limit is exceeded, a
  button will be provided to show all macros within the group.

- **Nozzle Heating Shortcut**: Enhanced the extruder card by replacing the spool button with a direct nozzle heating
  button. This improvement allows users to quickly heat the nozzle without having to

- **Toggle Tablet Layout**: For devices that support the tablet layout, users can now toggle it on or off in the app
  settings. This feature allows users to switch between the tablet and phone layout based on their preference.

- **Progress Bar Categories on Android**: Progress bar notifications now have their own category on Android. This allows
  users to
  customize notification settings for text-based progress and progress bar notifications separately in the system
  settings. (Android only)

- **Tablet UI Beta**: The tablet UI has proven to be stable enough. Therefore, the warning card on the dashboard has
  been removed.

- **MediaMTX Support**: Added support for the MediaMTX-based webcam streamer. This allows users to use the MediaMTX
  webcam streamer with Mobileraker. [#349](https://github.com/Clon1998/mobileraker/pull/349)

### Bug Fixes

- **Tool Selector**: Fixed an issue where the tool selector broke the extruder card if the tool was using an invalid
  color variable. [#397](https://github.com/Clon1998/mobileraker/pull/397)

## [2.7.1] - 2024-07-16

### New Features

- **Filament Load and Unload Wizard**: Introduced dedicated Filament Load and Unload buttons within the control extruder
  card. These buttons launch a step-by-step wizard to assist users in loading or unloading filament. Users can configure
  the speeds and distances in the printer settings within the app.
- **Tool Selector**: Added a Tool-Selector to the Extruder Card, enhancing the functionality and ease of tool
  management.
- **Configurable ETA and Remaining Time**: Users can now configure the Estimated Time of Arrival (ETA) and Remaining
  Time via a new ETA-Source selection field in the app settings. This setting is also automatically synchronized with
  the companion which after the next companion update will also respect this setting.
- **Companion Language Synchronization**: The app now automatically synchronizes its language settings with the
  companion device to ensure notifications are displayed in the correct language, provided it is available on the
  companion.

### Enhancements

- **Realtime Remote Configuration Updates**: App-Remote-Configs now update in real-time, preventing the dashboard from
  becoming unresponsive due to a bad configuration.
- **Increased File Page Timeout**: The timeout for the File Page has been increased to prevent early disconnections on
  slow connections. This timeout can be further adjusted in the printer settings within the app.
- **Static Dashboard Widgets**: Static Dashboard Widgets (e.g., Warnings, Announcements) are now displayed only on the
  first page of the dashboard, reducing clutter on subsequent pages.
- **Independent GCode-Macro Cards**: Multiple GCode-Macro cards now operate independently and do not synchronize the
  selected group, providing greater flexibility.
- **Enhanced HttpClient Stability**: The default HttpClient idle timeout has been increased to ensure a more stable
  connection to the printer.

### Bug Fixes

- **GCode Detail Page Button Functionality**: Resolved an issue where the buttons on the GCode detail page did not
  respond correctly to the printer and Klipper state unless the dashboard was opened first.
- **Nozzle Size Metadata Display**: Fixed an issue where the GCode Page displayed `null` instead of `Unknown` if the
  nozzle size metadata was unavailable.
- **Log Sharing on iPad**: Logs can now be successfully shared on iPad devices.
- **Developer Announcements Frequency**: Corrected a problem where developer announcements were shown too frequently.
- **GCode Console History Preservation**: Fixed the issue where the GCode console history reset after navigating away
  from the page.
- **Full-Screen Webcam Page Access**: Addressed a bug preventing the full-screen webcam page from opening correctly from
  the overview page.
- **Printer Card Flickering**: Eliminated flickering of printer cards on the overview page during active prints.
- **Printer Switching Order**: Fixed an issue where switching printers via the app bar did not honor the configured
  printer order.

## [2.7.0] - 2024-06-26

### New Features

- **Customizable Dashboards for Supporters**: Users can now create up to five tabs on small screen devices and
  personalize them with various
  cards. For big screen devices like tablets it is possible to modify the layout of the
  page. [#11](https://github.com/Clon1998/mobileraker/issues/11)
- **Reorder Printers**: You can now reorder printers on the overview page by long-pressing a printer and dragging it to
  the desired position.
- **Full Tablet Support [Beta]**: The app now scales correctly on tablets, offering a more desktop-like experience
  optimized for larger screens. This includes the customizable dashboard feature, enhancing usability on tablets.

### Enhancements

- **Language Selection Menu**: Added country flags to improve accessibility.
- **Remote Connection Disclaimer**: Included a disclaimer for remote connection failures, clarifying the differences
  between _Mobileraker-Supporters_ and _OctoEverywhere_/_Obico-Supporters_.
- **Printer Settings Simplification**: Removed the `Websocket Address` field to reduce complexity and confusion.
- **Webcam Card Error Messages**: Enhanced the display of error messages for webcam cards for better clarity and
  consistency.
- **Webcam Card Visibility**: If a single webcam fails to load, the entire webcam card can now be
  hidden. [#217](https://github.com/Clon1998/mobileraker/issues/217)
- **Console Page Improvements**: More accurate command suggestions based on user input.
- **Num-Edit Dialog Slider**: Increased the slider size for easier usability.
- **Fan Control Enhancement**: You can now toggle fans to 100%/0% in the fans card by long-pressing the _Set_ button.
- **File Page Caching**: The File page now caches results to prevent unnecessary reloading when switching between tabs
  or files.
- **Default Presets**: For new machines, the app now includes default temperature presets for PLA, PETG and ABS.
- **Tach Fan Support**: The fan card now shows the tachometer value for fans that support it.
- **Config File Sharing**: Added the ability to share config files (`*.cfg`) with other apps.

### Bug Fixes

- **Back Button**: Fixed the Back button on the printer add page.
- **Spoolman Card**: The Spoolman card now displays the remaining filament with two decimal
  places. [#364](https://github.com/Clon1998/mobileraker/issues/364)
- **Printer Deletion Issue**: Fixed an issue that caused the app to get stuck when deleting a printer.
- **JobQueue Button**: The JobQueue button on the files page now only shows up if on the gcode tab.

### i18n

- **Hungarian Translation**: Updated the Hungarian translation, thanks to [@AntoszHUN](https://github.com/AntoszHUN).

## [2.6.19] - 2024-05-09

### Enhancements

- Implemented support for the `Z Thermal Adjust` sensor in the Temperature
  card. [#340](https://github.com/Clon1998/mobileraker/issues/340)
- Enhanced animations and transitions on the dashboard page.
- Updated Number Edit Dialog in slider mode to include buttons for incremental value adjustment.
- Refined coloring of circular print progress bar to align with the theme.
- MJPEG webcams now exhibit smoother transition when opened in fullscreen.

### Bug Fixes

- Eliminated dependency on firebase_ui_auth to resolve crashing on Android attributed to dynamic
  links. [#359](https://github.com/Clon1998/mobileraker/issues/359)
- Rectified overview page "jumping" in certain scenarios.
- Corrected faulty state of dashboard cards in case of prolonged or failed klipper/moonraker data fetching.

## [2.6.18] - 2024-04-30

Hotfixing broken overview page

## [2.6.17] - 2024-04-29

### Enhancements

- Introduced a new feature in machine settings that allows users to customize the order of sensors, heaters, fans, and
  outputs according to their preferences in their respective cards.

### Bug Fixes

- Optimized the screw tilt dialog to prevent it from triggering excessively when the app was backgrounded for a long
  period. [#362](https://github.com/Clon1998/mobileraker/issues/362)

## [2.6.16] - 2024-04-26

### Bug Fixes

- Fixed default name while adding a new macro group.
- Fixed color picker on IOS. [#360](https://github.com/Clon1998/mobileraker/issues/360)

### Localization

- Updated the Hungarian translation, thanks
  to [@AntoszHUN](https://github.com/AntoszHUN). [#353](https://github.com/Clon1998/mobileraker/pull/353)

## [2.6.15] - 2024-04-24

### Bug Fixes

- Fixed an issue that, in some cases, prevented the app from refreshing a printer during a pull-to-refresh action.
- The webcam card no longer displays an error if no webcams were found.
- Filament runout sensor and calibration watcher now work correctly after switching between printers.
- Added support for the `screws_tilt_adjust` dialog. [#175](https://github.com/Clon1998/mobileraker/issues/175)
- WebRtc webcam now pauses when the app is in the background.

## [2.6.14] - 2024-03-25

### Changed Features

- Added support for self hosted Obico instances. Users can now add their own Obico instance to the app and use it to
  connect to their printers. [#294](https://github.com/Clon1998/mobileraker/issues/294)
- Added a setting that allows users to configure if the macro execution should be confirmed. If enabled, the app will
  show a confirmation dialog before executing a macro via the dashboard.
- [Android] Added a setting to enable/disable the progressbar notification for print progress on Android.

### Bug Fixes

- Fixed an issue that prevented the Power API card from being displayed if klipper is in shutdown state.

## [2.6.13] - 2024-03-15

- Hotfixing issue with the French translation preventing the app from starting for users with active French translation.

## [2.6.12] - 2024-03-13

### Major Updates

- Added support for filament runout and motion sensors. Users can now monitor the status of these sensors and customize
  their behavior through dashboard.

### Changed Features

- Updated 🇫🇷 translation, thanks to Arnaud Petetin and [@dtourde](https://github.com/dtourde).
- Refactored the PrintInfo/MachineStatus card into its own component with some more animations, improving the overall
  user experience and performance.
- The UI theme on the app settings page now shows a hint if the current theme is printer-specific.
- Temperature fan cards now also show a graph to match the other temperature card
  elements. ([#118](https://github.com/Clon1998/mobileraker/issues/118))
- Updated the title of outputs to "Miscellaneous," reflecting the inclusion of filament sensors alongside other outputs.
- The horizontal scrollable cards now snap to the nearest card when scrolling, providing a more intuitive user
  experience.

### Bug Fixes

- The Step Selector in the Z-Offset card now shows up to three decimal places again.
- Printer specific themes are now correctly applied on app start.

## [2.6.11-hotfix1] - 2024-02-20

### ANDROID ONLY

### Bug Fixes

- Fixed an issue that prevented the app from starting on some android devices.

## [2.6.11] - 2024-02-02

### Major Updates

- Introduced bed mesh visualization card to the dashboard, empowering users to switch seamlessly between various mesh
  profiles.
  ([#196](https://github.com/Clon1998/mobileraker/issues/196))
- Added a spoolman card to the dashboard, enabling users to monitor their filament usage and manage their spools.
  ([#245](https://github.com/Clon1998/mobileraker/issues/245))

### Changed Features

- Webcam paths (URLs) now support relative paths and respect the configured HTTP address port (Printer address),
  addressing previous issues of ignoring it. This might require users to reconfigure their webcams.
- Updated 🇩🇪 translation, thanks to [@Clon1998](https://github.com/clon1998)
- Updated 🇹🇷 translation, thanks to [@larinspub](https://github.com/larinspub)

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
- Improved the app's settings page by introducing hints, providing users with clearer insights into the functionality
  and implications of each setting.

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

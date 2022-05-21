# Mobileraker
![GitHub](https://img.shields.io/github/license/Clon1998/mobileraker?style=for-the-badge)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/clon1998/mobileraker?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/Clon1998/mobileraker?style=for-the-badge)

![GitHub Repo stars](https://img.shields.io/github/stars/Clon1998/mobileraker?style=for-the-badge)
![GitHub all releases](https://img.shields.io/github/downloads/clon1998/mobileraker/total?style=for-the-badge)
![Custom badge](https://img.shields.io/endpoint?color=%235fd102&style=for-the-badge&url=https%3A%2F%2Fplayshields.herokuapp.com%2Fplay%3Fi%3Dcom.mobileraker.android%26l%3DAndroid%26m%3D%24installs)

Get Mobileraker now:  
[!["PlayStore"](https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.mobileraker.android)
[!["AppStore"](https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white)](https://apps.apple.com/us/app/mobileraker/id1581451248)
---

🏷️ Mobileraker works as a simple UI for Klipper on the phone. Connect it to an existing moonraker installation and control the printer.

🧰  With Mobileraker, the user has access to critical machine commands:
- Pause, Resume, Stop a print job
- Monitor the print progress
- Control all axis of the machine
- Control the heaters
- Get the current temperature readings
- Control fans
- Control pins like LEDs
- Send GCode Macros
- Emergency Stop the machine

🛠️  Additionally, Mobileraker enables the user to monitor the machine via an integrated webcam viewer with support for multiple cams, interact with the machine through the GCode console and browse the available GCode files to start a new print job.
Mobileraker also offers comfort features like remote push notifications about the progress of a print job, temperature presets.

✨  One more thing ...
Mobileraker can manage multiple machines!

✍🏻  Some final words from the project owner:
Hi,
My name is Patrick Schmidt, and I am the developer of Mobileraker. Mobileraker started as a small side project with the intention to be able to control My 3D printer via My phone. After posting some screenshots of the app to the 3D printing community, the public interest in Mobileraker grew, and I published it to the app stores.
As I am only able to work on Mobileraker in my free time, I am always thankful for support and feedback. Either via lovely messages of people enjoying Mobileraker, good reviews in the store or through donations. I hope you enjoy Mobileraker and happy printing 🙏!


## Support me
Want to support me?


[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/PadS)


## Push Notifications / Remote Notification
In order to use remote notifications be sure to follow the setup guide to install [Mobileraker's Companion](https://github.com/Clon1998/mobileraker_companion) for Klipper/Moonraker.

## App Screenshots

|                    Dashboard - Dash                     |                   Dashboard - Controls                    |
|:-------------------------------------------------------:|:---------------------------------------------------------:|
| ![Floating Style](misc/images/dashboard_screenshot.png) | ![Grounded Style](misc/images/dashboard2_screenshot.png)  |
|              Overview - Multiple Printers               |                      GCode - Console                      |
| ![Floating Style](misc/images/overview_screenshot.png)  |   ![Grounded Style](misc/images/console_screenshot.png)   |
|                   GCode File Browser                    |                    GCode File Details                     |
|   ![Floating Style](misc/images/files_screenshot.png)   | ![Grounded Style](misc/images/file_detail_screenshot.png) |

## Planed features
* [x] Support for multiple printers
* [ ] Multiple colors/themes and dark mode
  * [x] Dark mode
* [x] Notifications (Might need an klipper addon?)
  * [x] Print done
  * [x] Print progress
  * [ ] Klipper errors
* [x] Overview page
  * [x] Refactor current layout with multiple and clearer menu-tabs
  * [ ] Add temperature graphs
  * [x] Add a console
  * [ ] Add mesh selection
  * [ ] Add query endstops
* [ ] Files(STL) page
  * [ ] Upload stls
  * [ ] Stl preview
  * [ ] Stl viewer
* [ ] Config page
* [ ] Print-statistics/history page
* [ ] Klipper power control feature

## Getting Started
After importing this project into your IDE be sure to run `flutter packages pub run build_runner build` in order to generate required files!

![Alt](https://repobeats.axiom.co/api/embed/4b14f21342f3066389fba0d6e2ebf469f1033848.svg "Repobeats analytics image")

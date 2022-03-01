# mobileraker
![GitHub](https://img.shields.io/github/license/Clon1998/mobileraker?style=for-the-badge)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/clon1998/mobileraker?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/Clon1998/mobileraker?style=for-the-badge)

![GitHub Repo stars](https://img.shields.io/github/stars/Clon1998/mobileraker?style=for-the-badge)
![GitHub all releases](https://img.shields.io/github/downloads/clon1998/mobileraker/total?style=for-the-badge)
![Custom badge](https://img.shields.io/endpoint?color=%235fd102&style=for-the-badge&url=https%3A%2F%2Fplayshields.herokuapp.com%2Fplay%3Fi%3Dcom.mobileraker.android%26l%3DAndroid%26m%3D%24installs)

Mobileraker is a Flutter app to control a single or multiple 3D printers running Klipper+Moonraker.

Checkout the first release to download an Android APK!


[!["PlayStore"](https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.mobileraker.android)
[!["AppStore"](https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white)](https://testflight.apple.com/join/ekk3AM5z)



## Support me
Want to support me?


[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/PadS)


## Push Notifications / Remote Notification
In order to use remote notifications be sure to follow the setup guide to install [Mobileraker's Companion](https://github.com/Clon1998/mobileraker_companion) for Klipper/Moonraker.

Home           |  More images...
:------------------------------------------------------:|:-------------------------------------------------------:
![Floating Style](misc/images/Screenshot_1628195007.png)  |  ![Grounded Style](misc/images/Screenshot_1628195012.png)
![Floating Style](misc/images/Screenshot_20210808-223102.jpg)  |  ![Grounded Style](misc/images/Screenshot_20210808-223110.jpg)


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
  * [ ] Add a console
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

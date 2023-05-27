> Have a question or suggestion for the FAQ? Open an issue on GitHub, and we will make sure to address it here!

## 🚀 What is Mobileraker?

🏷️ Mobileraker serves as a user-friendly interface (UI) for Klipper on mobile devices. It enables you to connect to an
existing moonraker installation and control your printer.

## 📷 How do I add a Webcam?

Mobileraker comes with built-in support for displaying MJPEG webcam streams directly on the dashboard screen. You can
add multiple webcams by accessing the printer's settings page. To access the settings, open the navigation bar and tap
the gear icon located next to your printer's name. This will open the printer's settings. Scroll down to the webcam
section, where you can add or edit webcams. Don't forget to save your changes after adding or editing a webcam.

> Starting with Mobileraker version 2.3.0, webcam configs are synced with Mainsail/Fluidd

## 🛰️ Remote printer access?

There are several options available for remote printer access:

- VPN
- [Octoeverywhere](https://octoeverywhere.com/)

> The recommended and most convenient option is Octoeverywhere.

## 👨‍💻 How to set up push notifications?

Mobileraker supports native push notifications for both Android and iOS. To enable this feature, you need to install and
correctly set up the [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion) on your device. The
companion app allows you to receive notifications even when you are not connected to the same network as your printer.

Here's a summary of the companion installation process:

```shell
cd ~/
git clone https://github.com/Clon1998/mobileraker_companion.git
cd mobileraker_companion
./scripts/install-mobileraker-companion.sh
```

For more detailed instructions, visit the official GitHub page
of  [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion).

## 💬 What kind of notifications can mobileraker send?

Currently, Mobileraker supports the following types of notifications:

- Print-progress
- Print-status
- Custom `M117` notifications,
  see [Custom Notifications](https://github.com/Clon1998/mobileraker_companion/blob/main/docs/Custom_Notifications.md)

## 📫 Why do the notifications not update if I open the app?

In an earlier version of the app, the notification system was designed to update notifications and progress
notifications within the app. However, due to a change in the underlying notification library, the entire notification
creation process had to be moved to the companion app. This change ensures reliable remote notifications on all devices.
As a result, the app is currently unable to update notifications.

## 🌪️ How can I switch the active printer without using the navbar?
You can easily switch between printers by swiping horizontally on the page's title.

## 🖼️ Is it possible for Mobileraker to send notifications along with a screenshot?
Currently, only mobileraker supporters have access to notification support that includes screenshots.

## 🦺 Does Mobileraker store the notification's screenshots the backend receives?
To ensure efficient delivery of push notifications, mobilerarker caches all images received until they are delivered to the user. However, all images are encrypted and deleted within 48 hours of receiving the initial request from the `mobilraker_companion`. If a user wants to prevent the transmission of image data to the backend, they can simply disable it in the `Mobileraker.conf` file (`include_snapshot: False` in the `[general]` section).

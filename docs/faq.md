> The FAQ is still WIP

## 🚀 What is Mobileraker?

🏷️ Mobileraker works as a simple UI for Klipper on the phone. Connect it to an existing moonraker installation and
control the printer.

## 📷 How do I add a Webcam?

Out of the box, Mobileraker offers support for any MJPEG webcam stream directly on the dashboard screen. You can add as
many webcams as you like on the printer's setting page. To open it, open the navigation bar and press the gear icon at
the top, right next to your printer's name. This opens the printer's settings. Scroll down until you reach the webcam
section. After you are done adding/editing a webcam please make sure you press save.

## 🛰️ Remote printer access?

There exist multiple options to access your printer from everywhere. Among these options are:

- VPN
- [Octoeverywhere](https://octoeverywhere.com/)

> The fastest, easiest, and suggested option is Octoeverywhere.

## 👨‍💻 How to set up push notifications?

Mobileraker supports native push notifications for both Android and iOS.
The notification system requires that the user installed
the [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion) and has it set up correctly. Afterward,
the companion can send you notifications even if you are not connected to the same network as your printer.

Here is a short summary of how to install the companion:

```shell
cd ~/
git clone https://github.com/Clon1998/mobileraker_companion.git
cd mobileraker_companion
./scripts/install-mobileraker-companion.sh
```

Find out more at the official GitHub page of [mobileraker_companion](https://github.com/Clon1998/mobileraker_companion).

## 💬 What kind of notifications can mobileraker send?

Currently, mobileraker offers support for the following kind of notifications:

- Print-progress
- Print-status
- Custom `M117` notifications,
  see [Custom Notifications](https://github.com/Clon1998/mobileraker_companion/blob/main/docs/Custom_Notifications.md)

## 📫 Why do the notifications not update if I open the app?
In an initial version of the app's notification system, I implemented it in a way that ensured that the app was able to update any notification/progress notification. However, due to a change in the library that offers notification functionality, I was forced to move the entire notification creation progress to the companion. This also ensured that the remote notifications work reliably on all devices. However, this also meant that the App currently is unable to update any notifications.

## 🌪️ How can I switch the active printer without using the navbar?
You can easily switch between printers by swiping horizontally on the page's title.
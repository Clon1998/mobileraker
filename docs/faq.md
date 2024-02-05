> Have a question or suggestion for the FAQ? Open an issue on GitHub, and we will make sure to address it here!

## 🚀 What is Mobileraker?

🏷️ Mobileraker serves as a user-friendly interface (UI) for Klipper on mobile devices. It enables you to connect to an
existing moonraker installation and control your printer.

## 📷 How do I add a Webcam?

Mobileraker comes with built-in support for displaying WebRTC & MJPEG webcam streams directly on the dashboard screen.
You can
add multiple webcams by accessing the printer's settings page. To access the settings, open the navigation bar and tap
the gear icon located next to your printer's name. This will open the printer's settings. Scroll down to the webcam
section, where you can add or edit webcams. Don't forget to save your changes after adding or editing a webcam.

> Starting with Mobileraker version 2.3.0, webcam configs are synced with Mainsail/Fluidd

## 🎥 My Webcam Is Not Showing Up in Mobileraker but Works in Mainsail/Fluidd

If you're experiencing an issue where your webcam isn't displaying in Mobileraker while it works in Mainsail or Fluidd, the problem may be related to Mobileraker's auto-resolving of URLs. Typically, webcams are added using a relative path (e.g., `/webcam?action=stream`), and Mobileraker attempts to convert it to an absolute path using the 'Printer - Address' you provided during printer setup. Alternatively, you can directly add a webcam using its absolute path (e.g., `http://192.0.0.1:8080/webcam/action=stream`), bypassing Mobileraker's auto-resolving process.

### Why Auto-Resolving?

Mobileraker was initially designed for a simple setup with one printer and one Raspberry Pi running FluiddPi or MainsailOS. In this scenario, resolving a relative webcam URL to an absolute one was straightforward, as everything operated on a single host. However, in more complex setups, such as running multiple printers on a single Pi or using custom images like CrealityOS or Klipper, correctly resolving the webcam URL can become challenging. If you encounter any webcam-related issues, we recommend opening Mainsail or Fluidd, copying the stream/image URL directly as an absolute webcam URL into Mobileraker, and checking Mobileraker's error message for the attempted URL.

### Auto-Resolve Process

Here's a breakdown of how the auto-resolve process works:

**Given:**
- Printer Address: `http://192.6.2.1:8080`
- Websocket Address: `http://192.6.2.1:8080/websocket`
- Cam-URI: `/webcam1/action=stream`

The auto-resolve process will take the 'Printer Address' (`http://192.6.2.1:8080`) and append the relative path, resulting in `http://192.6.2.1:8080/webcam1/action=stream`. If you encounter issues, Mobileraker's error message will provide the attempted URL for debugging purposes.

## 🛰️ Remote printer access?

There are several options available for remote printer access:

- VPN
- Reverse Proxy (e.g., Nginx) via manual setup in printer settings
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

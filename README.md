# README Pack for LAN Share

[English](README.md) | [中文](README-zh.md)

Below are two ready-to-copy versions for this project:

---

# README.md

# LAN Share

A Flutter-based local network sharing tool for sending text, files, and folders between devices on the same LAN.

This project is designed for simple peer-to-peer transfer inside a local network. It uses local device discovery and direct socket communication, so users can quickly find nearby devices and share content without relying on a cloud service.

## Features

* Local device discovery on the same LAN
* Send plain text between devices
* Send one or more files to one or more devices
* Send folders
* Desktop and Android UI
* Device selection for batch sending
* Manual device adding by IP and port
* Transfer task list and status display
* Log panel and log export
* Basic connection test tools

## Current Platform Status

* Android: supported with mobile UI
* Linux: supported with desktop UI
* Windows: supported with desktop UI
* macOS: desktop scaffold exists, but should be tested before production use
* iOS: scaffold exists, but this project is mainly designed for Android and desktop scenarios
* Web: not supported now

## Tech Stack

* Flutter
* Dart
* Local socket communication
* File Picker
* Path Provider
* Archive

## Project Structure


    lan_share/
    ├─ android/
    ├─ ios/
    ├─ linux/
    ├─ macos/
    ├─ web/
    ├─ windows/
    ├─ lib/
    │  ├─ main.dart
    │  ├─ app.dart
    │  ├─ models/
    │  ├─ pages/
    │  ├─ services/
    │  ├─ utils/
    │  └─ widgets/
    ├─ test/
    ├─ pubspec.yaml
    └─ README.md


## Main Modules

### 1. Device Discovery

The project discovers nearby devices in the same LAN and keeps a device list for sending.

### 2. Text Transfer

Users can send plain text to selected devices.

### 3. File Transfer

Users can choose one or more files and send them to selected devices.

### 4. Folder Transfer

Users can choose a folder and send it to selected devices.

### 5. Desktop UI

The desktop page focuses on:

* device list
* manual device adding
* text sending
* file and folder sending
* transfer queue
* logs
* connection testing

### 6. Mobile UI

The Android page focuses on:

* device discovery
* text sending
* multi-file sending
* folder sending
* received content display

## Default Ports

The code uses these default ports:

* Discovery: `40401`
* Text: `40402`
* File: `40403`

Make sure these ports are allowed in your local firewall if devices cannot discover or connect to each other.

## Requirements

* Flutter SDK
* Dart SDK
* A LAN environment where devices can reach each other
* Android Studio or VS Code for development
* For desktop builds, enable the target platform first

## Getting Started

### 1. Clone the project

```bash
git clone https://github.com/ldk2645/lan_share.git
cd lan_share
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run on Windows

```bash
flutter run -d windows
```

### 4. Run on Linux

```bash
flutter run -d linux
```

### 5. Run on Android

```bash
flutter run -d android
```

## Build

### Windows

```bash
flutter build windows
```

### Linux

```bash
flutter build linux
```

### Android APK

```bash
flutter build apk
```

## Usage

1. Connect both devices to the same local network.
2. Open LAN Share on each device.
3. Wait for automatic discovery, or add a device manually.
4. Select one or more target devices.
5. Choose to send text, files, or a folder.
6. Check the transfer list and logs if something fails.

## Common Issues

### Devices cannot find each other

* Make sure both devices are on the same LAN
* Check firewall rules
* Check whether the discovery port is blocked
* Try manual device adding by IP

### File transfer fails

* Check whether the receiver is online
* Check firewall rules for file port
* Try a smaller file first
* Read logs from the log panel

### Web does not work

This is expected. The current app shows that web is not supported.

## Suggested Future Improvements

* Better retry and resume support
* Stronger transfer confirmation and checksum validation
* Better Android background discovery stability
* Better packaging and release scripts
* More complete test coverage
* iOS and macOS real-device verification

## License

You can add your own license here, such as MIT.


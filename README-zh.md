# LAN Share

[English](README.md) | [中文](README-zh.md)

一个基于 Flutter 的局域网传输工具，用来在同一局域网内发送文字、文件和文件夹。

本项目的目标是做一个简单、直接的局域网点对点分享工具。它通过局域网设备发现和本地 Socket 通信，让设备之间不依赖云端也能快速互传内容。

## 功能特点

* 同一局域网内自动发现设备
* 发送纯文本消息
* 向一个或多个设备发送单个或多个文件
* 发送文件夹
* 提供桌面端和安卓端界面
* 支持多设备选择后批量发送
* 支持手动输入 IP 和端口添加设备
* 支持传输任务列表和状态显示
* 支持日志查看与日志导出
* 支持基础连通性测试

## 当前平台支持情况

* Android：支持，使用移动端界面
* Linux：支持，使用桌面端界面
* Windows：支持，使用桌面端界面
* macOS：已有桌面工程骨架，但正式使用前建议先完整测试
* iOS：已有工程骨架，但当前项目主要面向 Android 和桌面端场景
* Web：暂不支持

## 技术栈

* Flutter
* Dart
* 本地 Socket 通信
* File Picker
* Path Provider
* Archive

## 项目结构


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


## 核心模块

### 1. 设备发现

项目会在局域网内发现附近设备，并维护一个可发送的设备列表。

### 2. 文本传输

用户可以向已选择的设备发送纯文本内容。

### 3. 文件传输

用户可以选择一个或多个文件，并发送给选中的设备。

### 4. 文件夹传输

用户可以选择一个文件夹，并发送给选中的设备。

### 5. 桌面端界面

桌面端页面主要包含：

* 设备列表
* 手动添加设备
* 文本发送
* 文件和文件夹发送
* 传输队列
* 日志面板
* 连通性测试

### 6. 移动端界面

安卓端页面主要包含：

* 设备发现
* 文本发送
* 多文件发送
* 文件夹发送
* 接收内容展示

## 默认端口

当前代码中默认使用以下端口：

* 发现端口：`40401`
* 文本端口：`40402`
* 文件端口：`40403`

如果设备之间无法发现或连接，请先检查本地防火墙是否放行这些端口。

## 环境要求

* Flutter SDK
* Dart SDK
* 可互相访问的局域网环境
* Android Studio 或 VS Code
* 如果要构建桌面端，请先启用对应平台支持

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/ldk2645/lan_share.git
cd lan_share
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行 Windows 版本

```bash
flutter run -d windows
```

### 4. 运行 Linux 版本

```bash
flutter run -d linux
```

### 5. 运行 Android 版本

```bash
flutter run -d android
```

## 构建

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

## 使用说明

1. 让两台设备连接到同一个局域网。
2. 在每台设备上打开 LAN Share。
3. 等待自动发现设备，或者手动添加设备。
4. 选择一个或多个目标设备。
5. 选择发送文字、文件或文件夹。
6. 如果传输失败，可以查看传输列表和日志。

## 常见问题

### 设备互相发现不到

* 确认两台设备在同一个局域网内
* 检查系统防火墙
* 检查发现端口是否被拦截
* 可以尝试手动输入 IP 添加设备

### 文件传输失败

* 确认接收端在线
* 检查文件端口是否被防火墙拦截
* 先尝试发送小文件
* 到日志面板查看详细报错

### Web 不能使用

这是当前的预期行为，项目里已经明确写了 Web 暂不支持。

## 后续可优化方向

* 更完善的重试和断点续传
* 更强的传输确认与校验机制
* 更稳定的 Android 后台发现能力
* 更完整的打包和发布脚本
* 更完善的自动化测试
* iOS 和 macOS 真机验证

## License

你可以在这里补充自己的开源协议，例如 MIT。

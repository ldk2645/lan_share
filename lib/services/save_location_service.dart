import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SaveLocationService {
  SaveLocationService._internal();

  static final SaveLocationService instance = SaveLocationService._internal();

  bool useDefaultPath = true;
  String? customBasePath;

  Future<void> chooseCustomBasePath() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && path.trim().isNotEmpty) {
      customBasePath = path;
      useDefaultPath = false;
    }
  }

  void useDefault() {
    useDefaultPath = true;
  }

  void useCustom(String path) {
    customBasePath = path;
    useDefaultPath = false;
  }

  Future<Directory> getBaseReceiveDirectory() async {
    if (!useDefaultPath &&
        customBasePath != null &&
        customBasePath!.trim().isNotEmpty) {
      final dir = Directory(customBasePath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final dir = await _resolveDefaultDirectory('Received');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getBaseCacheDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(
        '${tempDir.path}${Platform.pathSeparator}LanShareCache',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      final dir = Directory(
        '${Directory.current.path}${Platform.pathSeparator}Cache',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  Future<File> createTempCacheFile(String fileName) async {
    final cacheDir = await getBaseCacheDirectory();
    final safeName = _sanitize(fileName);
    return File('${cacheDir.path}${Platform.pathSeparator}$safeName');
  }

  Future<String> previewBaseReceivePath() async {
    final dir = await getBaseReceiveDirectory();
    return dir.path;
  }


  Future<Directory> ensureSenderCategoryDirectory({
    required String senderName,
    required String category,
  }) async {
    final base = await getBaseReceiveDirectory();
    final safeSender = _sanitize(senderName);
    final safeCategory = _sanitize(category);

    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$safeSender'
      '${Platform.pathSeparator}$safeCategory',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  String sanitizeFileName(String value) {
    return _sanitize(value);
  }

  Future<Directory> _resolveDefaultDirectory(String leafName) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      return Directory('${base.path}${Platform.pathSeparator}$leafName');
    } catch (_) {
      return Directory(
        '${Directory.current.path}${Platform.pathSeparator}$leafName',
      );
    }
  }

  String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll('\n', '_')
        .replaceAll('\r', '_')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }
}

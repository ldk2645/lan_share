import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

import '../models/device.dart';
import 'log_service.dart';
import 'save_location_service.dart';

class ReceivedFileRecord {
  final String fileName;
  final String savedPath;
  final int size;
  final String fromDeviceName;
  final String fromIp;
  final DateTime time;

  ReceivedFileRecord({
    required this.fileName,
    required this.savedPath,
    required this.size,
    required this.fromDeviceName,
    required this.fromIp,
    required this.time,
  });
}

class ReceivedFolderRecord {
  final String folderName;
  final String savedPath;
  final int zipSize;
  final String fromDeviceName;
  final String fromIp;
  final DateTime time;

  ReceivedFolderRecord({
    required this.folderName,
    required this.savedPath,
    required this.zipSize,
    required this.fromDeviceName,
    required this.fromIp,
    required this.time,
  });
}

class FileTransferService {
  static const int filePort = 40403;

  final String selfName;
  ServerSocket? _serverSocket;

  final StreamController<ReceivedFileRecord> _receivedFileController =
      StreamController<ReceivedFileRecord>.broadcast();

  final StreamController<ReceivedFolderRecord> _receivedFolderController =
      StreamController<ReceivedFolderRecord>.broadcast();

  Stream<ReceivedFileRecord> get receivedFileStream =>
      _receivedFileController.stream;

  Stream<ReceivedFolderRecord> get receivedFolderStream =>
      _receivedFolderController.stream;

  FileTransferService({required this.selfName});

  Future<void> startReceiver() async {
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      filePort,
      shared: true,
    );

    await LogService.instance.info(
      'File receiver started at ${_serverSocket?.address.address}:$filePort',
    );

    _serverSocket!.listen(_handleClient);
  }

  Future<void> _handleClient(Socket socket) async {
    final headerBytes = <int>[];
    bool headerDone = false;

    IOSink? sink;
    File? outputFile;

    String packetType = '';
    String fileName = 'unknown.bin';
    String folderName = 'unknown_folder';
    String fromName = 'Unknown_Device';
    String fromIp = socket.remoteAddress.address;
    int expectedSize = 0;
    int receivedSize = 0;

    try {
      await for (final chunk in socket) {
        if (!headerDone) {
          final index = chunk.indexOf(10);

          if (index == -1) {
            headerBytes.addAll(chunk);
            continue;
          }

          headerBytes.addAll(chunk.sublist(0, index));
          final headerText = utf8.decode(headerBytes);
          final header = jsonDecode(headerText) as Map<String, dynamic>;

          packetType = header['type'] as String? ?? '';
          fromName = header['fromName'] as String? ?? 'Unknown_Device';
          fromIp = header['fromIp'] as String? ?? socket.remoteAddress.address;
          expectedSize = header['fileSize'] as int? ?? 0;

          if (packetType == 'file_transfer') {
            fileName = header['fileName'] as String? ?? 'unknown.bin';

            final saveDir = await SaveLocationService.instance
                .ensureSenderCategoryDirectory(
                  senderName: fromName,
                  category: 'Files',
                );

            outputFile = File(
              '${saveDir.path}${Platform.pathSeparator}$fileName',
            );
            outputFile = await _uniqueFile(outputFile);
            sink = outputFile.openWrite();
          } else if (packetType == 'folder_transfer') {
            folderName = header['folderName'] as String? ?? 'unknown_folder';

            final saveDir = await SaveLocationService.instance
                .ensureSenderCategoryDirectory(
                  senderName: fromName,
                  category: 'Folders',
                );

            final tempZip = File(
              '${saveDir.path}${Platform.pathSeparator}${folderName}_temp.zip',
            );

            outputFile = await _uniqueFile(tempZip);
            sink = outputFile.openWrite();
          } else {
            throw Exception('Unsupported packet type: $packetType');
          }

          headerDone = true;

          final remain = chunk.sublist(index + 1);
          if (remain.isNotEmpty) {
            sink.add(remain);
            receivedSize += remain.length;
          }
        } else {
          sink?.add(chunk);
          receivedSize += chunk.length;
        }
      }

      await sink?.flush();
      await sink?.close();

      if (packetType == 'file_transfer' && outputFile != null) {
        final record = ReceivedFileRecord(
          fileName: outputFile.uri.pathSegments.last,
          savedPath: outputFile.path,
          size: receivedSize,
          fromDeviceName: fromName,
          fromIp: fromIp,
          time: DateTime.now(),
        );

        _receivedFileController.add(record);

        await LogService.instance.info(
          'Received file ${record.fileName} from $fromName ($fromIp), bytes=$receivedSize/$expectedSize, saved=${record.savedPath}',
        );
      }

      if (packetType == 'folder_transfer' && outputFile != null) {
        final folderDir = await SaveLocationService.instance
            .ensureSenderCategoryDirectory(
              senderName: fromName,
              category: 'Folders',
            );

        final finalFolder = await _uniqueDirectory(
          Directory('${folderDir.path}${Platform.pathSeparator}$folderName'),
        );
        await finalFolder.create(recursive: true);

        await _extractZipToDirectory(
          zipFile: outputFile,
          targetDir: finalFolder,
        );

        if (await outputFile.exists()) {
          await outputFile.delete();
        }

        final record = ReceivedFolderRecord(
          folderName: finalFolder.uri.pathSegments
              .where((e) => e.isNotEmpty)
              .last,
          savedPath: finalFolder.path,
          zipSize: receivedSize,
          fromDeviceName: fromName,
          fromIp: fromIp,
          time: DateTime.now(),
        );

        _receivedFolderController.add(record);

        await LogService.instance.info(
          'Received folder ${record.folderName} from $fromName ($fromIp), zipBytes=$receivedSize/$expectedSize, saved=${record.savedPath}',
        );
      }
    } catch (e) {
      await sink?.flush();
      await sink?.close();

      await LogService.instance.error('Receive file/folder failed: $e');
    } finally {
      await socket.close();
    }
  }

  Future<void> _extractZipToDirectory({
    required File zipFile,
    required Directory targetDir,
  }) async {
    final input = InputFileStream(zipFile.path);
    final archive = ZipDecoder().decodeStream(input);
    input.close();

    for (final entry in archive) {
      final rawName = entry.name.replaceAll('\\', '/');

      if (rawName.isEmpty) {
        continue;
      }

      String relativeName = rawName;

      final firstSlash = rawName.indexOf('/');
      if (firstSlash != -1) {
        relativeName = rawName.substring(firstSlash + 1);
      }

      if (relativeName.isEmpty) {
        continue;
      }

      final outPath =
          '${targetDir.path}${Platform.pathSeparator}${relativeName.replaceAll('/', Platform.pathSeparator)}';

      if (entry.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
      } else {
        final outDir = Directory(outPath);
        await outDir.create(recursive: true);
      }
    }
  }

  Future<File> _uniqueFile(File file) async {
    if (!await file.exists()) {
      return file;
    }

    final path = file.path;
    final dotIndex = path.lastIndexOf('.');
    final hasExt = dotIndex > path.lastIndexOf(Platform.pathSeparator);

    final namePart = hasExt ? path.substring(0, dotIndex) : path;
    final extPart = hasExt ? path.substring(dotIndex) : '';

    int i = 1;
    while (true) {
      final candidate = File('$namePart ($i)$extPart');
      if (!await candidate.exists()) {
        return candidate;
      }
      i++;
    }
  }

  Future<Directory> _uniqueDirectory(Directory dir) async {
    if (!await dir.exists()) {
      return dir;
    }

    final path = dir.path;
    int i = 1;
    while (true) {
      final candidate = Directory('$path ($i)');
      if (!await candidate.exists()) {
        return candidate;
      }
      i++;
    }
  }

  Future<void> sendFileToDevices({
    required File file,
    required String fromName,
    required String fromIp,
    required List<Device> devices,
  }) async {
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();

    for (final device in devices) {
      try {
        final socket = await Socket.connect(
          device.ip,
          device.filePort,
          timeout: const Duration(seconds: 5),
        );

        final header = {
          'type': 'file_transfer',
          'fileName': fileName,
          'fileSize': fileSize,
          'fromName': fromName,
          'fromIp': fromIp,
          'time': DateTime.now().toIso8601String(),
        };

        socket.add(utf8.encode('${jsonEncode(header)}\n'));

        await for (final chunk in file.openRead()) {
          socket.add(chunk);
        }

        await socket.flush();
        await socket.close();

        await LogService.instance.info(
          'Sent file $fileName to ${device.name} (${device.ip}:${device.filePort}), bytes=$fileSize',
        );
      } catch (e) {
        await LogService.instance.error(
          'Send file $fileName to ${device.name} failed: $e',
        );
      }
    }
  }

  Future<void> sendFolderToDevices({
    required Directory folder,
    required String fromName,
    required String fromIp,
    required List<Device> devices,
  }) async {
    final folderName = folder.uri.pathSegments.where((e) => e.isNotEmpty).last;

    final tempZipPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '${folderName}_${DateTime.now().millisecondsSinceEpoch}.zip';

    final encoder = ZipFileEncoder();
    encoder.create(tempZipPath);
    encoder.addDirectory(folder, includeDirName: true);
    encoder.close();

    final zipFile = File(tempZipPath);
    final zipSize = await zipFile.length();

    for (final device in devices) {
      try {
        final socket = await Socket.connect(
          device.ip,
          device.filePort,
          timeout: const Duration(seconds: 5),
        );

        final header = {
          'type': 'folder_transfer',
          'folderName': folderName,
          'fileSize': zipSize,
          'fromName': fromName,
          'fromIp': fromIp,
          'time': DateTime.now().toIso8601String(),
        };

        socket.add(utf8.encode('${jsonEncode(header)}\n'));

        await for (final chunk in zipFile.openRead()) {
          socket.add(chunk);
        }

        await socket.flush();
        await socket.close();

        await LogService.instance.info(
          'Sent folder $folderName to ${device.name} (${device.ip}:${device.filePort}), zipBytes=$zipSize',
        );
      } catch (e) {
        await LogService.instance.error(
          'Send folder $folderName to ${device.name} failed: $e',
        );
      }
    }

    if (await zipFile.exists()) {
      await zipFile.delete();
    }
  }

  Future<void> dispose() async {
    await _serverSocket?.close();
    await _receivedFileController.close();
    await _receivedFolderController.close();
  }
}

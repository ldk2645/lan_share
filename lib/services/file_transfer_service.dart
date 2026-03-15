import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final int fromTextPort;
  final int fromFilePort;
  final DateTime time;

  ReceivedFileRecord({
    required this.fileName,
    required this.savedPath,
    required this.size,
    required this.fromDeviceName,
    required this.fromIp,
    required this.fromTextPort,
    required this.fromFilePort,
    required this.time,
  });
}

class ReceivedFolderRecord {
  final String folderName;
  final String savedPath;
  final int zipSize;
  final String fromDeviceName;
  final String fromIp;
  final int fromTextPort;
  final int fromFilePort;
  final DateTime time;

  ReceivedFolderRecord({
    required this.folderName,
    required this.savedPath,
    required this.zipSize,
    required this.fromDeviceName,
    required this.fromIp,
    required this.fromTextPort,
    required this.fromFilePort,
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

  Future<void> _trace(String message) async {
    await LogService.instance.info('[folder-trace] $message');
  }

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
    int fromTextPort = 40402;
    int fromFilePort = 40403;
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
          fromTextPort = header['fromTextPort'] as int? ?? 40402;
          fromFilePort = header['fromFilePort'] as int? ?? 40403;
          expectedSize = header['fileSize'] as int? ?? 0;

          await _trace(
            'header received type=$packetType from=$fromName ip=$fromIp textPort=$fromTextPort filePort=$fromFilePort expectedSize=$expectedSize',
          );

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

            await _trace('prepare receive file path=${outputFile.path}');
          } else if (packetType == 'folder_transfer') {
            folderName = header['folderName'] as String? ?? 'unknown_folder';

            final tempZip = await SaveLocationService.instance.createTempCacheFile(
              '${folderName}_${DateTime.now().millisecondsSinceEpoch}_recv.zip',
            );

            outputFile = await _uniqueFile(tempZip);
            sink = outputFile.openWrite();

            await _trace('prepare cache zip file=${outputFile.path}');
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

      await _trace(
        'stream write finished type=$packetType actualBytes=$receivedSize',
      );

      if (packetType == 'file_transfer' && outputFile != null) {
        final record = ReceivedFileRecord(
          fileName: outputFile.uri.pathSegments.last,
          savedPath: outputFile.path,
          size: receivedSize,
          fromDeviceName: fromName,
          fromIp: fromIp,
          fromTextPort: fromTextPort,
          fromFilePort: fromFilePort,
          time: DateTime.now(),
        );

        _receivedFileController.add(record);

        await LogService.instance.info(
          'Received file ${record.fileName} from $fromName ($fromIp), bytes=$receivedSize/$expectedSize, saved=${record.savedPath}',
        );
      }

      if (packetType == 'folder_transfer' && outputFile != null) {
        final folderParentDir = await SaveLocationService.instance
            .ensureSenderCategoryDirectory(
              senderName: fromName,
              category: 'Folders',
            );

        await _trace('folder packet received from=$fromName ip=$fromIp');
        await _trace('cached zip path=${outputFile.path}');
        await _trace('target parent dir=${folderParentDir.path}');
        await _trace(
          'start unzip folderName=$folderName expectedZipBytes=$expectedSize actualZipBytes=$receivedSize',
        );

        final beforeDirs = folderParentDir
            .listSync()
            .whereType<Directory>()
            .map((e) => e.path)
            .toSet();

        extractFileToDisk(outputFile.path, folderParentDir.path);

        await _trace('extractFileToDisk finished');

        final afterDirs = folderParentDir
            .listSync()
            .whereType<Directory>()
            .toList();

        Directory? finalFolder;

        for (final dir in afterDirs) {
          await _trace('after unzip dir=${dir.path}');
          if (!beforeDirs.contains(dir.path)) {
            finalFolder = dir;
            break;
          }
        }

        final expectedFolder = Directory(
          '${folderParentDir.path}${Platform.pathSeparator}$folderName',
        );

        if (finalFolder == null && await expectedFolder.exists()) {
          finalFolder = expectedFolder;
        }

        if (finalFolder == null) {
          await _trace(
            'no new folder detected after unzip, parent=${folderParentDir.path}',
          );
          throw Exception(
            'Folder extracted but target directory not found: $folderName',
          );
        }

        await _trace('final extracted folder=${finalFolder.path}');

        if (await outputFile.exists()) {
          await _trace('delete cache zip=${outputFile.path}');
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
          fromTextPort: fromTextPort,
          fromFilePort: fromFilePort,
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
          'fromTextPort': 40402,
          'fromFilePort': 40403,
          'time': DateTime.now().toIso8601String(),
        };

        await _trace(
          'send file start target=${device.name} ${device.ip}:${device.filePort} file=$fileName size=$fileSize',
        );

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

    final zipFile = await SaveLocationService.instance.createTempCacheFile(
      '${folderName}_${DateTime.now().millisecondsSinceEpoch}.zip',
    );

    await _trace('start pack folder=${folder.path}');
    await _trace('cache zip path=${zipFile.path}');

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    encoder.addDirectory(folder, includeDirName: true);
    encoder.close();

    final zipSize = await zipFile.length();
    await _trace('pack finished zip=${zipFile.path} size=$zipSize');

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
          'fromTextPort': 40402,
          'fromFilePort': 40403,
          'time': DateTime.now().toIso8601String(),
        };

        await _trace(
          'send folder start target=${device.name} ${device.ip}:${device.filePort} folder=$folderName zipSize=$zipSize',
        );

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
      await _trace('delete cache zip after send=${zipFile.path}');
      await zipFile.delete();
    }
  }

  Future<void> dispose() async {
    await _serverSocket?.close();
    await _receivedFileController.close();
    await _receivedFolderController.close();
  }
}

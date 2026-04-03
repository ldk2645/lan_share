import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';
import 'log_service.dart';

class ReceivedTextMessage {
  final String fromDeviceName;
  final String fromIp;
  final String text;
  final String contentType;
  final bool preserveFormat;
  final int fromTextPort;
  final int fromFilePort;
  final DateTime time;

  ReceivedTextMessage({
    required this.fromDeviceName,
    required this.fromIp,
    required this.text,
    required this.contentType,
    required this.preserveFormat,
    required this.fromTextPort,
    required this.fromFilePort,
    required this.time,
  });
}

class MessageService {
  static const int messagePort = 40402;

  final String selfName;
  ServerSocket? _serverSocket;

  final StreamController<ReceivedTextMessage> _messageController =
      StreamController<ReceivedTextMessage>.broadcast();

  Stream<ReceivedTextMessage> get messageStream => _messageController.stream;

  MessageService({required this.selfName});

  Future<void> start() async {
    if (_serverSocket != null) return;

    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      messagePort,
      shared: true,
    );

    await LogService.instance.info(
      'Message server started at ${_serverSocket?.address.address}:$messagePort',
    );

    _serverSocket!.listen(_handleClient);
  }

  Future<void> _handleClient(Socket socket) async {
    try {
      final List<int> bytes = await _collectBytes(socket);
      final raw = utf8.decode(bytes);
      final map = jsonDecode(raw);

      if (map is! Map<String, dynamic>) {
        return;
      }

      final type = map['type'] as String? ?? '';
      if (type != 'text_message') {
        return;
      }

      final fromName = map['fromName'] as String? ?? 'Unknown Device';
      final fromIp = socket.remoteAddress.address;
      final messageText = map['text'] as String? ?? '';
      final contentType = map['contentType'] as String? ?? 'text/plain';
      final preserveFormat = map['preserveFormat'] as bool? ?? true;
      final fromTextPort = map['fromTextPort'] as int? ?? 40402;
      final fromFilePort = map['fromFilePort'] as int? ?? 40403;

      final message = ReceivedTextMessage(
        fromDeviceName: fromName,
        fromIp: fromIp,
        text: messageText,
        contentType: contentType,
        preserveFormat: preserveFormat,
        fromTextPort: fromTextPort,
        fromFilePort: fromFilePort,
        time: DateTime.now(),
      );

      _messageController.add(message);

      await LogService.instance.info(
        'Received text from $fromName ($fromIp), type=$contentType, length=${messageText.length}',
      );
    } catch (e) {
      await LogService.instance.error('Read message failed: $e');
    } finally {
      await socket.close();
    }
  }

  Future<void> sendTextToDevices({
    required String text,
    required String fromName,
    required String fromIp,
    required List<Device> devices,
    String contentType = 'text/plain',
    bool preserveFormat = true,
  }) async {
    for (final device in devices) {
      bool delivered = false;
      Object? lastError;

      for (int attempt = 1; attempt <= 3; attempt++) {
        Socket? socket;
        try {
          socket = await Socket.connect(
            device.ip,
            device.textPort,
            timeout: const Duration(seconds: 4),
          );

          final packet = <String, dynamic>{
            'type': 'text_message',
            'fromName': fromName,
            'fromIp': fromIp,
            'fromTextPort': 40402,
            'fromFilePort': 40403,
            'text': text,
            'contentType': contentType,
            'preserveFormat': preserveFormat,
            'time': DateTime.now().toIso8601String(),
          };

          socket.add(utf8.encode(jsonEncode(packet)));
          await socket.flush();
          await socket.close();

          delivered = true;
          await LogService.instance.info(
            'Sent text to ${device.name} (${device.ip}:${device.textPort}), type=$contentType, length=${text.length}, attempt=$attempt',
          );
          break;
        } catch (e) {
          lastError = e;
          await socket?.close();

          if (attempt < 3) {
            await LogService.instance.warn(
              'Send text retry $attempt/3 to ${device.name} failed: $e',
            );
            await Future<void>.delayed(
              Duration(milliseconds: 350 * attempt),
            );
          }
        }
      }

      if (!delivered) {
        await LogService.instance.error(
          'Send text to ${device.name} failed: $lastError',
        );
      }
    }
  }

  Future<List<int>> _collectBytes(Socket socket) async {
    final List<int> all = <int>[];
    await for (final chunk in socket) {
      all.addAll(chunk);
    }
    return all;
  }

  Future<void> dispose() async {
    await _serverSocket?.close();
    _serverSocket = null;
    await _messageController.close();
  }
}

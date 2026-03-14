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
  final DateTime time;

  ReceivedTextMessage({
    required this.fromDeviceName,
    required this.fromIp,
    required this.text,
    required this.contentType,
    required this.preserveFormat,
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
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      messagePort,
      shared: true,
    );

    await LogService.instance.info(
      'Message server started at port $messagePort',
    );

    _serverSocket!.listen((socket) {
      socket.listen(
        (data) async {
          try {
            final raw = utf8.decode(data);
            final map = jsonDecode(raw);

            if (map is! Map<String, dynamic>) {
              return;
            }

            final type = map['type'] as String? ?? '';
            if (type != 'text_message') {
              return;
            }

            final fromName = map['fromName'] as String? ?? 'Unknown Device';
            final fromIp =
                map['fromIp'] as String? ?? socket.remoteAddress.address;
            final messageText = map['text'] as String? ?? '';
            final contentType = map['contentType'] as String? ?? 'text/plain';
            final preserveFormat = map['preserveFormat'] as bool? ?? true;

            final message = ReceivedTextMessage(
              fromDeviceName: fromName,
              fromIp: fromIp,
              text: messageText,
              contentType: contentType,
              preserveFormat: preserveFormat,
              time: DateTime.now(),
            );

            _messageController.add(message);

            await LogService.instance.info(
              'Received text from $fromName ($fromIp), type=$contentType, length=${messageText.length}',
            );
          } catch (e) {
            await LogService.instance.error('Read message failed: $e');
          }
        },
        onDone: () {
          socket.destroy();
        },
        onError: (error) async {
          await LogService.instance.error('Socket read error: $error');
          socket.destroy();
        },
      );
    });
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
      try {
        final socket = await Socket.connect(
          device.ip,
          device.textPort,
          timeout: const Duration(seconds: 3),
        );

        final packet = {
          'type': 'text_message',
          'fromName': fromName,
          'fromIp': fromIp,
          'text': text,
          'contentType': contentType,
          'preserveFormat': preserveFormat,
          'time': DateTime.now().toIso8601String(),
        };

        socket.add(utf8.encode(jsonEncode(packet)));
        await socket.flush();
        await socket.close();

        await LogService.instance.info(
          'Sent text to ${device.name} (${device.ip}:${device.textPort}), type=$contentType, length=${text.length}',
        );
      } catch (e) {
        await LogService.instance.error(
          'Send text to ${device.name} failed: $e',
        );
      }
    }
  }

  Future<void> dispose() async {
    await _serverSocket?.close();
    await _messageController.close();
  }
}

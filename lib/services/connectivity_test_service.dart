import 'dart:io';

class PortTestResult {
  final String host;
  final int port;
  final bool success;
  final String message;

  PortTestResult({
    required this.host,
    required this.port,
    required this.success,
    required this.message,
  });
}

class ConnectivityTestService {
  static Future<PortTestResult> testPort({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    Socket? socket;

    try {
      socket = await Socket.connect(host, port, timeout: timeout);

      await socket.close();

      return PortTestResult(
        host: host,
        port: port,
        success: true,
        message: 'Connected successfully',
      );
    } catch (e) {
      return PortTestResult(
        host: host,
        port: port,
        success: false,
        message: e.toString(),
      );
    } finally {
      await socket?.close();
    }
  }
}

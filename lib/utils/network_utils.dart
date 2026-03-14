import 'dart:io';

class NetworkUtils {
  static Future<String> findLocalIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        final ip = addr.address;
        if (!ip.startsWith('127.')) {
          return ip;
        }
      }
    }

    return '0.0.0.0';
  }
}

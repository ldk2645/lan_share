import 'dart:io';

class NetworkUtils {
  static Future<String> findLocalIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    String? fallback;

    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      final looksVirtual =
          name.contains('virtual') ||
          name.contains('vmware') ||
          name.contains('vbox') ||
          name.contains('hyper-v') ||
          name.contains('vethernet') ||
          name.contains('vpn') ||
          name.contains('loopback') ||
          name.contains('bluetooth');

      for (final addr in interface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
          continue;
        }

        fallback ??= ip;

        final isPrivateLan =
            ip.startsWith('192.168.') || ip.startsWith('10.') || _is172(ip);

        if (isPrivateLan && !looksVirtual) {
          return ip;
        }
      }
    }

    return fallback ?? '0.0.0.0';
  }

  static bool _is172(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '172') return false;
    final second = int.tryParse(parts[1]) ?? -1;
    return second >= 16 && second <= 31;
  }
}

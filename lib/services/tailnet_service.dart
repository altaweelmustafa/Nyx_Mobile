import 'dart:io';

/// Detects whether this device currently has a Tailscale interface up, by
/// checking for a local IPv4 address in Tailscale's CGNAT range
/// (100.64.0.0/10). This IS the auth model for Nyx -- same philosophy
/// JamService's host/client already uses: no credentials, the tailnet's
/// own network boundary is the security boundary. No package, no external
/// call -- just local network interface enumeration.
class TailnetService {
  // 100.64.0.0/10 == 100.64.0.0 through 100.127.255.255.
  static const _rangeStart = 0x64400000;
  static const _rangeEnd = 0x647FFFFF;

  /// The device's current Tailscale IP, or null if not connected.
  static Future<String?> currentTailnetIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isTailscaleRange(addr)) return addr.address;
        }
      }
    } catch (_) {
      // No interfaces reachable, permission denied, etc. -- treat as
      // not connected rather than surfacing a platform-specific error.
    }
    return null;
  }

  static Future<bool> isOnTailnet() async => (await currentTailnetIp()) != null;

  static bool _isTailscaleRange(InternetAddress addr) {
    final bytes = addr.rawAddress;
    if (bytes.length != 4) return false;
    final value =
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    return value >= _rangeStart && value <= _rangeEnd;
  }
}

import 'package:wake_on_lan/wake_on_lan.dart';

/// Wake‑on‑LAN helper.
///
/// TVs disconnect from Wi‑Fi when powered off. To power them back on we send a
/// "Magic Packet" containing the TV's MAC address to the broadcast address.
/// The TV's NIC (wired or wireless) must have WOL enabled in its settings.
class WolService {
  /// Send a Wake‑on‑LAN magic packet.
  /// [macAddress] – colon‑separated MAC like "AA:BB:CC:DD:EE:FF".
  /// [broadcastIp] – usually 255.255.255.255 or subnet broadcast.
  static Future<void> wake(
    String macAddress, {
    String broadcastIp = '255.255.255.255',
  }) async {
    try {
      final ip = IPAddress(broadcastIp);
      final mac = MACAddress(macAddress);

      await WakeOnLAN(ip, mac).wake();
    } catch (_) {
      // Swallow – WOL is best‑effort.
    }
  }
}
